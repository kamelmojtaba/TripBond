from fastapi import APIRouter, HTTPException, status, Depends
from fastapi.concurrency import run_in_threadpool
from ..database import SupabaseDB, get_current_user_token, get_supabase_client_for_user, get_supabase_admin_client
from ..config import get_settings
from ..schemas.auth import (
    SignUpRequest,
    SignInRequest,
    AuthResponse,
    PasswordResetRequest,
    VerifyResetCodeRequest,
    UpdatePasswordRequest,
    UpdatePasswordWithCodeRequest,
    VerifyEmailRequest,
    ResendVerificationRequest,
    SendVerificationCodeRequest,
    VerifyEmailCodeRequest,
)
from ..services import verification_store
from ..services import password_reset_store
from ..services.email_service import send_verification_code_email, send_password_reset_code_email
import logging
import bcrypt
import jwt
import uuid
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/signup", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def sign_up(request: SignUpRequest):
    """
    Register a new user with email and password (Custom Auth - No Supabase Auth)
    """
    try:
        print(f"\n🔵 CUSTOM SIGNUP REQUEST RECEIVED")
        print(f"Email: {request.email}")
        print(f"Name: {request.full_name}")
        print(f"DOB: {request.date_of_birth}")
        
        admin_client = get_supabase_admin_client()
        config = get_settings()
        
        # Check if user already exists
        print(f"🔵 Checking if user exists...")
        existing_user = await run_in_threadpool(
            lambda: admin_client.table("profiles").select("id").eq("email_address", request.email.lower()).execute()
        )
        
        if existing_user.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )
        
        # Generate user ID
        user_id = str(uuid.uuid4())
        print(f"🔵 Generated user ID: {user_id}")
        
        # Hash password
        password_hash = bcrypt.hashpw(request.password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        print(f"🔵 Password hashed")
        
        # Create profile with hashed password
        profile_data = {
            "id": user_id,
            "email_address": request.email.lower(),
            "password_hash": password_hash,
            "full_name": request.full_name,
            "date_of_birth": request.date_of_birth.isoformat() if request.date_of_birth else None,
            "phone_number": request.phone_number,
            "gender": request.gender.lower() if request.gender else None,
            "email_verified": False,  # Not verified yet
            "created_at": datetime.utcnow().isoformat(),
        }
        
        # Insert profile (ignore None values)
        profile_data = {k: v for k, v in profile_data.items() if v is not None}
        
        print(f"🔵 Inserting profile: {profile_data}")
        await run_in_threadpool(lambda: admin_client.table("profiles").insert(profile_data).execute())
        
        print(f"🔵 Profile created successfully!")

        # Generate and send 6-digit email verification code
        code = verification_store.generate_code()
        verification_store.store_code(request.email, code, user_id)
        send_verification_code_email(
            to_email=request.email,
            code=code,
            name=request.full_name,
        )
        print(f"🔵 Verification code sent to {request.email}")

        # Generate JWT token (unverified)
        token_payload = {
            "sub": user_id,
            "email": request.email.lower(),
            "email_verified": False,
            "exp": datetime.utcnow() + timedelta(days=30)
        }
        access_token = jwt.encode(token_payload, config.secret_key, algorithm=config.algorithm)

        return AuthResponse(
            access_token=access_token,
            user={
                "id": user_id,
                "email": request.email.lower(),
                "full_name": request.full_name,
                "email_verified": False
            },
            message="Account created! A 6-digit verification code has been sent to your email."
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"\n🔴 SIGNUP ERROR: {type(e).__name__}: {str(e)}")
        import traceback
        traceback.print_exc()
        logger.exception("Signup failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Signup failed: {str(e)}"
        )


@router.post("/signin", response_model=AuthResponse)
async def sign_in(request: SignInRequest):
    """
    Sign in user with email and password (Custom Auth - No Supabase Auth)
    """
    try:
        print(f"\n🔵 CUSTOM SIGNIN REQUEST")
        print(f"Email: {request.email}")
        
        admin_client = get_supabase_admin_client()
        config = get_settings()
        
        # Get user by email
        user_result = await run_in_threadpool(
            lambda: admin_client.table("profiles")
            .select("id, email_address, password_hash, full_name, username, avatar_url, email_verified")
            .eq("email_address", request.email.lower())
            .execute()
        )
        
        if not user_result.data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
        
        user = user_result.data[0]
        
        # Verify password
        if not bcrypt.checkpw(request.password.encode('utf-8'), user["password_hash"].encode('utf-8')):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
        
        print(f"🔵 Password verified for user: {user['id']}")
        
        # Generate JWT token
        token_payload = {
            "sub": user["id"],
            "email": user["email_address"],
            "email_verified": user.get("email_verified", False),
            "exp": datetime.utcnow() + timedelta(days=30)
        }
        access_token = jwt.encode(token_payload, config.secret_key, algorithm=config.algorithm)
        
        print(f"🔵 Signin successful!")
        
        return AuthResponse(
            access_token=access_token,
            user={
                "id": user["id"],
                "email": user["email_address"],
                "full_name": user.get("full_name"),
                "username": user.get("username"),
                "avatar_url": user.get("avatar_url")
            },
            message="Signed in successfully!"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"\n🔴 SIGNIN ERROR: {type(e).__name__}: {str(e)}")
        logger.exception("Sign in failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Sign in failed. Please check your credentials."
        )


@router.post("/signout")
async def sign_out(token: str = Depends(get_current_user_token)):
    """
    Sign out the current user
    
    Requires: Authorization header with Bearer token
    
    Note: In Supabase architecture, signout is typically handled client-side
    by clearing the local session. This endpoint provides server-side revocation
    if needed, but frontend should still clear local storage.
    """
    try:
        # Use user-authenticated client to sign out the specific session
        client = get_supabase_client_for_user(token)
        client.auth.sign_out()
        
        return {"message": "Signed out successfully. Please clear your local session."}
        
    except Exception as e:
        logger.exception("Sign out failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Sign out failed. Please try again."
        )


@router.post("/reset-password")
async def reset_password(request: PasswordResetRequest):
    """
    Send password reset code email to user (custom auth flow).
    """
    try:
        admin_client = get_supabase_admin_client()

        user_result = await run_in_threadpool(
            lambda: admin_client.table("profiles")
            .select("id, email_address, full_name")
            .eq("email_address", request.email.lower())
            .limit(1)
            .execute()
        )

        if user_result.data:
            user = user_result.data[0]
            code = password_reset_store.generate_code()
            password_reset_store.store_code(request.email, code, user["id"])
            send_password_reset_code_email(
                to_email=request.email,
                code=code,
                name=user.get("full_name") or "",
            )
        
        return {
            "message": f"If an account exists with {request.email}, you will receive a password reset email."
        }
        
    except Exception as e:
        logger.exception("Password reset request failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Password reset request failed. Please try again."
        )


@router.post("/verify-reset-code")
async def verify_reset_code(request: VerifyResetCodeRequest):
    """
    Verify a 6-digit password reset code for an email.
    """
    try:
        is_valid = password_reset_store.verify(request.email, request.code)
        return {"valid": is_valid}
    except Exception:
        logger.exception("Password reset code verification failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to verify reset code. Please try again.",
        )


@router.post("/update-password-with-code")
async def update_password_with_code(request: UpdatePasswordWithCodeRequest):
    """
    Update password using email + 6-digit reset code (custom auth flow).
    """
    try:
        user_id = password_reset_store.verify_and_consume(request.email, request.code)
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired reset code. Please request a new one.",
            )

        admin_client = get_supabase_admin_client()
        password_hash = bcrypt.hashpw(request.new_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

        await run_in_threadpool(
            lambda: admin_client.table("profiles")
            .update({"password_hash": password_hash})
            .eq("id", user_id)
            .execute()
        )

        return {
            "message": "Password updated successfully! You can now sign in with your new password."
        }
    except HTTPException:
        raise
    except Exception:
        logger.exception("Password update with code failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Password update failed. Please try again.",
        )


@router.post("/update-password")
async def update_password(
    request: UpdatePasswordRequest,
    token: str = Depends(get_current_user_token)
):
    """
    Update password for authenticated user
    
    Requires: Authorization header with valid JWT access token.
    
    Flow:
    1. User requests password reset via /reset-password
    2. Receives email with reset link (format depends on Supabase config)
    3. Frontend handles the reset link and extracts/exchanges for access token
    4. Frontend calls this endpoint with Authorization: Bearer <access_token>
    5. Password is updated for the authenticated user
    
    Note: Supabase password reset links may contain access_token directly,
    or may require an additional exchange step depending on your configuration.
    Frontend must provide a valid JWT access token in the Authorization header.
    
    Alternative: Use Supabase client-side updateUser() directly from frontend
    for simpler flow and better cross-version compatibility.
    """
    try:
        # Use user-authenticated client so Supabase knows which user to update
        client = get_supabase_client_for_user(token)
        
        # Update the user's password using their authenticated session
        response = client.auth.update_user({
            "password": request.new_password
        })
        
        if not response.user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to update password. Please try again or request a new reset link."
            )
        
        return {
            "message": "Password updated successfully! You can now sign in with your new password."
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Password update failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Password update failed. Please try again."
        )


@router.post("/verify-email")
async def verify_email(request: VerifyEmailRequest):
    """
    Verify user email with token hash from verification email
    Token hash is received from the verification email link
    """
    try:
        db = SupabaseDB()
        
        # Verify the OTP/token
        response = db.client.auth.verify_otp({
            "token_hash": request.token_hash,
            "type": request.type
        })
        
        if not response.user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired verification token"
            )
        
        return {
            "message": "Email verified successfully! You can now sign in.",
            "user": {
                "id": response.user.id,
                "email": response.user.email,
                "email_confirmed_at": response.user.email_confirmed_at
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Email verification failed")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email verification failed. The link may be invalid or expired."
        )


@router.post("/resend-verification")
async def resend_verification_email(request: ResendVerificationRequest):
    """
    Resend verification email to user
    """
    try:
        db = SupabaseDB()
        
        # Resend verification email
        db.client.auth.resend({
            "type": "signup",
            "email": request.email
        })
        
        return {
            "message": f"Verification email sent to {request.email}. Please check your inbox."
        }
        
    except Exception as e:
        logger.exception("Failed to resend verification email")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to resend verification email. Please try again."
        )


# ── 6-digit email verification code endpoints ──────────────────────────────


@router.post("/send-verification-code")
async def send_email_verification_code(request: SendVerificationCodeRequest):
    """
    Generate a 6-digit verification code and send it to the given email.
    Call this to resend/refresh the code (e.g., if the user clicks 'Resend').
    """
    try:
        admin_client = get_supabase_admin_client()

        # Look up the user by email using the admin API
        users_response = await run_in_threadpool(
            lambda: admin_client.auth.admin.list_users()
        )

        user = next(
            (u for u in users_response if u.email and u.email.lower() == request.email.lower()),
            None,
        )
        if not user:
            # Don't reveal whether the email exists
            return {"message": "If an account exists for this email, a verification code has been sent."}

        code = verification_store.generate_code()
        verification_store.store_code(request.email, code, user.id)
        send_verification_code_email(to_email=request.email, code=code, name="")

        return {"message": "A new verification code has been sent to your email."}

    except Exception as e:
        logger.exception("Failed to send verification code")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send verification code. Please try again.",
        )


@router.post("/verify-email-code")
async def verify_email_code(request: VerifyEmailCodeRequest):
    """
    Verify the 6-digit code submitted by the user.
    On success, marks the user's email as verified and returns an access token.
    """
    try:
        user_id = verification_store.verify_and_consume(request.email, request.code)

        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired verification code. Please request a new one.",
            )

        # Update email_verified in profiles table
        admin_client = get_supabase_admin_client()
        await run_in_threadpool(
            lambda: admin_client.table("profiles")
            .update({"email_verified": True})
            .eq("id", user_id)
            .execute()
        )

        # Get user details for token generation
        user_result = await run_in_threadpool(
            lambda: admin_client.table("profiles")
            .select("id, email_address, full_name, username, avatar_url")
            .eq("id", user_id)
            .execute()
        )

        if not user_result.data or len(user_result.data) == 0:
            raise HTTPException(status_code=404, detail="User not found")

        user = user_result.data[0]

        # Generate access token with email_verified = true
        config = get_settings()
        token_payload = {
            "sub": user["id"],
            "email": user["email_address"],
            "email_verified": True,
            "exp": datetime.utcnow() + timedelta(days=30)
        }
        access_token = jwt.encode(token_payload, config.secret_key, algorithm=config.algorithm)

        logger.info(f"Email verified for user {user_id}")
        return {
            "message": "Email verified successfully!",
            "email": request.email,
            "access_token": access_token,
            "user": {
                "id": user["id"],
                "email": user["email_address"],
                "full_name": user["full_name"],
                "username": user["username"],
                "avatar_url": user["avatar_url"],
                "email_verified": True
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Email code verification failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Email verification failed. Please try again.",
        )
