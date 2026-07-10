from fastapi import APIRouter, HTTPException, status
from typing import List
from ..schemas.preferences import (
    TripPreferencesRequest,
    TripPreferencesResponse,
    UserGeneralPreferences,
)
from ..services import preferences_service

router = APIRouter()


@router.get("/questionnaire")
async def get_travel_questionnaire():
    """Get the complete travel preferences questionnaire structure."""
    return preferences_service.get_questionnaire()


@router.post("/trip/submit", response_model=TripPreferencesResponse)
async def submit_trip_preferences(preferences: TripPreferencesRequest):
    """Submit or update trip-specific preferences."""
    try:
        return preferences_service.submit_trip_preferences(preferences)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to submit trip preferences: {str(e)}"
        )


@router.get("/trip/{trip_id}/{user_id}", response_model=TripPreferencesResponse)
async def get_trip_preferences(trip_id: str, user_id: str):
    """Get trip preferences for a specific user on a specific trip."""
    try:
        return preferences_service.get_trip_preferences(trip_id, user_id)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get trip preferences: {str(e)}"
        )


@router.get("/trip/{trip_id}")
async def get_all_trip_preferences(trip_id: str):
    """Get all user preferences for a specific trip (for group comparison)."""
    try:
        preferences = preferences_service.get_all_trip_preferences(trip_id)
        return {"trip_id": trip_id, "preferences": preferences}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get trip preferences: {str(e)}"
        )


@router.put("/trip/{trip_id}/{user_id}", response_model=TripPreferencesResponse)
async def update_trip_preferences(trip_id: str, user_id: str, preferences: TripPreferencesRequest):
    """Update trip preferences for a user."""
    try:
        return preferences_service.update_trip_preferences(trip_id, user_id, preferences)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update trip preferences: {str(e)}"
        )


@router.delete("/trip/{trip_id}/{user_id}")
async def delete_trip_preferences(trip_id: str, user_id: str):
    """Delete trip preferences for a user."""
    try:
        preferences_service.delete_trip_preferences(trip_id, user_id)
        return {"message": "Trip preferences deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete trip preferences: {str(e)}"
        )


@router.post("/user/general", response_model=UserGeneralPreferences)
async def update_user_general_preferences(preferences: UserGeneralPreferences):
    """Update general user preferences (stored in profiles table)."""
    try:
        return preferences_service.update_user_general_preferences(preferences)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update user preferences: {str(e)}"
        )


@router.get("/user/general/{user_id}", response_model=UserGeneralPreferences)
async def get_user_general_preferences(user_id: str):
    """Get general user preferences from profile."""
    try:
        return preferences_service.get_user_general_preferences(user_id)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get user preferences: {str(e)}"
        )

