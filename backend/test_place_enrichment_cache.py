from datetime import datetime, timedelta, timezone

from app.services import place_enrichment_service


def test_merge_place_with_enrichment_prefers_cached_gallery():
    expires_at = (datetime.now(timezone.utc) + timedelta(days=7)).isoformat()
    place = {
        "id": "dataset-1",
        "name": "Old Name",
        "location": "Riyadh",
        "image_url": "https://example.com/old.jpg",
    }
    enrichment = {
        "source_place_id": "google-1",
        "name": "Google Name",
        "city": "Riyadh",
        "address": "Riyadh, Saudi Arabia",
        "description": "A cached description.",
        "google_maps_url": "https://maps.google.com/?cid=1",
        "images": [
            {
                "url": "https://cdn.example.com/cover.jpg",
                "attributions": ["Photo Author"],
                "expires_at": expires_at,
                "sort_order": 0,
            },
            {
                "url": "https://cdn.example.com/second.jpg",
                "attributions": ["Second Author"],
                "expires_at": expires_at,
                "sort_order": 1,
            },
        ],
        "expires_at": expires_at,
    }

    merged = place_enrichment_service.merge_place_with_enrichment(place, enrichment)

    assert merged["place_id"] == "google-1"
    assert merged["image_url"] == "https://cdn.example.com/cover.jpg"
    assert len(merged["images"]) == 2
    assert merged["google_maps_url"] == "https://maps.google.com/?cid=1"
    assert merged["cache_status"] == "fresh"


def test_merge_place_without_enrichment_marks_missing_cache():
    merged = place_enrichment_service.merge_place_with_enrichment(
        {"name": "Dammam Corniche", "city": "Dammam"},
        None,
    )

    assert merged["image_asset"] == "assets/images/places/dammam_corniche.jpg"
    assert merged["cache_status"] == "missing"
