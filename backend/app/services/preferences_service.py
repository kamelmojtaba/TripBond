"""
Preferences Service

Handles trip-specific and general user preference CRUD operations.
Routers delegate all preferences business logic to this service.
"""
from fastapi import HTTPException, status
from typing import List, Optional
from ..database import SupabaseDB
from ..schemas.preferences import (
    TripPreferencesRequest,
    TripPreferencesResponse,
    UserGeneralPreferences,
)
import logging

logger = logging.getLogger(__name__)

# Questionnaire structure - defines all available options
TRAVEL_QUESTIONNAIRE = {
    "questions": [
        {
            "id": 1,
            "question": "What kind of trip are you planning?",
            "type": "single_choice",
            "field": "trip_type",
            "storage": "trips.trip_type",
            "options": [
                {"value": "relax", "label": "Relax and Recharge"},
                {"value": "culture", "label": "Explore Culture"},
                {"value": "adventure", "label": "Adventure and Nature"},
                {"value": "food", "label": "Food and Cafes"},
                {"value": "family", "label": "Family Fun"},
                {"value": "nightlife", "label": "Nightlife"},
            ],
        },
        {
            "id": 2,
            "question": "What two activities excite you the most?",
            "type": "multiple_choice",
            "field": "activity_tags",
            "storage": "trip_preferences.activity_tags",
            "max_selections": 2,
            "options": [
                {"value": "museums", "label": "Museums"},
                {"value": "dive_fun", "label": "Dive/Fun"},
                {"value": "hiking", "label": "Hiking"},
                {"value": "landmarks", "label": "Landmarks"},
                {"value": "local_dessert", "label": "Local Dessert"},
                {"value": "theme_parks", "label": "Theme Parks"},
            ],
        },
        {
            "id": 3,
            "question": "What is your estimated daily budget (in SAR)?",
            "type": "single_choice",
            "field": "budget_level",
            "storage": "profiles.budget_level",
            "options": [
                {"value": "low", "label": "50 to 100 SAR"},
                {"value": "medium", "label": "200 to 500 SAR"},
                {"value": "high", "label": "500 SAR and above"},
            ],
        },
        {
            "id": 4,
            "question": "Who are you traveling with?",
            "type": "single_choice",
            "field": "travel_companions",
            "storage": "metadata",
            "options": [
                {"value": "solo", "label": "Solo"},
                {"value": "friends", "label": "Friends"},
                {"value": "family", "label": "Family"},
                {"value": "couple", "label": "Couple"},
            ],
        },
        {
            "id": 5,
            "question": "What is your preferred pace?",
            "type": "single_choice",
            "field": "pace",
            "storage": "trip_preferences.pace",
            "options": [
                {"value": "slow", "label": "Relaxed & Flexible"},
                {"value": "moderate", "label": "Balanced"},
                {"value": "fast", "label": "Packed & Efficient"},
            ],
        },
        {
            "id": 6,
            "question": "Select any options that are important for your comfort",
            "type": "multiple_choice",
            "field": "comfort_tags",
            "storage": "trip_preferences.activity_tags",
            "options": [
                {"value": "luxury", "label": "Luxury Travel"},
                {"value": "prayer_rooms", "label": "Hotels (prayer rooms)"},
                {"value": "accessibility", "label": "Accessibility requests"},
                {"value": "halal_friendly", "label": "Halal Friendly"},
            ],
        },
    ]
}


def get_questionnaire() -> dict:
    """Return the travel preferences questionnaire."""
    return TRAVEL_QUESTIONNAIRE


def submit_trip_preferences(preferences: TripPreferencesRequest) -> TripPreferencesResponse:
    """Create or update trip-specific preferences."""
    db = SupabaseDB()

    prefs_data = {k: v for k, v in {
        "trip_id": preferences.trip_id,
        "user_id": preferences.user_id,
        "activity_tags": preferences.activity_tags,
        "pace": preferences.pace,
    }.items() if v is not None}

    existing = db.client.table("trip_preferences").select("*").eq(
        "trip_id", preferences.trip_id
    ).eq("user_id", preferences.user_id).execute()

    if existing.data:
        response = db.client.table("trip_preferences").update(prefs_data).eq(
            "trip_id", preferences.trip_id
        ).eq("user_id", preferences.user_id).execute()
    else:
        response = db.client.table("trip_preferences").insert(prefs_data).execute()

    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save trip preferences"
        )

    result = response.data[0]
    return TripPreferencesResponse(
        trip_id=result.get("trip_id"),
        user_id=result.get("user_id"),
        activity_tags=result.get("activity_tags"),
        pace=result.get("pace"),
        updated_at=result.get("updated_at"),
    )


def get_trip_preferences(trip_id: str, user_id: str) -> TripPreferencesResponse:
    """Get preferences for one user on a specific trip."""
    db = SupabaseDB()
    response = db.client.table("trip_preferences").select("*").eq(
        "trip_id", trip_id
    ).eq("user_id", user_id).execute()

    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trip preferences not found"
        )

    result = response.data[0]
    return TripPreferencesResponse(
        trip_id=result.get("trip_id"),
        user_id=result.get("user_id"),
        activity_tags=result.get("activity_tags"),
        pace=result.get("pace"),
        updated_at=result.get("updated_at"),
    )


def get_all_trip_preferences(trip_id: str) -> List[TripPreferencesResponse]:
    """Get preferences for all members of a trip."""
    db = SupabaseDB()
    response = db.client.table("trip_preferences").select("*").eq("trip_id", trip_id).execute()

    if not response.data:
        return []

    return [
        TripPreferencesResponse(
            trip_id=p.get("trip_id"),
            user_id=p.get("user_id"),
            activity_tags=p.get("activity_tags"),
            pace=p.get("pace"),
            updated_at=p.get("updated_at"),
        )
        for p in response.data
    ]


def update_trip_preferences(trip_id: str, user_id: str, preferences: TripPreferencesRequest) -> TripPreferencesResponse:
    """Update existing trip preferences for a user."""
    update_data = {}
    if preferences.activity_tags is not None:
        update_data["activity_tags"] = preferences.activity_tags
    if preferences.pace is not None:
        update_data["pace"] = preferences.pace

    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No preferences provided for update"
        )

    db = SupabaseDB()
    response = db.client.table("trip_preferences").update(update_data).eq(
        "trip_id", trip_id
    ).eq("user_id", user_id).execute()

    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trip preferences not found"
        )

    result = response.data[0]
    return TripPreferencesResponse(
        trip_id=result.get("trip_id"),
        user_id=result.get("user_id"),
        activity_tags=result.get("activity_tags"),
        pace=result.get("pace"),
        updated_at=result.get("updated_at"),
    )


def delete_trip_preferences(trip_id: str, user_id: str) -> None:
    """Delete trip preferences for a user."""
    db = SupabaseDB()
    db.client.table("trip_preferences").delete().eq(
        "trip_id", trip_id
    ).eq("user_id", user_id).execute()


def update_user_general_preferences(preferences: UserGeneralPreferences) -> UserGeneralPreferences:
    """Update general preferences stored in the profiles table."""
    update_data = {k: v for k, v in {
        "budget_level": preferences.budget_level,
        "travel_style": preferences.travel_style,
        "dietary_preferences": preferences.dietary_preferences,
        "preferred_accommodation": preferences.preferred_accommodation,
        "preferred_transport": preferences.preferred_transport,
    }.items() if v is not None}

    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No preferences provided for update"
        )

    db = SupabaseDB()
    response = db.client.table("profiles").update(update_data).eq(
        "id", preferences.user_id
    ).execute()

    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found"
        )

    profile = response.data[0]
    return UserGeneralPreferences(
        user_id=profile["id"],
        budget_level=profile.get("budget_level"),
        travel_style=profile.get("travel_style"),
        dietary_preferences=profile.get("dietary_preferences"),
        preferred_accommodation=profile.get("preferred_accommodation"),
        preferred_transport=profile.get("preferred_transport"),
    )


def get_user_general_preferences(user_id: str) -> UserGeneralPreferences:
    """Get general preferences for a user from the profiles table."""
    db = SupabaseDB()
    response = db.client.table("profiles").select(
        "id, budget_level, travel_style, dietary_preferences, preferred_accommodation, preferred_transport"
    ).eq("id", user_id).execute()

    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found"
        )

    profile = response.data[0]
    return UserGeneralPreferences(
        user_id=profile["id"],
        budget_level=profile.get("budget_level"),
        travel_style=profile.get("travel_style"),
        dietary_preferences=profile.get("dietary_preferences"),
        preferred_accommodation=profile.get("preferred_accommodation"),
        preferred_transport=profile.get("preferred_transport"),
    )
