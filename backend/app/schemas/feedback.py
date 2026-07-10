"""
Feedback Schemas

Pydantic models for request/response validation in feedback endpoints.
"""
from pydantic import BaseModel
from typing import List, Optional, Dict


class TripRating(BaseModel):
    trip_id: str
    user_id: str
    overall_rating: float  # 1.0 to 5.0
    itinerary_rating: Optional[float] = None
    accommodation_rating: Optional[float] = None
    activities_rating: Optional[float] = None
    value_rating: Optional[float] = None
    recommendation_accuracy: Optional[float] = None  # How well recommendations matched preferences
    comments: Optional[str] = None


class ActivityRating(BaseModel):
    activity_id: str
    user_id: str
    trip_id: str
    rating: float  # 1.0 to 5.0
    attendance: bool  # Did user actually attend?
    relevance_score: Optional[float] = None  # How relevant was this activity to preferences
    tags: Optional[List[str]] = None  # User-defined tags
    comments: Optional[str] = None


class RecommendationFeedback(BaseModel):
    recommendation_id: str
    user_id: str
    trip_id: Optional[str] = None
    accepted: bool  # Did user accept the recommendation?
    useful: bool  # Was it useful?
    relevance: float  # 1.0 to 5.0
    feedback_type: str  # 'like', 'dislike', 'neutral'
    reason: Optional[str] = None


class RatingResponse(BaseModel):
    id: str
    user_id: str
    entity_id: str  # trip_id or activity_id
    entity_type: str  # 'trip' or 'activity'
    rating: float
    created_at: str
    updated_at: Optional[str] = None


class ModelUpdateRequest(BaseModel):
    trigger: str  # 'manual', 'scheduled', 'threshold'
    include_recent_only: Optional[bool] = False
    days_back: Optional[int] = 30


class ModelUpdateResponse(BaseModel):
    status: str
    updated_at: str
    ratings_processed: int
    users_affected: int
    model_version: str
    improvements: Dict[str, float]  # Metrics like RMSE, precision, recall


class UserFeedbackStats(BaseModel):
    user_id: str
    total_ratings: int
    average_rating: float
    trips_rated: int
    activities_rated: int
    recommendations_accepted: int
    recommendations_rejected: int
    last_rating_date: Optional[str] = None
