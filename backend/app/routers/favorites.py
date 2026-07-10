from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.concurrency import run_in_threadpool
from typing import List
from ..schemas.favorites import FavoriteResponse, AddFavoriteRequest
from ..services import favorites_service
from ..auth import get_current_user_context

router = APIRouter()


def _ensure_self(user_id: str, auth_user_id: str) -> None:
    if user_id != auth_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot access another user's favorites",
        )


@router.get("/{user_id}", response_model=List[FavoriteResponse])
async def get_user_favorites(
    user_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Get all favorites for the authenticated user."""
    auth_user_id, _ = user_context
    _ensure_self(user_id, auth_user_id)
    try:
        return await run_in_threadpool(favorites_service.get_user_favorites, user_id)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get favorites: {str(e)}",
        )


@router.post("/{user_id}", response_model=FavoriteResponse)
async def add_favorite(
    user_id: str,
    favorite: AddFavoriteRequest,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Add a destination, trip, or POI to the authenticated user's favorites."""
    auth_user_id, _ = user_context
    _ensure_self(user_id, auth_user_id)
    try:
        return await run_in_threadpool(favorites_service.add_favorite, user_id, favorite)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to add favorite: {str(e)}",
        )


@router.delete("/{user_id}/{favorite_id}")
async def remove_favorite(
    user_id: str,
    favorite_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Remove a favorite (owner only)."""
    auth_user_id, _ = user_context
    _ensure_self(user_id, auth_user_id)
    try:
        await run_in_threadpool(favorites_service.remove_favorite, user_id, favorite_id)
        return {"message": "Favorite removed successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to remove favorite: {str(e)}",
        )
