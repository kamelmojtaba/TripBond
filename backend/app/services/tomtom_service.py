"""
TomTom Search & Details Service

Replaces Google Places API with TomTom Search API for place discovery.
Provides:
  - Fuzzy Search (text-based place search)
  - Nearby Search (geographic proximity search)
  - Place Details (full details for a specific entity)

Requires TOMTOM_API_KEY to be set in the environment / .env file.

TomTom API Endpoints:
  - Search: https://api.tomtom.com/search/2/search/{query}.json
  - Nearby Search: https://api.tomtom.com/search/2/nearbySearch/.json
  - Place Details: https://api.tomtom.com/search/2/place/{entityId}.json
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
)

logger = logging.getLogger(__name__)

TOMTOM_BASE_URL = "https://api.tomtom.com/search/2"

# Map short language codes to TomTom-compatible locale codes
LANGUAGE_CODE_MAP = {
    "en": "en-US",
    "es": "es-ES",
    "fr": "fr-FR",
    "de": "de-DE",
    "it": "it-IT",
    "pt": "pt-BR",
    "ja": "ja-JP",
    "zh": "zh-CN",
    "ko": "ko-KR",
    "ru": "ru-RU",
}


def _normalize_language_code(code: str) -> str:
    """Convert short language codes (e.g., 'en') to TomTom-compatible locale codes (e.g., 'en-US')."""
    if "-" in code:
        return code  # Already a full locale code
    return LANGUAGE_CODE_MAP.get(code.lower(), f"{code.lower()}-US")  # Default to -US


def _get_api_key() -> str:
    """Return the configured TomTom API key or raise 503."""
    key = get_settings().tomtom_api_key
    if not key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="TomTom API key is not configured. Set TOMTOM_API_KEY in your environment.",
        )
    return key


def _parse_search_result(result: dict) -> PlaceResult:
    """
    Convert a TomTom Search API result into a PlaceResult schema.
    
    TomTom search result structure:
    {
        "id": "entityId",
        "type": "POI",
        "score": 43.2,
        "dist": 234.0,
        "info": "search info",
        "poi": {
            "name": "Place Name",
            "classifications": [{"code": "RESTAURANT"}, ...],
            "url": "https://...",
            "image": "https://..."
        },
        "address": {
            "streetNumber": "123",
            "streetName": "Main St",
            "municipalitySubdivision": "Area",
            "municipality": "City",
            "countrySecondarySubdivision": "State",
            "countrySubdivision": "State",
            "country": "Country",
            "countryCode": "US",
            "postalCode": "12345",
            "extendedPostalCode": "123456"
        },
        "position": {
            "lat": 40.123,
            "lon": -74.456
        },
        "viewport": {...},
        "entryPoints": [...],
        "chargingPark": {...},
        "matchingPattern": "..."
    }
    """
    poi = result.get("poi", {})
    position = result.get("position", {})
    address = result.get("address", {})
    
    # Extract geometry
    geometry = None
    if position:
        geometry = PlaceGeometry(
            lat=position.get("lat", 0.0),
            lng=position.get("lon", 0.0)
        )
    
    # Format address
    address_parts = []
    if address.get("streetNumber"):
        address_parts.append(address["streetNumber"])
    if address.get("streetName"):
        address_parts.append(address["streetName"])
    if address.get("municipality"):
        address_parts.append(address["municipality"])
    if address.get("countrySubdivision"):
        address_parts.append(address["countrySubdivision"])
    if address.get("country"):
        address_parts.append(address["country"])
    
    formatted_address = ", ".join(address_parts) if address_parts else address.get("freeformAddress", "")
    
    # Extract categories from classifications
    types = []
    classifications = poi.get("classifications", [])
    for classification in classifications:
        if classification.get("code"):
            types.append(classification["code"])
    
    # Extract photos if available
    photos = []
    if poi.get("image"):
        photos.append(PlacePhoto(
            photo_reference="tomtom_image",
            height=0,
            width=0
        ))
    
    return PlaceResult(
        place_id=result.get("id", ""),
        name=poi.get("name", result.get("address", {}).get("freeformAddress", "")),
        formatted_address=formatted_address,
        vicinity=address.get("municipality", ""),
        geometry=geometry,
        rating=None,  # TomTom search doesn't include ratings
        user_ratings_total=None,
        price_level=None,
        types=types,
        opening_hours=None,
        photos=photos,
        icon=None,
        business_status=None,
    )


def _parse_place_details(result: dict) -> PlaceDetailsResult:
    """
    Convert a TomTom Place Details API result into a PlaceDetailsResult schema.
    
    TomTom place details result has same structure as search results but with
    additional fields like ratings, reviews, hours, etc. in some cases.
    """
    poi = result.get("poi", {})
    position = result.get("position", {})
    address = result.get("address", {})
    
    # Extract geometry
    geometry = None
    if position:
        geometry = PlaceGeometry(
            lat=position.get("lat", 0.0),
            lng=position.get("lon", 0.0)
        )
    
    # Format address
    address_parts = []
    if address.get("streetNumber"):
        address_parts.append(address["streetNumber"])
    if address.get("streetName"):
        address_parts.append(address["streetName"])
    if address.get("municipality"):
        address_parts.append(address["municipality"])
    if address.get("countrySubdivision"):
        address_parts.append(address["countrySubdivision"])
    if address.get("country"):
        address_parts.append(address["country"])
    
    formatted_address = ", ".join(address_parts) if address_parts else address.get("freeformAddress", "")
    
    # Extract categories
    types = []
    classifications = poi.get("classifications", [])
    for classification in classifications:
        if classification.get("code"):
            types.append(classification["code"])
    
    # Extract photos
    photos = []
    if poi.get("image"):
        photos.append(PlacePhoto(
            photo_reference="tomtom_image",
            height=0,
            width=0
        ))
    
    # Extract opening hours
    opening_hours_data = None
    if poi.get("openingHours"):
        opening_hours_data = poi["openingHours"]
    
    # Try to extract rating from reviews or ratings field (if TomTom provides it)
    rating = poi.get("rating")
    user_ratings_total = poi.get("review_count")
    
    editorial_summary = poi.get("description") or poi.get("summary")
    
    return PlaceDetailsResult(
        place_id=result.get("id", ""),
        name=poi.get("name", address.get("freeformAddress", "")),
        formatted_address=formatted_address,
        formatted_phone_number=poi.get("phone"),
        international_phone_number=None,
        website=poi.get("url"),
        geometry=geometry,
        rating=rating,
        user_ratings_total=user_ratings_total,
        price_level=None,
        types=types,
        opening_hours=opening_hours_data,
        photos=photos,
        url=poi.get("url"),
        editorial_summary=editorial_summary,
    )


def text_search_places(
    query: str,
    language: str = "en",
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    limit: int = 20,
) -> PlacesSearchResponse:
    """
    Search for places using TomTom Fuzzy Search API.
    
    This performs a free-text search that can include place names, addresses,
    keywords, etc. Optionally biased by coordinates.
    
    Args:
        query: Free-text search string, e.g. "restaurants in Paris" or "Eiffel Tower"
        language: Language code for results (default "en", converted to "en-US" for TomTom)
        lat: Optional latitude to bias search results
        lng: Optional longitude to bias search results
        limit: Max results to return (1-100, default 20)
    
    Returns:
        PlacesSearchResponse with search results
    """
    api_key = _get_api_key()
    language = _normalize_language_code(language)
    
    # URL encode the query
    query_encoded = query.replace(" ", "%20")
    url = f"{TOMTOM_BASE_URL}/search/{query_encoded}.json"
    
    params = {
        "key": api_key,
        "language": language,
        "limit": min(limit, 100),
    }
    
    # Add coordinates for spatial biasing if provided
    if lat is not None and lng is not None:
        params["lat"] = lat
        params["lon"] = lng
    
    try:
        with httpx.Client(timeout=10.0) as client:
            resp = client.get(url, params=params)
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPError as exc:
        logger.error(f"TomTom search failed: {exc}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"TomTom Search API request failed: {exc}",
        )
    
    # Check for TomTom error responses
    if data.get("errorText"):
        logger.warning(f"TomTom API error: {data.get('errorText')}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"TomTom API error: {data.get('errorText')}",
        )
    
    results = data.get("results", [])
    
    return PlacesSearchResponse(
        results=[_parse_search_result(r) for r in results],
        next_page_token=None,  # TomTom uses limit/offset, not tokens
        status="OK" if results else "ZERO_RESULTS",
    )


def nearby_search_places(
    lat: float,
    lng: float,
    radius: int = 5000,
    keyword: Optional[str] = None,
    language: str = "en",
    limit: int = 20,
) -> PlacesSearchResponse:
    """
    Search for places near a geographic coordinate using TomTom Nearby Search API.
    
    Args:
        lat: Latitude of search center
        lng: Longitude of search center
        radius: Search radius in meters (default 5000, max 50000)
        keyword: Optional keyword to filter results (e.g., "restaurants")
        language: Language code for results (default "en", converted to "en-US" for TomTom)
        limit: Max results to return (1-100)
    
    Returns:
        PlacesSearchResponse with nearby results
    """
    api_key = _get_api_key()
    language = _normalize_language_code(language)
    
    # URL: /nearbySearch/.json
    url = f"{TOMTOM_BASE_URL}/nearbySearch/.json"
    
    # TomTom uses radiusInMeters, max 50000
    radius_clamped = min(max(radius, 100), 50000)
    
    params = {
        "key": api_key,
        "lat": lat,
        "lon": lng,
        "radiusInMeters": radius_clamped,
        "language": language,
        "limit": min(limit, 100),
    }
    
    # Add keyword if provided
    if keyword:
        params["query"] = keyword
    
    try:
        with httpx.Client(timeout=10.0) as client:
            resp = client.get(url, params=params)
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPError as exc:
        logger.error(f"TomTom nearby search failed: {exc}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"TomTom Nearby Search API request failed: {exc}",
        )
    
    if data.get("errorText"):
        logger.warning(f"TomTom API error: {data.get('errorText')}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"TomTom API error: {data.get('errorText')}",
        )
    
    results = data.get("results", [])
    
    return PlacesSearchResponse(
        results=[_parse_search_result(r) for r in results],
        next_page_token=None,
        status="OK" if results else "ZERO_RESULTS",
    )


def get_place_details(
    entity_id: str,
    language: str = "en",
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    country: Optional[str] = None,
    fallback_name: Optional[str] = None,
) -> PlaceDetailsResponse:
    """
    Retrieve full details for a place using its TomTom entity ID.
    
    If entity_id doesn't return a direct match, uses intelligent fallback:
    1. Search by name with coordinates for geographic context
    2. Filter by country if provided
    3. Match against original latitude/longitude if available
    
    Args:
        entity_id: The TomTom entity ID (from search results) or place name
        language: Language code for results (default "en", converted to "en-US" for TomTom)
        latitude: Original latitude for fallback matching
        longitude: Original longitude for fallback matching
        country: Country code (e.g., "SA") for filtering search results
        fallback_name: Place name to use if entity_id doesn't work
    
    Returns:
        PlaceDetailsResponse with full place details
    """
    api_key = _get_api_key()
    language = _normalize_language_code(language)
    
    logger.debug(
        f"get_place_details called with entity_id='{entity_id}', "
        f"lat={latitude}, lng={longitude}, country={country}"
    )
    
    # Step 1: Try direct search/lookup with the entity_id
    try:
        search_response = text_search_places(
            query=entity_id,
            language=language,
            lat=latitude,
            lng=longitude,
            limit=5,  # Get top 5 to find best match
        )
        
        if search_response.results and len(search_response.results) > 0:
            # If we have coordinates, find closest match by distance
            if latitude is not None and longitude is not None:
                best_match = _find_closest_place(
                    search_response.results,
                    latitude,
                    longitude,
                    country=country,
                    target_name=fallback_name or entity_id,
                )
                if best_match:
                    details_result = _convert_to_details_result(best_match)
                    logger.info(
                        f"Matched '{fallback_name or entity_id}' with coordinates fallback"
                    )
                    return PlaceDetailsResponse(result=details_result, status="OK")
            
            # Otherwise, return top result
            place_result = search_response.results[0]
            details_result = _convert_to_details_result(place_result)
            logger.info(f"Returned top search result for '{entity_id}'")
            return PlaceDetailsResponse(result=details_result, status="OK")
    except Exception as search_exc:
        logger.debug(f"Direct search failed: {search_exc}")
    
    # Step 2: Fallback with name and country context if available
    if fallback_name:
        try:
            logger.info(
                f"Attempting fallback search: name='{fallback_name}', "
                f"country={country}, lat={latitude}, lng={longitude}"
            )
            fallback_response = text_search_places(
                query=fallback_name,
                language=language,
                lat=latitude,
                lng=longitude,
                limit=5,
            )
            
            if fallback_response.results and len(fallback_response.results) > 0:
                # Find best match with all available context
                best_match = _find_closest_place(
                    fallback_response.results,
                    latitude,
                    longitude,
                    country=country,
                    target_name=fallback_name,
                )
                if best_match:
                    details_result = _convert_to_details_result(best_match)
                    logger.info(f"Fallback: Matched '{fallback_name}' with context")
                    return PlaceDetailsResponse(result=details_result, status="OK")
                
                # If no good match, return top result with warning
                logger.warning(
                    f"Fallback: No exact match for '{fallback_name}', "
                    f"returning best result"
                )
                place_result = fallback_response.results[0]
                details_result = _convert_to_details_result(place_result)
                return PlaceDetailsResponse(result=details_result, status="OK")
        except Exception as fallback_exc:
            logger.debug(f"Fallback search failed: {fallback_exc}")
    
    # If all methods fail, log and raise error
    logger.error(
        f"Could not find place details for '{entity_id}' "
        f"(fallback_name='{fallback_name}')"
    )
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=f"Place '{entity_id}' not found in TomTom database",
    )


def _find_closest_place(
    results: list,
    target_lat: Optional[float],
    target_lng: Optional[float],
    country: Optional[str] = None,
    target_name: Optional[str] = None,
) -> Optional[PlaceResult]:
    """
    Find the closest/best-matching place from search results.
    
    Strategy:
    1. Filter by country if provided
    2. Filter by name similarity if target_name provided
    3. Find closest by coordinates if available
    """
    if not results:
        return None
    
    candidates = results
    
    # Filter by country if provided
    if country:
        country_upper = country.upper()
        logger.debug(f"Filtering by country: {country_upper}")
        candidates = [
            r for r in candidates
            if _extract_country_code(r.formatted_address) == country_upper
        ]
        if not candidates:
            logger.debug(f"No results found in country {country_upper}")
            candidates = results  # Fallback to all results
    
    # Filter by name similarity if target_name provided
    if target_name:
        target_lower = target_name.lower().strip()
        exact_match = [
            r for r in candidates
            if r.name.lower().strip() == target_lower
        ]
        if exact_match:
            logger.debug(f"Found exact name match: {exact_match[0].name}")
            return exact_match[0]
        
        # Prefix match
        prefix_match = [
            r for r in candidates
            if r.name.lower().startswith(target_lower)
        ]
        if prefix_match:
            logger.debug(f"Found prefix match: {prefix_match[0].name}")
            return prefix_match[0]
    
    # Find closest by distance if coordinates available
    if target_lat is not None and target_lng is not None:
        def distance(place: PlaceResult) -> float:
            if place.geometry is None:
                return float('inf')
            lat_diff = place.geometry.lat - target_lat
            lng_diff = place.geometry.lng - target_lng
            return (lat_diff ** 2 + lng_diff ** 2) ** 0.5
        
        try:
            closest = min(candidates, key=distance)
            dist = distance(closest)
            logger.debug(
                f"Found closest match '{closest.name}' at distance {dist:.4f}"
            )
            return closest
        except (ValueError, TypeError):
            logger.debug("Could not calculate distance")
    
    # Return first result as fallback
    logger.debug(f"Returning top result: {candidates[0].name}")
    return candidates[0] if candidates else None


def _extract_country_code(formatted_address: Optional[str]) -> Optional[str]:
    """Extract country code from formatted address (last part after comma)."""
    if not formatted_address:
        return None
    
    parts = formatted_address.split(",")
    if len(parts) > 0:
        country_part = parts[-1].strip()
        # Try to extract country code (usually 2 letters at the end)
        words = country_part.split()
        if words:
            last_word = words[-1]
            if len(last_word) == 2 and last_word.isupper():
                return last_word
            # Some countries have full names, map the common ones
            country_map = {
                "Saudi Arabia": "SA",
                "United Arab Emirates": "AE",
                "Egypt": "EG",
                "Qatar": "QA",
                "Kuwait": "KW",
                "France": "FR",
                "United States": "US",
                "United Kingdom": "GB",
                "Germany": "DE",
                "Japan": "JP",
                "China": "CN",
                "India": "IN",
            }
            if country_part in country_map:
                return country_map[country_part]
    return None


def _convert_to_details_result(place_result: PlaceResult) -> PlaceDetailsResult:
    """Convert PlaceResult to PlaceDetailsResult."""
    return PlaceDetailsResult(
        place_id=place_result.place_id,
        name=place_result.name,
        formatted_address=place_result.formatted_address,
        formatted_phone_number=None,
        international_phone_number=None,
        website=None,
        geometry=place_result.geometry,
        rating=place_result.rating,
        user_ratings_total=place_result.user_ratings_total,
        price_level=place_result.price_level,
        types=place_result.types or [],
        opening_hours=place_result.opening_hours,
        photos=place_result.photos or [],
        url=None,
        editorial_summary=None,
    )


def get_photo_url(photo_reference: str, max_width: int = 800) -> str:
    """
    Return a photo URL. For TomTom, this would be the direct image URL from the
    place details, or a placeholder/default image.
    
    Args:
        photo_reference: Photo reference from TomTom (typically a URL)
        max_width: Max width (for compatibility, TomTom handles this server-side)
    
    Returns:
        URL string that can be used as an image src
    """
    # If photo_reference is already a URL, return it as-is
    if photo_reference.startswith("http"):
        return photo_reference
    
    # Otherwise, return a placeholder or construct a TomTom image URL
    # For now, return the reference as-is (would be a URL from place details)
    return photo_reference
