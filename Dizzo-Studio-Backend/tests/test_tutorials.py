import httpx
import pytest

from tests.conftest import FakeStorage, register
from tests.test_catalog import catalog_image, ok
from tests.test_studio import png, upload

T = "/api/admin/tutorials"
PUBLIC_KEYS = {"id", "title", "cover_url", "cover_width", "cover_height", "video_url"}


@pytest.mark.asyncio
async def test_admin_manages_tutorials(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    cover = await catalog_image(admin_client, storage)
    other_cover = await catalog_image(admin_client, storage)

    first = ok(await admin_client.post(f"{T}/", json={
        "title": "  Dizayn yaratish ", "cover_media_id": cover, "cover_width": 1200, "cover_height": 1500,
    }), 201)
    second = ok(await admin_client.post(f"{T}/", json={
        "title": "Buyurtma berish", "cover_media_id": cover, "video_url": " https://youtu.be/abc ",
        "is_published": True,
    }), 201)

    assert set(PUBLIC_KEYS) <= set(first)
    assert first["title"] == "Dizayn yaratish" and first["video_url"] is None
    assert (first["cover_width"], first["cover_height"]) == (1200, 1500)
    assert first["cover_media_id"] == cover and first["cover_url"].startswith("https://media.test/")
    assert first["is_published"] is False and first["created_at"]
    assert second["video_url"] == "https://youtu.be/abc" and second["is_published"] is True
    assert (first["sort_order"], second["sort_order"]) == (0, 1)

    patched = ok(await admin_client.patch(f"{T}/{first['id']}/", json={
        "video_url": "https://t.me/dizzo_uz/5", "is_published": True,
    }))
    assert patched["video_url"] == "https://t.me/dizzo_uz/5" and patched["is_published"] is True
    assert patched["title"] == "Dizayn yaratish" and patched["cover_width"] == 1200  # untouched
    swapped = ok(await admin_client.patch(f"{T}/{first['id']}/", json={"cover_media_id": other_cover, "video_url": ""}))
    assert swapped["cover_media_id"] == other_cover and swapped["video_url"] is None
    assert swapped["cover_width"] is None  # a new picture, size unknown

    reordered = ok(await admin_client.put(f"{T}/order/", json={"ids": [second["id"], first["id"]]}))
    assert [(i["id"], i["sort_order"]) for i in reordered] == [(second["id"], 0), (first["id"], 1)]
    assert [i["id"] for i in ok(await admin_client.get(f"{T}/"))] == [second["id"], first["id"]]

    assert (await admin_client.delete(f"{T}/{second['id']}/")).status_code == 204
    assert [i["id"] for i in ok(await admin_client.get(f"{T}/"))] == [first["id"]]
    assert (await admin_client.delete(f"{T}/{second['id']}/")).status_code == 404
    assert (await admin_client.patch(f"{T}/{second['id']}/", json={"title": "x"})).status_code == 404
    third = ok(await admin_client.post(f"{T}/", json={"title": "Yana", "cover_media_id": cover}), 201)
    assert third["sort_order"] == 2  # new items go last


@pytest.mark.asyncio
async def test_tutorial_validation(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    cover = await catalog_image(admin_client, storage)
    design = await upload(admin_client, storage, "design", png((10, 10)))
    pending = ok(await admin_client.post("/api/media/uploads/", json={
        "purpose": "catalog", "content_type": "image/png", "size_bytes": 64,
    }), 201)["id"]

    def post(**body):
        return admin_client.post(f"{T}/", json={"title": "Darslik", "cover_media_id": cover, **body})

    for body in (
        {"title": "   "}, {"title": "x" * 121}, {"video_url": "javascript:alert(1)"},
        {"video_url": "https://x.uz/" + "a" * 500}, {"cover_width": 0}, {"foo": 1},
    ):
        assert (await post(**body)).status_code == 422, body
    unknown = await post(cover_media_id="no-such-media")
    not_ready = await post(cover_media_id=pending)
    not_catalog = await post(cover_media_id=design)
    assert unknown.status_code == 422 and "topilmadi" in unknown.json()["detail"]
    assert not_ready.status_code == 422
    assert not_catalog.status_code == 422 and "katalog" in not_catalog.json()["detail"]
    assert ok(await admin_client.get(f"{T}/")) == []

    item = ok(await post(), 201)
    assert (await admin_client.patch(f"{T}/{item['id']}/", json={"cover_media_id": design})).status_code == 422
    assert (await admin_client.patch(f"{T}/{item['id']}/", json={"video_url": "ftp://x"})).status_code == 422
    assert (await admin_client.put(f"{T}/order/", json={"ids": [item["id"], 99999]})).status_code == 422
    assert (await admin_client.put(f"{T}/order/", json={"ids": [item["id"], item["id"]]})).status_code == 422


@pytest.mark.asyncio
async def test_tutorial_admin_needs_an_admin(client: httpx.AsyncClient, storage: FakeStorage) -> None:
    assert (await client.get(f"{T}/")).status_code == 401
    await register(client, "tutorial-customer@example.com")
    assert (await client.get(f"{T}/")).status_code == 403
    assert (await client.post(f"{T}/", json={"title": "x", "cover_media_id": "x"})).status_code == 403
    assert (await client.put(f"{T}/order/", json={"ids": []})).status_code == 403
    assert (await client.patch(f"{T}/1/", json={})).status_code == 403
    assert (await client.delete(f"{T}/1/")).status_code == 403


@pytest.mark.asyncio
async def test_public_list_shows_published_in_order(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    assert ok(await admin_client.get("/api/tutorials/")) == []
    cover = await catalog_image(admin_client, storage)
    a = ok(await admin_client.post(f"{T}/", json={"title": "A", "cover_media_id": cover, "is_published": True}), 201)
    ok(await admin_client.post(f"{T}/", json={"title": "Draft", "cover_media_id": cover}), 201)
    c = ok(await admin_client.post(f"{T}/", json={
        "title": "C", "cover_media_id": cover, "video_url": "https://youtu.be/x", "is_published": True,
    }), 201)
    ok(await admin_client.put(f"{T}/order/", json={"ids": [c["id"], a["id"]]}))

    feed = ok(await admin_client.get("/api/tutorials/"))
    assert [i["title"] for i in feed] == ["C", "A"]
    assert set(feed[0]) == PUBLIC_KEYS
    assert feed[0]["video_url"] == "https://youtu.be/x" and feed[0]["cover_url"] == a["cover_url"]
