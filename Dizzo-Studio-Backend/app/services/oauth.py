import logging
import time
from typing import Any

import httpx
import jwt

from app.core.config import get_settings

logger = logging.getLogger(__name__)


async def verify_google_id_token(id_token: str | None = None, access_token: str | None = None) -> dict[str, Any] | None:
    audiences = get_settings().google_audiences
    if not audiences:
        return None
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            if id_token:
                response = await client.get("https://oauth2.googleapis.com/tokeninfo", params={"id_token": id_token})
                if response.status_code != 200:
                    return None
                data = response.json()
                if data.get("aud") not in audiences or data.get("iss") not in {
                    "accounts.google.com",
                    "https://accounts.google.com",
                }:
                    return None
                return data
            elif access_token:
                # 1. Verify that token was issued for our client_id
                token_resp = await client.get("https://oauth2.googleapis.com/tokeninfo", params={"access_token": access_token})
                if token_resp.status_code != 200:
                    return None
                token_data = token_resp.json()
                if token_data.get("aud") not in audiences:
                    return None

                # 2. Retrieve user profile info (name, email, picture)
                userinfo_resp = await client.get(
                    "https://www.googleapis.com/oauth2/v3/userinfo",
                    headers={"Authorization": f"Bearer {access_token}"},
                )
                if userinfo_resp.status_code != 200:
                    return None
                user_data = userinfo_resp.json()
                user_data.update(token_data)
                return user_data
        return None
    except (httpx.HTTPError, ValueError):
        return None


# Telegram's newer OIDC login (oauth.telegram.org/js/telegram-login.js —
# popup + postMessage, distinct from the classic embeddable widget's
# HMAC-signed payload) hands back a real signed JWT instead. It's a
# standards-compliant OIDC provider, so this verifies it the same way any
# OIDC id_token is verified: the signing key by `kid` from Telegram's JWKS,
# then signature, audience (our client id) and issuer.
#
# The JWKS is fetched with httpx, not PyJWKClient: Telegram gzips that
# response even when asked for `identity`, and PyJWKClient's bare urllib
# fetch can't decode it. The set is kept for an hour; a token signed with a
# key not in it (Telegram rotated its keys) fetches the set anew, at most
# once a minute.
_TELEGRAM_JWKS_URL = "https://oauth.telegram.org/.well-known/jwks.json"
_TELEGRAM_JWKS_TTL_S = 3600
_TELEGRAM_JWKS_REFETCH_S = 60
_telegram_jwks: tuple[float, jwt.PyJWKSet] | None = None


async def _fetch_telegram_jwks() -> jwt.PyJWKSet:
    global _telegram_jwks
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.get(_TELEGRAM_JWKS_URL)
        response.raise_for_status()
    _telegram_jwks = (time.monotonic(), jwt.PyJWKSet.from_dict(response.json()))
    return _telegram_jwks[1]


async def _telegram_signing_key(id_token: str) -> jwt.PyJWK:
    kid = jwt.get_unverified_header(id_token).get("kid")
    cached = _telegram_jwks
    if cached is None or time.monotonic() - cached[0] >= _TELEGRAM_JWKS_TTL_S:
        return (await _fetch_telegram_jwks())[kid]
    keys = cached[1]
    if not any(k.key_id == kid for k in keys.keys) and time.monotonic() - cached[0] >= _TELEGRAM_JWKS_REFETCH_S:
        keys = await _fetch_telegram_jwks()
    return keys[kid]


async def verify_telegram_oidc_token(id_token: str) -> dict[str, Any] | None:
    settings = get_settings()
    # BotFather's Web Login/OIDC setup issues its own Client ID, distinct
    # from the bot's numeric id (the part before ":" in the bot token) —
    # that's what telegram-login.js sends as client_id and what Telegram
    # signs the JWT's `aud` claim with, not effective_bot_token's id.
    client_id = settings.telegram_oidc_client_id
    if not client_id:
        return None
    try:
        signing_key = await _telegram_signing_key(id_token)
        return jwt.decode(
            id_token,
            signing_key.key,
            algorithms=["RS256", "ES256", "EdDSA", "ES256K"],
            audience=client_id,
            issuer="https://oauth.telegram.org",
        )
    except Exception as exc:
        # A failed JWKS fetch, unknown key or malformed token shouldn't 500,
        # just fail this login attempt. Logs only the unverified aud/iss/exp,
        # so a mismatch is visible without the phone number, name or token.
        try:
            unverified = jwt.decode(id_token, options={"verify_signature": False})
            seen = {key: unverified.get(key) for key in ("aud", "iss", "exp")}
        except Exception:
            seen = None
        logger.warning(
            "telegram oidc verify failed: %s expected_aud=%s unverified=%s", type(exc).__name__, client_id, seen
        )
        return None
