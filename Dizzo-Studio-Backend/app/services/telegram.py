import hashlib
import hmac
import json
import time
from urllib.parse import parse_qsl


def _data_check_hash(data: dict[str, str], received_hash: str, secret: bytes) -> bool:
    if not received_hash:
        return False
    check_string = "\n".join(f"{key}={value}" for key, value in sorted(data.items()))
    expected = hmac.new(secret, check_string.encode(), hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, received_hash)


def _webapp_secret(bot_token: str) -> bytes:
    # Mini App (initData) verification key, per Telegram's WebApp docs.
    return hmac.new(b"WebAppData", bot_token.encode(), hashlib.sha256).digest()


def _login_widget_secret(bot_token: str) -> bytes:
    # Login Widget verification key is a *plain* SHA-256 of the bot token —
    # a different formula from the WebApp one above (no "WebAppData" HMAC
    # step). Using the WebApp secret here made every widget hash mismatch
    # and login fail with 401 regardless of a valid Telegram payload.
    return hashlib.sha256(bot_token.encode()).digest()


# A signed payload may be replayed: it's only accepted for a day after
# Telegram signed it, and never without its date.
FUTURE_SKEW_SECONDS = 300


def _fresh(auth_date: object, max_age: int) -> bool:
    try:
        signed_at = int(str(auth_date))
    except (TypeError, ValueError):
        return False
    age = time.time() - signed_at
    return signed_at > 0 and -FUTURE_SKEW_SECONDS <= age <= max_age


def validate_webapp_init_data(init_data: str, bot_token: str, max_age: int = 86400) -> dict | None:
    if not bot_token:
        return None
    try:
        pairs = dict(parse_qsl(init_data, keep_blank_values=True))
        received_hash = pairs.pop("hash", "")
        if not _fresh(pairs.get("auth_date"), max_age):
            return None
        if not _data_check_hash(pairs, received_hash, _webapp_secret(bot_token)):
            return None
        user = json.loads(pairs.get("user", "{}"))
        return user if isinstance(user, dict) and user.get("id") else None
    except (ValueError, TypeError, json.JSONDecodeError):
        return None


def validate_login_widget(payload: dict, bot_token: str, max_age: int = 86400) -> dict | None:
    if not bot_token:
        return None
    data = {str(k): str(v) for k, v in payload.items() if k != "hash" and v is not None}
    if not _fresh(data.get("auth_date"), max_age):
        return None
    received_hash = str(payload.get("hash", ""))
    if not _data_check_hash(data, received_hash, _login_widget_secret(bot_token)):
        return None
    return payload if payload.get("id") else None
