"""Cart packages: building them from the Studio's upload, serialising them
for the cart and orders, and copying them into an order.

A package (CartItem.package / OrderItem.package) is plain JSON:

    {
      "product": {"slug", "name"}, "variant": {"id", "name", "material"},
      "color": {"id", "name", "hex"}, "size": "M" | null, "shape": {"id", "name", "kind"},
      "print_scale": "0.75",        # the size's share of the print area
      "document": DesignDocument,
      "quote": QuoteOut,
      "files": [{"area", "area_name", "method", "key", "width_px", "height_px", "dpi", "painted_cm2"}],
      "underbase": [{"area", "area_name", "key"}],          # orders only
      "mockups": [{"key"}],
      "placements": [{"area", "area_name", "width_mm", "height_mm", "max_width_mm", "max_height_mm",
                      "print_scale", "placement_note", "anchor"}],
    }

A placement's width_mm/height_mm are the print at the size ordered;
max_width_mm/max_height_mm are the area's own (the largest size).

Files are referenced by storage key, so a copy under orders/ is just a new
key; URLs are derived when the package is shown. The names in it are the
Uzbek ones: a cart shows the catalog's current translations of them, and an
order line keeps its own (OrderItem.translations, see line_translations).
"""

from __future__ import annotations

import asyncio
from decimal import Decimal

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.i18n import OTHER_LANGUAGES, _, tr_dict
from app.models.catalog import Variant, VariantColor
from app.models.commerce import CartItem, OrderItem
from app.models.media import Media
from app.models.user import User
from app.schemas.catalog import QuoteOut
from app.schemas.design import CartItemIn, CartItemOut, DesignDocument, PackageFile
from app.services import print_files
from app.services.catalog import (
    is_sellable_color,
    is_sellable_variant,
    local_size,
    quote,
    resolve_size,
    size_names,
    size_scale,
)
from app.services.design_rules import FULL_SCALE, document_problems, required_files, size_mm, stored_strip
from app.services.storage import R2Storage


def unprocessable(detail: str) -> HTTPException:
    return HTTPException(status_code=422, detail=detail)


async def owned_media(session: AsyncSession, user: User, ids: list[str], purpose: str, what: str) -> dict[str, Media]:
    rows = {m.id: m for m in (await session.execute(select(Media).where(Media.id.in_(ids)))).scalars()}
    for media_id in ids:
        media = rows.get(media_id)
        if media is None or media.owner_id != user.id or media.purpose != purpose or media.status != "ready":
            raise unprocessable(_(
                "{what} topilmadi yoki sizga tegishli emas: {media_id}", what=_(what), media_id=media_id
            ))
    return rows


def image_is_allowed(row: Media | None, user: User) -> bool:
    if row is None or row.status != "ready":
        return False
    # Catalog icons/stickers and template library copies are public.
    if row.purpose in ("library", "catalog"):
        return True
    return row.purpose == "design" and row.owner_id == user.id


async def normalise_images(
    session: AsyncSession, user: User, document: DesignDocument, storage: R2Storage
) -> DesignDocument:
    """Every image layer must be the customer's own upload, a library
    image (from an admin's template), or a catalog Studio asset; its
    URL is taken from the media record, never from the client."""
    images = [layer.image for layer in document.layers if layer.image is not None]
    if not images:
        return document
    ids = list({i.media_id for i in images})
    media = {m.id: m for m in (await session.execute(select(Media).where(Media.id.in_(ids)))).scalars()}
    for media_id in ids:
        if not image_is_allowed(media.get(media_id), user):
            raise unprocessable(_("Rasm topilmadi yoki sizga tegishli emas: {media_id}", media_id=media_id))
    for image in images:
        image.url = storage.public_url(media[image.media_id].key)
    return document


async def variant_and_color(session: AsyncSession, variant_id: int, color_id: int) -> tuple[Variant, VariantColor]:
    variant = await session.get(Variant, variant_id)
    color = await session.get(VariantColor, color_id)
    if variant is None or variant.archived_at is not None:
        raise HTTPException(status_code=404, detail="Variant topilmadi")
    if color is None or color.variant_id != variant.id:
        raise unprocessable("Bu rang tanlangan variant uchun emas")
    return variant, color


def sellable(variant: Variant, color: VariantColor, size: str = "") -> bool:
    """Whether this exact combination can still be ordered. A cart item's
    size that ran out takes the item off sale, like a colour would; an item
    with no size (a mug, or one added before its product had sizes) is only
    judged on the variant and the colour."""
    product = variant.product
    if not (
        product.archived_at is None and product.is_available and is_sellable_variant(variant)
        and color.variant_id == variant.id and is_sellable_color(color)
    ):
        return False
    try:
        resolve_size(variant, size or None)
    except HTTPException:
        return False
    return True


def package_problems(package: dict | None, variant: Variant, size: str = "") -> list[str]:
    """The stored design checked again against the size the item is actually
    ordered in — the size is chosen after the design is made, and an admin
    may change a size's print scale while it sits in the cart. Everything
    that can no longer be printed comes back here."""
    if not isinstance(package, dict) or not isinstance(package.get("document"), dict):
        return []
    try:
        document = DesignDocument.model_validate(package["document"])
        chosen = resolve_size(variant, size or None)
    except (HTTPException, ValueError):
        return []
    return document_problems(document, variant, size_scale(chosen), chosen["label"] if chosen else "")


async def build_package(
    session: AsyncSession, user: User, payload: CartItemIn, variant: Variant, color: VariantColor, storage: R2Storage
) -> tuple[dict, QuoteOut]:
    """Validates the document and the print files and returns the package
    and its price. Raises 422 with the first problem found."""
    # A product with sizes is never added without one.
    size = resolve_size(variant, payload.size, required=True)
    # How much of each print area this size may use: below 1 the design must
    # fit the smaller box and the print files are cut to it.
    scale = size_scale(size)
    document = await normalise_images(session, user, payload.document, storage)
    problems = document_problems(document, variant, scale, size["label"] if size else "")
    if problems:
        raise unprocessable(problems[0])

    wanted = required_files(document, variant)
    given = [(f.area, f.method) for f in payload.files]
    if len(set(given)) != len(given):
        raise unprocessable("Bir hudud va usul uchun bitta bosma fayl bo'ladi")
    if set(given) != wanted:
        missing = sorted(wanted - set(given))
        extra = sorted(set(given) - wanted)
        raise unprocessable(_(
            "Bosma fayllar dizaynga mos emas (yetishmaydi: {missing}, ortiqcha: {extra})", missing=missing, extra=extra
        ))

    files_media = await owned_media(session, user, [f.media_id for f in payload.files], "print", "Bosma fayl")
    mockup_media = await owned_media(session, user, payload.mockups, "design", "Kadr")
    areas = {area.key: area for area in variant.shape.areas}

    files: list[dict] = []
    areas_cm2: dict[str, Decimal] = {}
    for item in payload.files:
        area = areas[item.area]
        method = next(m for m in area.methods if m.method == item.method)
        media = files_media[item.media_id]
        data = await storage.read(media.key)
        try:
            strip_x = stored_strip(document, area.key, method.method)
            analysed = await asyncio.to_thread(print_files.analyse, data, area, method, strip_x, scale)
        except print_files.PrintFileError as exc:
            raise unprocessable(f"“{area.name}” ({item.method}): {exc}") from exc
        areas_cm2[item.method] = areas_cm2.get(item.method, Decimal("0")) + analysed.painted_cm2
        files.append({
            "area": area.key, "area_name": area.name, "method": item.method, "key": media.key,
            "width_px": analysed.width_px, "height_px": analysed.height_px, "dpi": analysed.dpi,
            "painted_cm2": str(analysed.painted_cm2),
        })

    price = quote(variant, color, payload.quantity, areas_cm2, size["label"] if size else None)
    used = sorted({f["area"] for f in files})
    package = {
        "product": {"slug": variant.product.slug, "name": variant.product.name},
        "variant": {"id": variant.id, "name": variant.name, "material": variant.material},
        "color": {"id": color.id, "name": color.name, "hex": color.hex},
        "size": size["label"] if size else None,
        "shape": {"id": variant.shape.id, "name": variant.shape.name, "kind": variant.shape.kind},
        "white_underbase": variant.white_underbase,
        "document": document.model_dump(mode="json"),
        "quote": price.model_dump(mode="json"),
        "files": files,
        "mockups": [{"key": mockup_media[m].key} for m in payload.mockups],
        # What the factory measures out: the print's millimetres at the size
        # ordered, not the shape's maximum. `max_width_mm`/`max_height_mm`
        # keep the area's own size so the placement is still recognisable.
        "print_scale": str(scale),
        "placements": [
            {
                "area": key, "area_name": areas[key].name,
                "width_mm": str(size_mm(areas[key], scale)[0]), "height_mm": str(size_mm(areas[key], scale)[1]),
                "max_width_mm": str(areas[key].width_mm), "max_height_mm": str(areas[key].height_mm),
                "print_scale": str(scale), "placement_note": areas[key].placement_note,
                "anchor": areas[key].anchor,
            }
            for key in used
        ],
    }
    return package, price


def package_files(package: dict | None, storage: R2Storage) -> list[PackageFile]:
    if not package or not isinstance(package, dict):
        return []
    files = package.get("files") or []
    out: list[PackageFile] = []
    for f in files:
        if not isinstance(f, dict):
            continue
        try:
            painted = Decimal(str(f.get("painted_cm2", 0)))
        except Exception:
            painted = Decimal("0")
        out.append(
            PackageFile(
                area=f.get("area", ""),
                area_name=f.get("area_name", ""),
                method=f.get("method", ""),
                url=storage.public_url(f["key"]) if "key" in f else "",
                width_px=f.get("width_px", 0),
                height_px=f.get("height_px", 0),
                dpi=f.get("dpi", 0),
                painted_cm2=painted,
            )
        )
    return out


def cart_item_out(item: CartItem, storage: R2Storage) -> CartItemOut:
    package = item.package
    variant = item.variant
    price = QuoteOut.model_validate(package["quote"])
    price.size = local_size(variant, price.size)
    on_sale = sellable(item.variant, item.color, item.size)
    problems = package_problems(package, item.variant, item.size) if on_sale else []
    issue = problems[0] if problems else None if on_sale else _("Sotuvda yo'q")
    return CartItemOut(
        uuid=item.uuid, design_id=item.design_id, product_slug=package["product"]["slug"],
        product_name=tr_dict(variant.product.translations, "name", package["product"]["name"]),
        variant_id=item.variant_id, variant_name=tr_dict(variant.translations, "name", package["variant"]["name"]),
        color_id=item.color_id, color_name=tr_dict(item.color.translations, "name", package["color"]["name"]),
        color_hex=package["color"]["hex"], size=local_size(variant, item.size) or "", quantity=item.quantity,
        unit_price=item.unit_price, total_price=item.unit_price * item.quantity, quote=price,
        mockups=[storage.public_url(m["key"]) for m in package["mockups"]],
        files=package_files(package, storage), available=on_sale and not problems, issue=issue,
        created_at=item.created_at,
    )


def line_translations(variant: Variant, color: VariantColor, size: str) -> dict:
    """An order line's names in the other languages, as the catalog has
    them now: {"ru": {"product_name", "variant_name", "color_name", "size"}}."""

    def text(row, language: str) -> str | None:
        return ((row.translations or {}).get(language) or {}).get("name")

    out: dict[str, dict[str, str]] = {}
    for language in OTHER_LANGUAGES:
        texts = {
            "product_name": text(variant.product, language),
            "variant_name": text(variant, language),
            "color_name": text(color, language),
            "size": size_names(variant, language).get(size) if size else None,
        }
        texts = {field: value for field, value in texts.items() if value}
        if texts:
            out[language] = texts
    return out


def painted_areas(package: dict) -> dict[str, Decimal]:
    areas: dict[str, Decimal] = {}
    for f in package["files"]:
        areas[f["method"]] = areas.get(f["method"], Decimal("0")) + Decimal(f["painted_cm2"])
    return areas


async def resize_item(
    item: CartItem, size: dict | None, storage: R2Storage
) -> tuple[dict, dict[str, Decimal]]:
    """The item's package moved to another size: every print file cut to the
    new size box (print_files.recut — the ink does not move, the sheet
    does), re-measured, and the placements rewritten. Returns the new
    package and the painted cm² per method it now has."""
    package = item.package
    variant = item.variant
    was = Decimal(str(package.get("print_scale", FULL_SCALE)))
    now = size_scale(size)
    areas = {area.key: area for area in variant.shape.areas}
    files: list[dict] = []
    areas_cm2: dict[str, Decimal] = {}
    for entry in package.get("files") or []:
        area = areas.get(entry["area"])
        method = next((m for m in area.methods if m.method == entry["method"]), None) if area else None
        if area is None or method is None:
            raise unprocessable(_("“{area}” hududi bu variantda yo'q", area=entry["area"]))
        data = await storage.read(entry["key"])
        if now != was:
            data = await asyncio.to_thread(print_files.recut, data, area, method, was, now)
            await storage.put_bytes(entry["key"], data, "image/png")
        try:
            analysed = await asyncio.to_thread(print_files.analyse, data, area, method, None, now)
        except print_files.PrintFileError as exc:
            raise unprocessable(f"“{area.name}” ({entry['method']}): {exc}") from exc
        areas_cm2[entry["method"]] = areas_cm2.get(entry["method"], Decimal("0")) + analysed.painted_cm2
        files.append({
            **entry, "width_px": analysed.width_px, "height_px": analysed.height_px,
            "painted_cm2": str(analysed.painted_cm2),
        })
    placements = [
        {
            **placement,
            "width_mm": str(size_mm(areas[placement["area"]], now)[0]),
            "height_mm": str(size_mm(areas[placement["area"]], now)[1]),
            "print_scale": str(now),
        }
        if placement.get("area") in areas else placement
        for placement in package.get("placements") or []
    ]
    return {
        **package, "size": size["label"] if size else None, "print_scale": str(now),
        "files": files, "placements": placements,
    }, areas_cm2


async def copy_into_order(package: dict, order_number: str, line: int, storage: R2Storage) -> dict:
    """The package with every file copied under orders/<number>/<line>/,
    plus white underbase masks for UV prints when the variant needs them."""
    prefix = f"orders/{order_number}/{line}"
    copied = dict(package)
    copied["files"] = []
    copied["underbase"] = []
    for f in package["files"]:
        key = f"{prefix}/{f['area']}-{f['method']}.png"
        await storage.copy(f["key"], key)
        copied["files"].append({**f, "key": key})
        if package["white_underbase"] and f["method"] == "uv":
            mask = await asyncio.to_thread(print_files.underbase, await storage.read(f["key"]))
            mask_key = f"{prefix}/{f['area']}-oq-taglik.png"
            await storage.put_bytes(mask_key, mask, "image/png")
            copied["underbase"].append({"area": f["area"], "area_name": f["area_name"], "key": mask_key})
    copied["mockups"] = []
    for i, mockup in enumerate(package["mockups"], start=1):
        extension = mockup["key"].rsplit(".", 1)[-1]
        key = f"{prefix}/kadr-{i}.{extension}"
        await storage.copy(mockup["key"], key)
        copied["mockups"].append({"key": key})
    return copied


def order_item_payload(item: OrderItem, storage: R2Storage) -> dict:
    """An order line with its names in the request's language; the raw
    `translations` come along for the admin."""
    package = item.package if isinstance(getattr(item, "package", None), dict) else {}
    texts = item.translations if isinstance(getattr(item, "translations", None), dict) else {}
    price = package.get("quote") if isinstance(package, dict) else None
    if price and isinstance(price, dict) and price.get("size"):
        price = {**price, "size": tr_dict(texts, "size", price["size"])}
    mockups = package.get("mockups") if isinstance(package, dict) else []
    underbase = package.get("underbase") if isinstance(package, dict) else []
    placements = package.get("placements") if isinstance(package, dict) else []
    return {
        "id": item.id,
        "product_name": tr_dict(texts, "product_name", item.product_name),
        "product_slug": item.product_slug or "",
        "variant_name": tr_dict(texts, "variant_name", item.variant_name),
        "color_name": tr_dict(texts, "color_name", item.color_name),
        "color_hex": item.color_hex or "",
        "size": tr_dict(texts, "size", item.size) if item.size else item.size,
        "translations": texts or {},
        "unit_price": str(item.unit_price) if item.unit_price is not None else "0",
        "quantity": item.quantity or 0,
        "total_price": str((item.unit_price or 0) * (item.quantity or 0)),
        "production_status": item.production_status or "PENDING",
        "quote": price,
        "mockups": [storage.public_url(m["key"]) for m in (mockups or []) if isinstance(m, dict) and "key" in m],
        "files": [f.model_dump(mode="json") for f in package_files(package, storage)],
        "underbase": [
            {"area": u.get("area", ""), "area_name": u.get("area_name", ""), "url": storage.public_url(u["key"])}
            for u in (underbase or [])
            if isinstance(u, dict) and "key" in u
        ],
        "placements": placements or [],
        "shape": package.get("shape") if isinstance(package, dict) else None,
        "document": package.get("document") if isinstance(package, dict) else None,
        "created_at": item.created_at.isoformat() if item.created_at else None,
        "updated_at": item.updated_at.isoformat() if item.updated_at else None,
    }
