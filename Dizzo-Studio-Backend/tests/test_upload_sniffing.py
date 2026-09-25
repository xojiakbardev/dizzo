"""Uploaded bytes must match the declared content type."""

import httpx
import pytest

from app.api.v1.media import image_content_error, pdf_content_error
from tests.conftest import FakeStorage, tiny_image


async def complete(client: httpx.AsyncClient, storage: FakeStorage, content_type: str, body: bytes) -> httpx.Response:
    ticket = await client.post(
        "/api/media/uploads/", json={"purpose": "design", "content_type": content_type, "size_bytes": len(body)}
    )
    assert ticket.status_code == 201, ticket.text
    storage.put(ticket.json()["upload_url"], size_bytes=len(body), content_type=content_type, body=body)
    return await client.post(f"/api/media/{ticket.json()['id']}/complete/")


@pytest.mark.asyncio
async def test_only_real_images_become_ready(client: httpx.AsyncClient, storage: FakeStorage) -> None:
    png, jpeg, webp = tiny_image("image/png"), tiny_image("image/jpeg"), tiny_image("image/webp")

    for content_type, body in (("image/png", png), ("image/jpeg", jpeg), ("image/webp", webp)):
        assert (await complete(client, storage, content_type, body)).status_code == 200

    disguised = await complete(client, storage, "image/png", jpeg)
    script = await complete(client, storage, "image/jpeg", b"<script>alert(1)</script>")
    broken = await complete(client, storage, "image/png", png[:-20] + b"\x00" * 20)

    assert disguised.status_code == 422 and "PNG" in disguised.json()["detail"]
    assert script.status_code == 422 and broken.status_code == 422
    assert len(storage.objects) == 3  # the rejected objects were deleted


def test_content_checks() -> None:
    assert image_content_error("image/png", tiny_image("image/png")) is None
    assert image_content_error("image/webp", tiny_image("image/png")) is not None
    assert image_content_error("image/png", b"") is not None
    assert pdf_content_error(b"%PDF-1.7\n...") is None
    assert pdf_content_error(b"PK\x03\x04") == "Fayl PDF emas"
