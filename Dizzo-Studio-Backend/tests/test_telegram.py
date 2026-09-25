import hashlib
import hmac
import json
import time
from urllib.parse import urlencode

from app.services.telegram import validate_login_widget, validate_webapp_init_data

BOT_TOKEN = "123456:local-test-token"


def _sign(values: dict[str, str], secret: bytes) -> str:
    check_string = "\n".join(f"{key}={value}" for key, value in sorted(values.items()))
    return hmac.new(secret, check_string.encode(), hashlib.sha256).hexdigest()


# Two distinct Telegram signing formulas — mixing them up is exactly the bug
# this test suite needs to catch: a widget-signed payload verified with the
# WebApp secret (or vice versa) always fails, regardless of validity.
def _sign_login_widget(values: dict[str, str]) -> str:
    return _sign(values, hashlib.sha256(BOT_TOKEN.encode()).digest())


def _sign_webapp(values: dict[str, str]) -> str:
    secret = hmac.new(b"WebAppData", BOT_TOKEN.encode(), hashlib.sha256).digest()
    return _sign(values, secret)


def test_login_widget_signature_is_verified() -> None:
    payload = {"id": "123", "first_name": "Ali", "username": "ali", "auth_date": str(int(time.time()))}
    payload["hash"] = _sign_login_widget(payload)
    assert validate_login_widget(payload, BOT_TOKEN) == payload
    assert validate_login_widget({**payload, "first_name": "Evil"}, BOT_TOKEN) is None


def test_webapp_init_data_signature_is_verified() -> None:
    user = json.dumps({"id": 123, "first_name": "Ali"}, separators=(",", ":"))
    values = {"auth_date": str(int(time.time())), "user": user}
    values["hash"] = _sign_webapp(values)
    assert validate_webapp_init_data(urlencode(values), BOT_TOKEN) == {"id": 123, "first_name": "Ali"}


def test_expired_telegram_payload_is_rejected() -> None:
    payload = {"id": "123", "auth_date": str(int(time.time()) - 90_000)}
    payload["hash"] = _sign_login_widget(payload)
    assert validate_login_widget(payload, BOT_TOKEN) is None
