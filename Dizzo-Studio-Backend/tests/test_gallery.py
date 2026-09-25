
import httpx
import pytest

from app.models.commerce import Order, OrderItem
from app.services import feed_cache
from tests.conftest import FakeStorage, register
from tests.test_catalog import A, catalog_image, ok
from tests.test_studio import png, upload

G = "/api/admin/gallery"
OLD_KEYS = {"order_item_id", "product_name", "customer_name", "preview_image_url", "created_at"}
NEW_KEYS = {"id", "kind", "product_slug", "title", "image_urls"}


async def product(client: httpx.AsyncClient, slug: str = "krujka") -> int:
    return ok(await client.post(f"{A}/products/", json={"slug": slug, "name": slug.title()}), 201)["id"]


async def images(client: httpx.AsyncClient, storage: FakeStorage, n: int) -> list[str]:
    return [await catalog_image(client, storage) for _ in range(n)]


async def completed_order(session_factory, user_id: int, number: str, keys: list[str]) -> int:
    async with session_factory() as session:
        order = Order(order_number=number, customer_id=user_id, status="COMPLETED", total_amount=65000)
        item = OrderItem(
            product_name="Krujka", product_slug="krujka", quantity=1, unit_price=65000,
            package={"mockups": [{"key": k} for k in keys]},
        )
        order.items.append(item)
        session.add(order)
        await session.commit()
    feed_cache.clear()  # written past the API, which would clear it
    return item.id


@pytest.mark.asyncio
async def test_admin_manages_showcase_items(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    pid = await product(admin_client)
    pics = await images(admin_client, storage, 3)

    first = ok(await admin_client.post(f"{G}/", json={
        "product_id": pid, "media_ids": pics[:2], "title": "  Oilaviy krujka ", "customer_name": "   ",
    }), 201)
    second = ok(await admin_client.post(f"{G}/", json={"product_id": pid, "media_ids": [pics[2]], "is_published": True}), 201)

    assert first["product_name"] == "Krujka" and first["product_slug"] == "krujka" and first["product_id"] == pid
    assert first["title"] == "Oilaviy krujka" and first["customer_name"] is None
    assert first["is_published"] is False and first["created_at"]
    assert [i["media_id"] for i in first["images"]] == pics[:2]
    assert first["images"][0]["url"].startswith("https://media.test/")
    assert (first["sort_order"], second["sort_order"]) == (0, 1) and second["is_published"] is True

    patched = ok(await admin_client.patch(f"{G}/{first['id']}/", json={
        "media_ids": [pics[1], pics[0], pics[2]], "customer_name": " Madina ", "is_published": True,
    }))
    assert [i["media_id"] for i in patched["images"]] == [pics[1], pics[0], pics[2]]
    assert patched["customer_name"] == "Madina" and patched["is_published"] is True
    assert patched["title"] == "Oilaviy krujka"  # untouched
    cleared = ok(await admin_client.patch(f"{G}/{first['id']}/", json={"title": ""}))
    assert cleared["title"] is None and cleared["customer_name"] == "Madina"

    reordered = ok(await admin_client.put(f"{G}/order/", json={"ids": [second["id"], first["id"]]}))
    assert [(i["id"], i["sort_order"]) for i in reordered] == [(second["id"], 0), (first["id"], 1)]
    assert [i["id"] for i in ok(await admin_client.get(f"{G}/"))] == [second["id"], first["id"]]

    assert (await admin_client.delete(f"{G}/{second['id']}/")).status_code == 204
    assert [i["id"] for i in ok(await admin_client.get(f"{G}/"))] == [first["id"]]
    assert (await admin_client.delete(f"{G}/{second['id']}/")).status_code == 404
    assert (await admin_client.patch(f"{G}/{second['id']}/", json={"title": "x"})).status_code == 404
    third = ok(await admin_client.post(f"{G}/", json={"product_id": pid, "media_ids": [pics[0]]}), 201)
    assert third["sort_order"] == 2  # new items go last


@pytest.mark.asyncio
async def test_showcase_validation(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    pid = await product(admin_client)
    pics = await images(admin_client, storage, 6)
    design = await upload(admin_client, storage, "design", png((10, 10)))
    pending = ok(await admin_client.post("/api/media/uploads/", json={
        "purpose": "catalog", "content_type": "image/png", "size_bytes": 64,
    }), 201)["id"]

    def post(**body):
        return admin_client.post(f"{G}/", json={"product_id": pid, "media_ids": pics[:1], **body})

    none = await post(media_ids=[])
    six = await post(media_ids=pics)
    dup = await post(media_ids=[pics[0], pics[0]])
    unknown = await post(media_ids=["no-such-media"])
    not_ready = await post(media_ids=[pending])
    not_catalog = await post(media_ids=[design])
    bad_product = await post(product_id=99999)
    long_title = await post(title="x" * 121)
    extra = await post(foo=1)

    for response in (none, six):
        assert response.status_code == 422 and "5 tagacha" in response.json()["detail"]
    assert dup.status_code == 422 and "ikki marta" in dup.json()["detail"]
    assert unknown.status_code == 422 and "topilmadi" in unknown.json()["detail"]
    assert not_ready.status_code == 422
    assert not_catalog.status_code == 422 and "katalog" in not_catalog.json()["detail"]
    assert bad_product.status_code == 422 and "Mahsulot" in bad_product.json()["detail"]
    assert long_title.status_code == 422 and extra.status_code == 422
    assert ok(await admin_client.get(f"{G}/")) == []

    item = ok(await post(), 201)
    assert (await admin_client.patch(f"{G}/{item['id']}/", json={"media_ids": pics})).status_code == 422
    assert (await admin_client.patch(f"{G}/{item['id']}/", json={"product_id": 99999})).status_code == 422
    assert (await admin_client.put(f"{G}/order/", json={"ids": [item["id"], 99999]})).status_code == 422
    assert (await admin_client.put(f"{G}/order/", json={"ids": [item["id"], item["id"]]})).status_code == 422
    assert [i["media_id"] for i in ok(await admin_client.get(f"{G}/"))[0]["images"]] == pics[:1]


@pytest.mark.asyncio
async def test_showcase_admin_needs_an_admin(client: httpx.AsyncClient, storage: FakeStorage) -> None:
    assert (await client.get(f"{G}/")).status_code == 401
    await register(client, "gallery-customer@example.com")
    assert (await client.get(f"{G}/")).status_code == 403
    assert (await client.post(f"{G}/", json={"product_id": 1, "media_ids": ["x"]})).status_code == 403
    assert (await client.put(f"{G}/order/", json={"ids": []})).status_code == 403
    assert (await client.patch(f"{G}/1/", json={})).status_code == 403
    assert (await client.delete(f"{G}/1/")).status_code == 403


