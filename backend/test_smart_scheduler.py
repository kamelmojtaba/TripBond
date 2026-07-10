from app.schemas.trips import ItineraryResponse
from app.services.smart_scheduler import build_smart_itinerary


def test_smart_itinerary_activities_validate_against_response_schema():
    trip = {
        "id": "trip-1",
        "destination": "Jeddah",
        "start_date": "2026-05-18",
        "end_date": "2026-05-19",
    }
    places = [
        {
            "id": "place-1",
            "name": "Albaik",
            "address": "Jeddah, Makkah",
            "latitude": 21.5433,
            "longitude": 39.1728,
            "rating": 4.8,
            "types": [],
        },
        {
            "id": "place-2",
            "name": "Jeddah Corniche",
            "address": "Jeddah, Makkah",
            "latitude": 21.5795,
            "longitude": 39.1466,
            "rating": 4.6,
            "types": [],
        },
    ]

    generated = build_smart_itinerary(trip, places, pace="moderate")

    response = ItineraryResponse(
        trip_id=trip["id"],
        days=generated.days,
        total_cost=generated.total_cost,
        total_days=len(generated.days),
        optimization_score=generated.fitness_score,
        strategy=generated.strategy,
    )

    assert response.days[0].activities[0].location == "Jeddah, Makkah"


if __name__ == "__main__":
    test_smart_itinerary_activities_validate_against_response_schema()
    print("smart scheduler schema regression passed")
