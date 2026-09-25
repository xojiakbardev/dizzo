from datetime import UTC, datetime
from decimal import Decimal

import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.catalog import Shape
from tests.conftest import FakeStorage, register

A = "/api/admin/catalog"
UV_TIERS = [
    {"min_cm2": "0", "max_cm2": "100", "surcharge": "0"},
    {"min_cm2": "100", "max_cm2": "500", "surcharge": "1000"},
    {"min_cm2": "500", "max_cm2": None, "surcharge": "2500"},
]
UV_METHOD = {
    "method": "uv", "zone_x_mm": "0", "zone_y_mm": "0", "zone_w_mm": "226", "zone_h_mm": "79",
    "colors_allowed": True, "dpi": 300,
}
ENGRAVE_METHOD = {
    "method": "engrave", "zone_x_mm": "75", "zone_y_mm": "15", "zone_w_mm": "100", "zone_h_mm": "50",
    "max_width_mm": "100", "max_height_mm": "50", "min_font_mm": "2", "colors_allowed": False, "dpi": 600,
}


async def catalog_image(client: httpx.AsyncClient, storage: FakeStorage) -> str:
    ticket = (await client.post("/api/media/uploads/", json={"purpose": "catalog", "content_type": "image/png", "size_bytes": 64})).json()
    storage.put(ticket["upload_url"], size_bytes=64, content_type="image/png")
    assert (await client.post(f"/api/media/{ticket['id']}/complete/")).status_code == 200
    return ticket["id"]


def ok(response: httpx.Response, code: int = 200) -> dict:
    assert response.status_code == code, response.text
    return response.json()


async def build_mug(client: httpx.AsyncClient, storage: FakeStorage, *, with_colors: bool = True) -> dict:
    """A complete, sellable mug built only through the admin API."""
    cover = await catalog_image(client, storage)
    product = ok(await client.post(f"{A}/products/", json={"slug": "krujka", "name": "Krujka", "cover_media_id": cover}), 201)
    pid = product["id"]
    product = ok(await client.post(f"{A}/products/{pid}/shapes/", json={
        "name": "Krujka 330 ml", "kind": "cylinder",
        "dims": {"diameter_mm": "80", "height_mm": "95", "handle": True, "handle_gap_mm": "25"},
    }), 201)
    shape_id = product["shapes"][0]["id"]
    product = ok(await client.post(f"{A}/shapes/{shape_id}/areas/", json={
        "key": "wrap", "name": "O'rab olish", "width_mm": "226", "height_mm": "79",
        "anchor": {"start_mm": "0", "top_mm": "8"}, "placement_note": "dastadan 12 mm",
    }), 201)
    area_id = product["shapes"][0]["areas"][0]["id"]
    ok(await client.put(f"{A}/areas/{area_id}/methods/", json={"methods": [UV_METHOD, ENGRAVE_METHOD]}))
    ok(await client.post(f"{A}/shapes/{shape_id}/ready/"))
    ok(await client.put(f"{A}/products/{pid}/price-tiers/uv/", json={"tiers": UV_TIERS}))
    ok(await client.put(f"{A}/products/{pid}/price-tiers/engrave/", json={"tiers": [{"min_cm2": "0", "max_cm2": None, "surcharge": "0"}]}))
    product = ok(await client.post(f"{A}/products/{pid}/variants/", json={
        "shape_id": shape_id, "name": "Xameleon", "base_price": "149000", "methods": ["uv"],
        "material": "ceramic_glossy", "specs": [{"label": "Hajmi", "value": "330 ml"}],
    }), 201)
    variant_id = product["variants"][0]["id"]
    if with_colors:
        product = ok(await client.post(f"{A}/variants/{variant_id}/colors/", json={"name": "Qora", "hex": "#161618"}), 201)
        ok(await client.post(f"{A}/variants/{variant_id}/colors/", json={"name": "Qizil", "hex": "#b3202a", "surcharge": "5000"}), 201)
    return ok(await client.get(f"{A}/products/{pid}/"))


def color_id(product: dict, name: str) -> int:
    return next(c["id"] for c in product["variants"][0]["colors"] if c["name"] == name)


@pytest.mark.asyncio
async def test_a_complete_product_appears_in_the_storefront(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await build_mug(admin_client, storage)

    assert product["issues"] == []
    assert product["sellable"] is True
    cards = ok(await admin_client.get("/api/catalog/products/"))
    assert [c["slug"] for c in cards] == ["krujka"]
    assert Decimal(cards[0]["from_price"]) == Decimal("149000")
    assert cards[0]["cover_url"].startswith("https://media.test/catalog/")
    detail = ok(await admin_client.get("/api/catalog/products/krujka/"))
    assert detail["variants"][0]["methods"] == ["uv"]
    # The Studio needs to know whether ink prints on a white underbase to
    # preview colour honestly (defaults to false when unset).
    assert detail["variants"][0]["white_underbase"] is False
    assert [c["name"] for c in detail["variants"][0]["colors"]] == ["Qora", "Qizil"]
    [shape] = detail["shapes"]
    assert shape["kind"] == "cylinder" and shape["areas"][0]["key"] == "wrap"
    assert {m["method"] for m in shape["areas"][0]["methods"]} == {"uv", "engrave"}


@pytest.mark.asyncio
async def test_the_admin_list_shows_shapes_and_the_lowest_price(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    await build_mug(admin_client, storage)
    ok(await admin_client.post(f"{A}/products/", json={"slug": "bosh", "name": "Bo'sh"}), 201)

    rows = {r["slug"]: r for r in ok(await admin_client.get(f"{A}/products/"))}
    assert rows["krujka"]["shape_count"] == 1 and rows["krujka"]["variant_count"] == 1
    assert Decimal(rows["krujka"]["from_price"]) == Decimal("149000")
    assert rows["bosh"]["shape_count"] == 0 and rows["bosh"]["from_price"] is None


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("area", "tier_surcharge"),
    [("0", None), ("99.99", "0"), ("100", "1000"), ("126", "1000"), ("499.99", "1000"), ("500", "2500")],
)
async def test_quote_uses_the_right_tier_including_boundaries(
    admin_client: httpx.AsyncClient, storage: FakeStorage, area: str, tier_surcharge: str | None
) -> None:
    product = await build_mug(admin_client, storage)
    variant_id = product["variants"][0]["id"]

    q = ok(await admin_client.post("/api/catalog/quote/", json={
        "variant_id": variant_id, "color_id": color_id(product, "Qizil"), "quantity": 3, "areas_cm2": {"uv": area},
    }))

    surcharge = Decimal(tier_surcharge) if tier_surcharge is not None else Decimal("0")
    assert [line["surcharge"] for line in q["methods"]] == ([] if tier_surcharge is None else [tier_surcharge + ".00"])
    unit = Decimal("149000") + Decimal("5000") + surcharge
    assert Decimal(q["unit_price"]) == unit
    assert Decimal(q["total"]) == unit * 3


@pytest.mark.asyncio
async def test_quote_rejects_a_method_the_variant_does_not_offer(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await build_mug(admin_client, storage)

    response = await admin_client.post("/api/catalog/quote/", json={
        "variant_id": product["variants"][0]["id"], "color_id": color_id(product, "Qora"), "quantity": 1,
        "areas_cm2": {"engrave": "5"},
    })

    assert response.status_code == 422


@pytest.mark.asyncio
async def test_quote_rejects_an_unavailable_colour_or_variant(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await build_mug(admin_client, storage)
    variant_id = product["variants"][0]["id"]
    qora = color_id(product, "Qora")
    ok(await admin_client.patch(f"{A}/colors/{qora}/", json={"is_available": False}))
    body = {"variant_id": variant_id, "color_id": qora, "quantity": 1, "areas_cm2": {}}
    assert (await admin_client.post("/api/catalog/quote/", json=body)).status_code == 422

    ok(await admin_client.patch(f"{A}/variants/{variant_id}/", json={"archived": True}))
    body["color_id"] = color_id(product, "Qizil")
    assert (await admin_client.post("/api/catalog/quote/", json=body)).status_code == 422
    assert ok(await admin_client.get("/api/catalog/products/")) == []


@pytest.mark.asyncio
async def test_a_variant_without_colours_or_tiers_is_not_sold(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await build_mug(admin_client, storage, with_colors=False)
    assert any("mavjud rang yo'q" in issue for issue in product["issues"])
    assert product["sellable"] is False
    assert ok(await admin_client.get("/api/catalog/products/")) == []
    assert (await admin_client.get("/api/catalog/products/krujka/")).status_code == 404

    variant_id = product["variants"][0]["id"]
    ok(await admin_client.post(f"{A}/variants/{variant_id}/colors/", json={"name": "Qora", "hex": "#161618"}), 201)
    product = ok(await admin_client.delete(f"{A}/products/{product['id']}/price-tiers/uv/"))
    assert any("narx pog'onalari yo'q: uv" in issue for issue in product["issues"])
    assert ok(await admin_client.get("/api/catalog/products/")) == []


@pytest.mark.asyncio
async def test_areas_and_zones_must_fit(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    pid = ok(await admin_client.post(f"{A}/products/", json={"slug": "k2", "name": "K2"}), 201)["id"]
    shape_id = ok(await admin_client.post(f"{A}/products/{pid}/shapes/", json={
        "name": "S", "kind": "cylinder", "dims": {"diameter_mm": "80", "height_mm": "95", "handle_gap_mm": "25"},
    }), 201)["shapes"][0]["id"]
    area = {"key": "wrap", "name": "W", "width_mm": "230", "height_mm": "79", "anchor": {"start_mm": "0", "top_mm": "8"}}

    too_wide = await admin_client.post(f"{A}/shapes/{shape_id}/areas/", json=area)
    too_tall = await admin_client.post(f"{A}/shapes/{shape_id}/areas/", json={**area, "width_mm": "200", "height_mm": "90"})
    area_id = ok(await admin_client.post(f"{A}/shapes/{shape_id}/areas/", json={**area, "width_mm": "200"}), 201)["shapes"][0]["areas"][0]["id"]
    zone_out = await admin_client.put(f"{A}/areas/{area_id}/methods/", json={"methods": [{**ENGRAVE_METHOD, "zone_x_mm": "150"}]})

    assert too_wide.status_code == 422 and "aylana" in too_wide.json()["detail"]
    assert too_tall.status_code == 422 and "balandlik" in too_tall.json()["detail"]
    assert zone_out.status_code == 422


@pytest.mark.asyncio
async def test_engraving_needs_a_min_font_and_no_colours(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await build_mug(admin_client, storage)
    shape_id = product["shapes"][0]["id"]
    area_id = product["shapes"][0]["areas"][0]["id"]
    ok(await admin_client.post(f"{A}/shapes/{shape_id}/draft/"))

    coloured = await admin_client.put(f"{A}/areas/{area_id}/methods/", json={"methods": [{**ENGRAVE_METHOD, "colors_allowed": True}]})
    no_font = await admin_client.put(f"{A}/areas/{area_id}/methods/", json={"methods": [{**ENGRAVE_METHOD, "min_font_mm": None}]})

    assert coloured.status_code == 422 and no_font.status_code == 422


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "tiers",
    [
        [{"min_cm2": "10", "max_cm2": None, "surcharge": "0"}],
        [{"min_cm2": "0", "max_cm2": "100", "surcharge": "0"}, {"min_cm2": "120", "max_cm2": None, "surcharge": "1"}],
        [{"min_cm2": "0", "max_cm2": "100", "surcharge": "0"}, {"min_cm2": "90", "max_cm2": None, "surcharge": "1"}],
        [{"min_cm2": "0", "max_cm2": None, "surcharge": "0"}, {"min_cm2": "100", "max_cm2": None, "surcharge": "1"}],
        [{"min_cm2": "0", "max_cm2": "100", "surcharge": "0"}],
    ],
    ids=["not-from-zero", "gap", "overlap", "two-open-ended", "last-bounded"],
)
async def test_price_tiers_must_cover_zero_to_infinity(admin_client: httpx.AsyncClient, storage: FakeStorage, tiers: list) -> None:
    pid = ok(await admin_client.post(f"{A}/products/", json={"slug": "t", "name": "T"}), 201)["id"]

    response = await admin_client.put(f"{A}/products/{pid}/price-tiers/uv/", json={"tiers": tiers})

    assert response.status_code == 422


@pytest.mark.asyncio
async def test_validation_errors_are_reported_in_uzbek(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await build_mug(admin_client, storage)
    area_id = product["shapes"][0]["areas"][0]["id"]
    ok(await admin_client.post(f"{A}/shapes/{product['shapes'][0]['id']}/draft/"))

    tier = await admin_client.put(f"{A}/products/{product['id']}/price-tiers/uv/", json={
        "tiers": [{"min_cm2": "0", "max_cm2": "0", "surcharge": "0"}], "extra": 1,
    })
    engrave = await admin_client.put(f"{A}/areas/{area_id}/methods/", json={"methods": [{**ENGRAVE_METHOD, "min_font_mm": None}]})

    assert tier.status_code == 422
    assert {(tuple(e["loc"]), e["msg"], e["type"]) for e in tier.json()["detail"]} == {
        (("body", "tiers", 0, "max_cm2"), "0 dan katta bo'lishi kerak", "greater_than"),
        (("body", "extra"), "noma'lum maydon", "extra_forbidden"),
    }
    [error] = engrave.json()["detail"]
    assert error["msg"] == "O'yish uchun minimal shrift o'lchami (min_font_mm) kiritilishi shart"


@pytest.mark.asyncio
async def test_ready_shapes_are_edited_only_through_draft(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await build_mug(admin_client, storage)
    shape_id = product["shapes"][0]["id"]
    area = {"key": "front", "name": "Old", "width_mm": "50", "height_mm": "50", "anchor": {"start_mm": "0", "top_mm": "0"}}

    assert (await admin_client.post(f"{A}/shapes/{shape_id}/areas/", json=area)).status_code == 409
    ok(await admin_client.post(f"{A}/shapes/{shape_id}/draft/"))
    assert (await admin_client.post(f"{A}/shapes/{shape_id}/areas/", json=area)).status_code == 201
    # While the shape is a draft the product is off the storefront.
    assert ok(await admin_client.get("/api/catalog/products/")) == []


@pytest.mark.asyncio
async def test_locked_shapes_are_changed_through_a_duplicate(
    admin_client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    product = await build_mug(admin_client, storage)
    shape_id = product["shapes"][0]["id"]
    async with session_factory() as session:
        (await session.get(Shape, shape_id)).locked_at = datetime.now(UTC)
        await session.commit()

    assert (await admin_client.post(f"{A}/shapes/{shape_id}/draft/")).status_code == 409
    product = ok(await admin_client.post(f"{A}/shapes/{shape_id}/duplicate/"), 201)

    copy = product["shapes"][1]
    assert copy["status"] == "draft" and copy["locked"] is False
    assert [a["key"] for a in copy["areas"]] == ["wrap"]
    assert {m["method"] for m in copy["areas"][0]["methods"]} == {"uv", "engrave"}


@pytest.mark.asyncio
async def test_a_shape_in_use_cannot_be_archived(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await build_mug(admin_client, storage)

    response = await admin_client.patch(f"{A}/shapes/{product['shapes'][0]['id']}/", json={"archived": True})

    assert response.status_code == 409


@pytest.mark.asyncio
async def test_catalog_images_must_be_catalog_uploads(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    ticket = (await admin_client.post("/api/media/uploads/", json={"purpose": "design", "content_type": "image/png", "size_bytes": 8})).json()
    storage.put(ticket["upload_url"], size_bytes=8, content_type="image/png")
    await admin_client.post(f"/api/media/{ticket['id']}/complete/")

    response = await admin_client.post(f"{A}/products/", json={"slug": "x", "name": "X", "cover_media_id": ticket["id"]})

    assert response.status_code == 422


@pytest.mark.asyncio
async def test_duplicate_slug_is_a_conflict(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    ok(await admin_client.post(f"{A}/products/", json={"slug": "same", "name": "A"}), 201)

    assert (await admin_client.post(f"{A}/products/", json={"slug": "same", "name": "B"})).status_code == 409


@pytest.mark.asyncio
async def test_catalog_admin_needs_an_admin(client: httpx.AsyncClient, storage: FakeStorage) -> None:
    assert (await client.get(f"{A}/products/")).status_code == 401
    await register(client, "customer@example.com")
    assert (await client.get(f"{A}/products/")).status_code == 403


@pytest.mark.asyncio
async def test_a_shape_in_use_is_edited_through_a_revision_that_replaces_it(
    admin_client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    product = await build_mug(admin_client, storage)
    shape_id = product["shapes"][0]["id"]
    async with session_factory() as session:
        (await session.get(Shape, shape_id)).locked_at = datetime.now(UTC)
        await session.commit()

    product = ok(await admin_client.post(f"{A}/shapes/{shape_id}/revise/"))
    again = ok(await admin_client.post(f"{A}/shapes/{shape_id}/revise/"))
    revision = next(s for s in product["shapes"] if s["replaces_id"] == shape_id)
    area_id = revision["areas"][0]["id"]
    ok(await admin_client.put(f"{A}/areas/{area_id}/", json={
        "key": "wrap", "name": "Aylana", "width_mm": "226", "height_mm": "79", "anchor": {"start_mm": "0", "top_mm": "8"},
    }))
    still_sold = ok(await admin_client.get("/api/catalog/products/"))
    product = ok(await admin_client.post(f"{A}/shapes/{revision['id']}/ready/"))

    assert len(again["shapes"]) == 2  # one revision, however often edit is opened
    assert revision["name"] == "Krujka 330 ml" and revision["status"] == "draft"
    assert [p["slug"] for p in still_sold] == ["krujka"]  # the old shape sells meanwhile
    old = next(s for s in product["shapes"] if s["id"] == shape_id)
    new = next(s for s in product["shapes"] if s["id"] == revision["id"])
    assert old["archived"] and new["status"] == "ready" and new["replaces_id"] is None
    assert product["variants"][0]["shape_id"] == new["id"]
    assert new["areas"][0]["name"] == "Aylana"


@pytest.mark.asyncio
async def test_a_draft_is_its_own_revision_and_unused_shapes_can_be_deleted(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await build_mug(admin_client, storage)
    pid = product["id"]
    product = ok(await admin_client.post(f"{A}/products/{pid}/shapes/", json={"name": "Vizitka", "kind": "plane", "dims": {"width_mm": "90", "height_mm": "50", "sides": 1}}), 201)
    draft_id = product["shapes"][-1]["id"]

    same = ok(await admin_client.post(f"{A}/shapes/{draft_id}/revise/"))
    in_use = await admin_client.delete(f"{A}/shapes/{product['shapes'][0]['id']}/")
    deleted = ok(await admin_client.delete(f"{A}/shapes/{draft_id}/"))

    assert [s["id"] for s in same["shapes"]] == [s["id"] for s in product["shapes"]]
    assert in_use.status_code == 409 and "variantlar" in in_use.json()["detail"]
    assert draft_id not in [s["id"] for s in deleted["shapes"]]


@pytest.mark.asyncio
async def test_the_storefront_list_pages_filters_and_searches(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await build_mug(admin_client, storage)
    ok(await admin_client.patch(f"{A}/products/{product['id']}/", json={"translations": {"ru": {"name": "Кружка"}}}))

    listed = await admin_client.get("/api/catalog/products/", params={"limit": 1, "offset": 0})
    assert listed.headers["x-total-count"] == "1" and len(listed.json()) == 1
    assert ok(await admin_client.get("/api/catalog/products/", params={"offset": 1})) == []
    # The name matches in any language; another shelf or word finds nothing.
    assert len(ok(await admin_client.get("/api/catalog/products/", params={"q": "кружк"}))) == 1
    assert ok(await admin_client.get("/api/catalog/products/", params={"q": "futbolka"})) == []
    shelf = listed.json()[0]["category"]
    assert len(ok(await admin_client.get("/api/catalog/products/", params={"category": shelf}))) == 1
    assert ok(await admin_client.get("/api/catalog/products/", params={"category": "yoq"})) == []
    assert ok(await admin_client.get("/api/catalog/products/shelves/")) == {"total": 1, "counts": {shelf: 1}}

    # A change in the admin reaches the cached list at once.
    ok(await admin_client.patch(f"{A}/products/{product['id']}/", json={"is_available": False}))
    assert ok(await admin_client.get("/api/catalog/products/")) == []


@pytest.mark.asyncio
async def test_the_from_price_includes_the_print_every_order_must_carry(
    admin_client: httpx.AsyncClient, storage: FakeStorage
) -> None:
    """A card that advertises a price nobody is ever charged is a lie: every
    order paints something, so the cheapest tier's surcharge is part of the
    cheapest possible basket."""
    product = await build_mug(admin_client, storage)
    base = Decimal(ok(await admin_client.get("/api/catalog/products/"))[0]["from_price"])

    ok(await admin_client.put(f"{A}/products/{product['id']}/price-tiers/uv/", json={"tiers": [
        {"min_cm2": "0", "max_cm2": "100", "surcharge": "7000"},
        {"min_cm2": "100", "max_cm2": None, "surcharge": "19000"},
    ]}))

    card = ok(await admin_client.get("/api/catalog/products/"))[0]
    detail = ok(await admin_client.get("/api/catalog/products/krujka/"))
    # the cheapest tier, not the dearest, and not zero
    assert Decimal(card["from_price"]) == base + Decimal("7000")
    assert Decimal(detail["from_price"]) == base + Decimal("7000")
