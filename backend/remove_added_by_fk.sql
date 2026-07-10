-- Remove the foreign key constraint on trip_places.added_by
-- This allows tracking who added places without requiring users table entries

ALTER TABLE trip_places
DROP CONSTRAINT IF EXISTS trip_places_added_by_fkey;
