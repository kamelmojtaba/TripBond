"""
Smart Itinerary Scheduler

Builds a multi-day plan from a list of places. Designed to consume the
top-voted ``trip_places`` rows for a trip and produce day-by-day activities
that respect:

* Place category (meals scheduled at meal times, attractions in their best
  visiting window, nightlife at night, etc).
* Distance between consecutive activities (nearest-neighbour ordering per
  day so we don't zig-zag across the city).
* Trip duration (places are distributed across all days of the trip, not
  jammed into the first day).
* Pace (relaxed / moderate / fast) which controls activities per day.

This module contains pure, deterministic logic so it is easy to test in
isolation. The backend itinerary service wraps it with persistence.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta, time
from math import asin, cos, radians, sin, sqrt
from typing import Any, Dict, Iterable, List, Optional, Tuple


PACE_DEFAULTS = {
    "relaxed": {"per_day": 3, "start_hour": 10},
    "moderate": {"per_day": 4, "start_hour": 9},
    "fast": {"per_day": 5, "start_hour": 8},
}


# Categories we recognise. Order matters: we pick the first matching tag.
CATEGORY_RULES = [
    ("meal", {"restaurant", "food", "cafe", "bakery", "bar"}),
    ("nightlife", {"night_club", "nightlife", "bar"}),
    ("nature", {"park", "natural_feature", "beach", "garden", "zoo"}),
    ("museum", {"museum", "art_gallery", "library"}),
    ("religious", {"mosque", "church", "temple", "synagogue", "place_of_worship"}),
    ("shopping", {"shopping_mall", "store", "supermarket", "market"}),
    ("entertainment", {"amusement_park", "movie_theater", "cinema", "stadium", "aquarium"}),
    ("landmark", {"landmark", "tourist_attraction", "historical", "monument"}),
]

# Best time-of-day slot for each category (hour of day).
CATEGORY_BEST_HOUR = {
    "meal": 13,
    "nightlife": 21,
    "nature": 9,
    "museum": 11,
    "religious": 16,
    "shopping": 15,
    "entertainment": 17,
    "landmark": 10,
    "activity": 11,
}

# Average duration per category (minutes)
CATEGORY_DURATION = {
    "meal": 75,
    "nightlife": 120,
    "nature": 120,
    "museum": 90,
    "religious": 45,
    "shopping": 90,
    "entertainment": 120,
    "landmark": 90,
    "activity": 90,
}


@dataclass
class ScheduledActivity:
    place_id: Optional[str]
    title: str
    category: str
    day_index: int
    start_time: str  # HH:MM
    end_time: str  # HH:MM
    latitude: Optional[float]
    longitude: Optional[float]
    rating: Optional[float]
    score: float
    notes: str = ""


@dataclass
class GeneratedItinerary:
    days: List[Dict[str, Any]] = field(default_factory=list)
    total_cost: float = 0.0
    fitness_score: float = 0.0
    strategy: str = "smart_scheduler"


def _haversine_km(a: Tuple[float, float], b: Tuple[float, float]) -> float:
    lat1, lon1 = a
    lat2, lon2 = b
    R = 6371.0
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    h = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
    return 2 * R * asin(sqrt(h))


def categorize(place_types: Optional[Iterable[str]]) -> str:
    types = {str(t).lower() for t in (place_types or [])}
    for category, matches in CATEGORY_RULES:
        if types & matches:
            return category
    return "activity"


def _normalize_place(p: Dict[str, Any]) -> Dict[str, Any]:
    """Coerce a trip_places row (or generic dict) into the scheduler's shape."""
    types = p.get("place_types") or p.get("types") or []
    if isinstance(types, str):
        types = [types]
    lat = p.get("latitude") or p.get("lat")
    lng = p.get("longitude") or p.get("lng") or p.get("lon")
    rating = p.get("rating") or 0.0
    score = p.get("vote_score")
    if score is None:
        score = float(rating)
    return {
        "id": p.get("id"),
        "name": p.get("name") or p.get("title") or "Activity",
        "category": categorize(types),
        "latitude": float(lat) if lat is not None else None,
        "longitude": float(lng) if lng is not None else None,
        "rating": float(rating) if rating else None,
        "score": float(score),
        "address": p.get("address"),
        "image_url": p.get("image_url") or p.get("photo_url"),
        "external_place_id": p.get("external_place_id"),
        "raw": p,
    }


def _split_into_days(places: List[Dict[str, Any]], num_days: int, per_day: int) -> List[List[Dict[str, Any]]]:
    """Distribute places across days while ensuring each day has roughly per_day items.

    Higher-scored places land on earlier days (greedy day fill). If we have
    fewer places than capacity, days will simply be shorter; if we have more,
    later places spill into the last day or are dropped.
    """
    if num_days < 1:
        num_days = 1
    sorted_places = sorted(places, key=lambda p: p["score"], reverse=True)
    capacity = per_day * num_days
    sorted_places = sorted_places[:capacity]

    buckets: List[List[Dict[str, Any]]] = [[] for _ in range(num_days)]
    # Round-robin highest scores so each day gets a strong anchor.
    for idx, place in enumerate(sorted_places):
        buckets[idx % num_days].append(place)
    return buckets


def _order_by_distance(places: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Nearest-neighbour ordering: start from the highest-rated place, then
    repeatedly pick the closest remaining one."""
    if len(places) <= 2:
        return list(places)
    remaining = list(places)
    # start with the best-scored one we have
    remaining.sort(key=lambda p: p["score"], reverse=True)
    start = remaining.pop(0)
    ordered = [start]
    current = start
    while remaining:
        if current.get("latitude") is None or current.get("longitude") is None:
            # No coords - fall back to score order
            remaining.sort(key=lambda p: p["score"], reverse=True)
            ordered.extend(remaining)
            return ordered
        candidates = [p for p in remaining if p.get("latitude") is not None and p.get("longitude") is not None]
        if not candidates:
            ordered.extend(remaining)
            return ordered
        nxt = min(
            candidates,
            key=lambda p: _haversine_km(
                (current["latitude"], current["longitude"]),
                (p["latitude"], p["longitude"]),
            ),
        )
        ordered.append(nxt)
        remaining.remove(nxt)
        current = nxt
    return ordered


def _category_priority_for_slot(category: str) -> int:
    """Lower number == should be earlier in the day (used as secondary sort)."""
    return CATEGORY_BEST_HOUR.get(category, 11)


def _slot_day(places: List[Dict[str, Any]], start_hour: int) -> List[ScheduledActivity]:
    """Given an ordered list of places for one day, assign realistic start/end times."""
    if not places:
        return []
    # Re-order by best hour while trying to preserve nearest-neighbour grouping.
    # We do a stable insertion-sort by category priority within each "cluster" of 3.
    ordered: List[Dict[str, Any]] = []
    cluster: List[Dict[str, Any]] = []
    for p in places:
        cluster.append(p)
        if len(cluster) >= 3:
            cluster.sort(key=lambda x: _category_priority_for_slot(x["category"]))
            ordered.extend(cluster)
            cluster = []
    if cluster:
        cluster.sort(key=lambda x: _category_priority_for_slot(x["category"]))
        ordered.extend(cluster)

    activities: List[ScheduledActivity] = []
    cursor = datetime(2000, 1, 1, start_hour, 0)
    for idx, p in enumerate(ordered):
        duration = CATEGORY_DURATION.get(p["category"], 90)
        # Buffer for travel between activities (10 min default, more if categories differ).
        travel_buffer = 0
        if idx > 0:
            prev = ordered[idx - 1]
            if prev.get("latitude") and p.get("latitude"):
                dist = _haversine_km(
                    (prev["latitude"], prev["longitude"]),
                    (p["latitude"], p["longitude"]),
                )
                # 30 km/h average urban -> minutes
                travel_buffer = max(10, int(dist / 30 * 60))
            else:
                travel_buffer = 15
        cursor = cursor + timedelta(minutes=travel_buffer)
        # Snap meal categories close to typical meal hours.
        if p["category"] == "meal":
            best = CATEGORY_BEST_HOUR["meal"]
            if cursor.hour < best - 2:
                cursor = cursor.replace(hour=best, minute=0)
            elif cursor.hour > best + 4:
                # Push meal to dinner time
                cursor = cursor.replace(hour=19, minute=0)
        end_cursor = cursor + timedelta(minutes=duration)
        activities.append(
            ScheduledActivity(
                place_id=p.get("id"),
                title=p["name"],
                category=p["category"],
                day_index=0,  # filled in by caller
                start_time=cursor.strftime("%H:%M"),
                end_time=end_cursor.strftime("%H:%M"),
                latitude=p.get("latitude"),
                longitude=p.get("longitude"),
                rating=p.get("rating"),
                score=p["score"],
                notes=p.get("address") or "",
            )
        )
        cursor = end_cursor
    return activities


def build_smart_itinerary(
    trip: Dict[str, Any],
    places: List[Dict[str, Any]],
    pace: str = "moderate",
) -> GeneratedItinerary:
    """Top-level entry: build a complete multi-day itinerary."""
    if not places:
        return GeneratedItinerary(days=[], total_cost=0.0, fitness_score=0.0)

    pace_cfg = PACE_DEFAULTS.get(pace, PACE_DEFAULTS["moderate"])
    per_day = pace_cfg["per_day"]
    start_hour = pace_cfg["start_hour"]

    # Compute number of days from trip dates (default to 1 if missing).
    num_days = 1
    start_date_obj: Optional[datetime] = None
    if trip.get("start_date") and trip.get("end_date"):
        try:
            start_date_obj = datetime.fromisoformat(str(trip["start_date"]))
            end_date_obj = datetime.fromisoformat(str(trip["end_date"]))
            num_days = max(1, (end_date_obj.date() - start_date_obj.date()).days + 1)
        except ValueError:
            pass

    normalized = [_normalize_place(p) for p in places]
    day_buckets = _split_into_days(normalized, num_days=num_days, per_day=per_day)

    days: List[Dict[str, Any]] = []
    total_cost = 0.0
    score_sum = 0.0
    score_count = 0

    for day_idx, bucket in enumerate(day_buckets, start=1):
        if not bucket:
            continue
        ordered = _order_by_distance(bucket)
        scheduled = _slot_day(ordered, start_hour=start_hour)
        for a in scheduled:
            a.day_index = day_idx
            score_sum += a.score
            score_count += 1
        day_date = (
            (start_date_obj + timedelta(days=day_idx - 1)).date().isoformat()
            if start_date_obj
            else f"Day {day_idx}"
        )
        days.append(
            {
                "day": day_idx,
                "date": day_date,
                "activities": [
                    {
                        "id": a.place_id,
                        "name": a.title,
                        "title": a.title,
                        "type": a.category,
                        "category": a.category,
                        "location": a.notes or trip.get("destination") or "Unknown",
                        "start_time": a.start_time,
                        "end_time": a.end_time,
                        "latitude": a.latitude,
                        "longitude": a.longitude,
                        "rating": a.rating,
                        "score": round(a.score, 2),
                        "description": a.notes,
                        "address": a.notes or None,
                    }
                    for a in scheduled
                ],
                "total_cost": 0.0,
                "total_duration_minutes": sum(
                    CATEGORY_DURATION.get(a.category, 90) for a in scheduled
                ),
            }
        )

    fitness = (score_sum / score_count) if score_count else 0.0
    return GeneratedItinerary(
        days=days,
        total_cost=total_cost,
        fitness_score=round(fitness, 3),
        strategy="smart_scheduler",
    )
