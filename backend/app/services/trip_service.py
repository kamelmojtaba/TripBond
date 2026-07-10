"""
Trip Management Service

Handles trip CRUD operations, member management, and invite workflows.
"""
from fastapi import HTTPException, status
from fastapi.concurrency import run_in_threadpool
from typing import Optional, List
from datetime import datetime
from ..database import SupabaseDB
from . import notification_service
import logging

logger = logging.getLogger(__name__)


async def _are_friends(db: SupabaseDB, user_a: str, user_b: str) -> bool:
    """Return true when either direction has an accepted friendship row."""
    first = await run_in_threadpool(
        lambda: db.client.table("friends")
        .select("id")
        .eq("user_id", user_a)
        .eq("friend_id", user_b)
        .eq("status", "accepted")
        .limit(1)
        .execute()
    )
    if first.data:
        return True

    second = await run_in_threadpool(
        lambda: db.client.table("friends")
        .select("id")
        .eq("user_id", user_b)
        .eq("friend_id", user_a)
        .eq("status", "accepted")
        .limit(1)
        .execute()
    )
    return bool(second.data)


# ==================== Trip CRUD Operations ====================

async def get_user_trips(user_id: str, token: str) -> List[dict]:
    """Get all trips the user created or joined."""
    # Use admin client since we're using custom JWT (not Supabase Auth)
    db = SupabaseDB(admin=True)
    
    created_response = await run_in_threadpool(
        lambda: db.client.table("trips")
        .select("*")
        .eq("created_by", user_id)
        .order("created_at", desc=True)
        .execute()
    )

    trips: List[dict] = list(created_response.data or [])
    existing_ids = {trip["id"] for trip in trips}

    participant_response = await run_in_threadpool(
        lambda: db.client.table("trip_participants")
        .select("trip_id")
        .eq("user_id", user_id)
        .eq("status", "accepted")
        .execute()
    )

    for participant in participant_response.data or []:
        trip_id = participant.get("trip_id")
        if not trip_id or trip_id in existing_ids:
            continue
        trip_response = await run_in_threadpool(
            lambda trip_id=trip_id: db.client.table("trips")
            .select("*")
            .eq("id", trip_id)
            .execute()
        )
        if trip_response.data:
            trips.append(trip_response.data[0])
            existing_ids.add(trip_id)

    trips.sort(key=lambda trip: trip.get("created_at") or "", reverse=True)
    return trips


def get_user_trips_all(user_id: str) -> List[dict]:
    """
    Get all trips a user is involved in (created + participant).
    Returns deduplicated list using admin DB (no RLS).
    """
    db = SupabaseDB(admin=True)

    created = db.client.table("trips").select("*").eq(
        "created_by", user_id
    ).order("created_at", desc=True).execute()

    participant = db.client.table("trip_participants").select(
        "trip_id"
    ).eq("user_id", user_id).eq("status", "accepted").execute()

    all_trips: List[dict] = list(created.data or [])
    existing_ids = {t["id"] for t in all_trips}

    for pt in (participant.data or []):
        if pt["trip_id"] not in existing_ids:
            td = db.client.table("trips").select("*").eq("id", pt["trip_id"]).execute()
            if td.data:
                all_trips.append(td.data[0])
                existing_ids.add(pt["trip_id"])

    return all_trips


async def create_trip(user_id: str, token: str, trip_data: dict) -> dict:
    """Create a new trip."""
    # Use admin client since we're using custom JWT (not Supabase Auth)
    db = SupabaseDB(admin=True)
    
    # Add creator ID
    trip_data["created_by"] = user_id
    
    # Filter out None values
    trip_data = {k: v for k, v in trip_data.items() if v is not None}
    
    response = await run_in_threadpool(
        lambda: db.client.table("trips").insert(trip_data).execute()
    )
    
    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create trip"
        )
    
    return response.data[0]


async def update_trip(trip_id: str, token: str, update_data: dict) -> dict:
    """Update trip details."""
    db = SupabaseDB(admin=True)
    
    # Filter out None values
    update_data = {k: v for k, v in update_data.items() if v is not None}
    
    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields to update"
        )
    
    response = await run_in_threadpool(
        lambda: db.client.table("trips").update(update_data).eq("id", trip_id).execute()
    )
    
    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update trip"
        )
    
    return response.data[0]


async def delete_trip(trip_id: str, token: str) -> None:
    """Delete trip (cascade will delete related data)."""
    db = SupabaseDB(admin=True)
    
    await run_in_threadpool(
        lambda: db.client.table("trips").delete().eq("id", trip_id).execute()
    )


# ==================== Member Management ====================

async def get_trip_members(trip_id: str, token: str, status_filter: Optional[str] = "accepted") -> List[dict]:
    """Get trip members by status."""
    db = SupabaseDB(admin=True)
    
    query = db.client.table("trip_participants").select("*").eq("trip_id", trip_id)
    
    if status_filter:
        query = query.eq("status", status_filter)
    
    response = await run_in_threadpool(lambda: query.execute())
    
    return response.data if response.data else []


async def get_trip_member_count(trip_id: str, token: str) -> int:
    """Count accepted trip members."""
    db = SupabaseDB(admin=True)
    
    response = await run_in_threadpool(
        lambda: db.client.table("trip_participants")
        .select("user_id", count="exact")
        .eq("trip_id", trip_id)
        .eq("status", "accepted")
        .execute()
    )
    
    return response.count if response.count else 0


async def invite_member(trip_id: str, inviter_id: str, invitee_id: str, token: str) -> dict:
    """Invite a member to trip."""
    db = SupabaseDB(admin=True)
    
    if invitee_id == inviter_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Creator cannot invite themselves"
        )

    if not await _are_friends(db, inviter_id, invitee_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only invite friends to a trip"
        )
    
    # Check if already exists
    existing = await run_in_threadpool(
        lambda: db.client.table("trip_participants")
        .select("status")
        .eq("trip_id", trip_id)
        .eq("user_id", invitee_id)
        .execute()
    )
    
    if existing.data:
        status_val = existing.data[0].get("status")
        if status_val == "accepted":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User is already a member of this trip"
            )
        if status_val == "pending":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User already has a pending invite"
            )
    
    # Create invite
    payload = {
        "trip_id": trip_id,
        "user_id": invitee_id,
        "status": "pending",
        "invited_by": inviter_id,
        "invited_at": datetime.now().isoformat(),
        "responded_at": None,
        "joined_at": None
    }
    
    response = await run_in_threadpool(
        lambda: db.client.table("trip_participants")
        .upsert(payload, on_conflict="trip_id,user_id")
        .execute()
    )

    # Notify invitee
    try:
        admin = SupabaseDB(admin=True)
        trip = admin.client.table("trips").select("title").eq("id", trip_id).execute()
        trip_title = trip.data[0]["title"] if trip.data else "a trip"
        notification_service.emit(
            user_id=invitee_id,
            notif_type="trip_invite",
            title="You've been invited",
            body=f"You have a new invite to '{trip_title}'.",
            payload={"trip_id": trip_id, "invited_by": inviter_id},
        )
    except Exception:
        logger.exception("Failed to notify invitee of trip invite")

    return response.data[0]


async def accept_invite(trip_id: str, user_id: str, token: str) -> dict:
    """Accept a pending trip invite."""
    db = SupabaseDB(admin=True)
    
    # Check invite exists
    existing = await run_in_threadpool(
        lambda: db.client.table("trip_participants")
        .select("*")
        .eq("trip_id", trip_id)
        .eq("user_id", user_id)
        .execute()
    )
    
    if not existing.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No invite found for this trip"
        )
    
    row = existing.data[0]
    
    if row.get("status") != "pending":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invite is already {row.get('status')}"
        )
    
    # Accept invite
    now = datetime.now().isoformat()
    update_data = {
        "status": "accepted",
        "responded_at": now,
        "joined_at": now
    }
    
    response = await run_in_threadpool(
        lambda: db.client.table("trip_participants")
        .update(update_data)
        .eq("trip_id", trip_id)
        .eq("user_id", user_id)
        .execute()
    )

    # Notify trip creator that someone accepted
    try:
        admin = SupabaseDB(admin=True)
        trip = admin.client.table("trips").select("created_by, title").eq("id", trip_id).execute()
        if trip.data:
            notification_service.emit(
                user_id=trip.data[0]["created_by"],
                notif_type="trip_invite_accepted",
                title="Invite accepted",
                body=f"Someone joined '{trip.data[0]['title']}'.",
                payload={"trip_id": trip_id, "user_id": user_id},
            )
    except Exception:
        logger.exception("Failed to notify creator of accepted invite")

    return response.data[0]


async def decline_invite(trip_id: str, user_id: str, token: str) -> None:
    """Decline a pending trip invite."""
    db = SupabaseDB(admin=True)
    
    # Check invite exists
    existing = await run_in_threadpool(
        lambda: db.client.table("trip_participants")
        .select("*")
        .eq("trip_id", trip_id)
        .eq("user_id", user_id)
        .execute()
    )
    
    if not existing.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No invite found for this trip"
        )
    
    row = existing.data[0]
    
    if row.get("status") != "pending":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invite is already {row.get('status')}"
        )
    
    # Decline invite
    update_data = {
        "status": "declined",
        "responded_at": datetime.now().isoformat(),
        "joined_at": None
    }
    
    await run_in_threadpool(
        lambda: db.client.table("trip_participants")
        .update(update_data)
        .eq("trip_id", trip_id)
        .eq("user_id", user_id)
        .execute()
    )


async def leave_trip(trip_id: str, user_id: str, token: str) -> None:
    """Leave a trip (members only, not creator)."""
    db = SupabaseDB(admin=True)
    
    # Check if user is creator
    trip_response = await run_in_threadpool(
        lambda: db.client.table("trips").select("*").eq("id", trip_id).execute()
    )
    
    if not trip_response.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trip not found"
        )
    
    trip = trip_response.data[0]
    
    if trip["created_by"] == user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Trip creator cannot leave. Delete the trip instead."
        )
    
    # Check membership
    existing = await run_in_threadpool(
        lambda: db.client.table("trip_participants")
        .select("*")
        .eq("trip_id", trip_id)
        .eq("user_id", user_id)
        .execute()
    )
    
    if not existing.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="You are not a member of this trip"
        )
    
    if existing.data[0].get("status") != "accepted":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You are not an accepted member of this trip"
        )
    
    # Mark as left
    update_data = {
        "status": "left",
        "responded_at": datetime.now().isoformat(),
        "joined_at": None
    }
    
    await run_in_threadpool(
        lambda: db.client.table("trip_participants")
        .update(update_data)
        .eq("trip_id", trip_id)
        .eq("user_id", user_id)
        .execute()
    )


async def remove_member(trip_id: str, user_id_to_remove: str, token: str) -> None:
    """Remove a member or cancel invite (creator only)."""
    db = SupabaseDB(admin=True)
    
    # Check if member exists
    existing = await run_in_threadpool(
        lambda: db.client.table("trip_participants")
        .select("*")
        .eq("trip_id", trip_id)
        .eq("user_id", user_id_to_remove)
        .execute()
    )
    
    if not existing.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found in this trip (no membership or invite)"
        )
    
    # Check if trying to remove creator
    trip_response = await run_in_threadpool(
        lambda: db.client.table("trips").select("created_by").eq("id", trip_id).execute()
    )
    
    if trip_response.data and trip_response.data[0].get("created_by") == user_id_to_remove:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot remove trip creator"
        )
    
    # Mark as removed
    update_data = {
        "status": "removed",
        "responded_at": datetime.now().isoformat(),
        "joined_at": None
    }
    
    await run_in_threadpool(
        lambda: db.client.table("trip_participants")
        .update(update_data)
        .eq("trip_id", trip_id)
        .eq("user_id", user_id_to_remove)
        .execute()
    )


# ==================== Invite Listing ====================

async def get_user_pending_invites(user_id: str, token: str) -> List[dict]:
    """Get all pending invites for a user with trip details."""
    db = SupabaseDB(admin=True)
    
    # Get pending invites
    response = await run_in_threadpool(
        lambda: db.client.table("trip_participants")
        .select("trip_id, status, invited_by, invited_at")
        .eq("user_id", user_id)
        .eq("status", "pending")
        .execute()
    )
    
    if not response.data:
        return []
    
    # Fetch trip details for each invite
    invites = []
    
    for invite in response.data:
        trip_response = await run_in_threadpool(
            lambda trip_id=invite["trip_id"]: db.client.table("trips")
            .select("*")
            .eq("id", trip_id)
            .execute()
        )
        
        if trip_response.data:
            trip = trip_response.data[0]
            invites.append({
                "trip_id": invite["trip_id"],
                "trip_title": trip.get("title", ""),
                "trip_destination": trip.get("destination", ""),
                "trip_start_date": trip.get("start_date"),
                "trip_end_date": trip.get("end_date"),
                "trip_image_url": trip.get("image_url"),
                "invited_by": invite.get("invited_by"),
                "invited_at": invite.get("invited_at"),
                "status": invite.get("status")
            })
    
    return invites
