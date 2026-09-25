import httpx
import pytest

from app.schemas.design import DesignDocument
from tests.conftest import FakeStorage
from tests.test_catalog import A, catalog_image, ok


async def test_admin_manages_shelves_and_products_follow(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    shelves = ok(await admin_client.get(f"{A}/categories/"))
    assert [c["slug"] for c in shelves][:2] == ["idish-tovoq", "uy-buyumlari"]

    image = await catalog_image(admin_client, storage)
    shelf = ok(await admin_client.post(f"{A}/categories/", json={
        "slug": "sovgalar", "name": "Sovg'alar", "icon_svg": "<svg/>", "image_media_id": image, "sort_order": 5,
    }), 201)
    assert shelf["image_url"] and shelf["product_count"] == 0

    product = ok(await admin_client.post(f"{A}/products/", json={"slug": "quti", "name": "Quti", "category": "sovgalar"}), 201)
    assert product["category"] == "sovgalar"
    bad = await admin_client.post(f"{A}/products/", json={"slug": "yoq", "name": "Yo'q", "category": "yoq-kategoriya"})
    assert bad.status_code == 422

    # Renaming the slug moves its products along; a used shelf can't be deleted.
    shelf = ok(await admin_client.patch(f"{A}/categories/{shelf['id']}/", json={"slug": "sovga"}))
    assert shelf["product_count"] == 1
    assert ok(await admin_client.get(f"{A}/products/{product['id']}/"))["category"] == "sovga"
    assert (await admin_client.delete(f"{A}/categories/{shelf['id']}/")).status_code == 409

    ok(await admin_client.patch(f"{A}/categories/{shelf['id']}/", json={"is_active": False}))
    public = ok(await admin_client.get("/api/catalog/categories/"))
    assert "sovga" not in [c["slug"] for c in public] and public[0]["slug"] == "idish-tovoq"


def test_clock_numerals_layer_and_locks() -> None:
    layer = {
        "id": "dial1", "area": "dial", "method": "uv", "kind": "dial", "x_mm": 140, "y_mm": 140, "w_mm": 280, "h_mm": 280,
        "dial": {"font": "Montserrat", "size_mm": 22, "color": "#111111", "numerals": "roman"}, "locked": "system",
    }
    doc = DesignDocument.model_validate({"layers": [layer]})
    assert doc.layers[0].color == "#111111" and doc.layers[0].locked == "system"
    with pytest.raises(ValueError):
        DesignDocument.model_validate({"layers": [{**layer, "text": {"content": "x", "font": "Roboto", "size_mm": 5, "color": "#000000"}}]})
    with pytest.raises(ValueError):
        DesignDocument.model_validate({"layers": [{**layer, "locked": "admin"}]})
