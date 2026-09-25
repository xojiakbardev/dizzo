"""PUT /shapes/{id}/layout/: the shape editor's one atomic save."""

from decimal import Decimal

import httpx
import pytest

from tests.conftest import FakeStorage
from tests.test_area_pairs import plate
from tests.test_catalog import A, ok
from tests.test_catalog_model import glb_bytes, model_shape, upload_model

PLACED = {"point": [0, 1200, 90], "normal": [0, 0, 1], "up": [0, 1, 0], "depth_mm": "120"}
SCALE = {"a": [0, 0, 0], "b": [0, 0, 360], "mm": "720"}


def uv(w: str, h: str, **extra) -> dict:
    return {"method": "uv", "zone_x_mm": "0", "zone_y_mm": "0", "zone_w_mm": w, "zone_h_mm": h, "colors_allowed": True,
            "dpi": 300, **extra}


def engrave(w: str, h: str, **extra) -> dict:
    return {"method": "engrave", "zone_x_mm": "0", "zone_y_mm": "0", "zone_w_mm": w, "zone_h_mm": h,
            "colors_allowed": False, "min_font_mm": "2", "dpi": 600, **extra}


def layout_area(key: str, *, id: int | None = None, w: str = "100", h: str = "100", anchor: dict | None = None,
                methods: list[dict] | None = None, **extra) -> dict:
    return {"id": id, "key": key, "name": key.title(), "width_mm": w, "height_mm": h,
            "anchor": PLACED if anchor is None else anchor, "methods": methods or [uv(w, h)], **extra}


def areas_of(product: dict) -> dict[str, dict]:
    return {a["key"]: a for a in product["shapes"][0]["areas"]}


@pytest.mark.asyncio
async def test_layout_saves_everything_at_once(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product, area_id = await model_shape(admin_client, storage)
    shape_id = product["shapes"][0]["id"]

    product = ok(await admin_client.put(f"{A}/shapes/{shape_id}/layout/", json={
        "name": "Futbolka L",
        "scale": SCALE,
        "areas": [
            layout_area("front", id=area_id, w="300", h="350",
                        methods=[uv("280", "300", zone_x_mm="10"), engrave("200", "100", strip_width_mm="60")]),
            layout_area("back", camera={"position": [0, 1, 5], "target": [0, 1, 0]}),
        ],
    }))

    shape = product["shapes"][0]
    assert shape["name"] == "Futbolka L" and shape["mm_per_unit"] == "2.000000"
    assert shape["model_transform"]["scale_ref"]["mm"] == "720"
    front, back = areas_of(product)["front"], areas_of(product)["back"]
    assert front["id"] == area_id  # kept, not re-created
    assert Decimal(front["height_mm"]) == 350
    by_method = {m["method"]: m for m in front["methods"]}
    assert Decimal(by_method["uv"]["zone_x_mm"]) == 10
    assert Decimal(by_method["engrave"]["strip_width_mm"]) == 60
    assert back["camera"] == {"position": [0, 1, 5], "target": [0, 1, 0]}
    assert back["anchor"]["point"] == [0, 1200, 90]


@pytest.mark.asyncio
async def test_shape_description_is_saved_and_copied(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product, area_id = await model_shape(admin_client, storage)
    shape_id = product["shapes"][0]["id"]
    assert product["shapes"][0]["description"] == ""

    product = ok(await admin_client.put(f"{A}/shapes/{shape_id}/layout/", json={
        "description": "  Oq, paxta  ", "areas": [layout_area("front", id=area_id)],
    }))
    assert product["shapes"][0]["description"] == "Oq, paxta"
    product = ok(await admin_client.patch(f"{A}/shapes/{shape_id}/", json={"description": "Qora"}))
    assert product["shapes"][0]["description"] == "Qora"
    # Leaving it out keeps it.
    product = ok(await admin_client.put(f"{A}/shapes/{shape_id}/layout/", json={"areas": [layout_area("front", id=area_id)]}))
    assert product["shapes"][0]["description"] == "Qora"

    product = ok(await admin_client.post(f"{A}/shapes/{shape_id}/duplicate/"), 201)
    assert [s["description"] for s in product["shapes"]] == ["Qora", "Qora"]
    too_long = await admin_client.patch(f"{A}/shapes/{shape_id}/", json={"description": "x" * 201})
    assert too_long.status_code == 422


@pytest.mark.asyncio
async def test_layout_deletes_left_out_areas_and_swaps_keys(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product, front_id = await model_shape(admin_client, storage)
    shape_id = product["shapes"][0]["id"]
    product = ok(await admin_client.put(f"{A}/shapes/{shape_id}/layout/", json={"areas": [
        layout_area("front", id=front_id), layout_area("back"), layout_area("sleeve"),
    ]}))
    ids = {k: a["id"] for k, a in areas_of(product).items()}

    product = ok(await admin_client.put(f"{A}/shapes/{shape_id}/layout/", json={"areas": [
        layout_area("back", id=ids["front"]), layout_area("front", id=ids["back"]),
    ]}))

    assert {k: a["id"] for k, a in areas_of(product).items()} == {"back": ids["front"], "front": ids["back"]}


@pytest.mark.asyncio
async def test_layout_is_all_or_nothing(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product, front_id = await model_shape(admin_client, storage)
    shape_id = product["shapes"][0]["id"]
    before = product["shapes"][0]

    # The second area's zone sticks out: nothing is saved, not even the name.
    response = await admin_client.put(f"{A}/shapes/{shape_id}/layout/", json={"name": "Boshqa", "areas": [
        layout_area("front", id=front_id, w="50", h="50"),
        layout_area("back", w="100", h="100", methods=[uv("100", "100", zone_x_mm="20")]),
    ]})

    assert response.status_code == 422 and "“Back”" in response.json()["detail"]
    after = ok(await admin_client.get(f"{A}/products/{product['id']}/"))["shapes"][0]
    assert after == before


@pytest.mark.asyncio
async def test_layout_checks_the_rules(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product, front_id = await model_shape(admin_client, storage)
    shape_id = product["shapes"][0]["id"]
    url = f"{A}/shapes/{shape_id}/layout/"

    duplicate_key = await admin_client.put(url, json={"areas": [layout_area("front"), layout_area("front")]})
    foreign = await admin_client.put(url, json={"areas": [layout_area("front", id=front_id + 999)]})
    colour_engrave = await admin_client.put(url, json={"areas": [
        layout_area("front", methods=[{**engrave("100", "100"), "colors_allowed": True}]),
    ]})
    wide_strip = await admin_client.put(url, json={"areas": [
        layout_area("front", methods=[engrave("50", "100", strip_width_mm="60")]),
    ]})
    no_methods = await admin_client.put(url, json={"areas": [{**layout_area("front"), "methods": []}]})
    one_sided_pair = await admin_client.put(url, json={"areas": [layout_area("front", pair_key="back"), layout_area("back")]})

    assert duplicate_key.status_code == 422 and "takrorlangan" in duplicate_key.json()["detail"]
    assert foreign.status_code == 422 and "hudud yo'q" in foreign.json()["detail"]
    assert colour_engrave.status_code == 422
    assert wide_strip.status_code == 422
    assert no_methods.status_code == 422
    assert one_sided_pair.status_code == 422 and "juft" in one_sided_pair.json()["detail"]


@pytest.mark.asyncio
async def test_layout_pairs_must_match(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await plate(admin_client)
    shape_id = product["shapes"][0]["id"]
    left = {"side": "front", "x_mm": "0", "y_mm": "5"}
    right = {"side": "front", "x_mm": "60", "y_mm": "5"}
    url = f"{A}/shapes/{shape_id}/layout/"

    # Mirrored: the partner's zone starts 40 − 5 − 20 = 15 mm in.
    matched = await admin_client.put(url, json={"areas": [
        layout_area("left", w="40", h="40", anchor=left, pair_key="right", methods=[uv("20", "40", zone_x_mm="5")]),
        layout_area("right", w="40", h="40", anchor=right, pair_key="left", methods=[uv("20", "40", zone_x_mm="15")]),
    ]})
    unmatched = await admin_client.put(url, json={"areas": [
        layout_area("left", w="40", h="40", anchor=left, pair_key="right", methods=[uv("20", "40", zone_x_mm="5")]),
        layout_area("right", w="40", h="40", anchor=right, pair_key="left", methods=[uv("20", "40", zone_x_mm="5")]),
    ]})

    product = ok(matched)
    assert areas_of(product)["left"]["pair_key"] == "right"
    assert unmatched.status_code == 422 and "farq qiladi" in unmatched.json()["detail"]
    # The failed save changed nothing.
    after = ok(await admin_client.get(f"{A}/products/{product['id']}/"))
    assert after["shapes"] == product["shapes"]


@pytest.mark.asyncio
async def test_layout_resizes_a_built_body_with_its_areas(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await plate(admin_client)
    shape_id = product["shapes"][0]["id"]
    ids = {k: a["id"] for k, a in areas_of(product).items()}
    body = {"areas": [
        layout_area("left", id=ids["left"], w="40", h="40", anchor={"side": "front", "x_mm": "0", "y_mm": "5"}),
        layout_area("right", id=ids["right"], w="40", h="40", anchor={"side": "front", "x_mm": "100", "y_mm": "5"}),
    ]}

    # On the 100 mm plate the right area doesn't fit; on a 150 mm one it does.
    too_small = await admin_client.put(f"{A}/shapes/{shape_id}/layout/", json=body)
    product = ok(await admin_client.put(f"{A}/shapes/{shape_id}/layout/", json={
        **body, "dims": {"width_mm": "150", "height_mm": "50", "sides": 1},
    }))

    assert too_small.status_code == 422 and "“Right”" in too_small.json()["detail"]
    assert product["shapes"][0]["dims"]["width_mm"] == "150"
    assert areas_of(product)["right"]["anchor"]["x_mm"] == "100"


@pytest.mark.asyncio
async def test_a_new_model_keeps_the_areas(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product, front_id = await model_shape(admin_client, storage)
    shape_id = product["shapes"][0]["id"]
    url = f"{A}/shapes/{shape_id}/layout/"
    ok(await admin_client.patch(f"{A}/shapes/{shape_id}/", json={"model_transform": {"up_axis": "z", "yaw_deg": 90}}))
    ok(await admin_client.put(url, json={"scale": SCALE, "areas": [layout_area("front", id=front_id)]}))
    new_model = ok(await upload_model(admin_client, storage, glb_bytes(300)))["id"]

    moved = {**PLACED, "point": [0, 600, 45]}
    rescaled = ok(await admin_client.put(url, json={
        "model_media_id": new_model, "scale": {**SCALE, "b": [0, 0, 180]},
        "areas": [layout_area("front", id=front_id, anchor=moved)],
    }))
    unscaled = ok(await admin_client.put(url, json={
        "model_media_id": (ok(await upload_model(admin_client, storage, glb_bytes(310))))["id"],
        "areas": [layout_area("front", id=front_id, anchor=moved)],
    }))

    shape = rescaled["shapes"][0]
    assert shape["model_media_id"] == new_model
    assert shape["mm_per_unit"] == "4.000000"
    assert shape["model_transform"]["up_axis"] == "z" and shape["model_transform"]["yaw_deg"] == 90
    assert areas_of(rescaled)["front"]["anchor"]["point"] == [0, 600, 45]
    # A new model without a new scale has none.
    shape = unscaled["shapes"][0]
    assert shape["mm_per_unit"] is None and shape["model_transform"]["scale_ref"] is None
    assert areas_of(unscaled)["front"]["anchor"]["point"] == [0, 600, 45]


@pytest.mark.asyncio
async def test_layout_needs_an_editable_model_shape(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    plate_product = await plate(admin_client)
    plate_id = plate_product["shapes"][0]["id"]
    left = areas_of(plate_product)["left"]

    scale_on_plate = await admin_client.put(f"{A}/shapes/{plate_id}/layout/", json={"scale": SCALE, "areas": []})
    ok(await admin_client.put(f"{A}/areas/{left['id']}/pair/", json={"pair_key": "right"}))
    ok(await admin_client.post(f"{A}/shapes/{plate_id}/ready/"))
    ready = await admin_client.put(f"{A}/shapes/{plate_id}/layout/", json={"areas": [
        layout_area("left", id=left["id"], w="40", h="40", anchor={"side": "front", "x_mm": "0", "y_mm": "5"}),
    ]})

    assert scale_on_plate.status_code == 422
    assert ready.status_code == 409


@pytest.mark.asyncio
async def test_layout_needs_an_admin(client: httpx.AsyncClient) -> None:
    response = await client.put(f"{A}/shapes/1/layout/", json={"areas": []})
    assert response.status_code == 401
