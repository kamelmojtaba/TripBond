from fastapi import APIRouter, HTTPException, status, Query, Depends
from fastapi.concurrency import run_in_threadpool
from typing import Any, Dict, List
from datetime import datetime, timedelta
from collections import Counter
from ..database import SupabaseDB, get_supabase_admin_client
from ..services.trip_access import check_trip_access
from ..services import trip_flow_service, trip_service
from ..services.itinerary_service import (
    generate_itinerary,
    create_itinerary,
    get_latest_itinerary,
    list_items,
    insert_items,
    update_item,
    delete_item,
    get_itinerary_with_items,
)
from ..services.smart_scheduler import build_smart_itinerary
from ..services.recommendation_service import rank_recommendations
from ..services import ai_poi_service, vote_service, notification_service, group_service, place_enrichment_service, place_image_assets
from ..schemas.trips import (
    TripResponse,
    CreateTripRequest,
    UpdateTripRequest,
    TripSummaryResponse,
    AddMemberRequest,
    TripMember,
    ItineraryActivity,
    DayItinerary,
    ItineraryResponse,
    GenerateItineraryRequest,
    POIResponse,
    RecommendationResponse,
    StarterPlanResponse,
)
import logging

logger = logging.getLogger(__name__)
router = APIRouter()

# Import auth dependency
from ..auth import get_current_user_context


def _trip_phase(trip: Dict[str, Any]) -> str:
    return str(trip.get("phase") or "planning")


def _is_public_trip(trip: Dict[str, Any]) -> bool:
    value = trip.get("is_public")
    if value is None:
        return True
    if isinstance(value, str):
        return value.strip().lower() not in {"false", "0", "no", "private"}
    return bool(value)


def _to_trip_response(trip: Dict[str, Any]) -> TripResponse:
    return TripResponse(
        id=trip["id"],
        created_by=trip["created_by"],
        title=trip.get("title", ""),
        destination=trip.get("destination", ""),
        phase=_trip_phase(trip),
        location=trip.get("location"),
        start_date=trip.get("start_date"),
        end_date=trip.get("end_date"),
        trip_type=trip.get("trip_type"),
        description=trip.get("description"),
        image_url=trip.get("image_url"),
        is_public=_is_public_trip(trip),
        created_at=trip.get("created_at"),
    )


# ==================== Trip Endpoints ====================

@router.get("/me", response_model=List[TripResponse])
async def get_my_created_trips(user_context: tuple[str, str] = Depends(get_current_user_context)):
    """Get all trips created by authenticated user"""
    user_id, token = user_context
    
    try:
        trips_data = await trip_service.get_user_trips(user_id, token)
        
        return [_to_trip_response(trip) for trip in trips_data]
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to get trips")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve trips"
        )


@router.get("/user/{user_id}", response_model=List[TripResponse])
async def get_trips_by_user(user_id: str):
    """Get all trips created by a specific user (public-facing)."""
    try:
        db = SupabaseDB(admin=True)
        response = await run_in_threadpool(
            lambda: db.client.table("trips").select("*").eq("created_by", user_id).execute()
        )
        return [
            _to_trip_response(trip)
            for trip in (response.data or [])
            if _is_public_trip(trip)
        ]
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to get trips for user %s", user_id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve user trips",
        )


@router.get("/public/{trip_id}", response_model=TripResponse)
async def get_public_trip_detail(trip_id: str):
    """Get public trip details (no auth required)"""
    try:
        client = get_supabase_admin_client()
        
        trip_response = await run_in_threadpool(
            lambda: client.table("trips").select("*").eq("id", trip_id).execute()
        )
        if not trip_response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Trip not found"
            )
        
        trip = trip_response.data[0]
        
        if not _is_public_trip(trip):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="This trip is private"
            )
        
        return _to_trip_response(trip)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to get public trip details")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve trip details"
        )


@router.get("/public/{trip_id}/itinerary")
async def get_public_trip_itinerary(trip_id: str):
    """Get public trip itinerary (no auth required)"""
    try:
        client = get_supabase_admin_client()
        
        trip_response = await run_in_threadpool(
            lambda: client.table("trips").select("*").eq("id", trip_id).execute()
        )
        if not trip_response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Trip not found"
            )
        
        trip = trip_response.data[0]
        
        if not _is_public_trip(trip):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="This trip is private"
            )
        
        # Fetch latest itinerary
        itinerary = await run_in_threadpool(
            lambda: get_latest_itinerary(trip_id, client=client)
        )
        
        if not itinerary:
            return ItineraryResponse(
                trip_id=trip_id,
                days=[],
                total_cost=0.0,
                total_days=0,
                optimization_score=None,
                generated_at=None,
                strategy=None,
            )
        
        # Fetch all items for this itinerary
        items = await run_in_threadpool(
            lambda: list_items(itinerary["id"], client=client)
        )
        
        # Build a map of place names/ids to trip_places for enrichment
        places_response = await run_in_threadpool(
            lambda: client.table("trip_places").select("*").eq("trip_id", trip_id).execute()
        )
        places_map = {}
        if places_response.data:
            for place in places_response.data:
                # Map by name or external_place_id
                if place.get("name"):
                    places_map[place["name"].lower()] = place
                if place.get("external_place_id"):
                    places_map[place["external_place_id"]] = place
        
        # Group by day_index → days[]
        days_dict = {}
        total_cost = 0.0
        trip_start_date = None
        if trip.get("start_date"):
            try:
                trip_start_date = datetime.fromisoformat(str(trip["start_date"])).date()
            except ValueError:
                trip_start_date = None
        
        for item in items:
            try:
                day_idx = int(item.get("day_index") or 1)
            except (TypeError, ValueError):
                day_idx = 1
            if day_idx not in days_dict:
                if trip_start_date:
                    day_date = (trip_start_date + timedelta(days=day_idx - 1)).isoformat()
                else:
                    day_date = f"Day {day_idx}"
                days_dict[day_idx] = {
                    "day": day_idx,
                    "date": day_date,
                    "activities": [],
                    "total_cost": 0.0,
                    "total_duration_minutes": 0,
                }
            
            # Try to enrich with place data
            item_title = item.get("title") or "Activity"
            place_data = places_map.get(item_title.lower()) or places_map.get(item_title)
            
            activity = {
                "id": item["id"],
                "name": item_title,
                "type": item.get("type") or "activity",
                "location": item.get("location") or trip.get("destination", "Unknown"),
                "start_time": item.get("start_time"),
                "end_time": item.get("end_time"),
                "description": item.get("notes", ""),
                "cost": place_data.get("cost") if place_data else item.get("cost"),
                "rating": place_data.get("rating") if place_data else item.get("rating"),
                "user_ratings_total": place_data.get("user_ratings_total") if place_data else None,
                "priority": item.get("priority", 1),
                "photo_url": item.get("photo_url") or (place_data.get("image_url") if place_data else None),
                "address": place_data.get("address") if place_data else None,
                "fsq_id": item.get("fsq_id"),
                "external_place_id": item.get("external_place_id") or (place_data.get("external_place_id") if place_data else None),
                "latitude": place_data.get("latitude") if place_data else None,
                "longitude": place_data.get("longitude") if place_data else None,
                "score": item.get("score")
            }
            activity_cost = activity.get("cost") or 0.0
            try:
                activity_cost = float(activity_cost)
            except (TypeError, ValueError):
                activity_cost = 0.0
            total_cost += activity_cost
            days_dict[day_idx]["total_cost"] += activity_cost
            duration = _duration_minutes(activity.get("start_time"), activity.get("end_time")) or 0
            days_dict[day_idx]["total_duration_minutes"] += duration
            days_dict[day_idx]["activities"].append(
                _activity_with_media(activity, trip.get("destination") or trip.get("location") or "", place_data)
            )
        
        days = [days_dict[k] for k in sorted(days_dict.keys())]
        
        return ItineraryResponse(
            trip_id=trip_id,
            days=days,
            total_cost=total_cost,
            total_days=len(days),
            optimization_score=itinerary.get("optimization_score"),
            generated_at=itinerary.get("created_at"),
            strategy=itinerary.get("generated_by", "unknown")
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to get public itinerary")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve itinerary"
        )


@router.get("/{trip_id}", response_model=TripResponse)
async def get_trip_detail(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Get trip details (creator, members, or public)"""
    user_id, token = user_context
    
    try:
        trip = await check_trip_access(trip_id, user_id, token=token, required_role="view")
        
        return _to_trip_response(trip)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to get trip details")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve trip details"
        )


@router.get("/{trip_id}/summary", response_model=TripSummaryResponse)
async def get_trip_summary(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Get trip summary: member count, itinerary status, user relationship"""
    user_id, token = user_context
    
    try:
        trip = await check_trip_access(trip_id, user_id, token=token, required_role="view")
        db = SupabaseDB(admin=True)
        
        members_response = await run_in_threadpool(
            lambda: db.client.table("trip_participants").select("user_id", count="exact")
            .eq("trip_id", trip_id)
            .eq("status", "accepted")
            .execute()
        )
        member_count = members_response.count if members_response.count else 0
        
        itinerary_response = await run_in_threadpool(
            lambda: db.client.table("itineraries").select("id")
            .eq("trip_id", trip_id)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        
        has_itinerary = bool(itinerary_response.data)
        itinerary_days = 0
        if has_itinerary:
            itinerary_id = itinerary_response.data[0]["id"]
            # Count distinct day_index values to get number of days
            items_response = await run_in_threadpool(
                lambda: db.client.table("itinerary_items")
                .select("day_index")
                .eq("itinerary_id", itinerary_id)
                .execute()
            )
            if items_response.data:
                itinerary_days = len(set(item["day_index"] for item in items_response.data))
        
        is_creator = trip["created_by"] == user_id
        
        participant_response = await run_in_threadpool(
            lambda: db.client.table("trip_participants").select("user_id, status")
            .eq("trip_id", trip_id)
            .eq("user_id", user_id)
            .execute()
        )
        is_member = bool(participant_response.data and participant_response.data[0].get("status") == "accepted")
        
        return TripSummaryResponse(
            trip_id=trip["id"],
            title=trip.get("title", ""),
            destination=trip.get("destination", ""),
            phase=_trip_phase(trip),
            member_count=member_count,
            has_itinerary=has_itinerary,
            itinerary_days=itinerary_days,
            is_creator=is_creator,
            is_member=is_member,
            is_public=trip.get("is_public", True),
            start_date=trip.get("start_date"),
            end_date=trip.get("end_date")
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to get trip summary")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve trip summary"
        )


@router.post("/", response_model=TripResponse)
async def create_new_trip(
    trip: CreateTripRequest,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Create new trip"""
    user_id, token = user_context
    
    try:
        trip_data = {
            "title": trip.title,
            "destination": trip.destination,
            "location": trip.location,
            "start_date": trip.start_date.isoformat() if trip.start_date else None,
            "end_date": trip.end_date.isoformat() if trip.end_date else None,
            "trip_type": trip.trip_type,
            "description": trip.description,
            "image_url": trip.image_url,
            "is_public": trip.is_public,
            "phase": "planning",
        }
        
        created_trip = await trip_service.create_trip(user_id, token, trip_data)
        
        return _to_trip_response(created_trip)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to create trip")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create trip"
        )


@router.delete("/{trip_id}")
async def delete_trip_endpoint(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Delete trip (creator only)"""
    user_id, token = user_context
    
    try:
        await check_trip_access(trip_id, user_id, token=token, required_role="creator")
        await trip_service.delete_trip(trip_id, token)
        
        return {"message": "Trip deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to delete trip")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete trip"
        )


@router.patch("/{trip_id}", response_model=TripResponse)
async def update_trip_endpoint(
    trip_id: str,
    updates: UpdateTripRequest,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Update trip details (creator only)"""
    user_id, token = user_context
    
    try:
        await check_trip_access(trip_id, user_id, token=token, required_role="creator")
        
        update_data = {
            "title": updates.title,
            "destination": updates.destination,
            "location": updates.location,
            "start_date": updates.start_date.isoformat() if updates.start_date else None,
            "end_date": updates.end_date.isoformat() if updates.end_date else None,
            "trip_type": updates.trip_type,
            "description": updates.description,
            "image_url": updates.image_url,
            "is_public": updates.is_public
        }
        
        updated_trip = await trip_service.update_trip(trip_id, token, update_data)
        
        return _to_trip_response(updated_trip)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to update trip")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update trip"
        )


# ==================== Member Endpoints ====================

@router.get("/{trip_id}/members", response_model=List[TripMember])
async def get_trip_members(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Get accepted trip members (creator/members only)"""
    user_id, token = user_context
    
    try:
        await check_trip_access(trip_id, user_id, token=token, required_role="member")
        members_data = await trip_service.get_trip_members(trip_id, token, status_filter="accepted")
        
        return [
            TripMember(
                id=member.get("id"),
                user_id=member["user_id"],
                status=member.get("status", "accepted"),
                invited_by=member.get("invited_by"),
                invited_at=member.get("invited_at"),
                responded_at=member.get("responded_at"),
                joined_at=member.get("joined_at")
            )
            for member in members_data
        ]
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to get trip members")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve trip members"
        )


@router.get("/{trip_id}/members/pending", response_model=List[TripMember])
async def get_pending_invites(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Get pending invites for trip (creator only)"""
    user_id, token = user_context
    
    try:
        await check_trip_access(trip_id, user_id, token=token, required_role="creator")
        members_data = await trip_service.get_trip_members(trip_id, token, status_filter="pending")
        
        return [
            TripMember(
                id=member.get("id"),
                user_id=member["user_id"],
                status=member.get("status", "pending"),
                invited_by=member.get("invited_by"),
                invited_at=member.get("invited_at"),
                responded_at=member.get("responded_at"),
                joined_at=member.get("joined_at")
            )
            for member in members_data
        ]
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to get pending invites")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve pending invites"
        )


@router.get("/{trip_id}/members/all", response_model=List[TripMember])
async def get_all_trip_members(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Get all trip members (accepted + pending + declined) (creator only)"""
    user_id, token = user_context
    
    try:
        await check_trip_access(trip_id, user_id, token=token, required_role="creator")
        members_data = await trip_service.get_trip_members(trip_id, token, status_filter=None)
        
        return [
            TripMember(
                id=member.get("id"),
                user_id=member["user_id"],
                status=member.get("status", "accepted"),
                invited_by=member.get("invited_by"),
                invited_at=member.get("invited_at"),
                responded_at=member.get("responded_at"),
                joined_at=member.get("joined_at")
            )
            for member in members_data
        ]
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to get all trip members")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve all trip members"
        )


@router.post("/{trip_id}/leave")
async def leave_trip_endpoint(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Leave trip (members only, creator must delete)"""
    user_id, token = user_context
    
    try:
        await trip_service.leave_trip(trip_id, user_id, token)
        return {"message": "Successfully left the trip"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to leave trip")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to leave trip"
        )


@router.post("/{trip_id}/members", response_model=TripMember)
async def invite_trip_member(
    trip_id: str,
    member: AddMemberRequest,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Invite member (creates pending invite)"""
    inviter_id, token = user_context
    
    try:
        await check_trip_access(trip_id, inviter_id, token=token, required_role="creator")
        
        row = await trip_service.invite_member(trip_id, inviter_id, member.user_id, token)
        
        return TripMember(
            id=row.get("id"),
            user_id=row["user_id"],
            status=row["status"],
            invited_by=row.get("invited_by"),
            invited_at=row.get("invited_at"),
            responded_at=row.get("responded_at"),
            joined_at=row.get("joined_at")
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to invite member")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to invite member"
        )


@router.delete("/{trip_id}/members/{user_id}")
async def remove_trip_member(
    trip_id: str,
    user_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Remove member or cancel invite (creator only)"""
    current_user_id, token = user_context
    
    try:
        await check_trip_access(trip_id, current_user_id, token=token, required_role="creator")
        await trip_service.remove_member(trip_id, user_id, token)
        
        return {"message": "Member/invite removed successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to remove member")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to remove member"
        )


@router.get("/invites", response_model=List[dict])
async def get_my_pending_invites(
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Get user's pending trip invites"""
    user_id, token = user_context
    
    try:
        invites = await trip_service.get_user_pending_invites(user_id, token)
        return invites
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to get pending invites")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve pending invites"
        )


@router.post("/{trip_id}/invites/accept", response_model=TripMember)
async def accept_trip_invite(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Accept pending trip invite"""
    user_id, token = user_context
    
    try:
        row = await trip_service.accept_invite(trip_id, user_id, token)
        
        return TripMember(
            id=row.get("id"),
            user_id=row["user_id"],
            status=row["status"],
            invited_by=row.get("invited_by"),
            invited_at=row.get("invited_at"),
            responded_at=row.get("responded_at"),
            joined_at=row.get("joined_at")
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to accept invite")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to accept invite"
        )


@router.post("/{trip_id}/invites/decline")
async def decline_trip_invite(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Decline pending trip invite"""
    user_id, token = user_context
    
    try:
        await trip_service.decline_invite(trip_id, user_id, token)
        return {"message": "Invite declined successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to decline invite")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to decline invite"
        )


# ==================== Trip Flow Progress Endpoints ====================

@router.get("/{trip_id}/flow-status")
async def get_trip_flow_status_endpoint(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Return the gated trip flow state for the current user."""
    user_id, token = user_context
    try:
        trip = await check_trip_access(trip_id, user_id, token=token, required_role="member")
        return trip_flow_service.get_trip_flow_status(trip, user_id)
    except HTTPException:
        raise
    except Exception:
        logger.exception("Failed to get trip flow status")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get trip flow status",
        )


@router.post("/{trip_id}/flow/places-complete")
async def mark_places_complete(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Mark the current user's place-picking stage as complete."""
    user_id, token = user_context
    try:
        trip = await check_trip_access(trip_id, user_id, token=token, required_role="member")
        if _trip_phase(trip) != "planning":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Places can only be marked complete during planning.",
            )
        trip_flow_service.mark_progress(trip_id, user_id, "places_completed_at")
        return trip_flow_service.get_trip_flow_status(trip, user_id)
    except HTTPException:
        raise
    except Exception:
        logger.exception("Failed to mark places complete")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to mark places complete",
        )


@router.delete("/{trip_id}/flow/places-complete")
async def clear_places_complete(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Let the current user reopen their place-picking stage while planning."""
    user_id, token = user_context
    try:
        trip = await check_trip_access(trip_id, user_id, token=token, required_role="member")
        if _trip_phase(trip) != "planning":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Places can only be changed during planning.",
            )
        trip_flow_service.clear_progress(trip_id, user_id, "places_completed_at")
        return trip_flow_service.get_trip_flow_status(trip, user_id)
    except HTTPException:
        raise
    except Exception:
        logger.exception("Failed to reopen places")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to reopen places",
        )


@router.post("/{trip_id}/flow/voting-complete")
async def mark_voting_complete(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Mark the current user's voting stage as complete."""
    user_id, token = user_context
    try:
        trip = await check_trip_access(trip_id, user_id, token=token, required_role="member")
        if _trip_phase(trip) != "voting":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Voting can only be marked complete while voting is open.",
            )
        trip_flow_service.mark_progress(trip_id, user_id, "voting_completed_at")
        return trip_flow_service.get_trip_flow_status(trip, user_id)
    except HTTPException:
        raise
    except Exception:
        logger.exception("Failed to mark voting complete")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to mark voting complete",
        )


@router.delete("/{trip_id}/flow/voting-complete")
async def clear_voting_complete(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Let the current user update votes while voting remains open."""
    user_id, token = user_context
    try:
        trip = await check_trip_access(trip_id, user_id, token=token, required_role="member")
        if _trip_phase(trip) != "voting":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Voting can only be changed while voting is open.",
            )
        trip_flow_service.clear_progress(trip_id, user_id, "voting_completed_at")
        return trip_flow_service.get_trip_flow_status(trip, user_id)
    except HTTPException:
        raise
    except Exception:
        logger.exception("Failed to reopen voting")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to reopen voting",
        )


# ==================== Itinerary Endpoints ====================

@router.post("/{trip_id}/generate-itinerary", response_model=ItineraryResponse)
async def generate_trip_itinerary(
    trip_id: str,
    request: GenerateItineraryRequest,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Generate optimized itinerary from top-voted trip places (creator only).

    Pipeline:
      1. Validate access + (recommended) trip phase == 'finalized'.
      2. Pull top-voted trip_places via the vote service.
      3. Run smart scheduler (distance + time-of-day aware) over them.
      4. Persist itineraries + itinerary_items.
      5. Notify members.
    """
    user_id, token = user_context

    try:
        trip = await check_trip_access(trip_id, user_id, token=token, required_role="creator")
        if _trip_phase(trip) != "finalized":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Voting must be closed before generating the AI plan.",
            )

        db = SupabaseDB(admin=True)
        group_prefs_response = await run_in_threadpool(
            lambda: db.client.table("group_models").select("*").eq("trip_id", trip_id).execute()
        )
        group_prefs = group_prefs_response.data[0] if group_prefs_response.data else None

        voted = await run_in_threadpool(
            lambda: vote_service.top_voted_places(trip_id, top_n=24)
        )

        itinerary_data, strategy = generate_itinerary(
            trip=trip,
            group_preferences=group_prefs.get("aggregated_preferences") if group_prefs else None,
            use_ga=request.use_ga,
            max_budget=request.max_budget,
            pace=request.pace,
            preferences=request.preferences,
            voted_places=voted,
        )

        activity_count = sum(
            len(day.get("activities", []))
            for day in itinerary_data.get("days", [])
            if isinstance(day, dict)
        )
        if activity_count == 0:
            destination = (trip.get("destination") or trip.get("location") or "").strip()
            fallback_pois = await run_in_threadpool(
                lambda: ai_poi_service.get_pois_for_destination(
                    destination,
                    limit=24,
                    require_coordinates=True,
                )
            )
            if fallback_pois:
                fallback = build_smart_itinerary(
                    trip,
                    fallback_pois,
                    pace=request.pace or "moderate",
                )
                itinerary_data = {
                    "days": fallback.days,
                    "total_cost": fallback.total_cost,
                    "fitness_score": fallback.fitness_score,
                }
                strategy = f"{fallback.strategy}_destination_fallback"
                activity_count = sum(
                    len(day.get("activities", []))
                    for day in itinerary_data.get("days", [])
                    if isinstance(day, dict)
                )

        if activity_count == 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="No usable places found for this trip destination.",
            )
        
        # Insert itinerary record using helper function
        itinerary_row = await run_in_threadpool(
            lambda: create_itinerary(
                trip_id=trip_id,
                generated_by=user_id,
                status="active",
                optimization_score=itinerary_data.get("fitness_score", 0.0),
                version=1
            )
        )
        itinerary_id = itinerary_row["id"]
        
        # Bulk insert itinerary items using helper function
        # Convert days structure to flat items list
        items_to_insert = []
        for day in itinerary_data.get("days", []):
            for activity in day.get("activities", []):
                item = {
                    "day_index": day.get("day"),
                    "start_time": activity.get("start_time"),
                    "end_time": activity.get("end_time"),
                    "title": activity.get("name"),
                    "notes": activity.get("description") or activity.get("category"),
                    "score": activity.get("score", 0.0),
                }
                items_to_insert.append(item)

        await run_in_threadpool(
            lambda: insert_items(itinerary_id, items_to_insert)
        )

        # Notify members + creator that the plan is ready
        try:
            members = await run_in_threadpool(
                lambda: db.client.table("trip_participants").select("user_id").eq("trip_id", trip_id).eq("status", "accepted").execute()
            )
            recipients = [m["user_id"] for m in (members.data or [])]
            if trip.get("created_by") and trip["created_by"] not in recipients:
                recipients.append(trip["created_by"])
            notification_service.emit_many(
                user_ids=recipients,
                notif_type="itinerary_generated",
                title="Plan ready",
                body=f"AI generated a new plan for '{trip.get('title','your trip')}'.",
                payload={"trip_id": trip_id, "itinerary_id": itinerary_id, "strategy": strategy},
            )
        except Exception:
            logger.exception("Failed to notify members of generated itinerary")

        return ItineraryResponse(
            trip_id=trip_id,
            days=itinerary_data["days"],
            total_cost=itinerary_data["total_cost"],
            total_days=len(itinerary_data["days"]),
            optimization_score=itinerary_data.get("fitness_score"),
            generated_at=datetime.now().isoformat(),
            strategy=strategy
        )
        
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
    except Exception as e:
        logger.exception("Failed to generate itinerary")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate itinerary"
        )


@router.get("/{trip_id}/itinerary", response_model=ItineraryResponse)
async def get_itinerary(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Get trip itinerary"""
    user_id, token = user_context
    
    try:
        trip = await check_trip_access(trip_id, user_id, token=token, required_role="view")
        db = SupabaseDB(admin=True)
        
        # Fetch latest itinerary
        itinerary = await run_in_threadpool(
            lambda: get_latest_itinerary(trip_id)
        )
        
        if not itinerary:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No itinerary found for this trip. Please generate one first."
            )
        
        # Fetch all items for this itinerary
        items = await run_in_threadpool(
            lambda: list_items(itinerary["id"])
        )
        
        # Group by day_index → days[]
        days_dict = {}
        total_cost = 0.0

        start_date_raw = trip.get("start_date") if isinstance(trip, dict) else None
        start_date_obj = None
        if start_date_raw:
            try:
                start_date_obj = datetime.fromisoformat(str(start_date_raw)).date()
            except ValueError:
                start_date_obj = None
        
        # Build a map of place names/ids to trip_places for enrichment
        places_response = await run_in_threadpool(
            lambda: db.client.table("trip_places").select("*").eq("trip_id", trip_id).execute()
        )
        places_map = {}
        if places_response.data:
            for place in places_response.data:
                # Map by name or external_place_id
                if place.get("name"):
                    places_map[place["name"].lower()] = place
                if place.get("external_place_id"):
                    places_map[place["external_place_id"]] = place
        
        for item in items:
            day_idx = item["day_index"]
            if day_idx not in days_dict:
                day_date = (
                    (start_date_obj + timedelta(days=max(day_idx - 1, 0))).isoformat()
                    if start_date_obj
                    else f"Day {day_idx}"
                )
                days_dict[day_idx] = {
                    "day": day_idx,
                    "date": day_date,
                    "activities": [],
                    "total_cost": 0.0,
                    "total_duration_minutes": 0,
                }
            
            # Try to enrich with place data
            item_title = item.get("title", "Activity")
            place_data = places_map.get(item_title.lower()) or places_map.get(item_title)
            
            # If not found by name, try by external_place_id
            if not place_data and item.get("external_place_id"):
                place_data = places_map.get(item["external_place_id"])
            
            activity = {
                "id": item["id"],
                "name": item.get("name") or item_title,
                "title": item_title,
                "type": item.get("type", "activity"),
                "location": item.get("location") or item.get("notes") or trip.get("destination", "Unknown"),
                "start_time": item["start_time"],
                "end_time": item["end_time"],
                "description": item.get("notes", ""),
                "priority": item.get("priority", 1),
                "rating": place_data.get("rating") if place_data else item.get("rating", 4.0),
                "user_ratings_total": place_data.get("user_ratings_total") if place_data else None,
                "cost": place_data.get("cost") if place_data else item.get("cost", 0),
                "photo_url": item.get("photo_url") or (place_data.get("image_url") if place_data else None),
                "address": place_data.get("address") if place_data else None,
                # Place data fields
                "external_place_id": item.get("external_place_id") or (place_data.get("external_place_id") if place_data else None),
                "place_id": item.get("place_id"),
                "fsq_id": item.get("fsq_id"),
                "latitude": place_data.get("latitude") if place_data else item.get("latitude"),
                "longitude": place_data.get("longitude") if place_data else item.get("longitude"),
            }
            days_dict[day_idx]["activities"].append(
                _activity_with_media(
                    activity,
                    (trip.get("destination") or trip.get("location") or ""),
                    place_data,
                )
            )
        
        days = [days_dict[k] for k in sorted(days_dict.keys())]
        
        return ItineraryResponse(
            trip_id=trip_id,
            days=days,
            total_cost=total_cost,
            total_days=len(days),
            optimization_score=itinerary.get("optimization_score"),
            generated_at=itinerary.get("created_at"),
            strategy=itinerary.get("generated_by", "unknown")
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to get itinerary")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve itinerary"
        )


@router.put("/{trip_id}/recalculate", response_model=ItineraryResponse)
async def recalculate_itinerary(
    trip_id: str,
    request: GenerateItineraryRequest,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Recalculate itinerary with updated preferences"""
    return await generate_trip_itinerary(trip_id, request, user_context)


@router.put("/{trip_id}/itinerary/items/{item_id}")
async def update_itinerary_item(
    trip_id: str,
    item_id: str,
    activity: ItineraryActivity,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Update itinerary activity (creator only)"""
    user_id, token = user_context
    
    try:
        await check_trip_access(trip_id, user_id, token=token, required_role="member")
        
        # Verify itinerary exists for this trip
        itinerary = await run_in_threadpool(
            lambda: get_latest_itinerary(trip_id)
        )
        
        if not itinerary:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No itinerary found for this trip"
            )
        
        # Update the specific itinerary item using helper
        patch = {
            "title": activity.name,
            "start_time": activity.start_time,
            "end_time": activity.end_time,
            "notes": activity.description,
            "score": activity.priority if activity.priority else 1
        }
        if activity.day is not None:
            patch["day_index"] = max(activity.day, 1)
        
        try:
            updated_item = await run_in_threadpool(
                lambda: update_item(item_id, patch)
            )
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Activity item not found in itinerary"
            )
        
        return {
            "message": "Itinerary item updated successfully", 
            "activity": updated_item
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to update itinerary item")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update itinerary item"
        )



@router.post("/{trip_id}/itinerary/items")
async def add_itinerary_item(
    trip_id: str,
    day: int,
    activity: ItineraryActivity,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Add activity to itinerary day (any accepted member)"""
    user_id, token = user_context
    
    try:
        await check_trip_access(trip_id, user_id, token=token, required_role="member")
        
        # Get itinerary for this trip
        itinerary = await run_in_threadpool(
            lambda: get_latest_itinerary(trip_id)
        )
        
        if not itinerary:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No itinerary found for this trip"
            )
        
        itinerary_id = itinerary["id"]
        
        # Insert new activity item using helper
        new_item = {
            "day_index": day,
            "start_time": activity.start_time,
            "end_time": activity.end_time,
            "title": activity.name,
            "notes": activity.description,
            "score": activity.priority if activity.priority else 0.0
        }
        
        await run_in_threadpool(
            lambda: insert_items(itinerary_id, [new_item])
        )
        
        return {
            "message": "Activity added successfully", 
            "activity": new_item
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to add itinerary item")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to add itinerary item"
        )



@router.delete("/{trip_id}/itinerary/items/{item_id}")
async def delete_itinerary_item(
    trip_id: str,
    item_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Remove activity from itinerary (any accepted member)"""
    user_id, token = user_context
    
    try:
        await check_trip_access(trip_id, user_id, token=token, required_role="member")
        
        # Verify itinerary exists for this trip
        itinerary = await run_in_threadpool(
            lambda: get_latest_itinerary(trip_id)
        )
        
        if not itinerary:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No itinerary found for this trip"
            )
        
        # Delete the specific itinerary item using helper
        try:
            await run_in_threadpool(
                lambda: delete_item(item_id)
            )
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Activity item not found in itinerary"
            )
        
        return {"message": "Activity removed successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to delete itinerary item")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete itinerary item"
        )


# ==================== POI Recommendations ====================

def _as_float(value: Any) -> float | None:
    try:
        if value is None:
            return None
        return float(value)
    except (TypeError, ValueError):
        return None


def _as_tags(value: Any) -> List[str]:
    if isinstance(value, list):
        return [str(item) for item in value if item]
    if isinstance(value, str) and value.strip():
        return [value.strip()]
    return []


def _as_int(value: Any) -> int | None:
    try:
        if value is None:
            return None
        return int(float(value))
    except (TypeError, ValueError):
        return None


def _opening_hours_dict(value: Any) -> dict | None:
    if isinstance(value, dict):
        return value
    if isinstance(value, list):
        return {"weekday_text": value}
    if isinstance(value, str) and value.strip() and value.strip().lower() != "nan":
        return {"text": value.strip()}
    return None


def _poi_with_media(poi: dict, destination: str) -> dict:
    """Attach cached Google or bundled fallback images to a POI dict."""
    city = (poi.get("city") or destination or "").strip()
    merged = dict(poi)
    if city:
        enriched_rows = place_enrichment_service.merge_pois_with_cached_enrichments([merged], city)
        if enriched_rows:
            merged = enriched_rows[0]
    return place_image_assets.apply_bundled_images(merged)


def _activity_with_media(
    activity: dict,
    destination: str,
    place_data: dict | None = None,
) -> dict:
    """Ensure itinerary activities expose a usable photo/image for the client."""
    enriched_activity = dict(activity)
    source = dict(place_data or {})
    source.setdefault("name", enriched_activity.get("name"))
    source.setdefault("city", destination)

    photo_url = (
        enriched_activity.get("photo_url")
        or enriched_activity.get("image_url")
        or source.get("image_url")
        or source.get("photo_url")
    )
    images = enriched_activity.get("images") or source.get("images")
    image_asset = enriched_activity.get("image_asset") or source.get("image_asset")

    if not photo_url:
        bundled = place_image_assets.apply_bundled_images(source)
        photo_url = bundled.get("image_url")
        images = images or bundled.get("images")
        image_asset = image_asset or bundled.get("image_asset")

    if photo_url:
        enriched_activity["photo_url"] = photo_url
        enriched_activity["image_url"] = photo_url
    if images:
        enriched_activity["images"] = images
    if image_asset:
        enriched_activity["image_asset"] = image_asset
    return enriched_activity


def _recommendation_poi_response(poi: dict, destination: str) -> POIResponse:
    poi = _poi_with_media(poi, destination)
    latitude = _as_float(poi.get("latitude") or poi.get("lat"))
    longitude = _as_float(poi.get("longitude") or poi.get("lng") or poi.get("lon"))
    coordinates = poi.get("coordinates")
    if not isinstance(coordinates, dict) and latitude is not None and longitude is not None:
        coordinates = {"lat": latitude, "lng": longitude}

    poi_id = (
        poi.get("id")
        or poi.get("poi_id")
        or poi.get("place_id")
        or poi.get("external_place_id")
        or poi.get("name")
    )
    poi_type = poi.get("poi_type") or poi.get("type") or poi.get("category") or "attraction"
    location = (
        poi.get("location")
        or poi.get("address")
        or poi.get("formatted_address")
        or poi.get("city")
        or destination
    )

    return POIResponse(
        id=str(poi_id),
        name=str(poi.get("name") or "Unknown place"),
        type=str(poi_type),
        category=poi.get("category"),
        poi_type=poi.get("poi_type"),
        location=str(location),
        address=poi.get("address") or poi.get("formatted_address"),
        description=poi.get("description"),
        rating=_as_float(poi.get("rating")),
        review_count=_as_int(poi.get("review_count")),
        user_ratings_total=_as_int(poi.get("user_ratings_total") or poi.get("review_count")),
        price_level=poi.get("price_level"),
        image_url=poi.get("image_url"),
        coordinates=coordinates,
        latitude=latitude,
        longitude=longitude,
        coordinates_inferred=poi.get("coordinates_inferred"),
        external_place_id=(
            poi.get("external_place_id")
            or poi.get("place_id")
            or poi.get("id")
            or poi.get("poi_id")
        ),
        place_id=poi.get("place_id") or poi.get("external_place_id") or poi.get("id"),
        types=_as_tags(poi.get("types")),
        province=poi.get("province"),
        tags=_as_tags(poi.get("tags") or poi.get("types") or poi.get("category")),
        opening_hours=_opening_hours_dict(poi.get("opening_hours")),
        contact=poi.get("contact"),
        created_at=poi.get("created_at")
    )


def _poi_identifier(poi: dict) -> str:
    return str(
        poi.get("id")
        or poi.get("poi_id")
        or poi.get("place_id")
        or poi.get("external_place_id")
        or poi.get("name")
        or "unknown"
    )


def _starter_scheduler_place(poi: dict, score: float) -> dict:
    place = dict(poi)
    place_id = _poi_identifier(poi)
    place["id"] = place_id
    place["external_place_id"] = (
        poi.get("external_place_id")
        or poi.get("place_id")
        or poi.get("poi_id")
        or place_id
    )
    place["place_types"] = _as_tags(
        poi.get("place_types")
        or poi.get("types")
        or poi.get("tags")
        or poi.get("category")
        or poi.get("poi_type")
    )
    place["vote_score"] = score
    return place


def _duration_minutes(start: str | None, end: str | None) -> int | None:
    if not start or not end:
        return None
    try:
        start_dt = datetime.strptime(start, "%H:%M")
        end_dt = datetime.strptime(end, "%H:%M")
        return int((end_dt - start_dt).total_seconds() / 60)
    except ValueError:
        return None


def _liked_trip_signals_for_user(db: SupabaseDB, user_id: str) -> Dict[str, Any]:
    likes = (
        db.client.table("trip_post_likes")
        .select("trip_id")
        .eq("user_id", user_id)
        .limit(50)
        .execute()
    )
    liked_trip_ids = [row["trip_id"] for row in (likes.data or []) if row.get("trip_id")]
    if not liked_trip_ids:
        return {}

    trips = (
        db.client.table("trips")
        .select("id, destination, trip_type")
        .in_("id", liked_trip_ids)
        .eq("is_public", True)
        .execute()
    )
    rows = trips.data or []
    if not rows:
        return {}

    destinations = [
        str(row.get("destination") or "").strip()
        for row in rows
        if str(row.get("destination") or "").strip()
    ]
    trip_types = [
        str(row.get("trip_type") or "").strip().lower()
        for row in rows
        if str(row.get("trip_type") or "").strip()
    ]

    trip_type_tags = {
        "adventure": ["activity", "attraction", "park", "nature", "outdoor"],
        "outdoor": ["activity", "attraction", "park", "nature", "outdoor"],
        "culture": ["museum", "historical", "landmark"],
        "cultural": ["museum", "historical", "landmark"],
        "food": ["restaurant", "cafe"],
        "family": ["park", "zoo", "aquarium", "amusement_park", "museum"],
        "relax": ["restaurant", "cafe", "beach", "park", "garden"],
        "relaxing": ["restaurant", "cafe", "beach", "park", "garden"],
        "nightlife": ["restaurant", "cafe", "entertainment"],
    }
    activity_tags: list[str] = []
    for trip_type in trip_types:
        activity_tags.extend(trip_type_tags.get(trip_type, [trip_type]))

    return {
        "liked_trip_count": len(rows),
        "liked_destinations": [item for item, _ in Counter(destinations).most_common(5)],
        "liked_trip_types": [item for item, _ in Counter(trip_types).most_common(5)],
        "activity_tags": [item for item, _ in Counter(activity_tags).most_common(10)],
    }


def _build_group_preferences_from_members(db: SupabaseDB, trip: Dict[str, Any]) -> dict:
    trip_id = trip["id"]
    members = (
        db.client.table("trip_participants")
        .select("user_id")
        .eq("trip_id", trip_id)
        .eq("status", "accepted")
        .execute()
    )
    member_ids = [row["user_id"] for row in (members.data or []) if row.get("user_id")]
    creator_id = trip.get("created_by")
    if creator_id and creator_id not in member_ids:
        member_ids.insert(0, creator_id)

    individual_preferences = []
    for member_id in member_ids:
        trip_prefs = (
            db.client.table("trip_preferences")
            .select("*")
            .eq("trip_id", trip_id)
            .eq("user_id", member_id)
            .limit(1)
            .execute()
        )
        profile = (
            db.client.table("profiles")
            .select(
                "budget_level, travel_style, dietary_preferences, "
                "preferred_accommodation, preferred_transport, openness, "
                "conscientiousness, extraversion, agreeableness, neuroticism"
            )
            .eq("id", member_id)
            .limit(1)
            .execute()
        )
        profile_data = profile.data[0] if profile.data else {}
        trip_pref_data = trip_prefs.data[0] if trip_prefs.data else {}
        liked_signals = _liked_trip_signals_for_user(db, member_id)
        if liked_signals.get("activity_tags"):
            merged_activity_tags = list(dict.fromkeys([
                *(trip_pref_data.get("activity_tags") or []),
                *liked_signals["activity_tags"],
            ]))
            trip_pref_data = {**trip_pref_data, "activity_tags": merged_activity_tags}

        individual_preferences.append({
            "user_id": member_id,
            "weight": 1.0,
            "trip_preferences": trip_pref_data,
            "general_preferences": profile_data,
            "personality": profile_data,
            "liked_trips": liked_signals,
        })

    if not individual_preferences:
        return {}

    aggregated = group_service.apply_aggregation_strategy(individual_preferences, "average")
    conservative = group_service.apply_aggregation_strategy(individual_preferences, "least_misery")
    for key in ("budget_level", "pace"):
        if conservative.get(key) and not aggregated.get(key):
            aggregated[key] = conservative[key]

    travel_styles = [
        prefs.get("general_preferences", {}).get("travel_style")
        for prefs in individual_preferences
        if prefs.get("general_preferences", {}).get("travel_style")
    ]
    if travel_styles and not aggregated.get("travel_style"):
        aggregated["travel_style"] = max(set(travel_styles), key=travel_styles.count)

    liked_destinations = [
        destination
        for prefs in individual_preferences
        for destination in prefs.get("liked_trips", {}).get("liked_destinations", [])
    ]
    if liked_destinations:
        aggregated["liked_destinations"] = [
            item for item, _ in Counter(liked_destinations).most_common(5)
        ]

    liked_trip_types = [
        trip_type
        for prefs in individual_preferences
        for trip_type in prefs.get("liked_trips", {}).get("liked_trip_types", [])
    ]
    if liked_trip_types:
        aggregated["liked_trip_types"] = [
            item for item, _ in Counter(liked_trip_types).most_common(5)
        ]

    return aggregated


@router.get("/{trip_id}/starter-plan", response_model=StarterPlanResponse)
async def get_trip_starter_plan(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
    limit: int = Query(24, description="Maximum places to consider"),
    pace: str = Query("moderate", description="relaxed, moderate, or fast"),
):
    """Generate a non-persisted AI starter plan for place selection.

    This runs before voting and uses destination POIs plus the latest stored
    group preference model when available. It does not create the final
    itinerary; selected places still flow through voting first.
    """
    user_id, token = user_context

    try:
        trip = await check_trip_access(trip_id, user_id, token=token, required_role="member")
        if _trip_phase(trip) != "planning":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Starter plans are only available while the trip is in place selection.",
            )

        destination = (trip.get("destination") or trip.get("location") or "").strip()
        if not destination:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Trip destination is required before generating a starter plan.",
            )

        limit = max(1, min(limit, 60))
        pace = pace if pace in {"relaxed", "moderate", "fast"} else "moderate"
        db = SupabaseDB(admin=True)

        group_prefs_response = await run_in_threadpool(
            lambda: db.client.table("group_models")
            .select("*")
            .eq("trip_id", trip_id)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        group_prefs = group_prefs_response.data[0] if group_prefs_response.data else None
        preferences = group_prefs.get("aggregated_preferences") if group_prefs else {}
        preferences_source = "group_model" if group_prefs else "trip_context"
        if not preferences:
            preferences = await run_in_threadpool(
                lambda: _build_group_preferences_from_members(db, trip)
            )
            if preferences:
                preferences_source = "member_preferences"

        candidate_limit = max(limit * 3, 30)
        pois = await run_in_threadpool(
            lambda: ai_poi_service.get_pois_for_destination(
                destination,
                limit=candidate_limit,
                require_coordinates=True,
            )
        )
        pois = [
            poi for poi in pois
            if _as_float(poi.get("latitude") or poi.get("lat")) is not None
            and _as_float(poi.get("longitude") or poi.get("lng") or poi.get("lon")) is not None
        ]

        if not pois:
            return StarterPlanResponse(
                trip_id=trip_id,
                days=[],
                recommended_places=[],
                total_cost=0.0,
                total_days=0,
                optimization_score=0.0,
                generated_at=datetime.now().isoformat(),
                strategy="smart_scheduler",
                preferences_source=preferences_source,
            )

        pois = place_enrichment_service.merge_pois_with_cached_enrichments(pois, destination)

        ranked = rank_recommendations(pois, preferences or {}, trip, limit=limit)
        scheduler_places = [
            _starter_scheduler_place(poi, score)
            for poi, score, _reason in ranked
        ]
        generated = build_smart_itinerary(trip, scheduler_places, pace=pace)

        poi_by_id = {_poi_identifier(poi): poi for poi, _score, _reason in ranked}
        meta_by_id = {
            _poi_identifier(poi): {"score": score, "reason": reason}
            for poi, score, reason in ranked
        }
        scheduled_by_id: Dict[str, Dict[str, Any]] = {}
        response_days = []

        for day in generated.days:
            activities = []
            for activity in day.get("activities", []):
                place_id = str(activity.get("id") or activity.get("name") or "")
                poi = poi_by_id.get(place_id) or {}
                meta = meta_by_id.get(place_id, {})
                poi_response = _recommendation_poi_response(poi or activity, destination)
                scheduled_by_id[place_id] = {
                    "day": day.get("day"),
                    "start_time": activity.get("start_time"),
                    "end_time": activity.get("end_time"),
                }
                activities.append({
                    "id": poi_response.id,
                    "name": activity.get("name") or poi_response.name,
                    "type": activity.get("type") or poi_response.type,
                    "location": poi_response.location,
                    "start_time": activity.get("start_time"),
                    "end_time": activity.get("end_time"),
                    "duration_minutes": _duration_minutes(
                        activity.get("start_time"),
                        activity.get("end_time"),
                    ),
                    "cost": 0.0,
                    "description": meta.get("reason") or activity.get("description"),
                    "priority": 1,
                    "coordinates": poi_response.coordinates,
                    "rating": poi_response.rating,
                    "user_ratings_total": poi_response.user_ratings_total,
                    "photo_url": poi_response.image_url,
                    "image_url": poi_response.image_url,
                    "fsq_id": poi.get("fsq_id"),
                    "external_place_id": poi_response.external_place_id,
                    "address": poi_response.address,
                    "latitude": poi_response.latitude,
                    "longitude": poi_response.longitude,
                })

            response_days.append({
                "day": day.get("day"),
                "date": str(day.get("date") or f"Day {day.get('day')}"),
                "activities": activities,
                "total_cost": day.get("total_cost", 0.0),
                "total_duration_minutes": day.get("total_duration_minutes", 0),
            })

        recommended_places = []
        for poi, score, reason in ranked:
            place_id = _poi_identifier(poi)
            schedule = scheduled_by_id.get(place_id, {})
            recommended_places.append({
                "poi": _recommendation_poi_response(poi, destination),
                "score": score,
                "reason": reason,
                "day": schedule.get("day"),
                "start_time": schedule.get("start_time"),
                "end_time": schedule.get("end_time"),
            })

        return StarterPlanResponse(
            trip_id=trip_id,
            days=response_days,
            recommended_places=recommended_places,
            total_cost=generated.total_cost,
            total_days=len(response_days),
            optimization_score=generated.fitness_score,
            generated_at=datetime.now().isoformat(),
            strategy=generated.strategy,
            preferences_source=preferences_source,
        )

    except HTTPException:
        raise
    except Exception:
        logger.exception("Failed to generate starter plan")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate starter plan",
        )


@router.get("/{trip_id}/recommendations", response_model=List[RecommendationResponse])
async def get_trip_recommendations(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
    limit: int = Query(20, description="Number of recommendations to return")
):
    """Get personalized POI recommendations"""
    user_id, token = user_context
    
    try:
        trip = await check_trip_access(trip_id, user_id, token=token, required_role="view")
        
        db = SupabaseDB(admin=True)
        destination = (trip.get("destination") or trip.get("location") or "").strip()
        if not destination:
            return []
        limit = max(1, min(limit, 100))
        
        group_prefs_response = await run_in_threadpool(
            lambda: db.client.table("group_models").select("*")
            .eq("trip_id", trip_id)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        
        group_prefs = group_prefs_response.data[0] if group_prefs_response.data else None
        
        candidate_limit = max(limit * 3, 30)
        pois = await run_in_threadpool(
            lambda: ai_poi_service.get_pois_for_destination(
                destination,
                limit=candidate_limit,
                require_coordinates=True,
            )
        )
        pois = [
            poi for poi in pois
            if _as_float(poi.get("latitude") or poi.get("lat")) is not None
            and _as_float(poi.get("longitude") or poi.get("lng") or poi.get("lon")) is not None
        ]

        if not pois:
            return []

        pois = place_enrichment_service.merge_pois_with_cached_enrichments(pois, destination)

        ranked = rank_recommendations(
            pois,
            group_prefs.get("aggregated_preferences") if group_prefs else {},
            trip,
            limit=limit,
        )

        recommendations = []
        for poi, score, reason in ranked:
            recommendations.append(RecommendationResponse(
                poi=_recommendation_poi_response(poi, destination),
                score=score,
                reason=reason
            ))

        return recommendations
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to get recommendations")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve recommendations"
        )


@router.post("/{trip_id}/recommendations/selected")
async def mark_recommendations_selected(
    trip_id: str,
    poi_ids: List[str],
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """Mark selected POIs for CF learning"""
    user_id, token = user_context
    
    try:
        await check_trip_access(trip_id, user_id, token=token, required_role="view")
        
        db = SupabaseDB(admin=True)
        
        for poi_id in poi_ids:
            selection_data = {
                "trip_id": trip_id,
                "poi_id": poi_id,
                "selected": True,
                "selection_type": "user_choice"
            }
            
            await run_in_threadpool(
                lambda: db.client.table("poi_selections").insert(selection_data).execute()
            )
        
        return {
            "message": f"Recorded {len(poi_ids)} POI selections",
            "trip_id": trip_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to record selections")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to record selections"
        )


# ==================== Place Endpoints ====================

@router.get("/{trip_id}/places")
async def list_trip_places(
    trip_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """List all places added to a trip (members only)."""
    user_id, token = user_context
    await check_trip_access(trip_id, user_id, token=token, required_role="member")
    db = SupabaseDB(admin=True)
    res = await run_in_threadpool(
        lambda: db.client.table("trip_places")
        .select("*")
        .eq("trip_id", trip_id)
        .order("added_at", desc=False)
        .execute()
    )
    rows = res.data or []
    if not rows:
        return []
    adder_ids = list({r["added_by"] for r in rows if r.get("added_by")})
    profiles_resp = await run_in_threadpool(
        lambda: db.client.table("profiles").select("id, full_name, avatar_url").in_("id", adder_ids).execute()
    )
    by_id = {p["id"]: p for p in (profiles_resp.data or [])}
    return [
        {**r, "added_by_profile": by_id.get(r.get("added_by"))}
        for r in rows
    ]


@router.post("/{trip_id}/places/check-duplicate")
async def check_place_duplicate(
    trip_id: str,
    place_data: dict,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """
    Check if a place already exists in the trip.
    
    Duplicate detection rules:
    1. Prefer external_place_id for matching
    2. Fallback to (name + latitude + longitude)
    3. Include trip_id in check
    
    Returns:
    {
        "already_exists": bool,
        "message": str,
        "place_id": str (if exists)
    }
    """
    user_id, token = user_context
    
    try:
        await check_trip_access(trip_id, user_id, token=token, required_role="view")
        
        external_place_id = place_data.get("external_place_id")
        name = place_data.get("name")
        latitude = place_data.get("latitude")
        longitude = place_data.get("longitude")
        
        db = SupabaseDB(admin=True)
        
        # Try to find by external_place_id first
        if external_place_id:
            result = await run_in_threadpool(
                lambda: db.client.table("trip_places").select("id").eq("trip_id", trip_id).eq("external_place_id", external_place_id).execute()
            )
            
            if result.data:
                return {
                    "already_exists": True,
                    "message": f"This place is already in your trip",
                    "place_id": result.data[0]["id"]
                }
        
        # Fallback to name + lat/lng if no external_place_id
        if name and latitude is not None and longitude is not None:
            result = await run_in_threadpool(
                lambda: db.client.table("trip_places").select("id").eq("trip_id", trip_id).eq("name", name).eq("latitude", latitude).eq("longitude", longitude).execute()
            )
            
            if result.data:
                return {
                    "already_exists": True,
                    "message": f"{name} is already in your trip",
                    "place_id": result.data[0]["id"]
                }
        
        return {
            "already_exists": False,
            "message": "Place is not in trip"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"Failed to check place duplicate: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to check place duplicate"
        )


@router.post("/{trip_id}/places/add")
async def add_place_to_trip(
    trip_id: str,
    place_data: dict,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """
    Add a place to the trip with duplicate detection.
    
    Expected place_data:
    {
        "external_place_id": str,
        "name": str,
        "latitude": float,
        "longitude": float,
        "address": str,
        "rating": float,
        "user_ratings_total": int,
        "types": list,
        "image_url": str (optional)
    }
    
    Returns:
    {
        "success": bool,
        "id": str (place id),
        "already_exists": bool,
        "message": str
    }
    """
    user_id, token = user_context
    
    try:
        await check_trip_access(trip_id, user_id, token=token, required_role="edit")
        
        external_place_id = place_data.get("external_place_id")
        name = place_data.get("name")
        latitude = place_data.get("latitude")
        longitude = place_data.get("longitude")
        address = place_data.get("address", "")
        rating = place_data.get("rating")
        user_ratings_total = place_data.get("user_ratings_total")
        types = place_data.get("types", [])
        image_url = place_data.get("image_url") or place_data.get("photo_url")
        if not image_url and isinstance(place_data.get("images"), list):
            for image in place_data["images"]:
                if isinstance(image, dict) and image.get("url"):
                    image_url = image["url"]
                    break
        
        if not name or latitude is None or longitude is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Missing required fields: name, latitude, longitude"
            )
        
        db = SupabaseDB(admin=True)
        
        # Check for duplicates first
        # Try external_place_id
        if external_place_id:
            result = await run_in_threadpool(
                lambda: db.client.table("trip_places").select("id").eq("trip_id", trip_id).eq("external_place_id", external_place_id).execute()
            )
            
            if result.data:
                return {
                    "success": False,
                    "already_exists": True,
                    "id": result.data[0]["id"],
                    "message": f"{name} is already in your trip"
                }
        
        # Fallback to name + lat/lng
        result = await run_in_threadpool(
            lambda: db.client.table("trip_places").select("id").eq("trip_id", trip_id).eq("name", name).eq("latitude", latitude).eq("longitude", longitude).execute()
        )
        
        if result.data:
            return {
                "success": False,
                "already_exists": True,
                "id": result.data[0]["id"],
                "message": f"{name} is already in your trip"
            }
        
        # Place doesn't exist, insert it
        place_record = {
            "trip_id": trip_id,
            "name": name,
            "address": address,
            "latitude": latitude,
            "longitude": longitude,
            "rating": rating,
            "user_ratings_total": user_ratings_total,
            "place_types": types,
            "added_by": user_id,
            "added_at": datetime.utcnow().isoformat()
        }
        
        # Add optional fields only if they have values
        if external_place_id:
            place_record["external_place_id"] = external_place_id
        if image_url:
            place_record["image_url"] = image_url
        
        insert_result = await run_in_threadpool(
            lambda: db.client.table("trip_places").insert(place_record).execute()
        )
        
        if insert_result.data:
            place_id = insert_result.data[0]["id"]
            logger.info(f"Added place {name} ({place_id}) to trip {trip_id}")
            return {
                "success": True,
                "already_exists": False,
                "id": place_id,
                "message": f"✓ {name} added to your trip"
            }
        else:
            raise Exception("Insert returned no data")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"Failed to add place to trip: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to add place to trip: {str(e)}"
        )

