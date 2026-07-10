"""
Profile Schemas

Pydantic models for request/response validation in profile endpoints.
"""
from pydantic import BaseModel
from typing import Optional
from datetime import date


class ProfileResponse(BaseModel):
    id: str
    email: str
    full_name: Optional[str] = None
    username: Optional[str] = None
    phone_number: Optional[str] = None
    date_of_birth: Optional[str] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    current_location: Optional[str] = None
    gender: Optional[str] = None
    is_public: Optional[bool] = True
    # Stats
    past_trips_count: Optional[int] = 0
    liked_pages_count: Optional[int] = 0
    favorites_count: Optional[int] = 0
    followers_count: Optional[int] = 0
    following_count: Optional[int] = 0


class UpdateProfileRequest(BaseModel):
    full_name: Optional[str] = None
    username: Optional[str] = None
    phone_number: Optional[str] = None
    date_of_birth: Optional[date] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    current_location: Optional[str] = None
    gender: Optional[str] = None
    is_public: Optional[bool] = None
