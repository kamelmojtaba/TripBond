-- Cache Google Places enrichment data for app-facing city and POI screens.
-- Google Maps content must be refreshed according to the configured cache policy.

CREATE TABLE IF NOT EXISTS place_enrichments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source TEXT NOT NULL DEFAULT 'google_places',
    source_place_id TEXT NOT NULL,
    dataset_poi_id TEXT,
    name TEXT NOT NULL,
    city TEXT,
    address TEXT,
    latitude NUMERIC(9, 6),
    longitude NUMERIC(9, 6),
    rating NUMERIC(3, 1),
    user_ratings_total INTEGER,
    price_level INTEGER,
    types JSONB NOT NULL DEFAULT '[]'::jsonb,
    description TEXT,
    google_maps_url TEXT,
    website TEXT,
    phone TEXT,
    opening_hours JSONB,
    image_url TEXT,
    images JSONB NOT NULL DEFAULT '[]'::jsonb,
    photo_attributions JSONB NOT NULL DEFAULT '[]'::jsonb,
    place_attributions JSONB NOT NULL DEFAULT '[]'::jsonb,
    match_confidence NUMERIC(4, 3),
    fetched_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_error TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT place_enrichments_source_place_unique UNIQUE (source, source_place_id)
);

CREATE INDEX IF NOT EXISTS idx_place_enrichments_city
ON place_enrichments (city);

CREATE INDEX IF NOT EXISTS idx_place_enrichments_dataset_poi_id
ON place_enrichments (dataset_poi_id);

CREATE INDEX IF NOT EXISTS idx_place_enrichments_expires_at
ON place_enrichments (expires_at);

CREATE INDEX IF NOT EXISTS idx_place_enrichments_name_city
ON place_enrichments (lower(name), lower(city));

ALTER TABLE place_enrichments ENABLE ROW LEVEL SECURITY;

-- The backend uses the service role for enrichment writes. Public reads should
-- continue through FastAPI endpoints rather than direct client table access.
DROP POLICY IF EXISTS "Backend service role manages place enrichments" ON place_enrichments;
CREATE POLICY "Backend service role manages place enrichments"
ON place_enrichments
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

COMMENT ON TABLE place_enrichments IS 'Scheduled cache of Google Places metadata and temporary photo galleries for TripBond POI displays.';
COMMENT ON COLUMN place_enrichments.images IS 'Ordered cached gallery entries with url, width, height, source, attributions, expires_at, and sort_order.';
