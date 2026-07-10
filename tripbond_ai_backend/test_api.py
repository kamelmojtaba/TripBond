"""Test TripBond API endpoints"""
import requests
import json

BASE_URL = "http://127.0.0.1:5000"

def test_health():
    """Test health endpoint"""
    print("\n" + "="*60)
    print("Testing: GET /health")
    print("="*60)
    
    response = requests.get(f"{BASE_URL}/health")
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.json()}")
    return response.status_code == 200

def test_group_recommendations():
    """Test group recommendations endpoint"""
    print("\n" + "="*60)
    print("Testing: POST /recommend/group")
    print("="*60)
    
    payload = {
        "user_ids": ["USER_000001", "USER_000002", "USER_000003"],
        "top_k": 10
    }
    
    print(f"Request: {json.dumps(payload, indent=2)}")
    
    response = requests.post(
        f"{BASE_URL}/recommend/group",
        json=payload
    )
    
    print(f"Status Code: {response.status_code}")
    result = response.json()
    
    if result.get("success"):
        print(f"Success! Got {result.get('num_pois')} recommendations")
        print(f"\nTop 3 POIs:")
        for poi in result.get('recommendations', [])[:3]:
            print(f"  - {poi['poi_id']}: score={poi.get('final_group_score', 'N/A')}")
    else:
        print(f"Error: {result.get('error')}")
    
    return response.status_code == 200

def test_itinerary_ga():
    """Test GA itinerary endpoint"""
    print("\n" + "="*60)
    print("Testing: POST /itinerary/group (GA method)")
    print("="*60)
    
    payload = {
        "user_ids": ["USER_000001", "USER_000002"],
        "method": "ga",
        "num_stops": 5
    }
    
    print(f"Request: {json.dumps(payload, indent=2)}")
    
    response = requests.post(
        f"{BASE_URL}/itinerary/group",
        json=payload
    )
    
    print(f"Status Code: {response.status_code}")
    result = response.json()
    
    if result.get("success"):
        print(f"Success! Generated {result.get('num_stops')}-stop itinerary")
        print(f"Total Cost: {result.get('total_cost')}")
        print(f"Fitness: {result.get('fitness')}")
        print(f"\nItinerary:")
        for stop in result.get('itinerary', []):
            print(f"  Stop {stop['stop_number']}: {stop['poi_id']} (score: {stop.get('final_group_score', 'N/A')})")
    else:
        print(f"Error: {result.get('error')}")
    
    return response.status_code == 200

if __name__ == "__main__":
    print("\n" + "="*60)
    print("TripBond API Test Suite")
    print("="*60)
    
    # Test endpoints
    results = []
    
    try:
        results.append(("Health Check", test_health()))
        results.append(("Group Recommendations", test_group_recommendations()))
        results.append(("GA Itinerary", test_itinerary_ga()))
    except requests.exceptions.ConnectionError:
        print("\n[ERROR] Could not connect to server.")
        print("Make sure the Flask server is running on http://127.0.0.1:5000")
        exit(1)
    except Exception as e:
        print(f"\n[ERROR] Test failed: {str(e)}")
        exit(1)
    
    # Summary
    print("\n" + "="*60)
    print("Test Summary")
    print("="*60)
    for test_name, passed in results:
        status = "✓ PASSED" if passed else "✗ FAILED"
        print(f"{test_name:<30} {status}")
    
    all_passed = all(result[1] for result in results)
    print("\n" + "="*60)
    if all_passed:
        print("All tests passed! ✓")
    else:
        print("Some tests failed! ✗")
    print("="*60)
