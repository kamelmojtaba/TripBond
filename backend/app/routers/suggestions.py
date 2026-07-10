"""
Place suggestions system - AI evaluates and approves/rejects suggestions
"""

from fastapi import APIRouter, HTTPException, status, Depends
from fastapi.concurrency import run_in_threadpool
from typing import Optional
from datetime import datetime
import httpx
from ..database import SupabaseDB, get_supabase_client_for_user
from ..auth import get_current_user_context
from ..config import get_settings
from ..services.trip_access import check_trip_access
from ..services import notification_service
import logging

logger = logging.getLogger(__name__)
router = APIRouter()

AI_APPROVAL_THRESHOLD = 0.55


@router.post("/{trip_id}/suggest-place")
async def suggest_place(
    trip_id: str,
    place_data: dict,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """
    Suggest a place for the trip. 
    Place goes to Bonders Suggestions for AI evaluation.
    
    Expected place_data:
    {
        "external_place_id": str (optional),
        "name": str,
        "latitude": float,
        "longitude": float,
        "address": str,
        "rating": float,
        "user_ratings_total": int,
        "types": list,
        "image_url": str (optional)
    }
    """
    user_id, token = user_context
    
    try:
        await check_trip_access(trip_id, user_id, token=token, required_role="edit")
        
        name = place_data.get("name")
        latitude = place_data.get("latitude")
        longitude = place_data.get("longitude")
        
        if not name or latitude is None or longitude is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Missing required fields: name, latitude, longitude"
            )
        
        db = SupabaseDB(admin=True)
        
        image_url = place_data.get("image_url") or place_data.get("photo_url")
        if not image_url and isinstance(place_data.get("images"), list):
            for image in place_data["images"]:
                if isinstance(image, dict) and image.get("url"):
                    image_url = image["url"]
                    break

        # Prepare suggestion record
        suggestion_record = {
            "trip_id": trip_id,
            "name": name,
            "address": place_data.get("address", ""),
            "latitude": latitude,
            "longitude": longitude,
            "rating": place_data.get("rating"),
            "user_ratings_total": place_data.get("user_ratings_total"),
            "place_types": place_data.get("types", []),
            "image_url": image_url,
            "external_place_id": place_data.get("external_place_id"),
            "suggested_by": user_id,
            "status": "pending"
        }
        
        # Insert suggestion
        insert_result = await run_in_threadpool(
            lambda: db.client.table("place_suggestions").insert(suggestion_record).execute()
        )
        
        if not insert_result.data:
            raise Exception("Insert returned no data")
        
        suggestion_id = insert_result.data[0]["id"]
        logger.info(f"Suggested place {name} ({suggestion_id}) for trip {trip_id}")
        
        # Trigger AI evaluation in background
        try:
            await evaluate_place_with_ai(suggestion_id, trip_id, name, latitude, longitude, place_data.get("types", []))
        except Exception as e:
            logger.warning(f"AI evaluation failed for suggestion {suggestion_id}: {e}")
        
        return {
            "success": True,
            "suggestion_id": suggestion_id,
            "message": f"✓ {name} added",
            "status": "pending"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"Failed to suggest place: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to suggest place: {str(e)}"
        )


@router.get("/{trip_id}/list")
async def list_suggestions(
    trip_id: str,
    status: Optional[str] = None,
    user_context: tuple[str, str] = Depends(get_current_user_context)
):
    """List suggestions for a trip (Bonders Suggestions), optionally filtered by status"""
    user_id, token = user_context
    
    try:
        await check_trip_access(trip_id, user_id, token=token, required_role="view")
        
        db = SupabaseDB(admin=True)
        query = db.client.table("place_suggestions").select("*").eq("trip_id", trip_id)
        
        if status:
            query = query.eq("status", status)
        
        result = await run_in_threadpool(lambda: query.execute())
        
        return {
            "success": True,
            "suggestions": result.data or []
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"Failed to list suggestions: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list suggestions: {str(e)}"
        )


async def _call_flask_evaluator(payload: dict) -> Optional[dict]:
    """Call the Flask AI service /evaluate/place. Returns None on failure."""
    settings = get_settings()
    url = f"{settings.ai_backend_url}/evaluate/place"
    try:
        async with httpx.AsyncClient(timeout=settings.ai_backend_timeout) as client:
            response = await client.post(url, json=payload)
            response.raise_for_status()
            data = response.json()
            if data.get("success"):
                return data
    except Exception as exc:
        logger.warning("AI evaluator unreachable (%s): %s", url, exc)
    return None


def _local_score_fallback(name: str, rating: float | None, ratings_total: int | None, types: list) -> tuple[float, str]:
    """Deterministic backup score when the Flask service is down."""
    travel_friendly = {
        "tourist_attraction", "landmark", "museum", "park", "beach",
        "restaurant", "cafe", "shopping_mall", "art_gallery", "amusement_park",
        "aquarium", "zoo", "natural_feature", "place_of_worship", "mosque",
    }
    downweight = {"hospital", "doctor", "lawyer", "atm", "bank", "gas_station"}
    type_set = {str(t).lower() for t in (types or [])}
    score = 0.0
    if rating:
        score += min(max(float(rating) / 5.0, 0.0), 1.0) * 0.55
    if ratings_total:
        score += min(1.0, int(ratings_total) / 1500.0) * 0.20
    if type_set & travel_friendly:
        score += 0.20
    if type_set & downweight:
        score -= 0.40
    score = max(0.0, min(1.0, score))
    return round(score, 3), f"{name}: local heuristic score"


async def _add_suggestion_to_trip_places(db: SupabaseDB, trip_id: str, sugg: dict) -> None:
    place_record = {
        "trip_id": trip_id,
        "name": sugg["name"],
        "address": sugg.get("address"),
        "latitude": sugg["latitude"],
        "longitude": sugg["longitude"],
        "rating": sugg.get("rating"),
        "user_ratings_total": sugg.get("user_ratings_total"),
        "place_types": sugg.get("place_types") or [],
        "added_by": sugg.get("suggested_by"),
        "added_at": datetime.utcnow().isoformat(),
    }
    if sugg.get("external_place_id"):
        place_record["external_place_id"] = sugg["external_place_id"]
    if sugg.get("image_url"):
        place_record["image_url"] = sugg["image_url"]
    try:
        await run_in_threadpool(
            lambda: db.client.table("trip_places").insert(place_record).execute()
        )
    except Exception as exc:
        # Most likely a unique-constraint conflict (place already added). Log and continue.
        logger.info("Approved suggestion not added to trip_places (%s): %s", sugg.get("name"), exc)


async def evaluate_place_with_ai(suggestion_id: str, trip_id: str, place_name: str, latitude: float, longitude: float, types: list):
    """Evaluate a suggestion via the AI service and approve/reject it."""
    db = SupabaseDB(admin=True)
    try:
        sugg_resp = await run_in_threadpool(
            lambda: db.client.table("place_suggestions").select("*").eq("id", suggestion_id).execute()
        )
        if not sugg_resp.data:
            return
        sugg = sugg_resp.data[0]

        trip_resp = await run_in_threadpool(
            lambda: db.client.table("trips").select("destination, title").eq("id", trip_id).execute()
        )
        trip = trip_resp.data[0] if trip_resp.data else {}

        payload = {
            "name": place_name,
            "rating": sugg.get("rating"),
            "user_ratings_total": sugg.get("user_ratings_total"),
            "place_types": types,
            "trip_destination": trip.get("destination"),
        }
        ai_result = await _call_flask_evaluator(payload)
        if ai_result:
            ai_score = float(ai_result.get("ai_score", 0.0))
            ai_reasoning = str(ai_result.get("ai_reasoning") or "")
        else:
            ai_score, ai_reasoning = _local_score_fallback(
                place_name, sugg.get("rating"), sugg.get("user_ratings_total"), types
            )

        new_status = "approved" if ai_score >= AI_APPROVAL_THRESHOLD else "rejected"
        await run_in_threadpool(
            lambda: db.client.table("place_suggestions")
            .update({"ai_score": ai_score, "ai_reasoning": ai_reasoning, "status": new_status})
            .eq("id", suggestion_id)
            .execute()
        )
        logger.info("AI %s suggestion %s with score %.2f", new_status, suggestion_id, ai_score)

        if new_status == "approved":
            await _add_suggestion_to_trip_places(db, trip_id, sugg)

        # Notify the user who suggested it of the outcome.
        if sugg.get("suggested_by"):
            notification_service.emit(
                user_id=sugg["suggested_by"],
                notif_type=f"suggestion_{new_status}",
                title="Suggestion " + ("approved" if new_status == "approved" else "rejected"),
                body=f"AI {new_status} '{place_name}' (score {ai_score:.2f}).",
                payload={"trip_id": trip_id, "suggestion_id": suggestion_id, "ai_score": ai_score},
            )
    except Exception as exc:
        logger.warning("Failed AI evaluation for suggestion %s: %s", suggestion_id, exc)
