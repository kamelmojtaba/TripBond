#!/usr/bin/env python3
"""Test the POI endpoint to see what data it returns"""
import requests
import json

BASE_URL = "http://localhost:8000"

# First test if backend is running
try:
    response = requests.get(f"{BASE_URL}/health", timeout=2)
    print("Backend Status:", response.status_code)
    print(json.dumps(response.json(), indent=2))
except requests.exceptions.ConnectionError:
    print("ERROR: Cannot connect to backend at localhost:8000")
    print("Make sure backend is running: python -m uvicorn app.main:app --reload")
    exit(1)

print("\n" + "="*60)
print("Testing POI Search Endpoint")
print("="*60 + "\n")

# Test POI search for Jeddah
response = requests.get(f"{BASE_URL}/api/pois", params={
    "location": "Jeddah",
    "limit": 5
})

print("Status Code:", response.status_code)
if response.status_code == 200:
    data = response.json()
    print("Response:")
    print(json.dumps(data, indent=2))
    
    # Check first place structure
    if data and len(data) > 0:
        first_place = data[0]
        print("\n\nFirst place structure:")
        for key, value in first_place.items():
            print(f"  {key}: {value} (type: {type(value).__name__})")
else:
    print(f"Error: {response.status_code}")
    print(response.text)
