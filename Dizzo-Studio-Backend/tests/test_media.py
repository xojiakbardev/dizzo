import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.api.v1 import media as media_api
from app.models.user import User
from tests.conftest import FakeStorage, register

PNG = "image/png"


async def upload(client: httpx.AsyncClient, storage: FakeStorage, *, purpose: str = "design", size: int = 2048) -> dict:
    ticket = await client.post("/api/media/uploads/", json={"purpose": purpose, "content_type": PNG, "size_bytes": size})
    assert ticket.status_code == 201, ticket.text
    body = ticket.json()
    storage.put(body["upload_url"], size_bytes=size, content_type=PNG)
    done = await client.post(f"/api/media/{body['id']}/complete/")
    assert done.status_code == 200, done.text
    return done.json()


@pytest.mark.asyncio
async def test_guest_design_upload_lands_in_guest_folder_and_becomes_ready(client: httpx.AsyncClient, storage: FakeStorage) -> None:
    media = await upload(client, storage)

    assert media["status"] == "ready"
    assert media["guest"] is True
    assert media["url"].startswith("https://media.test/designs/guests/") and media["url"].endswith(".png")


@pytest.mark.asyncio
async def test_complete_before_upload_is_a_conflict(client: httpx.AsyncClient, storage: FakeStorage) -> None:
    ticket = await client.post("/api/media/uploads/", json={"purpose": "design", "content_type": PNG, "size_bytes": 10})

    done = await client.post(f"/api/media/{ticket.json()['id']}/complete/")

    assert done.status_code == 409


@pytest.mark.asyncio
async def test_mismatched_object_is_rejected_and_deleted(client: httpx.AsyncClient, storage: FakeStorage) -> None:
    ticket = (await client.post("/api/media/uploads/", json={"purpose": "design", "content_type": PNG, "size_bytes": 10})).json()
    storage.put(ticket["upload_url"], size_bytes=999, content_type=PNG)

    done = await client.post(f"/api/media/{ticket['id']}/complete/")

    assert done.status_code == 422
    assert storage.objects == {}


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("content_type", "size_bytes"),
    [("image/svg+xml", 100), ("application/pdf", 100), (PNG, 10 * 1024 * 1024 + 1)],
)
async def test_wrong_type_or_too_big_is_rejected(
    client: httpx.AsyncClient, storage: FakeStorage, content_type: str, size_bytes: int
) -> None:
    response = await client.post(
        "/api/media/uploads/", json={"purpose": "design", "content_type": content_type, "size_bytes": size_bytes}
    )

    assert response.status_code == 422


@pytest.mark.asyncio
async def test_guest_uploads_are_rate_limited_per_ip(client: httpx.AsyncClient, storage: FakeStorage) -> None:
    for _ in range(media_api.GUEST_UPLOADS_PER_HOUR):
        ok = await client.post("/api/media/uploads/", json={"purpose": "design", "content_type": PNG, "size_bytes": 1})
        assert ok.status_code == 201

    over = await client.post("/api/media/uploads/", json={"purpose": "design", "content_type": PNG, "size_bytes": 1})

    assert over.status_code == 429


@pytest.mark.asyncio
async def test_staff_uploads_are_not_rate_limited(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession], monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(media_api, "UPLOADS_PER_HOUR", 2)
    user = await register(client, "staff@example.com")
    async with session_factory() as session:
        (await session.get(User, user["id"])).role = "admin"
        await session.commit()

    for _ in range(5):
        res = await client.post("/api/media/uploads/", json={"purpose": "catalog", "content_type": PNG, "size_bytes": 100})
        assert res.status_code == 201


@pytest.mark.asyncio
async def test_customer_uploads_are_rate_limited(
    client: httpx.AsyncClient, storage: FakeStorage, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(media_api, "UPLOADS_PER_HOUR", 2)
    await register(client, "limited_customer@example.com")

    for _ in range(2):
        res = await client.post("/api/media/uploads/", json={"purpose": "design", "content_type": PNG, "size_bytes": 100})
        assert res.status_code == 201

    over = await client.post("/api/media/uploads/", json={"purpose": "design", "content_type": PNG, "size_bytes": 100})
    assert over.status_code == 429


@pytest.mark.asyncio
async def test_catalog_uploads_need_an_admin(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    body = {"purpose": "catalog", "content_type": PNG, "size_bytes": 100}
    assert (await client.post("/api/media/uploads/", json=body)).status_code == 401
    user = await register(client, "customer@example.com")
    assert (await client.post("/api/media/uploads/", json=body)).status_code == 403

    async with session_factory() as session:
        (await session.get(User, user["id"])).role = "admin"
        await session.commit()
    media = await upload(client, storage, purpose="catalog")

    assert "/catalog/" in media["url"]
    # Phones get small WebP copies next to the original.
    key = media["url"].removeprefix("https://media.test/")
    for width in (480, 960):
        assert storage.objects[f"{key}.w{width}.webp"].content_type == "image/webp"
    assert not any(k.endswith(".webp") and k.startswith("designs/") for k in storage.objects)


@pytest.mark.asyncio
async def test_signed_in_upload_goes_to_the_user_prefix(client: httpx.AsyncClient, storage: FakeStorage) -> None:
    user = await register(client, "owner@example.com")

    media = await upload(client, storage)

    assert f"/designs/u{user['id']}/" in media["url"]


@pytest.mark.asyncio
async def test_claim_moves_guest_uploads_to_the_user(client: httpx.AsyncClient, storage: FakeStorage) -> None:
    guest_media = await upload(client, storage)
    guest_key = guest_media["url"].removeprefix("https://media.test/")
    user = await register(client, "claimer@example.com")

    claimed = await client.post("/api/media/claim/", json={"ids": [guest_media["id"]]})
    again = await client.post("/api/media/claim/", json={"ids": [guest_media["id"]]})

    assert claimed.status_code == 200
    new_key = claimed.json()[0]["url"].removeprefix("https://media.test/")
    assert new_key == f"designs/u{user['id']}/{guest_key.removeprefix('designs/guests/')}"
    assert set(storage.objects) == {new_key}
    assert claimed.json()[0]["guest"] is False
    assert again.status_code == 200 and again.json()[0]["url"] == claimed.json()[0]["url"]


@pytest.mark.asyncio
async def test_claiming_someone_elses_upload_is_forbidden(client: httpx.AsyncClient, storage: FakeStorage) -> None:
    await register(client, "first@example.com")
    owned = await upload(client, storage)
    await client.post("/api/auth/logout/")
    await register(client, "second@example.com")

    response = await client.post("/api/media/claim/", json={"ids": [owned["id"]]})

    assert response.status_code == 403


@pytest.mark.asyncio
async def test_invalid_token_is_401_not_a_silent_guest(client: httpx.AsyncClient, storage: FakeStorage) -> None:
    response = await client.post(
        "/api/media/uploads/",
        json={"purpose": "design", "content_type": PNG, "size_bytes": 1},
        headers={"Authorization": "Bearer not-a-real-token"},
    )

    assert response.status_code == 401
