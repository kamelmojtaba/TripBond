from supabase import create_client, Client
from supabase.lib.client_options import ClientOptions
from .config import get_settings
from fastapi import Header, HTTPException, status
from fastapi.concurrency import run_in_threadpool
from typing import Optional
import logging

"""
Database Access Layer - Supabase Client Management

⚠️ SECURITY WARNING:
- SupabaseDB(admin=True) bypasses RLS - use ONLY for admin/global operations
- SupabaseDB(admin=False) uses anon client without JWT - RLS sees anonymous user
- For per-user operations: use get_supabase_client_for_user(token) instead

Correct pattern:
    client = get_supabase_client_for_user(token)
    result = await run_in_threadpool(lambda: client.table(...).execute())

Token handling (use as FastAPI dependencies):
- get_current_user_token(): Extracts token from header (NO validation - just parsing)
- get_current_user_id(): VALIDATES token signature via Supabase, returns verified user_id
  
✅ SAFE for authorization: get_current_user_id() - calls auth.get_user() to verify signature
❌ UNSAFE for authorization: get_current_user_token() alone - doesn't verify signature

Current security status:
- get_current_user_id() NOW validates tokens via auth.get_user() (prevents forgery)
- SupabaseDB logs all admin=True usage with caller location for auditing
- All admin usages currently derive user_id from JWT (safe from parameter tampering)
"""

logger = logging.getLogger(__name__)


def get_supabase_admin_client() -> Client:
    """
    Admin client (SERVICE_ROLE): bypasses RLS. Use carefully for backend-admin tasks only.

    Supabase 2.10 creates a PostgREST httpx client with HTTP/2 enabled and no way
    to inject our own transport options. Keeping one process-wide client can reuse
    a stale/shared connection across concurrent FastAPI requests, which shows up
    as intermittent httpx.RemoteProtocolError: "Server disconnected".
    """
    settings = get_settings()
    return create_client(
        supabase_url=settings.supabase_url,
        supabase_key=settings.supabase_service_role_key,
        options=ClientOptions(
            auto_refresh_token=False,
            persist_session=False,
        ),
    )


def get_supabase_anon_client() -> Client:
    """Base client for token validation and user-scoped requests."""
    settings = get_settings()
    return create_client(
        supabase_url=settings.supabase_url,
        supabase_key=settings.supabase_anon_key,
        options=ClientOptions(
            auto_refresh_token=False,
            persist_session=False,
        ),
    )


def get_supabase_client_for_user(access_token: str) -> Client:
    """
    Create Supabase client with user JWT for proper RLS enforcement.
    
    Use this for all per-user operations. The JWT ensures RLS policies
    apply correctly and operations are scoped to the authenticated user.
    """
    settings = get_settings()
    client = create_client(
        supabase_url=settings.supabase_url,
        supabase_key=settings.supabase_anon_key,
        options=ClientOptions(
            auto_refresh_token=False,
            persist_session=False,
        ),
    )
    client.postgrest.auth(access_token)
    
    return client


async def get_current_user_id(authorization: Optional[str] = Header(None)) -> str:
    """
    Extract and VALIDATE user_id from JWT via Supabase auth.
    
    ✅ SECURE: Calls auth.get_user() to verify JWT signature with Supabase.
    This prevents token forgery - only valid tokens signed by Supabase will pass.
    
    Use this dependency for endpoints that need verified user identity.
    """
    token = await get_current_user_token(authorization)
    
    try:
        client = get_supabase_anon_client()
        # This call validates the token signature server-side
        user_response = await run_in_threadpool(lambda: client.auth.get_user(token))
        
        if not user_response.user:
            raise HTTPException(status_code=401, detail="Invalid or expired token")
        
        return user_response.user.id
        
    except Exception as e:
        logger.error(f"Token validation failed: {e}")
        raise HTTPException(status_code=401, detail="Invalid token")


async def get_current_user_token(authorization: Optional[str] = Header(None)) -> str:
    """
    Extract JWT token from Authorization header (NO validation).
    
    ⚠️ This only parses the header - it does NOT verify the token signature.
    
    Safe usage patterns:
    ✅ Pass to get_supabase_client_for_user() - Supabase validates it
    ✅ Use as input to get_current_user_id() - validates and extracts user_id
    
    Unsafe:
    ❌ Don't decode and use claims for authorization without validation
    ❌ Don't extract user_id by decoding - use get_current_user_id() instead
    """
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing authorization header")
    
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(status_code=401, detail="Invalid authorization header format")
    
    return parts[1]


class SupabaseDB:
    """
    ⚠️ DEPRECATED: Use get_supabase_client_for_user(token) for per-user operations
    
    Only use SupabaseDB(admin=True) for admin/global operations.
    admin=False will fail with proper RLS policies (no user JWT attached).
    
    🚨 RISK: Easy to misuse. Audit all usages before production.
    """
    
    def __init__(self, admin: bool = False):
        import inspect
        caller_frame = inspect.currentframe().f_back
        caller_info = f"{caller_frame.f_code.co_filename}:{caller_frame.f_lineno}"
        
        if admin:
            logger.warning(f"🚨 ADMIN CLIENT used at {caller_info} - bypasses RLS")
        else:
            logger.warning(f"SupabaseDB(admin=False) at {caller_info} - no user context, use get_supabase_client_for_user(token)")
        
        self.client = get_supabase_admin_client() if admin else get_supabase_anon_client()
        self.admin = admin
    
    def get_user_preferences(self, user_id: str):
        """
        ⚠️ DEPRECATED: Refactor to use get_supabase_client_for_user(token)
        
        Security: With admin=True, ensure user_id comes from JWT, not request params.
        """
        if self.admin:
            logger.info(f"Admin fetch: user_preferences for user_id={user_id}")
        
        profile_response = self.client.table("profiles").select("*").eq("id", user_id).execute()
        profile = profile_response.data[0] if profile_response.data else None
        
        personality_response = self.client.table("personality_answers").select("*").eq("user_id", user_id).execute()
        prefs_response = self.client.table("trip_preferences").select("*").eq("user_id", user_id).execute()
        
        if profile:
            profile["personality_answers"] = personality_response.data
            profile["trip_preferences"] = prefs_response.data
        
        return profile
