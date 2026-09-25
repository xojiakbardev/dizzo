"""Clothing sizes: an ordered list on a variant, chosen in the Studio,
carried by the cart item and copied to the order line.

Everything without sizes (the mug these tests start from) keeps working
untouched — that is checked here too, since the same code prices both.
"""

from decimal import Decimal

import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from tests.conftest import FakeStorage
from tests.test_catalog import A, build_mug, ok
from tests.test_studio import UV_LAYER, UV_PX, document, png, shop, upload

# Two sizes on the mug's variant: "M" as it comes, "XXL" for 10 000 more.
SIZES = [
    {"label": "M", "surcharge": "0", "is_available": True},
    {"label": "XXL", "surcharge": "10000", "is_available": True},
]


async def set_sizes(client: httpx.AsyncClient, variant_id: int, sizes: list[dict]) -> dict:
    return ok(await client.put(f"{A}/variants/{variant_id}/sizes/", json={"sizes": sizes}))


async def as_admin(client: httpx.AsyncClient, email: str = "shop-admin@example.com"):
    await client.post("/api/auth/logout/")
    await client.post("/api/auth/login/", json={"email": email, "password": "password123"})


async def as_customer(client: httpx.AsyncClient):
    await client.post("/api/auth/logout/")
    await client.post("/api/auth/login/", json={"email": "customer@example.com", "password": "password123"})


async def add_item(
    client: httpx.AsyncClient, storage: FakeStorage, s: dict, *, size: str | None, expected: str, quantity: int = 1
) -> httpx.Response:
    """The Studio's "Savatga qo'shish" with one UV file well under 100 cm²
    (tier 0–100, no method surcharge)."""
    body = png(UV_PX, (500, 60, 2000, 860, (200, 30, 40, 255)))
    files = [{"area": "wrap", "method": "uv", "media_id": await upload(client, storage, "print", body)}]
    mockup = await upload(client, storage, "design", png((64, 64), (0, 0, 64, 64, (10, 10, 10, 255))))
    return await client.post("/api/cart/items/", json={
        "variant_id": s["variant_id"], "color_id": s["black"], "quantity": quantity, "document": document(UV_LAYER),
        "files": files, "mockups": [mockup], "expected_unit_price": expected,
        **({"size": size} if size is not None else {}),
    })


@pytest.mark.asyncio
async def test_sizes_are_one_ordered_list_on_the_variant(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await build_mug(admin_client, storage)
    variant_id = product["variants"][0]["id"]
    assert product["variants"][0]["sizes"] == []  # nothing has sizes until they are set

    saved = await set_sizes(admin_client, variant_id, SIZES)
    reordered = await set_sizes(admin_client, variant_id, [SIZES[1], {**SIZES[0], "is_available": False}])
    duplicate = await admin_client.put(f"{A}/variants/{variant_id}/sizes/", json={
        "sizes": [SIZES[0], {**SIZES[0], "label": "m"}],
    })

    assert [s["label"] for s in saved["variants"][0]["sizes"]] == ["M", "XXL"]
    assert Decimal(saved["variants"][0]["sizes"][1]["surcharge"]) == Decimal("10000")
    # Order, availability and removal are all one save of the whole list.
    assert [(s["label"], s["is_available"]) for s in reordered["variants"][0]["sizes"]] == [("XXL", True), ("M", False)]
    assert duplicate.status_code == 422
    # The cheapest size counts towards "boshlang'ich narx"; the mug's is 0.
    assert Decimal(reordered["variants"][0]["base_price"]) == Decimal("149000")
    listed = ok(await admin_client.get("/api/catalog/products/"))
    assert Decimal(listed[0]["from_price"]) == Decimal("159000")  # only XXL (+10 000) is in stock


@pytest.mark.asyncio
async def test_the_storefront_and_the_quote_carry_the_sizes(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await build_mug(admin_client, storage)
    variant_id = product["variants"][0]["id"]
    color = next(c["id"] for c in product["variants"][0]["colors"] if c["name"] == "Qora")
    await set_sizes(admin_client, variant_id, SIZES)

    detail = ok(await admin_client.get("/api/catalog/products/krujka/"))
    quoted = ok(await admin_client.post("/api/catalog/quote/", json={
        "variant_id": variant_id, "color_id": color, "quantity": 2, "size": "XXL",
    }))
    unknown = await admin_client.post("/api/catalog/quote/", json={
        "variant_id": variant_id, "color_id": color, "quantity": 1, "size": "XS",
    })

    assert detail["variants"][0]["sizes"] == [
        {"label": "M", "surcharge": "0.00", "is_available": True, "print_scale": "1.00"},
        {"label": "XXL", "surcharge": "10000.00", "is_available": True, "print_scale": "1.00"},
    ]
    assert quoted["size"] == "XXL" and Decimal(quoted["size_surcharge"]) == Decimal("10000")
    assert Decimal(quoted["unit_price"]) == Decimal("159000") and Decimal(quoted["total"]) == Decimal("318000")
    assert unknown.status_code == 422 and "o'lchami bu variantda yo'q" in unknown.json()["detail"]


@pytest.mark.asyncio
async def test_the_cart_refuses_a_missing_or_unknown_size(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    await as_admin(client)
    await set_sizes(client, s["variant_id"], SIZES)
    await as_customer(client)

    missing = await add_item(client, storage, s, size=None, expected="149000")
    empty = await add_item(client, storage, s, size="", expected="149000")
    unknown = await add_item(client, storage, s, size="XS", expected="149000")
    added = await add_item(client, storage, s, size="XXL", expected="159000")

    assert missing.status_code == 422 and "o'lchamni tanlang" in missing.json()["detail"].lower()
    assert empty.status_code == 422
    assert unknown.status_code == 422 and "XS" in unknown.json()["detail"]
    assert added.status_code == 201, added.text
    item = added.json()["items"][0]
    assert item["size"] == "XXL" and Decimal(item["unit_price"]) == Decimal("159000")
    assert Decimal(item["quote"]["size_surcharge"]) == Decimal("10000")


@pytest.mark.asyncio
async def test_a_product_without_sizes_keeps_working_and_takes_none(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)

    plain = await add_item(client, storage, s, size=None, expected="149000")
    with_size = await add_item(client, storage, s, size="M", expected="149000")

    assert plain.status_code == 201, plain.text
    assert plain.json()["items"][0]["size"] == ""
    assert with_size.status_code == 422 and "o'lcham tanlanmaydi" in with_size.json()["detail"]


@pytest.mark.asyncio
async def test_the_chosen_size_reaches_the_order(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    await as_admin(client)
    await set_sizes(client, s["variant_id"], SIZES)
    await as_customer(client)
    ok(await add_item(client, storage, s, size="XXL", expected="159000", quantity=2), 201)

    checkout = ok(await client.post("/api/checkout/", json={"contact_name": "Test", "delivery_method": "PICKUP"}))

    [line] = checkout["order"]["items"]
    assert line["size"] == "XXL" and line["color_name"] == "Qora"
    assert Decimal(checkout["total_amount"]) == Decimal("318000")
    # Whoever produces the order reads it from the order line itself.
    detail = ok(await client.get(f"/api/orders/{checkout['order_id']}/"))
    assert detail["items"][0]["size"] == "XXL"


@pytest.mark.asyncio
async def test_a_size_that_runs_out_blocks_the_checkout(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    await as_admin(client)
    await set_sizes(client, s["variant_id"], SIZES)
    await as_customer(client)
    ok(await add_item(client, storage, s, size="XXL", expected="159000"), 201)

    await as_admin(client)
    await set_sizes(client, s["variant_id"], [SIZES[0], {**SIZES[1], "is_available": False}])
    await as_customer(client)
    cart = ok(await client.get("/api/cart/"))
    blocked = await client.post("/api/checkout/", json={"contact_name": "Test", "delivery_method": "PICKUP"})

    assert cart["items"][0]["available"] is False and cart["blocked"] is True
    assert blocked.status_code == 409 and "Sotuvda yo'q" in blocked.json()["detail"]
