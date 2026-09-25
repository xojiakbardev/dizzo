"""Admin API for the dynamic catalog. Every mutation returns the whole,
freshly loaded product, so the admin UI never shows stale nested data.

Shape lifecycle: draft (editable) -> ready (usable by variants) -> locked
(used by a design; edit a duplicate instead). Nothing that a cart or order
can reference is hard-deleted — it is archived.
"""

from __future__ import annotations

from copy import deepcopy
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, require_roles
from app.core.i18n import _ as msg  # `_` is taken: the endpoints' unused admin parameter
from app.db.session import get_db
from app.models.catalog import (
    METHODS,
    AreaMethod,
    CatalogImage,
    PriceTier,
    PrintArea,
    Product,
    ProductCategory,
    Shape,
    Variant,
    VariantColor,
)
from app.models.media import Media
from app.models.user import User
from app.schemas.catalog import (
    AdminProductListItem,
    AdminProductOut,
    AreaIn,
    AreaMethodIn,
    AreaMethodsIn,
    CategoryIn,
    CategoryOut,
    CategoryPatch,
    ColorIn,
    ColorPatch,
    ImagesIn,
    PairIn,
    ProductIn,
    ProductPatch,
    ReadyIn,
    ShapeIn,
    ShapeLayoutIn,
    ShapePatch,
    SizesIn,
    TiersIn,
    VariantIn,
    VariantPatch,
)
from app.schemas.i18n import merge_translations
from app.services.catalog import (
    area_fit_error,
    default_model_transform,
    mm_per_unit,
    pair_errors,
    partner_method_fields,
    partner_of,
    shape_ready_errors,
    unprocessable,
    validate_anchor,
    validate_dims,
    validate_tiers,
    zone_fit_error,
)
from app.services.catalog_views import admin_list_item, admin_product_out
from app.services.rich_text import clean_html
from app.services.storage import R2Storage, get_storage

router = APIRouter(prefix="/admin/catalog", tags=["admin-catalog"])

# How many pictures one colour's gallery may hold. The owner picked five:
# enough to show the thing from every side, few enough that the storefront
# slideshow stays a slideshow. The colour's card picture is not one of them
# (VariantColor.card_media_id), so this is five gallery photos on top of it.
MAX_COLOR_IMAGES = 5


def admin_user(user: User = Depends(get_current_user)) -> User:
    require_roles(user, "super_admin", "admin", "moderator")
    return user


def not_found(what: str) -> HTTPException:
    # "Mahsulot topilmadi" is catalogued whole, so each language words it its own way.
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"{what} topilmadi")


def conflict(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)


async def fetch(session: AsyncSession, model, obj_id: int, what: str):
    obj = await session.get(model, obj_id)
    if obj is None:
        raise not_found(what)
    return obj


async def fresh_product(session: AsyncSession, product_id: int, storage: R2Storage) -> AdminProductOut:
    # Drop every cached instance so all nested collections are reloaded.
    session.expunge_all()
    product = (await session.execute(select(Product).where(Product.id == product_id))).scalar_one()
    return admin_product_out(product, storage)


async def commit(session: AsyncSession, conflict_detail: str) -> None:
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise conflict(conflict_detail) from exc


async def catalog_media(session: AsyncSession, media_ids: list[str]) -> None:
    if len(set(media_ids)) != len(media_ids):
        raise unprocessable("Bir rasm ikki marta berilgan")
    rows = (await session.execute(select(Media).where(Media.id.in_(media_ids)))).scalars().all()
    by_id = {m.id: m for m in rows}
    for media_id in media_ids:
        media = by_id.get(media_id)
        if media is None:
            raise unprocessable(msg("Rasm topilmadi: {media_id}", media_id=media_id))
        if media.purpose != "catalog" or media.status != "ready":
            raise unprocessable(msg(
                "Rasm katalog uchun yuklanmagan yoki yuklash tugamagan: {media_id}", media_id=media_id
            ))


def editable_shape(shape: Shape) -> None:
    if shape.locked_at is not None:
        raise conflict("Shakl dizaynlarda ishlatilgan va qulflangan. Nusxa olib tahrirlang.")
    if shape.status != "draft":
        raise conflict("Tayyor shaklni tahrirlash uchun avval uni qoralamaga qaytaring")


def set_archived(obj, archived: bool | None) -> None:
    if archived is not None:
        obj.archived_at = datetime.now(UTC) if archived else None


def set_translations(obj, translations: dict | None) -> None:
    """Merges the languages sent into the row's translations; None keeps them."""
    if translations is not None:
        obj.translations = merge_translations(obj.translations, translations)


# ── Products ──────────────────────────────────────────────────────────────


async def check_category(session: AsyncSession, slug: str | None) -> None:
    if slug is None:
        return
    found = (await session.execute(select(ProductCategory.id).where(ProductCategory.slug == slug))).scalar_one_or_none()
    if found is None:
        raise unprocessable(msg("“{slug}” kategoriyasi yo'q", slug=slug))


# ── Categories (storefront shelves) ───────────────────────────────────────


async def category_out(session: AsyncSession, category: ProductCategory, storage: R2Storage) -> CategoryOut:
    count = (
        await session.execute(select(func.count(Product.id)).where(Product.category == category.slug))
    ).scalar_one()
    return CategoryOut(
        id=category.id, slug=category.slug, name=category.name, icon_svg=category.icon_svg,
        image_media_id=category.image_media_id,
        image_url=storage.public_url(category.image.key) if category.image else None,
        sort_order=category.sort_order, is_active=category.is_active, product_count=count,
        translations=category.translations or {},
    )


@router.get("/categories/", response_model=list[CategoryOut])
async def list_categories(
    session: AsyncSession = Depends(get_db), _: User = Depends(admin_user), storage: R2Storage = Depends(get_storage)
):
    rows = (
        await session.execute(select(ProductCategory).order_by(ProductCategory.sort_order, ProductCategory.name))
    ).scalars().all()
    return [await category_out(session, c, storage) for c in rows]


@router.post("/categories/", response_model=CategoryOut, status_code=status.HTTP_201_CREATED)
async def create_category(
    payload: CategoryIn, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    if payload.image_media_id:
        await catalog_media(session, [payload.image_media_id])
    category = ProductCategory(**payload.model_dump(exclude={"translations"}), translations=payload.translations or {})
    session.add(category)
    await commit(session, msg("“{slug}” slug band", slug=payload.slug))
    await session.refresh(category, ["image"])
    return await category_out(session, category, storage)


@router.patch("/categories/{category_id}/", response_model=CategoryOut)
async def update_category(
    category_id: int, payload: CategoryPatch, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    category = await fetch(session, ProductCategory, category_id, "Kategoriya")
    data = payload.model_dump(exclude_unset=True, exclude={"translations"})
    set_translations(category, payload.translations)
    if data.get("image_media_id"):
        await catalog_media(session, [data["image_media_id"]])
    old_slug = category.slug
    for field, value in data.items():
        setattr(category, field, value)
    if category.slug != old_slug:
        # Products follow their shelf to its new slug.
        for product in (await session.execute(select(Product).where(Product.category == old_slug))).scalars():
            product.category = category.slug
    await commit(session, "Bu slug band")
    await session.refresh(category, ["image"])
    return await category_out(session, category, storage)


@router.delete("/categories/{category_id}/", status_code=status.HTTP_204_NO_CONTENT)
async def delete_category(category_id: int, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user)):
    category = await fetch(session, ProductCategory, category_id, "Kategoriya")
    used = (await session.execute(select(func.count(Product.id)).where(Product.category == category.slug))).scalar_one()
    if used:
        raise conflict(msg(
            "Bu kategoriyada {count} ta mahsulot bor: avval ularni boshqa kategoriyaga o'tkazing", count=used
        ))
    await session.delete(category)
    await session.commit()


# ── Products ──────────────────────────────────────────────────────────────


@router.get("/products/", response_model=list[AdminProductListItem])
async def list_products(
    session: AsyncSession = Depends(get_db), _: User = Depends(admin_user), storage: R2Storage = Depends(get_storage)
):
    products = (await session.execute(select(Product).order_by(Product.sort_order, Product.name))).scalars().all()
    return [admin_list_item(p, storage) for p in products]


@router.post("/products/", response_model=AdminProductOut, status_code=status.HTTP_201_CREATED)
async def create_product(
    payload: ProductIn, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    if payload.cover_media_id:
        await catalog_media(session, [payload.cover_media_id])
    await check_category(session, payload.category)
    product = Product(**{
        **payload.model_dump(exclude={"translations"}), "description": clean_html(payload.description),
        "translations": payload.translations or {},
    })
    session.add(product)
    await commit(session, msg("“{slug}” slug band", slug=payload.slug))
    return await fresh_product(session, product.id, storage)


@router.get("/products/{product_id}/", response_model=AdminProductOut)
async def get_product(
    product_id: int, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    await fetch(session, Product, product_id, "Mahsulot")
    return await fresh_product(session, product_id, storage)


@router.patch("/products/{product_id}/", response_model=AdminProductOut)
async def update_product(
    product_id: int, payload: ProductPatch, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    product = await fetch(session, Product, product_id, "Mahsulot")
    data = payload.model_dump(exclude_unset=True, exclude={"translations"})
    set_translations(product, payload.translations)
    if data.get("cover_media_id"):
        await catalog_media(session, [data["cover_media_id"]])
    await check_category(session, data.get("category"))
    if "description" in data:
        data["description"] = clean_html(data["description"] or "")
    set_archived(product, data.pop("archived", None))
    for field, value in data.items():
        setattr(product, field, value)
    await commit(session, "Bu slug band")
    return await fresh_product(session, product_id, storage)


async def replace_images(
    session: AsyncSession, owner_field: str, owner_id: int, media_ids: list[str], source: str = "manual"
) -> None:
    """Replaces an owner's whole gallery with this ordered list. Every row
    written is stamped with `source`, so a future bulk regenerate can pick
    out its own 'render' rows and leave the photographs alone."""
    await catalog_media(session, media_ids)
    column = getattr(CatalogImage, owner_field)
    for old in (await session.execute(select(CatalogImage).where(column == owner_id))).scalars():
        await session.delete(old)
    await session.flush()
    for order, media_id in enumerate(media_ids):
        session.add(
            CatalogImage(**{owner_field: owner_id}, media_id=media_id, sort_order=order, source=source)
        )
    await session.commit()


@router.put("/products/{product_id}/images/", response_model=AdminProductOut)
async def set_product_images(
    product_id: int, payload: ImagesIn, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    await fetch(session, Product, product_id, "Mahsulot")
    await replace_images(session, "product_id", product_id, payload.media_ids, payload.source)
    return await fresh_product(session, product_id, storage)


# ── Price tiers ───────────────────────────────────────────────────────────


@router.put("/products/{product_id}/price-tiers/{method}/", response_model=AdminProductOut)
async def set_price_tiers(
    product_id: int, method: str, payload: TiersIn, session: AsyncSession = Depends(get_db),
    _: User = Depends(admin_user), storage: R2Storage = Depends(get_storage),
):
    if method not in METHODS:
        raise not_found("Usul")
    await fetch(session, Product, product_id, "Mahsulot")
    ordered = validate_tiers(payload.tiers)
    for old in (
        await session.execute(select(PriceTier).where(PriceTier.product_id == product_id, PriceTier.method == method))
    ).scalars():
        await session.delete(old)
    await session.flush()
    for tier in ordered:
        session.add(PriceTier(product_id=product_id, method=method, **tier.model_dump()))
    await session.commit()
    return await fresh_product(session, product_id, storage)


@router.delete("/products/{product_id}/price-tiers/{method}/", response_model=AdminProductOut)
async def delete_price_tiers(
    product_id: int, method: str, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    await fetch(session, Product, product_id, "Mahsulot")
    for old in (
        await session.execute(select(PriceTier).where(PriceTier.product_id == product_id, PriceTier.method == method))
    ).scalars():
        await session.delete(old)
    await session.commit()
    return await fresh_product(session, product_id, storage)


# ── Shapes and print areas ────────────────────────────────────────────────


@router.post("/products/{product_id}/shapes/", response_model=AdminProductOut, status_code=status.HTTP_201_CREATED)
async def create_shape(
    product_id: int, payload: ShapeIn, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    await fetch(session, Product, product_id, "Mahsulot")
    session.add(Shape(
        product_id=product_id, name=payload.name, description=payload.description.strip(), kind=payload.kind, dims=payload.dims, status="draft",
        model_transform=default_model_transform() if payload.kind == "model" else None,
        translations=payload.translations or {},
    ))
    await session.commit()
    return await fresh_product(session, product_id, storage)


async def model_media(session: AsyncSession, media_id: str) -> Media:
    media = await session.get(Media, media_id)
    if media is None:
        raise unprocessable(msg("Model fayli topilmadi: {media_id}", media_id=media_id))
    if media.purpose != "model" or media.status != "ready":
        raise unprocessable("Fayl 3D model sifatida yuklanmagan yoki yuklash tugamagan")
    return media


async def apply_model_settings(session: AsyncSession, shape: Shape, payload: ShapePatch) -> None:
    fields = payload.model_fields_set & {"model_media_id", "model_transform", "scale"}
    if not fields:
        return
    if shape.kind != "model":
        raise unprocessable("GLB sozlamalari faqat “3D model” turidagi shakllar uchun")
    editable_shape(shape)
    if "model_media_id" in fields and payload.model_media_id != shape.model_media_id:
        if payload.model_media_id is None:
            raise unprocessable("Modelni olib tashlab bo'lmaydi, faqat boshqasiga almashtirish mumkin")
        await model_media(session, payload.model_media_id)
        # Placements and the scale were measured on the old model.
        shape.model_media_id = payload.model_media_id
        shape.model_transform = default_model_transform()
        shape.mm_per_unit = None
        for area in shape.areas:
            area.anchor = {}
            area.camera = None
    if shape.model_media_id is None and fields - {"model_media_id"}:
        raise unprocessable("Avval GLB modelni yuklang")
    transform = dict(shape.model_transform or default_model_transform())
    if payload.model_transform is not None:
        transform.update(payload.model_transform.model_dump())
    if payload.scale is not None:
        shape.mm_per_unit = mm_per_unit(payload.scale)
        transform["scale_ref"] = payload.scale.model_dump(mode="json")
    shape.model_transform = transform


@router.patch("/shapes/{shape_id}/", response_model=AdminProductOut)
async def update_shape(
    shape_id: int, payload: ShapePatch, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    shape = await fetch(session, Shape, shape_id, "Shakl")
    data = payload.model_dump(exclude_unset=True)
    await apply_model_settings(session, shape, payload)
    if "dims" in data:
        editable_shape(shape)
        shape.dims = validate_dims(shape.kind, data["dims"])
    if data.get("archived"):
        in_use = (
            await session.execute(select(Variant.id).where(Variant.shape_id == shape_id, Variant.archived_at.is_(None)))
        ).first()
        if in_use:
            raise conflict("Shakl arxivlanmagan turlarda ishlatilyapti")
    set_archived(shape, data.get("archived"))
    if "name" in data:
        shape.name = data["name"]
    if data.get("description") is not None:
        shape.description = data["description"].strip()
    set_translations(shape, payload.translations)
    await session.commit()
    return await fresh_product(session, shape.product_id, storage)


@router.post("/shapes/{shape_id}/ready/", response_model=AdminProductOut)
async def mark_shape_ready(
    shape_id: int, payload: ReadyIn | None = None, session: AsyncSession = Depends(get_db),
    _: User = Depends(admin_user), storage: R2Storage = Depends(get_storage),
):
    shape = await fetch(session, Shape, shape_id, "Shakl")
    errors = shape_ready_errors(shape, payload.checks if payload else {})
    if errors:
        raise unprocessable(msg("Shakl tayyor emas: {errors}", errors="; ".join(errors)))
    shape.status = "ready"
    if shape.replaces_id is not None:
        # A finished revision takes the old shape's place: its types move
        # over and the old one (kept for saved designs) is archived.
        old = await fetch(session, Shape, shape.replaces_id, "Shakl")
        for variant in (await session.execute(select(Variant).where(Variant.shape_id == old.id))).scalars():
            variant.shape_id = shape.id
        old.archived_at = datetime.now(UTC)
        shape.replaces_id = None
    await session.commit()
    return await fresh_product(session, shape.product_id, storage)


@router.post("/shapes/{shape_id}/draft/", response_model=AdminProductOut)
async def mark_shape_draft(
    shape_id: int, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    shape = await fetch(session, Shape, shape_id, "Shakl")
    if shape.locked_at is not None:
        raise conflict("Shakl dizaynlarda ishlatilgan va qulflangan. Nusxa olib tahrirlang.")
    shape.status = "draft"
    await session.commit()
    return await fresh_product(session, shape.product_id, storage)


def copy_of(shape: Shape, name: str, replaces_id: int | None = None) -> Shape:
    """A draft copy of the shape with all its areas and methods."""
    copy = Shape(
        product_id=shape.product_id, name=name, description=shape.description, kind=shape.kind,
        dims=deepcopy(shape.dims),
        model_media_id=shape.model_media_id, model_transform=deepcopy(shape.model_transform),
        mm_per_unit=shape.mm_per_unit, status="draft", replaces_id=replaces_id,
        translations=deepcopy(shape.translations or {}),
    )
    for area in shape.areas:
        new_area = PrintArea(
            key=area.key, name=area.name, width_mm=area.width_mm, height_mm=area.height_mm,
            anchor=deepcopy(area.anchor), camera=deepcopy(area.camera), placement_note=area.placement_note,
            sort_order=area.sort_order, pair_key=area.pair_key, pair_mirror=area.pair_mirror,
            translations=deepcopy(area.translations or {}),
        )
        new_area.methods = [
            AreaMethod(**{c: getattr(m, c) for c in (
                "method", "zone_x_mm", "zone_y_mm", "zone_w_mm", "zone_h_mm", "max_width_mm", "max_height_mm",
                "strip_width_mm", "min_font_mm", "colors_allowed", "dpi",
            )})
            for m in area.methods
        ]
        copy.areas.append(new_area)
    return copy


@router.post("/shapes/{shape_id}/duplicate/", response_model=AdminProductOut, status_code=status.HTTP_201_CREATED)
async def duplicate_shape(
    shape_id: int, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    shape = await fetch(session, Shape, shape_id, "Shakl")
    session.add(copy_of(shape, f"{shape.name} (nusxa)"))
    await session.commit()
    return await fresh_product(session, shape.product_id, storage)


@router.post("/shapes/{shape_id}/revise/", response_model=AdminProductOut)
async def revise_shape(
    shape_id: int, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    """The draft the admin edits for this shape: the shape itself while it
    is an unused draft, otherwise its revision (made on first edit), which
    replaces it once marked ready. Customers keep seeing the shape meanwhile."""
    shape = await fetch(session, Shape, shape_id, "Shakl")
    if shape.archived_at is not None:
        raise conflict("Shakl o'chirilgan")
    if shape.replaces_id is not None or (shape.status == "draft" and shape.locked_at is None):
        return await fresh_product(session, shape.product_id, storage)
    pending = (
        await session.execute(select(Shape.id).where(Shape.replaces_id == shape.id, Shape.archived_at.is_(None)))
    ).first()
    if pending is None:
        session.add(copy_of(shape, shape.name, replaces_id=shape.id))
        await session.commit()
    return await fresh_product(session, shape.product_id, storage)


@router.delete("/shapes/{shape_id}/", response_model=AdminProductOut)
async def delete_shape(
    shape_id: int, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    """Removes a shape nobody uses: a discarded revision, or one no type or
    design ever used. Anything else is archived instead (PATCH archived)."""
    shape = await fetch(session, Shape, shape_id, "Shakl")
    if shape.locked_at is not None:
        raise conflict("Shakl mijoz dizaynlarida ishlatilgan, uni o'chirib bo'lmaydi")
    if (await session.execute(select(Variant.id).where(Variant.shape_id == shape.id))).first():
        raise conflict("Bu shakldan variantlar foydalanyapti: avval ularni boshqa shaklga o'tkazing")
    product_id = shape.product_id
    await session.delete(shape)
    await session.commit()
    return await fresh_product(session, product_id, storage)


async def sync_partner(
    session: AsyncSession, shape: Shape, area: PrintArea, methods: list[AreaMethodIn] | None = None
) -> None:
    """Pair partners always match: the partner takes the area's size and
    methods (``methods`` when they are being replaced in this request),
    with zones mirrored when the pair is mirrored."""
    partner = partner_of(shape, area)
    if partner is None:
        return
    fit = area_fit_error(shape, area.width_mm, area.height_mm, partner.anchor)
    if fit:
        raise unprocessable(msg("Juft hudud “{name}”: {problem}", name=partner.name, problem=fit))
    partner.width_mm = area.width_mm
    partner.height_mm = area.height_mm
    partner.pair_mirror = area.pair_mirror
    fields = [partner_method_fields(area, m) for m in (methods if methods is not None else area.methods)]
    # Old rows go first: (area_id, method) is unique.
    partner.methods.clear()
    await session.flush()
    partner.methods.extend(AreaMethod(**f) for f in fields)


def check_area(shape: Shape, payload: AreaIn) -> dict:
    anchor = validate_anchor(shape.kind, payload.anchor)
    fit = area_fit_error(shape, payload.width_mm, payload.height_mm, anchor)
    if fit:
        raise unprocessable(fit)
    return anchor


@router.post("/shapes/{shape_id}/areas/", response_model=AdminProductOut, status_code=status.HTTP_201_CREATED)
async def create_area(
    shape_id: int, payload: AreaIn, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    shape = await fetch(session, Shape, shape_id, "Shakl")
    editable_shape(shape)
    anchor = check_area(shape, payload)
    session.add(PrintArea(
        shape_id=shape_id, **payload.model_dump(exclude={"anchor", "translations"}), anchor=anchor,
        translations=payload.translations or {},
    ))
    await commit(session, msg("Bu shaklda “{key}” kalitli hudud allaqachon bor", key=payload.key))
    return await fresh_product(session, shape.product_id, storage)


@router.put("/areas/{area_id}/", response_model=AdminProductOut)
async def replace_area(
    area_id: int, payload: AreaIn, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    area = await fetch(session, PrintArea, area_id, "Hudud")
    shape = await fetch(session, Shape, area.shape_id, "Shakl")
    editable_shape(shape)
    anchor = check_area(shape, payload)
    for method in area.methods:
        if method.zone_x_mm + method.zone_w_mm > payload.width_mm or method.zone_y_mm + method.zone_h_mm > payload.height_mm:
            raise unprocessable(msg(
                "{method} zonasi yangi o'lchamga sig'maydi, avval zonani o'zgartiring", method=method.method
            ))
    partner = partner_of(shape, area)
    for field, value in payload.model_dump(exclude={"anchor", "translations"}).items():
        setattr(area, field, value)
    area.anchor = anchor
    set_translations(area, payload.translations)
    if partner is not None:
        partner.pair_key = area.key  # follows a renamed key
        await sync_partner(session, shape, area)
    await commit(session, msg("Bu shaklda “{key}” kalitli hudud allaqachon bor", key=payload.key))
    return await fresh_product(session, shape.product_id, storage)


@router.delete("/areas/{area_id}/", response_model=AdminProductOut)
async def delete_area(
    area_id: int, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    area = await fetch(session, PrintArea, area_id, "Hudud")
    shape = await fetch(session, Shape, area.shape_id, "Shakl")
    editable_shape(shape)
    partner = partner_of(shape, area)
    if partner is not None:
        partner.pair_key = None
    await session.delete(area)
    await session.commit()
    return await fresh_product(session, shape.product_id, storage)


@router.put("/areas/{area_id}/methods/", response_model=AdminProductOut)
async def set_area_methods(
    area_id: int, payload: AreaMethodsIn, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    area = await fetch(session, PrintArea, area_id, "Hudud")
    shape = await fetch(session, Shape, area.shape_id, "Shakl")
    editable_shape(shape)
    for method in payload.methods:
        fit = zone_fit_error(area, method)
        if fit:
            raise unprocessable(fit)
    for old in list(area.methods):
        await session.delete(old)
    await session.flush()
    for method in payload.methods:
        session.add(AreaMethod(area_id=area_id, **method.model_dump()))
    await sync_partner(session, shape, area, payload.methods)
    await session.commit()
    return await fresh_product(session, shape.product_id, storage)


@router.put("/areas/{area_id}/pair/", response_model=AdminProductOut)
async def set_area_pair(
    area_id: int, payload: PairIn, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    """Pairs two areas of a shape (left ↔ right sleeve) or unpairs them.
    The partner takes this area's size and methods."""
    area = await fetch(session, PrintArea, area_id, "Hudud")
    shape = await fetch(session, Shape, area.shape_id, "Shakl")
    editable_shape(shape)
    partner = next((a for a in shape.areas if a.key == payload.pair_key), None) if payload.pair_key else None
    if payload.pair_key and partner is None:
        raise unprocessable(msg("Bu shaklda “{key}” kalitli hudud yo'q", key=payload.pair_key))
    if partner is area:
        raise unprocessable("Hudud o'zi bilan juft bo'lmaydi")
    # Whoever either side was paired with before is released.
    for side in (area, partner):
        old = partner_of(shape, side) if side is not None else None
        if old is not None and old not in (area, partner):
            old.pair_key = None
    if partner is None:
        area.pair_key = None
    else:
        area.pair_key, partner.pair_key = partner.key, area.key
        area.pair_mirror = partner.pair_mirror = payload.mirror
        await sync_partner(session, shape, area)
    await session.commit()
    return await fresh_product(session, shape.product_id, storage)


def layout_errors(shape: Shape, payload: ShapeLayoutIn) -> list[str]:
    """What is wrong with the areas as sent, before anything is changed."""
    errors: list[str] = []
    known = {a.id for a in shape.areas}
    ids = [a.id for a in payload.areas if a.id is not None]
    if len(set(ids)) != len(ids):
        errors.append(msg("Bir hudud ikki marta berilgan"))
    stray = sorted(set(ids) - known)
    if stray:
        errors.append(msg("Bu shaklda bunday hudud yo'q: {ids}", ids=stray))
    keys = [a.key for a in payload.areas]
    for key in sorted({k for k in keys if keys.count(k) > 1}):
        errors.append(msg("“{key}” kaliti ikki hududda takrorlangan", key=key))
    by_key = {a.key: a for a in payload.areas}
    for area in payload.areas:
        if area.pair_key is None:
            continue
        partner = by_key.get(area.pair_key)
        if partner is None or partner is area or partner.pair_key != area.key:
            errors.append(msg("“{name}” juft hududi topilmadi yoki unga bog'lanmagan", name=area.name))
        elif partner.pair_mirror != area.pair_mirror:
            errors.append(msg("“{name}” va “{partner}” juftligi bir xil emas", name=area.name, partner=partner.name))
    return errors


@router.put("/shapes/{shape_id}/layout/", response_model=AdminProductOut)
async def save_shape_layout(
    shape_id: int, payload: ShapeLayoutIn, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    """Saves the shape editor's whole state at once: all of it or nothing.
    Areas are matched by id (new ones have none), and the ones left out
    are deleted. Pair partners must already match (the editor keeps them
    in step); a new GLB keeps the areas exactly as sent."""
    shape = await fetch(session, Shape, shape_id, "Shakl")
    editable_shape(shape)
    errors = layout_errors(shape, payload)
    if errors:
        raise unprocessable("; ".join(errors))

    if payload.name is not None:
        shape.name = payload.name
    if payload.description is not None:
        shape.description = payload.description.strip()
    set_translations(shape, payload.translations)
    if payload.dims is not None:
        shape.dims = validate_dims(shape.kind, payload.dims)
    if payload.model_media_id is not None or payload.model_transform is not None or payload.scale is not None:
        if shape.kind != "model":
            raise unprocessable("GLB sozlamalari faqat “3D model” turidagi shakllar uchun")
        transform = dict(shape.model_transform or default_model_transform())
        if payload.model_media_id is not None and payload.model_media_id != shape.model_media_id:
            await model_media(session, payload.model_media_id)
            shape.model_media_id = payload.model_media_id
            # The old scale was measured on the old model; the turn is kept.
            shape.mm_per_unit = None
            transform["scale_ref"] = None
        if shape.model_media_id is None:
            raise unprocessable("Avval GLB modelni yuklang")
        if payload.model_transform is not None:
            transform.update(payload.model_transform.model_dump())
        if payload.scale is not None:
            shape.mm_per_unit = mm_per_unit(payload.scale)
            transform["scale_ref"] = payload.scale.model_dump(mode="json")
        shape.model_transform = transform

    # Every area is checked against the new body before anything changes.
    anchors: list[dict] = []
    for item in payload.areas:
        try:
            anchors.append(check_area(shape, item))
        except HTTPException as exc:
            raise unprocessable(f"“{item.name}”: {exc.detail}") from exc
        for method in item.methods:
            if method.zone_x_mm + method.zone_w_mm > item.width_mm or method.zone_y_mm + method.zone_h_mm > item.height_mm:
                problem = msg(
                    "{method} zonasi hududdan chiqib ketadi ({width} × {height} mm)",
                    method=method.method, width=item.width_mm, height=item.height_mm,
                )
                raise unprocessable(f"“{item.name}”: {problem}")

    existing = {a.id: a for a in shape.areas}
    kept = {item.id for item in payload.areas if item.id is not None}
    for area in list(shape.areas):
        if area.id not in kept:
            shape.areas.remove(area)
    # Kept areas may swap keys: free every key first, (shape_id, key) is unique.
    for area in shape.areas:
        area.key = f"_{area.id}"
    await session.flush()

    fields = ("key", "name", "width_mm", "height_mm", "placement_note", "sort_order", "pair_key", "pair_mirror")
    for item, anchor in zip(payload.areas, anchors, strict=True):
        # A new area's collections start loaded: nothing is lazy-loaded later.
        area = existing[item.id] if item.id is not None else PrintArea(methods=[])
        for field in fields:
            setattr(area, field, getattr(item, field))
        area.anchor = anchor
        area.camera = item.camera.model_dump(mode="json") if item.camera else None
        set_translations(area, item.translations)
        if item.id is None:
            shape.areas.append(area)
        else:
            area.methods.clear()
    await session.flush()
    for item in payload.areas:
        area = next(a for a in shape.areas if a.key == item.key)
        area.methods.extend(AreaMethod(**m.model_dump()) for m in item.methods)
    await session.flush()

    errors = pair_errors(shape)
    if errors:
        await session.rollback()
        raise unprocessable("; ".join(errors))
    await commit(session, "Hududlar kalitlari takrorlanmasin")
    return await fresh_product(session, shape.product_id, storage)


# ── Variants and colours ──────────────────────────────────────────────────


async def own_shape(session: AsyncSession, product_id: int, shape_id: int) -> Shape:
    shape = await fetch(session, Shape, shape_id, "Shakl")
    if shape.product_id != product_id:
        raise unprocessable("Shakl boshqa mahsulotga tegishli")
    if shape.archived_at is not None:
        raise unprocessable("Shakl arxivlangan")
    return shape


@router.post("/products/{product_id}/variants/", response_model=AdminProductOut, status_code=status.HTTP_201_CREATED)
async def create_variant(
    product_id: int, payload: VariantIn, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    await fetch(session, Product, product_id, "Mahsulot")
    await own_shape(session, product_id, payload.shape_id)
    session.add(Variant(
        product_id=product_id, **payload.model_dump(mode="json", exclude={"base_price", "translations"}),
        base_price=payload.base_price, translations=payload.translations or {},
    ))
    await commit(session, "Variantni saqlab bo'lmadi")
    return await fresh_product(session, product_id, storage)


@router.patch("/variants/{variant_id}/", response_model=AdminProductOut)
async def update_variant(
    variant_id: int, payload: VariantPatch, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    variant = await fetch(session, Variant, variant_id, "Variant")
    data = payload.model_dump(exclude_unset=True, exclude={"translations"})
    set_translations(variant, payload.translations)
    if "shape_id" in data:
        await own_shape(session, variant.product_id, data["shape_id"])
    if "specs" in data:
        data["specs"] = [s.model_dump() for s in payload.specs]
    set_archived(variant, data.pop("archived", None))
    for field, value in data.items():
        setattr(variant, field, value)
    await commit(session, "Variantni saqlab bo'lmadi")
    return await fresh_product(session, variant.product_id, storage)


@router.put("/variants/{variant_id}/sizes/", response_model=AdminProductOut)
async def set_variant_sizes(
    variant_id: int, payload: SizesIn, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    """Replaces the variant's sizes with this ordered list — adding,
    removing, reordering and marking out of stock are all the same save. An
    empty list means the product has no sizes."""
    variant = await fetch(session, Variant, variant_id, "Variant")
    variant.sizes = [size.model_dump(mode="json") for size in payload.sizes]
    await session.commit()
    return await fresh_product(session, variant.product_id, storage)


@router.put("/variants/{variant_id}/images/", response_model=AdminProductOut)
async def set_variant_images(
    variant_id: int, payload: ImagesIn, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    """Kept for old clients: pictures now belong to a variant's colours (the
    admin no longer sets these; the public views still read them)."""
    variant = await fetch(session, Variant, variant_id, "Variant")
    await replace_images(session, "variant_id", variant_id, payload.media_ids, payload.source)
    return await fresh_product(session, variant.product_id, storage)


@router.post("/variants/{variant_id}/colors/", response_model=AdminProductOut, status_code=status.HTTP_201_CREATED)
async def create_color(
    variant_id: int, payload: ColorIn, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    variant = await fetch(session, Variant, variant_id, "Variant")
    session.add(VariantColor(
        variant_id=variant_id, **payload.model_dump(exclude={"translations"}), translations=payload.translations or {},
    ))
    await commit(session, "Rangni saqlab bo'lmadi")
    return await fresh_product(session, variant.product_id, storage)


@router.patch("/colors/{color_id}/", response_model=AdminProductOut)
async def update_color(
    color_id: int, payload: ColorPatch, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    color = await fetch(session, VariantColor, color_id, "Rang")
    variant = await fetch(session, Variant, color.variant_id, "Variant")
    data = payload.model_dump(exclude_unset=True, exclude={"translations"})
    set_translations(color, payload.translations)
    set_archived(color, data.pop("archived", None))
    for field, value in data.items():
        setattr(color, field, value)
    await commit(session, "Rangni saqlab bo'lmadi")
    return await fresh_product(session, variant.product_id, storage)


@router.put("/colors/{color_id}/images/", response_model=AdminProductOut)
async def set_color_images(
    color_id: int, payload: ImagesIn, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    """Replaces the colour's gallery — the customer's slideshow, at most
    MAX_COLOR_IMAGES pictures. The card the colour-picking UI shows is not
    one of these: it is the colour's own `card_media_id`."""
    color = await fetch(session, VariantColor, color_id, "Rang")
    variant = await fetch(session, Variant, color.variant_id, "Variant")
    if len(payload.media_ids) > MAX_COLOR_IMAGES:
        raise unprocessable(msg(
            "Bitta rang uchun ko'pi bilan {count} ta rasm qo'shish mumkin", count=MAX_COLOR_IMAGES
        ))
    await replace_images(session, "color_id", color_id, payload.media_ids, payload.source)
    return await fresh_product(session, variant.product_id, storage)
