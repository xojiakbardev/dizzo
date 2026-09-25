import hmac

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import client_ip, get_current_user
from app.core import rate_limit
from app.core.config import get_settings
from app.core.i18n import get_language
from app.core.security import decode_claims, hash_password, normalize_email, verify_password
from app.db.session import get_db
from app.models.user import SocialConnection, TelegramAppLogin, TelegramLinkToken, User
from app.schemas.auth import (
    AuthResponse,
    BotLanguageRequest,
    BotUpsertRequest,
    GoogleLoginRequest,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    SetCredentialsRequest,
    TelegramAppLoginConfirmRequest,
    TelegramLoginRequest,
    TelegramOidcLoginRequest,
    UserOut,
)
from app.services.auth import (
    apply_auth_cookies,
    authenticate_google,
    authenticate_telegram,
    authenticate_telegram_oidc,
    clear_auth_cookies,
    get_or_create_social,
    request_access_token,
    revoke_all_tokens,
    rotate_refresh_token,
    set_credentials,
    tokens,
    user_from_any_token,
    user_payload,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def require_bot(request: Request) -> None:
    """Bot-only endpoints: the X-Bot-Token header must equal the bot token.
    An unset bot token never matches, so a missing header can't pass as ""."""
    expected = get_settings().effective_bot_token
    sent = request.headers.get("x-bot-token", "")
    if not expected or not hmac.compare_digest(sent.encode(), expected.encode()):
        raise HTTPException(status_code=403, detail="Ruxsat yo'q")


@router.get("/oauth/config/")
async def oauth_config() -> dict:
    settings = get_settings()
    # telegram-login.js's popup flow (oauth.telegram.org) authenticates
    # against BotFather's Web Login/OIDC Client ID — a distinct value from
    # the bot's own numeric id (the "<id>:<secret>" token prefix), set up
    # separately in BotFather's Web Login panel.
    return {
        "google": {"enabled": bool(settings.google_client_id), "client_id": settings.google_client_id},
        "telegram": {
            "enabled": bool(settings.telegram_oidc_client_id),
            "bot_username": settings.telegram_bot_username,
            "bot_id": settings.telegram_oidc_client_id,
        },
    }


@router.post("/register/", response_model=AuthResponse)
async def register(
    payload: RegisterRequest, request: Request, response: Response, session: AsyncSession = Depends(get_db)
):
    email = normalize_email(payload.email)
    rate_limit.check(request, "register", email)
    exists = (await session.execute(select(User).where(User.email == email))).scalar_one_or_none()
    if exists:
        raise HTTPException(status_code=409, detail="Bu email allaqachon ro'yxatdan o'tgan")
    user = User(
        email=email,
        first_name=payload.first_name,
        last_name=payload.last_name,
        phone_number=payload.phone_number,
        password_hash=hash_password(payload.password),
        language=get_language(),
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    pair = await tokens(session, user)
    apply_auth_cookies(response, pair)
    return pair


# Checked when the email is unknown, so a miss takes as long as a wrong
# password and response times don't reveal which emails exist.
_DUMMY_HASH = hash_password("timing-equaliser")


@router.post("/login/", response_model=AuthResponse)
async def login(payload: LoginRequest, request: Request, response: Response, session: AsyncSession = Depends(get_db)):
    email = normalize_email(payload.email)
    # Per account only failures count, so a stranger can't lock the owner out.
    rate_limit.check(request, "login", email, count_account=False)
    user = (await session.execute(select(User).where(User.email == email))).scalar_one_or_none()
    valid = verify_password(payload.password, user.password_hash if user and user.password_hash else _DUMMY_HASH)
    if not user or not user.password_hash or not valid:
        rate_limit.count_failure(request, "login", email)
        raise HTTPException(status_code=401, detail="Email yoki parol noto'g'ri")
    pair = await tokens(session, user)
    apply_auth_cookies(response, pair)
    return pair


async def _social_sign_in(request: Request, response: Response, session: AsyncSession, user: User) -> dict:
    rate_limit.check(request, "oauth", f"user:{user.id}", count_account=True)
    pair = await tokens(session, user)
    apply_auth_cookies(response, pair)
    return pair


@router.post("/oauth/google/", response_model=AuthResponse)
async def google_login(
    payload: GoogleLoginRequest, request: Request, response: Response, session: AsyncSession = Depends(get_db)
):
    rate_limit.check(request, "oauth")
    user = await authenticate_google(session, id_token=payload.id_token, access_token=payload.access_token)
    return await _social_sign_in(request, response, session, user)


@router.post("/oauth/telegram/", response_model=AuthResponse)
async def telegram_login(
    payload: TelegramLoginRequest, request: Request, response: Response, session: AsyncSession = Depends(get_db)
):
    rate_limit.check(request, "oauth")
    user = await authenticate_telegram(session, payload.model_dump(exclude_none=True))
    return await _social_sign_in(request, response, session, user)


@router.post("/oauth/telegram-oidc/", response_model=AuthResponse)
async def telegram_oidc_login(
    payload: TelegramOidcLoginRequest, request: Request, response: Response, session: AsyncSession = Depends(get_db)
):
    """Telegram's newer OIDC login (telegram-login.js popup + postMessage,
    hands back a real signed JWT) — distinct from /oauth/telegram/ above,
    which verifies the classic embeddable widget's HMAC-signed payload."""
    rate_limit.check(request, "oauth")
    user = await authenticate_telegram_oidc(session, payload.id_token)
    return await _social_sign_in(request, response, session, user)


@router.post("/telegram", response_model=AuthResponse)
async def telegram_webapp_login(
    payload: TelegramLoginRequest, request: Request, response: Response, session: AsyncSession = Depends(get_db)
):
    return await telegram_login(payload, request, response, session)


@router.post("/telegram/bot", response_model=UserOut)
async def telegram_bot_upsert(payload: BotUpsertRequest, request: Request, session: AsyncSession = Depends(get_db)):
    require_bot(request)
    user = await get_or_create_social(
        session,
        "telegram",
        str(payload.telegram_id),
        first_name=payload.first_name or "",
        last_name=payload.last_name or "",
        username=payload.username or "",
        avatar=payload.photo_url,
        language=payload.language,
    )
    return user_payload(user)


@router.post("/telegram/language/")
async def telegram_user_language(
    payload: BotLanguageRequest, request: Request, session: AsyncSession = Depends(get_db)
) -> dict:
    """The bot speaks to a chat in its account's language: the account the
    chat is linked to for order messages, else the one it signs in to.
    None when the chat has no account (the bot then goes by Telegram's)."""
    require_bot(request)
    language = await session.scalar(select(User.language).where(User.telegram_id == payload.telegram_id))
    if language is None:
        language = await session.scalar(
            select(User.language)
            .join(SocialConnection, SocialConnection.user_id == User.id)
            .where(SocialConnection.provider == "telegram", SocialConnection.provider_id == str(payload.telegram_id))
        )
    return {"language": language}


# Deep-link account linking, so any signed-in user gets order messages in
# Telegram (staff: new orders; customers: their own orders' status) without
# the bot ever seeing their password or session: the profile page requests
# a one-time token, opens t.me/<bot>?start=link_<token>, and the bot calls
# the endpoint below to consume it. Login is separate (SocialConnection):
# telegram_id is only the chat that order messages go to. The tap-to-bot-response round trip is near-instant, so 60
# seconds is plenty — and a leaked/screenshotted token is useless fast.
TELEGRAM_LINK_TOKEN_TTL_SECONDS = 60
STAFF_ROLES = ("super_admin", "admin", "production_admin", "production_manager")


@router.post("/telegram/link-token/")
async def create_telegram_link_token(
    session: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)
):
    import secrets

    settings = get_settings()
    token = secrets.token_urlsafe(16)
    session.add(TelegramLinkToken(token=token, user_id=user.id))
    await session.commit()
    bot_username = settings.telegram_bot_username.lstrip("@")
    return {
        "token": token,
        "deep_link": f"https://t.me/{bot_username}?start=link_{token}" if bot_username else None,
        "expires_in_seconds": TELEGRAM_LINK_TOKEN_TTL_SECONDS,
    }


@router.post("/telegram/link/")
async def consume_telegram_link_token(request: Request, session: AsyncSession = Depends(get_db)):
    """Called by the bot process (not the browser) — authenticated the same
    way as /telegram/bot above, via the shared bot token header."""
    from datetime import UTC, datetime, timedelta

    from fastapi import HTTPException

    require_bot(request)
    body = await request.json()
    raw_token = str(body.get("token") or "")
    telegram_id = body.get("telegram_id")
    if not raw_token or not telegram_id:
        raise HTTPException(status_code=422, detail="token va telegram_id kerak")

    import logging

    logger = logging.getLogger(__name__)

    link = (
        await session.execute(select(TelegramLinkToken).where(TelegramLinkToken.token == raw_token))
    ).scalar_one_or_none()
    if link is None:
        logger.warning("telegram link consume: unknown token")
        return {"ok": False, "reason": "invalid"}
    if link.used_at is not None:
        logger.warning("telegram link consume: token of user %s already used at %s", link.user_id, link.used_at)
        return {"ok": False, "reason": "invalid"}
    created_at = link.created_at if link.created_at.tzinfo else link.created_at.replace(tzinfo=UTC)
    age = datetime.now(UTC) - created_at
    if age > timedelta(seconds=TELEGRAM_LINK_TOKEN_TTL_SECONDS):
        logger.warning("telegram link consume: token of user %s expired (age=%s)", link.user_id, age)
        return {"ok": False, "reason": "expired"}

    target = await session.get(User, link.user_id)
    if target is None:
        return {"ok": False, "reason": "invalid"}

    # Re-linking a Telegram account that was previously linked to someone
    # else quietly steals it from them instead of erroring — simplest
    # behavior for staff reassignment/testing, and telegram_id stays unique.
    previous_holder = (
        await session.execute(select(User).where(User.telegram_id == telegram_id))
    ).scalar_one_or_none()
    if previous_holder is not None and previous_holder.id != target.id:
        previous_holder.telegram_id = None

    target.telegram_id = telegram_id
    target.telegram_linked_at = datetime.now(UTC)
    link.used_at = datetime.now(UTC)
    await session.commit()
    staff = target.is_staff or target.role in STAFF_ROLES
    return {"ok": True, "full_name": target.full_name, "staff": staff, "language": target.language}


# Telegram sign-in for the mobile app, which has no Telegram SDK: the app
# gets a code and opens t.me/<bot>?start=login_<token>, the bot confirms it
# for whoever pressed Start, and the app polls GET .../{token}/ and collects
# the token pair exactly once. A code lives for the TTL from its creation.
def _app_login_expired(login: TelegramAppLogin) -> bool:
    from datetime import UTC, datetime, timedelta

    created_at = login.created_at if login.created_at.tzinfo else login.created_at.replace(tzinfo=UTC)
    return datetime.now(UTC) - created_at > timedelta(seconds=get_settings().telegram_app_login_ttl_seconds)


@router.post("/telegram/app-login/")
async def create_telegram_app_login(request: Request, session: AsyncSession = Depends(get_db)):
    import secrets
    from datetime import UTC, datetime, timedelta

    settings = get_settings()
    bot_username = settings.telegram_bot_username.lstrip("@")
    if not bot_username:
        raise HTTPException(status_code=503, detail="Telegram bot sozlanmagan")
    ip = client_ip(request)
    since = datetime.now(UTC) - timedelta(hours=1)
    recent = await session.scalar(
        select(func.count())
        .select_from(TelegramAppLogin)
        .where(TelegramAppLogin.requester_ip == ip, TelegramAppLogin.created_at >= since)
    )
    if recent >= settings.telegram_app_logins_per_hour:
        raise HTTPException(status_code=429, detail="Juda ko'p urinish. Birozdan keyin qayta urinib ko'ring.")
    # 32 url-safe chars: fits Telegram's 64-char [A-Za-z0-9_-] start payload.
    token = secrets.token_urlsafe(24)
    session.add(TelegramAppLogin(token=token, requester_ip=ip))
    await session.commit()
    return {
        "token": token,
        "deep_link": f"https://t.me/{bot_username}?start=login_{token}",
        "expires_in_seconds": settings.telegram_app_login_ttl_seconds,
    }


@router.post("/telegram/app-login/confirm/")
async def confirm_telegram_app_login(
    payload: TelegramAppLoginConfirmRequest, request: Request, session: AsyncSession = Depends(get_db)
):
    """Called by the bot only once the Telegram user presses "Tasdiqlash"
    under the /start login_<token> warning — never on /start itself, so a
    link someone else sent can't sign them in unnoticed."""
    from datetime import UTC, datetime

    require_bot(request)
    login = (
        await session.execute(select(TelegramAppLogin).where(TelegramAppLogin.token == payload.token))
    ).scalar_one_or_none()
    if login is None or login.confirmed_at is not None or login.cancelled_at is not None:
        return {"ok": False, "reason": "invalid"}
    if _app_login_expired(login):
        return {"ok": False, "reason": "expired"}

    user = await get_or_create_social(
        session,
        "telegram",
        str(payload.telegram_id),
        first_name=payload.first_name or "",
        last_name=payload.last_name or "",
        username=payload.username or "",
        avatar=payload.photo_url,
        language=payload.language,
    )
    if not user.is_active:
        return {"ok": False, "reason": "inactive"}
    # This chat also gets the account's order messages, unless the account
    # already has one or the chat is linked to another account.
    if user.telegram_id is None:
        holder = await session.scalar(select(User.id).where(User.telegram_id == payload.telegram_id))
        if holder is None:
            user.telegram_id = payload.telegram_id
            user.telegram_linked_at = datetime.now(UTC)
    login.user_id = user.id
    login.confirmed_at = datetime.now(UTC)
    await session.commit()
    return {"ok": True, "full_name": user.full_name, "language": user.language}


@router.post("/telegram/app-login/cancel/")
async def cancel_telegram_app_login(request: Request, session: AsyncSession = Depends(get_db)):
    """Called by the bot on "Bekor qilish": the code is dead, the app's poll gets 410."""
    from datetime import UTC, datetime

    require_bot(request)
    body = await request.json()
    login = (
        await session.execute(select(TelegramAppLogin).where(TelegramAppLogin.token == str(body.get("token") or "")))
    ).scalar_one_or_none()
    if login is None or login.confirmed_at is not None or login.cancelled_at is not None:
        return {"ok": False, "reason": "invalid"}
    if _app_login_expired(login):
        return {"ok": False, "reason": "expired"}
    login.cancelled_at = datetime.now(UTC)
    await session.commit()
    return {"ok": True}


@router.get("/telegram/app-login/{token}/")
async def poll_telegram_app_login(token: str, session: AsyncSession = Depends(get_db)):
    from datetime import UTC, datetime

    gone = HTTPException(status_code=410, detail="Kirish havolasi muddati o'tgan")
    login = (
        await session.execute(select(TelegramAppLogin).where(TelegramAppLogin.token == token))
    ).scalar_one_or_none()
    if login is None or login.used_at or login.cancelled_at or _app_login_expired(login):
        raise gone
    if login.confirmed_at is None or login.user_id is None:
        return {"status": "pending"}
    # Spent with a conditional update, so two concurrent polls can't both collect.
    spent = await session.execute(
        update(TelegramAppLogin)
        .where(TelegramAppLogin.id == login.id, TelegramAppLogin.used_at.is_(None))
        .values(used_at=datetime.now(UTC))
    )
    await session.commit()
    user = await session.get(User, login.user_id)
    if spent.rowcount != 1 or user is None or not user.is_active:
        raise gone
    return {"status": "done", **(await tokens(session, user))}


@router.post("/token/refresh/", response_model=dict)
async def refresh(
    payload: RefreshRequest, request: Request, response: Response, session: AsyncSession = Depends(get_db)
):
    """Spends the refresh token for a new pair (rotation): the client must
    keep the refresh token it gets back — the one it sent stops working."""
    token = payload.refresh_token or request.cookies.get("refresh_token") or ""
    claims = decode_claims(token, "refresh") if token else None
    rate_limit.check(request, "refresh", f"user:{claims['sub']}" if claims else None)
    pair = await rotate_refresh_token(session, token)
    apply_auth_cookies(response, pair)
    return {"access": pair["access_token"], "refresh": pair["refresh_token"], **pair}


@router.post("/logout/")
async def logout(
    request: Request,
    response: Response,
    payload: RefreshRequest | None = None,
    session: AsyncSession = Depends(get_db),
):
    """Signs the account out everywhere: every access and refresh token
    issued to it so far stops working. The app sends {"refresh_token"}; the
    web sends its cookies."""
    user = await user_from_any_token(
        session,
        request_access_token(request),
        (payload.refresh_token if payload else None) or request.cookies.get("refresh_token") or "",
    )
    if user is not None:
        await revoke_all_tokens(session, user)
        await session.commit()
    clear_auth_cookies(response)
    return {"detail": "Logged out"}


@router.get("/me", response_model=UserOut)
async def auth_me(user: User = Depends(get_current_user)):
    return user_payload(user)


@router.post("/set-credentials/", response_model=UserOut)
async def set_credentials_route(
    payload: SetCredentialsRequest,
    request: Request,
    response: Response,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    """Lets an OAuth-only user (e.g. signed up via Google/Telegram, no email yet)
    add an email + password so they can also log in with email/password.
    Every other session is signed out; this one gets new cookies."""
    rate_limit.check(request, "password", f"user:{user.id}")
    pair = await set_credentials(session, user, payload.email, payload.password)
    apply_auth_cookies(response, pair)
    return pair["user"]
