from collections.abc import AsyncIterator, Iterator

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.api.v1 import auth as auth_router
from app.core.config import Settings
from app.db.base import Base
from app.main import create_app
from app.models.catalog import ProductCategory
from app.models.user import User
from app.services import auth as auth_service
from app.services.storage import StoredObject, get_storage


@pytest.fixture(autouse=True)
def isolate_test_settings(monkeypatch: pytest.MonkeyPatch) -> None:
    from app.core.config import get_settings

    monkeypatch.setenv("FRONTEND_URL", "http://localhost:3000")
    monkeypatch.setenv("COOKIE_SECURE", "False")
    monkeypatch.setenv("COOKIE_DOMAIN", "")
    monkeypatch.setenv("COOKIE_SAMESITE", "lax")
    monkeypatch.setenv("ENVIRONMENT", "testing")
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


@pytest.fixture(autouse=True)
def fresh_feed_cache() -> None:
    # Tests write straight to the database too: never serve a list cached by another test.
    from app.services import feed_cache

    feed_cache.clear()


@pytest.fixture
def test_app() -> FastAPI:
    return create_app(lifespan_enabled=False)


@pytest.fixture
async def session_factory() -> AsyncIterator[async_sessionmaker[AsyncSession]]:
    async_engine = create_async_engine(
        "sqlite+aiosqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    factory = async_sessionmaker(async_engine, expire_on_commit=False)

    async with async_engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
        # The shelves migration 0010 seeds.
        await connection.execute(ProductCategory.__table__.insert(), [
            {"slug": slug, "name": name, "icon_svg": "", "sort_order": i, "is_active": True}
            for i, (slug, name) in enumerate([
                ("idish-tovoq", "Idish-tovoq"), ("uy-buyumlari", "Uy-buyumlari"), ("kiyim", "Kiyim"),
                ("aksessuar", "Aksessuarlar"), ("boshqa", "Boshqalar"),
            ])
        ])

    yield factory
    await async_engine.dispose()


@pytest.fixture
async def client(
    test_app: FastAPI, session_factory: async_sessionmaker[AsyncSession]
) -> AsyncIterator[AsyncClient]:
    async def override_get_db() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    test_app.dependency_overrides[auth_router.get_db] = override_get_db
    test_app.dependency_overrides[auth_router.get_current_user] = auth_router.get_current_user

    async with AsyncClient(
        transport=ASGITransport(app=test_app),
        base_url="http://testserver",
    ) as test_client:
        yield test_client

    test_app.dependency_overrides.clear()


def tiny_image(content_type: str) -> bytes:
    import io

    from PIL import Image

    image_format = {"image/png": "PNG", "image/jpeg": "JPEG", "image/webp": "WEBP"}.get(content_type)
    if image_format is None:
        return b""
    out = io.BytesIO()
    Image.new("RGB", (1, 1), (255, 0, 0)).save(out, format=image_format)
    return out.getvalue()


class FakeStorage:
    """In-memory stand-in for R2Storage: presigned PUTs are simulated by
    `put`, the way the browser would upload after getting a ticket."""

    def __init__(self) -> None:
        self.objects: dict[str, StoredObject] = {}
        self.bodies: dict[str, bytes] = {}

    def presign_put(self, key: str, *, content_type: str, size_bytes: int) -> str:
        return f"https://r2.test/{key}?signed"

    def public_url(self, key: str) -> str:
        return f"https://media.test/{key}"

    def put(self, url: str, *, size_bytes: int, content_type: str, body: bytes | None = None) -> None:
        """Without a body, the object is a 1×1 image of the declared type (the
        backend checks uploaded bytes against it)."""
        key = url.removeprefix("https://r2.test/").removesuffix("?signed")
        if body is None:
            body = tiny_image(content_type)
        self.objects[key] = StoredObject(size_bytes=size_bytes, content_type=content_type)
        self.bodies[key] = body

    async def head(self, key: str) -> StoredObject | None:
        return self.objects.get(key)

    async def read_range(self, key: str, start: int, length: int) -> bytes:
        return self.bodies[key][start:start + length]

    async def read(self, key: str) -> bytes:
        return self.bodies[key]

    async def put_bytes(self, key: str, body: bytes, content_type: str) -> None:
        self.objects[key] = StoredObject(size_bytes=len(body), content_type=content_type)
        self.bodies[key] = body

    async def copy(self, source_key: str, target_key: str) -> None:
        self.objects[target_key] = self.objects[source_key]
        self.bodies[target_key] = self.bodies[source_key]

    async def delete(self, key: str) -> None:
        self.objects.pop(key, None)
        self.bodies.pop(key, None)


@pytest.fixture
def storage(test_app: FastAPI) -> Iterator[FakeStorage]:
    fake = FakeStorage()
    test_app.dependency_overrides[get_storage] = lambda: fake
    yield fake


async def register(client: AsyncClient, email: str) -> dict:
    response = await client.post(
        "/api/auth/register/", json={"first_name": "Test", "email": email, "password": "password123"}
    )
    assert response.status_code == 200, response.text
    return response.json()["user"]


async def make_admin(session_factory: async_sessionmaker[AsyncSession], user_id: int) -> None:
    async with session_factory() as session:
        (await session.get(User, user_id)).role = "admin"
        await session.commit()


@pytest.fixture
async def admin_client(
    client: AsyncClient, session_factory: async_sessionmaker[AsyncSession], storage: FakeStorage
) -> AsyncClient:
    user = await register(client, "catalog-admin@example.com")
    await make_admin(session_factory, user["id"])
    return client


@pytest.fixture
def configure_oauth(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    settings = Settings(
        jwt_secret_key="test-secret-key-that-is-long-enough",
        google_client_id="google-client-id",
        telegram_bot_token="123456:test-token",
        telegram_bot_username="enjoy_test_bot",
        telegram_oidc_client_id="987654321",
    )
    monkeypatch.setattr(auth_router, "get_settings", lambda: settings)
    monkeypatch.setattr(auth_service, "get_settings", lambda: settings)
    yield
