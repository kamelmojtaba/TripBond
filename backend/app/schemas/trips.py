"""
Trip & Itinerary Schemas

Pydantic models for request/response validation in trip-related endpoints.
"""
from pydantic import BaseModel
from typing import List, Optional
from datetime import date


# ==================== Trip Schemas ====================

class TripResponse(BaseModel):
    id: str
    created_by: str
    title: str
    destination: str
    phase: Optional[str] = "planning"
    location: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    trip_type: Optional[str] = None
    description: Optional[str] = None
    image_url: Optional[str] = None
    is_public: Optional[bool] = True
    created_at: Optional[str] = None


class CreateTripRequest(BaseModel):
    title: str
    destination: str
    location: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    trip_type: Optional[str] = None
    description: Optional[str] = None
    image_url: Optional[str] = None
    is_public: Optional[bool] = True


class UpdateTripRequest(BaseModel):
    title: Optional[str] = None
    destination: Optional[str] = None
    location: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    trip_type: Optional[str] = None
    description: Optional[str] = None
    image_url: Optional[str] = None
    is_public: Optional[bool] = None


class TripSummaryResponse(BaseModel):
    trip_id: str
    title: str
    destination: str
    phase: Optional[str] = "planning"
    member_count: int
    has_itinerary: bool
    itinerary_days: Optional[int] = 0
    is_creator: bool
    is_member: bool
    is_public: bool
    start_date: Optional[str] = None
    end_date: Optional[str] = None


class TripSummary(BaseModel):
    """Lightweight trip summary used for user trip lists."""
    id: str
    title: str
    destination: str
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    created_at: Optional[str] = None


# ==================== Member Schemas ====================

class AddMemberRequest(BaseModel):
    user_id: str


class TripMember(BaseModel):
    id: Optional[str] = None
    user_id: str
    status: str
    invited_by: Optional[str] = None
    invited_at: Optional[str] = None
    responded_at: Optional[str] = None
    joined_at: Optional[str] = None


# ==================== Itinerary Schemas ====================

class ItineraryActivity(BaseModel):
    id: Optional[str] = None
    day: Optional[int] = None
    name: str
    type: str
    location: str
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    duration_minutes: Optional[int] = None
    cost: Optional[float] = None
    description: Optional[str] = None
    priority: Optional[int] = 1
    coordinates: Optional[dict] = None
    rating: Optional[float] = None
    user_ratings_total: Optional[int] = None
    photo_url: Optional[str] = None
    fsq_id: Optional[str] = None
    external_place_id: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class DayItinerary(BaseModel):
    day: int
    date: str
    activities: List[ItineraryActivity]
    total_cost: Optional[float] = 0.0
    total_duration_minutes: Optional[int] = 0


class ItineraryResponse(BaseModel):
    trip_id: str
    days: List[DayItinerary]
    total_cost: float
    total_days: int
    optimization_score: Optional[float] = None
    generated_at: Optional[str] = None
    strategy: Optional[str] = None


class GenerateItineraryRequest(BaseModel):
    preferences: Optional[dict] = None
    use_ga: Optional[bool] = True
    max_budget: Optional[float] = None
    pace: Optional[str] = "moderate"


# ==================== POI/Recommendation Schemas ====================

class POIResponse(BaseModel):
    id: str
    name: str
    type: str
    category: Optional[str] = None
    poi_type: Optional[str] = None
    location: str
    address: Optional[str] = None
    description: Optional[str] = None
    rating: Optional[float] = None
    review_count: Optional[int] = None
    user_ratings_total: Optional[int] = None
    price_level: Optional[int] = None
    image_url: Optional[str] = None
    coordinates: Optional[dict] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    coordinates_inferred: Optional[bool] = None
    external_place_id: Optional[str] = None
    place_id: Optional[str] = None
    types: Optional[List[str]] = []
    province: Optional[str] = None
    tags: Optional[List[str]] = []
    opening_hours: Optional[dict] = None
    contact: Optional[dict] = None
    created_at: Optional[str] = None


class RecommendationResponse(BaseModel):
    poi: POIResponse
    score: float
    reason: str


class StarterPlanPlace(BaseModel):
    poi: POIResponse
    score: float
    reason: str
    day: Optional[int] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None


class StarterPlanResponse(BaseModel):
    trip_id: str
    days: List[DayItinerary]
    recommended_places: List[StarterPlanPlace]
    total_cost: float
    total_days: int
    optimization_score: Optional[float] = None
    generated_at: Optional[str] = None
    strategy: Optional[str] = None
    preferences_source: Optional[str] = None
