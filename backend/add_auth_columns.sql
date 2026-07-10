-- Add custom authentication columns to profiles table
-- Run this in Supabase SQL Editor

ALTER TABLE profiles
ADD COLUMN email_address TEXT UNIQUE NOT NULL DEFAULT '',
ADD COLUMN password_hash TEXT NOT NULL DEFAULT '',
ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT FALSE;

-- Create index on email_address for faster lookups
CREATE INDEX idx_profiles_email_address ON profiles(email_address);

-- Remove default values after adding columns (they were just for migration)
ALTER TABLE profiles
ALTER COLUMN email_address DROP DEFAULT,
ALTER COLUMN password_hash DROP DEFAULT;
