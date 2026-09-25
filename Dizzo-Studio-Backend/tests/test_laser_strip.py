"""A laser reaches only so far round a mug: an engraving zone with a strip
width takes the design in one strip that wide, anywhere across the zone."""

from decimal import Decimal
from types import SimpleNamespace

import httpx
import pytest
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.catalog import AreaMethod, PrintArea
from app.schemas.design import DesignDocument, Layer
from app.services.design_rules import Box, document_problems, follow_strip, print_zone, settle_strips, strip_problems
from tests.conftest import FakeStorage
from tests.test_catalog import ENGRAVE_METHOD, UV_METHOD, A, build_mug, ok
from tests.test_studio import ENGRAVE_PX, cart_item, png, shop, upload

BLACK = (0, 0, 0, 255)


def engrave(strip: str | None) -> AreaMethod:
    """The mug's engraving zone: 75,15 100×50 mm."""
    return AreaMethod(
        method="engrave", zone_x_mm=Decimal("75"), zone_y_mm=Decimal("15"), zone_w_mm=Decimal("100"),
        zone_h_mm=Decimal("50"), max_width_mm=None, max_height_mm=None,
        strip_width_mm=Decimal(strip) if strip else None, min_font_mm=Decimal("2"), colors_allowed=False, dpi=600,
    )


def text(layer_id: str, x: float, w: float) -> Layer:
    return Layer.model_validate({
        "id": layer_id, "area": "wrap", "method": "engrave", "kind": "text",
        "x_mm": x, "y_mm": 40, "w_mm": w, "h_mm": 10,
        "text": {"content": "Salom", "font": "Montserrat", "size_mm": 5, "color": "#000000"},
    })


def dial(x: float, w: float) -> Layer:
    return Layer.model_validate({
        "id": "d1", "area": "wrap", "method": "engrave", "kind": "dial", "x_mm": x, "y_mm": 40, "w_mm": w, "h_mm": 30,
        "dial": {"font": "Montserrat", "size_mm": 6, "color": "#000000"},
    })


def test_without_a_strip_the_zone_is_the_whole_zone() -> None:
    assert print_zone(engrave(None), [text("a", 90, 10)]) == Box(75, 15, 175, 65)


def test_the_strip_centres_on_the_layers_and_stays_in_the_zone() -> None:
    method = engrave("40")

    assert print_zone(method, []) == Box(105, 15, 145, 65)  # nothing placed: the middle
    assert print_zone(method, [text("a", 110, 10), text("b", 130, 10)]) == Box(100, 15, 140, 65)
    assert print_zone(method, [text("a", 80, 10)]) == Box(75, 15, 115, 65)  # at the left edge
    assert print_zone(method, [text("a", 180, 30)]) == Box(135, 15, 175, 65)  # partly off the zone
    # Only what lies in the zone counts.
    assert print_zone(method, [text("a", 110, 10), text("far", 20, 10)]) == Box(90, 15, 130, 65)


def mug(strip: str | None = "40") -> SimpleNamespace:
    area = PrintArea(key="wrap", name="O'rab olish", width_mm=Decimal("226"), height_mm=Decimal("79"), pair_key=None)
    area.methods = [engrave(strip)]
    return SimpleNamespace(shape=SimpleNamespace(areas=[area]), methods=["engrave"])


def test_the_strip_stays_until_the_design_reaches_its_edge() -> None:
    zone = Box(75, 15, 175, 65)

    assert follow_strip(100, (110, 130), zone, 40) == 100  # inside: it stays
    assert follow_strip(100, (100, 140), zone, 40) == 100  # touching both edges
    assert follow_strip(100, (95, 120), zone, 40) == 95  # pushed left by the design
    assert follow_strip(100, (120, 150), zone, 40) == 110  # pushed right
    assert follow_strip(100, (60, 70), zone, 40) == 75  # never out of the zone
    assert follow_strip(100, (170, 190), zone, 40) == 135
    assert follow_strip(100, None, zone, 40) == 100  # nothing in the zone
    assert follow_strip(300, None, zone, 40) == 135
    assert follow_strip(100, (100, 160), zone, 40) == 100  # wider than the strip (older designs): it stays
    assert follow_strip(160, (100, 160), zone, 40) == 135  # ... kept in the zone


def test_a_stored_strip_is_where_it_was_left() -> None:
    method = engrave("40")
    layers = [text("a", 110, 10), text("b", 130, 10)]

    assert print_zone(method, layers) == Box(100, 15, 140, 65)  # no position stored: centred
    assert print_zone(method, layers, 95) == Box(95, 15, 135, 65)
    assert print_zone(method, layers, 60) == Box(75, 15, 115, 65)  # kept in the zone
    assert print_zone(method, layers, 170) == Box(135, 15, 175, 65)
    assert print_zone(engrave(None), layers, 95) == Box(75, 15, 175, 65)  # no strip: the zone


def test_stored_strips_are_checked_against_the_variant() -> None:
    def doc(*strips: dict) -> DesignDocument:
        return DesignDocument.model_validate({"layers": [text("a", 110, 10).model_dump()], "strips": list(strips)})

    good = doc({"area": "wrap", "method": "engrave", "x_mm": 95})
    edge = doc({"area": "wrap", "method": "engrave", "x_mm": 135.4})  # within the rounding slack
    outside = doc({"area": "wrap", "method": "engrave", "x_mm": 140})
    no_area = doc({"area": "back", "method": "engrave", "x_mm": 95})
    no_strip = doc({"area": "wrap", "method": "uv", "x_mm": 95})

    assert document_problems(good, mug()) == [] and document_problems(edge, mug()) == []
    assert strip_problems(outside, mug()) == ["Tasma “O'rab olish” hududidagi bosma zonasidan chiqib ketgan"]
    assert "hududi bu variantda yo'q" in strip_problems(no_area, mug())[0]
    assert "tasmasi yo'q" in strip_problems(no_strip, mug())[0]
    assert "tasmasi yo'q" in strip_problems(good, mug(None))[0]
    assert any(p.startswith("Tasma") for p in document_problems(outside, mug()))
    with pytest.raises(ValidationError, match="bitta tasma"):
        doc({"area": "wrap", "method": "engrave", "x_mm": 95}, {"area": "wrap", "method": "engrave", "x_mm": 100})
    # Older documents have no strips at all.
    assert DesignDocument.model_validate({"layers": []}).strips == []

    # Read back on a variant that changed: dropped or kept in the zone.
    assert settle_strips(good, mug()) is good
    assert settle_strips(outside, mug()).strips[0].x_mm == 135
    assert settle_strips(no_area, mug()).strips == []
    assert settle_strips(good, mug(None)).strips == []


def test_layers_must_fit_one_strip_together() -> None:
    variant = mug()
    alone = DesignDocument(layers=[dial(100, 30)])
    apart = DesignDocument(layers=[dial(100, 30), text("t", 160, 10)])
    wide_text = DesignDocument(layers=[text("a", 110, 10), text("b", 160, 10)])

    # The dial fits a strip of its own; a text far off pulls the strip off it.
    assert document_problems(alone, variant) == []
    assert any("chiqib ketgan" in p for p in document_problems(apart, variant))
    # Text sticking out of the strip is only cropped, like out of a zone.
    assert document_problems(wide_text, variant) == []


@pytest.mark.asyncio
async def test_the_admin_sets_a_strip_no_wider_than_the_zone(
    admin_client: httpx.AsyncClient, storage: FakeStorage
) -> None:
    product = await build_mug(admin_client, storage)
    shape = product["shapes"][0]
    area_id = shape["areas"][0]["id"]
    ok(await admin_client.post(f"{A}/shapes/{shape['id']}/draft/"))

    too_wide = await admin_client.put(f"{A}/areas/{area_id}/methods/", json={
        "methods": [UV_METHOD, {**ENGRAVE_METHOD, "strip_width_mm": "120"}],
    })
    saved = ok(await admin_client.put(f"{A}/areas/{area_id}/methods/", json={
        "methods": [UV_METHOD, {**ENGRAVE_METHOD, "strip_width_mm": "40"}],
    }))

    assert too_wide.status_code == 422
    methods = {m["method"]: m for m in saved["shapes"][0]["areas"][0]["methods"]}
    assert Decimal(methods["engrave"]["strip_width_mm"]) == Decimal("40")
    assert methods["uv"]["strip_width_mm"] is None


@pytest.mark.asyncio
async def test_engraving_files_fit_the_strip(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setitem(ENGRAVE_METHOD, "strip_width_mm", "40")
    s = await shop(client, storage, session_factory)
    await client.post("/api/auth/logout/")
    await client.post("/api/auth/login/", json={"email": "shop-admin@example.com", "password": "password123"})
    ok(await client.patch(f"{A}/variants/{s['variant_id']}/", json={"methods": ["uv", "engrave"]}))
    await client.post("/api/auth/logout/")
    await client.post("/api/auth/login/", json={"email": "customer@example.com", "password": "password123"})
    # 80 mm of text: the strip crops it to 40 mm, which isn't a problem.
    layer = {
        "id": "l1", "area": "wrap", "method": "engrave", "kind": "text", "x_mm": 125, "y_mm": 40, "w_mm": 80,
        "h_mm": 20, "text": {"content": "Salom", "font": "Montserrat", "size_mm": 12, "color": "#000000"},
    }
    # 600 DPI ≈ 23.6 px/mm; the zone is x 1772–4134 px: 35 mm ≈ 827 px, 60 mm ≈ 1417 px.
    narrow = png(ENGRAVE_PX, (3200, 500, 4027, 900, BLACK))  # anywhere in the zone, the right end here
    wide = png(ENGRAVE_PX, (2000, 500, 3417, 900, BLACK))
    apart = png(ENGRAVE_PX, (2000, 500, 2200, 900, BLACK), (3300, 500, 3500, 900, BLACK))

    fits = await cart_item(client, storage, s, [("wrap", "engrave", narrow)], layer, expected="149000")
    too_wide = await cart_item(client, storage, s, [("wrap", "engrave", wide)], layer, expected="149000")
    too_far_apart = await cart_item(client, storage, s, [("wrap", "engrave", apart)], layer, expected="149000")

    assert fits.status_code == 201, fits.text
    assert too_wide.status_code == 422 and "tasmadan keng" in too_wide.json()["detail"]
    assert too_far_apart.status_code == 422 and "tasmadan keng" in too_far_apart.json()["detail"]


@pytest.mark.asyncio
async def test_engraving_files_stay_in_the_stored_strip(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setitem(ENGRAVE_METHOD, "strip_width_mm", "40")
    s = await shop(client, storage, session_factory)
    await client.post("/api/auth/logout/")
    await client.post("/api/auth/login/", json={"email": "shop-admin@example.com", "password": "password123"})
    ok(await client.patch(f"{A}/variants/{s['variant_id']}/", json={"methods": ["uv", "engrave"]}))
    await client.post("/api/auth/logout/")
    await client.post("/api/auth/login/", json={"email": "customer@example.com", "password": "password123"})
    layer = {
        "id": "l1", "area": "wrap", "method": "engrave", "kind": "text", "x_mm": 140, "y_mm": 40, "w_mm": 30,
        "h_mm": 20, "text": {"content": "Salom", "font": "Montserrat", "size_mm": 12, "color": "#000000"},
    }
    strips = [{"area": "wrap", "method": "engrave", "x_mm": 120}]  # 120–160 mm ≈ 2835–3780 px

    async def add(body: bytes, stored: list[dict]) -> httpx.Response:
        media = await upload(client, storage, "print", body)
        mockup = await upload(client, storage, "design", png((64, 64), (0, 0, 64, 64, (10, 10, 10, 255))))
        return await client.post("/api/cart/items/", json={
            "variant_id": s["variant_id"], "color_id": s["black"], "quantity": 2,
            "document": {"version": 1, "layers": [layer], "strips": stored},
            "files": [{"area": "wrap", "method": "engrave", "media_id": media}], "mockups": [mockup],
            "expected_unit_price": "149000",
        })

    inside = png(ENGRAVE_PX, (3000, 500, 3700, 900, BLACK))
    left_of_it = png(ENGRAVE_PX, (2000, 500, 2700, 900, BLACK))  # no wider than the strip, but not in it

    fits = await add(inside, strips)
    outside = await add(left_of_it, strips)
    old_document = await add(left_of_it, [])  # no stored strip: only the width counts
    bad_strip = await add(inside, [{"area": "wrap", "method": "engrave", "x_mm": 150}])

    assert fits.status_code == 201, fits.text
    assert outside.status_code == 422 and "tasmadan chiqib ketgan" in outside.json()["detail"]
    assert old_document.status_code == 201, old_document.text
    assert bad_strip.status_code == 422 and "zonasidan chiqib ketgan" in bad_strip.json()["detail"]

    # The design keeps its strip; one that doesn't fit the variant isn't saved.
    design = ok(await client.post("/api/studio/designs/", json={
        "variant_id": s["variant_id"], "color_id": s["black"],
        "document": {"version": 1, "layers": [layer], "strips": strips},
    }), 201)
    refused = await client.post("/api/studio/designs/", json={
        "variant_id": s["variant_id"], "color_id": s["black"],
        "document": {"version": 1, "layers": [layer], "strips": [{"area": "back", "method": "engrave", "x_mm": 120}]},
    })
    assert design["document"]["strips"] == strips and design["issues"] == []
    assert refused.status_code == 422 and "hududi bu variantda yo'q" in refused.json()["detail"]
