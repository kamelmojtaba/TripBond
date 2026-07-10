import json
import urllib.request

BASE = "http://localhost:8000"
EMAIL = "jayuslayy@gmail.com"
PASSWORD = "Juju1234"


def call(method: str, path: str, data=None, token=None):
    url = f"{BASE}{path}"
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    body = None if data is None else json.dumps(data).encode("utf-8")
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=60) as resp:
        txt = resp.read().decode("utf-8")
        return json.loads(txt) if txt else {}


print("1) Sign in")
signin = call("POST", "/api/auth/signin", {"email": EMAIL, "password": PASSWORD})
token = signin["access_token"]
print("   Sign in OK")

print("2) Create trip")
trip = call(
    "POST",
    "/api/trips/",
    {
        "title": "AI E2E Smoke Trip",
        "destination": "Khobar",
        "location": "Khobar",
        "start_date": "2026-04-10",
        "end_date": "2026-04-12",
        "trip_type": "friends",
        "description": "Automated AI flow verification",
        "is_public": True,
    },
    token=token,
)
trip_id = trip["id"]
print(f"   Trip created: {trip_id}")

print("3) Generate itinerary")
itinerary = call(
    "POST",
    f"/api/trips/{trip_id}/generate-itinerary",
    {
        "preferences": {
            "activities": {"cultural": 0.8, "food": 0.7, "adventure": 0.6},
            "budget": 2,
            "pace": "moderate",
        },
        "use_ga": True,
        "max_budget": 1000,
        "pace": "moderate",
    },
    token=token,
)
print(
    f"   Generated days: {itinerary.get('total_days')}, strategy: {itinerary.get('strategy')}"
)

print("4) Fetch latest itinerary")
latest = call("GET", f"/api/trips/{trip_id}/itinerary", token=token)
print(f"   Latest itinerary days: {latest.get('total_days')}")
# Print first day's activities to verify place names
if latest.get("days") and len(latest["days"]) > 0:
    first_day_activities = latest["days"][0].get("activities", [])
    if first_day_activities:
        print(f"   Day 1 activities:")
        for activity in first_day_activities[:2]:
            print(f"     - {activity.get('name', 'Unknown')} ({activity.get('title', 'N/A')})")

print("5) Fetch recommendations")
recs = call("GET", f"/api/trips/{trip_id}/recommendations?limit=3", token=token)
print(f"   Recommendations: {len(recs)}")
if recs:
    print(f"   First recommendation: {recs[0]['poi']['name']}")

print("6) Cleanup trip")
call("DELETE", f"/api/trips/{trip_id}", token=token)
print("   Cleanup done (trip deleted)")

print("\nAI E2E smoke test: PASSED")
