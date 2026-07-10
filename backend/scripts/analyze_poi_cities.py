#!/usr/bin/env python3
"""Analyze POI counts per city in the integrated dataset."""
import pandas as pd
from pathlib import Path

CSV = Path(__file__).resolve().parents[2] / "tripbond_ai_backend" / "data" / "final_integrated_poi_dataset.csv"
df = pd.read_csv(CSV)
counts = df.groupby("city").size().sort_values()
out = Path(__file__).resolve().parent / "city_counts.txt"
lines = [f"Total rows: {len(df)}", "", "All cities (count):"]
for c, n in counts.items():
    lines.append(f"{n:4d}  {c!r}")
out.write_text("\n".join(lines), encoding="utf-8")
print(f"Wrote {out}")
