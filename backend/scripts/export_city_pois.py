#!/usr/bin/env python3
"""Export POI names for a city from the integrated dataset."""

from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
CSV = ROOT / "tripbond_ai_backend" / "data" / "final_integrated_poi_dataset.csv"


def main() -> int:
    cities = sys.argv[1:] or ["Dammam", "Al Khobar", "Riyadh", "Jeddah"]
    df = pd.read_csv(CSV)
    for city in cities:
        sub = df[df["city"] == city]
        print(f"=== {city} ({len(sub)}) ===")
        for _, row in sub.iterrows():
            print(row["name"])
        print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
