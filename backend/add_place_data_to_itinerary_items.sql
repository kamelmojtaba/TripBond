-- Migration: Add place data columns to itinerary_items
-- Purpose: Preserve place information (external_place_id, coordinates, etc.) in itinerary items
-- This enables the frontend to fetch detailed place information using the external_place_id

-- Add columns if they don't exist
ALTER TABLE itinerary_items
ADD COLUMN IF NOT EXISTS external_place_id TEXT,
ADD COLUMN IF NOT EXISTS place_id TEXT,
ADD COLUMN IF NOT EXISTS latitude NUMERIC(9, 6),
ADD COLUMN IF NOT EXISTS longitude NUMERIC(9, 6),
ADD COLUMN IF NOT EXISTS name TEXT,
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS rating NUMERIC(3, 1),
ADD COLUMN IF NOT EXISTS user_ratings_total INTEGER,
ADD COLUMN IF NOT EXISTS place_types JSONB;

-- Add index for finding items by external_place_id
CREATE INDEX IF NOT EXISTS idx_itinerary_items_external_place_id 
ON itinerary_items(external_place_id);
