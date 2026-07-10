"""
Feedback Service

Handles trip/activity ratings, recommendation feedback, CF model updates,
and user feedback statistics.
Routers delegate all feedback business logic to this service.
"""
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any
from fastapi import HTTPException, status
from ..database import SupabaseDB
from ..schemas.feedback import (
    TripRating,
    ActivityRating,
    RecommendationFeedback,
    RatingResponse,
    ModelUpdateRequest,
    ModelUpdateResponse,
    UserFeedbackStats,
)
import logging

logger = logging.getLogger(__name__)


# ==================== Trip Ratings ====================

def submit_trip_rating(trip_id: str, rating: TripRating) -> RatingResponse:
    """Create or update a trip rating. Triggers CF model update if threshold reached."""
    db = SupabaseDB()

    trip_response = db.client.table("trips").select("id").eq("id", trip_id).execute()
    if not trip_response.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found")

    rating_data = {
        "trip_id": trip_id,
        "user_id": rating.user_id,
        "overall_rating": rating.overall_rating,
        "itinerary_rating": rating.itinerary_rating,
        "accommodation_rating": rating.accommodation_rating,
        "activities_rating": rating.activities_rating,
        "value_rating": rating.value_rating,
        "recommendation_accuracy": rating.recommendation_accuracy,
        "comments": rating.comments,
        "entity_type": "trip",
    }

    existing = db.client.table("ratings").select("id").eq(
        "trip_id", trip_id
    ).eq("user_id", rating.user_id).execute()

    if existing.data:
        response = db.client.table("ratings").update(rating_data).eq(
            "id", existing.data[0]["id"]
        ).execute()
    else:
        response = db.client.table("ratings").insert(rating_data).execute()

    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save rating"
        )

    result = response.data[0]
    _check_update_threshold(db)

    return RatingResponse(
        id=result["id"],
        user_id=result["user_id"],
        entity_id=trip_id,
        entity_type="trip",
        rating=result["overall_rating"],
        created_at=result.get("created_at", datetime.now().isoformat()),
        updated_at=result.get("updated_at"),
    )


def submit_activity_rating(rating: ActivityRating) -> RatingResponse:
    """Create or update an activity rating and update user preferences from feedback."""
    db = SupabaseDB()

    rating_data = {
        "activity_id": rating.activity_id,
        "user_id": rating.user_id,
        "trip_id": rating.trip_id,
        "rating": rating.rating,
        "attendance": rating.attendance,
        "relevance_score": rating.relevance_score,
        "tags": rating.tags,
        "comments": rating.comments,
        "entity_type": "activity",
    }

    existing = db.client.table("ratings").select("id").eq(
        "activity_id", rating.activity_id
    ).eq("user_id", rating.user_id).execute()

    if existing.data:
        response = db.client.table("ratings").update(rating_data).eq(
            "id", existing.data[0]["id"]
        ).execute()
    else:
        response = db.client.table("ratings").insert(rating_data).execute()

    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save activity rating"
        )

    result = response.data[0]
    _update_user_preferences_from_feedback(db, rating.user_id, rating.tags, rating.rating)

    return RatingResponse(
        id=result["id"],
        user_id=result["user_id"],
        entity_id=rating.activity_id,
        entity_type="activity",
        rating=result["rating"],
        created_at=result.get("created_at", datetime.now().isoformat()),
        updated_at=result.get("updated_at"),
    )


# ==================== Recommendation Feedback ====================

def submit_recommendation_feedback(feedback: RecommendationFeedback) -> dict:
    """Record user feedback on a recommendation."""
    db = SupabaseDB()

    feedback_data = {
        "recommendation_id": feedback.recommendation_id,
        "user_id": feedback.user_id,
        "trip_id": feedback.trip_id,
        "accepted": feedback.accepted,
        "useful": feedback.useful,
        "relevance": feedback.relevance,
        "feedback_type": feedback.feedback_type,
        "reason": feedback.reason,
    }

    response = db.client.table("recommendation_feedback").insert(feedback_data).execute()

    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save feedback"
        )

    return {"message": "Feedback recorded successfully", "feedback_id": response.data[0]["id"]}


# ==================== Trip Ratings Retrieval ====================

def get_trip_ratings(trip_id: str) -> dict:
    """Return all ratings for a trip with statistics."""
    db = SupabaseDB()
    response = db.client.table("ratings").select("*").eq(
        "trip_id", trip_id
    ).eq("entity_type", "trip").execute()

    if not response.data:
        return {"trip_id": trip_id, "ratings": [], "average_rating": 0.0, "total_ratings": 0}

    ratings = response.data
    average = sum(r["overall_rating"] for r in ratings) / len(ratings)

    return {
        "trip_id": trip_id,
        "ratings": ratings,
        "average_rating": round(average, 2),
        "total_ratings": len(ratings),
    }


# ==================== User Feedback Stats ====================

def get_user_feedback_stats(user_id: str) -> UserFeedbackStats:
    """Compute and return feedback statistics for a user."""
    db = SupabaseDB()

    ratings = db.client.table("ratings").select("*").eq("user_id", user_id).execute().data or []
    feedback = db.client.table("recommendation_feedback").select("*").eq("user_id", user_id).execute().data or []

    trip_ratings = [r for r in ratings if r.get("entity_type") == "trip"]
    activity_ratings = [r for r in ratings if r.get("entity_type") == "activity"]

    accepted = len([f for f in feedback if f.get("accepted")])
    rejected = len([f for f in feedback if not f.get("accepted")])

    rating_values = [
        r.get("overall_rating") or r.get("rating")
        for r in ratings
        if r.get("overall_rating") or r.get("rating")
    ]
    avg_rating = sum(rating_values) / len(rating_values) if rating_values else 0.0

    last_rating = (
        max((r.get("created_at") for r in ratings if r.get("created_at")), default=None)
        if ratings else None
    )

    return UserFeedbackStats(
        user_id=user_id,
        total_ratings=len(ratings),
        average_rating=round(avg_rating, 2),
        trips_rated=len(trip_ratings),
        activities_rated=len(activity_ratings),
        recommendations_accepted=accepted,
        recommendations_rejected=rejected,
        last_rating_date=last_rating,
    )


# ==================== CF Model Management ====================

def update_cf_model(request: ModelUpdateRequest) -> ModelUpdateResponse:
    """Collect ratings, run CF model update, and persist the result."""
    db = SupabaseDB()

    if request.include_recent_only:
        cutoff_date = (datetime.now() - timedelta(days=request.days_back)).isoformat()
        ratings_response = db.client.table("ratings").select("*").gte(
            "created_at", cutoff_date
        ).execute()
    else:
        ratings_response = db.client.table("ratings").select("*").execute()

    ratings = ratings_response.data or []

    if not ratings:
        return ModelUpdateResponse(
            status="no_updates_needed",
            updated_at=datetime.now().isoformat(),
            ratings_processed=0,
            users_affected=0,
            model_version="current",
            improvements={},
        )

    update_result = _run_cf_model_update(ratings)

    db.client.table("model_updates").insert({
        "trigger": request.trigger,
        "ratings_processed": len(ratings),
        "users_affected": update_result["users_affected"],
        "model_version": update_result["version"],
        "improvements": update_result["metrics"],
        "status": "completed",
    }).execute()

    return ModelUpdateResponse(
        status="completed",
        updated_at=datetime.now().isoformat(),
        ratings_processed=len(ratings),
        users_affected=update_result["users_affected"],
        model_version=update_result["version"],
        improvements=update_result["metrics"],
    )


def get_model_status() -> dict:
    """Return current CF model status and pending rating count."""
    db = SupabaseDB()

    updates_response = db.client.table("model_updates").select("*").order(
        "created_at", desc=True
    ).limit(1).execute()

    ratings_response = db.client.table("ratings").select("id", count="exact").execute()
    total_ratings = ratings_response.count if ratings_response else 0

    last_update = updates_response.data[0] if updates_response.data else None
    pending_ratings = total_ratings

    if last_update:
        last_update_date = last_update.get("created_at")
        if last_update_date:
            pending_response = db.client.table("ratings").select("id", count="exact").gte(
                "created_at", last_update_date
            ).execute()
            pending_ratings = pending_response.count if pending_response else 0

    return {
        "model_version": last_update.get("model_version") if last_update else "initial",
        "last_updated": last_update.get("created_at") if last_update else None,
        "total_ratings": total_ratings,
        "pending_ratings": pending_ratings,
        "update_threshold": 100,
        "needs_update": pending_ratings >= 100,
        "last_metrics": last_update.get("improvements") if last_update else {},
    }


def get_model_update_history(limit: int = 10) -> dict:
    """Return paginated history of CF model updates."""
    db = SupabaseDB()
    response = db.client.table("model_updates").select("*").order(
        "created_at", desc=True
    ).limit(limit).execute()
    updates = response.data or []
    return {"updates": updates, "total": len(updates)}


# ==================== Internal Helpers ====================

def _check_update_threshold(db: SupabaseDB) -> None:
    """Trigger background CF model update if 100+ new ratings accumulated."""
    updates = db.client.table("model_updates").select("created_at").order(
        "created_at", desc=True
    ).limit(1).execute()

    if not updates.data:
        return

    last_update = updates.data[0]["created_at"]
    recent = db.client.table("ratings").select("id", count="exact").gte(
        "created_at", last_update
    ).execute()

    if recent.count and recent.count >= 100:
        # TODO: enqueue background model retraining job
        logger.info("CF model update threshold reached — schedule retraining")


def _update_user_preferences_from_feedback(
    db: SupabaseDB,
    user_id: str,
    tags: Optional[List[str]],
    rating: float,
) -> None:
    """Lightweight update of user preferences based on positive activity feedback."""
    if not tags or rating < 3.0:
        return

    # TODO: Implement preference weight adjustment based on activity tags and rating
    logger.debug("Preference update triggered for user %s (rating=%.1f, tags=%s)", user_id, rating, tags)


def _run_cf_model_update(ratings: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Run collaborative filtering model update.

    TODO: Implement actual CF algorithm (SVD / ALS / neural CF) from research paper.
    Current placeholder returns mock metrics.
    """
    unique_users = len({r["user_id"] for r in ratings})

    return {
        "version": f"v{datetime.now().strftime('%Y%m%d_%H%M%S')}",
        "users_affected": unique_users,
        "metrics": {
            "rmse": 0.82,
            "mae": 0.65,
            "precision_at_10": 0.75,
            "recall_at_10": 0.68,
            "ndcg": 0.81,
        },
    }
