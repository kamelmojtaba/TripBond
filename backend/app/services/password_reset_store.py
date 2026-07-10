"""
In-memory store for password reset codes.

Each entry: email -> {code, user_id, expires_at}
Codes expire after CODE_TTL_SECONDS (10 minutes).
"""

import secrets
import time
from typing import Optional, Dict, Any

_store: Dict[str, Dict[str, Any]] = {}

CODE_TTL_SECONDS = 600  # 10 minutes


def generate_code() -> str:
    """Generate a cryptographically random 6-digit code."""
    return str(secrets.randbelow(1000000)).zfill(6)


def store_code(email: str, code: str, user_id: str) -> None:
    """Store a password reset code for an email address."""
    _store[email.lower()] = {
        "code": code,
        "user_id": user_id,
        "expires_at": time.time() + CODE_TTL_SECONDS,
    }


def get_entry(email: str) -> Optional[Dict[str, Any]]:
    """Return the stored entry if it exists and hasn't expired, else None."""
    entry = _store.get(email.lower())
    if not entry:
        return None
    if time.time() > entry["expires_at"]:
        _store.pop(email.lower(), None)
        return None
    return entry


def verify(email: str, code: str) -> bool:
    """Check whether the provided code is valid for the email."""
    entry = get_entry(email)
    if not entry:
        return False
    return entry["code"] == code


def verify_and_consume(email: str, code: str) -> Optional[str]:
    """
    Check the code for email.
    Returns user_id on success and removes the entry; returns None if invalid.
    """
    entry = get_entry(email)
    if not entry:
        return None
    if entry["code"] != code:
        return None
    _store.pop(email.lower(), None)
    return entry["user_id"]


def delete_code(email: str) -> None:
    """Remove the reset entry for an email."""
    _store.pop(email.lower(), None)
