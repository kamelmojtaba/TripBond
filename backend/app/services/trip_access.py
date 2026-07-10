"""
Trip Access Control Service

Handles authorization and access verification for trip operations.
"""
from fastapi import HTTPException, status
from fastapi.concurrency import run_in_threadpool
from typing import Optional
from ..database import SupabaseDB
import logging

logger = logging.getLogger(__name__)


def _is_public_trip(trip: dict) -> bool:
    value = trip.get("is_public")
    if value is None:
        return True
    if isinstance(value, str):
        return value.strip().lower() not in {"false", "0", "no", "private"}
    return bool(value)


async def check_trip_access(
    trip_id: str, 
    user_id: str, 
    token: Optional[str] = None, 
    required_role: str = "view"
) -> dict:
    """
    Check trip access authorization based on role.
    
    Args:
        trip_id: Trip identifier
        user_id: User requesting access
        token: JWT token for user-scoped operations
        required_role: "creator", "member", or "view"
    
    Returns:
        dict: Trip data if access is granted
    
    Raises:
        HTTPException: 404 if trip not found, 403 if access denied
    
    Access levels:
    - creator: Only trip creator
    - member: Trip creator or accepted members
    - view: Members or anyone if trip is public
    """
    db = SupabaseDB(admin=True)
    
    # Fetch trip (admin client for read-only access)
    trip_response = await run_in_threadpool(
        lambda: db.client.table("trips").select("*").eq("id", trip_id).execute()
    )
    
    if not trip_response.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trip not found"
        )
    
    trip = trip_response.data[0]
    is_creator = trip["created_by"] == user_id
    
    # Require token for creator/member checks to prevent accidental privilege escalation
    if required_role in ("creator", "member") and not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token required for this operation"
        )
    
    # Check if user is an accepted member
    participant_response = await run_in_threadpool(
        lambda: db.client.table("trip_participants")
        .select("user_id, status")
        .eq("trip_id", trip_id)
        .eq("user_id", user_id)
        .execute()
    )
    
    is_member = bool(
        participant_response.data 
        and participant_response.data[0].get("status") == "accepted"
    )
    
    # Enforce access control based on required role
    if required_role == "creator":
        if not is_creator:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only trip creator can perform this action"
            )
    elif required_role in ("member", "edit"):
        if not (is_creator or is_member):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only trip members can perform this action"
            )
    elif required_role == "view":
        if not (is_creator or is_member):
            if not _is_public_trip(trip):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="You do not have access to this private trip"
                )
    
    return trip
