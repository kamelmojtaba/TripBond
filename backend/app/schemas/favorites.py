"""
Favorites Schemas

Pydantic models for favorites request/response validation.
"""
from pydantic import BaseModel
from typing import Optional


class FavoriteResponse(BaseModel):
    id: str
    user_id: str
    trip_id: Optional[str] = None
    destination_name: Optional[str] = None
    destination_type: Optional[str] = None  # 'trip', 'location', 'activity', 'poi'
    created_at: Optional[str] = None


class AddFavoriteRequest(BaseModel):
    trip_id: Optional[str] = None
    destination_name: Optional[str] = None
    destination_type: Optional[str] = None
    poi_id: Optional[str] = None
