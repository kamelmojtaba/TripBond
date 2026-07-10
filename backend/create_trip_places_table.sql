-- Create trip_places table to store places added to trips by users
-- Supports duplicate detection by external_place_id or (name, latitude, longitude) combo

CREATE TABLE IF NOT EXISTS trip_places (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    
    -- Place identification
    external_place_id TEXT,  -- e.g., Geoapify place ID
    name TEXT NOT NULL,
    address TEXT,
    
    -- Location coordinates
    latitude NUMERIC(9, 6) NOT NULL,
    longitude NUMERIC(9, 6) NOT NULL,
    
    -- Place info
    rating NUMERIC(3, 1),
    user_ratings_total INTEGER,
    place_types JSONB DEFAULT '[]'::jsonb,  -- Array of place types/categories
    image_url TEXT,
    
    -- Tracking
    added_by UUID NOT NULL REFERENCES auth.users(id),
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes for efficient duplicate detection
    CONSTRAINT unique_external_place_per_trip UNIQUE NULLS NOT DISTINCT (trip_id, external_place_id),
    CONSTRAINT unique_coordinates_per_trip UNIQUE (trip_id, name, latitude, longitude)
);

-- Create indexes for common queries
CREATE INDEX idx_trip_places_trip_id ON trip_places(trip_id);
CREATE INDEX idx_trip_places_external_id ON trip_places(external_place_id);
CREATE INDEX idx_trip_places_added_by ON trip_places(added_by);
