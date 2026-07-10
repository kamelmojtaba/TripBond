#!/usr/bin/env python3
"""Download bundled place images from Wikimedia Commons (CC-licensed)."""

from __future__ import annotations

import shutil
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLACES_DIR = ROOT / "frontend" / "assets" / "images" / "places"
CITIES_DIR = ROOT / "frontend" / "assets" / "images" / "cities"

# Unique source URL -> list of relative destination paths under places/ or cities/
IMAGE_SOURCES: dict[str, list[str]] = {
    "https://upload.wikimedia.org/wikipedia/commons/5/53/Dammam%2C_KSA_%286358927965%29.jpg": [
        "cities/Dammam.jpg",
    ],
    "https://upload.wikimedia.org/wikipedia/commons/b/bb/In_Saudi_Arabia.JPG": [
        "dammam_corniche.jpg",
        "marina_mall_dammam.jpg",
        "dammam_regional_museum.jpg",
        "dolphin_village.jpg",
        "king_fahd_park_dammam.jpg",
        "dammam_beach.jpg",
        "marjan_island.jpg",
        "heritage_village_dammam.jpg",
        "lake_park.jpg",
    ],
    "https://upload.wikimedia.org/wikipedia/commons/1/1f/Al_Khobar_Corniche.JPG": [
        "scitech.jpg",
        "khobar_corniche.jpg",
        "corniche_island.jpg",
        "al_rashid_mall.jpg",
        "heritage_village_khobar.jpg",
        "khobar_water_tower.jpg",
        "khobar_fish_market.jpg",
        "khobar_park.jpg",
    ],
    "https://upload.wikimedia.org/wikipedia/commons/d/dd/The_Boulevard_Riyadh_181303.jpg": [
        "boulevard_riyadh.jpg",
        "diriyah.jpg",
    ],
    "https://upload.wikimedia.org/wikipedia/commons/8/81/Masmak_Fort_(12753717253).jpg": [
        "masmak_palace.jpg",
        "murabba_palace.jpg",
        "riyadh_heritage.jpg",
    ],
    "https://upload.wikimedia.org/wikipedia/commons/9/9b/Riyadh-Skyline.jpg": [
        "edge_of_the_world.jpg",
        "national_museum_riyadh.jpg",
        "wadi_namar.jpg",
        "heet_cave.jpg",
        "riyadh_desert.jpg",
        "riyadh_leisure.jpg",
    ],
    "https://upload.wikimedia.org/wikipedia/commons/7/7f/The_Digital_City%2C_Riyadh_191028.jpg": [
        "kafd.jpg",
    ],
    "https://upload.wikimedia.org/wikipedia/commons/8/88/Kingdom_Tower_at_night.JPG": [
        "kingdom_centre.jpg",
    ],
    "https://upload.wikimedia.org/wikipedia/commons/e/e1/Jeddah_waterfront_sunset.jpg": [
        "jeddah_corniche.jpg",
        "historic_jeddah.jpg",
        "red_sea_mall.jpg",
        "mall_of_arabia.jpg",
        "floating_mosque.jpg",
        "jeddah_beach.jpg",
        "tayebat_museum.jpg",
        "fakieh_aquarium.jpg",
        "jeddah_sports.jpg",
        "jeddah_arts.jpg",
    ],
    "https://upload.wikimedia.org/wikipedia/commons/0/00/King_Fahd%27s_Fountain_Jeddah_Fountain_%285129797428%29.jpg": [
        "king_fahd_fountain.jpg",
    ],
}


def _dest_path(rel_path: str) -> Path:
    if rel_path.startswith("cities/"):
        return CITIES_DIR / rel_path.split("/", 1)[1]
    return PLACES_DIR / rel_path


def fetch_url(url: str, retries: int = 5) -> bytes:
    last_error: Exception | None = None
    for attempt in range(retries):
        try:
            request = urllib.request.Request(
                url,
                headers={"User-Agent": "TripBond/1.0 (place-image-downloader; contact@tripbond.app)"},
            )
            with urllib.request.urlopen(request, timeout=90) as response:
                content = response.read()
            if len(content) < 5000:
                raise ValueError(f"response too small ({len(content)} bytes)")
            return content
        except Exception as exc:
            last_error = exc
            wait = min(30, 2 ** attempt)
            print(f"retry {attempt + 1}/{retries} in {wait}s: {url} ({exc})")
            time.sleep(wait)
    raise RuntimeError(f"failed to download {url}: {last_error}")


def main() -> int:
    PLACES_DIR.mkdir(parents=True, exist_ok=True)
    CITIES_DIR.mkdir(parents=True, exist_ok=True)

    ok = 0
    fail = 0

    for index, (url, rel_paths) in enumerate(IMAGE_SOURCES.items()):
        if index > 0:
            time.sleep(3)
        try:
            content = fetch_url(url)
            cache_file = PLACES_DIR / f"_cache_{abs(hash(url))}.bin"
            cache_file.write_bytes(content)
            for rel_path in rel_paths:
                dest = _dest_path(rel_path)
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(cache_file, dest)
                print(f"ok: {dest.name} ({len(content) // 1024} KB)")
                ok += 1
        except Exception as exc:
            print(f"fail source: {url} -> {exc}")
            fail += len(rel_paths)

    dammam_jpg = CITIES_DIR / "Dammam.jpg"
    dammam_png = CITIES_DIR / "Dammam.png"
    if dammam_jpg.exists():
        shutil.copyfile(dammam_jpg, dammam_png)
        print("ok: Dammam.png")

    print(f"\nDone: {ok} files written, {fail} failed")
    return 1 if fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
