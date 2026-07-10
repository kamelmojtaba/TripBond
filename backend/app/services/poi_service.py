"""
POI Service

Handles database queries and filtering for Points of Interest.
Routers delegate all POI business logic to this service.
"""
from fastapi import HTTPException, status
from typing import List, Optional
from ..database import SupabaseDB
from ..schemas.pois import POIResponse
import logging

logger = logging.getLogger(__name__)


def _row_to_poi(poi: dict) -> POIResponse:
    """Map a database row to a POIResponse schema."""
    return POIResponse(
        id=poi["id"],
        name=poi.get("name", ""),
        type=poi.get("poi_type", ""),
        location=poi.get("location", ""),
        description=poi.get("description"),
        rating=poi.get("rating"),
        price_level=poi.get("price_level"),
        image_url=poi.get("image_url"),
        coordinates=poi.get("coordinates"),
        tags=poi.get("tags", []),
        opening_hours=poi.get("opening_hours"),
        contact=poi.get("contact"),
        created_at=poi.get("created_at"),
    )


def search_pois(
    location: Optional[str] = None,
    poi_type: Optional[str] = None,
    min_rating: Optional[float] = None,
    max_price_level: Optional[int] = None,
    limit: int = 50,
) -> List[POIResponse]:
    """
    Search and filter Points of Interest from the database.
    Returns a list of POIResponse objects ordered by rating descending.
    """
    db = SupabaseDB()
    query = db.client.table("pois").select("*")

    if location:
        query = query.ilike("location", f"%{location}%")
    if poi_type:
        query = query.eq("type", poi_type)
    if min_rating is not None:
        query = query.gte("rating", min_rating)
    if max_price_level is not None:
        query = query.lte("price_level", max_price_level)

    query = query.order("rating", desc=True).limit(limit)
    response = query.execute()

    if not response.data:
        return []

    return [_row_to_poi(poi) for poi in response.data]


def get_poi_by_id(poi_id: str) -> POIResponse:
    """
    Retrieve a single POI by its ID.

    Raises:
        HTTPException 404 if not found.
    """
    db = SupabaseDB()
    response = db.client.table("pois").select("*").eq("id", poi_id).execute()

    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="POI not found"
        )

    return _row_to_poi(response.data[0])
