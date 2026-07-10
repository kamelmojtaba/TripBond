#!/usr/bin/env python3
"""Report bundled-image coverage for priority-city POIs."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
MODULE = ROOT / "backend" / "app" / "services" / "place_image_assets.py"
spec = importlib.util.spec_from_file_location("place_image_assets", MODULE)
place_image_assets = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(place_image_assets)

CSV = ROOT / "tripbond_ai_backend" / "data" / "final_integrated_poi_dataset.csv"
CITIES = ["Dammam", "Al Khobar", "Riyadh", "Jeddah"]


def main() -> int:
    df = pd.read_csv(CSV)
    missing = []
    covered = 0
    for city in CITIES:
        sub = df[df["city"] == city]
        city_covered = 0
        for _, row in sub.iterrows():
            asset = place_image_assets.lookup_bundled_asset(row["name"], city)
            if asset:
                covered += 1
                city_covered += 1
            else:
                missing.append((city, row["name"]))
        print(f"{city}: {city_covered}/{len(sub)} covered")

    print(f"\nTotal covered: {covered}/{sum(len(df[df['city']==c]) for c in CITIES)}")
    print(f"Missing bundled asset: {len(missing)}")
    if missing:
        out = ROOT / "backend" / "scripts" / "missing_place_images.txt"
        out.write_text("\n".join(f"[{city}] {name}" for city, name in missing), encoding="utf-8")
        print(f"Missing list written to {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
