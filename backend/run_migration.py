#!/usr/bin/env python3
"""Run database migration to add place data columns"""

import os
import sys
from app.database import _SupabaseDB

def run_migration():
    """Apply place data migration to itinerary_items table"""
    
    # Read the migration SQL
    migration_path = os.path.join(os.path.dirname(__file__), "add_place_data_to_itinerary_items.sql")
    
    if not os.path.exists(migration_path):
        print(f"❌ Migration file not found: {migration_path}")
        return False
    
    with open(migration_path, 'r') as f:
        migration_sql = f.read()
    
    print("🔵 Running migration: add_place_data_to_itinerary_items.sql")
    print("=" * 60)
    
    try:
        # Get admin client
        db = _SupabaseDB(admin=True)
        
        # Execute SQL - note: this uses the raw supabase client to execute SQL
        # We need to split the migration into executable statements
        
        # For now, we'll use a simpler approach - just try to insert with the new columns
        # If it fails, the columns are missing. If it succeeds, they exist.
        
        result = db.client.rpc("execute_sql", {"query": migration_sql}).execute()
        
        print("✅ Migration executed successfully")
        print(result)
        return True
        
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        return False

if __name__ == "__main__":
    success = run_migration()
    sys.exit(0 if success else 1)
