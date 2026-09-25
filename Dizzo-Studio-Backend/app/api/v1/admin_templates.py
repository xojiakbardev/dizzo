"""Admin API for the gallery's designs (templates).

An admin designs a template in the Studio and saves it here with the
variants it is for. The document is checked against every one of those
variants, and its images (the admin's own uploads) are copied into library
media, which any customer's design may reference.
"""

from __future__ import annotations

from pathlib import PurePosixPath
from uuid import uuid4

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.admin_catalog import admin_user, fetch, not_found, set_translations
from app.core.config import get_settings
from app.core.i18n import _ as msg  # `_` is taken: the endpoints' unused admin parameter
from app.db.session import get_db
from app.models.catalog import DesignTemplate, DesignTemplateImage, Product, Variant
from app.models.media import Media
from app.models.user import User
from app.schemas.design import DesignDocument
from app.schemas.template import TemplateImage, TemplateIn, TemplateOrder, TemplateOut, TemplatePatch
from app.services.catalog import unprocessable
from app.services.design_rules import document_problems
from app.services.storage import R2Storage, get_storage

router = APIRouter(prefix="/admin/catalog", tags=["admin-templates"])

# The template-library folder, kept in one place (app/core/config.py) so it
# matches object_key's layout in api/v1/media.py.
LIBRARY_PREFIX = get_settings().library_prefix


def template_out(template: DesignTemplate, storage: R2Storage) -> TemplateOut:
    return TemplateOut(
        id=template.id, product_id=template.product_id, product_name=template.product.name,
        product_slug=template.product.slug, name=template.name, category=template.category,
        preview_url=storage.public_url(template.preview.key), variant_ids=[v.id for v in template.variants],
        document=DesignDocument.model_validate(template.document), is_active=template.is_active,
        sort_order=template.sort_order, updated_at=template.updated_at,
        images=[TemplateImage(media_id=i.media_id, url=storage.public_url(i.media.key)) for i in template.images],
        in_gallery=template.in_gallery, color_id=template.color_id, translations=template.translations or {},
    )


async def set_gallery(
    session: AsyncSession, template: DesignTemplate, variants: list[Variant],
    images: list[str] | None, in_gallery: bool | None, color_id: int | None, color_given: bool,
) -> None:
    """The gallery fields: pictures are catalog (or library) media; the
    colour belongs to one of the template's variants."""
    if images is not None:
        ids = list(dict.fromkeys(images))
        rows = {m.id: m for m in (await session.execute(select(Media).where(Media.id.in_(ids)))).scalars()}
        for media_id in ids:
            media = rows.get(media_id)
            if media is None or media.status != "ready" or media.purpose not in ("catalog", "library"):
                raise unprocessable(msg("Galereya rasmi topilmadi: {media_id}", media_id=media_id))
        template.images = [DesignTemplateImage(media_id=m, sort_order=i) for i, m in enumerate(ids)]
    if color_given:
        if color_id is not None and not any(
            c.id == color_id and c.archived_at is None for v in variants for c in v.colors
        ):
            raise unprocessable("Rang bu dizayn variantlariga tegishli emas")
        template.color_id = color_id
    if in_gallery is not None:
        template.in_gallery = in_gallery


async def fresh(session: AsyncSession, template_id: int) -> DesignTemplate:
    session.expunge_all()
    return (await session.execute(select(DesignTemplate).where(DesignTemplate.id == template_id))).scalar_one()


def product_variants(product: Product, ids: list[int]) -> list[Variant]:
    variants = {v.id: v for v in product.variants if v.archived_at is None}
    missing = [i for i in ids if i not in variants]
    if missing:
        raise unprocessable(msg("Variant topilmadi yoki bu mahsulotga tegishli emas: {id}", id=missing[0]))
    return [variants[i] for i in dict.fromkeys(ids)]


def check_document(document: DesignDocument, variants: list[Variant]) -> None:
    if any(layer.area is None for layer in document.layers):
        raise unprocessable("Shablonda joylashtirilmagan qatlam bo'lmasin: ularni joylang yoki o'chiring")
    for variant in variants:
        problems = document_problems(document, variant)
        if problems:
            raise unprocessable(msg("“{variant}” variantida: {problem}", variant=variant.name, problem=problems[0]))


async def to_library(
    session: AsyncSession, storage: R2Storage, user: User, ids: list[str], what: str
) -> dict[str, Media]:
    """The admin's own design uploads become library copies; library media
    (a template edited again) stay as they are."""
    rows = {m.id: m for m in (await session.execute(select(Media).where(Media.id.in_(ids)))).scalars()}
    out: dict[str, Media] = {}
    for media_id in dict.fromkeys(ids):
        media = rows.get(media_id)
        if media is None or media.status != "ready":
            raise unprocessable(msg("{what} topilmadi: {media_id}", what=msg(what), media_id=media_id))
        if media.purpose == "library":
            out[media_id] = media
            continue
        if media.purpose != "design" or media.owner_id != user.id:
            raise unprocessable(msg("{what} sizga tegishli emas: {media_id}", what=msg(what), media_id=media_id))
        copy_id = str(uuid4())
        copy = Media(
            id=copy_id, key=f"{LIBRARY_PREFIX}{copy_id}{PurePosixPath(media.key).suffix}", purpose="library",
            content_type=media.content_type, size_bytes=media.size_bytes, status="ready", owner_id=None,
        )
        await storage.copy(media.key, copy.key)
        session.add(copy)
        out[media_id] = copy
    await session.flush()
    return out


async def apply(
    session: AsyncSession, storage: R2Storage, user: User, template: DesignTemplate, payload: TemplateIn,
    product: Product,
) -> None:
    variants = product_variants(product, payload.variant_ids)
    document = payload.document
    check_document(document, variants)
    images = [layer.image for layer in document.layers if layer.image is not None]
    media = await to_library(session, storage, user, [i.media_id for i in images], "Rasm")
    for image in images:
        library = media[image.media_id]
        image.media_id, image.url = library.id, storage.public_url(library.key)
    preview = await to_library(session, storage, user, [payload.preview_media_id], "Ko'rinish rasmi")
    template.name = payload.name
    set_translations(template, payload.translations)
    template.category = payload.category
    template.document = document.model_dump(mode="json")
    template.preview_media_id = preview[payload.preview_media_id].id
    template.variants = variants
    await set_gallery(
        session, template, variants, payload.images, payload.in_gallery, payload.color_id,
        "color_id" in payload.model_fields_set,
    )


async def all_templates(session: AsyncSession, storage: R2Storage) -> list[TemplateOut]:
    rows = (
        await session.execute(
            select(DesignTemplate).join(Product, Product.id == DesignTemplate.product_id)
            .where(Product.archived_at.is_(None))
            .order_by(DesignTemplate.sort_order, DesignTemplate.id)
        )
    ).scalars().all()
    return [template_out(t, storage) for t in rows]


@router.get("/templates/", response_model=list[TemplateOut])
async def list_all_templates(
    session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    """Every product's designs, in gallery order (the admin's "Galereya")."""
    return await all_templates(session, storage)


@router.put("/templates/order/", response_model=list[TemplateOut])
async def order_templates(
    payload: TemplateOrder, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    """The gallery's order: the ids given come first, in that order."""
    rows = {t.id: t for t in (await session.execute(select(DesignTemplate))).scalars()}
    ids = list(dict.fromkeys(payload.ids))
    if any(i not in rows for i in ids):
        raise not_found("Shablon")
    given = set(ids)
    rest = sorted((t for t in rows.values() if t.id not in given), key=lambda t: (t.sort_order, t.id))
    for index, template in enumerate([rows[i] for i in ids] + rest):
        template.sort_order = index
    await session.commit()
    session.expunge_all()
    return await all_templates(session, storage)


@router.get("/products/{product_id}/templates/", response_model=list[TemplateOut])
async def list_templates(
    product_id: int, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    await fetch(session, Product, product_id, "Mahsulot")
    rows = (
        await session.execute(
            select(DesignTemplate).where(DesignTemplate.product_id == product_id)
            .order_by(DesignTemplate.sort_order, DesignTemplate.id)
        )
    ).scalars().all()
    return [template_out(t, storage) for t in rows]


@router.post("/products/{product_id}/templates/", response_model=TemplateOut, status_code=status.HTTP_201_CREATED)
async def create_template(
    product_id: int, payload: TemplateIn, session: AsyncSession = Depends(get_db), user: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    product = await fetch(session, Product, product_id, "Mahsulot")
    last = (
        await session.execute(
            select(DesignTemplate.sort_order).where(DesignTemplate.product_id == product_id)
            .order_by(DesignTemplate.sort_order.desc()).limit(1)
        )
    ).scalar_one_or_none()
    # New designs go to the end of the whole gallery.
    last = (
        await session.execute(select(DesignTemplate.sort_order).order_by(DesignTemplate.sort_order.desc()).limit(1))
    ).scalar_one_or_none()
    template = DesignTemplate(product_id=product_id, sort_order=(last + 1) if last is not None else 0, is_active=True)
    await apply(session, storage, user, template, payload, product)
    session.add(template)
    await session.commit()
    return template_out(await fresh(session, template.id), storage)


async def template_or_404(session: AsyncSession, template_id: int) -> DesignTemplate:
    template = await session.get(DesignTemplate, template_id)
    if template is None:
        raise not_found("Shablon")
    return template


@router.get("/templates/{template_id}/", response_model=TemplateOut)
async def get_template(
    template_id: int, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    return template_out(await template_or_404(session, template_id), storage)


@router.put("/templates/{template_id}/", response_model=TemplateOut)
async def replace_template(
    template_id: int, payload: TemplateIn, session: AsyncSession = Depends(get_db), user: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    template = await template_or_404(session, template_id)
    product = await fetch(session, Product, template.product_id, "Mahsulot")
    await apply(session, storage, user, template, payload, product)
    await session.commit()
    return template_out(await fresh(session, template_id), storage)


@router.patch("/templates/{template_id}/", response_model=TemplateOut)
async def update_template(
    template_id: int, payload: TemplatePatch, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    template = await template_or_404(session, template_id)
    variants = list(template.variants)
    if payload.variant_ids is not None:
        product = await fetch(session, Product, template.product_id, "Mahsulot")
        variants = product_variants(product, payload.variant_ids)
        check_document(DesignDocument.model_validate(template.document), variants)
        template.variants = variants
    await set_gallery(
        session, template, variants, payload.images, payload.in_gallery, payload.color_id,
        "color_id" in payload.model_fields_set,
    )
    set_translations(template, payload.translations)
    for field in ("name", "category", "is_active", "sort_order"):
        value = getattr(payload, field)
        if value is not None:
            setattr(template, field, value)
    await session.commit()
    return template_out(await fresh(session, template_id), storage)


@router.delete("/templates/{template_id}/", status_code=status.HTTP_204_NO_CONTENT)
async def delete_template(
    template_id: int, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
) -> Response:
    # Library images stay: customers' designs made from the template use them.
    template = await template_or_404(session, template_id)
    await session.delete(template)
    await session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)

