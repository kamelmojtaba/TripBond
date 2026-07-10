"""
AI POI Service - Integration with TripBond AI Backend Dataset + Google Places Photo Enrichment

Combines:
1. Primary: Pre-trained AI recommendations from CSV datasets
2. Enrichment: Google Places API for photos and nearby place matching
"""

import pandas as pd
import logging
import math
import re
from pathlib import Path
from typing import List, Optional, Dict, Any
from app.config import get_settings

logger = logging.getLogger(__name__)

# Paths to AI backend datasets
AI_BACKEND_ROOT = Path(__file__).parent.parent.parent.parent / "tripbond_ai_backend"
DATA_DIR = AI_BACKEND_ROOT / "data"

# Cache datasets in memory
_pois_cache = None
_group_recs_cache = None

_GENERIC_DESTINATION_TOKENS = {
    "saudi arabia",
    "kingdom of saudi arabia",
    "ksa",
    "saudi",
}

_CITY_ALIASES = {
    "khobar": ["Al Khobar"],
    "al khobar": ["Al Khobar", "Khobar"],
    "kaec": ["King Abdullah Economic City"],
    "king abdullah economic city": ["King Abdullah Economic City"],
    "alula": ["AlUla", "Al Ula"],
    "al ula": ["AlUla"],
    "buraidah": ["Buraydah"],
    "buraydah": ["Buraydah", "Buraidah"],
    "medina": ["Madinah"],
    "madinah": ["Madinah", "Medina"],
    "mecca": ["Makkah"],
    "makkah": ["Makkah", "Mecca"],
    "as seer": ["Aseer"],
    "asir": ["Aseer", "Abha"],
}


def invalidate_poi_dataset_cache() -> None:
    """Clear in-memory POI CSV cache (call after updating the dataset file)."""
    global _pois_cache, _group_recs_cache
    _pois_cache = None
    _group_recs_cache = None


def _load_poi_dataset() -> Optional[pd.DataFrame]:
    """Load integrated POI dataset."""
    global _pois_cache
    if _pois_cache is not None:
        return _pois_cache
    
    try:
        poi_file = DATA_DIR / "final_integrated_poi_dataset.csv"
        if not poi_file.exists():
            logger.warning(f"POI dataset not found at {poi_file}")
            return None
        
        _pois_cache = pd.read_csv(poi_file)
        logger.info(f"Loaded {len(_pois_cache)} POIs from AI backend dataset")
        return _pois_cache
    except Exception as e:
        logger.error(f"Failed to load POI dataset: {e}")
        return None


def _load_group_recommendations() -> Optional[pd.DataFrame]:
    """Load group-recommended POIs."""
    global _group_recs_cache
    if _group_recs_cache is not None:
        return _group_recs_cache
    
    try:
        recs_file = DATA_DIR / "top_pois_for_group.csv"
        if not recs_file.exists():
            logger.warning(f"Group recommendations not found at {recs_file}")
            return None
        
        _group_recs_cache = pd.read_csv(recs_file)
        logger.info(f"Loaded {len(_group_recs_cache)} group recommendations from AI backend")
        return _group_recs_cache
    except Exception as e:
        logger.error(f"Failed to load group recommendations: {e}")
        return None


def _clean_text(value: Any) -> Optional[str]:
    if value is None:
        return None
    if isinstance(value, float) and math.isnan(value):
        return None
    text = str(value).strip()
    if not text or text.lower() == "nan":
        return None
    return text


def _safe_float(value: Any) -> Optional[float]:
    try:
        if value is None or (isinstance(value, float) and math.isnan(value)):
            return None
        return float(value)
    except (TypeError, ValueError):
        return None


def _safe_int(value: Any) -> int:
    try:
        if value is None or (isinstance(value, float) and math.isnan(value)):
            return 0
        return int(float(value))
    except (TypeError, ValueError):
        return 0


def _normalise_key(value: Any) -> str:
    text = _clean_text(value)
    if not text:
        return ""
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()


def _destination_candidates(destination: str) -> List[str]:
    raw = _clean_text(destination)
    if not raw:
        return []

    pieces = [raw]
    pieces.extend(part.strip() for part in re.split(r"[,/|()\-]+", raw) if part.strip())

    candidates: List[str] = []
    for piece in pieces:
        normalised = _normalise_key(piece)
        if not normalised or normalised in _GENERIC_DESTINATION_TOKENS:
            continue
        candidates.append(piece)
        without_country = normalised
        for token in _GENERIC_DESTINATION_TOKENS:
            without_country = without_country.replace(token, "").strip()
        if without_country and without_country != normalised:
            candidates.append(without_country)
        candidates.extend(_CITY_ALIASES.get(normalised, []))

    seen = set()
    unique: List[str] = []
    for candidate in candidates:
        key = _normalise_key(candidate)
        if key and key not in seen:
            seen.add(key)
            unique.append(candidate)
    return unique


def _matching_pois_for_destination(pois_df: pd.DataFrame, destination: str) -> pd.DataFrame:
    candidates = _destination_candidates(destination)
    if not candidates:
        return pois_df.iloc[0:0]

    candidate_keys = {_normalise_key(candidate) for candidate in candidates}
    candidate_keys.discard("")

    city_keys = pois_df["city"].map(_normalise_key)
    province_keys = pois_df["province"].map(_normalise_key)

    exact = pois_df[city_keys.isin(candidate_keys)]
    if not exact.empty:
        return exact

    mask = pd.Series(False, index=pois_df.index)
    for key in candidate_keys:
        if len(key) < 3 or key in _GENERIC_DESTINATION_TOKENS:
            continue
        mask = (
            mask
            | city_keys.str.contains(key, regex=False, na=False)
            | province_keys.str.contains(key, regex=False, na=False)
        )
    return pois_df[mask]


def _dataset_row_to_poi(row: pd.Series, destination: str) -> Dict:
    city = _clean_text(row.get("city")) or destination
    province = _clean_text(row.get("province"))
    category = _clean_text(row.get("category")) or "attraction"
    poi_type = _clean_text(row.get("poi_type")) or category
    poi_id = _clean_text(row.get("poi_id")) or _clean_text(row.get("id")) or _clean_text(row.get("name")) or ""
    tags = [tag for tag in [category, poi_type, province] if tag]

    return {
        "id": str(poi_id),
        "external_place_id": str(poi_id),
        "name": _clean_text(row.get("name")) or "Unknown",
        "location": city,
        "address": ", ".join(part for part in [city, province] if part),
        "type": poi_type,
        "category": category,
        "poi_type": poi_type,
        "rating": _safe_float(row.get("rating")),
        "description": _clean_text(row.get("description")),
        "image_url": _clean_text(row.get("image_url")),
        "latitude": _safe_float(row.get("latitude")),
        "longitude": _safe_float(row.get("longitude")),
        "review_count": _safe_int(row.get("review_count")),
        "user_ratings_total": _safe_int(row.get("review_count")),
        "opening_hours": _clean_text(row.get("opening_hours")),
        "province": province,
        "tags": tags,
    }


def _row_has_coordinates(row: pd.Series) -> bool:
    return _safe_float(row.get("latitude")) is not None and _safe_float(row.get("longitude")) is not None


def _city_center_for_destination(destination: str) -> Optional[tuple[float, float]]:
    candidate_keys = {_normalise_key(candidate) for candidate in _destination_candidates(destination)}
    candidate_keys.discard("")
    if not candidate_keys:
        return None

    try:
        from . import cities_service

        for city in cities_service.list_cities(min_count=1):
            if _normalise_key(city.get("name")) in candidate_keys:
                lat = _safe_float(city.get("lat"))
                lng = _safe_float(city.get("lng"))
                if lat is not None and lng is not None:
                    return lat, lng
    except Exception as exc:
        logger.debug("Could not resolve city center for %s: %s", destination, exc)

    return None


def _with_city_center_coordinates(poi: Dict, destination: str, index: int) -> Dict:
    if poi.get("latitude") is not None and poi.get("longitude") is not None:
        return poi

    center = _city_center_for_destination(poi.get("location") or destination)
    if center is None:
        return poi

    lat, lng = center
    # Spread inferred coordinates slightly so cards can be selected and mapped
    # without every marker landing on the exact same city-center point.
    poi["latitude"] = round(lat + ((index % 5) - 2) * 0.002, 6)
    poi["longitude"] = round(lng + (((index // 5) % 5) - 2) * 0.002, 6)
    poi["coordinates_inferred"] = True
    return poi


def _google_place_to_poi(place: Any, destination: str) -> Optional[Dict]:
    geometry = getattr(place, "geometry", None)
    latitude = getattr(geometry, "lat", None) if geometry else None
    longitude = getattr(geometry, "lng", None) if geometry else None
    types = list(getattr(place, "types", []) or [])
    place_id = getattr(place, "place_id", None)
    name = getattr(place, "name", None)

    if not place_id or not name or latitude is None or longitude is None:
        return None

    display_type = next(
        (t for t in types if t not in {"point_of_interest", "establishment"}),
        "attraction",
    )
    address = getattr(place, "formatted_address", None) or getattr(place, "vicinity", None)

    return {
        "id": str(place_id),
        "external_place_id": str(place_id),
        "place_id": str(place_id),
        "name": str(name),
        "location": address or destination,
        "address": address or destination,
        "type": display_type,
        "category": display_type,
        "poi_type": display_type,
        "rating": getattr(place, "rating", None),
        "price_level": getattr(place, "price_level", None),
        "description": None,
        "image_url": getattr(place, "image_url", None),
        "latitude": float(latitude),
        "longitude": float(longitude),
        "review_count": getattr(place, "user_ratings_total", None) or 0,
        "user_ratings_total": getattr(place, "user_ratings_total", None) or 0,
        "tags": types,
    }


def _get_external_pois_for_destination(destination: str, limit: int) -> List[Dict]:
    try:
        from . import google_places_service

        response = google_places_service.text_search_places(
            query=f"top tourist attractions in {destination}",
            language="en",
        )
    except Exception as exc:
        logger.warning("Google Places fallback unavailable for %s: %s", destination, exc)
    else:
        pois = _places_response_to_pois(response.results, destination, limit)
        if pois:
            return pois

    try:
        from . import geoapify_service

        response = geoapify_service.text_search_places(
            query=f"top tourist attractions in {destination}",
            language="en",
        )
    except Exception as exc:
        logger.warning("Geoapify fallback unavailable for %s: %s", destination, exc)
        return []

    return _places_response_to_pois(response.results, destination, limit)


def _places_response_to_pois(places: List[Any], destination: str, limit: int) -> List[Dict]:
    pois: List[Dict] = []
    for place in places:
        poi = _google_place_to_poi(place, destination)
        if poi:
            pois.append(poi)
        if len(pois) >= limit:
            break
    return pois


def _enrich_with_photos(poi: Dict, lat: Optional[float], lng: Optional[float]) -> Dict:
    """
    Enrich a POI with an image URL from Google Places API.
    
    Complete flow:
    1. Search for the POI by name
    2. Get the place_id from search results
    3. Call Place Details API for that place_id
    4. Extract the first photo_reference
    5. Build the photo URL
    
    Args:
        poi: POI dictionary from CSV
        lat: Latitude for nearby search bias
        lng: Longitude for nearby search bias
    
    Returns:
        Enhanced POI dictionary with image_url field
    """
    poi_name = poi.get('name', 'Unknown')
    try:
        settings = get_settings()
    except Exception as exc:
        logger.debug(f"Skipping enrichment for {poi_name}: settings unavailable ({exc})")
        return poi
    
    # Only proceed if coordinates are provided
    if lat is None or lng is None:
        logger.debug(f"Skipping enrichment for {poi_name}: missing coordinates (lat={lat}, lng={lng})")
        return poi
    
    # Only proceed if Google Maps API key is configured
    if not settings.google_maps_api_key:
        logger.debug(f"Skipping enrichment for {poi_name}: Google Maps API key not configured")
        return poi
    
    try:
        from .google_places_service import get_image_url_for_place
        
        # Call the complete flow: search, get details, extract photo, build URL.
        image_url = get_image_url_for_place(
            place_name=poi_name,
            lat=lat,
            lng=lng,
            language='en'
        )
        
        # Only update if Google Places found an image
        if image_url:
            poi["image_url"] = image_url
            logger.info(f"Enriched '{poi_name}' with image URL from Google Places")
        else:
            logger.debug(f"No image URL found from Google Places for '{poi_name}' (keeping CSV image if available)")
        
        return poi
        
    except Exception as e:
        logger.debug(f"Error enriching '{poi_name}' with image URL: {e}")
        return poi


def get_pois_for_destination(
    destination: str,
    limit: int = 15,
    enrich_photos: bool = False,
    require_coordinates: bool = False,
) -> List[Dict]:
    """
    Get POIs for a destination from the AI backend dataset, enriched with Google Places photos.
    
    Args:
        destination: City or destination name
        limit: Number of POIs to return
        enrich_photos: When true, fetch Google Places photos for dataset rows
        require_coordinates: When true, fall back to external search if dataset rows lack coordinates
    
    Returns:
        List of POI dictionaries with CSV data and Google Places photo enrichment
    """
    pois_df = _load_poi_dataset()
    if pois_df is None:
        logger.warning("POI dataset unavailable")
        return []
    
    matching = _matching_pois_for_destination(pois_df, destination)
    if matching.empty:
        logger.warning(f"No AI POIs found for destination: {destination}; trying external search")
        return _get_external_pois_for_destination(destination, limit=limit)

    use_city_center_fallback = False
    if require_coordinates:
        matching_with_coordinates = matching[matching.apply(_row_has_coordinates, axis=1)]
        if matching_with_coordinates.empty:
            if _city_center_for_destination(destination) is not None:
                logger.warning(
                    "AI POIs for %s lack coordinates; using city-center fallback",
                    destination,
                )
                use_city_center_fallback = True
            else:
                logger.warning(
                    "AI POIs for %s lack coordinates and no city center is known; "
                    "trying external search",
                    destination,
                )
                external_pois = _get_external_pois_for_destination(destination, limit=limit)
                if external_pois:
                    return external_pois
                use_city_center_fallback = True
        else:
            matching = matching_with_coordinates

    matching = matching.assign(
        _rating_sort=matching["rating"].apply(lambda value: _safe_float(value) or 0),
        _review_sort=matching["review_count"].apply(_safe_int),
    ).sort_values(["_rating_sort", "_review_sort"], ascending=False)

    # Convert to output format and enrich with Google Places photos.
    result = []
    for index, (_, row) in enumerate(matching.head(limit).iterrows()):
        poi = _dataset_row_to_poi(row, destination)
        if use_city_center_fallback:
            poi = _with_city_center_coordinates(poi, destination, index)
        if enrich_photos:
            poi = _enrich_with_photos(poi, poi["latitude"], poi["longitude"])
        result.append(poi)
    
    logger.info(f"Loaded {len(result)} POIs from AI backend for {destination}")
    return result


def get_recommended_pois(limit: int = 20) -> List[Dict]:
    """
    Get the AI-recommended top POIs from the group recommender, enriched with Google Places photos.
    
    Returns:
        List of recommended POI dictionaries with Google Places photo enrichment
    """
    group_recs = _load_group_recommendations()
    pois_df = _load_poi_dataset()
    
    if group_recs is None or pois_df is None:
        logger.warning("Cannot load recommended POIs")
        return []
    
    # Get top N by final_group_score
    top_recs = group_recs.nlargest(limit, 'final_group_score')
    
    result = []
    for _, rec in top_recs.iterrows():
        poi_id = rec.get('poi_id')
        
        # Find matching POI details
        poi_details = pois_df[pois_df['poi_id'] == poi_id]
        
        if poi_details.empty:
            # Fallback: create record from recommendations row
            poi = {
                "id": str(poi_id),
                "name": f"POI {poi_id}",
                "location": "Multiple",
                "type": str(rec.get('poi_category', 'attraction')),
                "rating": float(rec.get('poi_normalized_rating', 4.0)),
                "latitude": float(rec.get('poi_latitude', 0)) if pd.notna(rec.get('poi_latitude')) else None,
                "longitude": float(rec.get('poi_longitude', 0)) if pd.notna(rec.get('poi_longitude')) else None,
                "group_score": float(rec.get('final_group_score', 0)),
                "fairness_score": float(rec.get('fairness_score', 0)),
            }
        else:
            poi_row = poi_details.iloc[0]
            poi = {
                "id": str(poi_id),
                "name": str(poi_row.get('name', 'Unknown')),
                "location": str(poi_row.get('city', 'Multiple')),
                "type": str(poi_row.get('category', 'attraction')),
                "rating": float(poi_row.get('rating', 4.0)),
                "description": str(poi_row.get('description', '')),
                "latitude": float(poi_row.get('latitude', 0)) if pd.notna(poi_row.get('latitude')) else None,
                "longitude": float(poi_row.get('longitude', 0)) if pd.notna(poi_row.get('longitude')) else None,
                "group_score": float(rec.get('final_group_score', 0)),
                "fairness_score": float(rec.get('fairness_score', 0)),
            }
        
        poi = _enrich_with_photos(poi, poi.get("latitude"), poi.get("longitude"))
        result.append(poi)
    
    return result


def search_pois(query: str, limit: int = 20) -> List[Dict]:
    """
    Search POIs by name or description, enriched with Google Places photos.
    
    Args:
        query: Search query
        limit: Number of results
    
    Returns:
        List of matching POIs with Google Places photo enrichment
    """
    pois_df = _load_poi_dataset()
    if pois_df is None:
        return []
    
    query_lower = query.lower()
    
    # Search in name and description
    matching = pois_df[
        (pois_df['name'].str.lower().str.contains(query_lower, na=False)) |
        (pois_df['description'].str.lower().str.contains(query_lower, na=False)) |
        (pois_df['category'].str.lower().str.contains(query_lower, na=False))
    ]
    
    result = []
    for _, row in matching.head(limit).iterrows():
        poi = {
            "id": str(row.get('poi_id', '')),
            "name": str(row.get('name', 'Unknown')),
            "location": str(row.get('city', '')),
            "type": str(row.get('category', 'attraction')),
            "rating": float(row.get('rating', 4.0)),
            "description": str(row.get('description', '')),
            "latitude": float(row.get('latitude', 0)) if pd.notna(row.get('latitude')) else None,
            "longitude": float(row.get('longitude', 0)) if pd.notna(row.get('longitude')) else None,
        }
        
        poi = _enrich_with_photos(poi, poi.get("latitude"), poi.get("longitude"))
        result.append(poi)
    
    return result
