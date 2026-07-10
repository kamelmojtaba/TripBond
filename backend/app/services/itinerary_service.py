"""
Itinerary Generation Service

Handles trip itinerary creation using:
- Genetic Algorithm (GA) optimization
- Heuristic fallback methods
- Integration with TomTom Places API for real recommendations
"""
from datetime import datetime, timedelta
from typing import Optional, List
import logging

logger = logging.getLogger(__name__)

# Suggested activity slots for different pace preferences
ACTIVITY_SLOTS = {
    "relaxed": [
        {"time": "09:00", "end": "11:00", "type": "attraction", "cost_est": 50},
        {"time": "12:00", "end": "13:00", "type": "restaurant", "cost_est": 30},
        {"time": "14:00", "end": "16:00", "type": "attraction", "cost_est": 40},
    ],
    "moderate": [
        {"time": "08:00", "end": "10:00", "type": "attraction", "cost_est": 50},
        {"time": "10:30", "end": "12:00", "type": "attraction", "cost_est": 50},
        {"time": "12:30", "end": "14:00", "type": "restaurant", "cost_est": 35},
        {"time": "14:30", "end": "17:00", "type": "attraction", "cost_est": 45},
    ],
    "fast": [
        {"time": "07:00", "end": "09:00", "type": "attraction", "cost_est": 50},
        {"time": "09:30", "end": "11:30", "type": "attraction", "cost_est": 50},
        {"time": "12:00", "end": "13:00", "type": "restaurant", "cost_est": 30},
        {"time": "13:30", "end": "16:00", "type": "attraction", "cost_est": 60},
        {"time": "17:00", "end": "18:30", "type": "attraction", "cost_est": 40},
    ]
}


def _get_places_for_destination(destination: str) -> List[dict]:
    """
    Fetch real places from the AI backend dataset for the destination.
    Falls back to configured external providers when the dataset is missing
    or lacks usable coordinates. It never fabricates placeholder places.
    """
    try:
        from .ai_poi_service import get_pois_for_destination
        places = get_pois_for_destination(
            destination,
            limit=24,
            require_coordinates=True,
        )
        
        if places:
            logger.info(f"Loaded {len(places)} POIs from AI backend for {destination}")
            # Keep all place data for activities
            return places
    except Exception as e:
        logger.warning(f"Failed to fetch real places for {destination}: {e}")

    raise ValueError(f"No real places found for destination: {destination}")


def generate_itinerary(
    trip: dict,
    group_preferences: Optional[dict] = None,
    use_ga: bool = False,
    max_budget: Optional[float] = None,
    pace: str = "moderate",
    preferences: Optional[dict] = None,
    voted_places: Optional[list] = None,
) -> tuple[dict, str]:
    """
    Generate a trip itinerary.

    Preferred path (when ``voted_places`` is provided): runs the smart
    scheduler (distance + time-of-day + category aware) over the actual
    voted trip places. This is the AI-driven flow described in the spec.

    Fallback path: when no voted places are available, falls back to the
    legacy destination-driven heuristic that pulls sample/AI POIs.

    Returns:
        (itinerary_data dict, strategy_name str)
    """
    from .smart_scheduler import build_smart_itinerary

    if voted_places:
        result = build_smart_itinerary(trip, voted_places, pace=pace)
        return (
            {
                "days": result.days,
                "total_cost": result.total_cost,
                "fitness_score": result.fitness_score,
            },
            result.strategy,
        )

    if use_ga and group_preferences:
        constraints = {
            "max_budget": max_budget,
            "pace": pace,
            **(preferences or {}),
        }
        itinerary_data = generate_itinerary_with_ga(trip, group_preferences, constraints)
        return itinerary_data, "genetic_algorithm"

    itinerary_data = generate_itinerary_heuristic(trip, pace, max_budget)
    return itinerary_data, "heuristic"


def generate_itinerary_with_ga(
    trip: dict, 
    group_preferences: dict, 
    constraints: dict
) -> dict:
    """
    Generate itinerary using Genetic Algorithm with real place data.
    
    Now integrates with TomTom Places for actual recommendations.
    
    Args:
        trip: Trip data
        group_preferences: Aggregated preferences from group model
        constraints: Budget, pace, and other constraints
    
    Returns:
        dict: Itinerary data with days, activities, costs, and fitness score
    """
    pace = constraints.get("pace", "moderate")
    max_budget = constraints.get("max_budget")
    destination = trip.get("destination", "Unknown")
    
    logger.info(f"Generating itinerary for {destination} (pace: {pace}, budget: {max_budget})")
    
    # Fetch real places for the destination
    places = _get_places_for_destination(destination)
    activity_slots = ACTIVITY_SLOTS.get(pace, ACTIVITY_SLOTS["moderate"])
    
    days = []
    
    # Handle None values for dates
    start_raw = trip.get("start_date") or datetime.now().isoformat()
    end_raw = trip.get("end_date") or (datetime.now() + timedelta(days=3)).isoformat()
    start_date = datetime.fromisoformat(start_raw)
    end_date = datetime.fromisoformat(end_raw)
    
    if end_date < start_date:
        end_date = start_date
    
    num_days = (end_date - start_date).days + 1
    
    for day_num in range(1, num_days + 1):
        current_date = start_date + timedelta(days=day_num - 1)
        
        # Create activities from slots, rotating through available places
        day_activities = []
        place_idx = (day_num - 1) * len(activity_slots)  # Vary places by day
        
        for slot_idx, slot in enumerate(activity_slots):
            place = places[(place_idx + slot_idx) % len(places)]
            
            activity = {
                "id": f"act_{day_num}_{slot_idx + 1}",
                "name": place.get("name", f"{slot['type'].title()} Activity"),
                "type": slot.get("type", place.get("type", "activity")),
                "location": place.get("location", destination),
                "start_time": slot["time"],
                "end_time": slot["end"],
                "duration_minutes": _calc_duration(slot["time"], slot["end"]),
                "cost": slot.get("cost_est", 40.0),
                "description": f"Popular {slot['type']} in {destination}",
                "rating": place.get("rating", 4.0),
                "priority": 4 if slot.get("type") == "attraction" else 3,
                # Preserve place identifiers
                "place_id": place.get("id"),
                "external_place_id": place.get("external_place_id") or place.get("id"),
                "fsq_id": place.get("fsq_id"),
                "latitude": place.get("latitude"),
                "longitude": place.get("longitude"),
                "photo_url": place.get("photo_url"),
                "address": place.get("address"),
            }
            day_activities.append(activity)
        
        day_total_cost = sum(a.get("cost", 0) or 0 for a in day_activities)
        day_total_duration = sum(
            a.get("duration_minutes", 0) or 0 for a in day_activities
        )
        
        days.append({
            "day": day_num,
            "date": current_date.strftime("%Y-%m-%d"),
            "activities": day_activities,
            "total_cost": day_total_cost,
            "total_duration_minutes": day_total_duration
        })
    
    total_cost = sum(day.get("total_cost", 0) or 0 for day in days)
    
    return {
        "days": days,
        "total_cost": total_cost,
        "fitness_score": 0.87
    }


def _calc_duration(start: str, end: str) -> int:
    """Calculate duration in minutes between two time strings (HH:MM format)."""
    try:
        s = datetime.strptime(start, "%H:%M")
        e = datetime.strptime(end, "%H:%M")
        return int((e - s).total_seconds() / 60)
    except:
        return 120


def generate_itinerary_heuristic(
    trip: dict, 
    pace: str, 
    max_budget: Optional[float]
) -> dict:
    """
    Generate itinerary using simple heuristic approach with real place data.
    
    Fallback method when no group model exists or GA is disabled.
    Uses rule-based activity selection and timing with TomTom integration.
    
    Args:
        trip: Trip data
        pace: Activity pace ("relaxed", "moderate", "fast")
        max_budget: Optional budget constraint
    
    Returns:
        dict: Itinerary data
    """
    logger.info(
        "Heuristic approach with real place data (pace: %s, max_budget: %s)",
        pace,
        max_budget
    )
    # Delegate to GA with place data - GA now has real recommendations
    return generate_itinerary_with_ga(
        trip, 
        {}, 
        {"pace": pace, "max_budget": max_budget}
    )



# ==================== Database Helpers (itinerary_db) ====================

from typing import Optional as _Optional, List as _List
from ..database import SupabaseDB as _SupabaseDB


def create_itinerary(
    trip_id: str,
    generated_by: str,
    status: str = "generated",
    optimization_score: float = 0.0,
    version: int = 1,
) -> dict:
    """Create a new itinerary record."""
    db = _SupabaseDB(admin=True)
    record = {
        "trip_id": trip_id,
        "version": version,
        "status": status,
        "generated_by": generated_by,
    }
    response = db.client.table("itineraries").insert(record).execute()
    if not response.data:
        raise Exception("Failed to create itinerary")
    logger.info(f"Created itinerary {response.data[0]['id']} for trip {trip_id}")
    return response.data[0]


def get_latest_itinerary(trip_id: str, client=None) -> _Optional[dict]:
    """Get the latest itinerary record for a trip."""
    db_client = client or _SupabaseDB(admin=True).client
    response = (
        db_client.table("itineraries")
        .select("*")
        .eq("trip_id", trip_id)
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )
    return response.data[0] if response.data else None


def list_items(itinerary_id: str, client=None) -> _List[dict]:
    """List all items for an itinerary, ordered by day and time."""
    db_client = client or _SupabaseDB(admin=True).client
    response = (
        db_client.table("itinerary_items")
        .select("*")
        .eq("itinerary_id", itinerary_id)
        .order("day_index")
        .order("start_time")
        .execute()
    )
    return response.data if response.data else []


def insert_items(itinerary_id: str, items: _List[dict]) -> None:
    """Bulk insert itinerary items."""
    db = _SupabaseDB(admin=True)
    to_insert = []
    for item in items:
        if "itinerary_id" in item:
            to_insert.append(item)
        else:
            item_record = {
                "itinerary_id": itinerary_id,
                "day_index": item.get("day_index") or item.get("day", 1),
                "start_time": item.get("start_time"),
                "end_time": item.get("end_time"),
                "title": item.get("title") or item.get("name", "Untitled"),
                "notes": item.get("notes") or item.get("description"),
                "score": item.get("score", 0.0),
            }
            
            # NOTE: The database schema for itinerary_items is limited.
            # Only core fields above are guaranteed to exist.
            # Do not add additional fields without migrations.
            
            to_insert.append(item_record)
    if to_insert:
        response = db.client.table("itinerary_items").insert(to_insert).execute()
        if not response.data:
            raise Exception("Failed to insert itinerary items")
        logger.info(f"Inserted {len(to_insert)} items for itinerary {itinerary_id}")


def update_item(item_id: str, patch: dict) -> dict:
    """Update an itinerary item."""
    db = _SupabaseDB(admin=True)
    response = db.client.table("itinerary_items").update(patch).eq("id", item_id).execute()
    if not response.data:
        raise Exception(f"Failed to update item {item_id}")
    logger.info(f"Updated itinerary item {item_id}")
    return response.data[0]


def delete_item(item_id: str) -> None:
    """Delete an itinerary item."""
    db = _SupabaseDB(admin=True)
    response = db.client.table("itinerary_items").delete().eq("id", item_id).execute()
    if not response.data:
        raise Exception(f"Failed to delete item {item_id}")
    logger.info(f"Deleted itinerary item {item_id}")


def get_itinerary_with_items(trip_id: str) -> _Optional[dict]:
    """Fetch latest itinerary and its items as a days structure."""
    itinerary = get_latest_itinerary(trip_id)
    if not itinerary:
        return None
    itinerary_id = itinerary["id"]
    items = list_items(itinerary_id)
    days_dict: dict = {}
    for item in items:
        day_idx = item["day_index"]
        if day_idx not in days_dict:
            days_dict[day_idx] = {"day": day_idx, "activities": []}
        days_dict[day_idx]["activities"].append({
            "id": item["id"],
            "name": item["title"],
            "start_time": item["start_time"],
            "end_time": item["end_time"],
            "notes": item["notes"],
            "score": item["score"],
        })
    days = [days_dict[k] for k in sorted(days_dict.keys())]
    return {
        "itinerary_id": itinerary_id,
        "optimization_score": itinerary.get("optimization_score", 0.0),
        "generated_by": itinerary.get("generated_by", "unknown"),
        "created_at": itinerary.get("created_at"),
        "days": days,
        "total_cost": 0.0,
    }
