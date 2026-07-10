#!/usr/bin/env python
"""Test if all backend modules can be imported"""

try:
    print("Importing app...")
    from app.main import app
    print("✓ app.main loaded")
    
    from app.config import get_settings
    print("✓ config loaded")
    settings = get_settings()
    print(f"✓ Settings loaded: API on {settings.api_host}:{settings.api_port}")
    
    from app.database import get_supabase_admin_client
    print("✓ database loaded")
    
    from app.routers import auth
    print("✓ auth router loaded")
    
    from app.services import email_service
    print("✓ email_service loaded")
    
    print("\n✅ All imports successful - backend should be ready")
    
except Exception as e:
    print(f"\n❌ Import error: {type(e).__name__}: {e}")
    import traceback
    traceback.print_exc()
