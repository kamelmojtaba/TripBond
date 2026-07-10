-- Add image_url column to trip_places table if it doesn't exist
ALTER TABLE trip_places ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Add comment to column for clarity
COMMENT ON COLUMN trip_places.image_url IS 'URL of the place image';
