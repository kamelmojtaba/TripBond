#!/usr/bin/env python
"""
TripBond AI Backend Server Startup
===================================
Runs the Flask REST API for AI recommendations, itinerary generation, and GA optimization.

Usage:
    python tripbond_ai_backend/run_ai.py

Endpoints:
    GET  /health              - Health check
    POST /recommend/group     - Group POI recommendations  
    POST /itinerary/group     - Group itinerary optimization (GA or Greedy)
"""

import sys
from pathlib import Path

# Add root to path so imports work correctly
root_path = Path(__file__).parent.parent
sys.path.insert(0, str(root_path))

from tripbond_ai_backend.api.app import app

if __name__ == "__main__":
    print("=" * 70)
    print("TripBond AI Backend - Starting Flask Server")
    print("=" * 70)
    print(f"🚀 Server running on http://localhost:5000")
    print(f"📊 Health check: http://localhost:5000/health")
    print(f"📈 API Docs: http://localhost:5000/docs (if Swagger enabled)")
    print(f"⚙️  Press Ctrl+C to stop server")
    print("=" * 70)
    
    # Run Flask app
    app.run(
        host="0.0.0.0",
        port=5000,
        debug=False,
        use_reloader=False
    )
