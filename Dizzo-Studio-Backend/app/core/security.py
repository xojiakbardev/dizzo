import secrets
from datetime import UTC, datetime, timedelta
from typing import Any

import bcrypt
import jwt

from app.core.config import get_settings


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode(), password_hash.encode())
    except (ValueError, TypeError):
        return False


def normalize_email(email: str | None) -> str | None:
    """Emails are stored and looked up lowercased, trimmed; "" is no email."""
    if email is None:
        return None
    return email.strip().lower() or None


# Every token carries the user's token_version ("tv"): bumping the column
# (logout, password change, deactivation, role change) invalidates every
# token issued before. Refresh tokens also carry a jti naming their row in
# refresh_sessions, which is spent on use (rotation). Tokens issued before
# this existed have neither claim and count as version 0.
def create_token(user_id: int, token_type: str, expires: timedelta, **claims: Any) -> str:
    now = datetime.now(UTC)
    payload: dict[str, Any] = {"sub": str(user_id), "type": token_type, "iat": now, "exp": now + expires, **claims}
    return jwt.encode(payload, get_settings().jwt_secret_key, algorithm=get_settings().jwt_algorithm)


def create_access_token(user_id: int, token_version: int = 0) -> str:
    return create_token(
        user_id, "access", timedelta(minutes=get_settings().access_token_minutes), tv=token_version
    )


def create_refresh_token(user_id: int, token_version: int = 0, jti: str | None = None) -> str:
    return create_token(
        user_id,
        "refresh",
        timedelta(days=get_settings().refresh_token_days),
        tv=token_version,
        jti=jti or new_jti(),
    )


def new_jti() -> str:
    return secrets.token_urlsafe(24)


def decode_claims(token: str, expected_type: str = "access") -> dict[str, Any] | None:
    """The verified claims with `sub` as int and `tv` defaulted, or None."""
    try:
        payload = jwt.decode(token, get_settings().jwt_secret_key, algorithms=[get_settings().jwt_algorithm])
        if payload.get("type") != expected_type:
            return None
        payload["sub"] = int(payload["sub"])
        payload["tv"] = int(payload.get("tv", 0))
        return payload
    except (jwt.PyJWTError, KeyError, TypeError, ValueError):
        return None


def decode_token(token: str, expected_type: str = "access") -> int | None:
    claims = decode_claims(token, expected_type)
    return claims["sub"] if claims else None
