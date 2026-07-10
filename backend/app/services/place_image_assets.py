"""
Bundled place images for POIs that lack Google Places photos.

Assets live under frontend/assets/images/places/ and are referenced with
Flutter asset paths (assets/images/places/...).
"""

from __future__ import annotations

import re
from typing import Any, Dict, Iterable, List, Optional, Tuple

BUNDLED_SOURCE = "bundled"
LOGO_ASSET = "assets/images/icons/logo.png"

# Cities that receive bundled landmark/category images before falling back to logo.
PRIORITY_CITIES = frozenset(
    {
        "dammam",
        "al khobar",
        "khobar",
        "riyadh",
        "jeddah",
    }
)

_CITY_DEFAULTS: Dict[str, str] = {
    "dammam": "assets/images/cities/Dammam.png",
    "al khobar": "assets/images/cities/Khobar.png",
    "riyadh": "assets/images/cities/Riyadh.png",
    "jeddah": "assets/images/cities/jeddah.png",
}

# (pattern, asset_path) — first match wins within a city block.
_CITY_RULES: Dict[str, List[Tuple[str, str]]] = {
    "dammam": [
        (r"dammam corniche|share al.?hob|central market", "assets/images/places/dammam_corniche.jpg"),
        (r"marina mall", "assets/images/places/marina_mall_dammam.jpg"),
        (r"regional museum", "assets/images/places/dammam_regional_museum.jpg"),
        (r"dolphin village", "assets/images/places/dolphin_village.jpg"),
        (r"king fahd park", "assets/images/places/king_fahd_park_dammam.jpg"),
        (r"shatea|district beach|public beach", "assets/images/places/dammam_beach.jpg"),
        (r"marjan|coral island", "assets/images/places/marjan_island.jpg"),
        (r"heritage village", "assets/images/places/heritage_village_dammam.jpg"),
        (r"modon lake|lake park", "assets/images/places/lake_park.jpg"),
        (r"ithra|world culture", "assets/images/places/Ithra.png"),
        (r"scitech|science and technology", "assets/images/places/scitech.jpg"),
        (r"cinema|cinepolis|vox|empire|theater|theatre|comedy club|theme park|romaland|rmroma|emerald hall|event venue|concert", "assets/images/places/Cinema.png"),
        (r"hotel|suites|plaza", "assets/images/places/khobar_corniche.jpg"),
    ],
    "al khobar": [
        (r"corniche|sea front|waterfront", "assets/images/places/khobar_corniche.jpg"),
        (r"ajdan walk", "assets/images/cities/khobar2.png"),
        (r"escape the room", "assets/images/places/escapeTheRoom.png"),
        (r"silver sands|beach", "assets/images/places/Beach.png"),
        (r"corniche island|marjan", "assets/images/places/corniche_island.jpg"),
        (r"rashid mall", "assets/images/places/al_rashid_mall.jpg"),
        (r"heritage village", "assets/images/places/heritage_village_khobar.jpg"),
        (r"water tower", "assets/images/places/khobar_water_tower.jpg"),
        (r"fish market", "assets/images/places/khobar_fish_market.jpg"),
        (r"scitech|science", "assets/images/places/scitech.jpg"),
        (r"cinema|amc|empire|vox", "assets/images/places/Cinema.png"),
        (r"hotel|suites|plaza|ihg|crowne", "assets/images/places/khobar_corniche.jpg"),
        (r"desert designs|turki street|danah mall|park", "assets/images/places/khobar_park.jpg"),
    ],
    "riyadh": [
        (r"diriyah", "assets/images/places/diriyah.jpg"),
        (r"boulevard riyadh|boulevard", "assets/images/places/boulevard_riyadh.jpg"),
        (r"edge of the world", "assets/images/places/edge_of_the_world.jpg"),
        (r"national museum", "assets/images/places/national_museum_riyadh.jpg"),
        (r"masmak", "assets/images/places/masmak_palace.jpg"),
        (r"murabba", "assets/images/places/murabba_palace.jpg"),
        (r"wadi namar|wadi namer", "assets/images/places/wadi_namar.jpg"),
        (r"heet cave", "assets/images/places/heet_cave.jpg"),
        (r"kafd|financial district", "assets/images/places/kafd.jpg"),
        (r"kingdom centre|kingdom center|kingdom tower", "assets/images/places/kingdom_centre.jpg"),
        (r"rawdat tinhat|national park|kharrarah", "assets/images/places/riyadh_desert.jpg"),
        (r"library|museum|gallery|palace|heritage|historical", "assets/images/places/riyadh_heritage.jpg"),
        (r"cinema|vox|amc|empire|muvi", "assets/images/places/Cinema.png"),
        (r"escape the room", "assets/images/places/escapeTheRoom.png"),
        (r"city walk", "assets/images/places/CityWalk.png"),
        (r"golf|equestrian|club|stadium|sports", "assets/images/places/riyadh_leisure.jpg"),
        (r"neighborhood|visitor center|gallery|art|museum|palace|heritage|historical|fort|gate|boulevard|park|cave|wadi|desert|edge|library|financial|kingdom|masmak|diriyah|murabba|tinhat|kharrarah|dirab|abstract|naila|ajlan|subaie|munikh|addoho|faisaliah|faisaliyah|fiha|watan|gamers|avtar|cheese|mosque|shuaib|huraymila|aviation|kayan", "assets/images/places/riyadh_heritage.jpg"),
        (r"mall|shopping|market|restaurant|dining|coffee|park", "assets/images/places/boulevard_riyadh.jpg"),
    ],
    "jeddah": [
        (r"king fahd.*fountain|fountain", "assets/images/places/king_fahd_fountain.jpg"),
        (r"jeddah corniche|waterfront|obhur corniche|corniche circuit", "assets/images/places/jeddah_corniche.jpg"),
        (r"historic jeddah|al.?balad|balad", "assets/images/places/historic_jeddah.jpg"),
        (r"red sea mall", "assets/images/places/red_sea_mall.jpg"),
        (r"mall of arabia", "assets/images/places/mall_of_arabia.jpg"),
        (r"floating mosque|rahma mosque", "assets/images/places/floating_mosque.jpg"),
        (r"obhur beach|durat al arous|beach", "assets/images/places/jeddah_beach.jpg"),
        (r"tayebat museum", "assets/images/places/tayebat_museum.jpg"),
        (r"fakieh aquarium|aquarium", "assets/images/places/fakieh_aquarium.jpg"),
        (r"superdome|sports city|jawharah stadium", "assets/images/places/jeddah_sports.jpg"),
        (r"teamlab|hayy jameel|tariq abdulhakim", "assets/images/places/jeddah_arts.jpg"),
        (r"cinema|vox|amc|empire|muvi|cinepolis|theater|theatre|escape|amusement|entertainer|club|dome|stage|snowy|mazebox|xtreme|daz|arab", "assets/images/places/Cinema.png"),
        (r"albaik|restaurant|dining|salt", "assets/images/places/salt.jpg"),
        (r"mall|shopping|market|waterfront|corniche|beach|museum|aquarium|mosque|balad|fountain|sports|superdome|teamlab|hayy|tariq|jawharah|stadium|circuit|obhur|durat", "assets/images/places/jeddah_corniche.jpg"),
    ],
}

# Exact normalised name overrides (city|name -> asset).
_EXACT: Dict[str, str] = {
    "dammam|dammam corniche": "assets/images/places/dammam_corniche.jpg",
    "dammam|share al hob market": "assets/images/places/dammam_corniche.jpg",
    "dammam|marina mall dammam": "assets/images/places/marina_mall_dammam.jpg",
    "dammam|king abdulaziz center for world culture ithra": "assets/images/places/Ithra.png",
    "al khobar|al khobar corniche": "assets/images/places/khobar_corniche.jpg",
    "al khobar|ajdan walk al khobar": "assets/images/cities/khobar2.png",
    "al khobar|escape the room khobar": "assets/images/places/escapeTheRoom.png",
    "jeddah|king fahd fountain": "assets/images/places/king_fahd_fountain.jpg",
    "jeddah|jeddah corniche": "assets/images/places/jeddah_corniche.jpg",
    "jeddah|red sea mall": "assets/images/places/red_sea_mall.jpg",
    "riyadh|boulevard riyadh city": "assets/images/places/boulevard_riyadh.jpg",
    "riyadh|al masmak palace": "assets/images/places/masmak_palace.jpg",
    "riyadh|diriyah gate": "assets/images/places/diriyah.jpg",
}


def _normalise_key(value: Any) -> str:
    text = str(value or "").strip().lower()
    text = text.replace("'", "'").replace("`", "'")
    return re.sub(r"[^a-z0-9]+", " ", text).strip()


def _city_key(city: Any) -> str:
    key = _normalise_key(city)
    if key == "khobar":
        return "al khobar"
    return key


def _has_images(place: Dict[str, Any]) -> bool:
    image_url = str(place.get("image_url") or "").strip()
    if image_url:
        return True
    images = place.get("images")
    if isinstance(images, list):
        for image in images:
            if isinstance(image, dict) and str(image.get("url") or "").strip():
                return True
            if isinstance(image, str) and image.strip():
                return True
    return False


def lookup_bundled_asset(name: Any, city: Any) -> Optional[str]:
    """Return a bundled asset path for a POI, or None."""
    city_norm = _city_key(city)
    if city_norm not in PRIORITY_CITIES:
        return None

    name_norm = _normalise_key(name)
    if not name_norm:
        return _CITY_DEFAULTS.get(city_norm)

    exact_key = f"{city_norm}|{name_norm}"
    if exact_key in _EXACT:
        return _EXACT[exact_key]

    rules = _CITY_RULES.get(city_norm, [])
    for pattern, asset in rules:
        if re.search(pattern, name_norm):
            return asset
    return _CITY_DEFAULTS.get(city_norm)


def bundled_image_entry(asset_path: str) -> Dict[str, Any]:
    return {
        "url": asset_path,
        "source": BUNDLED_SOURCE,
        "attributions": ["TripBond"],
        "sort_order": 0,
    }


def apply_bundled_images(place: Dict[str, Any]) -> Dict[str, Any]:
    """Attach bundled images when Google/cache photos are missing."""
    if _has_images(place):
        return place

    city = place.get("city") or place.get("location") or place.get("destination")
    asset = lookup_bundled_asset(place.get("name"), city)
    if not asset:
        return place

    entry = bundled_image_entry(asset)
    place = {
        **place,
        "image_asset": asset,
        "image_url": asset,
        "images": [entry],
        "cache_status": place.get("cache_status") or "missing",
        "photo_attributions": [],
        "place_attributions": ["TripBond"],
    }
    return place


def apply_bundled_images_to_places(places: Iterable[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return [apply_bundled_images(dict(place)) for place in places]
