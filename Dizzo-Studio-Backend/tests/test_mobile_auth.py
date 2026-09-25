from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import httpx
import pytest
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.api.v1 import auth as auth_router
from app.core.config import Settings
from app.models.user import TelegramAppLogin
from app.services import auth as auth_service
from app.services import oauth
from tests.conftest import register

BOT = {"x-bot-token": "123456:test-token"}
TG_USER = {"telegram_id": 5050150433, "first_name": "Ali", "last_name": "Valiyev", "username": "ali"}


@pytest.fixture
def mobile_settings(monkeypatch: pytest.MonkeyPatch) -> Iterator[Settings]:
    settings = Settings(
        jwt_secret_key="test-secret-key-that-is-long-enough",
        google_client_id="web-id",
        google_mobile_client_ids=" android-id , ios-id,",
        telegram_bot_token="123456:test-token",
        telegram_bot_username="@enjoy_test_bot",
        telegram_app_logins_per_hour=3,
    )
    for module in (auth_router, auth_service, oauth):
        monkeypatch.setattr(module, "get_settings", lambda: settings)
    yield settings


def bearer(token: str) -> dict:
    return {"authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_the_app_refreshes_and_logs_out_with_body_tokens(client: httpx.AsyncClient) -> None:
    await register(client, "mobile@example.com")
    login = await client.post("/api/auth/login/", json={"email": "mobile@example.com", "password": "password123"})
    body = login.json()
    assert body["access_token"] and body["refresh_token"] and body["user"]["email"] == "mobile@example.com"
    client.cookies.clear()  # the app has no cookie jar

    refreshed = await client.post("/api/auth/token/refresh/", json={"refresh_token": body["refresh_token"]})
    assert refreshed.status_code == 200, refreshed.text
    pair = refreshed.json()
    client.cookies.clear()
    me = await client.get("/api/auth/me", headers=bearer(pair["access_token"]))
    assert me.status_code == 200 and me.json()["email"] == "mobile@example.com"
    again = await client.post("/api/auth/token/refresh/", json={"refresh_token": pair["refresh_token"]})
    assert again.status_code == 200

    client.cookies.clear()
    assert (await client.post("/api/auth/token/refresh/", json={"refresh_token": "junk"})).status_code == 401
    # An access token is not a refresh token.
    assert (await client.post("/api/auth/token/refresh/", json={"refresh_token": pair["access_token"]})).status_code == 401
    assert (await client.post("/api/auth/token/refresh/", json={})).status_code == 401

    assert (await client.post("/api/auth/logout/", json={"refresh_token": pair["refresh_token"]})).status_code == 200
    assert (await client.post("/api/auth/logout/")).status_code == 200


@pytest.mark.asyncio
async def test_google_accepts_web_and_mobile_audiences(
    client: httpx.AsyncClient, mobile_settings: Settings, monkeypatch: pytest.MonkeyPatch
) -> None:
    def tokeninfo(request: httpx.Request) -> httpx.Response:
        aud = request.url.params["id_token"]  # the fake id_token is just its audience
        return httpx.Response(
            200,
            json={
                "aud": aud,
                "iss": "https://accounts.google.com",
                "sub": f"sub-{aud}",
                "email": f"{aud}@example.com",
                "email_verified": "true",
                "given_name": "G",
            },
        )

    transport = httpx.MockTransport(tokeninfo)
    monkeypatch.setattr(
        oauth,
        "httpx",
        SimpleNamespace(
            AsyncClient=lambda **kwargs: httpx.AsyncClient(transport=transport, **kwargs), HTTPError=httpx.HTTPError
        ),
    )

    assert mobile_settings.google_audiences == ["web-id", "android-id", "ios-id"]
    for aud in ("web-id", "android-id", "ios-id"):
        response = await client.post("/api/auth/oauth/google/", json={"id_token": aud})
        assert response.status_code == 200, response.text
        assert response.json()["refresh_token"] and response.json()["user"]["email"] == f"{aud}@example.com"
    assert (await client.post("/api/auth/oauth/google/", json={"id_token": "someone-else"})).status_code == 401


async def app_login(client: httpx.AsyncClient) -> str:
    response = await client.post("/api/auth/telegram/app-login/")
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["deep_link"] == f"https://t.me/enjoy_test_bot?start=login_{body['token']}"
    assert body["expires_in_seconds"] == 300
    assert len(f"login_{body['token']}") <= 64
    return body["token"]


def confirm(client: httpx.AsyncClient, token: str, headers: dict = BOT, **user) -> object:
    return client.post("/api/auth/telegram/app-login/confirm/", headers=headers, json={"token": token, **TG_USER, **user})


@pytest.mark.asyncio
async def test_telegram_app_login_round_trip(client: httpx.AsyncClient, mobile_settings: Settings) -> None:
    token = await app_login(client)
    poll = f"/api/auth/telegram/app-login/{token}/"
    assert (await client.get(poll)).json() == {"status": "pending"}

    assert (await confirm(client, token, headers={"x-bot-token": "wrong"})).status_code == 403
    assert (await confirm(client, token, headers={})).status_code == 403
    assert (await client.get(poll)).json() == {"status": "pending"}

    confirmed = await confirm(client, token)
    assert confirmed.json() == {"ok": True, "full_name": "Ali Valiyev", "language": "uz"}
    assert (await confirm(client, token)).json() == {"ok": False, "reason": "invalid"}

    done = await client.get(poll)
    body = done.json()
    assert done.status_code == 200 and body["status"] == "done"
    assert body["access_token"] and body["refresh_token"]
    assert body["user"]["first_name"] == "Ali" and body["user"]["telegram_linked"] is True
    assert "access_token" not in done.cookies

    assert (await client.get(poll)).status_code == 410  # spent
    assert (await client.get("/api/auth/telegram/app-login/unknown-token/")).status_code == 410
    me = await client.get("/api/auth/me", headers=bearer(body["access_token"]))
    assert me.json()["id"] == body["user"]["id"]

    # The same Telegram user signing in again gets the same account.
    second = await app_login(client)
    await confirm(client, second)
    assert (await client.get(f"/api/auth/telegram/app-login/{second}/")).json()["user"]["id"] == body["user"]["id"]


@pytest.mark.asyncio
async def test_telegram_app_login_codes_expire(
    client: httpx.AsyncClient, mobile_settings: Settings, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    async def age(token: str) -> None:
        async with session_factory() as session:
            await session.execute(
                update(TelegramAppLogin)
                .where(TelegramAppLogin.token == token)
                .values(created_at=datetime.now(UTC) - timedelta(minutes=6))
            )
            await session.commit()

    stale = await app_login(client)
    await age(stale)
    assert (await confirm(client, stale)).json() == {"ok": False, "reason": "expired"}
    assert (await client.get(f"/api/auth/telegram/app-login/{stale}/")).status_code == 410

    # Confirmed in time, but never collected within the TTL.
    late = await app_login(client)
    assert (await confirm(client, late)).json()["ok"] is True
    await age(late)
    assert (await client.get(f"/api/auth/telegram/app-login/{late}/")).status_code == 410


@pytest.mark.asyncio
async def test_telegram_app_login_keeps_another_accounts_chat(
    client: httpx.AsyncClient, mobile_settings: Settings
) -> None:
    await register(client, "has-the-chat@example.com")
    link = (await client.post("/api/auth/telegram/link-token/")).json()["token"]
    await client.post("/api/auth/telegram/link/", headers=BOT, json={"token": link, "telegram_id": TG_USER["telegram_id"]})
    client.cookies.clear()

    token = await app_login(client)
    await confirm(client, token)
    body = (await client.get(f"/api/auth/telegram/app-login/{token}/")).json()
    assert body["user"]["email"] is None and body["user"]["telegram_linked"] is False


@pytest.mark.asyncio
async def test_telegram_app_login_is_rate_limited_per_ip(client: httpx.AsyncClient, mobile_settings: Settings) -> None:
    for _ in range(3):
        await app_login(client)
    assert (await client.post("/api/auth/telegram/app-login/")).status_code == 429


def cancel(client: httpx.AsyncClient, token: str, headers: dict = BOT) -> object:
    return client.post("/api/auth/telegram/app-login/cancel/", headers=headers, json={"token": token})


@pytest.mark.asyncio
async def test_telegram_app_login_waits_for_the_button(
    client: httpx.AsyncClient, mobile_settings: Settings, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    # Opening the link (/start) calls nothing: the code stays pending and
    # nobody is signed in until the bot confirms after "Tasdiqlash".
    token = await app_login(client)
    for _ in range(3):
        assert (await client.get(f"/api/auth/telegram/app-login/{token}/")).json() == {"status": "pending"}
    async with session_factory() as session:
        login = await session.scalar(select(TelegramAppLogin).where(TelegramAppLogin.token == token))
        assert login.user_id is None and login.confirmed_at is None
    assert (await confirm(client, token)).json()["ok"] is True
    assert (await client.get(f"/api/auth/telegram/app-login/{token}/")).json()["status"] == "done"


@pytest.mark.asyncio
async def test_telegram_app_login_can_be_cancelled(
    client: httpx.AsyncClient, mobile_settings: Settings, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    token = await app_login(client)
    poll = f"/api/auth/telegram/app-login/{token}/"
    assert (await cancel(client, token, headers={"x-bot-token": "wrong"})).status_code == 403
    assert (await cancel(client, token, headers={})).status_code == 403
    assert (await client.get(poll)).json() == {"status": "pending"}

    assert (await cancel(client, token)).json() == {"ok": True}
    assert (await client.get(poll)).status_code == 410
    assert (await cancel(client, token)).json() == {"ok": False, "reason": "invalid"}
    assert (await confirm(client, token)).json() == {"ok": False, "reason": "invalid"}
    assert (await client.get(poll)).status_code == 410
    assert (await cancel(client, "unknown-token")).json() == {"ok": False, "reason": "invalid"}

    # A confirmed code can't be cancelled any more; an expired one says so.
    confirmed = await app_login(client)
    await confirm(client, confirmed)
    assert (await cancel(client, confirmed)).json() == {"ok": False, "reason": "invalid"}
    stale = await app_login(client)
    async with session_factory() as session:
        await session.execute(
            update(TelegramAppLogin)
            .where(TelegramAppLogin.token == stale)
            .values(created_at=datetime.now(UTC) - timedelta(minutes=6))
        )
        await session.commit()
    assert (await cancel(client, stale)).json() == {"ok": False, "reason": "expired"}
