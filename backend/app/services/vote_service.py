"""
Vote Service

Handles the place_votes table for the trip planning voting flow.
"""
from __future__ import annotations

from datetime import datetime
from typing import Optional, Dict, Any, List

from fastapi import HTTPException, status

from ..database import get_supabase_admin_client


def _client():
    return get_supabase_admin_client()


def _get_trip_place(trip_place_id: str) -> Optional[Dict[str, Any]]:
    res = _client().table("trip_places").select("id, trip_id, added_by, name").eq("id", trip_place_id).execute()
    return res.data[0] if res.data else None


def upsert_vote(trip_place_id: str, user_id: str, value: int) -> Dict[str, Any]:
    """Cast or update a vote (1..5). Voter cannot vote on a place they themselves added."""
    if value < 1 or value > 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vote value must be between 1 and 5",
        )

    place = _get_trip_place(trip_place_id)
    if not place:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Place not found")
    if place.get("added_by") == user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You can't vote on your own place",
        )

    payload = {
        "trip_place_id": trip_place_id,
        "user_id": user_id,
        "value": int(value),
        "updated_at": datetime.utcnow().isoformat(),
    }
    res = (
        _client()
        .table("place_votes")
        .upsert(payload, on_conflict="trip_place_id,user_id")
        .execute()
    )
    if not res.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to record vote",
        )
    return res.data[0]


def retract_vote(trip_place_id: str, user_id: str) -> bool:
    res = (
        _client()
        .table("place_votes")
        .delete()
        .eq("trip_place_id", trip_place_id)
        .eq("user_id", user_id)
        .execute()
    )
    return bool(res.data)


def list_trip_votes(trip_id: str, user_id: str) -> List[Dict[str, Any]]:
    """Return one record per trip_place_id with aggregated stats and the requester's vote."""
    client = _client()
    places = (
        client.table("trip_places")
        .select("id, name, added_by")
        .eq("trip_id", trip_id)
        .execute()
    )
    place_ids = [p["id"] for p in (places.data or [])]
    if not place_ids:
        return []

    votes = (
        client.table("place_votes")
        .select("trip_place_id, user_id, value")
        .in_("trip_place_id", place_ids)
        .execute()
    )

    by_place: Dict[str, List[Dict[str, Any]]] = {pid: [] for pid in place_ids}
    for v in (votes.data or []):
        by_place[v["trip_place_id"]].append(v)

    out: List[Dict[str, Any]] = []
    for p in (places.data or []):
        rows = by_place.get(p["id"], [])
        count = len(rows)
        avg = sum(r["value"] for r in rows) / count if count else 0.0
        my = next((r["value"] for r in rows if r["user_id"] == user_id), None)
        out.append(
            {
                "trip_place_id": p["id"],
                "name": p["name"],
                "added_by": p.get("added_by"),
                "votes_count": count,
                "avg_value": round(avg, 2),
                "score": round(avg * count, 2),  # tie-break friendly
                "my_vote": my,
            }
        )
    return out


def top_voted_places(trip_id: str, top_n: int = 12) -> List[Dict[str, Any]]:
    """Return the top-N trip_places by aggregated score (avg * count). Falls back to all places when no votes exist."""
    client = _client()
    places = (
        client.table("trip_places")
        .select("*")
        .eq("trip_id", trip_id)
        .execute()
    )
    if not places.data:
        return []

    place_ids = [p["id"] for p in places.data]
    votes = (
        client.table("place_votes")
        .select("trip_place_id, value")
        .in_("trip_place_id", place_ids)
        .execute()
    )
    agg: Dict[str, Dict[str, float]] = {pid: {"sum": 0.0, "count": 0} for pid in place_ids}
    for v in (votes.data or []):
        agg[v["trip_place_id"]]["sum"] += v["value"]
        agg[v["trip_place_id"]]["count"] += 1

    enriched = []
    for p in places.data:
        a = agg[p["id"]]
        score = (a["sum"] / a["count"]) * a["count"] if a["count"] else float(p.get("rating") or 0.0)
        enriched.append({**p, "vote_score": score, "vote_count": a["count"]})

    enriched.sort(key=lambda x: (x["vote_score"], x.get("rating") or 0), reverse=True)
    return enriched[:top_n]
