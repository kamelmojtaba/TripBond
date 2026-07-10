#!/usr/bin/env python
"""Comprehensive module import test"""

failed_imports = []
successful_imports = []

test_modules = [
    # Routers
    "app.routers.auth",
    "app.routers.chat",
    "app.routers.feedback",
    "app.routers.favorites",
    "app.routers.group",
    "app.routers.personality",
    "app.routers.preferences",
    "app.routers.places",
    "app.routers.pois",
    "app.routers.trips",
    "app.routers.users",
    
    # Services
    "app.services.email_service",
    "app.services.verification_store",
    "app.services.password_reset_store",
    "app.services.geoapify_service",
    "app.services.feedback_service",
    
    # Main modules
    "app.main",
    "app.database",
    "app.config",
    "app.auth",
]

for module in test_modules:
    try:
        __import__(module)
        successful_imports.append(module)
        print(f"✓ {module}")
    except Exception as e:
        failed_imports.append((module, str(e)))
        print(f"✗ {module}: {e}")

print(f"\n\nSummary:")
print(f"✓ Successful: {len(successful_imports)}/{len(test_modules)}")
if failed_imports:
    print(f"✗ Failed: {len(failed_imports)}")
    for module, error in failed_imports:
        print(f"  - {module}: {error[:100]}...")
else:
    print("✓ All imports successful!")
