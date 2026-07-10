"""
Voting endpoints for trip places.
"""
from fastapi import APIRouter, Body, Depends, HTTPException, status
from fastapi.concurrency import run_in_threadpool
from typing import List

from ..auth import get_current_user_context
from ..database import SupabaseDB
from ..services import trip_flow_service, vote_service, notification_service
from ..services.trip_access import check_trip_access

router = APIRouter()


async def _trip_id_for_place(trip_place_id: str) -> str:
    db = SupabaseDB(admin=True)
    res = await run_in_threadpool(
        lambda: db.client.table("trip_places").select("trip_id").eq("id", trip_place_id).execute()
    )
    if not res.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Place not found")
    return res.data[0]["trip_id"]


@router.post("/place/{trip_place_id}")
async def cast_vote(
    trip_place_id: str,
    body: dict = Body(...),
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Cast or update a 1..5 vote on a trip place. Members only."""
    user_id, token = user_context
    trip_id = await _trip_id_for_place(trip_place_id)
    await check_trip_access(trip_id, user_id, token=token, required_role="member")

    value = body.get("value")
    try:
        value = int(value)
    except (TypeError, ValueError):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="value (1..5) is required")

    return vote_service.upsert_vote(trip_place_id, user_id, value)


@router.delete("/place/{trip_place_id}")
async def retract_vote(
    trip_place_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    user_id, token = user_context
    trip_id = await _trip_id_for_place(trip_place_id)
    await check_trip_access(trip_id, user_id, token=token, required_role="member")
    ok = vote_service.retract_vote(trip_place_id, user_id)
    return {"removed": ok}


@router.get("/trip/{trip_id}")
async def list_trip_votes(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Aggregated vote stats for every trip place plus the requester's own vote."""
    user_id, token = user_context
    await check_trip_access(trip_id, user_id, token=token, required_role="member")
    return vote_service.list_trip_votes(trip_id, user_id)


@router.post("/trip/{trip_id}/voting/open")
async def open_voting(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Move trip into the voting phase. Creator only."""
    user_id, token = user_context
    trip = await check_trip_access(trip_id, user_id, token=token, required_role="creator")
    trip_flow_service.assert_can_open_voting(trip)

    db = SupabaseDB(admin=True)
    await run_in_threadpool(
        lambda: db.client.table("trips").update({"phase": "voting"}).eq("id", trip_id).execute()
    )

    members = await run_in_threadpool(
        lambda: db.client.table("trip_participants").select("user_id").eq("trip_id", trip_id).eq("status", "accepted").execute()
    )
    member_ids = [m["user_id"] for m in (members.data or [])]
    notification_service.emit_many(
        user_ids=member_ids,
        notif_type="voting_opened",
        title="Voting opened",
        body=f"Voting is now open for '{trip.get('title', 'your trip')}'.",
        payload={"trip_id": trip_id},
    )

    return {"phase": "voting", "notified": len(member_ids)}


@router.post("/trip/{trip_id}/voting/close")
async def close_voting(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Lock voting and move trip to finalized. Creator only."""
    user_id, token = user_context
    trip = await check_trip_access(trip_id, user_id, token=token, required_role="creator")
    trip_flow_service.assert_can_close_voting(trip)

    db = SupabaseDB(admin=True)
    await run_in_threadpool(
        lambda: db.client.table("trips").update({"phase": "finalized"}).eq("id", trip_id).execute()
    )

    members = await run_in_threadpool(
        lambda: db.client.table("trip_participants").select("user_id").eq("trip_id", trip_id).eq("status", "accepted").execute()
    )
    member_ids = [m["user_id"] for m in (members.data or [])]
    if trip.get("created_by") and trip["created_by"] not in member_ids:
        member_ids.append(trip["created_by"])

    notification_service.emit_many(
        user_ids=member_ids,
        notif_type="voting_closed",
        title="Voting closed",
        body=f"Voting closed for '{trip.get('title', 'your trip')}'. The plan can now be generated.",
        payload={"trip_id": trip_id},
    )

    return {"phase": "finalized", "notified": len(member_ids)}
