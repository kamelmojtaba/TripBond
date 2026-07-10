#!/usr/bin/env python3
"""Run migration to add image_url column to trip_places"""

import sys
import os
sys.path.insert(0, os.getcwd())

from app.database import get_supabase_admin_client

def run_migration():
    print('🔵 Running migration to add image_url column...')
    print('=' * 60)

    try:
        client = get_supabase_admin_client()
        
        print("\n1. Checking if image_url column exists...")
        try:
            # Try to select the column - if it fails, it doesn't exist
            result = client.table('trip_places').select('image_url').limit(1).execute()
            print("✅ image_url column already exists!")
            return True
        except Exception as e:
            error_msg = str(e)
            if 'image_url' in error_msg or 'column' in error_msg.lower():
                print(f"❌ Column doesn't exist: {error_msg}")
                
                print("\n2. To add the column, please run this SQL in Supabase dashboard (SQL Editor):")
                print()
                print("   -- Add image_url column to trip_places table")
                print("   ALTER TABLE trip_places ADD COLUMN IF NOT EXISTS image_url TEXT;")
                print()
                print("   -- Add photo_url column to itinerary_items table")  
                print("   ALTER TABLE itinerary_items ADD COLUMN IF NOT EXISTS photo_url TEXT;")
                print()
                return False
            else:
                raise
        
    except Exception as e:
        print(f'\n❌ Error: {e}')
        return False

if __name__ == '__main__':
    success = run_migration()
    sys.exit(0 if success else 1)
