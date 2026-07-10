#!/usr/bin/env python3
"""Refresh cached Google Places metadata and photo galleries for TripBond."""

from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.getcwd())

from app.services import cities_service, place_enrichment_service


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Refresh TripBond's cached Google Places enrichment data.")
    parser.add_argument("--city", action="append", help="City/destination to refresh. Can be passed multiple times.")
    parser.add_argument("--limit", type=int, default=50, help="Maximum POIs per city.")
    parser.add_argument("--language", default="en", help="Google Places language code.")
    parser.add_argument("--dry-run", action="store_true", help="Resolve matches without writing to Supabase.")
    parser.add_argument(
        "--refresh-all",
        action="store_true",
        help="Refresh all matching records even when the cache is still fresh.",
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    destinations = args.city
    if not destinations:
        destinations = [city["name"] for city in cities_service.list_cities(min_count=1)]

    summaries = []
    for destination in destinations:
        summary = place_enrichment_service.refresh_destination_cache(
            destination,
            limit=args.limit,
            dry_run=args.dry_run,
            refresh_expired_only=not args.refresh_all,
            language=args.language,
        )
        summaries.append(summary)
        print(json.dumps(summary, ensure_ascii=False, indent=2))

    total_errors = sum(summary["counts"].get("error", 0) for summary in summaries)
    return 1 if total_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
