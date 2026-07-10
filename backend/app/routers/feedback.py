from fastapi import APIRouter, HTTPException, status
from ..schemas.feedback import (
    TripRating,
    ActivityRating,
    RecommendationFeedback,
    RatingResponse,
    UserFeedbackStats,
)
from ..services import feedback_service

router = APIRouter()


@router.post("/trips/{trip_id}/rate", response_model=RatingResponse)
async def rate_trip(trip_id: str, rating: TripRating):
    """Rate a completed trip. Feedback is used to improve recommendations."""
    try:
        return await feedback_service.submit_trip_rating(trip_id, rating)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to rate trip: {str(e)}",
        )


@router.post("/activities/rate", response_model=RatingResponse)
async def rate_activity(rating: ActivityRating):
    """Rate a specific activity within a trip."""
    try:
        return await feedback_service.submit_activity_rating(rating)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to rate activity: {str(e)}",
        )


@router.post("/recommendations/feedback")
async def submit_recommendation_feedback(feedback: RecommendationFeedback):
    """Provide feedback on a specific recommendation."""
    try:
        return await feedback_service.submit_recommendation_feedback(feedback)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to submit feedback: {str(e)}",
        )


@router.get("/trips/{trip_id}/ratings")
async def get_trip_ratings(trip_id: str):
    """Get all ratings for a specific trip."""
    try:
        return feedback_service.get_trip_ratings(trip_id)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get ratings: {str(e)}",
        )


@router.get("/users/{user_id}/feedback", response_model=UserFeedbackStats)
async def get_user_feedback_stats(user_id: str):
    """Get feedback statistics for a user."""
    try:
        return feedback_service.get_user_feedback_stats(user_id)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get feedback stats: {str(e)}",
        )


@router.get("/model/status")
async def get_model_status():
    """Get current CF model status and statistics."""
    try:
        return feedback_service.get_model_status()
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get model status: {str(e)}",
        )
