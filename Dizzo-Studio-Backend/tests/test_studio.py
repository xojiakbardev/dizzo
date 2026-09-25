import io
from decimal import Decimal

import httpx
import pytest
from PIL import Image
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.catalog import Shape
from tests.conftest import FakeStorage, make_admin, register
from tests.test_catalog import A, build_mug, ok

# The mug from build_mug: area "wrap" 226 × 79 mm, UV zone = whole area,
# engraving zone 75,15 100×50 mm (600 DPI). Base 149 000, "Qizil" +5 000.
UV_PX = (2669, 933)  # 226 × 79 mm at 300 DPI
ENGRAVE_PX = (5339, 1866)  # at 600 DPI
UV_LAYER = {
    "id": "l1", "area": "wrap", "method": "uv", "kind": "text", "x_mm": 113, "y_mm": 40, "w_mm": 80, "h_mm": 20,
    "rotation": 0, "text": {"content": "Salom", "font": "Montserrat", "size_mm": 12, "color": "#b3202a"},
}


def png(size: tuple[int, int], *rects: tuple[int, int, int, int, tuple[int, int, int, int]]) -> bytes:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    for x0, y0, x1, y1, color in rects:
        image.paste(color, (x0, y0, x1, y1))
    out = io.BytesIO()
    image.save(out, format="PNG")
    return out.getvalue()


async def upload(client: httpx.AsyncClient, storage: FakeStorage, purpose: str, body: bytes, content_type: str = "image/png") -> str:
    ticket = ok(await client.post("/api/media/uploads/", json={
        "purpose": purpose, "content_type": content_type, "size_bytes": len(body),
    }), 201)
    storage.put(ticket["upload_url"], size_bytes=len(body), content_type=content_type, body=body)
    ok(await client.post(f"/api/media/{ticket['id']}/complete/"))
    return ticket["id"]


async def shop(client: httpx.AsyncClient, storage: FakeStorage, session_factory) -> dict:
    """Admin builds the mug, then a customer signs in on the same client."""
    admin = await register(client, "shop-admin@example.com")
    await make_admin(session_factory, admin["id"])
    product = await build_mug(client, storage)
    await client.post("/api/auth/logout/")
    await register(client, "customer@example.com")
    variant = product["variants"][0]
    colors = {c["name"]: c["id"] for c in variant["colors"]}
    return {"product": product, "variant_id": variant["id"], "black": colors["Qora"], "red": colors["Qizil"]}


def document(*layers: dict) -> dict:
    return {"version": 1, "layers": list(layers)}


async def cart_item(
    client: httpx.AsyncClient, storage: FakeStorage, s: dict, files: list[tuple[str, str, bytes]], *layers: dict,
    expected: str, color: str = "black",
) -> httpx.Response:
    uploaded = [{"area": area, "method": method, "media_id": await upload(client, storage, "print", body)}
                for area, method, body in files]
    mockup = await upload(client, storage, "design", png((64, 64), (0, 0, 64, 64, (10, 10, 10, 255))))
    return await client.post("/api/cart/items/", json={
        "variant_id": s["variant_id"], "color_id": s[color], "quantity": 2, "document": document(*layers),
        "files": uploaded, "mockups": [mockup], "expected_unit_price": expected,
    })


# ── Designs ───────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_design_autosave_prices_and_versions(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)

    created = ok(await client.post("/api/studio/designs/", json={
        "variant_id": s["variant_id"], "color_id": s["red"], "document": document(UV_LAYER), "areas_cm2": {"uv": "120"},
    }), 201)
    assert created["version"] == 1 and created["product_slug"] == "krujka"
    # 149 000 base + 5 000 red + UV 100–500 cm² tier 1 000
    assert Decimal(created["quote"]["unit_price"]) == Decimal("155000")
    assert created["issues"] == []

    saved = ok(await client.put(f"/api/studio/designs/{created['id']}/", json={
        "variant_id": s["variant_id"], "color_id": s["black"], "document": document(UV_LAYER), "areas_cm2": {"uv": "40"},
        "version": 1,
    }))
    stale = await client.put(f"/api/studio/designs/{created['id']}/", json={
        "variant_id": s["variant_id"], "color_id": s["black"], "document": document(), "version": 1,
    })

    assert saved["version"] == 2 and Decimal(saved["quote"]["unit_price"]) == Decimal("149000")
    assert stale.status_code == 409 and "versiya 2" in stale.json()["detail"]
    listed = ok(await client.get("/api/studio/designs/"))
    assert [d["id"] for d in listed] == [created["id"]] and listed[0]["color_name"] == "Qora"
    # Designing on a shape locks it for the admin.
    async with session_factory() as session:
        shape = await session.get(Shape, s["product"]["shapes"][0]["id"])
        assert shape.locked_at is not None


@pytest.mark.asyncio
async def test_design_reports_issues_without_blocking_the_save(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    outside = {**UV_LAYER, "x_mm": 220}
    engrave = {**UV_LAYER, "id": "l2", "method": "engrave", "x_mm": 125, "y_mm": 40}
    unplaced = {**UV_LAYER, "id": "l3", "area": None}

    design = ok(await client.post("/api/studio/designs/", json={
        "variant_id": s["variant_id"], "color_id": s["black"], "document": document(outside, engrave, unplaced),
    }), 201)

    # Sticking out of the zone isn't an issue: the print file is cropped to it.
    assert any("bu usul yo'q" in issue for issue in design["issues"])  # the variant has UV only
    assert any("bitta usulda" in issue for issue in design["issues"])  # UV and engraving mixed
    assert len(design["issues"]) == 2  # the unplaced layer is fine: it just isn't printed


@pytest.mark.asyncio
async def test_design_keeps_the_studios_five_views(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    # "Saqlash" sends the five views with the design; "Dizaynlarim" shows them
    # first one first. A save without them keeps the saved ones.
    s = await shop(client, storage, session_factory)
    body = {"variant_id": s["variant_id"], "color_id": s["black"], "document": document(UV_LAYER)}
    created = ok(await client.post("/api/studio/designs/", json=body), 201)
    assert ok(await client.get("/api/studio/designs/"))[0]["previews"] == []

    views = [await upload(client, storage, "design", png((64, 64), (0, 0, 64, 64, (i * 40, 0, 0, 255)))) for i in range(5)]
    saved = ok(await client.put(f"/api/studio/designs/{created['id']}/", json={**body, "previews": views, "version": 1}))
    ok(await client.put(f"/api/studio/designs/{created['id']}/", json={**body, "version": 2}))
    [listed] = ok(await client.get("/api/studio/designs/"))
    print_file = await upload(client, storage, "print", png((10, 10)))
    wrong = await client.put(f"/api/studio/designs/{created['id']}/", json={**body, "previews": [print_file], "version": 3})

    assert len(listed["previews"]) == 5 and all(url.startswith("https://media.test/designs/u") for url in listed["previews"])
    assert listed["preview_url"] == listed["previews"][0] == saved["preview_url"]
    assert wrong.status_code == 422


@pytest.mark.asyncio
async def test_design_images_must_be_the_customers_own(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    mine = await upload(client, storage, "design", png((10, 10)))
    image_layer = {
        "id": "img", "area": "wrap", "method": "uv", "kind": "image", "x_mm": 50, "y_mm": 40, "w_mm": 40, "h_mm": 40,
        "image": {"media_id": mine, "url": "https://evil.example/x.png", "px_w": 10, "px_h": 10},
    }

    design = ok(await client.post("/api/studio/designs/", json={
        "variant_id": s["variant_id"], "color_id": s["black"], "document": document(image_layer),
    }), 201)
    await client.post("/api/auth/logout/")
    await register(client, "other@example.com")
    stolen = await client.post("/api/studio/designs/", json={
        "variant_id": s["variant_id"], "color_id": s["black"], "document": document(image_layer),
    })

    # The URL always comes from the media record.
    assert design["document"]["layers"][0]["image"]["url"].startswith("https://media.test/designs/u")
    assert stolen.status_code == 422
    assert (await client.get(f"/api/studio/designs/{design['id']}/")).status_code == 404


def image_layer(media_id: str) -> dict:
    return {
        "id": "img", "area": "wrap", "method": "uv", "kind": "image",
        "x_mm": 50, "y_mm": 40, "w_mm": 2, "h_mm": 2,
        "image": {"media_id": media_id, "url": "", "px_w": 10, "px_h": 10},
    }


@pytest.mark.asyncio
async def test_studio_may_use_catalog_design_assets(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    await client.post("/api/auth/logout/")
    ok(await client.post("/api/auth/login/", json={"email": "shop-admin@example.com", "password": "password123"}))
    sticker = await upload(client, storage, "catalog", png((10, 10)))
    leftover = await upload(client, storage, "catalog", png((10, 10)))
    ok(await client.post("/api/admin/catalog/assets/", json={
        "media_id": sticker, "name": "Yurak", "category": "love", "type": "sticker",
    }), 201)
    await client.post("/api/auth/logout/")
    ok(await client.post("/api/auth/login/", json={"email": "customer@example.com", "password": "password123"}))

    design = ok(await client.post("/api/studio/designs/", json={
        "variant_id": s["variant_id"], "color_id": s["black"], "document": document(image_layer(sticker)),
    }), 201)
    assert design["document"]["layers"][0]["image"]["url"].startswith("https://media.test/catalog/")

    added = await cart_item(
        client, storage, s, [("wrap", "uv", png(UV_PX, (0, 0, 10, 10, (0, 0, 0, 255))))],
        image_layer(sticker), expected="149000",
    )
    assert added.status_code == 201, added.text

    leftover_ok = ok(await client.post("/api/studio/designs/", json={
        "variant_id": s["variant_id"], "color_id": s["black"], "document": document(image_layer(leftover)),
    }), 201)
    assert leftover_ok["document"]["layers"][0]["image"]["url"].startswith("https://media.test/catalog/")


# ── Cart ──────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_cart_prices_from_the_print_files(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    # 1500 × 800 px painted at 300 DPI ≈ 127×68 mm ≈ 86 cm² → tier 0–100 → +0
    small = png(UV_PX, (500, 60, 2000, 860, (200, 30, 40, 255)))
    # the whole area: 226 × 79 mm = 178.54 cm² → tier 100–500 → +1 000
    full = png(UV_PX, (0, 0, *UV_PX, (200, 30, 40, 255)))

    wrong = await cart_item(client, storage, s, [("wrap", "uv", full)], UV_LAYER, expected="149000")
    added = await cart_item(client, storage, s, [("wrap", "uv", small)], UV_LAYER, expected="149000")

    assert wrong.status_code == 409
    assert Decimal(wrong.json()["quote"]["unit_price"]) == Decimal("150000")
    assert added.status_code == 201, added.text
    item = added.json()["items"][0]
    assert Decimal(item["unit_price"]) == Decimal("149000") and item["quantity"] == 2
    assert Decimal(added.json()["subtotal"]) == Decimal("298000")
    assert item["files"][0]["width_px"] == 2669 and Decimal(item["files"][0]["painted_cm2"]) < 100
    assert item["mockups"][0].startswith("https://media.test/designs/u")


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("body", "message"),
    [
        (png((2000, 933), (0, 0, 10, 10, (0, 0, 0, 255))), "o'lchami"),
        (png(UV_PX, (0, 0, 10, 10, (0, 0, 0, 255))) .replace(b"IHDR", b"IHDX"), "o'qib bo'lmadi"),
    ],
    ids=["wrong-size", "not-a-png"],
)
async def test_bad_print_files_are_rejected(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession],
    body: bytes, message: str,
) -> None:
    s = await shop(client, storage, session_factory)
    if message == "o'qib bo'lmadi":
        # A broken PNG doesn't get past the upload itself any more.
        ticket = ok(await client.post("/api/media/uploads/", json={
            "purpose": "print", "content_type": "image/png", "size_bytes": len(body),
        }), 201)
        storage.put(ticket["upload_url"], size_bytes=len(body), content_type="image/png", body=body)
        response = await client.post(f"/api/media/{ticket['id']}/complete/")
    else:
        response = await cart_item(client, storage, s, [("wrap", "uv", body)], UV_LAYER, expected="149000")

    assert response.status_code == 422 and message in response.json()["detail"]


@pytest.mark.asyncio
async def test_engraving_files_stay_in_the_zone_and_mono(
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
    layer = {**UV_LAYER, "method": "engrave", "x_mm": 125, "y_mm": 40, "text": {**UV_LAYER["text"], "color": "#000000"}}
    # engraving zone at 600 DPI starts at x = 75 mm ≈ 1772 px, y = 15 mm ≈ 354 px
    inside_black = png(ENGRAVE_PX, (2000, 500, 3000, 900, (0, 0, 0, 255)))
    outside = png(ENGRAVE_PX, (100, 500, 600, 900, (0, 0, 0, 255)))
    red = png(ENGRAVE_PX, (2000, 500, 3000, 900, (200, 0, 0, 255)))

    in_zone = await cart_item(client, storage, s, [("wrap", "engrave", inside_black)], layer, expected="149000")
    out_of_zone = await cart_item(client, storage, s, [("wrap", "engrave", outside)], layer, expected="149000")
    coloured = await cart_item(client, storage, s, [("wrap", "engrave", red)], layer, expected="149000")
    coloured_text = await cart_item(
        client, storage, s, [("wrap", "engrave", inside_black)], {**layer, "text": UV_LAYER["text"]}, expected="149000"
    )

    assert in_zone.status_code == 201, in_zone.text
    assert out_of_zone.status_code == 422 and "zonadan tashqarida" in out_of_zone.json()["detail"]
    assert coloured.status_code == 422 and "bir rangli" in coloured.json()["detail"]
    assert coloured_text.status_code == 422 and "rang bo'lmaydi" in coloured_text.json()["detail"]


@pytest.mark.asyncio
async def test_files_must_match_the_design(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    body = png(UV_PX, (500, 60, 900, 400, (0, 0, 0, 255)))

    empty = await cart_item(client, storage, s, [("wrap", "uv", body)], {**UV_LAYER, "area": None}, expected="149000")
    extra = await cart_item(
        client, storage, s, [("wrap", "uv", body), ("wrap", "engrave", body)], UV_LAYER, expected="149000"
    )

    assert empty.status_code == 422 and "bo'sh" in empty.json()["detail"]
    assert extra.status_code == 422


# ── Checkout and orders ───────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_checkout_copies_the_package_into_the_order(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    await client.post("/api/auth/logout/")
    await client.post("/api/auth/login/", json={"email": "shop-admin@example.com", "password": "password123"})
    ok(await client.patch(f"{A}/variants/{s['variant_id']}/", json={"white_underbase": True}))
    await client.post("/api/auth/logout/")
    await client.post("/api/auth/login/", json={"email": "customer@example.com", "password": "password123"})
    body = png(UV_PX, (500, 60, 2000, 860, (200, 30, 40, 255)))
    ok(await cart_item(client, storage, s, [("wrap", "uv", body)], UV_LAYER, expected="149000"), 201)

    checkout = await client.post("/api/checkout/", json={
        "contact_name": "Test", "contact_phone": "+998901234567", "delivery_method": "PICKUP",
    })

    assert checkout.status_code == 200, checkout.text
    number = checkout.json()["order_number"]
    assert number.isdigit() and len(number) == 7  # 0000001, 0000002…
    [line] = checkout.json()["order"]["items"]
    assert line["product_name"] == "Krujka" and line["variant_name"] == "Xameleon" and line["color_name"] == "Qora"
    assert line["files"][0]["url"] == f"https://media.test/orders/{number}/1/wrap-uv.png"
    assert line["mockups"][0].startswith(f"https://media.test/orders/{number}/1/kadr-1.")
    assert line["underbase"][0]["url"] == f"https://media.test/orders/{number}/1/wrap-oq-taglik.png"
    mask = Image.open(io.BytesIO(storage.bodies[f"orders/{number}/1/wrap-oq-taglik.png"]))
    assert mask.getpixel((1000, 400)) == (255, 255, 255, 255) and mask.getpixel((10, 10))[3] == 0
    assert line["placements"][0]["placement_note"] == "dastadan 12 mm"
    assert Decimal(checkout.json()["total_amount"]) == Decimal("298000")
    assert ok(await client.get("/api/cart/"))["is_empty"] is True


@pytest.mark.asyncio
async def test_the_studios_five_views_reach_the_order_in_their_order(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    # The Studio sends five mockups per item (front, either side, back, from
    # above); the cart and the order show them as a gallery, first one first.
    s = await shop(client, storage, session_factory)
    body = png(UV_PX, (500, 60, 2000, 860, (200, 30, 40, 255)))
    files = [{"area": "wrap", "method": "uv", "media_id": await upload(client, storage, "print", body)}]
    shots = [png((64, 64), (0, 0, 64, 64, (i * 40, 0, 0, 255))) for i in range(5)]
    views = [await upload(client, storage, "design", shot) for shot in shots]

    added = ok(await client.post("/api/cart/items/", json={
        "variant_id": s["variant_id"], "color_id": s["black"], "quantity": 1, "document": document(UV_LAYER),
        "files": files, "mockups": views, "expected_unit_price": "149000",
    }), 201)
    checkout = ok(await client.post("/api/checkout/", json={"contact_name": "Test", "delivery_method": "PICKUP"}))

    assert len(set(added["items"][0]["mockups"])) == 5
    number = checkout["order_number"]
    [line] = checkout["order"]["items"]
    assert line["mockups"] == [f"https://media.test/orders/{number}/1/kadr-{i}.png" for i in range(1, 6)]
    assert [storage.bodies[f"orders/{number}/1/kadr-{i}.png"] for i in range(1, 6)] == shots


@pytest.mark.asyncio
async def test_checkout_refuses_items_that_went_off_sale_or_changed_price(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    body = png(UV_PX, (500, 60, 2000, 860, (200, 30, 40, 255)))
    ok(await cart_item(client, storage, s, [("wrap", "uv", body)], UV_LAYER, expected="149000"), 201)
    order_form = {"contact_name": "Test", "delivery_method": "PICKUP"}

    async def as_admin(fn):
        await client.post("/api/auth/logout/")
        await client.post("/api/auth/login/", json={"email": "shop-admin@example.com", "password": "password123"})
        await fn()
        await client.post("/api/auth/logout/")
        await client.post("/api/auth/login/", json={"email": "customer@example.com", "password": "password123"})

    await as_admin(lambda: client.patch(f"{A}/colors/{s['black']}/", json={"is_available": False}))
    off_sale = await client.post("/api/checkout/", json=order_form)
    cart = ok(await client.get("/api/cart/"))
    await as_admin(lambda: client.patch(f"{A}/colors/{s['black']}/", json={"is_available": True}))
    await as_admin(lambda: client.patch(f"{A}/variants/{s['variant_id']}/", json={"base_price": "159000"}))
    repriced = await client.post("/api/checkout/", json=order_form)
    after = ok(await client.get("/api/cart/"))
    confirmed = await client.post("/api/checkout/", json=order_form)

    assert off_sale.status_code == 409 and "Sotuvda yo'q" in off_sale.json()["detail"]
    assert cart["blocked"] is True
    assert repriced.status_code == 409 and Decimal(after["items"][0]["unit_price"]) == Decimal("159000")
    assert confirmed.status_code == 200 and Decimal(confirmed.json()["total_amount"]) == Decimal("318000")


@pytest.mark.asyncio
async def test_completed_orders_feed_the_gallery_and_analytics(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    body = png(UV_PX, (500, 60, 2000, 860, (200, 30, 40, 255)))
    ok(await cart_item(client, storage, s, [("wrap", "uv", body)], UV_LAYER, expected="149000"), 201)
    order = ok(await client.post("/api/checkout/", json={"contact_name": "Test", "delivery_method": "PICKUP"}))
    await client.post("/api/auth/logout/")
    await client.post("/api/auth/login/", json={"email": "shop-admin@example.com", "password": "password123"})
    item_id = order["order"]["items"][0]["id"]

    printed = ok(await client.patch(
        f"/api/orders/admin/orders/{order['order_id']}/items/{item_id}/", json={"production_status": "PRINTED"}
    ))
    ok(await client.patch(f"/api/orders/admin/orders/{order['order_id']}/", json={"status": "COMPLETED"}))
    gallery = ok(await client.get("/api/gallery/"))
    analytics = ok(await client.get("/api/orders/analytics/", params={"days": 7}))

    assert printed["items"][0]["production_status"] == "PRINTED"
    assert gallery[0]["preview_image_url"].endswith("/1/kadr-1.png")
    [top] = analytics["top_products"]
    assert top["units_sold"] == 2 and Decimal(top["revenue"]) == Decimal("298000")
