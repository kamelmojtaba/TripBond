"""
Notification Service

Helpers for emitting in-app notifications. Inserts use the admin client
so they bypass RLS; the table's RLS policies still restrict reads to the
notification owner.
"""
from __future__ import annotations

from typing import Iterable, Optional, List, Dict, Any
import logging

from ..database import get_supabase_admin_client

logger = logging.getLogger(__name__)


def emit(
    user_id: str,
    notif_type: str,
    title: Optional[str] = None,
    body: Optional[str] = None,
    payload: Optional[Dict[str, Any]] = None,
) -> Optional[str]:
    """Insert a single notification. Returns the notification id (or None on failure)."""
    if not user_id:
        return None
    try:
        client = get_supabase_admin_client()
        record = {
            "user_id": user_id,
            "type": notif_type,
            "title": title,
            "body": body,
            "payload": payload or {},
        }
        result = client.table("notifications").insert(record).execute()
        if result.data:
            return result.data[0]["id"]
    except Exception as exc:
        logger.warning("Failed to emit notification (%s -> %s): %s", notif_type, user_id, exc)
    return None


def emit_many(
    user_ids: Iterable[str],
    notif_type: str,
    title: Optional[str] = None,
    body: Optional[str] = None,
    payload: Optional[Dict[str, Any]] = None,
) -> int:
    """Insert one notification per user_id. Returns count inserted."""
    user_ids = [u for u in user_ids if u]
    if not user_ids:
        return 0
    try:
        client = get_supabase_admin_client()
        records = [
            {
                "user_id": uid,
                "type": notif_type,
                "title": title,
                "body": body,
                "payload": payload or {},
            }
            for uid in user_ids
        ]
        result = client.table("notifications").insert(records).execute()
        return len(result.data or [])
    except Exception as exc:
        logger.warning("Failed to emit batch notifications (%s): %s", notif_type, exc)
        return 0


def list_for_user(user_id: str, limit: int = 50, only_unread: bool = False) -> List[Dict[str, Any]]:
    client = get_supabase_admin_client()
    query = client.table("notifications").select("*").eq("user_id", user_id)
    if only_unread:
        query = query.is_("read_at", "null")
    result = query.order("created_at", desc=True).limit(limit).execute()
    return result.data or []


def mark_read(user_id: str, notification_id: str) -> bool:
    client = get_supabase_admin_client()
    result = (
        client.table("notifications")
        .update({"read_at": "now()"})
        .eq("id", notification_id)
        .eq("user_id", user_id)
        .execute()
    )
    return bool(result.data)


def mark_all_read(user_id: str) -> int:
    client = get_supabase_admin_client()
    result = (
        client.table("notifications")
        .update({"read_at": "now()"})
        .eq("user_id", user_id)
        .is_("read_at", "null")
        .execute()
    )
    return len(result.data or [])


def unread_count(user_id: str) -> int:
    client = get_supabase_admin_client()
    result = (
        client.table("notifications")
        .select("id", count="exact")
        .eq("user_id", user_id)
        .is_("read_at", "null")
        .execute()
    )
    return result.count or 0
