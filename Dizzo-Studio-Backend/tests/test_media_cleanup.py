"""Retention: what the cleanup job deletes and, above all, what it doesn't
(app/services/media_cleanup.py, run by app/scripts/cleanup_media.py)."""

from datetime import UTC, datetime, timedelta

import httpx
import pytest
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.commerce import Design
from app.models.media import Media
from app.services import media_cleanup
from tests.conftest import FakeStorage, register
from tests.test_catalog import A, build_mug, catalog_image, color_id, ok
from tests.test_studio import UV_LAYER, UV_PX, document, png, shop
from tests.test_studio import upload as upload_file

IMAGE_LAYER = {
    "id": "img", "area": "wrap", "method": "uv", "kind": "image", "x_mm": 50, "y_mm": 40, "w_mm": 40, "h_mm": 40,
    "image": {"media_id": "", "url": "", "px_w": 10, "px_h": 10},
}


async def guest_upload(client: httpx.AsyncClient, storage: FakeStorage) -> dict:
    ticket = ok(await client.post(
        "/api/media/uploads/", json={"purpose": "design", "content_type": "image/png", "size_bytes": 2048},
    ), 201)
    storage.put(ticket["upload_url"], size_bytes=2048, content_type="image/png")
    return ok(await client.post(f"/api/media/{ticket['id']}/complete/"))


def key_of(media: dict) -> str:
    return media["url"].removeprefix("https://media.test/")


async def age(
    session_factory: async_sessionmaker[AsyncSession], *, days: float = 0, hours: float = 0,
    ids: list[str] | None = None,
) -> None:
    """Pretends the uploads were made that long ago."""
    query = update(Media).values(created_at=datetime.now(UTC) - timedelta(days=days, hours=hours))
    if ids is not None:
        query = query.where(Media.id.in_(ids))
    async with session_factory() as session:
        await session.execute(query)
        await session.commit()


async def sweep(
    session_factory: async_sessionmaker[AsyncSession], storage: FakeStorage, **kwargs
) -> dict[str, media_cleanup.Report]:
    async with session_factory() as session:
        return await media_cleanup.sweep(session, storage, **kwargs)


async def media_ids(session_factory: async_sessionmaker[AsyncSession]) -> set[str]:
    async with session_factory() as session:
        return set((await session.execute(select(Media.id))).scalars())


async def key_by_id(session_factory: async_sessionmaker[AsyncSession], media_id: str) -> str:
    async with session_factory() as session:
        return (await session.execute(select(Media.key).where(Media.id == media_id))).scalar_one()


@pytest.mark.asyncio
async def test_unclaimed_guest_uploads_go_and_claimed_ones_stay(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    forgotten = await guest_upload(client, storage)
    recent = await guest_upload(client, storage)
    claimed = await guest_upload(client, storage)
    await register(client, "claimer@example.com")
    [claimed] = ok(await client.post("/api/media/claim/", json={"ids": [claimed["id"]]}))
    await age(session_factory, days=8, ids=[forgotten["id"], claimed["id"]])

    reports = await sweep(session_factory, storage, dry_run=False)

    # Signing in is what saves a guest's picture; a week without one doesn't.
    assert reports["guests"].rows == 1
    assert await media_ids(session_factory) == {recent["id"], claimed["id"]}
    assert set(storage.objects) == {key_of(recent), key_of(claimed)}


@pytest.mark.asyncio
async def test_uploads_that_never_finished_are_cleaned_up(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    # The bytes reached the bucket but /complete/ never ran, so the row is
    # still pending and nothing will ever be able to use the file.
    abandoned = ok(await client.post(
        "/api/media/uploads/", json={"purpose": "design", "content_type": "image/png", "size_bytes": 2048},
    ), 201)
    storage.put(abandoned["upload_url"], size_bytes=2048, content_type="image/png")
    started_just_now = ok(await client.post(
        "/api/media/uploads/", json={"purpose": "design", "content_type": "image/png", "size_bytes": 2048},
    ), 201)
    await age(session_factory, hours=25, ids=[abandoned["id"]])

    reports = await sweep(session_factory, storage, dry_run=False)

    assert reports["pending"].rows == 1
    assert await media_ids(session_factory) == {started_just_now["id"]}
    assert storage.objects == {}


@pytest.mark.asyncio
async def test_a_dry_run_deletes_nothing(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    forgotten = await guest_upload(client, storage)
    await age(session_factory, days=8)

    reports = await sweep(session_factory, storage, dry_run=True)

    assert reports["guests"].rows == 1 and reports["guests"].sample == [key_of(forgotten)]
    assert reports["guests"].bytes == 2048
    assert await media_ids(session_factory) == {forgotten["id"]}
    assert set(storage.objects) == {key_of(forgotten)}


@pytest.mark.asyncio
async def test_a_saved_design_keeps_its_pictures_and_the_rest_go(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    used = await upload_file(client, storage, "design", png((10, 10)))
    views = [await upload_file(client, storage, "design", png((64, 64))) for _ in range(5)]
    dropped = await upload_file(client, storage, "design", png((10, 10)))
    ok(await client.post("/api/studio/designs/", json={
        "variant_id": s["variant_id"], "color_id": s["black"], "previews": views,
        "document": document({**IMAGE_LAYER, "image": {**IMAGE_LAYER["image"], "media_id": used}}),
    }), 201)
    await age(session_factory, days=40)

    reports = await sweep(session_factory, storage, dry_run=False)

    # The design names its picture by id and its five views by storage key:
    # both count, and only the upload nothing ever used is collected.
    left = await media_ids(session_factory)
    assert reports["orphans"].rows == 1 and reports["orphans"].sample[0].endswith(f"{dropped}.png")
    assert dropped not in left
    assert {used, *views} <= left


@pytest.mark.asyncio
async def test_media_an_order_froze_is_never_deleted(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    picture = await upload_file(client, storage, "design", png((10, 10)))
    print_file = await upload_file(client, storage, "print", png(UV_PX, (500, 60, 2000, 860, (200, 30, 40, 255))))
    mockup = await upload_file(client, storage, "design", png((64, 64)))
    ok(await client.post("/api/cart/items/", json={
        "variant_id": s["variant_id"], "color_id": s["black"], "quantity": 1, "expected_unit_price": "149000",
        "document": document({**IMAGE_LAYER, "image": {**IMAGE_LAYER["image"], "media_id": picture}}),
        "files": [{"area": "wrap", "method": "uv", "media_id": print_file}], "mockups": [mockup],
    }), 201)
    order = ok(await client.post("/api/checkout/", json={
        "contact_name": "Test", "contact_phone": "+998901234567", "delivery_method": "PICKUP",
    }))
    picture_key = await key_by_id(session_factory, picture)
    await age(session_factory, days=400)

    reports = await sweep(session_factory, storage, dry_run=False)

    # The order's own files were copied under orders/ and have no media row,
    # but the picture inside the document it froze is still named by id — so
    # the line can be reprinted years later.
    left = await media_ids(session_factory)
    assert picture in left and picture_key in storage.objects
    assert f"orders/{order['order_number']}/1/wrap-uv.png" in storage.objects
    # Exactly two files went: the print file and the mockup, both of which
    # the order copied. The shop's own pictures were never in question.
    assert reports["orphans"].rows == 2
    assert not {print_file, mockup} & left


@pytest.mark.asyncio
async def test_a_customer_may_keep_more_designs_than_the_old_cap(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    body = {"variant_id": s["variant_id"], "color_id": s["black"], "document": document(UV_LAYER)}
    first = ok(await client.post("/api/studio/designs/", json=body), 201)
    async with session_factory() as session:
        saved = (await session.execute(select(Design))).scalars().one()
        session.add_all([
            Design(
                owner_id=saved.owner_id, product_id=saved.product_id, variant_id=saved.variant_id,
                color_id=saved.color_id, document=saved.document, areas_cm2={}, previews=[],
            )
            for _ in range(30)
        ])
        await session.commit()

    another = ok(await client.post("/api/studio/designs/", json=body), 201)
    assert another["id"] != first["id"]


@pytest.mark.asyncio
async def test_a_colours_card_picture_is_never_an_orphan(
    admin_client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    """VariantColor.card_media_id must be one of media_cleanup.MEDIA_COLUMNS.
    It is a foreign key the reference graph is written out by hand, and the
    failure mode of leaving it out is every colour card deleted from R2."""
    product = await build_mug(admin_client, storage)
    card = await catalog_image(admin_client, storage)
    forgotten = await catalog_image(admin_client, storage)
    ok(await admin_client.patch(f"{A}/colors/{color_id(product, 'Qora')}/", json={"card_media_id": card}))
    card_key = await key_by_id(session_factory, card)
    forgotten_key = await key_by_id(session_factory, forgotten)
    await age(session_factory, days=40)

    dry = await sweep(session_factory, storage, dry_run=True)
    real = await sweep(session_factory, storage, dry_run=False)

    # Only the upload nobody ever used is in the running, in the dry run
    # that reports and in the run that deletes.
    assert dry["orphans"].rows == 1 and dry["orphans"].sample == [forgotten_key]
    assert real["orphans"].rows == 1
    left = await media_ids(session_factory)
    assert card in left and forgotten not in left
    assert card_key in storage.objects
