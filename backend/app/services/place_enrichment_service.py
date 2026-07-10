"""
Cached Google Places enrichment service.

User-facing endpoints read from this cache only. Google API calls are isolated
to admin enrichment jobs so normal app browsing does not call Google per user.
"""

from __future__ import annotations

import hashlib
import logging
import math
import re
from datetime import datetime, timedelta, timezone
from difflib import SequenceMatcher
from typing import Any, Dict, Iterable, List, Optional

import httpx
from fastapi import HTTPException, status

from ..config import get_settings
from ..database import get_supabase_admin_client
from ..schemas.places import PlaceDetailsResponse, PlaceDetailsResult, PlacePhoto
from . import ai_poi_service, google_places_service, place_image_assets

logger = logging.getLogger(__name__)

SOURCE = "google_places"


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _expiry() -> datetime:
    return _now() + timedelta(days=max(1, get_settings().place_cache_days))


def _iso(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat()


def _parse_datetime(value: Any) -> Optional[datetime]:
    if not value:
        return None
    try:
        text = str(value).replace("Z", "+00:00")
        parsed = datetime.fromisoformat(text)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed
    except ValueError:
        return None


def _safe_text(value: Any) -> Optional[str]:
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


def _normalise_key(value: Any) -> str:
    text = _safe_text(value) or ""
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()


def _name_score(left: Any, right: Any) -> float:
    left_key = _normalise_key(left)
    right_key = _normalise_key(right)
    if not left_key or not right_key:
        return 0.0
    if left_key == right_key:
        return 1.0
    if left_key in right_key or right_key in left_key:
        return 0.82
    return SequenceMatcher(None, left_key, right_key).ratio()


def _distance_km(lat1: Optional[float], lng1: Optional[float], lat2: Optional[float], lng2: Optional[float]) -> Optional[float]:
    if None in (lat1, lng1, lat2, lng2):
        return None
    radius_km = 6371.0
    phi1 = math.radians(float(lat1))
    phi2 = math.radians(float(lat2))
    delta_phi = math.radians(float(lat2) - float(lat1))
    delta_lambda = math.radians(float(lng2) - float(lng1))
    a = (
        math.sin(delta_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    )
    return radius_km * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _match_confidence(source: Dict[str, Any], result: Any) -> float:
    geometry = getattr(result, "geometry", None)
    result_lat = getattr(geometry, "lat", None) if geometry else None
    result_lng = getattr(geometry, "lng", None) if geometry else None
    name_score = _name_score(source.get("name"), getattr(result, "name", None))
    distance = _distance_km(
        _safe_float(source.get("latitude")),
        _safe_float(source.get("longitude")),
        _safe_float(result_lat),
        _safe_float(result_lng),
    )
    if distance is None:
        distance_score = 0.65
    elif distance <= 1:
        distance_score = 1.0
    elif distance <= 5:
        distance_score = 0.85
    elif distance <= 20:
        distance_score = 0.55
    else:
        distance_score = 0.2
    return round((name_score * 0.7) + (distance_score * 0.3), 3)


def _is_fresh(row: Dict[str, Any]) -> bool:
    expires_at = _parse_datetime(row.get("expires_at"))
    return expires_at is not None and expires_at > _now()


def _cache_status(row: Dict[str, Any]) -> str:
    return "fresh" if _is_fresh(row) else "expired"


def _get_client():
    return get_supabase_admin_client()


def get_enrichments_for_city(city: str) -> List[Dict[str, Any]]:
    """Return cached enrichment rows for a city. Never calls Google."""
    city_text = _safe_text(city)
    if not city_text:
        return []
    try:
        response = (
            _get_client()
            .table("place_enrichments")
            .select("*")
            .eq("source", SOURCE)
            .ilike("city", city_text)
            .execute()
        )
        return response.data or []
    except Exception as exc:
        logger.warning("Could not read place_enrichments for %s: %s", city_text, exc)
        return []


def get_enrichments_for_cities(cities: Iterable[str]) -> Dict[str, List[Dict[str, Any]]]:
    """Return cached enrichment rows grouped by normalised city name."""
    city_names = sorted({
        city_text
        for city in cities
        if (city_text := _safe_text(city))
    })
    if not city_names:
        return {}

    try:
        response = (
            _get_client()
            .table("place_enrichments")
            .select("*")
            .eq("source", SOURCE)
            .in_("city", city_names)
            .execute()
        )
        rows = response.data or []
    except Exception as exc:
        logger.warning("Could not batch read place_enrichments for cities: %s", exc)
        rows = [
            row
            for city_name in city_names
            for row in get_enrichments_for_city(city_name)
        ]

    grouped: Dict[str, List[Dict[str, Any]]] = {}
    for row in rows:
        key = _normalise_key(row.get("city"))
        if key:
            grouped.setdefault(key, []).append(row)
    return grouped


def get_cached_place_by_id(place_id: str) -> Optional[Dict[str, Any]]:
    """Return one cached place by Google place ID or dataset POI ID."""
    key = _safe_text(place_id)
    if not key:
        return None
    try:
        response = (
            _get_client()
            .table("place_enrichments")
            .select("*")
            .eq("source", SOURCE)
            .eq("source_place_id", key)
            .limit(1)
            .execute()
        )
        if response.data:
            return response.data[0]

        response = (
            _get_client()
            .table("place_enrichments")
            .select("*")
            .eq("dataset_poi_id", key)
            .limit(1)
            .execute()
        )
        return response.data[0] if response.data else None
    except Exception as exc:
        logger.warning("Could not read cached place %s: %s", key, exc)
        return None


def _index_rows(rows: Iterable[Dict[str, Any]]) -> tuple[Dict[str, Dict[str, Any]], Dict[str, Dict[str, Any]], Dict[str, Dict[str, Any]]]:
    by_source_id: Dict[str, Dict[str, Any]] = {}
    by_dataset_id: Dict[str, Dict[str, Any]] = {}
    by_name_city: Dict[str, Dict[str, Any]] = {}
    for row in rows:
        source_id = _safe_text(row.get("source_place_id"))
        dataset_id = _safe_text(row.get("dataset_poi_id"))
        if source_id:
            by_source_id[source_id] = row
        if dataset_id:
            by_dataset_id[dataset_id] = row
        key = f"{_normalise_key(row.get('name'))}|{_normalise_key(row.get('city'))}"
        if key != "|":
            by_name_city[key] = row
    return by_source_id, by_dataset_id, by_name_city


def _first_image_url(images: Any) -> Optional[str]:
    if isinstance(images, list):
        for image in images:
            if isinstance(image, dict) and _safe_text(image.get("url")):
                return str(image["url"])
    return None


def merge_place_with_enrichment(place: Dict[str, Any], enrichment: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    """Overlay cached Google data onto a city/POI dictionary."""
    if not enrichment:
        place.setdefault("images", [])
        place.setdefault("cache_status", "missing")
        return place_image_assets.apply_bundled_images(place)

    images = enrichment.get("images") or []
    image_url = _safe_text(enrichment.get("image_url")) or _first_image_url(images) or _safe_text(place.get("image_url"))
    merged = {
        **place,
        "external_place_id": enrichment.get("source_place_id") or place.get("external_place_id"),
        "place_id": enrichment.get("source_place_id") or place.get("place_id"),
        "formatted_address": enrichment.get("address") or place.get("formatted_address"),
        "address": enrichment.get("address") or place.get("address"),
        "latitude": _safe_float(enrichment.get("latitude")) or place.get("latitude"),
        "longitude": _safe_float(enrichment.get("longitude")) or place.get("longitude"),
        "rating": _safe_float(enrichment.get("rating")) or place.get("rating"),
        "user_ratings_total": enrichment.get("user_ratings_total") or place.get("user_ratings_total"),
        "review_count": enrichment.get("user_ratings_total") or place.get("review_count"),
        "price_level": enrichment.get("price_level") or place.get("price_level"),
        "types": enrichment.get("types") or place.get("types") or place.get("tags") or [],
        "description": enrichment.get("description") or place.get("description"),
        "google_maps_url": enrichment.get("google_maps_url"),
        "url": enrichment.get("google_maps_url") or place.get("url"),
        "website": enrichment.get("website"),
        "phone": enrichment.get("phone"),
        "opening_hours": enrichment.get("opening_hours") or place.get("opening_hours"),
        "image_url": image_url,
        "images": images,
        "photo_attributions": enrichment.get("photo_attributions") or [],
        "place_attributions": enrichment.get("place_attributions") or [],
        "cache_status": _cache_status(enrichment),
        "cache_expires_at": enrichment.get("expires_at"),
        "match_confidence": enrichment.get("match_confidence"),
    }
    if "geometry" not in merged and merged.get("latitude") is not None and merged.get("longitude") is not None:
        merged["geometry"] = {"lat": merged["latitude"], "lng": merged["longitude"]}
    return place_image_assets.apply_bundled_images(merged)


def merge_pois_with_cached_enrichments(pois: List[Dict[str, Any]], city: str) -> List[Dict[str, Any]]:
    rows = get_enrichments_for_city(city)
    return merge_pois_with_enrichment_rows(pois, city, rows)


def merge_pois_with_enrichment_rows(pois: List[Dict[str, Any]], city: str, rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    by_source_id, by_dataset_id, by_name_city = _index_rows(rows)
    city_key = _normalise_key(city)
    merged: List[Dict[str, Any]] = []
    for poi in pois:
        source_id = _safe_text(poi.get("place_id")) or _safe_text(poi.get("external_place_id"))
        dataset_id = _safe_text(poi.get("id")) or _safe_text(poi.get("poi_id"))
        name_key = f"{_normalise_key(poi.get('name'))}|{city_key}"
        enrichment = (
            (by_source_id.get(source_id) if source_id else None)
            or (by_dataset_id.get(dataset_id) if dataset_id else None)
            or by_name_city.get(name_key)
        )
        merged.append(merge_place_with_enrichment(poi, enrichment))
    return merged


def merge_cities_with_cached_enrichments(cities: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    rows_by_city = get_enrichments_for_cities(
        city.get("name")
        for city in cities
    )
    merged: List[Dict[str, Any]] = []
    for city in cities:
        city_name = _safe_text(city.get("name"))
        rows = rows_by_city.get(_normalise_key(city_name), [])
        city_key = _normalise_key(city_name)
        enrichment = next((row for row in rows if _normalise_key(row.get("name")) == city_key), None)
        merged.append(merge_place_with_enrichment(city, enrichment))
    return merged


def merge_places_by_city_with_cached_enrichments(places_by_city: Dict[str, List[Dict[str, Any]]]) -> Dict[str, List[Dict[str, Any]]]:
    rows_by_city = get_enrichments_for_cities(places_by_city.keys())
    return {
        city: merge_pois_with_enrichment_rows(
            pois,
            city,
            rows_by_city.get(_normalise_key(city), []),
        )
        for city, pois in places_by_city.items()
    }


def cached_row_to_place_details(row: Dict[str, Any]) -> PlaceDetailsResponse:
    geometry = None
    lat = _safe_float(row.get("latitude"))
    lng = _safe_float(row.get("longitude"))
    if lat is not None and lng is not None:
        from ..schemas.places import PlaceGeometry

        geometry = PlaceGeometry(lat=lat, lng=lng)

    result = PlaceDetailsResult(
        place_id=row.get("source_place_id") or row.get("dataset_poi_id") or str(row.get("id")),
        name=row.get("name") or "",
        formatted_address=row.get("address"),
        formatted_phone_number=row.get("phone"),
        international_phone_number=row.get("phone"),
        website=row.get("website"),
        geometry=geometry,
        rating=_safe_float(row.get("rating")),
        user_ratings_total=row.get("user_ratings_total"),
        price_level=row.get("price_level"),
        types=row.get("types") or [],
        opening_hours=row.get("opening_hours"),
        photos=[],
        images=row.get("images") or [],
        image_url=row.get("image_url") or _first_image_url(row.get("images")),
        url=row.get("google_maps_url"),
        editorial_summary=row.get("description"),
    )
    return PlaceDetailsResponse(result=result, status="OK")


def _photo_attributions(photos: Iterable[PlacePhoto]) -> List[Any]:
    attributions: List[Any] = []
    seen: set[str] = set()
    for photo in photos:
        for attribution in photo.html_attributions or []:
            text = str(attribution)
            if text not in seen:
                seen.add(text)
                attributions.append(text)
    return attributions


def _storage_path(place_id: str, photo_reference: str, index: int) -> str:
    digest = hashlib.sha256(photo_reference.encode("utf-8")).hexdigest()[:18]
    return f"google-places/{place_id}/{index:02d}-{digest}.jpg"


def _upload_photo_to_storage(photo_url: str, storage_path: str) -> Optional[str]:
    settings = get_settings()
    if not settings.place_cache_upload_images:
        return None

    try:
        with httpx.Client(timeout=20.0, follow_redirects=True) as client:
            response = client.get(photo_url)
            response.raise_for_status()
            content = response.content
            content_type = response.headers.get("content-type", "image/jpeg")

        supabase = _get_client()
        bucket = settings.place_cache_storage_bucket
        try:
            supabase.storage.create_bucket(bucket, options={"public": True})
        except Exception:
            # Bucket likely already exists or storage permissions are managed elsewhere.
            pass

        file_options = {"content-type": content_type, "upsert": "true"}
        supabase.storage.from_(bucket).upload(storage_path, content, file_options=file_options)
        return supabase.storage.from_(bucket).get_public_url(storage_path)
    except Exception as exc:
        logger.info("Falling back to expiring Google photo URL for %s: %s", storage_path, exc)
        return None


def _build_cached_images(details: PlaceDetailsResult, expires_at: datetime) -> List[Dict[str, Any]]:
    max_photos = max(1, get_settings().place_cache_max_photos)
    images: List[Dict[str, Any]] = []
    seen: set[str] = set()
    for index, photo in enumerate(details.photos[:max_photos]):
        if not photo.photo_reference or photo.photo_reference in seen:
            continue
        seen.add(photo.photo_reference)
        photo_url = photo.image_url or google_places_service.get_photo_url(photo.photo_reference, max_width=1200)
        storage_path = _storage_path(details.place_id, photo.photo_reference, index)
        public_url = _upload_photo_to_storage(photo_url, storage_path)
        images.append(
            {
                "url": public_url or photo_url,
                "width": photo.width,
                "height": photo.height,
                "source": SOURCE,
                "attributions": photo.html_attributions or [],
                "expires_at": _iso(expires_at),
                "sort_order": index,
                "storage_path": storage_path if public_url else None,
                "photo_reference": photo.photo_reference,
            }
        )
    return images


def _details_to_row(
    details_response: PlaceDetailsResponse,
    source_poi: Dict[str, Any],
    city: str,
    confidence: float,
) -> Dict[str, Any]:
    details = details_response.result
    expires_at = _expiry()
    images = _build_cached_images(details, expires_at)
    geometry = details.geometry
    source_lat = _safe_float(source_poi.get("latitude"))
    source_lng = _safe_float(source_poi.get("longitude"))
    types = details.types or source_poi.get("tags") or []
    return {
        "source": SOURCE,
        "source_place_id": details.place_id,
        "dataset_poi_id": _safe_text(source_poi.get("id") or source_poi.get("poi_id")),
        "name": details.name or source_poi.get("name") or "Unknown",
        "city": city,
        "address": details.formatted_address or source_poi.get("address") or source_poi.get("location"),
        "latitude": _safe_float(getattr(geometry, "lat", None)) or source_lat,
        "longitude": _safe_float(getattr(geometry, "lng", None)) or source_lng,
        "rating": _safe_float(details.rating),
        "user_ratings_total": details.user_ratings_total,
        "price_level": details.price_level,
        "types": types,
        "description": details.editorial_summary or source_poi.get("description"),
        "google_maps_url": details.url,
        "website": details.website,
        "phone": details.formatted_phone_number or details.international_phone_number,
        "opening_hours": details.opening_hours,
        "image_url": images[0]["url"] if images else details.image_url,
        "images": images,
        "photo_attributions": _photo_attributions(details.photos),
        "place_attributions": [],
        "match_confidence": confidence,
        "fetched_at": _iso(_now()),
        "expires_at": _iso(expires_at),
        "last_error": None,
        "updated_at": _iso(_now()),
    }


def _search_best_google_match(poi: Dict[str, Any], city: str, language: str = "en") -> tuple[Optional[str], float]:
    name = _safe_text(poi.get("name"))
    if not name:
        return None, 0.0
    lat = _safe_float(poi.get("latitude"))
    lng = _safe_float(poi.get("longitude"))
    try:
        if lat is not None and lng is not None:
            response = google_places_service.nearby_search_places(
                lat=lat,
                lng=lng,
                radius=3000,
                keyword=name,
                language=language,
            )
        else:
            response = google_places_service.text_search_places(
                query=f"{name} {city} Saudi Arabia",
                language=language,
            )
    except HTTPException:
        raise
    except Exception as exc:
        logger.warning("Google match search failed for %s: %s", name, exc)
        return None, 0.0

    best_place_id: Optional[str] = None
    best_confidence = 0.0
    for result in response.results:
        confidence = _match_confidence(poi, result)
        if confidence > best_confidence:
            best_confidence = confidence
            best_place_id = result.place_id
    return best_place_id, best_confidence


def _upsert_row(row: Dict[str, Any]) -> Dict[str, Any]:
    response = (
        _get_client()
        .table("place_enrichments")
        .upsert(row, on_conflict="source,source_place_id")
        .execute()
    )
    return response.data[0] if response.data else row


def _existing_cache_for_poi(poi: Dict[str, Any], city: str) -> Optional[Dict[str, Any]]:
    dataset_id = _safe_text(poi.get("id") or poi.get("poi_id"))
    if dataset_id:
        try:
            response = (
                _get_client()
                .table("place_enrichments")
                .select("*")
                .eq("dataset_poi_id", dataset_id)
                .limit(1)
                .execute()
            )
            if response.data:
                return response.data[0]
        except Exception:
            return None

    rows = get_enrichments_for_city(city)
    name_key = _normalise_key(poi.get("name"))
    return next((row for row in rows if _normalise_key(row.get("name")) == name_key), None)


def refresh_poi_cache(
    poi: Dict[str, Any],
    city: str,
    *,
    dry_run: bool = False,
    refresh_expired_only: bool = True,
    min_confidence: float = 0.45,
    language: str = "en",
) -> Dict[str, Any]:
    """Refresh one POI cache row from Google. Intended for admin jobs only."""
    existing = _existing_cache_for_poi(poi, city)
    if refresh_expired_only and existing and _is_fresh(existing):
        return {"status": "skipped_fresh", "place": existing.get("name"), "source_place_id": existing.get("source_place_id")}

    place_id, confidence = _search_best_google_match(poi, city, language=language)
    if not place_id or confidence < min_confidence:
        return {"status": "skipped_low_confidence", "place": poi.get("name"), "confidence": confidence}

    details = google_places_service.get_place_details(place_id=place_id, language=language)
    row = _details_to_row(details, poi, city, confidence)
    if dry_run:
        return {"status": "dry_run", "place": row["name"], "source_place_id": row["source_place_id"], "images": len(row["images"]), "confidence": confidence}

    saved = _upsert_row(row)
    return {"status": "updated", "place": saved.get("name"), "source_place_id": saved.get("source_place_id"), "images": len(saved.get("images") or []), "confidence": confidence}


def refresh_destination_cache(
    destination: str,
    *,
    limit: int = 50,
    dry_run: bool = False,
    refresh_expired_only: bool = True,
    language: str = "en",
) -> Dict[str, Any]:
    """Refresh cached Google enrichment rows for one destination/city."""
    pois = ai_poi_service.get_pois_for_destination(
        destination,
        limit=limit,
        enrich_photos=False,
        require_coordinates=False,
    )
    results: List[Dict[str, Any]] = []
    for poi in pois:
        try:
            results.append(
                refresh_poi_cache(
                    poi,
                    destination,
                    dry_run=dry_run,
                    refresh_expired_only=refresh_expired_only,
                    language=language,
                )
            )
        except Exception as exc:
            logger.warning("Failed to refresh %s in %s: %s", poi.get("name"), destination, exc)
            results.append({"status": "error", "place": poi.get("name"), "error": str(exc)})

    counts: Dict[str, int] = {}
    for item in results:
        counts[item["status"]] = counts.get(item["status"], 0) + 1
    return {"destination": destination, "total": len(results), "counts": counts, "results": results}


def require_cached_place_details(place_id: str) -> PlaceDetailsResponse:
    row = get_cached_place_by_id(place_id)
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cached place details not found. Run the Google Places enrichment job first.",
        )
    return cached_row_to_place_details(row)
