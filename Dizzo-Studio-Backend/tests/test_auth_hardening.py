"""Rate limits, token revocation/rotation, email handling, role grants."""

import hashlib
import hmac
import time
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import httpx
import jwt
import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.config import Settings, get_settings
from app.core.rate_limit import client_ip
from app.main import create_app
from app.models.user import RefreshSession, User
from app.services import oauth
from tests.conftest import register

PASSWORD = "password123"


def bearer(token: str) -> dict:
    return {"authorization": f"Bearer {token}"}


async def login(client: httpx.AsyncClient, email: str, password: str = PASSWORD) -> httpx.Response:
    response = await client.post("/api/auth/login/", json={"email": email, "password": password})
    client.cookies.clear()  # bearer tokens only, like the app
    return response


async def set_role(session_factory: async_sessionmaker[AsyncSession], user_id: int, role: str) -> None:
    async with session_factory() as session:
        (await session.get(User, user_id)).role = role
        await session.commit()


def legacy_token(user_id: int, kind: str, lifetime: timedelta) -> str:
    """A token as issued before token_version/jti existed."""
    now = datetime.now(UTC)
    settings = get_settings()
    return jwt.encode(
        {"sub": str(user_id), "type": kind, "iat": now, "exp": now + lifetime},
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )


# ── Client IP ──


def fake_request(peer: str, headers: dict[str, str]) -> SimpleNamespace:
    return SimpleNamespace(client=SimpleNamespace(host=peer), headers={k.lower(): v for k, v in headers.items()})


def test_client_ip_believes_headers_only_from_trusted_proxies(monkeypatch: pytest.MonkeyPatch) -> None:
    forged = {"CF-Connecting-IP": "1.1.1.1", "X-Forwarded-For": "2.2.2.2", "X-Real-IP": "3.3.3.3"}
    assert client_ip(fake_request("203.0.113.9", forged)) == "203.0.113.9"  # nothing trusted by default

    monkeypatch.setenv("TRUSTED_PROXIES", "172.18.0.1, 10.0.0.0/8")
    get_settings.cache_clear()
    assert client_ip(fake_request("203.0.113.9", forged)) == "203.0.113.9"  # untrusted peer
    assert client_ip(fake_request("172.18.0.1", forged)) == "1.1.1.1"
    xff = {"X-Forwarded-For": "6.6.6.6, 5.5.5.5, 10.0.0.7"}
    assert client_ip(fake_request("10.1.1.1", xff)) == "5.5.5.5"  # nearest hop that isn't a proxy
    assert client_ip(fake_request("10.1.1.1", {"X-Real-IP": "7.7.7.7"})) == "7.7.7.7"
    assert client_ip(fake_request("10.1.1.1", {"CF-Connecting-IP": "junk"})) == "10.1.1.1"


def test_behind_proxy_trusts_the_docker_network(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("BEHIND_PROXY", "true")
    get_settings.cache_clear()
    assert client_ip(fake_request("172.18.0.1", {"X-Real-IP": "8.8.8.8"})) == "8.8.8.8"
    assert client_ip(fake_request("8.8.4.4", {"X-Real-IP": "8.8.8.8"})) == "8.8.4.4"


# ── Rate limits ──


@pytest.mark.asyncio
async def test_login_failures_are_limited_per_account(client: httpx.AsyncClient) -> None:
    await register(client, "victim@example.com")
    for _ in range(10):
        assert (await login(client, "victim@example.com", "wrong-password")).status_code == 401
    blocked = await login(client, "VICTIM@example.com", PASSWORD)
    assert blocked.status_code == 429 and "Juda ko'p" in blocked.json()["detail"]
    assert int(blocked.headers["retry-after"]) > 0
    # Another account from the same address is still fine.
    await register(client, "other@example.com")
    assert (await login(client, "other@example.com")).status_code == 200


@pytest.mark.asyncio
async def test_successful_logins_do_not_lock_an_account(client: httpx.AsyncClient) -> None:
    await register(client, "busy@example.com")
    for _ in range(12):
        assert (await login(client, "busy@example.com")).status_code == 200


@pytest.mark.asyncio
async def test_login_is_limited_per_ip(client: httpx.AsyncClient) -> None:
    for i in range(30):
        assert (await login(client, f"nobody{i}@example.com")).status_code == 401
    assert (await login(client, "nobody-else@example.com")).status_code == 429


@pytest.mark.asyncio
async def test_registration_is_limited_per_ip(client: httpx.AsyncClient) -> None:
    for i in range(10):
        await register(client, f"spam{i}@example.com")
    extra = await client.post(
        "/api/auth/register/", json={"first_name": "S", "email": "spam-extra@example.com", "password": PASSWORD}
    )
    assert extra.status_code == 429


@pytest.mark.asyncio
async def test_rate_limits_can_be_switched_off(monkeypatch: pytest.MonkeyPatch, client: httpx.AsyncClient) -> None:
    monkeypatch.setenv("RATE_LIMIT_ENABLED", "false")
    get_settings.cache_clear()
    for i in range(35):
        assert (await login(client, f"nobody{i}@example.com")).status_code == 401


# ── Token revocation and rotation ──


@pytest.mark.asyncio
async def test_refresh_rotates_and_a_replayed_token_signs_everyone_out(
    client: httpx.AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    await register(client, "rotate@example.com")
    first = (await login(client, "rotate@example.com")).json()

    second = await client.post("/api/auth/token/refresh/", json={"refresh_token": first["refresh_token"]})
    assert second.status_code == 200
    pair = second.json()
    assert pair["refresh_token"] != first["refresh_token"]
    # Within the grace period the spent token still answers (two tabs at once).
    again = await client.post("/api/auth/token/refresh/", json={"refresh_token": first["refresh_token"]})
    assert again.status_code == 200

    monkeypatch.setenv("REFRESH_REUSE_GRACE_SECONDS", "0")
    get_settings.cache_clear()
    time.sleep(0.01)
    client.cookies.clear()
    replay = await client.post("/api/auth/token/refresh/", json={"refresh_token": first["refresh_token"]})
    assert replay.status_code == 401
    # The replay revoked every session, the legitimate one included.
    client.cookies.clear()
    assert (await client.get("/api/auth/me", headers=bearer(pair["access_token"]))).status_code == 401
    assert (await client.post("/api/auth/token/refresh/", json={"refresh_token": pair["refresh_token"]})).status_code == 401
    assert (await login(client, "rotate@example.com")).status_code == 200


@pytest.mark.asyncio
async def test_logout_revokes_access_and_refresh_tokens(client: httpx.AsyncClient) -> None:
    await register(client, "logout@example.com")
    app_pair = (await login(client, "logout@example.com")).json()
    other_device = (await login(client, "logout@example.com")).json()

    assert (await client.post("/api/auth/logout/", json={"refresh_token": app_pair["refresh_token"]})).status_code == 200

    for pair in (app_pair, other_device):
        assert (await client.get("/api/auth/me", headers=bearer(pair["access_token"]))).status_code == 401
        client.cookies.clear()
        refreshed = await client.post("/api/auth/token/refresh/", json={"refresh_token": pair["refresh_token"]})
        assert refreshed.status_code == 401


@pytest.mark.asyncio
async def test_web_logout_with_cookies_revokes_the_session(client: httpx.AsyncClient) -> None:
    await register(client, "cookie@example.com")  # leaves the auth cookies on the client
    access = client.cookies.get("access_token")
    assert (await client.post("/api/auth/logout/")).status_code == 200
    client.cookies.clear()
    assert (await client.get("/api/auth/me", headers=bearer(access))).status_code == 401


@pytest.mark.asyncio
async def test_tokens_from_before_the_upgrade_work_until_refreshed(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    user = await register(client, "legacy@example.com")
    client.cookies.clear()
    access = legacy_token(user["id"], "access", timedelta(minutes=30))
    refresh = legacy_token(user["id"], "refresh", timedelta(days=30))

    assert (await client.get("/api/auth/me", headers=bearer(access))).status_code == 200
    rotated = await client.post("/api/auth/token/refresh/", json={"refresh_token": refresh})
    assert rotated.status_code == 200 and rotated.json()["refresh_token"] != refresh
    async with session_factory() as session:
        spent = (await session.execute(select(RefreshSession).where(RefreshSession.jti.like("legacy-%")))).scalar_one()
        assert spent.rotated_at is not None and spent.user_id == user["id"]

    # Once logged out, old-style tokens stop too.
    client.cookies.clear()
    await client.post("/api/auth/logout/", json={"refresh_token": rotated.json()["refresh_token"]})
    assert (await client.get("/api/auth/me", headers=bearer(access))).status_code == 401


@pytest.mark.asyncio
async def test_new_password_signs_other_sessions_out(client: httpx.AsyncClient) -> None:
    await register(client, "pw@example.com")
    other = (await login(client, "pw@example.com")).json()
    this = (await login(client, "pw@example.com")).json()

    changed = await client.post(
        "/api/auth/set-credentials/",
        json={"email": "PW@Example.com", "password": "new-password-1"},
        headers=bearer(this["access_token"]),
    )
    assert changed.status_code == 200, changed.text
    assert changed.json()["email"] == "pw@example.com"
    new_access = changed.cookies.get("access_token")
    client.cookies.clear()
    assert (await client.get("/api/auth/me", headers=bearer(other["access_token"]))).status_code == 401
    assert (await client.get("/api/auth/me", headers=bearer(this["access_token"]))).status_code == 401
    assert (await client.get("/api/auth/me", headers=bearer(new_access))).status_code == 200
    assert (await login(client, "pw@example.com", "new-password-1")).status_code == 200


@pytest.mark.asyncio
async def test_role_change_and_deactivation_revoke_tokens(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    boss = await register(client, "boss@example.com")
    await set_role(session_factory, boss["id"], "super_admin")
    worker = await register(client, "worker@example.com")
    boss_access = (await login(client, "boss@example.com")).json()["access_token"]
    worker_access = (await login(client, "worker@example.com")).json()["access_token"]

    promoted = await client.patch(
        f"/api/users/admin/{worker['id']}/role/", json={"role": "production_manager"}, headers=bearer(boss_access)
    )
    assert promoted.status_code == 200
    assert (await client.get("/api/auth/me", headers=bearer(worker_access))).status_code == 401

    worker_access = (await login(client, "worker@example.com")).json()["access_token"]
    unchanged = await client.patch(
        f"/api/users/admin/{worker['id']}/role/", json={"role": "production_manager"}, headers=bearer(boss_access)
    )
    assert unchanged.status_code == 200
    assert (await client.get("/api/auth/me", headers=bearer(worker_access))).status_code == 200  # nothing changed

    await client.patch(f"/api/users/admin/{worker['id']}/role/", json={"is_active": False}, headers=bearer(boss_access))
    assert (await client.get("/api/auth/me", headers=bearer(worker_access))).status_code == 401
    assert (await login(client, "worker@example.com")).status_code == 403


@pytest.mark.asyncio
async def test_an_admin_cannot_grant_admin_rights(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    admin = await register(client, "admin@example.com")
    await set_role(session_factory, admin["id"], "admin")
    boss = await register(client, "boss2@example.com")
    await set_role(session_factory, boss["id"], "super_admin")
    customer = await register(client, "cust@example.com")
    headers = bearer((await login(client, "admin@example.com")).json()["access_token"])
    role_url = f"/api/users/admin/{customer['id']}/role/"
    new_user = {"email": "new@example.com", "password": PASSWORD}

    assert (await client.patch(role_url, json={"role": "super_admin"}, headers=headers)).status_code == 403
    assert (await client.patch(role_url, json={"role": "admin"}, headers=headers)).status_code == 403
    assert (await client.patch(role_url, json={"is_staff": True}, headers=headers)).status_code == 403
    assert (await client.patch(role_url, json={"role": "wizard"}, headers=headers)).status_code == 422
    boss_url = f"/api/users/admin/{boss['id']}/role/"
    assert (await client.patch(boss_url, json={"is_active": False}, headers=headers)).status_code == 403
    assert (await client.post("/api/users/admin/create/", json={**new_user, "role": "super_admin"}, headers=headers)).status_code == 403
    # What an admin may do.
    assert (await client.patch(role_url, json={"role": "production_admin"}, headers=headers)).status_code == 200
    created = await client.post(
        "/api/users/admin/create/", json={**new_user, "email": "New@Example.com", "role": "production_manager"},
        headers=headers,
    )
    assert created.status_code == 201 and created.json()["email"] == "new@example.com"

    boss_headers = bearer((await login(client, "boss2@example.com")).json()["access_token"])
    assert (await client.patch(role_url, json={"role": "admin"}, headers=boss_headers)).status_code == 200


# ── Emails ──


@pytest.mark.asyncio
async def test_emails_are_case_insensitive(client: httpx.AsyncClient) -> None:
    user = await register(client, "Mixed.Case@Example.COM")
    assert user["email"] == "mixed.case@example.com"
    duplicate = await client.post(
        "/api/auth/register/", json={"first_name": "T", "email": "MIXED.case@example.com", "password": PASSWORD}
    )
    assert duplicate.status_code == 409
    assert (await login(client, "  MIXED.CASE@example.com ".strip())).status_code == 200


def google_tokeninfo(monkeypatch: pytest.MonkeyPatch, claims: dict) -> None:
    def tokeninfo(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"aud": "web-id", "iss": "https://accounts.google.com", **claims})

    transport = httpx.MockTransport(tokeninfo)
    monkeypatch.setattr(
        oauth,
        "httpx",
        SimpleNamespace(
            AsyncClient=lambda **kwargs: httpx.AsyncClient(transport=transport, **kwargs), HTTPError=httpx.HTTPError
        ),
    )


@pytest.fixture
def google_settings(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("GOOGLE_CLIENT_ID", "web-id")
    get_settings.cache_clear()


@pytest.mark.asyncio
async def test_unverified_google_email_does_not_take_over_a_password_account(
    client: httpx.AsyncClient, google_settings: None, monkeypatch: pytest.MonkeyPatch,
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    owner = await register(client, "owner@example.com")
    client.cookies.clear()

    google_tokeninfo(monkeypatch, {"sub": "g-1", "email": "Owner@example.com", "email_verified": "false"})
    refused = await client.post("/api/auth/oauth/google/", json={"id_token": "x"})
    assert refused.status_code == 409

    google_tokeninfo(monkeypatch, {"sub": "g-2", "email": "stranger@example.com"})
    stranger = await client.post("/api/auth/oauth/google/", json={"id_token": "x"})
    assert stranger.status_code == 200 and stranger.json()["user"]["email"] is None  # unverified: not kept

    google_tokeninfo(monkeypatch, {"sub": "g-1", "email": "OWNER@example.com", "email_verified": "true"})
    joined = await client.post("/api/auth/oauth/google/", json={"id_token": "x"})
    assert joined.status_code == 200 and joined.json()["user"]["id"] == owner["id"]


# ── Telegram ──


def signed_widget(bot_token: str, **data: object) -> dict:
    fields = {k: str(v) for k, v in data.items()}
    check = "\n".join(f"{k}={v}" for k, v in sorted(fields.items()))
    digest = hmac.new(hashlib.sha256(bot_token.encode()).digest(), check.encode(), hashlib.sha256).hexdigest()
    return {**data, "hash": digest}


@pytest.mark.asyncio
async def test_telegram_login_needs_a_recent_auth_date(client: httpx.AsyncClient, configure_oauth: None) -> None:
    token = "123456:test-token"
    no_date = signed_widget(token, id=77, first_name="A")
    old = signed_widget(token, id=77, first_name="A", auth_date=int(time.time()) - 2 * 86400)
    future = signed_widget(token, id=77, first_name="A", auth_date=int(time.time()) + 3600)
    fresh = signed_widget(token, id=77, first_name="A", auth_date=int(time.time()))

    for payload in (no_date, old, future):
        assert (await client.post("/api/auth/oauth/telegram/", json=payload)).status_code == 401
    assert (await client.post("/api/auth/oauth/telegram/", json=fresh)).status_code == 200


# ── App configuration ──


@pytest.mark.asyncio
async def test_docs_and_local_origins_only_in_debug(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("CORS_ALLOWED_ORIGINS", "https://dizzo.uz")
    get_settings.cache_clear()
    assert Settings().cors_origins == ["https://dizzo.uz"]
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=create_app(lifespan_enabled=False)), base_url="http://t") as c:
        assert (await c.get("/api/docs")).status_code == 404
        assert (await c.get("/api/openapi.json")).status_code == 404
        preflight = await c.options(
            "/api/health/", headers={"origin": "http://localhost:3000", "access-control-request-method": "GET"}
        )
        assert "access-control-allow-origin" not in preflight.headers

    monkeypatch.setenv("DEBUG", "true")
    get_settings.cache_clear()
    assert Settings().cors_origins == ["https://dizzo.uz", "http://localhost:3000", "http://127.0.0.1:3000"]
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=create_app(lifespan_enabled=False)), base_url="http://t") as c:
        assert (await c.get("/api/openapi.json")).status_code == 200


def load_migration(name: str):
    import importlib.util
    from pathlib import Path

    path = Path(__file__).resolve().parents[1] / "migrations" / "versions" / name
    spec = importlib.util.spec_from_file_location(name.removesuffix(".py"), path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.mark.asyncio
async def test_the_email_migration_lowercases_without_collisions(
    session_factory: async_sessionmaker[AsyncSession],
) -> None:
    migration = load_migration("0019_lowercase_emails.py")
    emails = {1: "Solo@Example.com", 2: "Twin@x.com", 3: "TWIN@x.com", 4: "Dup@y.com", 5: "dup@y.com", 6: None}
    async with session_factory() as session:
        session.add_all([User(id=i, email=e) for i, e in emails.items()])
        await session.commit()
        left = await session.run_sync(lambda s: migration.lowercase_emails(s.connection()))
        await session.commit()
        stored = dict((await session.execute(select(User.id, User.email).order_by(User.id))).all())

    assert stored == {1: "solo@example.com", 2: "twin@x.com", 3: "TWIN@x.com", 4: "Dup@y.com", 5: "dup@y.com", 6: None}
    assert left == [(3, "TWIN@x.com"), (4, "Dup@y.com")]
