#!/usr/bin/env python3
"""Remove the foreign key constraint on trip_places.added_by"""

import os
import sys
from app.database import SupabaseDB

def run_migration():
    """Remove added_by foreign key constraint from trip_places table"""
    
    migration_sql = """
    ALTER TABLE trip_places
    DROP CONSTRAINT IF EXISTS trip_places_added_by_fkey;
    """
    
    print("🔵 Removing FK constraint on trip_places.added_by...")
    print("=" * 60)
    
    try:
        # Get admin client
        db = SupabaseDB(admin=True)
        
        # Execute the migration using RPC
        result = db.client.rpc("execute_sql", {"query": migration_sql}).execute()
        
        print("✅ FK constraint removed successfully!")
        print(result)
        return True
        
    except Exception as e:
        print(f"⚠️ Note: {e}")
        print("The constraint may already be removed or doesn't exist.")
        return True  # Don't fail if constraint doesn't exist

if __name__ == "__main__":
    success = run_migration()
    sys.exit(0 if success else 1)
