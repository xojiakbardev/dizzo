"""Studio designs: the signed-in customer's autosaved work.

Every save returns the backend's price for the painted area the editor
measured, so the price shown while editing always comes from here. Guests
keep their design in the browser and create it here after signing in.
"""

from __future__ import annotations

import time
from collections import Counter
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.i18n import _, tr
from app.db.session import get_db
from app.models.commerce import Design
from app.models.user import User
from app.schemas.design import DesignDocument, DesignIn, DesignOut, DesignPut, DesignSummary
from app.services.catalog import lock_shape, quote, resolve_size, size_scale
from app.services.design_rules import document_problems, settle_strips, strip_problems
from app.services.packages import normalise_images, owned_media, sellable, variant_and_color
from app.services.storage import R2Storage, get_storage

router = APIRouter(prefix="/studio", tags=["studio"])

# How often each library graphic (shape, icon, sticker) sits in saved
# designs: the Studio lists the most used first. Counted over every design,
# kept for a few minutes.
POPULAR_TTL_SECONDS = 600
_popular: tuple[float, list[dict]] | None = None


@router.get("/graphics/popular/")
async def popular_graphics(session: AsyncSession = Depends(get_db)) -> list[dict]:
    global _popular
    if _popular and time.monotonic() - _popular[0] < POPULAR_TTL_SECONDS:
        return _popular[1]
    counts: Counter[tuple[str, str]] = Counter()
    for (document,) in (await session.execute(select(Design.document))).all():
        for layer in (document or {}).get("layers", []):
            graphic = layer.get("graphic") if isinstance(layer, dict) else None
            if isinstance(graphic, dict) and graphic.get("library") and graphic.get("name"):
                counts[(graphic["library"], graphic["name"])] += 1
    result = [{"library": lib, "name": name, "count": n} for (lib, name), n in counts.most_common(300)]
    _popular = (time.monotonic(), result)
    return result


def not_found(what: str) -> HTTPException:
    # "Dizayn topilmadi" is catalogued whole, so each language words it its own way.
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"{what} topilmadi")


def design_previews(design: Design, storage: R2Storage) -> list[str]:
    """The Studio's views, or the one preview an older design has."""
    if design.previews:
        return [storage.public_url(key) for key in design.previews]
    return [storage.public_url(design.preview.key)] if design.preview else []


def design_out(design: Design, storage: R2Storage, size: str | None = None) -> DesignOut:
    document = settle_strips(DesignDocument.model_validate(design.document), design.variant)
    areas = {k: Decimal(str(v)) for k, v in design.areas_cm2.items()}
    # The size being designed for (never stored on the design) decides how
    # much of each print area may be used, so the draft is judged and priced
    # against the box the editor is drawing.
    try:
        chosen = resolve_size(design.variant, size)
    except HTTPException:
        chosen = None
    label = chosen["label"] if chosen else ""
    issues = document_problems(document, design.variant, size_scale(chosen), label)
    price = None
    if sellable(design.variant, design.color, label):
        price = quote(design.variant, design.color, 1, areas, label or None)
    else:
        issues.insert(0, _("Tanlangan variant yoki rang hozir sotuvda emas"))
    return DesignOut(
        id=design.id, version=design.version, product_slug=design.product.slug, product_name=tr(design.product, "name"),
        variant_id=design.variant_id, color_id=design.color_id, document=document, areas_cm2=areas,
        preview_url=next(iter(design_previews(design, storage)), None), updated_at=design.updated_at,
        quote=price, issues=issues,
    )


async def owned_design(session: AsyncSession, design_id: str, user: User) -> Design:
    design = await session.get(Design, design_id)
    if design is None or design.owner_id != user.id:
        raise not_found("Dizayn")
    return design


async def apply(session: AsyncSession, design: Design, payload: DesignIn, user: User, storage: R2Storage) -> None:
    variant, color = await variant_and_color(session, payload.variant_id, payload.color_id)
    if design.product_id is not None and variant.product_id != design.product_id:
        raise HTTPException(status_code=422, detail="Dizayn boshqa mahsulotga tegishli; yangi dizayn boshlang")
    if payload.preview_media_id:
        await owned_media(session, user, [payload.preview_media_id], "design", "Ko'rinish rasmi")
    views = await owned_media(session, user, payload.previews, "design", "Ko'rinish rasmi") if payload.previews else {}
    document = await normalise_images(session, user, payload.document, storage)
    if problems := strip_problems(document, variant):
        raise HTTPException(status_code=422, detail=problems[0])
    design.product_id = variant.product_id
    design.variant_id = variant.id
    design.color_id = color.id
    design.document = document.model_dump(mode="json")
    design.areas_cm2 = {k: str(v) for k, v in payload.areas_cm2.items()}
    if payload.preview_media_id:
        design.preview_media_id = payload.preview_media_id
    if payload.previews is not None:
        design.previews = [views[media_id].key for media_id in payload.previews]
    lock_shape(variant.shape)


async def reloaded(session: AsyncSession, design_id: str) -> Design:
    session.expunge_all()
    return (await session.execute(select(Design).where(Design.id == design_id))).scalar_one()


@router.post("/designs/", response_model=DesignOut, status_code=status.HTTP_201_CREATED)
async def create_design(
    payload: DesignIn, session: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
    storage: R2Storage = Depends(get_storage),
):
    design = Design(owner_id=user.id, version=1)
    await apply(session, design, payload, user, storage)
    session.add(design)
    await session.commit()
    return design_out(await reloaded(session, design.id), storage, payload.size)


@router.get("/designs/", response_model=list[DesignSummary])
async def list_designs(
    session: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
    storage: R2Storage = Depends(get_storage),
):
    designs = (
        await session.execute(select(Design).where(Design.owner_id == user.id).order_by(Design.updated_at.desc()))
    ).scalars()
    summaries = []
    for d in designs:
        previews = design_previews(d, storage)
        summaries.append(DesignSummary(
            id=d.id, product_slug=d.product.slug, product_name=tr(d.product, "name"),
            variant_name=tr(d.variant, "name"), color_name=tr(d.color, "name"), color_hex=d.color.hex, preview_url=next(iter(previews), None), previews=previews,
            updated_at=d.updated_at,
        ))
    return summaries


@router.get("/designs/{design_id}/", response_model=DesignOut)
async def get_design(
    design_id: str, session: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
    storage: R2Storage = Depends(get_storage),
):
    return design_out(await owned_design(session, design_id, user), storage)


@router.put("/designs/{design_id}/", response_model=DesignOut)
async def save_design(
    design_id: str, payload: DesignPut, session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user), storage: R2Storage = Depends(get_storage),
):
    design = await owned_design(session, design_id, user)
    if payload.version != design.version:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=_(
                "Dizayn boshqa oynada o'zgartirilgan (versiya {version}). Oxirgi holati yuklanadi.",
                version=design.version,
            ),
        )
    await apply(session, design, payload, user, storage)
    design.version += 1
    await session.commit()
    return design_out(await reloaded(session, design_id), storage, payload.size)


@router.delete("/designs/{design_id}/", status_code=status.HTTP_204_NO_CONTENT)
async def delete_design(design_id: str, session: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    design = await owned_design(session, design_id, user)
    await session.delete(design)
    await session.commit()
