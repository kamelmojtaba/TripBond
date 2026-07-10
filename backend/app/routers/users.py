from fastapi import APIRouter, HTTPException, status, Depends
from fastapi.concurrency import run_in_threadpool
from ..database import SupabaseDB, get_supabase_client_for_user
from ..auth import get_current_user_context
from ..schemas.profile import ProfileResponse, UpdateProfileRequest
from ..schemas.settings import UserSettingsResponse, UpdateSettingsRequest
from ..services import notification_service
import logging
from typing import Any, List

logger = logging.getLogger(__name__)
router = APIRouter()


def _parse_connection_ids(raw_value: Any) -> list[str]:
    """Normalize follower/following field values into a list of user IDs."""
    if raw_value is None:
        return []

    if isinstance(raw_value, list):
        ids: list[str] = []
        for item in raw_value:
            if isinstance(item, str) and item.strip():
                ids.append(item.strip())
            elif isinstance(item, dict):
                candidate = (
                    item.get("id")
                    or item.get("user_id")
                    or item.get("follower_id")
                    or item.get("following_id")
                )
                if candidate:
                    ids.append(str(candidate).strip())
        return ids

    if isinstance(raw_value, str):
        value = raw_value.strip()
        if not value:
            return []
        if "," in value:
            return [part.strip() for part in value.split(",") if part.strip()]
        return [value]

    return []


async def _get_connection_users(db: SupabaseDB, user_id: str, field_name: str) -> list[dict]:
    """Resolve connection IDs from a profile field to lightweight user objects."""
    profile_response = await run_in_threadpool(
        lambda: db.client.table("profiles").select(field_name).eq("id", user_id).limit(1).execute()
    )

    if not profile_response.data:
        return []

    ids = _parse_connection_ids(profile_response.data[0].get(field_name))
    if not ids:
        return []

    users_response = await run_in_threadpool(
        lambda: db.client.table("profiles")
        .select("id,full_name,username,avatar_url,is_public")
        .in_("id", ids)
        .execute()
    )

    users = users_response.data or []
    users_by_id = {str(u.get("id")): u for u in users}

    ordered: list[dict] = []
    for connection_id in ids:
        user = users_by_id.get(connection_id)
        if not user:
            continue

        if user.get("is_public", True) is False:
            continue

        ordered.append(
            {
                "id": str(user.get("id", "")),
                "name": user.get("full_name") or user.get("username") or "TripBond User",
                "avatar_url": user.get("avatar_url"),
            }
        )

    return ordered


def _display_name(profile: dict | None) -> str:
    if not profile:
        return "TripBond User"
    return profile.get("full_name") or profile.get("username") or "TripBond User"


async def _get_public_profile(db: SupabaseDB, user_id: str) -> dict | None:
    response = await run_in_threadpool(
        lambda: db.client.table("profiles")
        .select("id,full_name,username,avatar_url,is_public")
        .eq("id", user_id)
        .limit(1)
        .execute()
    )
    if not response.data:
        return None
    return response.data[0]


async def _get_friend_rows_between(db: SupabaseDB, user_a: str, user_b: str) -> list[dict]:
    rows: list[dict] = []
    first = await run_in_threadpool(
        lambda: db.client.table("friends")
        .select("*")
        .eq("user_id", user_a)
        .eq("friend_id", user_b)
        .execute()
    )
    rows.extend(first.data or [])

    second = await run_in_threadpool(
        lambda: db.client.table("friends")
        .select("*")
        .eq("user_id", user_b)
        .eq("friend_id", user_a)
        .execute()
    )
    rows.extend(second.data or [])
    return rows


async def _resolve_profiles(db: SupabaseDB, user_ids: list[str]) -> dict[str, dict]:
    clean_ids = [user_id for user_id in dict.fromkeys(user_ids) if user_id]
    if not clean_ids:
        return {}

    response = await run_in_threadpool(
        lambda: db.client.table("profiles")
        .select("id,full_name,username,avatar_url,is_public")
        .in_("id", clean_ids)
        .execute()
    )
    return {str(profile.get("id")): profile for profile in response.data or []}


def _friend_item(profile: dict, row: dict) -> dict:
    return {
        "id": str(profile.get("id", "")),
        "name": _display_name(profile),
        "avatar_url": profile.get("avatar_url"),
        "friendship_id": row.get("id"),
        "status": row.get("status"),
    }


@router.get("/bonders", response_model=List[dict])
async def list_bonders(
    limit: int = 50,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """List discoverable users for the Bonders screen (excluding current user)."""
    user_id, _token = user_context
    safe_limit = max(1, min(limit, 200))

    try:
        db = SupabaseDB(admin=True)
        response = await run_in_threadpool(
            lambda: db.client.table("profiles")
            .select("id,full_name,username,avatar_url,is_public")
            .neq("id", user_id)
            .eq("is_public", True)
            .limit(safe_limit)
            .execute()
        )

        items = response.data or []
        return [
            {
                "id": p["id"],
                "name": p.get("full_name") or p.get("username") or "TripBond User",
                "avatar_url": p.get("avatar_url"),
            }
            for p in items
        ]
    except Exception:
        logger.exception("Failed to list bonders")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve bonders",
        )


@router.get("/me/followers", response_model=List[dict])
async def get_my_followers(
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Return current user's followers as lightweight profile items."""
    user_id, _token = user_context
    try:
        db = SupabaseDB(admin=True)
        return await _get_connection_users(db, user_id, "followers")
    except Exception:
        logger.exception("Failed to get followers")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve followers",
        )


@router.get("/me/following", response_model=List[dict])
async def get_my_following(
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Return users followed by current user as lightweight profile items."""
    user_id, _token = user_context
    try:
        db = SupabaseDB(admin=True)
        return await _get_connection_users(db, user_id, "following")
    except Exception:
        logger.exception("Failed to get following")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve following",
        )


@router.get("/me/friends", response_model=List[dict])
async def get_my_friends(
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Return current user's accepted bonders/friends."""
    user_id, _token = user_context
    try:
        db = SupabaseDB(admin=True)
        outgoing = await run_in_threadpool(
            lambda: db.client.table("friends")
            .select("*")
            .eq("user_id", user_id)
            .eq("status", "accepted")
            .execute()
        )
        incoming = await run_in_threadpool(
            lambda: db.client.table("friends")
            .select("*")
            .eq("friend_id", user_id)
            .eq("status", "accepted")
            .execute()
        )

        rows = list(outgoing.data or []) + list(incoming.data or [])
        if not rows:
            return []

        friend_ids = [
            str(row["friend_id"] if str(row.get("user_id")) == user_id else row["user_id"])
            for row in rows
        ]
        profiles = await _resolve_profiles(db, friend_ids)

        friends: list[dict] = []
        seen: set[str] = set()
        for row in rows:
            friend_id = str(row["friend_id"] if str(row.get("user_id")) == user_id else row["user_id"])
            if friend_id in seen:
                continue
            profile = profiles.get(friend_id)
            if not profile:
                continue
            friends.append(_friend_item(profile, row))
            seen.add(friend_id)

        return friends
    except Exception:
        logger.exception("Failed to get friends")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve friends",
        )


@router.get("/me/bond-requests", response_model=List[dict])
async def get_my_bond_requests(
    direction: str = "incoming",
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Return pending bond requests for the current user."""
    user_id, _token = user_context
    if direction not in {"incoming", "outgoing"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="direction must be incoming or outgoing",
        )

    try:
        db = SupabaseDB(admin=True)
        if direction == "incoming":
            response = await run_in_threadpool(
                lambda: db.client.table("friends")
                .select("*")
                .eq("friend_id", user_id)
                .eq("status", "pending")
                .execute()
            )
            related_ids = [str(row.get("user_id")) for row in response.data or []]
        else:
            response = await run_in_threadpool(
                lambda: db.client.table("friends")
                .select("*")
                .eq("user_id", user_id)
                .eq("status", "pending")
                .execute()
            )
            related_ids = [str(row.get("friend_id")) for row in response.data or []]

        profiles = await _resolve_profiles(db, related_ids)
        requests: list[dict] = []
        for row in response.data or []:
            related_id = str(row.get("user_id") if direction == "incoming" else row.get("friend_id"))
            profile = profiles.get(related_id)
            if not profile:
                continue
            requests.append(
                {
                    "id": row.get("id"),
                    "user_id": related_id,
                    "name": _display_name(profile),
                    "avatar_url": profile.get("avatar_url"),
                    "status": row.get("status"),
                    "direction": direction,
                    "created_at": row.get("created_at"),
                }
            )

        return requests
    except Exception:
        logger.exception("Failed to get bond requests")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve bond requests",
        )


# ==================== Profile ====================

@router.get("/me", response_model=ProfileResponse)
async def get_my_profile(user_context: tuple[str, str] = Depends(get_current_user_context)):
    """Get the current authenticated user's full profile with stats."""
    user_id, token = user_context
    try:
        # Use admin client to fetch profile (no longer using RLS with Supabase Auth)
        db = SupabaseDB(admin=True)
        profile_response = await run_in_threadpool(
            lambda: db.client.table("profiles").select("*").eq("id", user_id).execute()
        )
        if not profile_response.data:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
        profile = profile_response.data[0]

        trips_response = await run_in_threadpool(
            lambda: db.client.table("trips").select("id", count="exact").eq("created_by", user_id).execute()
        )
        favorites_response = await run_in_threadpool(
            lambda: db.client.table("user_favorites").select("id", count="exact").eq("user_id", user_id).execute()
        )
        liked_trips_response = await run_in_threadpool(
            lambda: db.client.table("trip_post_likes").select("trip_id", count="exact").eq("user_id", user_id).execute()
        )
        return ProfileResponse(
            id=profile["id"],
            email=profile.get("email_address", ""),  # Updated to use email_address
            full_name=profile.get("full_name"),
            username=profile.get("username"),
            phone_number=profile.get("phone_number"),
            date_of_birth=profile.get("date_of_birth"),
            bio=profile.get("bio"),
            avatar_url=profile.get("avatar_url"),
            current_location=profile.get("current_location"),
            gender=profile.get("gender"),
            is_public=profile.get("is_public", True),
            past_trips_count=trips_response.count if trips_response else 0,
            liked_pages_count=liked_trips_response.count if liked_trips_response else 0,
            favorites_count=favorites_response.count if favorites_response else 0,
            followers_count=len(_parse_connection_ids(profile.get("followers"))),
            following_count=len(_parse_connection_ids(profile.get("following"))),
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to get profile")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to retrieve profile")


@router.get("/{user_id}/profile", response_model=ProfileResponse)
async def get_user_profile(user_id: str):
    """Get a user's public profile."""
    try:
        db = SupabaseDB(admin=True)
        profile_response = await run_in_threadpool(
            lambda: db.client.table("profiles").select(
                "id,full_name,username,avatar_url,bio,current_location,is_public,followers,following"
            ).eq("id", user_id).execute()
        )
        if not profile_response.data:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
        profile = profile_response.data[0]

        if not profile.get("is_public", True):
            return ProfileResponse(
                id=profile["id"],
                email="",
                full_name=profile.get("full_name"),
                username=profile.get("username"),
                avatar_url=profile.get("avatar_url"),
                is_public=False,
            )

        try:
            trips_response = await run_in_threadpool(
                lambda: db.client.table("trips").select("id", count="exact").eq("created_by", user_id).execute()
            )
        except Exception as e:
            logger.warning(f"Failed to get trips count for user {user_id}: {e}")
            trips_response = None
            
        try:
            favorites_response = await run_in_threadpool(
                lambda: db.client.table("user_favorites").select("id", count="exact").eq("user_id", user_id).execute()
            )
        except Exception as e:
            logger.warning(f"Failed to get favorites count for user {user_id}: {e}")
            favorites_response = None

        try:
            liked_trips_response = await run_in_threadpool(
                lambda: db.client.table("trip_post_likes").select("trip_id", count="exact").eq("user_id", user_id).execute()
            )
        except Exception as e:
            logger.warning(f"Failed to get liked trips count for user {user_id}: {e}")
            liked_trips_response = None
            
        return ProfileResponse(
            id=profile["id"],
            email="",
            full_name=profile.get("full_name"),
            username=profile.get("username"),
            bio=profile.get("bio"),
            avatar_url=profile.get("avatar_url"),
            current_location=profile.get("current_location"),
            is_public=profile.get("is_public", True),
            past_trips_count=trips_response.count if trips_response else 0,
            liked_pages_count=liked_trips_response.count if liked_trips_response else 0,
            favorites_count=favorites_response.count if favorites_response else 0,
            followers_count=len(_parse_connection_ids(profile.get("followers"))),
            following_count=len(_parse_connection_ids(profile.get("following"))),
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"Failed to get user profile for {user_id}: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to retrieve user profile: {str(e)}")


@router.get("/{user_id}/relationship")
async def get_user_relationship(
    user_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Return the current user's relationship state with another user."""
    current_user_id, _token = user_context
    if user_id == current_user_id:
        return {
            "is_self": True,
            "is_following": False,
            "is_follower": False,
            "is_friend": False,
            "bond_request_status": "self",
        }

    try:
        db = SupabaseDB(admin=True)
        current_profile = await run_in_threadpool(
            lambda: db.client.table("profiles")
            .select("followers,following")
            .eq("id", current_user_id)
            .limit(1)
            .execute()
        )
        if not current_profile.data:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Current user not found")

        profile = current_profile.data[0]
        following = _parse_connection_ids(profile.get("following"))
        followers = _parse_connection_ids(profile.get("followers"))

        rows = await _get_friend_rows_between(db, current_user_id, user_id)
        accepted = next((row for row in rows if row.get("status") == "accepted"), None)
        pending_sent = next(
            (
                row
                for row in rows
                if row.get("status") == "pending"
                and str(row.get("user_id")) == current_user_id
                and str(row.get("friend_id")) == user_id
            ),
            None,
        )
        pending_received = next(
            (
                row
                for row in rows
                if row.get("status") == "pending"
                and str(row.get("user_id")) == user_id
                and str(row.get("friend_id")) == current_user_id
            ),
            None,
        )

        bond_request_status = "none"
        if accepted:
            bond_request_status = "accepted"
        elif pending_sent:
            bond_request_status = "pending_sent"
        elif pending_received:
            bond_request_status = "pending_received"
        elif rows:
            bond_request_status = str(rows[0].get("status") or "none")

        return {
            "is_self": False,
            "is_following": user_id in following,
            "is_follower": user_id in followers,
            "is_friend": accepted is not None,
            "bond_request_status": bond_request_status,
            "friendship_id": (accepted or pending_sent or pending_received or (rows[0] if rows else {})).get("id"),
        }
    except HTTPException:
        raise
    except Exception:
        logger.exception("Failed to get user relationship")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve relationship",
        )


@router.put("/{user_id}/profile", response_model=ProfileResponse)
async def update_profile(
    user_id: str,
    profile_update: UpdateProfileRequest,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Update user profile. Users can only update their own profile."""
    current_user_id, token = user_context
    if user_id != current_user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You can only update your own profile")
    try:
        # Profile updates are authorized by the user-id check above.
        # Use the admin client here to avoid token/client mismatches while
        # still restricting the operation to the authenticated user's own row.
        client = SupabaseDB(admin=True).client
        update_data = {
            k: (v.isoformat() if hasattr(v, "isoformat") else v)
            for k, v in profile_update.model_dump().items()
            if v is not None
        }

        gender_value = update_data.get("gender")
        if isinstance(gender_value, str):
            normalized_gender = gender_value.strip().lower()
            if normalized_gender in {"male", "female"}:
                update_data["gender"] = normalized_gender

        if not update_data:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No update data provided")

        response = await run_in_threadpool(
            lambda: client.table("profiles").update(update_data).eq("id", user_id).execute()
        )
        if not response.data:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")

        db = SupabaseDB(admin=True)
        trips_response = await run_in_threadpool(
            lambda: db.client.table("trips").select("id", count="exact").eq("created_by", user_id).execute()
        )
        favorites_response = await run_in_threadpool(
            lambda: db.client.table("user_favorites").select("id", count="exact").eq("user_id", user_id).execute()
        )
        liked_trips_response = await run_in_threadpool(
            lambda: db.client.table("trip_post_likes").select("trip_id", count="exact").eq("user_id", user_id).execute()
        )
        p = response.data[0]
        return ProfileResponse(
            id=p["id"],
            email=p.get("email", ""),
            full_name=p.get("full_name"),
            username=p.get("username"),
            phone_number=p.get("phone_number"),
            date_of_birth=p.get("date_of_birth"),
            bio=p.get("bio"),
            avatar_url=p.get("avatar_url"),
            current_location=p.get("current_location"),
            gender=p.get("gender"),
            is_public=p.get("is_public", True),
            past_trips_count=trips_response.count if trips_response else 0,
            liked_pages_count=liked_trips_response.count if liked_trips_response else 0,
            favorites_count=favorites_response.count if favorites_response else 0,
            followers_count=len(_parse_connection_ids(p.get("followers"))),
            following_count=len(_parse_connection_ids(p.get("following"))),
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to update profile")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to update profile")


@router.delete("/{user_id}")
async def delete_account(
    user_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Permanently delete a user account."""
    current_user_id, token = user_context
    if user_id != current_user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You can only delete your own account")
    try:
        client = get_supabase_client_for_user(token)
        await run_in_threadpool(lambda: client.table("profiles").delete().eq("id", user_id).execute())
        try:
            db = SupabaseDB(admin=True)
            await run_in_threadpool(lambda: db.client.auth.admin.delete_user(user_id))
        except Exception:
            logger.exception("Failed to delete auth user (non-critical)")
        return {"message": "Account deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to delete account")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to delete account")


# ==================== Follow/Unfollow ====================

@router.post("/{user_id}/follow")
async def follow_user(
    user_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Follow a user."""
    current_user_id, _token = user_context
    if user_id == current_user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="You cannot follow yourself")
    
    try:
        db = SupabaseDB(admin=True)
        
        # Get current user's following list
        current_profile = await run_in_threadpool(
            lambda: db.client.table("profiles").select("following").eq("id", current_user_id).execute()
        )
        if not current_profile.data:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Current user not found")
        
        following_list = _parse_connection_ids(current_profile.data[0].get("following"))
        
        # Check if already following
        if user_id in following_list:
            return {"message": "Already following this user"}
        
        # Add to following list
        following_list.append(user_id)
        
        # Get target user's followers list
        target_profile = await run_in_threadpool(
            lambda: db.client.table("profiles").select("followers").eq("id", user_id).execute()
        )
        if not target_profile.data:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Target user not found")
        
        followers_list = _parse_connection_ids(target_profile.data[0].get("followers"))
        
        # Add current user to target followers list
        if current_user_id not in followers_list:
            followers_list.append(current_user_id)
        
        # Update both profiles
        await run_in_threadpool(
            lambda: db.client.table("profiles").update({"following": following_list}).eq("id", current_user_id).execute()
        )
        await run_in_threadpool(
            lambda: db.client.table("profiles").update({"followers": followers_list}).eq("id", user_id).execute()
        )
        
        return {"message": "Successfully followed user"}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to follow user")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to follow user")


@router.delete("/{user_id}/follow")
async def unfollow_user(
    user_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Unfollow a user."""
    current_user_id, _token = user_context
    if user_id == current_user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="You cannot unfollow yourself")
    
    try:
        db = SupabaseDB(admin=True)
        
        # Get current user's following list
        current_profile = await run_in_threadpool(
            lambda: db.client.table("profiles").select("following").eq("id", current_user_id).execute()
        )
        if not current_profile.data:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Current user not found")
        
        following_list = _parse_connection_ids(current_profile.data[0].get("following"))
        
        # Check if actually following
        if user_id not in following_list:
            return {"message": "Not following this user"}
        
        # Remove from following list
        following_list.remove(user_id)
        
        # Get target user's followers list
        target_profile = await run_in_threadpool(
            lambda: db.client.table("profiles").select("followers").eq("id", user_id).execute()
        )
        if not target_profile.data:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Target user not found")
        
        followers_list = _parse_connection_ids(target_profile.data[0].get("followers"))
        
        # Remove current user from target followers list
        if current_user_id in followers_list:
            followers_list.remove(current_user_id)
        
        # Update both profiles
        await run_in_threadpool(
            lambda: db.client.table("profiles").update({"following": following_list}).eq("id", current_user_id).execute()
        )
        await run_in_threadpool(
            lambda: db.client.table("profiles").update({"followers": followers_list}).eq("id", user_id).execute()
        )
        
        return {"message": "Successfully unfollowed user"}
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to unfollow user")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to unfollow user")


# ==================== Bond Requests ====================

@router.post("/{user_id}/bond-request")
async def send_bond_request(
    user_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Send a bond request to another user."""
    current_user_id, _token = user_context
    if user_id == current_user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="You cannot bond with yourself")
    
    try:
        db = SupabaseDB(admin=True)
        target_profile = await _get_public_profile(db, user_id)
        if not target_profile:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
        if target_profile.get("is_public", True) is False:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="This user is not available for bonding")

        current_profile = await _get_public_profile(db, current_user_id)
        current_name = _display_name(current_profile)

        existing_rows = await _get_friend_rows_between(db, current_user_id, user_id)
        accepted = next((row for row in existing_rows if row.get("status") == "accepted"), None)
        if accepted:
            return {"message": "You are already friends", "status": "accepted", "friendship_id": accepted.get("id")}

        blocked = next((row for row in existing_rows if row.get("status") == "blocked"), None)
        if blocked:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Bond request is not allowed")

        incoming_pending = next(
            (
                row
                for row in existing_rows
                if row.get("status") == "pending"
                and str(row.get("user_id")) == user_id
                and str(row.get("friend_id")) == current_user_id
            ),
            None,
        )
        if incoming_pending:
            response = await run_in_threadpool(
                lambda: db.client.table("friends")
                .update({"status": "accepted"})
                .eq("id", incoming_pending["id"])
                .execute()
            )
            notification_service.emit(
                user_id=user_id,
                notif_type="bond_request_accepted",
                title="Bond request accepted",
                body=f"{current_name} accepted your bond request.",
                payload={"user_id": current_user_id, "friendship_id": incoming_pending.get("id")},
            )
            return {
                "message": "Bond request accepted",
                "status": "accepted",
                "friendship_id": response.data[0].get("id") if response.data else incoming_pending.get("id"),
            }

        outgoing_pending = next(
            (
                row
                for row in existing_rows
                if row.get("status") == "pending"
                and str(row.get("user_id")) == current_user_id
                and str(row.get("friend_id")) == user_id
            ),
            None,
        )
        if outgoing_pending:
            return {
                "message": "Bond request already pending",
                "status": "pending",
                "friendship_id": outgoing_pending.get("id"),
            }

        for row in existing_rows:
            if row.get("status") == "rejected":
                await run_in_threadpool(
                    lambda row_id=row["id"]: db.client.table("friends").delete().eq("id", row_id).execute()
                )

        response = await run_in_threadpool(
            lambda: db.client.table("friends")
            .insert(
                {
                    "user_id": current_user_id,
                    "friend_id": user_id,
                    "status": "pending",
                }
            )
            .execute()
        )
        if not response.data:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to send bond request")

        row = response.data[0]
        notification_service.emit(
            user_id=user_id,
            notif_type="bond_request",
            title="New bond request",
            body=f"{current_name} wants to bond with you.",
            payload={"user_id": current_user_id, "friendship_id": row.get("id")},
        )

        return {
            "message": "Bond request sent successfully",
            "status": "pending",
            "friendship_id": row.get("id"),
            "recipient_id": user_id,
            "requester_id": current_user_id,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to send bond request")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to send bond request")


@router.delete("/{user_id}/bond-request")
async def cancel_bond_request(
    user_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Cancel a bond request sent to another user."""
    current_user_id, _token = user_context
    if user_id == current_user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid bond request cancellation")
    
    try:
        db = SupabaseDB(admin=True)
        existing_rows = await _get_friend_rows_between(db, current_user_id, user_id)
        outgoing_pending = next(
            (
                row
                for row in existing_rows
                if row.get("status") == "pending"
                and str(row.get("user_id")) == current_user_id
                and str(row.get("friend_id")) == user_id
            ),
            None,
        )
        if not outgoing_pending:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pending bond request not found")

        await run_in_threadpool(
            lambda: db.client.table("friends").delete().eq("id", outgoing_pending["id"]).execute()
        )

        return {
            "message": "Bond request cancelled successfully",
            "recipient_id": user_id,
            "requester_id": current_user_id,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to cancel bond request")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to cancel bond request")


@router.post("/{user_id}/bond-request/accept")
async def accept_bond_request(
    user_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Accept a pending bond request from user_id."""
    current_user_id, _token = user_context
    if user_id == current_user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid bond request")

    try:
        db = SupabaseDB(admin=True)
        rows = await _get_friend_rows_between(db, current_user_id, user_id)
        request_row = next(
            (
                row
                for row in rows
                if row.get("status") == "pending"
                and str(row.get("user_id")) == user_id
                and str(row.get("friend_id")) == current_user_id
            ),
            None,
        )
        if not request_row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pending bond request not found")

        response = await run_in_threadpool(
            lambda: db.client.table("friends")
            .update({"status": "accepted"})
            .eq("id", request_row["id"])
            .execute()
        )
        if not response.data:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to accept bond request")

        current_profile = await _get_public_profile(db, current_user_id)
        notification_service.emit(
            user_id=user_id,
            notif_type="bond_request_accepted",
            title="Bond request accepted",
            body=f"{_display_name(current_profile)} accepted your bond request.",
            payload={"user_id": current_user_id, "friendship_id": request_row.get("id")},
        )
        return {"message": "Bond request accepted", "status": "accepted", "friendship_id": request_row.get("id")}
    except HTTPException:
        raise
    except Exception:
        logger.exception("Failed to accept bond request")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to accept bond request")


@router.post("/{user_id}/bond-request/reject")
async def reject_bond_request(
    user_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Reject a pending bond request from user_id."""
    current_user_id, _token = user_context
    if user_id == current_user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid bond request")

    try:
        db = SupabaseDB(admin=True)
        rows = await _get_friend_rows_between(db, current_user_id, user_id)
        request_row = next(
            (
                row
                for row in rows
                if row.get("status") == "pending"
                and str(row.get("user_id")) == user_id
                and str(row.get("friend_id")) == current_user_id
            ),
            None,
        )
        if not request_row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pending bond request not found")

        response = await run_in_threadpool(
            lambda: db.client.table("friends")
            .update({"status": "rejected"})
            .eq("id", request_row["id"])
            .execute()
        )
        if not response.data:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to reject bond request")

        current_profile = await _get_public_profile(db, current_user_id)
        notification_service.emit(
            user_id=user_id,
            notif_type="bond_request_rejected",
            title="Bond request declined",
            body=f"{_display_name(current_profile)} declined your bond request.",
            payload={"user_id": current_user_id, "friendship_id": request_row.get("id")},
        )
        return {"message": "Bond request rejected", "status": "rejected", "friendship_id": request_row.get("id")}
    except HTTPException:
        raise
    except Exception:
        logger.exception("Failed to reject bond request")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to reject bond request")


# ==================== Settings ====================

@router.get("/{user_id}/settings", response_model=UserSettingsResponse)
async def get_user_settings(
    user_id: str,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Get user app settings."""
    current_user_id, _token = user_context
    if user_id != current_user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You can only view your own settings")
    try:
        db = SupabaseDB(admin=True)
        resp = await run_in_threadpool(
            lambda: db.client.table("user_settings").select("*").eq("user_id", user_id).execute()
        )
        if resp.data:
            s = resp.data[0]
            return UserSettingsResponse(
                user_id=s["user_id"],
                security_enabled=s.get("security_enabled", True),
                notifications_enabled=s.get("notifications_enabled", True),
                privacy_mode=s.get("privacy_mode", "public"),
            )
        return UserSettingsResponse(user_id=user_id, security_enabled=True, notifications_enabled=True, privacy_mode="public")
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to get settings")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to retrieve settings")


@router.put("/{user_id}/settings", response_model=UserSettingsResponse)
async def update_user_settings(
    user_id: str,
    settings_update: UpdateSettingsRequest,
    user_context: tuple[str, str] = Depends(get_current_user_context),
):
    """Update user app settings."""
    current_user_id, _token = user_context
    if user_id != current_user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You can only update your own settings")
    try:
        db = SupabaseDB(admin=True)
        update_data: dict = {"user_id": user_id}
        if settings_update.security_enabled is not None:
            update_data["security_enabled"] = settings_update.security_enabled
        if settings_update.notifications_enabled is not None:
            update_data["notifications_enabled"] = settings_update.notifications_enabled
        if settings_update.privacy_mode is not None:
            update_data["privacy_mode"] = settings_update.privacy_mode

        existing = await run_in_threadpool(
            lambda: db.client.table("user_settings").select("*").eq("user_id", user_id).execute()
        )
        if existing.data:
            response = await run_in_threadpool(
                lambda: db.client.table("user_settings").update(update_data).eq("user_id", user_id).execute()
            )
        else:
            response = await run_in_threadpool(
                lambda: db.client.table("user_settings").insert(update_data).execute()
            )

        if not response.data:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to update settings")
        s = response.data[0]
        return UserSettingsResponse(
            user_id=s["user_id"],
            security_enabled=s.get("security_enabled", True),
            notifications_enabled=s.get("notifications_enabled", True),
            privacy_mode=s.get("privacy_mode", "public"),
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Failed to update settings")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to update settings")
