"""
Settings Schemas

Pydantic models for request/response validation in settings endpoints.
"""
from pydantic import BaseModel
from typing import Optional, Literal


class UserSettingsResponse(BaseModel):
    user_id: str
    # Account settings
    security_enabled: Optional[bool] = True
    notifications_enabled: Optional[bool] = True
    privacy_mode: Optional[Literal["public", "friends", "private"]] = "public"


class UpdateSettingsRequest(BaseModel):
    security_enabled: Optional[bool] = None
    notifications_enabled: Optional[bool] = None
    privacy_mode: Optional[Literal["public", "friends", "private"]] = None
