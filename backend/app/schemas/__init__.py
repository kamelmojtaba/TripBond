"""
Schemas - Pydantic Models

Request/response validation models for all API endpoints.
"""
from . import auth, profile, preferences, personality, group, pois, places, feedback, settings, trips, favorites, chat

__all__ = [
    "auth",
    "profile",
    "preferences",
    "personality",
    "group",
    "pois",
    "places",
    "feedback",
    "settings",
    "trips",
    "favorites",
    "chat",
]