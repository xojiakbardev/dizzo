"""Per-size print scaling: 40 x 40 cm is the maximum, on the largest size.

A shape's print area is measured for the biggest garment; every smaller
size prints a proportionally smaller picture (SizeItem.print_scale), in a
box centred on the same anchor. That one number has to mean the same thing
everywhere — the box the customer designs in, the print file the factory
gets, and the price — so these tests walk it through all three.

The mug from build_mug stands in for the garment: its "wrap" area is
226 x 79 mm and its UV zone is the whole of it, which makes the arithmetic
easy to read. Its own sizes are given here; a mug in the shop has none, and
the last test checks that nothing about it changed.
"""

from decimal import Decimal

import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from tests.conftest import FakeStorage
from tests.test_catalog import A, build_mug, color_id, ok
from tests.test_sizes import as_admin, as_customer, set_sizes
from tests.test_studio import UV_LAYER, UV_PX, document, png, shop, upload

# 3XL prints the area whole, S three quarters of it (the seeded defaults).
SCALED = [
    {"label": "3XL", "surcharge": "0", "is_available": True, "print_scale": "1.00"},
    {"label": "S", "surcharge": "0", "is_available": True, "print_scale": "0.75"},
]
# 226 x 79 mm at 0.75 is 169.50 x 59.25 mm, which at 300 DPI is this file.
S_PX = (2002, 700)
# A design 200 mm wide: inside the 226 mm area, far outside the 169.5 mm of S.
WIDE_LAYER = {**UV_LAYER, "id": "l2", "w_mm": 200, "h_mm": 20}


async def add(
    client: httpx.AsyncClient, storage: FakeStorage, s: dict, *, size: str | None, expected: str,
    layer: dict = UV_LAYER, px: tuple[int, int] = UV_PX,
) -> httpx.Response:
    """"Savatga qo'shish" with one UV print file of `px`, painted well under
    100 cm² so the mug's first price tier (0 so'm) applies."""
    body = png(px, (int(px[0] * 0.2), int(px[1] * 0.1), int(px[0] * 0.75), int(px[1] * 0.85), (200, 30, 40, 255)))
    files = [{"area": "wrap", "method": "uv", "media_id": await upload(client, storage, "print", body)}]
    mockup = await upload(client, storage, "design", png((64, 64), (0, 0, 64, 64, (10, 10, 10, 255))))
    return await client.post("/api/cart/items/", json={
        "variant_id": s["variant_id"], "color_id": s["black"], "quantity": 1, "document": document(layer),
        "files": files, "mockups": [mockup], "expected_unit_price": expected,
        **({"size": size} if size is not None else {}),
    })


@pytest.mark.asyncio
async def test_the_print_scale_round_trips_through_the_admin_api(
    admin_client: httpx.AsyncClient, storage: FakeStorage
) -> None:
    product = await build_mug(admin_client, storage)
    variant_id = product["variants"][0]["id"]

    saved = await set_sizes(admin_client, variant_id, SCALED)
    detail = ok(await admin_client.get("/api/catalog/products/krujka/"))

    assert [s["print_scale"] for s in saved["variants"][0]["sizes"]] == ["1.00", "0.75"]
    # The storefront carries it too: the size picker shows what each size prints.
    assert [s["print_scale"] for s in detail["variants"][0]["sizes"]] == ["1.00", "0.75"]
    # A size saved without one prints the area whole, exactly as before.
    plain = await set_sizes(admin_client, variant_id, [{"label": "M", "surcharge": "0", "is_available": True}])
    assert plain["variants"][0]["sizes"][0]["print_scale"] == "1.00"


@pytest.mark.asyncio
@pytest.mark.parametrize("scale", ["0", "0.00", "1.01", "2", "-0.5"])
async def test_a_print_scale_outside_zero_to_one_is_refused(
    admin_client: httpx.AsyncClient, storage: FakeStorage, scale: str
) -> None:
    product = await build_mug(admin_client, storage)
    variant_id = product["variants"][0]["id"]

    response = await admin_client.put(f"{A}/variants/{variant_id}/sizes/", json={
        "sizes": [{"label": "S", "surcharge": "0", "is_available": True, "print_scale": scale}],
    })

    assert response.status_code == 422, response.text


@pytest.mark.asyncio
async def test_a_design_that_fits_the_largest_size_is_refused_for_a_smaller_one(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    await as_admin(client)
    await set_sizes(client, s["variant_id"], SCALED)
    await as_customer(client)

    biggest = await add(client, storage, s, size="3XL", expected="149000", layer=WIDE_LAYER)
    smallest = await add(client, storage, s, size="S", expected="149000", layer=WIDE_LAYER, px=S_PX)

    assert biggest.status_code == 201, biggest.text
    # Refused, never quietly cropped: the customer designed inside the box
    # the Studio drew and has to be able to believe it.
    assert smallest.status_code == 422
    detail = smallest.json()["detail"]
    assert "169.50×59.25 mm" in detail and "S" in detail


@pytest.mark.asyncio
async def test_the_print_file_for_a_smaller_size_is_a_smaller_sheet(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    await as_admin(client)
    await set_sizes(client, s["variant_id"], SCALED)
    await as_customer(client)

    biggest = await add(client, storage, s, size="3XL", expected="149000", px=UV_PX)
    full_sheet = await add(client, storage, s, size="S", expected="149000", px=UV_PX)
    smallest = await add(client, storage, s, size="S", expected="149000", px=S_PX)

    assert biggest.status_code == 201, biggest.text
    # The sheet cut for 3XL is not the sheet size S prints on.
    assert full_sheet.status_code == 422
    assert f"{S_PX[0]}×{S_PX[1]} px" in full_sheet.json()["detail"]
    assert smallest.status_code == 201, smallest.text
    assert S_PX[0] * S_PX[1] < UV_PX[0] * UV_PX[1]
    files = {item["size"]: item["files"][0] for item in smallest.json()["items"]}
    assert (files["3XL"]["width_px"], files["3XL"]["height_px"]) == UV_PX
    assert (files["S"]["width_px"], files["S"]["height_px"]) == S_PX
    # And the factory is told the millimetres of the size ordered.
    assert Decimal(files["S"]["painted_cm2"]) < Decimal(files["3XL"]["painted_cm2"])


@pytest.mark.asyncio
async def test_a_smaller_size_is_never_charged_for_more_ink_than_it_can_print(
    admin_client: httpx.AsyncClient, storage: FakeStorage
) -> None:
    product = await build_mug(admin_client, storage)
    variant_id = product["variants"][0]["id"]
    # One tier boundary between what S can print (100.43 cm²) and what the
    # whole area holds (178.54 cm²), so the two sizes land either side of it.
    ok(await admin_client.put(f"{A}/products/{product['id']}/price-tiers/uv/", json={"tiers": [
        {"min_cm2": "0", "max_cm2": "120", "surcharge": "0"},
        {"min_cm2": "120", "max_cm2": None, "surcharge": "3000"},
    ]}))
    await set_sizes(admin_client, variant_id, SCALED)

    def body(size: str) -> dict:
        return {
            "variant_id": variant_id, "color_id": color_id(product, "Qora"), "quantity": 1, "size": size,
            "areas_cm2": {"uv": "178.54"},  # a design covering the whole area
        }

    biggest = ok(await admin_client.post("/api/catalog/quote/", json=body("3XL")))
    smallest = ok(await admin_client.post("/api/catalog/quote/", json=body("S")))

    assert Decimal(biggest["print_scale"]) == Decimal("1.00")
    assert Decimal(biggest["unit_price"]) == Decimal("152000")  # 149 000 + 3 000
    # S can only print 169.50 x 59.25 mm = 100.43 cm², so that is what it pays for.
    assert Decimal(smallest["print_scale"]) == Decimal("0.75")
    assert Decimal(smallest["print_area_cm2"]["uv"]) == Decimal("100.43")
    assert Decimal(smallest["unit_price"]) == Decimal("149000")
    assert Decimal(smallest["unit_price"]) < Decimal(biggest["unit_price"])


@pytest.mark.asyncio
async def test_a_size_change_in_the_cart_is_refused_when_the_design_no_longer_fits(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    await as_admin(client)
    await set_sizes(client, s["variant_id"], SCALED)
    await as_customer(client)
    added = ok(await add(client, storage, s, size="3XL", expected="149000", layer=WIDE_LAYER), 201)
    item = added["items"][0]["uuid"]

    refused = await client.patch(f"/api/cart/items/{item}/", json={"size": "S"})

    assert refused.status_code == 422
    assert "169.50×59.25 mm" in refused.json()["detail"]
    # The item is untouched: still 3XL, still on its own sheet.
    kept = ok(await client.get("/api/cart/"))["items"][0]
    assert kept["size"] == "3XL" and (kept["files"][0]["width_px"], kept["files"][0]["height_px"]) == UV_PX


@pytest.mark.asyncio
async def test_a_size_change_in_the_cart_re_cuts_the_print_file_and_re_prices_it(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    await as_admin(client)
    await set_sizes(client, s["variant_id"], SCALED)
    await as_customer(client)
    added = ok(await add(client, storage, s, size="3XL", expected="149000"), 201)
    item = added["items"][0]["uuid"]
    was = added["items"][0]["files"][0]

    changed = ok(await client.patch(f"/api/cart/items/{item}/", json={"size": "S"}))

    now = changed["items"][0]["files"][0]
    assert changed["items"][0]["size"] == "S"
    # The sheet is the one size S prints on, and what is on it was measured again.
    assert (now["width_px"], now["height_px"]) == S_PX
    assert (was["width_px"], was["height_px"]) == UV_PX
    assert Decimal(now["painted_cm2"]) <= Decimal(was["painted_cm2"])
    assert changed["items"][0]["available"] is True
    # Quantity still travels on its own.
    assert ok(await client.patch(f"/api/cart/items/{item}/", json={"quantity": 3}))["items"][0]["quantity"] == 3


@pytest.mark.asyncio
async def test_a_variant_without_sizes_is_untouched_by_print_scaling(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)

    added = await add(client, storage, s, size=None, expected="149000")
    quoted = ok(await client.post("/api/catalog/quote/", json={
        "variant_id": s["variant_id"], "color_id": s["black"], "quantity": 1,
        "areas_cm2": {"uv": "600"},  # more than the area holds: nothing caps it
    }))

    assert added.status_code == 201, added.text
    item = added.json()["items"][0]
    # The whole area, as it always was, and no scale in the way.
    assert (item["files"][0]["width_px"], item["files"][0]["height_px"]) == UV_PX
    assert item["size"] == "" and Decimal(item["quote"]["print_scale"]) == Decimal("1.00")
    assert item["quote"]["print_area_cm2"] == {}
    assert Decimal(quoted["unit_price"]) == Decimal("151500")  # the 500+ cm² tier, +2 500
