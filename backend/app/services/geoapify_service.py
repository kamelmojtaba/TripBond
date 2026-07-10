"""
Geoapify Places Service

Wraps the Geoapify Places API for text search, nearby search, and place details.
Geoapify is free-tier friendly and doesn't require API key restrictions for localhost.

Requires GEOAPIFY_API_KEY to be set in the environment / .env file.

Endpoints used:
- /v1/geocode/search - Free-text location search (text queries)
- /v2/places - POI search with geographic filters (nearby/category search)
"""

import httpx
import logging
from fastapi import HTTPException, status
from typing import Optional
from ..config import get_settings
from ..schemas.places import (
    PlacesSearchResponse,
    PlaceDetailsResponse,
    PlaceResult,
    PlaceDetailsResult,
    PlaceGeometry,
    PlacePhoto,
    PlaceOpeningHours,
)

logger = logging.getLogger(__name__)

GEOAPIFY_GEOCODE_URL = "https://api.geoapify.com/v1/geocode/search"
GEOAPIFY_PLACES_URL = "https://api.geoapify.com/v2/places"


def _get_api_key() -> str:
    """Return the configured Geoapify API key or raise 503."""
    key = get_settings().geoapify_api_key
    if not key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Geoapify API key is not configured. Set GEOAPIFY_API_KEY in your environment.",
        )
    return key


def _parse_place_result(place: dict) -> PlaceResult:
    """Convert a raw Geoapify result dict into a PlaceResult schema."""
    properties = place.get("properties", {})
    geometry = place.get("geometry", {})
    coordinates = geometry.get("coordinates", [])
    
    place_geometry = None
    if coordinates:
        place_geometry = PlaceGeometry(lat=coordinates[1], lng=coordinates[0])

    # Geoapify doesn't provide photos in the same way, so we'll use empty list
    photos = []

    # Parse opening hours if available
    opening_hours = None
    if properties.get("open_now") is not None:
        opening_hours = PlaceOpeningHours(open_now=properties.get("open_now"))

    return PlaceResult(
        place_id=properties.get("place_id", properties.get("name", "")),
        name=properties.get("name", ""),
        formatted_address=properties.get("address_line1", ""),
        vicinity=properties.get("address_line2", ""),
        geometry=place_geometry,
        rating=properties.get("rating"),
        user_ratings_total=properties.get("review_count"),
        price_level=None,  # Geoapify doesn't provide price level
        types=properties.get("categories", []),
        opening_hours=opening_hours,
        photos=photos,
        icon=None,
        business_status=properties.get("business_status"),
    )


def text_search_places(
    query: str,
    language: str = "en",
    next_page_token: Optional[str] = None,
) -> PlacesSearchResponse:
    """
    Search Geoapify using a free-text query for locations/addresses.
    Uses the Geocode API to find places by text (e.g., "restaurants in Paris").
    
    Args:
        query: Free-text search string, e.g. "restaurants in Paris".
        language: Language code for results.
        next_page_token: Offset for pagination.

    Returns:
        PlacesSearchResponse with up to 20 results per page.
    """
    api_key = _get_api_key()
    limit = 20
    offset = 0
    
    if next_page_token:
        try:
            offset = int(next_page_token)
        except (ValueError, TypeError):
            offset = 0

    params = {
        "text": query,
        "lang": language,
        "limit": limit,
        "offset": offset,
        "apiKey": api_key,
    }

    try:
        with httpx.Client(timeout=10.0) as client:
            resp = client.get(GEOAPIFY_GEOCODE_URL, params=params)
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPError as exc:
        logger.error("Geoapify text search failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Geoapify API request failed: {exc}",
        )

    results = data.get("features", [])
    next_offset = None
    if len(results) >= limit:
        next_offset = str(offset + limit)

    return PlacesSearchResponse(
        results=[_parse_place_result(p) for p in results],
        next_page_token=next_offset,
        status="OK" if results else "ZERO_RESULTS",
    )


def nearby_search_places(
    lat: float,
    lng: float,
    radius: int = 5000,
    place_type: Optional[str] = None,
    keyword: Optional[str] = None,
    language: str = "en",
    next_page_token: Optional[str] = None,
) -> PlacesSearchResponse:
    """
    Search for places near a geographic coordinate using Geoapify Places API.
    Ideal for "Explore Nearby" homepage section.
    
    The /v2/places endpoint searches POIs by geographic location and optional category filter.

    Args:
        lat: Latitude of the search centre.
        lng: Longitude of the search centre.
        radius: Search radius in metres (max 50 000).
        place_type: Optional category filter (e.g., 'catering', 'shopping').
        keyword: Optional keyword to filter results (note: /v2/places primarily uses categories).
        language: Language code for results.
        next_page_token: Offset for pagination.

    Returns:
        PlacesSearchResponse with up to 20 results per page.
    """
    api_key = _get_api_key()
    limit = 20
    offset = 0
    
    if next_page_token:
        try:
            offset = int(next_page_token)
        except (ValueError, TypeError):
            offset = 0

    # Build filter with circle (lat, lng, radius)
    # The filter parameter requires: lat=X&lon=Y or filter=circle:lng,lat,radius
    params = {
        "lat": lat,
        "lon": lng,
        "radius": min(radius, 50000),  # Geoapify max radius is 50km
        "lang": language,
        "limit": limit,
        "offset": offset,
        "apiKey": api_key,
    }
    
    # Add category filter if provided
    if place_type:
        params["categories"] = place_type

    try:
        with httpx.Client(timeout=10.0) as client:
            resp = client.get(GEOAPIFY_PLACES_URL, params=params)
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPError as exc:
        logger.error("Geoapify nearby search failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Geoapify API request failed: {exc}",
        )

    results = data.get("features", [])
    next_offset = None
    if len(results) >= limit:
        next_offset = str(offset + limit)

    return PlacesSearchResponse(
        results=[_parse_place_result(p) for p in results],
        next_page_token=next_offset,
        status="OK" if results else "ZERO_RESULTS",
    )


def get_place_details(place_id: str, language: str = "en") -> PlaceDetailsResponse:
    """
    Retrieve full details for a single place using Geoapify Geocode API.
    
    Args:
        place_id: The place name, address, or search term.
        language: Language code for results.

    Returns:
        PlaceDetailsResponse with comprehensive place information.
    """
    api_key = _get_api_key()
    
    params = {
        "text": place_id,
        "lang": language,
        "limit": 1,
        "apiKey": api_key,
    }

    try:
        with httpx.Client(timeout=10.0) as client:
            resp = client.get(GEOAPIFY_GEOCODE_URL, params=params)
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPError as exc:
        logger.error("Geoapify details request failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Geoapify API request failed: {exc}",
        )

    features = data.get("features", [])
    if not features:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Place not found",
        )

    place = features[0]
    properties = place.get("properties", {})
    geometry = place.get("geometry", {})
    coordinates = geometry.get("coordinates", [])
    
    place_geometry = None
    if coordinates:
        place_geometry = PlaceGeometry(lat=coordinates[1], lng=coordinates[0])

    photos = []

    return PlaceDetailsResponse(
        result=PlaceDetailsResult(
            place_id=properties.get("place_id", properties.get("name", "")),
            name=properties.get("name", ""),
            formatted_address=properties.get("address_line1", ""),
            formatted_phone_number=properties.get("phone"),
            website=properties.get("website"),
            geometry=place_geometry,
            rating=properties.get("rating"),
            user_ratings_total=properties.get("review_count"),
            types=properties.get("categories", []),
            photos=photos,
        ),
        status="OK",
    )


def get_photo_url(photo_reference: str, max_width: int = 800) -> str:
    """
    Return a photo URL. Geoapify doesn't have photo references like Google,
    so this is a placeholder that might return a generic image or handle
    place-specific photo URLs if available.
    
    Args:
        photo_reference: Reference string (not used for Geoapify).
        max_width: Maximum width (not used for Geoapify).
    
    Returns:
        A photo URL string.
    """
    # Geoapify doesn't have direct photo references
    # Return a placeholder or empty string
    return ""
