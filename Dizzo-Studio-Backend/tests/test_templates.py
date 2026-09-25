import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from tests.conftest import FakeStorage, make_admin, register
from tests.test_catalog import A, build_mug, ok
from tests.test_studio import UV_LAYER, document, png, shop, upload

HEART = {
    "id": "g1", "area": "wrap", "method": "uv", "kind": "graphic", "x_mm": 40, "y_mm": 40, "w_mm": 20, "h_mm": 20,
    "graphic": {"library": "icon", "name": "heart", "color": "#e11d48"},
}


async def admin_mug(client: httpx.AsyncClient, storage: FakeStorage, session_factory) -> dict:
    admin = await register(client, "tpl-admin@example.com")
    await make_admin(session_factory, admin["id"])
    return await build_mug(client, storage)


def image_layer(media_id: str) -> dict:
    return {
        "id": "img", "area": "wrap", "method": "uv", "kind": "image", "x_mm": 170, "y_mm": 40, "w_mm": 40, "h_mm": 40,
        "image": {"media_id": media_id, "url": "", "px_w": 10, "px_h": 10},
    }


@pytest.mark.asyncio
async def test_admin_saves_a_template_and_customers_start_from_it(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    product = await admin_mug(client, storage, session_factory)
    variant = product["variants"][0]
    photo = await upload(client, storage, "design", png((10, 10), (0, 0, 10, 10, (200, 0, 0, 255))))
    preview = await upload(client, storage, "design", png((32, 32)))

    template = ok(await client.post(f"{A}/products/{product['id']}/templates/", json={
        "name": " Tug‘ilgan kun ", "category": "Bayram", "variant_ids": [variant["id"]],
        "document": document(UV_LAYER, HEART, image_layer(photo)), "preview_media_id": preview,
    }), 201)

    # The admin's uploads were copied into library media.
    [image] = [layer["image"] for layer in template["document"]["layers"] if layer["kind"] == "image"]
    assert image["media_id"] != photo and image["url"].startswith("https://media.test/templates/")
    assert template["preview_url"].startswith("https://media.test/templates/")
    assert template["name"] == "Tug‘ilgan kun" and template["variant_ids"] == [variant["id"]]
    assert storage.bodies[image["url"].removeprefix("https://media.test/")] == storage.bodies[
        next(k for k in storage.bodies if photo in k)
    ]

    await client.post("/api/auth/logout/")
    public = ok(await client.get("/api/catalog/products/krujka/templates/"))
    assert [(t["id"], t["category"], t["variant_ids"]) for t in public] == [(template["id"], "Bayram", [variant["id"]])]

    # A customer's design may use the template's library images.
    await register(client, "tpl-customer@example.com")
    design = ok(await client.post("/api/studio/designs/", json={
        "variant_id": variant["id"], "color_id": variant["colors"][0]["id"], "document": public[0]["document"],
    }), 201)
    assert design["issues"] == []

    await client.post("/api/auth/logout/")
    await client.post("/api/auth/login/", json={"email": "tpl-admin@example.com", "password": "password123"})
    ok(await client.patch(f"/api/admin/catalog/templates/{template['id']}/", json={"is_active": False}))
    assert ok(await client.get("/api/catalog/products/krujka/templates/")) == []


@pytest.mark.asyncio
async def test_a_template_must_fit_its_variants(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    product = await admin_mug(client, storage, session_factory)
    variant_id = product["variants"][0]["id"]
    preview = await upload(client, storage, "design", png((32, 32)))
    url = f"{A}/products/{product['id']}/templates/"

    def body(*layers: dict, variant_ids: list[int] | None = None) -> dict:
        return {"name": "Shablon", "variant_ids": variant_ids or [variant_id], "document": document(*layers),
                "preview_media_id": preview}

    outside = await client.post(url, json=body({**UV_LAYER, "x_mm": 220}))
    unplaced = await client.post(url, json=body(UV_LAYER, {**HEART, "area": None}))
    foreign = await client.post(url, json=body(UV_LAYER, variant_ids=[variant_id + 999]))
    empty = await client.post(url, json=body())
    await client.post("/api/auth/logout/")
    await register(client, "stranger@example.com")
    stranger_photo = await upload(client, storage, "design", png((10, 10)))
    await client.post("/api/auth/logout/")
    await client.post("/api/auth/login/", json={"email": "tpl-admin@example.com", "password": "password123"})
    not_theirs = await client.post(url, json=body(image_layer(stranger_photo)))

    assert outside.status_code == 201  # sticking out is cropped, not refused
    assert unplaced.status_code == 422 and "joylashtirilmagan" in unplaced.json()["detail"]
    assert foreign.status_code == 422 and "Variant topilmadi" in foreign.json()["detail"]
    assert empty.status_code == 422 and "bo'sh" in empty.json()["detail"]
    assert not_theirs.status_code == 422 and "tegishli emas" in not_theirs.json()["detail"]
    assert [t["name"] for t in ok(await client.get(url))] == ["Shablon"]  # only the one sticking out


@pytest.mark.asyncio
async def test_graphic_layers_follow_the_method(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    await client.post("/api/auth/logout/")
    await client.post("/api/auth/login/", json={"email": "shop-admin@example.com", "password": "password123"})
    ok(await client.patch(f"{A}/variants/{s['variant_id']}/", json={"methods": ["uv", "engrave"]}))
    ok(await client.put(f"{A}/products/{s['product']['id']}/price-tiers/engrave/", json={
        "tiers": [{"min_cm2": "0", "max_cm2": None, "surcharge": "0"}],
    }))
    await client.post("/api/auth/logout/")
    await client.post("/api/auth/login/", json={"email": "customer@example.com", "password": "password123"})
    engraved = {**HEART, "id": "g2", "method": "engrave", "x_mm": 125}

    def save(*layers: dict) -> httpx.Response:
        return client.post("/api/studio/designs/", json={
            "variant_id": s["variant_id"], "color_id": s["black"], "document": document(*layers),
        })

    coloured = ok(await save(HEART), 201)
    red_engraving = ok(await save(engraved), 201)
    black_engraving = ok(await save({**engraved, "graphic": {**HEART["graphic"], "color": "#000000"}}), 201)
    mixed = await save({**HEART, "text": UV_LAYER["text"]})
    bad_name = await save({**HEART, "graphic": {**HEART["graphic"], "name": "../x"}})

    assert coloured["issues"] == []
    assert red_engraving["issues"] == ["ikonka: bu usulda rang bo'lmaydi"]
    assert black_engraving["issues"] == []
    assert mixed.status_code == 422 and bad_name.status_code == 422

    both = ok(await save(HEART, {**engraved, "graphic": {**HEART["graphic"], "color": "#000000"}}), 201)
    assert both["issues"] == ["Butun dizayn bitta usulda bosiladi: rangli bosma yoki lazer o'yma"]

    # Anything may stick out of the zone, even wholly: the print file is
    # cropped to it.
    sticking_out = ok(await save({**HEART, "x_mm": 5, "w_mm": 40, "h_mm": 40}), 201)
    gone = ok(await save({**HEART, "x_mm": 240}), 201)
    text_out = ok(await save({**UV_LAYER, "x_mm": 220}), 201)
    assert sticking_out["issues"] == []
    assert gone["issues"] == [] and text_out["issues"] == []


@pytest.mark.asyncio
async def test_gallery_shows_published_designs_after_orders(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    from tests.test_gallery import completed_order

    product = await admin_mug(client, storage, session_factory)
    variant = product["variants"][0]
    colour = variant["colors"][0]
    preview = await upload(client, storage, "design", png((32, 32)))
    pics = [await upload(client, storage, "catalog", png((20, 20))) for _ in range(3)]
    body = {"variant_ids": [variant["id"]], "document": document(UV_LAYER, HEART), "preview_media_id": preview}

    first = ok(await client.post(f"{A}/products/{product['id']}/templates/", json={
        **body, "name": "Sovg‘a", "images": pics[:2], "in_gallery": True, "color_id": colour["id"],
    }), 201)
    assert [i["media_id"] for i in first["images"]] == pics[:2]
    assert first["in_gallery"] is True and first["color_id"] == colour["id"]
    assert first["product_slug"] == "krujka" and first["product_name"] == "Krujka"
    second = ok(await client.post(f"{A}/products/{product['id']}/templates/", json={**body, "name": "Tong"}), 201)
    assert second["in_gallery"] is False and second["images"] == []

    # A colour of another product is refused; the gallery fields patch alone.
    bad = await client.patch(f"{A}/templates/{second['id']}/", json={"color_id": 99999})
    assert bad.status_code == 422
    second = ok(await client.patch(f"{A}/templates/{second['id']}/", json={"in_gallery": True, "images": [pics[2]]}))
    assert [i["media_id"] for i in second["images"]] == [pics[2]]

    listed = ok(await client.get(f"{A}/templates/"))
    assert [t["id"] for t in listed] == [first["id"], second["id"]]
    reordered = ok(await client.put(f"{A}/templates/order/", json={"ids": [second["id"], first["id"]]}))
    assert [t["id"] for t in reordered] == [second["id"], first["id"]]

    feed = ok(await client.get("/api/gallery/"))
    assert [i["id"] for i in feed] == [f"template-{second['id']}", f"template-{first['id']}"]
    item = feed[1]
    assert item["kind"] == "template" and item["template_id"] == first["id"]
    assert item["variant_id"] == variant["id"] and item["color_id"] == colour["id"]
    assert item["title"] == "Sovg‘a" and item["product_slug"] == "krujka" and item["customer_name"] == ""
    assert item["image_urls"] == [i["url"] for i in first["images"]]
    assert item["preview_image_url"] == item["image_urls"][0]

    # A page at a time, and one catalog shelf.
    shelf = item["category"]
    assert shelf
    assert [i["id"] for i in ok(await client.get("/api/gallery/", params={"limit": 1, "offset": 1}))] == [item["id"]]
    assert len(ok(await client.get("/api/gallery/", params={"category": shelf}))) == 2
    assert ok(await client.get("/api/gallery/", params={"category": "yoq"})) == []
    assert ok(await client.get("/api/gallery/shelves/")) == {"total": 2, "counts": {shelf: 2}}
    assert ok(await client.get(f"/api/gallery/item/{item['id']}/")) == item
    assert (await client.get("/api/gallery/item/template-999999/")).status_code == 404

    # Hidden from the gallery, it stays a Studio template.
    ok(await client.patch(f"{A}/templates/{second['id']}/", json={"in_gallery": False}))
    assert [i["id"] for i in ok(await client.get("/api/gallery/"))] == [f"template-{first['id']}"]
    assert len(ok(await client.get("/api/catalog/products/krujka/templates/"))) == 2

    # Real orders come first.
    customer = await register(client, "gallery-order@example.com")
    order_item = await completed_order(session_factory, customer["id"], "T-1", ["orders/T-1/1.png"])
    feed = ok(await client.get("/api/gallery/"))
    assert [i["kind"] for i in feed] == ["order", "template"]
    assert feed[0]["order_item_id"] == order_item
    assert [i["kind"] for i in ok(await client.get("/api/gallery/", params={"limit": 1}))] == ["order"]


@pytest.mark.asyncio
async def test_gallery_and_manual_images_for_variant_colors(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    product = await admin_mug(client, storage, session_factory)
    variant = product["variants"][0]
    colour = variant["colors"][0]

    # Initially color has no images
    detail = ok(await client.get("/api/catalog/products/krujka/"))
    assert detail["variants"][0]["colors"][0]["images"] == []

    # Upload mockups and create a template in Galereya for this color
    mockup1 = await upload(client, storage, "catalog", png((32, 32)))
    mockup2 = await upload(client, storage, "catalog", png((32, 32)))
    preview = await upload(client, storage, "design", png((32, 32)))

    template = ok(await client.post(f"{A}/products/{product['id']}/templates/", json={
        "name": "Dizayn 1",
        "category": "Bayram",
        "variant_ids": [variant["id"]],
        "document": document(UV_LAYER, HEART),
        "preview_media_id": preview,
        "color_id": colour["id"],
        "images": [mockup1, mockup2],
        "in_gallery": True,
    }), 201)

    # A template is a design a customer may apply — not a photograph of this
    # colour. It must never appear in the colour's gallery: a customer opening
    # a plain mug to design it themselves would otherwise see mugs that already
    # carry someone else's print, and believe the print is part of the product.
    detail_with_gallery = ok(await client.get("/api/catalog/products/krujka/"))
    assert detail_with_gallery["variants"][0]["colors"][0]["images"] == []
    assert detail_with_gallery["variants"][0]["images"] == []
    assert detail_with_gallery["images"] == []
    # It is still offered as a template, which is where it belongs.
    assert [t["id"] for t in ok(await client.get("/api/catalog/products/krujka/templates/"))] == [template["id"]]

    # What the admin puts on the colour is exactly what the colour shows.
    manual_photo = await upload(client, storage, "catalog", png((16, 16)))
    ok(await client.put(f"{A}/colors/{colour['id']}/images/", json={"media_ids": [manual_photo]}))

    detail_with_manual = ok(await client.get("/api/catalog/products/krujka/"))
    color_images = detail_with_manual["variants"][0]["colors"][0]["images"]
    assert len(color_images) == 1
    assert manual_photo in color_images[0]

