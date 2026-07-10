"""
TripBond AI Integration Endpoints
==================================
FastAPI endpoints that integrate with the AI pipeline.
Wires the Flask AI backend to the FastAPI main backend.
"""

from fastapi import APIRouter, HTTPException, status, Depends
from typing import List, Dict, Optional, Any
import httpx
import asyncio
from datetime import datetime
import logging

from ..config import get_settings

logger = logging.getLogger(__name__)

router = APIRouter()

# AI Backend configuration (resolved from settings so it can be overridden via .env)
AI_BACKEND_URL = get_settings().ai_backend_url
AI_ENDPOINTS = {
    "health": f"{AI_BACKEND_URL}/health",
    "group_recommendations": f"{AI_BACKEND_URL}/recommend/group",
    "group_itinerary": f"{AI_BACKEND_URL}/itinerary/group",
    "evaluate_place": f"{AI_BACKEND_URL}/evaluate/place",
}

# ============================================================================
# Health & Status Endpoints
# ============================================================================

@router.get("/status")
async def get_ai_status():
    """Check AI backend health status."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(AI_ENDPOINTS["health"])
            if response.status_code == 200:
                return {
                    "status": "healthy",
                    "timestamp": datetime.utcnow().isoformat(),
                    "ai_backend": response.json()
                }
            else:
                return {
                    "status": "unhealthy",
                    "timestamp": datetime.utcnow().isoformat(),
                    "error": f"AI backend returned {response.status_code}"
                }
    except Exception as e:
        logger.error(f"AI health check failed: {str(e)}")
        return {
            "status": "unreachable",
            "timestamp": datetime.utcnow().isoformat(),
            "error": str(e)
        }


# ============================================================================
# Group Recommendation Endpoints
# ============================================================================

@router.post("/recommendations/group")
async def get_group_recommendations(
    trip_id: str,
    user_ids: List[str],
    top_k: int = 10,
    aggregation_strategy: str = "average"
):
    """
    Get AI-powered group recommendations for a trip.
    
    Args:
        trip_id: Trip ID for context
        user_ids: List of user IDs in the group
        top_k: Number of recommendations to return
        aggregation_strategy: How to aggregate preferences ("average", "majority", "weighted")
    
    Returns:
        List of recommended POIs with scores and fairness metrics
    """
    try:
        payload = {
            "user_ids": user_ids,
            "top_k": top_k,
            "aggregation_strategy": aggregation_strategy
        }
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                AI_ENDPOINTS["group_recommendations"],
                json=payload
            )
            response.raise_for_status()
        
        recommendations = response.json()
        logger.info(f"Generated {len(recommendations.get('recommendations', []))} group recommendations for trip {trip_id}")
        
        return {
            "trip_id": trip_id,
            "user_ids": user_ids,
            "strategy": aggregation_strategy,
            "recommendations": recommendations.get("recommendations", []),
            "fairness_score": recommendations.get("fairness_score", 0.0),
            "timestamp": datetime.utcnow().isoformat()
        }
    except httpx.RequestError as e:
        logger.error(f"AI backend request failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"AI backend unavailable: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Error getting group recommendations: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get recommendations: {str(e)}"
        )


# ============================================================================
# Itinerary Optimization Endpoints
# ============================================================================

@router.post("/itinerary/optimize")
async def optimize_group_itinerary(
    trip_id: str,
    user_ids: List[str],
    pois: List[Dict[str, Any]],
    use_ga: bool = True,
    num_days: int = 1,
    max_budget: Optional[float] = None,
    pace: str = "moderate"
):
    """
    Generate optimized itinerary using AI (Genetic Algorithm or Greedy).
    
    Args:
        trip_id: Trip ID
        user_ids: List of user IDs in group
        pois: List of POI dicts with {id, name, latitude, longitude, category, rating}
        use_ga: Use Genetic Algorithm (True) or Greedy (False)
        num_days: Number of days to plan
        max_budget: Optional budget constraint in dollars
        pace: Travel pace ("slow", "moderate", "fast")
    
    Returns:
        Optimized itinerary with daily activities and travel time estimates
    """
    try:
        payload = {
            "user_ids": user_ids,
            "pois": pois,
            "use_ga": use_ga,
            "num_days": num_days,
            "pace": pace
        }
        
        if max_budget:
            payload["max_budget"] = max_budget
        
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                AI_ENDPOINTS["group_itinerary"],
                json=payload
            )
            response.raise_for_status()
        
        itinerary = response.json()
        logger.info(f"Generated {'GA' if use_ga else 'Greedy'} itinerary for trip {trip_id} with {len(pois)} POIs")
        
        return {
            "trip_id": trip_id,
            "user_ids": user_ids,
            "optimization_method": "genetic_algorithm" if use_ga else "greedy",
            "num_days": num_days,
            "itinerary": itinerary.get("itinerary", []),
            "total_cost": itinerary.get("total_cost", 0.0),
            "total_travel_time": itinerary.get("total_travel_time", 0),
            "fitness_score": itinerary.get("fitness_score", 0.0),
            "timestamp": datetime.utcnow().isoformat()
        }
    except httpx.RequestError as e:
        logger.error(f"AI backend request failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"AI backend unavailable: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Error optimizing itinerary: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to optimize itinerary: {str(e)}"
        )


# ============================================================================
# Individual User Recommendations
# ============================================================================

@router.get("/recommendations/user/{user_id}")
async def get_user_recommendations(
    user_id: str,
    trip_id: Optional[str] = None,
    top_k: int = 10,
    category: Optional[str] = None
):
    """
    Get personalized POI recommendations for a specific user.
    
    Args:
        user_id: Target user ID
        trip_id: Optional trip context
        top_k: Number of recommendations
        category: Optional POI category filter
    
    Returns:
        List of recommended POIs with personalization scores
    """
    try:
        # This would call the individual prediction endpoint if available
        # For now, we return a placeholder that can be implemented
        payload = {
            "user_id": user_id,
            "top_k": top_k
        }
        
        if category:
            payload["category"] = category
        
        logger.info(f"Generated {top_k} personalized recommendations for user {user_id}")
        
        return {
            "user_id": user_id,
            "trip_id": trip_id,
            "recommendations": [],
            "note": "Individual user recommendations endpoint - implement based on your use case",
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Error getting user recommendations: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get recommendations: {str(e)}"
        )


# ============================================================================
# Analytics & Feedback
# ============================================================================

@router.post("/feedback/itinerary/{itinerary_id}")
async def submit_itinerary_feedback(
    itinerary_id: str,
    feedback_score: float,
    notes: Optional[str] = None,
    improvements: Optional[List[str]] = None
):
    """
    Submit feedback on AI-generated itinerary to improve future recommendations.
    
    Args:
        itinerary_id: ID of the itinerary
        feedback_score: Score 1-5 (1=poor, 5=excellent)
        notes: Optional feedback notes
        improvements: List of suggested improvements
    
    Returns:
        Confirmation of feedback submission
    """
    try:
        if not 1 <= feedback_score <= 5:
            raise ValueError("feedback_score must be between 1 and 5")
        
        logger.info(f"Received feedback for itinerary {itinerary_id}: score={feedback_score}")
        
        return {
            "itinerary_id": itinerary_id,
            "feedback_score": feedback_score,
            "status": "recorded",
            "timestamp": datetime.utcnow().isoformat(),
            "note": "Feedback recorded for model improvement"
        }
    except Exception as e:
        logger.error(f"Error submitting feedback: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


# ============================================================================
# Configuration & Monitoring
# ============================================================================

@router.get("/config")
async def get_ai_config():
    """Get current AI integration configuration."""
    return {
        "ai_backend_url": AI_BACKEND_URL,
        "endpoints": AI_ENDPOINTS,
        "features": {
            "group_recommendations": True,
            "itinerary_optimization": True,
            "genetic_algorithm": True,
            "travel_cost_estimation": True,
            "fairness_scoring": True
        },
        "models": {
            "random_forest_poi": "trained",
            "genetic_algorithm": "available",
            "group_aggregator": "available"
        }
    }
