-- Remove the foreign key constraint linking profiles to auth.users
-- Run this in Supabase SQL Editor

ALTER TABLE profiles
DROP CONSTRAINT IF EXISTS profiles_id_fkey;

-- This allows profiles to exist independently without requiring entries in auth.users
