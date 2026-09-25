"""The product-image rework: a colour's own card picture, where a gallery
image came from, and the guarantee that no listing card is ever imageless.

The admin used to have to put a card-shaped photo first in a colour's
gallery, because the colour-picking card took element 0. A colour now has
its own `card_media_id` and the gallery is only the customer's slideshow —
five pictures at most, each stamped with the `source` that wrote it.
"""

from __future__ import annotations

import importlib.util
import io
from pathlib import Path

import httpx
import pytest
from alembic.migration import MigrationContext
from alembic.operations import Operations
from alembic.script import ScriptDirectory

from app.api.v1.admin_catalog import MAX_COLOR_IMAGES
from app.db.base import Base
from app.models.catalog import CatalogImage, VariantColor
from app.services import feed_cache
from tests.conftest import FakeStorage
from tests.test_catalog import A, build_mug, catalog_image, color_id, ok

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = "0028_color_card_image.py"


# ── The migration ─────────────────────────────────────────────────────────


def load_migration(name: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "migrations" / "versions" / name)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def emitted_sql(direction: str) -> str:
    """The DDL the migration writes for PostgreSQL, without a server: the
    migration really runs, against the dialect production uses."""
    migration = load_migration(MIGRATION)
    buffer = io.StringIO()
    context = MigrationContext.configure(
        url="postgresql+asyncpg://",
        opts={
            "as_sql": True, "output_buffer": buffer, "literal_binds": True, "target_metadata": Base.metadata,
        },
    )
    with Operations.context(context):
        getattr(migration, direction)()
    return buffer.getvalue()


def test_the_card_image_migration_follows_0027_on_the_one_line_of_migrations() -> None:
    script = ScriptDirectory(str(ROOT / "migrations"))

    # One line, never a branch: whatever the head is, 0028 is on the way to it.
    assert len(list(script.get_heads())) == 1
    assert script.get_revision("0028").down_revision == "0027"


def test_the_card_image_migration_applies() -> None:
    upgrade = emitted_sql("upgrade")
    downgrade = emitted_sql("downgrade")

    assert "ALTER TABLE variant_colors ADD COLUMN card_media_id VARCHAR(36)" in upgrade
    assert "REFERENCES media (id) ON DELETE SET NULL" in upgrade
    assert "CREATE INDEX ix_variant_colors_card_media_id ON variant_colors (card_media_id)" in upgrade
    # NOT NULL with a default, so rows that already exist are 'manual'
    # before the CHECK that follows could ever refuse one.
    assert "ALTER TABLE catalog_images ADD COLUMN source VARCHAR(16) DEFAULT 'manual' NOT NULL" in upgrade
    assert "UPDATE catalog_images SET source = 'manual'" in upgrade
    assert "CHECK (source IN ('manual', 'render'))" in upgrade
    assert upgrade.index("ADD COLUMN source") < upgrade.index("CHECK (source IN")

    assert "DROP CONSTRAINT ck_catalog_images_source" in downgrade
    assert "DROP COLUMN source" in downgrade
    assert "DROP COLUMN card_media_id" in downgrade


def test_the_models_carry_what_the_migration_adds() -> None:
    source = CatalogImage.__table__.c.source

    assert source.server_default.arg == "manual" and not source.nullable
    # The same name the migration writes: the naming convention renders
    # CheckConstraint(name="source") on catalog_images as this.
    checks = {c.name: str(c.sqltext) for c in CatalogImage.__table__.constraints if hasattr(c, "sqltext")}
    assert checks["ck_catalog_images_source"] == "source IN ('manual', 'render')"


# ── The admin writes ──────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_a_colour_takes_five_gallery_images_and_refuses_the_sixth(
    admin_client: httpx.AsyncClient, storage: FakeStorage
) -> None:
    product = await build_mug(admin_client, storage)
    black = color_id(product, "Qora")
    pictures = [await catalog_image(admin_client, storage) for _ in range(MAX_COLOR_IMAGES + 1)]

    too_many = await admin_client.put(f"{A}/colors/{black}/images/", json={"media_ids": pictures})
    filled = await admin_client.put(f"{A}/colors/{black}/images/", json={"media_ids": pictures[:MAX_COLOR_IMAGES]})

    assert MAX_COLOR_IMAGES == 5
    assert too_many.status_code == 422, too_many.text
    assert "5" in too_many.json()["detail"]
    assert len(color_of(ok(filled), "Qora")["images"]) == 5


@pytest.mark.asyncio
async def test_the_source_of_a_gallery_image_round_trips(
    admin_client: httpx.AsyncClient, storage: FakeStorage
) -> None:
    product = await build_mug(admin_client, storage)
    black = color_id(product, "Qora")
    rendered = [await catalog_image(admin_client, storage) for _ in range(2)]
    photographed = await catalog_image(admin_client, storage)

    generated = ok(await admin_client.put(
        f"{A}/colors/{black}/images/", json={"media_ids": rendered, "source": "render"}
    ))
    by_hand = ok(await admin_client.put(
        f"{A}/products/{product['id']}/images/", json={"media_ids": [photographed]}
    ))
    nonsense = await admin_client.put(
        f"{A}/colors/{black}/images/", json={"media_ids": rendered, "source": "guesswork"}
    )

    assert [i["source"] for i in color_of(generated, "Qora")["images"]] == ["render", "render"]
    # No source given means a human put it there.
    assert [i["source"] for i in by_hand["images"]] == ["manual"]
    assert nonsense.status_code == 422


# ── The public views ──────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_the_storefront_derives_colour_card_from_gallery_primary_image(
    admin_client: httpx.AsyncClient, storage: FakeStorage
) -> None:
    product = await build_mug(admin_client, storage)
    black = color_id(product, "Qora")
    gallery = [await catalog_image(admin_client, storage) for _ in range(3)]
    ok(await admin_client.put(f"{A}/colors/{black}/images/", json={"media_ids": gallery}))

    detail = ok(await admin_client.get("/api/catalog/products/krujka/"))

    colour = next(c for c in detail["variants"][0]["colors"] if c["name"] == "Qora")
    assert colour["card_image_url"] == f"https://media.test/catalog/{gallery[0]}.png"
    assert colour["images"] == [f"https://media.test/catalog/{m}.png" for m in gallery]
    # A colour with no gallery images has card_image_url None
    assert next(c for c in detail["variants"][0]["colors"] if c["name"] == "Qizil")["card_image_url"] is None


@pytest.mark.asyncio
async def test_the_product_detail_carries_the_products_description(
    admin_client: httpx.AsyncClient, storage: FakeStorage
) -> None:
    product = await build_mug(admin_client, storage)
    ok(await admin_client.patch(f"{A}/products/{product['id']}/", json={
        "description": "<p>Har kuni ishlatiladigan krujka</p>",
        "translations": {"ru": {"description": "<p>Кружка на каждый день</p>"}},
    }))

    uzbek = ok(await admin_client.get("/api/catalog/products/krujka/"))
    russian = ok(await admin_client.get("/api/catalog/products/krujka/?lang=ru"))

    assert uzbek["description"] == "<p>Har kuni ishlatiladigan krujka</p>"
    assert russian["description"] == "<p>Кружка на каждый день</p>"


@pytest.mark.asyncio
async def test_a_product_without_a_cover_falls_back_to_a_variants_main_image(
    admin_client: httpx.AsyncClient, storage: FakeStorage
) -> None:
    product = await build_mug(admin_client, storage)
    black = color_id(product, "Qora")
    main = await catalog_image(admin_client, storage)
    ok(await admin_client.put(f"{A}/colors/{black}/images/", json={"media_ids": [main]}))
    ok(await admin_client.patch(f"{A}/products/{product['id']}/", json={"cover_media_id": None}))
    feed_cache.clear()

    [card] = ok(await admin_client.get("/api/catalog/products/"))
    detail = ok(await admin_client.get("/api/catalog/products/krujka/"))

    # No listing card is imageless because somebody forgot the cover.
    assert card["cover_url"] == f"https://media.test/catalog/{main}.png"
    assert detail["cover_url"] == f"https://media.test/catalog/{main}.png"
    assert detail["variants"][0]["main_image_url"] == f"https://media.test/catalog/{main}.png"
    # Deprecated alias, one release only: the Flutter app still reads it.
    assert detail["variants"][0]["variant_main_image"] == detail["variants"][0]["main_image_url"]


def color_of(product: dict, name: str) -> dict:
    return next(c for c in product["variants"][0]["colors"] if c["name"] == name)
