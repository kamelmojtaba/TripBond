from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List

from fastapi import HTTPException, status
from postgrest.exceptions import APIError

from ..database import get_supabase_admin_client


def _client():
    return get_supabase_admin_client()


def _now() -> str:
    return datetime.utcnow().isoformat()


def _phase(trip: Dict[str, Any]) -> str:
    return str(trip.get("phase") or "planning")


def _is_missing_progress_table(exc: APIError) -> bool:
    text = str(exc)
    return "PGRST205" in text and "trip_member_progress" in text


def _raise_missing_progress_table() -> None:
    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail=(
            "Trip flow progress table is missing. Apply "
            "backend/add_trip_flow_progress.sql to Supabase and restart the API."
        ),
    )


def _member_ids_for_trip(trip: Dict[str, Any]) -> List[str]:
    client = _client()
    members = (
        client.table("trip_participants")
        .select("user_id")
        .eq("trip_id", trip["id"])
        .eq("status", "accepted")
        .execute()
    )
    ids = [row["user_id"] for row in (members.data or []) if row.get("user_id")]
    creator_id = trip.get("created_by")
    if creator_id and creator_id not in ids:
        ids.insert(0, creator_id)
    return ids


def _profiles_by_id(user_ids: List[str]) -> Dict[str, Dict[str, Any]]:
    if not user_ids:
        return {}
    profiles = (
        _client()
        .table("profiles")
        .select("id, full_name, username, avatar_url")
        .in_("id", user_ids)
        .execute()
    )
    return {row["id"]: row for row in (profiles.data or [])}


def _progress_by_user(trip_id: str, user_ids: List[str]) -> Dict[str, Dict[str, Any]]:
    if not user_ids:
        return {}
    try:
        progress = (
            _client()
            .table("trip_member_progress")
            .select("*")
            .eq("trip_id", trip_id)
            .in_("user_id", user_ids)
            .execute()
        )
    except APIError as exc:
        if _is_missing_progress_table(exc):
            _raise_missing_progress_table()
        raise
    return {row["user_id"]: row for row in (progress.data or [])}


def _place_counts_by_user(trip_id: str) -> tuple[Dict[str, int], int]:
    places = (
        _client()
        .table("trip_places")
        .select("id, added_by")
        .eq("trip_id", trip_id)
        .execute()
    )
    counts: Dict[str, int] = {}
    for row in places.data or []:
        user_id = row.get("added_by")
        if user_id:
            counts[user_id] = counts.get(user_id, 0) + 1
    return counts, len(places.data or [])


def _vote_counts(trip_id: str) -> tuple[Dict[str, int], int]:
    places = (
        _client()
        .table("trip_places")
        .select("id")
        .eq("trip_id", trip_id)
        .execute()
    )
    place_ids = [row["id"] for row in (places.data or [])]
    if not place_ids:
        return {}, 0
    votes = (
        _client()
        .table("place_votes")
        .select("user_id")
        .in_("trip_place_id", place_ids)
        .execute()
    )
    counts: Dict[str, int] = {}
    for row in votes.data or []:
        user_id = row.get("user_id")
        if user_id:
            counts[user_id] = counts.get(user_id, 0) + 1
    return counts, len(votes.data or [])


def _pending_invite_count(trip_id: str) -> int:
    res = (
        _client()
        .table("trip_participants")
        .select("user_id", count="exact")
        .eq("trip_id", trip_id)
        .eq("status", "pending")
        .execute()
    )
    return int(res.count or 0)


def _has_itinerary(trip_id: str) -> bool:
    res = (
        _client()
        .table("itineraries")
        .select("id")
        .eq("trip_id", trip_id)
        .limit(1)
        .execute()
    )
    return bool(res.data)


def get_trip_flow_status(trip: Dict[str, Any], current_user_id: str) -> Dict[str, Any]:
    trip_id = trip["id"]
    phase = _phase(trip)
    user_ids = _member_ids_for_trip(trip)
    profiles = _profiles_by_id(user_ids)
    progress = _progress_by_user(trip_id, user_ids)
    place_counts, total_places = _place_counts_by_user(trip_id)
    vote_counts, total_votes = _vote_counts(trip_id)

    members = []
    for user_id in user_ids:
        profile = profiles.get(user_id, {})
        row = progress.get(user_id, {})
        places_done_at = row.get("places_completed_at")
        voting_done_at = row.get("voting_completed_at")
        members.append(
            {
                "user_id": user_id,
                "is_creator": user_id == trip.get("created_by"),
                "full_name": profile.get("full_name") or profile.get("username") or "Member",
                "avatar_url": profile.get("avatar_url"),
                "places_count": place_counts.get(user_id, 0),
                "votes_count": vote_counts.get(user_id, 0),
                "places_completed": places_done_at is not None,
                "places_completed_at": places_done_at,
                "voting_completed": voting_done_at is not None,
                "voting_completed_at": voting_done_at,
            }
        )

    all_places_completed = bool(members) and all(member["places_completed"] for member in members)
    all_voting_completed = bool(members) and all(member["voting_completed"] for member in members)
    is_creator = trip.get("created_by") == current_user_id
    my_progress = progress.get(current_user_id, {})

    has_itinerary = _has_itinerary(trip_id)

    return {
        "trip": {
            "id": trip_id,
            "title": trip.get("title", ""),
            "destination": trip.get("destination", ""),
            "phase": phase,
            "created_by": trip.get("created_by"),
            "start_date": trip.get("start_date"),
            "end_date": trip.get("end_date"),
            "is_public": trip.get("is_public", True),
        },
        "phase": phase,
        "is_creator": is_creator,
        "members": members,
        "member_count": len(members),
        "pending_invites_count": _pending_invite_count(trip_id),
        "places_count": total_places,
        "votes_count": total_votes,
        "my_places_count": place_counts.get(current_user_id, 0),
        "my_votes_count": vote_counts.get(current_user_id, 0),
        "my_places_completed": my_progress.get("places_completed_at") is not None,
        "my_voting_completed": my_progress.get("voting_completed_at") is not None,
        "all_places_completed": all_places_completed,
        "all_voting_completed": all_voting_completed,
        "has_itinerary": has_itinerary,
        "can_open_voting": is_creator and phase == "planning" and total_places > 0 and all_places_completed,
        "can_close_voting": is_creator and phase == "voting" and all_voting_completed,
        "can_generate_plan": is_creator and phase == "finalized" and not has_itinerary,
    }


def mark_progress(trip_id: str, user_id: str, field: str) -> Dict[str, Any]:
    if field not in {"places_completed_at", "voting_completed_at"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid progress field")

    now = _now()
    payload = {
        "trip_id": trip_id,
        "user_id": user_id,
        field: now,
        "updated_at": now,
    }
    try:
        res = (
            _client()
            .table("trip_member_progress")
            .upsert(payload, on_conflict="trip_id,user_id")
            .execute()
        )
    except APIError as exc:
        if _is_missing_progress_table(exc):
            _raise_missing_progress_table()
        raise
    if not res.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update trip progress",
        )
    return res.data[0]


def clear_progress(trip_id: str, user_id: str, field: str) -> Dict[str, Any]:
    if field not in {"places_completed_at", "voting_completed_at"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid progress field")
    try:
        res = (
            _client()
            .table("trip_member_progress")
            .update({field: None, "updated_at": _now()})
            .eq("trip_id", trip_id)
            .eq("user_id", user_id)
            .execute()
        )
    except APIError as exc:
        if _is_missing_progress_table(exc):
            _raise_missing_progress_table()
        raise
    return res.data[0] if res.data else {}


def assert_can_open_voting(trip: Dict[str, Any]) -> None:
    status_data = get_trip_flow_status(trip, trip.get("created_by"))
    if status_data["phase"] != "planning":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Trip is not in planning.")
    if status_data["places_count"] == 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Add at least one place before starting voting.")
    if not status_data["all_places_completed"]:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Wait for all members to mark places complete.")


def assert_can_close_voting(trip: Dict[str, Any]) -> None:
    status_data = get_trip_flow_status(trip, trip.get("created_by"))
    if status_data["phase"] != "voting":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Voting is not open.")
    if not status_data["all_voting_completed"]:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Wait for all members to finish voting.")
