from decimal import Decimal

import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.catalog import PrintArea
from tests.conftest import FakeStorage, make_admin, register
from tests.test_catalog import A, ok
from tests.test_studio import png, upload

# A 100 × 50 mm plate with two 40 × 40 areas side by side: "left" at x 0,
# "right" at x 60. UV zone on the left: x 5, 20 mm wide.
LEFT_UV = {"method": "uv", "zone_x_mm": "5", "zone_y_mm": "0", "zone_w_mm": "20", "zone_h_mm": "40", "colors_allowed": True, "dpi": 300}
AREA_PX = 472  # 40 mm at 300 DPI


def area(product: dict, key: str) -> dict:
    return next(a for a in product["shapes"][0]["areas"] if a["key"] == key)


async def plate(client: httpx.AsyncClient) -> dict:
    product = ok(await client.post(f"{A}/products/", json={"slug": "plitka", "name": "Plitka"}), 201)
    pid = product["id"]
    product = ok(await client.post(f"{A}/products/{pid}/shapes/", json={
        "name": "Plitka", "kind": "plane", "dims": {"width_mm": "100", "height_mm": "50", "sides": 1},
    }), 201)
    shape_id = product["shapes"][0]["id"]
    for key, x in (("left", "0"), ("right", "60")):
        product = ok(await client.post(f"{A}/shapes/{shape_id}/areas/", json={
            "key": key, "name": key.title(), "width_mm": "40", "height_mm": "40", "anchor": {"side": "front", "x_mm": x, "y_mm": "5"},
        }), 201)
    return ok(await client.put(f"{A}/areas/{area(product, 'left')['id']}/methods/", json={"methods": [LEFT_UV]}))


@pytest.mark.asyncio
async def test_pairing_mirrors_the_partner(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await plate(admin_client)

    product = ok(await admin_client.put(f"{A}/areas/{area(product, 'left')['id']}/pair/", json={"pair_key": "right"}))

    left, right = area(product, "left"), area(product, "right")
    assert (left["pair_key"], right["pair_key"]) == ("right", "left")
    assert left["pair_mirror"] is True and right["pair_mirror"] is True
    [zone] = right["methods"]
    assert Decimal(zone["zone_x_mm"]) == Decimal("15")  # 40 − 5 − 20
    assert Decimal(zone["zone_w_mm"]) == Decimal("20")


@pytest.mark.asyncio
async def test_partners_stay_in_sync(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await plate(admin_client)
    left_id = area(product, "left")["id"]
    ok(await admin_client.put(f"{A}/areas/{left_id}/pair/", json={"pair_key": "right", "mirror": False}))

    product = ok(await admin_client.put(f"{A}/areas/{left_id}/methods/", json={"methods": [{**LEFT_UV, "zone_x_mm": "10"}]}))
    assert Decimal(area(product, "right")["methods"][0]["zone_x_mm"]) == Decimal("10")  # not mirrored

    product = ok(await admin_client.put(f"{A}/areas/{left_id}/", json={
        "key": "chap", "name": "Chap", "width_mm": "35", "height_mm": "40", "anchor": {"side": "front", "x_mm": "0", "y_mm": "5"},
    }))
    right = area(product, "right")
    assert right["pair_key"] == "chap" and Decimal(right["width_mm"]) == Decimal("35")

    product = ok(await admin_client.delete(f"{A}/areas/{left_id}/"))
    assert area(product, "right")["pair_key"] is None


@pytest.mark.asyncio
async def test_pairing_checks_the_partner_fits(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await plate(admin_client)
    right_id = area(product, "right")["id"]
    ok(await admin_client.put(f"{A}/areas/{right_id}/", json={
        "key": "right", "name": "Right", "width_mm": "40", "height_mm": "40", "anchor": {"side": "front", "x_mm": "60", "y_mm": "5"},
    }))
    product = ok(await admin_client.put(f"{A}/areas/{area(product, 'left')['id']}/", json={
        "key": "left", "name": "Left", "width_mm": "45", "height_mm": "40", "anchor": {"side": "front", "x_mm": "0", "y_mm": "5"},
    }))

    response = await admin_client.put(f"{A}/areas/{area(product, 'left')['id']}/pair/", json={"pair_key": "right"})

    # 60 + 45 > 100: the partner would stick out of the plate.
    assert response.status_code == 422 and "Juft hudud" in response.json()["detail"]


@pytest.mark.asyncio
async def test_a_broken_pair_blocks_ready(
    admin_client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    product = await plate(admin_client)
    ok(await admin_client.put(f"{A}/areas/{area(product, 'left')['id']}/pair/", json={"pair_key": "right"}))
    async with session_factory() as session:
        (await session.get(PrintArea, area(product, "right")["id"])).width_mm = Decimal("30")
        await session.commit()

    response = await admin_client.post(f"{A}/shapes/{product['shapes'][0]['id']}/ready/")

    assert response.status_code == 422 and "farq qiladi" in response.json()["detail"]


async def sellable_plate(client: httpx.AsyncClient, session_factory) -> dict:
    admin = await register(client, "pair-admin@example.com")
    await make_admin(session_factory, admin["id"])
    product = await plate(client)
    ok(await client.put(f"{A}/areas/{area(product, 'left')['id']}/pair/", json={"pair_key": "right"}))
    ok(await client.post(f"{A}/shapes/{product['shapes'][0]['id']}/ready/"))
    ok(await client.put(f"{A}/products/{product['id']}/price-tiers/uv/", json={"tiers": [
        {"min_cm2": "0", "max_cm2": "1", "surcharge": "0"}, {"min_cm2": "1", "max_cm2": None, "surcharge": "500"},
    ]}))
    product = ok(await client.post(f"{A}/products/{product['id']}/variants/", json={
        "shape_id": product["shapes"][0]["id"], "name": "Oq", "base_price": "20000", "methods": ["uv"], "material": "plastic",
    }), 201)
    product = ok(await client.post(f"{A}/variants/{product['variants'][0]['id']}/colors/", json={"name": "Oq", "hex": "#ffffff"}), 201)
    await client.post("/api/auth/logout/")
    await register(client, "pair-customer@example.com")
    return {"variant_id": product["variants"][0]["id"], "color_id": product["variants"][0]["colors"][0]["id"]}


LOGO = {
    "id": "logo", "area": "left", "method": "uv", "kind": "text", "x_mm": 12, "y_mm": 20, "w_mm": 10, "h_mm": 8,
    "text": {"content": "M", "font": "Rubik", "size_mm": 6, "color": "#111111"},
}


@pytest.mark.asyncio
async def test_a_linked_pair_prints_on_both_sides(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    ids = await sellable_plate(client, session_factory)
    document = {"version": 1, "layers": [LOGO], "links": [{"source": "left", "target": "right"}]}
    # Left zone 5..25 mm → px 59..295; mirrored right zone 15..35 mm → px 177..413.
    left_file = await upload(client, storage, "print", png((AREA_PX, AREA_PX), (100, 180, 180, 280, (17, 17, 17, 255))))
    right_file = await upload(client, storage, "print", png((AREA_PX, AREA_PX), (290, 180, 370, 280, (17, 17, 17, 255))))
    mockup = await upload(client, storage, "design", png((32, 32), (0, 0, 32, 32, (0, 0, 0, 255))))
    item = {"variant_id": ids["variant_id"], "color_id": ids["color_id"], "document": document, "mockups": [mockup]}

    design = ok(await client.post("/api/studio/designs/", json={**ids, "document": document}), 201)
    one_side = await client.post("/api/cart/items/", json={
        **item, "files": [{"area": "left", "method": "uv", "media_id": left_file}], "expected_unit_price": "20000",
    })
    both = await client.post("/api/cart/items/", json={
        **item, "expected_unit_price": "20500",
        "files": [{"area": "left", "method": "uv", "media_id": left_file}, {"area": "right", "method": "uv", "media_id": right_file}],
    })

    assert design["issues"] == [] and design["document"]["links"] == [{"source": "left", "target": "right"}]
    assert one_side.status_code == 422 and "yetishmaydi" in one_side.json()["detail"]
    assert both.status_code == 201, both.text
    # Each side 80 × 100 px at 300 DPI ≈ 0.57 cm²; only both together reach the 1 cm² tier.
    assert Decimal(both.json()["items"][0]["unit_price"]) == Decimal("20500")


@pytest.mark.asyncio
async def test_link_rules(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    ids = await sellable_plate(client, session_factory)
    own_layer = {**LOGO, "id": "own", "area": "right"}

    with_own = ok(await client.post("/api/studio/designs/", json={**ids, "document": {
        "version": 1, "layers": [LOGO, own_layer], "links": [{"source": "left", "target": "right"}],
    }}), 201)
    twice = await client.post("/api/studio/designs/", json={**ids, "document": {
        "version": 1, "layers": [LOGO], "links": [{"source": "left", "target": "right"}, {"source": "right", "target": "left"}],
    }})

    assert any("alohida qatlam bo'lmaydi" in issue for issue in with_own["issues"])
    assert twice.status_code == 422


@pytest.mark.asyncio
async def test_same_size_areas_sync_without_mirroring(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    """A business card: front and back are the same size, not a pair; the
    back can show the front's design as it is."""
    admin = await register(client, "sync-admin@example.com")
    await make_admin(session_factory, admin["id"])
    product = ok(await client.post(f"{A}/products/", json={"slug": "karta", "name": "Karta"}), 201)
    product = ok(await client.post(f"{A}/products/{product['id']}/shapes/", json={
        "name": "Karta", "kind": "plane", "dims": {"width_mm": "90", "height_mm": "50", "sides": 2},
    }), 201)
    shape_id = product["shapes"][0]["id"]
    for key, side, size in (("front", "front", "50"), ("back", "back", "50"), ("strip", "front", "10")):
        product = ok(await client.post(f"{A}/shapes/{shape_id}/areas/", json={
            "key": key, "name": key.title(), "width_mm": "90", "height_mm": size, "anchor": {"side": side, "x_mm": "0", "y_mm": "0"},
        }), 201)
    zone = {"method": "uv", "zone_x_mm": "0", "zone_y_mm": "0", "zone_w_mm": "90", "colors_allowed": True, "dpi": 300}
    for key, h in (("front", "50"), ("back", "50"), ("strip", "10")):
        product = ok(await client.put(f"{A}/areas/{area(product, key)['id']}/methods/", json={"methods": [{**zone, "zone_h_mm": h}]}))
    ok(await client.post(f"{A}/shapes/{shape_id}/ready/"))
    ok(await client.put(f"{A}/products/{product['id']}/price-tiers/uv/", json={"tiers": [{"min_cm2": "0", "max_cm2": None, "surcharge": "0"}]}))
    product = ok(await client.post(f"{A}/products/{product['id']}/variants/", json={
        "shape_id": shape_id, "name": "Oq", "base_price": "10000", "methods": ["uv"], "material": "paper",
    }), 201)
    product = ok(await client.post(f"{A}/variants/{product['variants'][0]['id']}/colors/", json={"name": "Oq", "hex": "#ffffff"}), 201)
    await client.post("/api/auth/logout/")
    await register(client, "sync-customer@example.com")
    ids = {"variant_id": product["variants"][0]["id"], "color_id": product["variants"][0]["colors"][0]["id"]}
    logo = {**LOGO, "area": "front", "x_mm": 20, "y_mm": 25}
    back_file = await upload(client, storage, "print", png((1063, 591), (200, 250, 270, 340, (17, 17, 17, 255))))
    front_file = await upload(client, storage, "print", png((1063, 591), (200, 250, 270, 340, (17, 17, 17, 255))))
    mockup = await upload(client, storage, "design", png((32, 32), (0, 0, 32, 32, (0, 0, 0, 255))))

    synced = ok(await client.post("/api/studio/designs/", json={**ids, "document": {
        "version": 1, "layers": [logo], "links": [{"source": "front", "target": "back"}],
    }}), 201)
    wrong_size = ok(await client.post("/api/studio/designs/", json={**ids, "document": {
        "version": 1, "layers": [logo], "links": [{"source": "front", "target": "strip"}],
    }}), 201)
    one_to_two = await client.post("/api/studio/designs/", json={**ids, "document": {
        "version": 1, "layers": [logo], "links": [{"source": "front", "target": "back"}, {"source": "back", "target": "strip"}],
    }})
    cart = await client.post("/api/cart/items/", json={
        **ids, "document": synced["document"], "mockups": [mockup], "expected_unit_price": "10000",
        "files": [{"area": "front", "method": "uv", "media_id": front_file}, {"area": "back", "method": "uv", "media_id": back_file}],
    })

    assert synced["issues"] == []
    assert any("o'lchamlari farq qiladi" in issue for issue in wrong_size["issues"])
    assert one_to_two.status_code == 422  # a synced area can't feed another
    # Not mirrored: the back's file has the logo at the same place as the front's.
    assert cart.status_code == 201, cart.text
