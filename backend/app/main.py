from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.concurrency import run_in_threadpool
from .config import get_settings
from .routers import (
    auth,
    personality,
    preferences,
    trips,
    group,
    feedback,
    users,
    pois,
    favorites,
    places,
    chat,
    ai,
    suggestions,
    votes,
    feed,
    notifications,
)
import logging
import os
import time
from .database import get_supabase_admin_client
from fastapi import Request

logger = logging.getLogger(__name__)

_settings = get_settings()

app = FastAPI(
    title="TripBond API",
    description="AI-based Group Travel Recommender System Backend",
    version=_settings.api_version
)

# Configure CORS at module level (must be before app starts)
app.add_middleware(
    CORSMiddleware,
    allow_origins=_settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# AI engine readiness (validated at startup)
ai_engine_status = {
    "status": "unknown",
    "error": None
}


@app.on_event("startup")
async def startup_initialization():
    """Initialize configuration and validate dependencies"""
    global ai_engine_status
    
    # Load config and store on app.state (test-friendly)
    app.state.config = _settings
    config = app.state.config
    
    logger.info(f"TripBond API v{config.api_version} starting up...")
    
    # Validate AI engine
    try:
        model_path = config.model_path
        
        if not model_path:
            ai_engine_status["status"] = "not_configured"
            logger.info("AI model not configured")
        elif not os.path.exists(model_path):
            ai_engine_status["status"] = "not_loaded"
            ai_engine_status["error"] = f"Model file not found at {model_path}"
            logger.warning(f"AI model not found: {model_path}")
        else:
            # TODO: Load model here (await run_in_threadpool(load_model, model_path))
            ai_engine_status["status"] = "ready"
            logger.info(f"AI model found: {model_path}")
        
    except Exception as e:
        ai_engine_status["status"] = "error"
        ai_engine_status["error"] = str(e)
        logger.exception("AI engine validation failed during startup")


# Include routers
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(personality.router, prefix="/api/personality", tags=["Personality Quiz"])
app.include_router(preferences.router, prefix="/api/preferences", tags=["Travel Preferences"])
app.include_router(trips.router, prefix="/api/trips", tags=["Trips & Itineraries"])
app.include_router(users.router, prefix="/api/users", tags=["User Management"])
app.include_router(favorites.router, prefix="/api/favorites", tags=["Favorites"])
app.include_router(pois.router, prefix="/api/pois", tags=["Points of Interest"])
app.include_router(group.router, prefix="/api/group", tags=["Group Modeling & Optimization"])
app.include_router(feedback.router, prefix="/api/feedback", tags=["Feedback & Learning"])
app.include_router(places.router, prefix="/api/places", tags=["Google Places"])
app.include_router(chat.router, prefix="/api/chat", tags=["Chat"])
app.include_router(ai.router, prefix="/api/ai", tags=["AI Recommendations & Optimization"])
app.include_router(suggestions.router, prefix="/api/suggestions", tags=["Place Suggestions & Voting"])
app.include_router(votes.router, prefix="/api/votes", tags=["Voting"])
app.include_router(feed.router, prefix="/api/feed", tags=["Social Feed"])
app.include_router(notifications.router, prefix="/api/notifications", tags=["Notifications"])


@app.get("/")
async def root(request: Request):
    """Root endpoint - service information"""
    print(f"🟢 ROOT ENDPOINT HIT from {request.client}")
    return {
        "status": "online",
        "service": "TripBond API",
        "version": request.app.state.config.api_version
    }


@app.get("/api/test")
async def test_endpoint(request: Request):
    """Test endpoint to verify connectivity"""
    print(f"🟢 TEST ENDPOINT HIT from {request.client}")
    return {
        "status": "success",
        "message": "Backend is reachable!",
        "client": str(request.client)
    }


@app.get("/health")
async def health_check():
    """Detailed health check - validates database and system readiness"""
    
    health_status = {
        "status": "healthy",
        "database": "unknown",
        "ai_engine": "unknown",
        "response_time_ms": {
            "database": None
        }
    }
    
    # Test database connection
    try:
        client = get_supabase_admin_client()
        start_time = time.perf_counter()

        await run_in_threadpool(
            lambda: client.table("profiles").select("id").limit(1).execute()
        )
        
        db_time = (time.perf_counter() - start_time) * 1000
        
        health_status["database"] = "connected"
        health_status["response_time_ms"]["database"] = round(db_time, 2)
    except Exception:
        logger.exception("Database health check failed")
        health_status["status"] = "unhealthy"
        health_status["database"] = "error"
    
    # Report AI engine status
    health_status["ai_engine"] = ai_engine_status["status"]
    
    if ai_engine_status["status"] in ["not_loaded", "error"]:
        if health_status["status"] == "healthy":
            health_status["status"] = "degraded"
    
    return health_status
