"""
Google Places Service

Wraps the Google Places API (Text Search, Nearby Search, Place Details)
for use on the TripBond homepage and POI discovery features.

Requires GOOGLE_MAPS_API_KEY to be set in the environment / .env file.
"""

import httpx
import logging
from fastapi import HTTPException, status
from datetime import datetime, timedelta, timezone
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
    CachedPlaceImage,
)

logger = logging.getLogger(__name__)

PLACES_BASE_URL = "https://places.googleapis.com/v1"
SEARCH_FIELD_MASK = (
    "places.id,places.displayName,places.formattedAddress,places.shortFormattedAddress,"
    "places.location,places.rating,places.userRatingCount,places.priceLevel,places.types,"
    "places.currentOpeningHours,places.photos,places.businessStatus,nextPageToken"
)
DETAILS_FIELD_MASK = (
    "id,displayName,formattedAddress,nationalPhoneNumber,internationalPhoneNumber,"
    "websiteUri,location,rating,userRatingCount,priceLevel,types,regularOpeningHours,"
    "photos,googleMapsUri,editorialSummary,businessStatus"
)


def _cache_expiry_iso() -> str:
    days = max(1, get_settings().place_cache_days)
    return (datetime.now(timezone.utc) + timedelta(days=days)).isoformat()


def _get_api_key() -> str:
    """Return the configured Google Maps API key or raise 503."""
    key = get_settings().google_maps_api_key
    if not key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google Maps API key is not configured. Set GOOGLE_MAPS_API_KEY in your environment.",
        )
    return key


def _headers(field_mask: str) -> dict:
    return {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": _get_api_key(),
        "X-Goog-FieldMask": field_mask,
    }


def _google_error_message(response: httpx.Response) -> str:
    try:
        data = response.json()
    except ValueError:
        return response.text
    error = data.get("error")
    if isinstance(error, dict):
        return error.get("message") or error.get("status") or str(error)
    return data.get("error_message") or data.get("status") or str(data)


def _raise_google_http_error(exc: httpx.HTTPStatusError, operation: str) -> None:
    message = _google_error_message(exc.response)
    logger.error("Google Places %s failed: %s", operation, message)
    raise HTTPException(
        status_code=status.HTTP_502_BAD_GATEWAY,
        detail=f"Google Places API request failed: {message}",
    )


def _localized_text(value: Optional[dict]) -> Optional[str]:
    if not isinstance(value, dict):
        return None
    return value.get("text")


def _parse_price_level(value) -> Optional[int]:
    if isinstance(value, int):
        return value
    mapping = {
        "PRICE_LEVEL_FREE": 0,
        "PRICE_LEVEL_INEXPENSIVE": 1,
        "PRICE_LEVEL_MODERATE": 2,
        "PRICE_LEVEL_EXPENSIVE": 3,
        "PRICE_LEVEL_VERY_EXPENSIVE": 4,
    }
    return mapping.get(value or "")


def _parse_location(place: dict) -> Optional[PlaceGeometry]:
    location = place.get("location") or {}
    lat = location.get("latitude")
    lng = location.get("longitude")
    if lat is None or lng is None:
        return None
    return PlaceGeometry(lat=lat, lng=lng)


def _parse_opening_hours(place: dict) -> Optional[PlaceOpeningHours]:
    opening = place.get("currentOpeningHours") or place.get("regularOpeningHours")
    if not isinstance(opening, dict):
        return None
    return PlaceOpeningHours(open_now=opening.get("openNow"))


def _parse_photo(photo: dict, sort_order: int = 0, max_width: int = 1200) -> PlacePhoto:
    reference = photo.get("name") or photo.get("photo_reference", "")
    attributions = []
    for attribution in photo.get("authorAttributions", []) or []:
        if isinstance(attribution, dict):
            display_name = attribution.get("displayName")
            uri = attribution.get("uri")
            if display_name and uri:
                attributions.append(f'<a href="{uri}">{display_name}</a>')
            elif display_name:
                attributions.append(display_name)
    attributions.extend(photo.get("html_attributions", []) or [])
    image_url = get_photo_url(reference, max_width=max_width) if reference else None
    return PlacePhoto(
        photo_reference=reference,
        height=photo.get("heightPx", photo.get("height", 0)),
        width=photo.get("widthPx", photo.get("width", 0)),
        html_attributions=attributions,
        image_url=image_url,
    )


def photos_to_cached_images(photos: list[PlacePhoto], expires_at: Optional[str] = None) -> list[CachedPlaceImage]:
    """Build ordered app image entries from Google Places photo metadata."""
    expiry = expires_at or _cache_expiry_iso()
    images: list[CachedPlaceImage] = []
    seen: set[str] = set()
    for index, photo in enumerate(photos):
        if not photo.photo_reference or photo.photo_reference in seen:
            continue
        seen.add(photo.photo_reference)
        url = photo.image_url or get_photo_url(photo.photo_reference, max_width=1200)
        images.append(
            CachedPlaceImage(
                url=url,
                width=photo.width,
                height=photo.height,
                source="google_places",
                attributions=photo.html_attributions,
                expires_at=expiry,
                sort_order=index,
                photo_reference=photo.photo_reference,
            )
        )
    return images

def _parse_place_result(place: dict) -> PlaceResult:
    """Convert a Places API (New) place dict into a PlaceResult schema."""
    photos = [_parse_photo(p, sort_order=index) for index, p in enumerate(place.get("photos", []))]
    images = photos_to_cached_images(photos)

    return PlaceResult(
        place_id=place["id"],
        name=_localized_text(place.get("displayName")) or "",
        formatted_address=place.get("formattedAddress"),
        vicinity=place.get("shortFormattedAddress"),
        geometry=_parse_location(place),
        rating=place.get("rating"),
        user_ratings_total=place.get("userRatingCount"),
        price_level=_parse_price_level(place.get("priceLevel")),
        types=place.get("types", []),
        opening_hours=_parse_opening_hours(place),
        photos=photos,
        images=images,
        image_url=images[0].url if images else None,
        icon=None,
        business_status=place.get("businessStatus"),
    )


def text_search_places(
    query: str,
    language: str = "en",
    next_page_token: Optional[str] = None,
) -> PlacesSearchResponse:
    """
    Search Google Places using a free-text query.
    Ideal for homepage destination search bar.

    Args:
        query: Free-text search string, e.g. "restaurants in Paris".
        language: BCP-47 language code for results.
        next_page_token: Token returned by a previous search to get the next page.

    Returns:
        PlacesSearchResponse with up to 20 results per page.
    """
    body: dict = {
        "textQuery": query,
        "languageCode": language,
        "maxResultCount": 20,
    }
    if next_page_token:
        body["pageToken"] = next_page_token

    try:
        with httpx.Client(timeout=10.0) as client:
            resp = client.post(
                f"{PLACES_BASE_URL}/places:searchText",
                json=body,
                headers=_headers(SEARCH_FIELD_MASK),
            )
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPStatusError as exc:
        _raise_google_http_error(exc, "text search")
    except httpx.HTTPError as exc:
        logger.error("Google Places text search failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Google Places API request failed: {exc}",
        )

    places = data.get("places", [])

    return PlacesSearchResponse(
        results=[_parse_place_result(p) for p in places],
        next_page_token=data.get("nextPageToken"),
        status="OK" if places else "ZERO_RESULTS",
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
    Search for places near a geographic coordinate.
    Ideal for "Explore Nearby" homepage section.

    Args:
        lat: Latitude of the search centre.
        lng: Longitude of the search centre.
        radius: Search radius in metres (max 50 000).
        place_type: Optional Google place type, e.g. "tourist_attraction".
        keyword: Optional keyword to filter results.
        language: BCP-47 language code for results.
        next_page_token: Pagination token from a previous response.

    Returns:
        PlacesSearchResponse with up to 20 results per page.
    """
    body: dict = {
        "maxResultCount": 20,
        "languageCode": language,
        "locationRestriction": {
            "circle": {
                "center": {
                    "latitude": lat,
                    "longitude": lng,
                },
                "radius": min(radius, 50000),
            }
        },
    }
    if place_type:
        body["includedTypes"] = [place_type]
    if keyword:
        # Nearby Search (New) has no keyword parameter; use Text Search with a
        # location bias when we need a named place near coordinates.
        text_body = {
            "textQuery": keyword,
            "languageCode": language,
            "maxResultCount": 20,
            "locationBias": body["locationRestriction"],
        }
        if place_type:
            text_body["includedType"] = place_type
        body = text_body
    if next_page_token:
        body["pageToken"] = next_page_token

    try:
        with httpx.Client(timeout=10.0) as client:
            endpoint = "places:searchText" if keyword else "places:searchNearby"
            resp = client.post(
                f"{PLACES_BASE_URL}/{endpoint}",
                json=body,
                headers=_headers(SEARCH_FIELD_MASK),
            )
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPStatusError as exc:
        _raise_google_http_error(exc, "nearby search")
    except httpx.HTTPError as exc:
        logger.error("Google Places nearby search failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Google Places API request failed: {exc}",
        )

    places = data.get("places", [])

    return PlacesSearchResponse(
        results=[_parse_place_result(p) for p in places],
        next_page_token=data.get("nextPageToken"),
        status="OK" if places else "ZERO_RESULTS",
    )


def get_place_details(place_id: str, language: str = "en") -> PlaceDetailsResponse:
    """
    Retrieve full details for a single place by its place_id.

    Args:
        place_id: The Google place_id string.
        language: BCP-47 language code for results.

    Returns:
        PlaceDetailsResponse with comprehensive place information.
    """
    params: dict = {
        "languageCode": language,
    }

    try:
        with httpx.Client(timeout=10.0) as client:
            resp = client.get(
                f"{PLACES_BASE_URL}/places/{place_id}",
                params=params,
                headers=_headers(DETAILS_FIELD_MASK),
            )
            resp.raise_for_status()
            data = resp.json()
    except httpx.HTTPStatusError as exc:
        if exc.response.status_code == 404:
            detail = _google_error_message(exc.response)
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Google Places API error: {detail}",
            )
        _raise_google_http_error(exc, "details")
    except httpx.HTTPError as exc:
        logger.error("Google Places details request failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Google Places API request failed: {exc}",
        )

    photos = [_parse_photo(p, sort_order=index) for index, p in enumerate(data.get("photos", []))]
    images = photos_to_cached_images(photos)

    editorial_summary = _localized_text(data.get("editorialSummary"))

    result = PlaceDetailsResult(
        place_id=data.get("id", place_id),
        name=_localized_text(data.get("displayName")) or "",
        formatted_address=data.get("formattedAddress"),
        formatted_phone_number=data.get("nationalPhoneNumber"),
        international_phone_number=data.get("internationalPhoneNumber"),
        website=data.get("websiteUri"),
        geometry=_parse_location(data),
        rating=data.get("rating"),
        user_ratings_total=data.get("userRatingCount"),
        price_level=_parse_price_level(data.get("priceLevel")),
        types=data.get("types", []),
        opening_hours=data.get("regularOpeningHours"),
        photos=photos,
        images=images,
        image_url=images[0].url if images else None,
        url=data.get("googleMapsUri"),
        editorial_summary=editorial_summary,
    )

    return PlaceDetailsResponse(result=result, status="OK")


def get_photo_url(photo_reference: str, max_width: int = 800) -> str:
    """
    Resolve a Places API (New) photo resource into a displayable image URI.

    Args:
        photo_reference: The photo resource name from a PlacePhoto.
        max_width: Maximum width of the returned image in pixels.

    Returns:
        A URL string that resolves to the photo image, without exposing the API key.
    """
    if not photo_reference:
        return ""

    params = {
        "maxWidthPx": max_width,
        "skipHttpRedirect": "true",
        "key": _get_api_key(),
    }
    try:
        with httpx.Client(timeout=10.0) as client:
            resp = client.get(f"{PLACES_BASE_URL}/{photo_reference}/media", params=params)
            resp.raise_for_status()
            data = resp.json()
            return data.get("photoUri") or str(resp.url)
    except httpx.HTTPStatusError as exc:
        logger.debug("Google Places photo lookup failed: %s", _google_error_message(exc.response))
    except httpx.HTTPError as exc:
        logger.debug("Google Places photo lookup failed: %s", exc)

    return ""


def get_image_url_for_place(place_name: str, lat: Optional[float] = None, lng: Optional[float] = None, language: str = "en") -> Optional[str]:
    """
    Complete flow: Search for a place → Get place_id → Get details → Extract photo → Build URL.
    
    This is the main entry point for enriching POIs with image URLs from Google Places.
    
    Args:
        place_name: Name of the place to search for
        lat: Optional latitude for nearby search bias
        lng: Optional longitude for nearby search bias
        language: BCP-47 language code
        
    Returns:
        A complete photo URL or None if no photos found
    """
    try:
        # Step 1: Search for the place
        if lat is not None and lng is not None:
            # Use nearby search if coordinates provided
            search_response = nearby_search_places(
                lat=lat,
                lng=lng,
                radius=2000,
                keyword=place_name,
                language=language
            )
        else:
            # Use text search if no coordinates
            search_response = text_search_places(
                query=place_name,
                language=language
            )
        
        # Step 2: Check if we got results
        if not search_response.results:
            logger.debug(f"No search results for place: {place_name}")
            return None
        
        # Step 3: Get the first result's place_id
        first_result = search_response.results[0]
        place_id = first_result.place_id
        logger.debug(f"Found place: {first_result.name} (ID: {place_id})")
        
        # Step 4: Get full details including photos
        details_response = get_place_details(place_id=place_id, language=language)
        
        # Step 5: Extract first photo_reference if available
        if details_response.result.photos:
            first_photo = details_response.result.photos[0]
            # Step 6: Build and return the photo URL
            photo_url = get_photo_url(photo_reference=first_photo.photo_reference, max_width=800)
            logger.info(f"✅ Generated image URL for {place_name}")
            return photo_url
        else:
            logger.debug(f"Place '{place_name}' found but has no photos")
            return None
            
    except HTTPException:
        # API key not configured or rate limited
        return None
    except Exception as e:
        logger.debug(f"Error getting image URL for '{place_name}': {e}")
        return None
