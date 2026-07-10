# Google Places Photo URL Retrieval Flow

## Overview
This document describes the updated flow for retrieving photo URLs from Google Places API and attaching them to POI recommendations.

## Complete Flow: Search → Details → Photo → URL

### Step 1: Place Search
**Function**: `google_places_service.nearby_search_places()` or `text_search_places()`
- Searches for places by name and/or coordinate
- Returns up to 20 results with basic info
- Extracts `place_id` from first result

### Step 2: Get Place Details  
**Function**: `google_places_service.get_place_details(place_id)`
- Calls Google Places API `/details/json` endpoint
- Retrieves full place information including photos array
- Each photo has: `photo_reference`, `height`, `width`

### Step 3: Extract Photo Reference
- Gets first photo from `details.result.photos[0]`
- Extracts `photo_reference` string

### Step 4: Build Photo URL
**Function**: `google_places_service.get_photo_url(photo_reference, max_width=800)`
```
https://maps.googleapis.com/maps/api/place/photo
  ?maxwidth=800
  &photo_reference={PHOTO_REFERENCE}
  &key={API_KEY}
```

### Step 5: Return Image URL
- URL is added to POI response as `image_url` field
- If no photos found: `image_url = None`

## Key Functions

### `google_places_service.get_image_url_for_place()`
**Purpose**: Complete end-to-end flow
```python
def get_image_url_for_place(
    place_name: str,
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    language: str = "en"
) -> Optional[str]
```

**Flow**:
1. Search (nearby if coords available, text search otherwise)
2. Get place_id from first result
3. Call get_place_details(place_id)
4. Extract first photo_reference
5. Build and return complete photo URL

**Returns**: Full photo URL or None

---

### `ai_poi_service._enrich_with_photos()`
**Purpose**: Enriches CSV-based POIs with Google Places photos

**Flow**:
1. Validates coordinates and API key
2. Calls `get_image_url_for_place()`  
3. Sets `poi["image_url"]` with returned URL
4. Logs success/failure

---

## POI Response Structure

```json
{
  "id": "POI_000024",
  "name": "Wadi Namar",
  "location": "Riyadh",
  "type": "attraction",
  "rating": 4.5,
  "description": "Tourist attraction with natural beauty...",
  "latitude": 24.6,
  "longitude": 46.7,
  "image_url": "https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=ABC123...&key=YOUR_KEY",
  "opening_hours": "Daily 9am-6pm",
  "province": "Riyadh"
}
```

## Error Handling

### Missing API Key
- `get_image_url_for_place()` returns `None`
- Logs warning: "Google Maps API key not configured"
- POI still returned with `image_url = null`

### No Photos Found
- Place found but no photos in details
- `get_image_url_for_place()` returns `None`
- POI still returned with `image_url = null`
- Logs debug message: "Place found but no photos"

### Network/API Errors
- Caught and logged
- Function returns `None`
- POI still returned with `image_url = null`
- App continues without blocking

## Testing

### Run POI Enrichment Test
```bash
cd backend
python test_poi_enrichment.py
```

Expected output:
```
Fetching POIs for Al Khobar with Google Places enrichment...
Found 5 POIs

Place: Saudi Plaza
  Image URL: https://maps.googleapis.com/maps/api/place/photo?maxwidth=800...
  Rating: 4.5
  Location: Al Khobar
  
Place: Marina Beach
  Image URL: https://maps.googleapis.com/maps/api/place/photo?maxwidth=800...
  Rating: 4.4
  Location: Al Khobar
  
Place: Local Restaurant
  Image URL: None (place found but no photos available)
  Rating: 4.2
  Location: Al Khobar
```

## Configuration

### Required
```env
GOOGLE_MAPS_API_KEY=your_api_key_here
```

### Prerequisites
1. Google Cloud Project with billing enabled
2. Places API enabled
3. API key has Places API permissions
4. Consider rate limits: ~2500 requests/day free tier

## Performance Notes

- Each POI enrichment makes 2 API calls: search + details
- Recommend caching photo URLs in database
- Consider batch enrichment for bulk operations
- Photos are not stored, only URLs returned

## Schema

### POI Response Schema
- `image_url: Optional[str]` - Complete Google Places photo URL
- Null if no photo available
- Direct link to image (200px-1600px width)

