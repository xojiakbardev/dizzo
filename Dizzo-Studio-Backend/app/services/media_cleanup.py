"""Retention: which uploads R2 is allowed to forget.

A file is deleted only when nothing in the database points at it any more.
That reference graph is worked out here in full — every foreign key to
`media`, and the media ids and storage keys buried in the JSON of designs,
templates, cart items and order lines — and three kinds of leftover are
swept against it:

    pending   an upload URL was issued and the upload never finished
              (PENDING_UPLOAD_TTL_HOURS)
    guests    a signed-out visitor's picture under designs/guests/ that no
              sign-in ever claimed (GUEST_MEDIA_TTL_DAYS)
    orphans   a finished upload nothing references any more: the print files
              of a cart item that became an order and was cleared, a picture
              dropped from a design (ORPHAN_MEDIA_TTL_DAYS)

Anything an order keeps is safe by construction. Checkout copies every file
under orders/ and those copies have no media row of their own, while the
pictures inside the line's frozen document stay named by their media id —
which counts here as a reference, so the order can still be reprinted years
later.

Each pass says in SQL exactly which rows it may even look at; none of them
starts from "every file" and subtracts. A row nobody claims is still kept
until it is older than its window, so an upload a few seconds ahead of the
save that will use it is never in the running.

app/scripts/cleanup_media.py runs this. Nothing in a request does.
"""

from __future__ import annotations

import logging
from collections.abc import AsyncIterator, Sequence
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from urllib.parse import urlparse

from sqlalchemy import Select, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.catalog import (
    CatalogImage,
    DesignTemplate,
    DesignTemplateImage,
    Product,
    ProductCategory,
    Shape,
    Variant,
    VariantColor,
)
from app.models.commerce import CartItem, Design, OrderItem
from app.models.gallery import GalleryShowcaseImage
from app.models.media import Media
from app.models.review import ReviewPhoto
from app.models.setting import SystemSetting
from app.models.tutorial import TutorialVideo
from app.models.user import User
from app.services.storage import R2Storage
from app.services.thumbnails import WIDTHS, thumb_key, wants_thumbnails

logger = logging.getLogger(__name__)

PASSES = ("pending", "guests", "orphans")
# Rows read, and deleted, at a time: a run that is interrupted has committed
# whole batches, and the next one carries on where it stopped.
BATCH = 500
# Keys kept in a report, so a dry run names what it found without printing
# a hundred thousand lines.
SAMPLE = 20

# Every column that names a media row. Written out rather than read off the
# metadata: a new reference must be added here deliberately, and the failure
# mode of forgetting one is a deleted file.
MEDIA_COLUMNS = (
    Product.cover_media_id,
    ProductCategory.image_media_id,
    Shape.model_media_id,
    CatalogImage.media_id,
    DesignTemplate.preview_media_id,
    DesignTemplateImage.media_id,
    GalleryShowcaseImage.media_id,
    ReviewPhoto.media_id,
    TutorialVideo.cover_media_id,
    Design.preview_media_id,
)


@dataclass(frozen=True)
class References:
    """Everything the database still points at, by media id and by storage
    key — media is named both ways, so both are collected."""

    ids: frozenset[str]
    keys: frozenset[str]

    def holds(self, media: Media) -> bool:
        return media.id in self.ids or media.key in self.keys


@dataclass
class Report:
    """What one pass did, or in a dry run would have done."""

    rows: int = 0
    bytes: int = 0
    # Rows whose file the bucket refused to delete: left in place, so the
    # next run tries them again instead of leaking a file nobody can find.
    failed: int = 0
    sample: list[str] = field(default_factory=list)


def document_media_ids(document: object) -> set[str]:
    """The media ids of a design document's image layers. Read defensively:
    old documents and hand-edited ones are still plain JSON."""
    layers = document.get("layers") if isinstance(document, dict) else None
    ids: set[str] = set()
    for layer in layers or []:
        image = layer.get("image") if isinstance(layer, dict) else None
        if isinstance(image, dict) and isinstance(image.get("media_id"), str):
            ids.add(image["media_id"])
    return ids


def package_media_ids(package: object) -> set[str]:
    """The pictures a frozen cart or order package still shows."""
    return document_media_ids(package.get("document") if isinstance(package, dict) else None)


def package_keys(package: object) -> set[str]:
    """The storage keys a frozen package names: its print files, its mockup
    frames and, on an order, the white underbase masks."""
    if not isinstance(package, dict):
        return set()
    keys: set[str] = set()
    for group in ("files", "mockups", "underbase"):
        for item in package.get(group) or []:
            if isinstance(item, dict) and isinstance(item.get("key"), str):
                keys.add(item["key"])
    return keys


def keys_in_url(text: str | None, public_prefix: str) -> set[str]:
    """The storage key a stored URL (a user's avatar, an admin's setting)
    might be naming. Both readings are kept because the bucket's public
    domain may have changed since it was written; a reading that matches
    nothing costs nothing, and a false match only ever means "keep it"."""
    if not text:
        return set()
    return {text.removeprefix(public_prefix).lstrip("/"), urlparse(text).path.lstrip("/")} - {""}


async def references(session: AsyncSession, storage: R2Storage) -> References:
    """Reads the whole reference graph. Only the columns that can name a
    file are selected, but this is still the heavy part of a run — which is
    why it happens once, off peak, and not per row."""
    ids: set[str] = set()
    keys: set[str] = set()

    for column in MEDIA_COLUMNS:
        ids.update((await session.execute(select(column).where(column.is_not(None)))).scalars())

    # A design names its pictures by id in the document and its five Studio
    # views by storage key.
    for document, previews in (await session.execute(select(Design.document, Design.previews))).all():
        ids |= document_media_ids(document)
        keys.update(key for key in previews or [] if isinstance(key, str))

    for (document,) in (await session.execute(select(DesignTemplate.document))).all():
        ids |= document_media_ids(document)

    for (package,) in (await session.execute(select(CartItem.package))).all():
        ids |= package_media_ids(package)
        keys |= package_keys(package)

    # An order's files were copied under orders/ and have no media row, but
    # the document it froze still names the customer's own uploads.
    for (package,) in (await session.execute(select(OrderItem.package))).all():
        ids |= package_media_ids(package)
        keys |= package_keys(package)

    # Avatars and the admin's free-text settings hold a URL, not an id.
    public_prefix = storage.public_url("")
    for (avatar,) in (await session.execute(select(User.avatar).where(User.avatar.is_not(None)))).all():
        keys |= keys_in_url(avatar, public_prefix)
    for (value,) in (await session.execute(select(SystemSetting.value))).all():
        keys |= keys_in_url(value, public_prefix)

    return References(ids=frozenset(ids), keys=frozenset(keys))


def cutoffs(now: datetime) -> dict[str, datetime]:
    settings = get_settings()
    return {
        "pending": now - timedelta(hours=settings.pending_upload_ttl_hours),
        "guests": now - timedelta(days=settings.guest_media_ttl_days),
        "orphans": now - timedelta(days=settings.orphan_media_ttl_days),
    }


def candidates(name: str, cutoff: datetime) -> Select:
    """The only rows a pass is allowed to consider, spelled out in SQL."""
    older = select(Media).where(Media.created_at < cutoff)
    if name == "pending":
        return older.where(Media.status == "pending")
    if name == "guests":
        # Pictures from before the bucket was rearranged sit under the old
        # prefix and are not matched here; the orphan pass reaches them.
        return older.where(
            Media.status == "ready",
            Media.owner_id.is_(None),
            Media.purpose == "design",
            Media.key.startswith(get_settings().guest_prefix, autoescape=True),
        )
    if name == "orphans":
        return older.where(Media.status == "ready")
    raise ValueError(f"unknown cleanup pass: {name}")


async def _pages(session: AsyncSession, query: Select, batch: int) -> AsyncIterator[list[Media]]:
    """Walks a pass's candidates `batch` rows at a time, carrying on from
    the last id seen — so rows that are kept can never crowd out the ones
    behind them, however many of them there are."""
    after = ""
    while True:
        page = (
            (await session.execute(query.where(Media.id > after).order_by(Media.id).limit(batch))).scalars().all()
        )
        if not page:
            return
        after = page[-1].id
        yield list(page)


def object_keys(media: Media) -> list[str]:
    """The file and everything written beside it (its WebP thumbnails)."""
    keys = [media.key]
    if wants_thumbnails(media.key, media.content_type):
        keys += [thumb_key(media.key, width) for width in WIDTHS]
    return keys


async def _delete(
    session: AsyncSession, storage: R2Storage, rows: list[Media], report: Report, *, dry_run: bool
) -> None:
    deleted = False
    for media in rows:
        if len(report.sample) < SAMPLE:
            report.sample.append(media.key)
        if dry_run:
            report.rows += 1
            report.bytes += media.size_bytes or 0
            continue
        # The file goes before the row: a run killed in between leaves a row
        # with nothing behind it, which the next run deletes again (deleting
        # an object that is already gone does nothing). The other order would
        # leak the file for good, with no row left to find it by.
        try:
            for key in object_keys(media):
                await storage.delete(key)
        except Exception:  # noqa: BLE001 — one unhappy file must not end the run
            logger.exception("keeping media %s: the bucket refused to delete %s", media.id, media.key)
            report.failed += 1
            continue
        await session.delete(media)
        deleted = True
        report.rows += 1
        report.bytes += media.size_bytes or 0
    if deleted:
        await session.commit()


async def sweep(
    session: AsyncSession,
    storage: R2Storage,
    *,
    dry_run: bool = True,
    passes: Sequence[str] = PASSES,
    batch: int = BATCH,
    limit: int | None = None,
    now: datetime | None = None,
) -> dict[str, Report]:
    """Deletes the uploads nothing uses any more and reports what went, per
    pass. Dry by default: deleting from R2 cannot be undone, so a caller
    that forgets to say has asked for a report."""
    now = now or datetime.now(UTC)
    held = await references(session, storage)
    windows = cutoffs(now)
    reports = {name: Report() for name in passes}
    for name in passes:
        report = reports[name]
        async for page in _pages(session, candidates(name, windows[name]), batch):
            unused = [media for media in page if not held.holds(media)]
            if limit is not None:
                unused = unused[: max(0, limit - report.rows)]
            await _delete(session, storage, unused, report, dry_run=dry_run)
            if limit is not None and report.rows >= limit:
                break
    return reports
