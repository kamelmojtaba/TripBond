"""
Preferences Schemas

Pydantic models for request/response validation in preferences endpoints.
"""
from pydantic import BaseModel
from typing import List, Optional


class TripPreferencesRequest(BaseModel):
    trip_id: str
    user_id: str
    activity_tags: Optional[List[str]] = None  # Array of activity preferences
    pace: Optional[str] = None  # 'slow', 'moderate', 'fast'


class TripPreferencesResponse(BaseModel):
    trip_id: str
    user_id: str
    activity_tags: Optional[List[str]] = None
    pace: Optional[str] = None
    updated_at: Optional[str] = None


class UserGeneralPreferences(BaseModel):
    """General user preferences stored in profiles table"""
    user_id: str
    budget_level: Optional[str] = None  # 'low', 'medium', 'high'
    travel_style: Optional[str] = None  # 'adventure', 'relax', 'cultural', 'luxury'
    dietary_preferences: Optional[str] = None
    preferred_accommodation: Optional[str] = None
    preferred_transport: Optional[str] = None
