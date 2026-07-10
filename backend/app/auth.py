"""
Authentication Dependencies

FastAPI dependencies for user authentication and authorization.
Prevents circular imports between routers by centralizing auth logic.
"""
from fastapi import Depends, HTTPException, status
from fastapi.concurrency import run_in_threadpool
from .database import get_current_user_token, get_supabase_client_for_user
from .config import get_settings
import logging
import jwt

logger = logging.getLogger(__name__)


async def get_current_user_context(token: str = Depends(get_current_user_token)) -> tuple[str, str]:
    """
    FastAPI dependency to extract user ID and token from authenticated custom JWT
    
    Validates the custom JWT token and extracts user information.
    
    Returns:
        Tuple of (user_id, token) for endpoints that need both user ID and token
    
    Raises:
        HTTPException: If token is invalid or expired
    """
    try:
        config = get_settings()
        
        # Decode and verify custom JWT token
        payload = jwt.decode(token, config.secret_key, algorithms=[config.algorithm])
        
        # Extract user ID from token
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication token"
            )
        
        return user_id, token
        
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired"
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token"
        )
    except Exception as e:
        logger.exception("Failed to extract user from token")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication failed"
        )
