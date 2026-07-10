"""
POI Schemas

Pydantic models for request/response validation in POI endpoints.
"""
from pydantic import BaseModel
from typing import List, Optional


class POIResponse(BaseModel):
    id: str
    name: str
    type: str  # 'attraction', 'restaurant', 'activity', 'accommodation', 'landmark'
    location: str
    description: Optional[str] = None
    rating: Optional[float] = None
    price_level: Optional[int] = None  # 1-4 ($, $$, $$$, $$$$)
    image_url: Optional[str] = None
    coordinates: Optional[dict] = None  # {"lat": float, "lng": float}
    tags: Optional[List[str]] = []
    opening_hours: Optional[dict] = None
    contact: Optional[dict] = None
    created_at: Optional[str] = None


class POISearchFilters(BaseModel):
    location: Optional[str] = None
    type: Optional[str] = None
    min_rating: Optional[float] = None
    max_price_level: Optional[int] = None
    tags: Optional[List[str]] = None
