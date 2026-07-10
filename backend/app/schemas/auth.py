"""
Authentication Schemas

Pydantic models for request/response validation in auth endpoints.
"""
from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import date


class SignUpRequest(BaseModel):
    # Basic registration info only
    email: EmailStr
    password: str
    full_name: str
    date_of_birth: Optional[date] = None
    phone_number: Optional[str] = None
    gender: Optional[str] = None  # 'male', 'female'


class SignInRequest(BaseModel):
    email: EmailStr
    password: str


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: dict
    message: str


class PasswordResetRequest(BaseModel):
    email: EmailStr


class VerifyResetCodeRequest(BaseModel):
    email: EmailStr
    code: str


class UpdatePasswordRequest(BaseModel):
    new_password: str


class UpdatePasswordWithCodeRequest(BaseModel):
    email: EmailStr
    code: str
    new_password: str


class VerifyEmailRequest(BaseModel):
    token_hash: str
    type: str = "email"  # 'email', 'signup'


class ResendVerificationRequest(BaseModel):
    email: EmailStr


# ── 6-digit email verification code flow ─────────────────────────────────────

class SendVerificationCodeRequest(BaseModel):
    """Request to send (or resend) a 6-digit verification code to an email."""
    email: EmailStr


class VerifyEmailCodeRequest(BaseModel):
    """Request to verify a 6-digit code submitted by the user."""
    email: EmailStr
    code: str
