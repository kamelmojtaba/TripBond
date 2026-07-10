#!/usr/bin/env python
"""Test POI service Google Places enrichment directly"""

import sys
sys.path.insert(0, '.')

from app.services.ai_poi_service import get_pois_for_destination
import json

print('Fetching POIs for Al Khobar with Google Places enrichment...')
pois = get_pois_for_destination('Al Khobar', limit=5)

print(f"\nFound {len(pois)} POIs\n")

for poi in pois:
    print(f"Place: {poi.get('name')}")
    image_url = poi.get('image_url', None)
    if image_url:
        print(f"  Image URL: {image_url[:90]}...")
    else:
        print(f"  Image URL: None (place found but no photos available)")  
    print(f"  Rating: {poi.get('rating', 'N/A')}")
    print(f"  Location: {poi.get('location', 'N/A')}")
    print()

