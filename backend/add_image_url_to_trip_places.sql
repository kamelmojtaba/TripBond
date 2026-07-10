-- Add image_url column to trip_places table to store Google Places photo URLs

ALTER TABLE trip_places
ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Add the same column to itinerary items if it doesn't exist
ALTER TABLE itinerary_items
ADD COLUMN IF NOT EXISTS photo_url TEXT;
