import hashlib
import logging
from datetime import UTC, datetime, timedelta

from fastapi import HTTPException, Request, status
from sqlalchemy import delete, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.i18n import get_language
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_claims,
    hash_password,
    new_jti,
    normalize_email,
)
from app.models.user import RefreshSession, SocialConnection, User
from app.services.oauth import verify_google_id_token, verify_telegram_oidc_token
from app.services.telegram import validate_login_widget, validate_webapp_init_data


def user_payload(user: User) -> dict:
    return {
        "id": user.id,
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "full_name": user.full_name,
        "phone_number": user.phone_number,
        "avatar": user.avatar,
        "role": user.role,
        "is_staff": user.is_staff,
        "is_active": user.is_active,
        "is_super_admin": user.role == "super_admin",
        "branch_id": user.branch_id,
        "branch_name": user.branch.name if getattr(user, "branch", None) else None,
        "telegram_linked": user.telegram_id is not None,
        "telegram_linked_at": user.telegram_linked_at.isoformat() if user.telegram_linked_at else None,
        "language": user.language or "uz",
        "created_at": user.created_at.isoformat() if getattr(user, "created_at", None) else None,
        "updated_at": user.updated_at.isoformat() if getattr(user, "updated_at", None) else None,
    }


logger = logging.getLogger(__name__)

INVALID_REFRESH = "Refresh token yaroqsiz"
INACTIVE = "Hisob faol emas"


def _aware(moment: datetime) -> datetime:
    return moment if moment.tzinfo else moment.replace(tzinfo=UTC)


def _pair(user: User, jti: str) -> dict:
    return {
        "access_token": create_access_token(user.id, user.token_version),
        "refresh_token": create_refresh_token(user.id, user.token_version, jti),
        "token_type": "bearer",
        "user": user_payload(user),
    }


def _new_session(user: User, now: datetime) -> RefreshSession:
    return RefreshSession(
        jti=new_jti(),
        user_id=user.id,
        created_at=now,
        expires_at=now + timedelta(days=get_settings().refresh_token_days),
    )


async def tokens(session: AsyncSession, user: User) -> dict:
    """A new sign-in: a token pair backed by a fresh refresh session."""
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=INACTIVE)
    now = datetime.now(UTC)
    await session.execute(
        delete(RefreshSession).where(RefreshSession.user_id == user.id, RefreshSession.expires_at < now)
    )
    row = _new_session(user, now)
    session.add(row)
    await session.commit()
    return _pair(user, row.jti)


def _legacy_jti(token: str) -> str:
    """Refresh tokens from before rotation have no jti: they are tracked by
    their hash, so each still works exactly once."""
    return "legacy-" + hashlib.sha256(token.encode()).hexdigest()[:40]


async def revoke_all_tokens(session: AsyncSession, user: User) -> None:
    """Every access and refresh token of the user stops working (the caller commits)."""
    user.token_version = (user.token_version or 0) + 1
    await session.execute(delete(RefreshSession).where(RefreshSession.user_id == user.id))


async def rotate_refresh_token(session: AsyncSession, token: str) -> dict:
    """Spends a refresh token for a new pair. A token spent within the grace
    period (another tab refreshed at the same moment) gets the pair of the
    session that replaced it; spent any earlier, it was replayed, and every
    session of the user is revoked."""
    unauthorized = HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=INVALID_REFRESH)
    claims = decode_claims(token, "refresh") if token else None
    user = await session.get(User, claims["sub"]) if claims else None
    if user is None or not user.is_active or claims["tv"] != user.token_version:
        raise unauthorized
    now = datetime.now(UTC)
    jti = str(claims.get("jti") or _legacy_jti(token))
    row = await session.get(RefreshSession, jti)
    if row is None and "jti" not in claims:
        # Issued before rotation existed: recorded as a session on first use.
        session.add(RefreshSession(
            jti=jti, user_id=user.id, created_at=now, expires_at=datetime.fromtimestamp(claims["exp"], UTC)
        ))
        try:
            await session.flush()
        except IntegrityError:  # a concurrent request recorded it first
            await session.rollback()
            user = await session.get(User, claims["sub"])
        row = await session.get(RefreshSession, jti)
    if row is None or user is None or row.user_id != user.id:
        raise unauthorized

    if row.rotated_at is None:
        successor = _new_session(user, now)
        spent = await session.execute(
            update(RefreshSession)
            .where(RefreshSession.jti == jti, RefreshSession.rotated_at.is_(None))
            .values(rotated_at=now, replaced_by=successor.jti)
        )
        if spent.rowcount == 1:
            session.add(successor)
            await session.commit()
            return _pair(user, successor.jti)
        await session.refresh(row)  # lost the race to a concurrent refresh

    grace = timedelta(seconds=get_settings().refresh_reuse_grace_seconds)
    if row.replaced_by and row.rotated_at and now - _aware(row.rotated_at) <= grace:
        successor = await session.get(RefreshSession, row.replaced_by)
        if successor is not None:
            await session.commit()
            return _pair(user, successor.jti)
    logger.warning("refresh token replayed for user %s: revoking all sessions", user.id)
    await revoke_all_tokens(session, user)
    await session.commit()
    raise unauthorized


async def user_from_any_token(session: AsyncSession, access: str, refresh: str) -> User | None:
    """The user a still-valid access or refresh token belongs to (for logout)."""
    for token, kind in ((access, "access"), (refresh, "refresh")):
        claims = decode_claims(token, kind) if token else None
        if claims is None:
            continue
        user = await session.get(User, claims["sub"])
        if user is not None and claims["tv"] == user.token_version:
            return user
    return None


def _cookie_scope() -> dict:
    settings = get_settings()
    return {
        "domain": settings.cookie_domain or None,
        "path": "/",
        "secure": settings.cookie_secure,
        "samesite": settings.cookie_samesite,
    }


def apply_auth_cookies(response, pair: dict) -> None:
    settings = get_settings()
    scope = _cookie_scope()
    response.set_cookie(
        "access_token", pair["access_token"], max_age=settings.access_token_minutes * 60, httponly=True, **scope
    )
    response.set_cookie(
        "refresh_token", pair["refresh_token"], max_age=settings.refresh_token_days * 86400, httponly=True, **scope
    )
    response.set_cookie("dizzo_session", "1", max_age=settings.refresh_token_days * 86400, httponly=False, **scope)
    response.set_cookie("enjoy_session", "1", max_age=settings.refresh_token_days * 86400, httponly=False, **scope)


def clear_auth_cookies(response) -> None:
    scope = _cookie_scope()
    response.delete_cookie("access_token", httponly=True, **scope)
    response.delete_cookie("refresh_token", httponly=True, **scope)
    response.delete_cookie("dizzo_session", httponly=False, **scope)
    response.delete_cookie("enjoy_session", httponly=False, **scope)


async def get_or_create_social(
    session: AsyncSession,
    provider: str,
    provider_id: str,
    *,
    email: str | None = None,
    first_name: str = "",
    last_name: str = "",
    username: str = "",
    avatar: str | None = None,
    extra: dict | None = None,
    phone_number: str = "",
    email_verified: bool = False,
    language: str | None = None,
) -> User:
    """The user behind a social login, created on the first one. A phone the
    provider vouches for fills an empty profile phone, never replaces one.

    A new social login joins the account that has its email only when the
    provider says it verified that email; an unverified email is not stored
    at all, so nobody can take over someone else's address through it."""
    email = normalize_email(email)
    connection = (
        await session.execute(
            select(SocialConnection).where(
                SocialConnection.provider == provider, SocialConnection.provider_id == provider_id
            )
        )
    ).scalar_one_or_none()
    if connection:
        user = await session.get(User, connection.user_id)
        if user:
            if phone_number and not user.phone_number:
                user.phone_number = phone_number
                await session.commit()
                await session.refresh(user)
            return user
    user = None
    if email:
        user = (await session.execute(select(User).where(User.email == email))).scalar_one_or_none()
        if user is not None and not email_verified:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Bu email bilan hisob allaqachon bor. Email va parol bilan kiring.",
            )
        if not email_verified:
            email = None
    if user is None:
        # No password-login email yet — the user can add email+password later
        # from their profile (see set_credentials) to unlock email/password login.
        user = User(
            email=email,
            first_name=first_name,
            last_name=last_name,
            avatar=avatar,
            phone_number=phone_number,
            language=language or get_language(),
        )
        session.add(user)
        await session.flush()
    else:
        if avatar and not user.avatar:
            user.avatar = avatar
        if phone_number and not user.phone_number:
            user.phone_number = phone_number
    session.add(
        SocialConnection(
            user_id=user.id,
            provider=provider,
            provider_id=provider_id,
            provider_username=username,
            extra_data=extra or {},
        )
    )
    await session.commit()
    await session.refresh(user)
    return user


async def authenticate_google(
    session: AsyncSession, id_token: str | None = None, access_token: str | None = None
) -> User:
    data = await verify_google_id_token(id_token=id_token, access_token=access_token)
    if not data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Google token yaroqsiz yoki Google OAuth sozlanmagan"
        )
    return await get_or_create_social(
        session,
        "google",
        str(data["sub"]),
        email=data.get("email"),
        first_name=data.get("given_name", ""),
        last_name=data.get("family_name", ""),
        username=data.get("email", "").split("@")[0],
        avatar=data.get("picture"),
        extra=data,
        # tokeninfo sends "true"/"false" strings, userinfo booleans.
        email_verified=str(data.get("email_verified", "")).lower() == "true",
    )


async def authenticate_telegram_oidc(session: AsyncSession, id_token: str) -> User:
    """Verifies the JWT from Telegram's newer OIDC login (popup +
    postMessage via telegram-login.js) — a real signed id_token checked
    against Telegram's own JWKS, distinct from the classic embeddable
    widget's HMAC-signed payload (authenticate_telegram below)."""
    data = await verify_telegram_oidc_token(id_token)
    if not data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Telegram token yaroqsiz yoki bot sozlanmagan"
        )
    full_name = str(data.get("name", "")).strip()
    first_name, _, last_name = full_name.partition(" ")
    return await get_or_create_social(
        session,
        "telegram",
        str(data["sub"]),
        first_name=str(data.get("given_name") or first_name),
        last_name=str(data.get("family_name") or last_name),
        username=data.get("preferred_username", ""),
        avatar=data.get("picture"),
        extra=data,
        phone_number=telegram_phone(data),
    )


def telegram_phone(claims: dict) -> str:
    """The phone Telegram shares on login (the `phone` access the button asks
    for), as +digits — only when Telegram marks it verified."""
    digits = "".join(ch for ch in str(claims.get("phone_number") or "") if ch.isdigit())
    if not digits or claims.get("phone_number_verified") is False:
        return ""
    return f"+{digits}"


async def authenticate_telegram(session: AsyncSession, payload: dict) -> User:
    settings = get_settings()
    user_data = None
    if payload.get("init_data"):
        user_data = validate_webapp_init_data(payload["init_data"], settings.effective_bot_token)
    else:
        user_data = validate_login_widget(payload, settings.effective_bot_token)
    if not user_data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Telegram ma'lumotlari yaroqsiz yoki bot token sozlanmagan"
        )
    return await get_or_create_social(
        session,
        "telegram",
        str(user_data["id"]),
        first_name=user_data.get("first_name", ""),
        last_name=user_data.get("last_name", ""),
        username=user_data.get("username", ""),
        avatar=user_data.get("photo_url"),
        extra=user_data,
    )


def request_access_token(request: Request) -> str:
    """The access token from the cookie or the Authorization header, "" if neither is sent."""
    return request.cookies.get("access_token") or request.headers.get("authorization", "").removeprefix("Bearer ")


async def current_user(request: Request, session: AsyncSession) -> User:
    token = request_access_token(request)
    claims = decode_claims(token) if token else None
    user = await session.get(User, claims["sub"]) if claims else None
    if not user or not user.is_active or claims["tv"] != user.token_version:
        raise HTTPException(status_code=401, detail="Autentifikatsiya talab qilinadi")
    return user


async def set_credentials(session: AsyncSession, user: User, email: str, password: str) -> dict:
    """Let an OAuth-only user (no email/password yet) add email+password
    login. A new password signs every session out; the caller gets a fresh
    token pair.

    Only for an account that has no password: with one set, this would be a
    password change without the current password, so a stolen session could
    take the account over. A real change-password flow (current password
    required) is still to be written."""
    if user.password_hash is not None:
        raise HTTPException(status_code=409, detail="Hisobingizda parol allaqachon o'rnatilgan")
    email = normalize_email(email)
    taken = (await session.execute(select(User).where(User.email == email, User.id != user.id))).scalar_one_or_none()
    if taken:
        raise HTTPException(status_code=409, detail="Bu email allaqachon boshqa hisobda ishlatilgan")
    user.email = email
    user.password_hash = hash_password(password)
    await revoke_all_tokens(session, user)
    await session.commit()
    return await tokens(session, user)
