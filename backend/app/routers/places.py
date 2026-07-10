"""
Google Places & Places Router

Exposes Google Places API endpoints consumed by the TripBond app:
  GET /api/places/search          – text/fuzzy search (destination search bar)
  GET /api/places/nearby          – nearby places search (proximity search)
  GET /api/places/details/{id}    – full place details
  GET /api/places/photo-url       – photo URL helper
"""

from fastapi import APIRouter, Query
from typing import Optional, List, Dict, Any
from ..schemas.places import PlacesSearchResponse, PlaceDetailsResponse
from ..services import google_places_service, cities_service, place_enrichment_service, ai_poi_service

router = APIRouter()


@router.get("/cities", response_model=List[Dict[str, Any]])
async def list_destination_cities():
    """
    Curated list of trip destinations derived from the bundled POI dataset.

    Each entry: name, count, province, country, lat, lng, image_asset, is_featured.
    Used by the Flutter app to render the destination quick-pick grid.
    """
    cities = cities_service.list_cities()
    return place_enrichment_service.merge_cities_with_cached_enrichments(cities)


@router.get("/bootstrap", response_model=Dict[str, Any])
async def get_destination_bootstrap(
    places_per_city: int = Query(200, ge=0, le=200, description="Number of POIs to include per city"),
):
    """
    Return destination cities and cached POIs in one payload.

    Used by the Flutter app during startup warmup so destination search and
    place-picking screens can render from local cache instead of waiting on
    separate requests after the user taps Search.
    """
    cities = place_enrichment_service.merge_cities_with_cached_enrichments(
        cities_service.list_cities()
    )
    places_by_city: Dict[str, List[Dict[str, Any]]] = {}

    if places_per_city > 0:
        raw_places_by_city = {
            city["name"]: ai_poi_service.get_pois_for_destination(
                city["name"],
                limit=places_per_city,
                enrich_photos=False,
                require_coordinates=False,
            )
            for city in cities
            if city.get("name")
        }
        places_by_city = place_enrichment_service.merge_places_by_city_with_cached_enrichments(
            raw_places_by_city
        )

    return {
        "cities": cities,
        "places_by_city": places_by_city,
    }


@router.get("/search", response_model=PlacesSearchResponse)
async def search_places(
    q: str = Query(..., description="Free-text search query, e.g. 'beaches in Bali'"),
    lat: Optional[float] = Query(None, description="Optional latitude for spatial biasing"),
    lng: Optional[float] = Query(None, description="Optional longitude for spatial biasing"),
    language: str = Query("en", description="BCP-47 language code for results"),
    limit: int = Query(20, ge=1, le=100, description="Max results to return (1-100)"),
):
    """
    Free-text/Fuzzy search using Google Places Text Search API.
    Ideal for the homepage destination search bar.
    Returns up to 20 results per call.
    """
    return google_places_service.text_search_places(
        query=q,
        language=language,
    )


@router.get("/nearby", response_model=PlacesSearchResponse)
async def nearby_places(
    lat: float = Query(..., description="Latitude of the search centre"),
    lng: float = Query(..., description="Longitude of the search centre"),
    radius: int = Query(5000, ge=100, le=50000, description="Search radius in metres (min 100, max 50000)"),
    q: Optional[str] = Query(None, description="Keyword to filter results (e.g., 'restaurants')"),
    language: str = Query("en", description="BCP-47 language code for results"),
    limit: int = Query(20, ge=1, le=100, description="Max results to return (1-100)"),
):
    """
    Search for places near a coordinate using Google Places Nearby Search API.
    Ideal for the 'Explore Nearby' homepage section.
    Returns up to 20 results per call.
    """
    return google_places_service.nearby_search_places(
        lat=lat,
        lng=lng,
        radius=radius,
        keyword=q,
        language=language,
    )


@router.get("/details/{place_id}", response_model=PlaceDetailsResponse)
async def get_place_details(
    place_id: str,
    language: str = Query("en", description="BCP-47 language code for results"),
):
    """
    Retrieve full details for a Google Places location using its place_id.
    Includes photos, ratings, phone number, website, and opening hours.
    """
    return google_places_service.get_place_details(
        place_id=place_id,
        language=language,
    )


@router.get("/cached/{place_id}", response_model=PlaceDetailsResponse)
async def get_cached_place_details(place_id: str):
    """
    Retrieve saved place details from the TripBond cache only.

    This endpoint does not call Google and is intended for normal app browsing.
    """
    return place_enrichment_service.require_cached_place_details(place_id)


@router.get("/photo-url")
async def get_photo_url(
    photo_reference: str = Query(..., description="Photo reference from Google Places API"),
    max_width: int = Query(800, ge=100, le=1600, description="Maximum image width in pixels"),
):
    """
    Return a photo URL that can be used directly in <img src>.
    For Google Places, constructs the complete photo endpoint URL.
    """
    url = google_places_service.get_photo_url(
        photo_reference=photo_reference,
        max_width=max_width,
    )
    return {"photo_url": url}
