from pydantic_settings import BaseSettings
from pydantic import ConfigDict
from typing import Optional
from functools import lru_cache
from pathlib import Path


class Settings(BaseSettings):
    """Application settings loaded from environment variables"""

    model_config = ConfigDict(
        env_file=str(Path(__file__).parent.parent / ".env"),
        case_sensitive=False,
        protected_namespaces=()
    )

    # Supabase
    supabase_url: str
    supabase_key: str
    supabase_anon_key: str
    supabase_service_role_key: Optional[str] = None

    # JWT Authentication
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30

    # Google Maps / Places API
    google_maps_api_key: Optional[str] = None
    place_cache_days: int = 27
    place_cache_max_photos: int = 6
    place_cache_upload_images: bool = True
    place_cache_storage_bucket: str = "place-images"

    # Geoapify Places API
    geoapify_api_key: Optional[str] = None

    # TomTom Search & Places API
    tomtom_api_key: Optional[str] = None

    # Foursquare API (for enriching POI data)
    foursquare_api_key: Optional[str] = None

    # ML Model
    model_path: str = ""
    recommendation_top_k: int = 5

    # External AI service (Flask)
    ai_backend_url: str = "http://localhost:5000"
    ai_backend_timeout: int = 30

    # API
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    api_version: str = "1.0.0"
    debug: bool = True
    allowed_origins: list[str] = ["http://localhost:3000", "http://localhost:8080", "http://10.0.2.2:8000", "http://192.168.3.114:8000", "*"]
    frontend_url: str = "http://192.168.3.114:8000"

    # Email / SMTP  (set these in your .env to send real emails)
    smtp_host: Optional[str] = None
    smtp_port: int = 587
    smtp_user: Optional[str] = None
    smtp_password: Optional[str] = None
    smtp_from_email: Optional[str] = None


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance"""
    settings = Settings()
    # Backward compatibility: if service_role_key not set, use supabase_key
    if not settings.supabase_service_role_key:
        settings.supabase_service_role_key = settings.supabase_key
    return settings
