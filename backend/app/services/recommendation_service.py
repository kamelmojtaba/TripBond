"""
Recommendation Service

Handles POI (Point of Interest) scoring and recommendation logic.
Uses preferences, trip context, and ratings to score locations.
"""
from typing import Any, Optional
import logging

logger = logging.getLogger(__name__)

# Scoring weights (adjustable parameters)
RATING_W = 0.2      # POI rating contribution
POPULARITY_W = 0.15 # Review-volume contribution
TYPE_W = 0.15       # Trip type alignment
PREF_W = 0.1        # Activity preference matching
BUDGET_W = 0.1      # Budget compatibility


def _normalise_tokens(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, dict):
        return [str(key).lower() for key, enabled in value.items() if enabled]
    if isinstance(value, (list, tuple, set)):
        return [str(item).lower() for item in value if item]
    if isinstance(value, str) and value.strip():
        return [value.strip().lower()]
    return []


def _budget_to_price_level(value: Any) -> Optional[int]:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return int(value)
    budget = str(value).strip().lower()
    return {
        "low": 1,
        "budget": 1,
        "medium": 2,
        "moderate": 2,
        "high": 3,
        "luxury": 4,
    }.get(budget)


def calculate_poi_score(
    poi: dict, 
    preferences: dict, 
    trip: dict
) -> tuple[float, str]:
    """
    Calculate relevance score for a POI based on preferences and trip context.
    
    Scoring factors:
    - Base rating (from POI data)
    - Trip type alignment (adventure, cultural, relaxing, etc.)
    - User preference matching
    - Budget compatibility
    
    Args:
        poi: POI data (name, type, tags, rating, price_level, etc.)
        preferences: User/group preferences
        trip: Trip data (type, budget, etc.)
    
    Returns:
        tuple: (score: float [0-1], reason: str)
    
    Future improvements:
    - Add distance/proximity scoring
    - Incorporate opening hours compatibility
    - Use ML model for scoring (Random Forest, etc.)
    - Learn from user selections (collaborative filtering)
    """
    # Normalize preferences to handle None safely
    preferences = preferences or {}
    
    base_score = 0.5
    reason_parts = []
    
    # Factor 1: POI rating
    if poi.get("rating"):
        rating_contribution = (poi["rating"] / 5.0) * RATING_W
        base_score += rating_contribution

    review_count = poi.get("review_count") or poi.get("user_ratings_total")
    if review_count:
        try:
            popularity = min(max(float(review_count), 0.0) / 15000.0, 1.0)
        except (TypeError, ValueError):
            popularity = 0.0
        if popularity:
            base_score += popularity * POPULARITY_W
            if popularity >= 0.5:
                reason_parts.append("popular with travelers")
    
    # Factor 2: Trip type alignment
    trip_type = str(trip.get("trip_type") or "").lower()
    poi_type = str(poi.get("poi_type") or poi.get("type") or "").lower()
    poi_tags = _normalise_tokens(poi.get("tags") or poi.get("types"))
    if poi.get("category"):
        poi_tags.append(str(poi["category"]).lower())
    
    if trip_type in ["adventure", "outdoor"] and poi_type in ["activity", "attraction"]:
        base_score += TYPE_W
        reason_parts.append("matches adventure preferences")
    elif trip_type in ["relaxing", "beach"] and poi_type in ["restaurant", "accommodation"]:
        base_score += TYPE_W
        reason_parts.append("suitable for relaxing trip")
    elif trip_type == "cultural" and ("museum" in poi_tags or "historical" in poi_tags):
        base_score += TYPE_W
        reason_parts.append("cultural significance")
    
    # Factor 3: Activity preferences matching
    if preferences:
        activity_prefs = preferences.get("activities", {})
        if isinstance(activity_prefs, dict):
            for pref_key, pref_value in activity_prefs.items():
                pref_key_l = str(pref_key).lower()
                if pref_key_l in poi_tags or pref_key_l == poi_type:
                    # Safely convert and clamp preference value to 0.0-1.0 range
                    try:
                        v = float(pref_value)
                    except (TypeError, ValueError):
                        v = 0.0
                    v = max(0.0, min(v, 1.0))  # assume weights are 0..1
                    base_score += v * PREF_W
                    reason_parts.append(f"high preference for {pref_key}")

        activity_tags = set(_normalise_tokens(
            preferences.get("activity_tags")
            or preferences.get("preferred_activities")
            or preferences.get("interests")
        ))
        if activity_tags and (activity_tags & (set(poi_tags) | {poi_type})):
            base_score += PREF_W
            reason_parts.append("matches group activity preferences")

        travel_style = str(preferences.get("travel_style") or "").lower()
        if travel_style:
            style_matches = {
                "adventure": {"activity", "attraction", "park", "nature", "outdoor"},
                "cultural": {"museum", "historical", "landmark", "art_gallery"},
                "relaxing": {"restaurant", "cafe", "beach", "park", "garden"},
                "family": {"park", "zoo", "aquarium", "amusement_park", "museum"},
            }
            matched_styles = style_matches.get(travel_style, set())
            if matched_styles and (matched_styles & (set(poi_tags) | {poi_type})):
                base_score += TYPE_W / 2
                reason_parts.append(f"fits {travel_style} travel style")
    
    # Factor 4: Budget compatibility
    budget_level = _budget_to_price_level(
        preferences.get("budget") or preferences.get("budget_level")
    )
    if budget_level and poi.get("price_level"):
        try:
            poi_price = int(float(poi["price_level"]))
        except (TypeError, ValueError):
            poi_price = None
        if poi_price is not None and poi_price <= budget_level:
            base_score += BUDGET_W
            reason_parts.append("within budget")
    
    # Build explanation
    reason = (
        "Based on " + ", ".join(reason_parts) 
        if reason_parts 
        else "Popular destination"
    )
    
    # Cap score at 1.0
    return min(base_score, 1.0), reason


def rank_recommendations(
    pois: list[dict], 
    preferences: dict, 
    trip: dict, 
    limit: int = 20
) -> list[tuple[dict, float, str]]:
    """
    Score and rank multiple POIs.
    
    Args:
        pois: List of POI data
        preferences: User/group preferences
        trip: Trip context
        limit: Maximum number of recommendations to return
    
    Returns:
        list: Tuples of (poi, score, reason) sorted by score descending
    """
    scored_pois = []
    
    for poi in pois:
        score, reason = calculate_poi_score(poi, preferences, trip)
        scored_pois.append((poi, score, reason))
    
    # Sort by score descending
    scored_pois.sort(key=lambda x: x[1], reverse=True)
    
    return scored_pois[:limit]
