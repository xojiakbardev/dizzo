import struct

import httpx
import pytest

from tests.conftest import FakeStorage
from tests.test_catalog import UV_METHOD, UV_TIERS, A, catalog_image, ok

GLB_TYPE = "model/gltf-binary"
PLACED = {"point": [0, 1200, 90], "normal": [0, 0, 2], "up": [0, 1, 0.5], "depth_mm": "120"}


def glb_bytes(size: int = 256, *, magic: bytes = b"glTF", version: int = 2, length: int | None = None) -> bytes:
    header = magic + struct.pack("<II", version, size if length is None else length)
    return header + b"\0" * (size - len(header))


async def upload_model(client: httpx.AsyncClient, storage: FakeStorage, body: bytes) -> httpx.Response:
    ticket = ok(await client.post("/api/media/uploads/", json={
        "purpose": "model", "content_type": GLB_TYPE, "size_bytes": len(body),
    }), 201)
    storage.put(ticket["upload_url"], size_bytes=len(body), content_type=GLB_TYPE, body=body)
    return await client.post(f"/api/media/{ticket['id']}/complete/")


async def model_shape(client: httpx.AsyncClient, storage: FakeStorage) -> tuple[dict, int]:
    """A product with a GLB shape that has one unplaced area with UV."""
    cover = await catalog_image(client, storage)
    product = ok(await client.post(f"{A}/products/", json={"slug": "futbolka", "name": "Futbolka", "cover_media_id": cover}), 201)
    product = ok(await client.post(f"{A}/products/{product['id']}/shapes/", json={
        "name": "Futbolka M", "kind": "model", "dims": {},
    }), 201)
    shape_id = product["shapes"][0]["id"]
    model = ok(await upload_model(client, storage, glb_bytes()))
    ok(await client.patch(f"{A}/shapes/{shape_id}/", json={"model_media_id": model["id"]}))
    product = ok(await client.post(f"{A}/shapes/{shape_id}/areas/", json={
        "key": "front", "name": "Old tomon", "width_mm": "300", "height_mm": "400", "anchor": {},
    }), 201)
    area_id = product["shapes"][0]["areas"][0]["id"]
    uv = {**UV_METHOD, "zone_w_mm": "300", "zone_h_mm": "400"}
    product = ok(await client.put(f"{A}/areas/{area_id}/methods/", json={"methods": [uv]}))
    return product, area_id


def area_body(anchor: dict, **extra) -> dict:
    return {"key": "front", "name": "Old tomon", "width_mm": "300", "height_mm": "400", "anchor": anchor, **extra}


@pytest.mark.asyncio
async def test_model_upload_checks_the_glb_header(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    good = await upload_model(admin_client, storage, glb_bytes())
    not_glb = await upload_model(admin_client, storage, glb_bytes(magic=b"PNG\0"))
    gltf1 = await upload_model(admin_client, storage, glb_bytes(version=1))
    truncated = await upload_model(admin_client, storage, glb_bytes(length=999))

    assert good.status_code == 200 and good.json()["url"].startswith("https://media.test/models/")
    assert (not_glb.status_code, not_glb.json()["detail"]) == (422, "Fayl GLB emas")
    assert gltf1.status_code == 422 and "glTF 2.0" in gltf1.json()["detail"]
    assert truncated.status_code == 422 and "buzilgan" in truncated.json()["detail"]
    # Rejected files don't stay in the bucket.
    assert len(storage.objects) == 1


@pytest.mark.asyncio
async def test_model_uploads_need_an_admin(client: httpx.AsyncClient, storage: FakeStorage) -> None:
    response = await client.post("/api/media/uploads/", json={"purpose": "model", "content_type": GLB_TYPE, "size_bytes": 10})
    too_big = {"purpose": "model", "content_type": GLB_TYPE, "size_bytes": 21 * 1024 * 1024}

    assert response.status_code == 401
    assert (await client.post("/api/media/uploads/", json={**too_big})).status_code == 422


@pytest.mark.asyncio
async def test_scale_placement_and_ready(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product, area_id = await model_shape(admin_client, storage)
    shape = product["shapes"][0]
    assert shape["model_url"].endswith(".glb")
    assert shape["model_transform"] == {"up_axis": "y", "yaw_deg": 0, "scale_ref": None}
    assert shape["areas"][0]["anchor"] == {}

    product = ok(await admin_client.patch(f"{A}/shapes/{shape['id']}/", json={
        "model_transform": {"up_axis": "z", "yaw_deg": 90},
        "scale": {"a": [0, 0, 0], "b": [0, 0, 360], "mm": "720"},
    }))
    shape = product["shapes"][0]
    assert shape["mm_per_unit"] == "2.000000"
    assert shape["model_transform"]["up_axis"] == "z" and shape["model_transform"]["yaw_deg"] == 90
    assert shape["model_transform"]["scale_ref"]["mm"] == "720"

    product = ok(await admin_client.put(f"{A}/areas/{area_id}/", json=area_body(PLACED, camera={
        "position": [0, 1200, 600], "target": [0, 1200, 90],
    })))
    anchor = product["shapes"][0]["areas"][0]["anchor"]
    # Normal and up come back as an orthonormal pair.
    assert anchor["normal"] == [0, 0, 1]
    assert anchor["up"] == [0, 1, 0]
    assert anchor["max_angle_deg"] == 70

    no_checks = await admin_client.post(f"{A}/shapes/{shape['id']}/ready/")
    low = await admin_client.post(f"{A}/shapes/{shape['id']}/ready/", json={
        "checks": {str(area_id): {"coverage": 0.9, "stretched_share": 0}},
    })
    assert no_checks.status_code == 422 and "tekshirilmagan" in no_checks.json()["detail"]
    assert low.status_code == 422 and "90.0%" in low.json()["detail"]

    product = ok(await admin_client.post(f"{A}/shapes/{shape['id']}/ready/", json={
        "checks": {str(area_id): {"coverage": 0.995, "stretched_share": 0.2}},
    }))
    assert product["shapes"][0]["status"] == "ready"


@pytest.mark.asyncio
async def test_an_unplaced_area_blocks_ready(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product, area_id = await model_shape(admin_client, storage)
    shape_id = product["shapes"][0]["id"]
    ok(await admin_client.patch(f"{A}/shapes/{shape_id}/", json={"scale": {"a": [0, 0, 0], "b": [1, 0, 0], "mm": "500"}}))

    response = await admin_client.post(f"{A}/shapes/{shape_id}/ready/", json={
        "checks": {str(area_id): {"coverage": 1, "stretched_share": 0}},
    })

    assert response.status_code == 422 and "joylashtirilmagan" in response.json()["detail"]


@pytest.mark.asyncio
async def test_a_new_model_resets_scale_and_placements(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product, area_id = await model_shape(admin_client, storage)
    shape_id = product["shapes"][0]["id"]
    ok(await admin_client.patch(f"{A}/shapes/{shape_id}/", json={"scale": {"a": [0, 0, 0], "b": [1, 0, 0], "mm": "500"}}))
    ok(await admin_client.put(f"{A}/areas/{area_id}/", json=area_body(PLACED)))
    other = ok(await upload_model(admin_client, storage, glb_bytes(300)))

    product = ok(await admin_client.patch(f"{A}/shapes/{shape_id}/", json={"model_media_id": other["id"]}))

    shape = product["shapes"][0]
    assert shape["mm_per_unit"] is None and shape["model_transform"]["scale_ref"] is None
    assert shape["areas"][0]["anchor"] == {} and shape["areas"][0]["camera"] is None


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("anchor", "message"),
    [
        ({**PLACED, "normal": [0, 0, 0]}, "nol uzunlikdagi"),
        ({**PLACED, "up": [0, 0, 5]}, "parallel"),
        ({**PLACED, "max_angle_deg": 95}, "89"),
        ({key: value for key, value in PLACED.items() if key != "up"}, "majburiy"),
    ],
    ids=["zero-normal", "up-along-normal", "angle-too-wide", "missing-up"],
)
async def test_bad_placements_are_rejected(
    admin_client: httpx.AsyncClient, storage: FakeStorage, anchor: dict, message: str
) -> None:
    _, area_id = await model_shape(admin_client, storage)

    response = await admin_client.put(f"{A}/areas/{area_id}/", json=area_body(anchor))

    assert response.status_code == 422 and message in response.json()["detail"]


@pytest.mark.asyncio
async def test_model_settings_are_rejected_on_other_shapes(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = ok(await admin_client.post(f"{A}/products/", json={"slug": "k", "name": "K"}), 201)
    product = ok(await admin_client.post(f"{A}/products/{product['id']}/shapes/", json={
        "name": "Krujka", "kind": "cylinder", "dims": {"diameter_mm": "80", "height_mm": "95"},
    }), 201)
    shape_id = product["shapes"][0]["id"]
    image = await catalog_image(admin_client, storage)

    scale = await admin_client.patch(f"{A}/shapes/{shape_id}/", json={"scale": {"a": [0, 0, 0], "b": [1, 0, 0], "mm": "5"}})
    wrong_file = await admin_client.patch(f"{A}/shapes/{shape_id}/", json={"model_media_id": image})
    checks = await admin_client.post(f"{A}/shapes/{shape_id}/ready/", json={"checks": {"1": {"coverage": 1, "stretched_share": 0}}})

    assert scale.status_code == 422 and wrong_file.status_code == 422
    assert checks.status_code == 422


@pytest.mark.asyncio
async def test_a_model_file_must_be_a_model_upload(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = ok(await admin_client.post(f"{A}/products/", json={"slug": "f", "name": "F"}), 201)
    product = ok(await admin_client.post(f"{A}/products/{product['id']}/shapes/", json={"name": "M", "kind": "model", "dims": {}}), 201)
    image = await catalog_image(admin_client, storage)

    response = await admin_client.patch(f"{A}/shapes/{product['shapes'][0]['id']}/", json={"model_media_id": image})

    assert response.status_code == 422 and "3D model" in response.json()["detail"]


@pytest.mark.asyncio
async def test_scale_must_be_plausible(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product, _ = await model_shape(admin_client, storage)
    shape_id = product["shapes"][0]["id"]

    same_point = await admin_client.patch(f"{A}/shapes/{shape_id}/", json={"scale": {"a": [1, 1, 1], "b": [1, 1, 1], "mm": "5"}})
    absurd = await admin_client.patch(f"{A}/shapes/{shape_id}/", json={"scale": {"a": [0, 0, 0], "b": [1e6, 0, 0], "mm": "1"}})

    assert same_point.status_code == 422 and absurd.status_code == 422


@pytest.mark.asyncio
async def test_a_ready_model_product_is_sold_with_its_model(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product, area_id = await model_shape(admin_client, storage)
    shape_id = product["shapes"][0]["id"]
    ok(await admin_client.patch(f"{A}/shapes/{shape_id}/", json={"scale": {"a": [0, 0, 0], "b": [1, 0, 0], "mm": "500"}}))
    ok(await admin_client.put(f"{A}/areas/{area_id}/", json=area_body(PLACED)))
    ok(await admin_client.post(f"{A}/shapes/{shape_id}/ready/", json={"checks": {str(area_id): {"coverage": 1, "stretched_share": 0}}}))
    ok(await admin_client.put(f"{A}/products/{product['id']}/price-tiers/uv/", json={"tiers": UV_TIERS}))
    product = ok(await admin_client.post(f"{A}/products/{product['id']}/variants/", json={
        "shape_id": shape_id, "name": "Paxta", "base_price": "99000", "methods": ["uv"], "material": "fabric",
    }), 201)
    ok(await admin_client.post(f"{A}/variants/{product['variants'][0]['id']}/colors/", json={"name": "Oq", "hex": "#ffffff"}), 201)

    detail = ok(await admin_client.get("/api/catalog/products/futbolka/"))

    public_shape = detail["shapes"][0]
    assert public_shape["kind"] == "model" and public_shape["model_url"].endswith(".glb")
    assert public_shape["mm_per_unit"] == "500.000000"
    assert public_shape["areas"][0]["anchor"]["normal"] == [0, 0, 1]


@pytest.mark.asyncio
async def test_a_print_can_wrap_round_the_model(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product, area_id = await model_shape(admin_client, storage)

    wrapped = ok(await admin_client.put(f"{A}/areas/{area_id}/", json=area_body({**PLACED, "wrap_radius_mm": "41"})))
    flat = ok(await admin_client.put(f"{A}/areas/{area_id}/", json=area_body({**PLACED, "wrap_radius_mm": None})))
    bad = await admin_client.put(f"{A}/areas/{area_id}/", json=area_body({**PLACED, "wrap_radius_mm": "-3"}))

    assert wrapped["shapes"][0]["areas"][0]["anchor"]["wrap_radius_mm"] == "41"
    assert flat["shapes"][0]["areas"][0]["anchor"]["wrap_radius_mm"] is None
    assert bad.status_code == 422
