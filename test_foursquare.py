#!/usr/bin/env python
"""Test Foursquare enrichment with new fix"""

import requests
import json
import time

user_id = 'test_user_' + str(int(time.time()))
trip_data = {
    'user_id': user_id,
    'destination': 'Al Khobar',  # Use correct city name from CSV
    'start_date': '2026-05-01',
    'end_date': '2026-05-03',
    'num_travelers': 2,
    'travel_pace': 'moderate',
    'interests': ['culture', 'food']
}

print(f"Creating trip for {trip_data['destination']}...")
headers = {
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJhaGdmdmtqcnFoaHZ0aG5xd3F3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk4Nzk0MTQsImV4cCI6MjA4NTQ1NTQxNH0.8hlveFpA3758k8Nv-Kj4tRwPE5WNke89UaD3aduSqpY' 
}
response = requests.post('http://localhost:8000/api/trips/', json=trip_data, headers=headers, timeout=30)

if response.status_code == 200:
    trip = response.json()
    print(f"✅ Trip created: {trip['id']}")
    
    # Check first activity for photo_url
    if trip.get('itinerary', {}).get('days'):
        first_day = trip['itinerary']['days'][0]
        print(f"Day 1 has {len(first_day.get('activities', []))} activities:")
        
        for i, activity in enumerate(first_day.get('activities', [])[:3]):
            print(f"  {i+1}. {activity.get('name')} - photo_url: {activity.get('photo_url', 'NONE')[:80] if activity.get('photo_url') else 'NONE'}")
else:
    print(f"❌ Error: {response.status_code}")
    print(response.text[:500])
