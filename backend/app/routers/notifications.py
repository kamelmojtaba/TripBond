"""
Notifications endpoints.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from typing import List, Dict, Any

from ..auth import get_current_user_context
from ..services import notification_service

router = APIRouter()


@router.get("/", response_model=List[Dict[str, Any]])
async def list_notifications(
    only_unread: bool = Query(False),
    limit: int = Query(50, ge=1, le=200),
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    user_id, _ = user_context
    return notification_service.list_for_user(user_id, limit=limit, only_unread=only_unread)


@router.get("/unread-count")
async def get_unread_count(user_context: tuple[str, str] = Depends(get_current_user_context)):
    user_id, _ = user_context
    return {"count": notification_service.unread_count(user_id)}


@router.post("/{notification_id}/read")
async def mark_read(
    notification_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    user_id, _ = user_context
    ok = notification_service.mark_read(user_id, notification_id)
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found",
        )
    return {"message": "Notification marked as read"}


@router.post("/read-all")
async def mark_all_read(user_context: tuple[str, str] = Depends(get_current_user_context)):
    user_id, _ = user_context
    count = notification_service.mark_all_read(user_id)
    return {"message": "All notifications marked as read", "count": count}
