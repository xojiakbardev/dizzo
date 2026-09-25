"""Small WebP copies of the catalog's pictures, for phones.

A catalog picture is uploaded at full size (often a 700 KB PNG) but shown
in a 200-pixel card. Next to every such file this writes
`<key>.w480.webp` and `<key>.w960.webp` (never wider than the original);
the frontend asks for them by that name (app/utils/thumb.ts) and falls back
to the original while one is missing.
"""

import asyncio
import io
import logging

from PIL import Image, ImageOps

from app.services.storage import R2Storage

logger = logging.getLogger(__name__)

WIDTHS = (480, 960)
QUALITY = 80
# Pictures the frontend shows through thumbnails.
THUMB_PREFIXES = ("catalog/",)
IMAGE_TYPES = ("image/png", "image/jpeg", "image/webp")


def thumb_key(key: str, width: int) -> str:
    return f"{key}.w{width}.webp"


def wants_thumbnails(key: str, content_type: str) -> bool:
    return key.startswith(THUMB_PREFIXES) and content_type in IMAGE_TYPES


def render_thumbnails(data: bytes) -> dict[int, bytes]:
    """{width: webp bytes}, each at most `width` wide (a smaller original
    is kept at its own size, only re-encoded)."""
    with Image.open(io.BytesIO(data)) as source:
        image = ImageOps.exif_transpose(source)
        image = image.convert("RGBA" if image.mode in ("RGBA", "LA", "P") else "RGB")
    out: dict[int, bytes] = {}
    for width in WIDTHS:
        copy = image
        if image.width > width:
            height = max(1, round(image.height * width / image.width))
            copy = image.resize((width, height), Image.Resampling.LANCZOS)
        buffer = io.BytesIO()
        copy.save(buffer, "WEBP", quality=QUALITY, method=4)
        out[width] = buffer.getvalue()
    return out


async def make_thumbnails(storage: R2Storage, key: str) -> None:
    """Writes the key's thumbnails; failures are logged, never raised (the
    original still works)."""
    try:
        data = await storage.read(key)
        thumbs = await asyncio.to_thread(render_thumbnails, data)
        for width, body in thumbs.items():
            await storage.put_bytes(thumb_key(key, width), body, "image/webp")
    except Exception:  # noqa: BLE001
        logger.exception("thumbnails for %s failed", key)
