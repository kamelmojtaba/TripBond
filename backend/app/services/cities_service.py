"""
Curated list of trip destinations.

Pulls cities out of the integrated POI CSV (the same one the AI POI service
uses), filters out the obvious junk (single-token fragments, very short names,
stop words), enriches them with sane defaults (province, lat/lng, image asset
hint), and caches the result in process memory.
"""
from __future__ import annotations

import logging
import math
from pathlib import Path
from typing import List, Dict, Any, Optional

import pandas as pd

logger = logging.getLogger(__name__)

# Same dataset as ai_poi_service uses
_AI_BACKEND_ROOT = Path(__file__).parent.parent.parent.parent / "tripbond_ai_backend"
_CSV_PATH = _AI_BACKEND_ROOT / "data" / "final_integrated_poi_dataset.csv"

# Things that look like cities in the CSV but are obviously dataset noise
# (truncated tokens, English stop words that survived the scrape, etc.)
_DENYLIST = {
    "Al", "Ad", "Ras", "King", "Saudi", "SH", "1c", "Closed", "Temporarily",
    "Tuwarin", "Sa'ad", "Khubayb", "Qesm", "Hafar",
    # Non-KSA / outside scope
    "Abu Dhabi", "Hurghada", "Manama", "Muharraq", "Zallaq",
    # Scrape noise / sub-locality fragments
    "Buqayq", "Dhurma", "Huraymila", "Rughabah", "Uthmaniyah", "Ushaiqer",
    "Al-Muzahmiya", "Kaec", "Rijal Almaa",
}

# Manual coordinate / metadata overrides for cities that have valid POIs but
# missing or zero coordinates in the CSV. Coordinates are city centres.
_OVERRIDES: Dict[str, Dict[str, Any]] = {
    "Riyadh":      {"province": "Riyadh",            "lat": 24.7136, "lng": 46.6753, "country": "Saudi Arabia"},
    "Jeddah":      {"province": "Makkah",            "lat": 21.4858, "lng": 39.1925, "country": "Saudi Arabia"},
    "Diriyah":     {"province": "Riyadh",            "lat": 24.7375, "lng": 46.5740, "country": "Saudi Arabia"},
    "Madinah":     {"province": "Madinah",           "lat": 24.4686, "lng": 39.6142, "country": "Saudi Arabia"},
    "Aseer":       {"province": "Asir",              "lat": 18.2164, "lng": 42.5053, "country": "Saudi Arabia"},
    "Hail":        {"province": "Hail",              "lat": 27.5219, "lng": 41.6907, "country": "Saudi Arabia"},
    "Makkah":      {"province": "Makkah",            "lat": 21.3891, "lng": 39.8579, "country": "Saudi Arabia"},
    "AlUla":       {"province": "Madinah",           "lat": 26.6080, "lng": 37.9220, "country": "Saudi Arabia"},
    "Dammam":      {"province": "Eastern Province",  "lat": 26.4207, "lng": 50.0888, "country": "Saudi Arabia"},
    "Qassim":      {"province": "Qassim",            "lat": 26.3260, "lng": 43.9750, "country": "Saudi Arabia"},
    "Tabuk":       {"province": "Tabuk",             "lat": 28.3838, "lng": 36.5660, "country": "Saudi Arabia"},
    "Al-Ahsa":     {"province": "Eastern Province",  "lat": 25.3833, "lng": 49.5833, "country": "Saudi Arabia"},
    "Taif":        {"province": "Makkah",            "lat": 21.2703, "lng": 40.4158, "country": "Saudi Arabia"},
    "Dhahran":     {"province": "Eastern Province",  "lat": 26.2879, "lng": 50.1140, "country": "Saudi Arabia"},
    "Yanbu":       {"province": "Madinah",           "lat": 24.0890, "lng": 38.0617, "country": "Saudi Arabia"},
    "Al Baha":     {"province": "Al Baha",           "lat": 20.0129, "lng": 41.4677, "country": "Saudi Arabia"},
    "Abha":        {"province": "Asir",              "lat": 18.2164, "lng": 42.5053, "country": "Saudi Arabia"},
    "Najran":      {"province": "Najran",            "lat": 17.4924, "lng": 44.1277, "country": "Saudi Arabia"},
    "Jazan":       {"province": "Jazan",             "lat": 16.8892, "lng": 42.5510, "country": "Saudi Arabia"},
    "Al Jubail":   {"province": "Eastern Province",  "lat": 27.0046, "lng": 49.6588, "country": "Saudi Arabia"},
    "Al Khobar":   {"province": "Eastern Province",  "lat": 26.2172, "lng": 50.1971, "country": "Saudi Arabia"},
    # Common alternate spellings get normalised to one of the above:
    "Khobar":      {"alias_of": "Al Khobar"},
    "Buraidah":    {"alias_of": "Buraydah"},
    "Buraydah":    {"province": "Qassim",            "lat": 26.3260, "lng": 43.9750, "country": "Saudi Arabia"},
    "King Abdullah Economic City": {
        "province": "Makkah", "lat": 22.4000, "lng": 39.0800, "country": "Saudi Arabia",
    },
    "Unayzah":     {"province": "Qassim",            "lat": 26.0900, "lng": 43.9700, "country": "Saudi Arabia"},
    "Umluj":       {"province": "Tabuk",             "lat": 25.0201, "lng": 37.2669, "country": "Saudi Arabia"},
    "Shaqra":      {"province": "Riyadh",            "lat": 25.2400, "lng": 45.2500, "country": "Saudi Arabia"},
    "Safwa":       {"province": "Eastern Province",  "lat": 26.6500, "lng": 49.9500, "country": "Saudi Arabia"},
    "Al-Kharj":    {"province": "Riyadh",            "lat": 24.1550, "lng": 47.3050, "country": "Saudi Arabia"},
    "Arar":        {"province": "Northern Borders",  "lat": 30.9750, "lng": 41.0380, "country": "Saudi Arabia"},
}

# Image asset hints. Keys are normalised city names; values are asset paths
# that already ship with the Flutter app under assets/images/cities/. The
# frontend can fall back to a Google Places photo URL if the asset is missing.
_ASSET_MAP: Dict[str, str] = {
    "Buraidah":   "assets/images/cities/Buraidah.png",
    "Buraydah":   "assets/images/cities/Buraidah.png",
    "Khobar":     "assets/images/cities/Khobar.png",
    "Al Khobar":  "assets/images/cities/Khobar.png",
    "Jeddah":     "assets/images/cities/jeddah.png",
    "Riyadh":     "assets/images/cities/Riyadh.png",
    "Dammam":     "assets/images/cities/Dammam.png",
    "AlUla":      "assets/images/cities/AlUla.png",
}

_cache: Optional[List[Dict[str, Any]]] = None


def invalidate_cache() -> None:
    """Clear in-memory city list (call after updating the POI CSV)."""
    global _cache
    _cache = None


def _load() -> Optional[pd.DataFrame]:
    if not _CSV_PATH.exists():
        logger.warning("Cities CSV missing at %s", _CSV_PATH)
        return None
    try:
        return pd.read_csv(_CSV_PATH)
    except Exception as exc:
        logger.exception("Failed to read cities CSV: %s", exc)
        return None


def _safe(value: Any) -> Optional[str]:
    if value is None:
        return None
    if isinstance(value, float) and math.isnan(value):
        return None
    text = str(value).strip()
    return text or None


# Only Saudi provinces / regions — blocks stray international rows in the CSV.
_KSA_PROVINCES = {
    "Riyadh", "Makkah", "Medina", "Madinah", "Eastern Province", "Asir", "Aseer",
    "Tabuk", "Hail", "Qassim", "Najran", "Jazan", "Jizan", "Al Baha", "Northern Borders",
    "",  # filled via overrides
}


def list_cities(min_count: int = 10) -> List[Dict[str, Any]]:
    """Return curated cities sorted by POI count (descending).

    Each entry contains: name, count, province, lat, lng, country,
    image_asset (may be None), is_featured.
    """
    global _cache
    if _cache is not None:
        return _cache

    df = _load()
    if df is None:
        _cache = []
        return _cache

    grouped = (
        df.groupby("city")
          .agg(
              count=("poi_id", "count"),
              province=("province", lambda s: _safe(next((p for p in s if _safe(p)), None))),
              lat_avg=("latitude", "mean"),
              lng_avg=("longitude", "mean"),
          )
          .reset_index()
    )

    result: List[Dict[str, Any]] = []
    for _, row in grouped.iterrows():
        raw_name = _safe(row["city"])
        if not raw_name:
            continue
        if len(raw_name) < 3:
            continue
        if raw_name in _DENYLIST:
            continue
        if not any(c.isalpha() for c in raw_name):
            continue
        if int(row["count"]) < min_count:
            continue

        # Resolve aliases (Khobar -> Al Khobar, Buraidah -> Buraydah)
        override = _OVERRIDES.get(raw_name, {})
        if "alias_of" in override:
            raw_name = override["alias_of"]
            override = _OVERRIDES.get(raw_name, {})

        lat = override.get("lat")
        lng = override.get("lng")
        if lat is None and not (isinstance(row["lat_avg"], float) and math.isnan(row["lat_avg"])):
            lat = float(row["lat_avg"])
        if lng is None and not (isinstance(row["lng_avg"], float) and math.isnan(row["lng_avg"])):
            lng = float(row["lng_avg"])

        # Skip cities with neither override nor valid coords AND below count
        # threshold - they are most likely dataset noise.
        if (lat is None or lng is None) and int(row["count"]) < min_count:
            continue
        if (lat is None or lng is None) and raw_name not in _OVERRIDES:
            continue

        province = _safe(override.get("province") or row.get("province")) or ""
        if province and province not in _KSA_PROVINCES and province != "International":
            # Allow unknown province only when we have an explicit KSA override.
            if raw_name not in _OVERRIDES:
                continue
        country = override.get("country", "Saudi Arabia")
        if str(country).strip().lower() not in {"", "saudi arabia", "ksa", "kingdom of saudi arabia"}:
            continue
        image_asset = _ASSET_MAP.get(raw_name)

        result.append({
            "name": raw_name,
            "count": int(row["count"]),
            "province": province,
            "country": country,
            "lat": lat,
            "lng": lng,
            "image_asset": image_asset,
            "is_featured": raw_name in {"Riyadh", "Jeddah", "AlUla", "Al Khobar"},
        })

    # Merge entries that resolved to the same alias
    merged: Dict[str, Dict[str, Any]] = {}
    for entry in result:
        key = entry["name"]
        if key in merged:
            merged[key]["count"] += entry["count"]
        else:
            merged[key] = entry

    final = sorted(merged.values(), key=lambda c: c["count"], reverse=True)
    _cache = final
    logger.info("Cached %d curated cities", len(final))
    return final
