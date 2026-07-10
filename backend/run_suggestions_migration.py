#!/usr/bin/env python3
"""Run the SQL migration to create suggestions and voting tables"""

import os
import sys
from pathlib import Path

# Add the backend to the path
backend_dir = Path(__file__).parent
sys.path.insert(0, str(backend_dir))

from app.database import SupabaseDB

def run_migration():
    """Create suggestions and voting tables"""
    
    # Read the SQL migration
    sql_file = backend_dir / "create_suggestions_voting_tables.sql"
    
    if not sql_file.exists():
        print(f"❌ SQL file not found: {sql_file}")
        return False
    
    with open(sql_file, 'r') as f:
        sql_statements = f.read()
    
    print("🔵 Running migration: create_suggestions_voting_tables.sql")
    print("=" * 60)
    
    try:
        # Get admin client
        db = SupabaseDB(admin=True)
        
        # Split and execute each statement
        for statement in sql_statements.split(';'):
            statement = statement.strip()
            if not statement or statement.startswith('--'):
                continue
            
            try:
                result = db.client.rpc("execute_sql", {"query": statement + ";"}).execute()
                print(f"✅ Executed: {statement[:50]}...")
            except Exception as e:
                print(f"⚠️  Note: {statement[:50]}... - {str(e)[:100]}")
        
        print("\n✅ Migration completed!")
        return True
        
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = run_migration()
    sys.exit(0 if success else 1)
