"""
Social feed endpoints (minimal):
  - GET /api/feed                                 -> public trips with likes/member counts
  - POST /api/feed/trips/{trip_id}/like           -> like a public trip
  - DELETE /api/feed/trips/{trip_id}/like         -> retract like
  - POST /api/feed/trips/{trip_id}/join-requests  -> ask to join a public trip
  - GET /api/feed/trips/{trip_id}/join-requests   -> creator views requests
  - POST /api/feed/trips/{trip_id}/join-requests/{request_id}/approve|reject
"""
from fastapi import APIRouter, Body, Depends, HTTPException, Query, status
from fastapi.concurrency import run_in_threadpool
from typing import List, Dict, Any, Optional
from datetime import date, datetime

from ..auth import get_current_user_context
from ..database import SupabaseDB
from ..services import notification_service
from ..services.trip_access import check_trip_access

router = APIRouter()


def _is_public_trip(trip: Dict[str, Any]) -> bool:
    value = trip.get("is_public")
    if value is None:
        return True
    if isinstance(value, str):
        return value.strip().lower() not in {"false", "0", "no", "private"}
    return bool(value)


def _parse_trip_date(value: Any) -> Optional[date]:
    if not value:
        return None
    try:
        if isinstance(value, datetime):
            return value.date()
        if isinstance(value, date):
            return value
        return datetime.fromisoformat(str(value).split("T")[0]).date()
    except ValueError:
        return None


def _can_request_join(trip: Dict[str, Any]) -> bool:
    """Join requests are only allowed before the trip start date."""
    start = _parse_trip_date(trip.get("start_date"))
    if start is None:
        return False
    return start > date.today()


def _profile_lookup(profile_ids: List[str]) -> Dict[str, Dict[str, Any]]:
    if not profile_ids:
        return {}
    db = SupabaseDB(admin=True)
    res = (
        db.client.table("profiles")
        .select("id, full_name, username, avatar_url")
        .in_("id", profile_ids)
        .execute()
    )
    return {p["id"]: p for p in (res.data or [])}


# ==================== Feed listing ====================


@router.get("/", response_model=List[Dict[str, Any]])
async def get_feed(
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Public-trips feed enriched with creator profile, likes count, has_liked, member count."""
    user_id, _ = user_context
    db = SupabaseDB(admin=True)

    trips_res = await run_in_threadpool(
        lambda: db.client.table("trips")
        .select("*")
        .eq("is_public", True)
        .order("created_at", desc=True)
        .range(offset, offset + limit - 1)
        .execute()
    )
    trips = trips_res.data or []
    if not trips:
        return []

    creator_ids = list({t["created_by"] for t in trips if t.get("created_by")})
    profiles = _profile_lookup(creator_ids)

    trip_ids = [t["id"] for t in trips]

    likes_res = await run_in_threadpool(
        lambda: db.client.table("trip_post_likes")
        .select("trip_id, user_id")
        .in_("trip_id", trip_ids)
        .execute()
    )
    likes_by_trip: Dict[str, List[str]] = {tid: [] for tid in trip_ids}
    for row in (likes_res.data or []):
        likes_by_trip.setdefault(row["trip_id"], []).append(row["user_id"])

    members_res = await run_in_threadpool(
        lambda: db.client.table("trip_participants")
        .select("trip_id, user_id, status")
        .in_("trip_id", trip_ids)
        .eq("status", "accepted")
        .execute()
    )
    members_by_trip: Dict[str, int] = {tid: 0 for tid in trip_ids}
    member_ids_by_trip: Dict[str, set[str]] = {tid: set() for tid in trip_ids}
    for row in (members_res.data or []):
        members_by_trip[row["trip_id"]] = members_by_trip.get(row["trip_id"], 0) + 1
        member_ids_by_trip.setdefault(row["trip_id"], set()).add(row["user_id"])

    pending_res = await run_in_threadpool(
        lambda: db.client.table("trip_join_requests")
        .select("trip_id")
        .in_("trip_id", trip_ids)
        .eq("user_id", user_id)
        .eq("status", "pending")
        .execute()
    )
    pending_join_trip_ids = {
        row["trip_id"] for row in (pending_res.data or []) if row.get("trip_id")
    }

    out: List[Dict[str, Any]] = []
    for trip in trips:
        liker_ids = likes_by_trip.get(trip["id"], [])
        creator = profiles.get(trip.get("created_by") or "", {})
        out.append(
            {
                "id": trip["id"],
                "title": trip.get("title"),
                "destination": trip.get("destination"),
                "image_url": trip.get("image_url"),
                "description": trip.get("description"),
                "start_date": trip.get("start_date"),
                "end_date": trip.get("end_date"),
                "phase": trip.get("phase") or "planning",
                "created_at": trip.get("created_at"),
                "creator": {
                    "id": creator.get("id"),
                    "full_name": creator.get("full_name"),
                    "username": creator.get("username"),
                    "avatar_url": creator.get("avatar_url"),
                },
                "likes_count": len(liker_ids),
                "has_liked": user_id in liker_ids,
                "member_count": members_by_trip.get(trip["id"], 0) + 1,  # +1 for creator
                "is_creator": trip.get("created_by") == user_id,
                "is_member": user_id in member_ids_by_trip.get(trip["id"], set()),
                "has_pending_join_request": trip["id"] in pending_join_trip_ids,
                "can_request_join": _can_request_join(trip),
            }
        )
    return out


# ==================== Likes ====================


@router.get("/me/liked-trips", response_model=List[Dict[str, Any]])
async def get_my_liked_trips(
    limit: int = Query(100, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Trips liked by the current user, shaped like feed cards for profile rendering."""
    user_id, _ = user_context
    db = SupabaseDB(admin=True)

    liked_res = await run_in_threadpool(
        lambda: db.client.table("trip_post_likes")
        .select("trip_id")
        .eq("user_id", user_id)
        .range(offset, offset + limit - 1)
        .execute()
    )
    liked_trip_ids = [
        row["trip_id"] for row in (liked_res.data or []) if row.get("trip_id")
    ]
    if not liked_trip_ids:
        return []

    trips_res = await run_in_threadpool(
        lambda: db.client.table("trips")
        .select("*")
        .in_("id", liked_trip_ids)
        .execute()
    )
    trip_by_id = {trip["id"]: trip for trip in (trips_res.data or [])}
    trips = [
        trip_by_id[trip_id]
        for trip_id in liked_trip_ids
        if trip_id in trip_by_id and _is_public_trip(trip_by_id[trip_id])
    ]
    if not trips:
        return []

    creator_ids = list({t["created_by"] for t in trips if t.get("created_by")})
    profiles = _profile_lookup(creator_ids)
    trip_ids = [t["id"] for t in trips]

    likes_res = await run_in_threadpool(
        lambda: db.client.table("trip_post_likes")
        .select("trip_id, user_id")
        .in_("trip_id", trip_ids)
        .execute()
    )
    likes_by_trip: Dict[str, List[str]] = {tid: [] for tid in trip_ids}
    for row in (likes_res.data or []):
        likes_by_trip.setdefault(row["trip_id"], []).append(row["user_id"])

    members_res = await run_in_threadpool(
        lambda: db.client.table("trip_participants")
        .select("trip_id, user_id, status")
        .in_("trip_id", trip_ids)
        .eq("status", "accepted")
        .execute()
    )
    members_by_trip: Dict[str, int] = {tid: 0 for tid in trip_ids}
    member_ids_by_trip: Dict[str, set[str]] = {tid: set() for tid in trip_ids}
    for row in (members_res.data or []):
        members_by_trip[row["trip_id"]] = members_by_trip.get(row["trip_id"], 0) + 1
        member_ids_by_trip.setdefault(row["trip_id"], set()).add(row["user_id"])

    out: List[Dict[str, Any]] = []
    for trip in trips:
        creator = profiles.get(trip.get("created_by") or "", {})
        out.append({
            "id": trip["id"],
            "title": trip.get("title"),
            "destination": trip.get("destination"),
            "image_url": trip.get("image_url"),
            "description": trip.get("description"),
            "start_date": trip.get("start_date"),
            "end_date": trip.get("end_date"),
            "phase": trip.get("phase") or "planning",
            "created_at": trip.get("created_at"),
            "creator": {
                "id": creator.get("id"),
                "full_name": creator.get("full_name"),
                "username": creator.get("username"),
                "avatar_url": creator.get("avatar_url"),
            },
            "likes_count": len(likes_by_trip.get(trip["id"], [])),
            "has_liked": True,
            "member_count": members_by_trip.get(trip["id"], 0) + 1,
            "is_creator": trip.get("created_by") == user_id,
            "is_member": user_id in member_ids_by_trip.get(trip["id"], set()),
        })
    return out


@router.post("/trips/{trip_id}/like")
async def like_trip(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    user_id, _ = user_context
    db = SupabaseDB(admin=True)

    trip = await run_in_threadpool(
        lambda: db.client.table("trips").select("id, created_by, title, is_public").eq("id", trip_id).execute()
    )
    if not trip.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found")
    trip_row = trip.data[0]
    if not _is_public_trip(trip_row) and trip_row["created_by"] != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Trip is private")

    record = {"trip_id": trip_id, "user_id": user_id}
    try:
        await run_in_threadpool(
            lambda: db.client.table("trip_post_likes").upsert(record, on_conflict="trip_id,user_id").execute()
        )
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to like: {exc}")

    if trip_row.get("created_by") and trip_row["created_by"] != user_id:
        notification_service.emit(
            user_id=trip_row["created_by"],
            notif_type="trip_liked",
            title="Someone liked your trip",
            body=f"Your trip '{trip_row.get('title','')}' got a new like.",
            payload={"trip_id": trip_id, "by": user_id},
        )
    return {"liked": True}


@router.delete("/trips/{trip_id}/like")
async def unlike_trip(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    user_id, _ = user_context
    db = SupabaseDB(admin=True)
    await run_in_threadpool(
        lambda: db.client.table("trip_post_likes")
        .delete()
        .eq("trip_id", trip_id)
        .eq("user_id", user_id)
        .execute()
    )
    return {"liked": False}


# ==================== Join requests ====================


@router.post("/trips/{trip_id}/join-requests")
async def request_to_join(
    trip_id: str,
    body: Optional[dict] = Body(None),
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    user_id, _ = user_context
    db = SupabaseDB(admin=True)

    trip = await run_in_threadpool(
        lambda: db.client.table("trips")
        .select("id, created_by, title, is_public, start_date")
        .eq("id", trip_id)
        .execute()
    )
    if not trip.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found")
    trip_row = trip.data[0]
    if not _is_public_trip(trip_row):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Trip is private")
    if not _can_request_join(trip_row):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Join requests are only allowed for future trips before the start date",
        )
    if trip_row["created_by"] == user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="You are the creator")

    existing_member = await run_in_threadpool(
        lambda: db.client.table("trip_participants").select("status").eq("trip_id", trip_id).eq("user_id", user_id).execute()
    )
    if existing_member.data and existing_member.data[0].get("status") == "accepted":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Already a member")

    existing = await run_in_threadpool(
        lambda: db.client.table("trip_join_requests")
        .select("id, status")
        .eq("trip_id", trip_id)
        .eq("user_id", user_id)
        .eq("status", "pending")
        .execute()
    )
    if existing.data:
        return {"already_pending": True, "id": existing.data[0]["id"]}

    record = {
        "trip_id": trip_id,
        "user_id": user_id,
        "status": "pending",
        "message": (body or {}).get("message"),
    }
    res = await run_in_threadpool(
        lambda: db.client.table("trip_join_requests").insert(record).execute()
    )
    if not res.data:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to create request")

    notification_service.emit(
        user_id=trip_row["created_by"],
        notif_type="trip_join_request",
        title="New join request",
        body=f"Someone wants to join '{trip_row.get('title','')}'.",
        payload={"trip_id": trip_id, "request_id": res.data[0]["id"], "from": user_id},
    )
    return {"created": True, "id": res.data[0]["id"]}


@router.get("/trips/{trip_id}/join-requests")
async def list_join_requests(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    user_id, token = user_context
    await check_trip_access(trip_id, user_id, token=token, required_role="creator")
    db = SupabaseDB(admin=True)
    res = await run_in_threadpool(
        lambda: db.client.table("trip_join_requests")
        .select("*")
        .eq("trip_id", trip_id)
        .order("requested_at", desc=True)
        .execute()
    )
    rows = res.data or []
    if not rows:
        return []
    profile_ids = [r["user_id"] for r in rows]
    profiles = _profile_lookup(profile_ids)
    return [
        {
            **r,
            "user": profiles.get(r["user_id"], {}),
        }
        for r in rows
    ]


@router.post("/trips/{trip_id}/join-requests/{request_id}/approve")
async def approve_join_request(
    trip_id: str,
    request_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    user_id, token = user_context
    await check_trip_access(trip_id, user_id, token=token, required_role="creator")
    db = SupabaseDB(admin=True)

    req = await run_in_threadpool(
        lambda: db.client.table("trip_join_requests").select("*").eq("id", request_id).eq("trip_id", trip_id).execute()
    )
    if not req.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Request not found")
    request_row = req.data[0]
    if request_row["status"] != "pending":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Request is {request_row['status']}")

    now_iso = datetime.utcnow().isoformat()
    await run_in_threadpool(
        lambda: db.client.table("trip_join_requests")
        .update({"status": "approved", "responded_at": now_iso, "responded_by": user_id})
        .eq("id", request_id)
        .execute()
    )

    # Create / update participant row to accepted.
    participant_payload = {
        "trip_id": trip_id,
        "user_id": request_row["user_id"],
        "status": "accepted",
        "invited_by": user_id,
        "invited_at": now_iso,
        "responded_at": now_iso,
        "joined_at": now_iso,
    }
    await run_in_threadpool(
        lambda: db.client.table("trip_participants")
        .upsert(participant_payload, on_conflict="trip_id,user_id")
        .execute()
    )

    notification_service.emit(
        user_id=request_row["user_id"],
        notif_type="join_request_approved",
        title="Request approved",
        body="You were approved to join the trip.",
        payload={"trip_id": trip_id, "request_id": request_id},
    )
    return {"approved": True}


@router.post("/trips/{trip_id}/join-requests/{request_id}/reject")
async def reject_join_request(
    trip_id: str,
    request_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    user_id, token = user_context
    await check_trip_access(trip_id, user_id, token=token, required_role="creator")
    db = SupabaseDB(admin=True)

    req = await run_in_threadpool(
        lambda: db.client.table("trip_join_requests").select("*").eq("id", request_id).eq("trip_id", trip_id).execute()
    )
    if not req.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Request not found")
    request_row = req.data[0]
    if request_row["status"] != "pending":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Request is {request_row['status']}")

    await run_in_threadpool(
        lambda: db.client.table("trip_join_requests")
        .update({
            "status": "rejected",
            "responded_at": datetime.utcnow().isoformat(),
            "responded_by": user_id,
        })
        .eq("id", request_id)
        .execute()
    )
    notification_service.emit(
        user_id=request_row["user_id"],
        notif_type="join_request_rejected",
        title="Request declined",
        body="Your request to join the trip was declined.",
        payload={"trip_id": trip_id, "request_id": request_id},
    )
    return {"rejected": True}
