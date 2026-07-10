-- Trip lifecycle and per-member readiness for the main planning flow.
-- Apply this to Supabase before using the gated trip flow screens.

ALTER TABLE trips
ADD COLUMN IF NOT EXISTS phase TEXT NOT NULL DEFAULT 'planning';

UPDATE trips
SET phase = 'planning'
WHERE phase IS NULL OR phase = '';

CREATE TABLE IF NOT EXISTS trip_member_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    places_completed_at TIMESTAMP WITH TIME ZONE,
    voting_completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT unique_trip_member_progress UNIQUE (trip_id, user_id)
);

ALTER TABLE trip_member_progress ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_trip_member_progress_trip_id
    ON trip_member_progress(trip_id);

CREATE INDEX IF NOT EXISTS idx_trip_member_progress_user_id
    ON trip_member_progress(user_id);

CREATE TABLE IF NOT EXISTS place_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_place_id UUID NOT NULL REFERENCES trip_places(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    value INTEGER NOT NULL CHECK (value BETWEEN 1 AND 5),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT unique_place_vote_per_user UNIQUE (trip_place_id, user_id)
);

ALTER TABLE place_votes ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_place_votes_trip_place_id
    ON place_votes(trip_place_id);

CREATE INDEX IF NOT EXISTS idx_place_votes_user_id
    ON place_votes(user_id);
