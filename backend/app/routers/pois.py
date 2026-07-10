from fastapi import APIRouter, HTTPException, status, Query
from typing import Any, Dict, List, Optional
from ..schemas.pois import POIResponse
from ..services import poi_service, ai_poi_service, place_enrichment_service

router = APIRouter()


def _poi_matches_type(poi: dict, requested_type: str) -> bool:
    requested = requested_type.strip().lower()
    if not requested:
        return True

    values = [
        poi.get("type"),
        poi.get("category"),
        poi.get("poi_type"),
    ]
    values.extend(poi.get("tags") or [])
    values.extend(poi.get("types") or [])

    return requested in {
        str(value).strip().lower()
        for value in values
        if value is not None and str(value).strip()
    }


@router.get("/", response_model=List)
async def search_pois(
    location: Optional[str] = Query(None, description="Filter by location"),
    type: Optional[str] = Query(None, description="Filter by type (attraction, restaurant, etc.)"),
    min_rating: Optional[float] = Query(None, description="Minimum rating (0-5)"),
    max_price_level: Optional[int] = Query(None, description="Maximum price level (1-4)"),
    tags: Optional[str] = Query(None, description="Comma-separated tags to filter by"),
    limit: int = Query(50, description="Maximum number of results"),
):
    """Search and filter Points of Interest (POIs).

    When a `location` is provided we use the bundled AI dataset (the same
    final_integrated_poi_dataset.csv that powers the destination cities).
    When no location is provided we fall back to the `pois` table in the
    database. The `tags` filter is intentionally not forwarded to the DB
    service yet; it is honoured client-side by the AI dataset path below.
    """
    try:
        if location:
            pois = ai_poi_service.get_pois_for_destination(location, limit=limit)
            pois = place_enrichment_service.merge_pois_with_cached_enrichments(pois, location)
            if type and pois:
                pois = [p for p in pois if _poi_matches_type(p, type)]
            if min_rating is not None and pois:
                pois = [p for p in pois if (p.get('rating') or 0) >= min_rating]
            if tags and pois:
                wanted = {t.strip().lower() for t in tags.split(',') if t.strip()}
                pois = [
                    p for p in pois
                    if wanted.intersection(
                        {str(t).lower() for t in (p.get('tags') or [])}
                    )
                ]
            return pois

        return poi_service.search_pois(
            location=None,
            poi_type=type,
            min_rating=min_rating,
            max_price_level=max_price_level,
            limit=limit,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to search POIs: {str(e)}",
        )


@router.get("/{poi_id}", response_model=Dict[str, Any])
async def get_poi_detail(poi_id: str):
    """Get detailed information about a specific POI."""
    try:
        cached = place_enrichment_service.get_cached_place_by_id(poi_id)
        if cached:
            return place_enrichment_service.merge_place_with_enrichment(
                {
                    "id": cached.get("dataset_poi_id") or cached.get("source_place_id") or poi_id,
                    "name": cached.get("name"),
                    "location": cached.get("city") or "",
                },
                cached,
            )
        return poi_service.get_poi_by_id(poi_id).model_dump()
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get POI details: {str(e)}",
        )
