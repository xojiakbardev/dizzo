import hashlib
import hmac
import time

import httpx
import pytest

from app.core.config import Settings
from app.services import auth as auth_service


@pytest.mark.asyncio
async def test_health_and_oauth_config(client: httpx.AsyncClient, configure_oauth: None) -> None:
    health = await client.get("/api/health/")
    config = await client.get("/api/auth/oauth/config/")

    assert health.status_code == 200
    assert health.json() == {"status": "ok"}
    assert config.json()["google"] == {"enabled": True, "client_id": "google-client-id"}
    assert config.json()["telegram"]["enabled"] is True


@pytest.mark.asyncio
async def test_register_cookie_and_current_user(client: httpx.AsyncClient) -> None:
    response = await client.post(
        "/api/auth/register/",
        json={
            "first_name": "Test",
            "last_name": "User",
            "phone_number": "+998901234567",
            "email": "integration@example.com",
            "password": "password123",
        },
    )

    assert response.status_code == 200
    assert "access_token" in response.cookies
    assert response.json()["user"]["full_name"] == "Test User"

    me = await client.get("/api/users/profile/me/")
    assert me.status_code == 200
    assert me.json()["email"] == "integration@example.com"


@pytest.mark.asyncio
async def test_register_with_a_bad_email_explains_it_in_uzbek(client: httpx.AsyncClient) -> None:
    response = await client.post(
        "/api/auth/register/", json={"first_name": "Test", "email": "not-an-email", "password": "password123"}
    )

    assert response.status_code == 422
    assert response.json()["detail"] == [
        {"loc": ["body", "email"], "msg": "noto'g'ri email manzil", "type": "value_error"}
    ]


@pytest.mark.asyncio
async def test_logout_deletes_cookies_with_the_domain_they_were_set_with(
    client: httpx.AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    settings = Settings(
        jwt_secret_key="test-secret-key-that-is-long-enough",
        cookie_domain=".dizzo.uz",
        cookie_secure=True,
        cookie_samesite="none",
    )
    monkeypatch.setattr(auth_service, "get_settings", lambda: settings)

    response = await client.post("/api/auth/logout/")

    deletions = response.headers.get_list("set-cookie")
    assert {header.split("=", 1)[0] for header in deletions} == {"access_token", "refresh_token", "dizzo_session", "enjoy_session"}
    for header in deletions:
        assert "Domain=.dizzo.uz" in header
        assert "Max-Age=0" in header
        assert "Secure" in header
        assert "SameSite=none" in header


@pytest.mark.asyncio
async def test_telegram_widget_login(client: httpx.AsyncClient, configure_oauth: None) -> None:
    payload = {
        "id": 987654,
        "first_name": "Telegram",
        "username": "telegram_test",
        "auth_date": int(time.time()),
    }
    values = {key: str(value) for key, value in payload.items()}
    check_string = "\n".join(f"{key}={value}" for key, value in sorted(values.items()))
    # Login Widget key is a plain SHA-256 of the bot token (the "WebAppData"
    # HMAC key is the Mini App initData scheme, not the widget's).
    secret = hashlib.sha256(b"123456:test-token").digest()
    payload["hash"] = hmac.new(secret, check_string.encode(), hashlib.sha256).hexdigest()

    response = await client.post("/api/auth/oauth/telegram/", json=payload)

    assert response.status_code == 200
    assert response.json()["user"]["first_name"] == "Telegram"
