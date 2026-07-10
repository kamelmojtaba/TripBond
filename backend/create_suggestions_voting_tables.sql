-- Create table for Bonders Suggestions - places awaiting AI evaluation
-- AI automatically evaluates and approves/rejects, then adds approved places to trip_places

CREATE TABLE IF NOT EXISTS place_suggestions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    
    -- Place identification
    external_place_id TEXT,
    name TEXT NOT NULL,
    address TEXT,
    
    -- Location coordinates
    latitude NUMERIC(9, 6) NOT NULL,
    longitude NUMERIC(9, 6) NOT NULL,
    
    -- Place info
    rating NUMERIC(3, 1),
    user_ratings_total INTEGER,
    place_types JSONB DEFAULT '[]'::jsonb,
    image_url TEXT,
    
    -- AI Evaluation
    ai_score NUMERIC(3, 2) DEFAULT 0.5,  -- 0.0 to 1.0, AI suitability score
    ai_reasoning TEXT,  -- Why AI approved/rejected
    
    -- Status
    status TEXT DEFAULT 'pending',  -- pending, approved, added, rejected
    suggested_by UUID,  -- Who suggested it
    suggested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_suggestion_per_trip UNIQUE (trip_id, external_place_id, name, latitude, longitude)
);

-- Create indexes for efficient queries
CREATE INDEX idx_place_suggestions_trip_id ON place_suggestions(trip_id);
CREATE INDEX idx_place_suggestions_status ON place_suggestions(status);
