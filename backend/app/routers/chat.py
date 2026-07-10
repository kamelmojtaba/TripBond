from fastapi import APIRouter, HTTPException, status, Depends, Query
from fastapi.concurrency import run_in_threadpool
from typing import List
import logging
from datetime import datetime, timezone

from ..auth import get_current_user_context
from ..database import SupabaseDB
from ..schemas.chat import (
    ChatMessageResponse,
    ConversationPreviewResponse,
    MarkReadResponse,
    SendMessageRequest,
)

logger = logging.getLogger(__name__)
router = APIRouter()


def _ordered_pair(user_a: str, user_b: str) -> tuple[str, str]:
    return (user_a, user_b) if user_a < user_b else (user_b, user_a)


async def _find_conversation_id(db: SupabaseDB, user_a: str, user_b: str) -> str | None:
    low, high = _ordered_pair(user_a, user_b)
    response = await run_in_threadpool(
        lambda: db.client.table("chat_conversations")
        .select("id")
        .eq("user_1_id", low)
        .eq("user_2_id", high)
        .limit(1)
        .execute()
    )
    if response.data:
        return response.data[0]["id"]
    return None


@router.get("/conversations", response_model=List[ConversationPreviewResponse])
async def get_conversations(user_context: tuple[str, str] = Depends(get_current_user_context)):
    """Get conversation previews for the current user."""
    user_id, _token = user_context

    try:
        db = SupabaseDB(admin=True)

        first = await run_in_threadpool(
            lambda: db.client.table("chat_conversations")
            .select("id,user_1_id,user_2_id,created_at")
            .eq("user_1_id", user_id)
            .execute()
        )
        second = await run_in_threadpool(
            lambda: db.client.table("chat_conversations")
            .select("id,user_1_id,user_2_id,created_at")
            .eq("user_2_id", user_id)
            .execute()
        )

        by_id: dict[str, dict] = {}
        for item in (first.data or []) + (second.data or []):
            by_id[item["id"]] = item

        conversations = list(by_id.values())
        if not conversations:
            return []

        previews: list[ConversationPreviewResponse] = []
        for conv in conversations:
            partner_id = conv["user_2_id"] if conv["user_1_id"] == user_id else conv["user_1_id"]

            profile = await run_in_threadpool(
                lambda: db.client.table("profiles")
                .select("full_name,username,avatar_url")
                .eq("id", partner_id)
                .limit(1)
                .execute()
            )
            p = profile.data[0] if profile.data else {}

            last_message_resp = await run_in_threadpool(
                lambda: db.client.table("chat_messages")
                .select("content,created_at")
                .eq("conversation_id", conv["id"])
                .order("created_at", desc=True)
                .limit(1)
                .execute()
            )
            m = last_message_resp.data[0] if last_message_resp.data else {}

            unread_resp = await run_in_threadpool(
                lambda: db.client.table("chat_messages")
                .select("id", count="exact")
                .eq("conversation_id", conv["id"])
                .eq("receiver_id", user_id)
                .is_("read_at", "null")
                .execute()
            )

            previews.append(
                ConversationPreviewResponse(
                    conversation_id=conv["id"],
                    partner_id=partner_id,
                    partner_name=p.get("full_name") or p.get("username") or "TripBond User",
                    partner_avatar_url=p.get("avatar_url"),
                    last_message=m.get("content"),
                    last_message_at=m.get("created_at"),
                    unread_count=unread_resp.count or 0,
                )
            )

        previews.sort(key=lambda x: x.last_message_at or "", reverse=True)
        return previews
    except Exception:
        logger.exception("Failed to retrieve conversations")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve conversations",
        )


@router.get("/messages/{other_user_id}", response_model=List[ChatMessageResponse])
async def get_messages_with_user(
    other_user_id: str,
    limit: int = Query(default=100, ge=1, le=500),
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Get direct messages between current user and another user."""
    user_id, _token = user_context

    try:
        db = SupabaseDB(admin=True)
        conversation_id = await _find_conversation_id(db, user_id, other_user_id)
        if not conversation_id:
            return []

        response = await run_in_threadpool(
            lambda: db.client.table("chat_messages")
            .select("id,conversation_id,sender_id,receiver_id,content,created_at,read_at")
            .eq("conversation_id", conversation_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )

        rows = list(response.data or [])
        rows.reverse()

        return [
            ChatMessageResponse(
                id=r["id"],
                conversation_id=r["conversation_id"],
                sender_id=r["sender_id"],
                receiver_id=r["receiver_id"],
                content=r.get("content", ""),
                created_at=r.get("created_at", ""),
                read_at=r.get("read_at"),
            )
            for r in rows
        ]
    except Exception:
        logger.exception("Failed to retrieve messages")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve messages",
        )


@router.post("/messages/{other_user_id}", response_model=ChatMessageResponse)
async def send_message(
    other_user_id: str,
    request: SendMessageRequest,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Send a direct message to another user."""
    user_id, _token = user_context

    if other_user_id == user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot message yourself",
        )

    try:
        db = SupabaseDB(admin=True)

        target = await run_in_threadpool(
            lambda: db.client.table("profiles").select("id").eq("id", other_user_id).limit(1).execute()
        )
        if not target.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )

        conversation_id = await _find_conversation_id(db, user_id, other_user_id)
        if not conversation_id:
            low, high = _ordered_pair(user_id, other_user_id)
            created = await run_in_threadpool(
                lambda: db.client.table("chat_conversations")
                .insert({"user_1_id": low, "user_2_id": high})
                .execute()
            )
            if not created.data:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to create conversation",
                )
            conversation_id = created.data[0]["id"]

        inserted = await run_in_threadpool(
            lambda: db.client.table("chat_messages")
            .insert(
                {
                    "conversation_id": conversation_id,
                    "sender_id": user_id,
                    "receiver_id": other_user_id,
                    "content": request.content.strip(),
                }
            )
            .execute()
        )

        if not inserted.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to send message",
            )

        msg = inserted.data[0]
        return ChatMessageResponse(
            id=msg["id"],
            conversation_id=msg["conversation_id"],
            sender_id=msg["sender_id"],
            receiver_id=msg["receiver_id"],
            content=msg.get("content", ""),
            created_at=msg.get("created_at", ""),
            read_at=msg.get("read_at"),
        )
    except HTTPException:
        raise
    except Exception:
        logger.exception("Failed to send message")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send message",
        )


@router.post("/messages/{other_user_id}/read", response_model=MarkReadResponse)
async def mark_messages_as_read(
    other_user_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Mark all messages sent by other_user_id to current user as read."""
    user_id, _token = user_context

    try:
        db = SupabaseDB(admin=True)
        conversation_id = await _find_conversation_id(db, user_id, other_user_id)
        if not conversation_id:
            return MarkReadResponse(marked_count=0)

        to_mark = await run_in_threadpool(
            lambda: db.client.table("chat_messages")
            .select("id")
            .eq("conversation_id", conversation_id)
            .eq("sender_id", other_user_id)
            .eq("receiver_id", user_id)
            .is_("read_at", "null")
            .execute()
        )

        rows = to_mark.data or []
        if not rows:
            return MarkReadResponse(marked_count=0)

        ids = [row["id"] for row in rows]
        await run_in_threadpool(
            lambda: db.client.table("chat_messages")
            .update({"read_at": datetime.now(timezone.utc).isoformat()})
            .in_("id", ids)
            .execute()
        )

        return MarkReadResponse(marked_count=len(ids))
    except Exception:
        logger.exception("Failed to mark messages as read")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to mark messages as read",
        )
