"""Admin API for curated gallery showcase items ("Galereya").

An admin picks a product and 1-5 catalog photos, optionally a title and a
customer name, and publishes the item; published items follow completed
orders in the public `GET /gallery/` feed.
"""

from __future__ import annotations

from fastapi import APIRouter, BackgroundTasks, Depends, Response, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import ALL_STAFF_ROLES, GLOBAL_STAFF_ROLES, get_current_user, require_roles
from app.api.v1.admin_catalog import admin_user, not_found
from app.api.v1.auth import require_bot
from app.core.i18n import _ as msg  # `_` is taken: the endpoints' unused admin parameter
from app.db.session import get_db
from app.models.catalog import Product
from app.models.gallery import MAX_SHOWCASE_IMAGES, GalleryShowcase, GalleryShowcaseImage
from app.models.media import Media
from app.models.user import User
from app.schemas.gallery import (
    ShowcaseImageOut,
    ShowcaseIn,
    ShowcaseModerateIn,
    ShowcaseOrder,
    ShowcaseOut,
    ShowcasePatch,
    ShowcaseSubmitIn,
)
from app.services.catalog import unprocessable
from app.services.storage import R2Storage, get_storage
from app.services.telegram_notify import notify_gallery_submission

router = APIRouter(prefix="/admin/gallery", tags=["admin-gallery"])



def showcase_out(item: GalleryShowcase, storage: R2Storage) -> ShowcaseOut:
    return ShowcaseOut(
        id=item.id,
        product_id=item.product_id,
        product_name=item.product.name,
        product_slug=item.product.slug,
        title=item.title,
        customer_name=item.customer_name,
        sort_order=item.sort_order,
        is_published=item.is_published,
        status=getattr(item, "status", "APPROVED") or "APPROVED",
        created_by_name=item.created_by.full_name if getattr(item, "created_by", None) else None,
        branch_name=item.branch.name if getattr(item, "branch", None) else None,
        rejection_reason=item.rejection_reason,
        created_at=item.created_at,
        images=[ShowcaseImageOut(media_id=i.media_id, url=storage.public_url(i.media.key)) for i in item.images],
    )



async def all_items(session: AsyncSession) -> list[GalleryShowcase]:
    session.expunge_all()
    query = select(GalleryShowcase).order_by(GalleryShowcase.sort_order, GalleryShowcase.id)
    return list((await session.execute(query)).scalars().all())


async def fresh(session: AsyncSession, item_id: int) -> GalleryShowcase:
    session.expunge_all()
    return (await session.execute(select(GalleryShowcase).where(GalleryShowcase.id == item_id))).scalar_one()


async def item_or_404(session: AsyncSession, item_id: int) -> GalleryShowcase:
    item = await session.get(GalleryShowcase, item_id)
    if item is None:
        raise not_found("Galereya elementi")
    return item


async def check_product(session: AsyncSession, product_id: int) -> None:
    if await session.get(Product, product_id) is None:
        raise unprocessable(msg("Mahsulot topilmadi: {id}", id=product_id))


async def images_of(session: AsyncSession, ids: list[str]) -> list[GalleryShowcaseImage]:
    """1-5 distinct, uploaded catalog images, in the order given."""
    if not 1 <= len(ids) <= MAX_SHOWCASE_IMAGES:
        raise unprocessable(msg("1 tadan {count} tagacha rasm tanlang", count=MAX_SHOWCASE_IMAGES))
    if len(set(ids)) != len(ids):
        raise unprocessable("Bir rasm ikki marta qo'shilgan")
    rows = {m.id: m for m in (await session.execute(select(Media).where(Media.id.in_(ids)))).scalars()}
    for media_id in ids:
        media = rows.get(media_id)
        if media is None or media.status != "ready":
            raise unprocessable(msg("Rasm topilmadi yoki hali yuklanmagan: {media_id}", media_id=media_id))
        if media.purpose != "catalog" or not media.content_type.startswith("image/"):
            raise unprocessable(msg("Rasm katalog uchun yuklangan bo'lishi kerak: {media_id}", media_id=media_id))
    return [GalleryShowcaseImage(media_id=media_id, sort_order=i) for i, media_id in enumerate(ids)]


@router.get("/", response_model=list[ShowcaseOut])
async def list_showcase(
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
    storage: R2Storage = Depends(get_storage),
):
    require_roles(user, *ALL_STAFF_ROLES)
    items = await all_items(session)
    if user.role not in GLOBAL_STAFF_ROLES:
        items = [
            i for i in items
            if i.created_by_id == user.id or (user.branch_id is not None and i.branch_id == user.branch_id)
        ]
    return [showcase_out(i, storage) for i in items]


@router.post("/", response_model=ShowcaseOut, status_code=status.HTTP_201_CREATED)
async def create_showcase(
    payload: ShowcaseIn, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    await check_product(session, payload.product_id)
    images = await images_of(session, payload.media_ids)
    last = (await session.execute(select(func.max(GalleryShowcase.sort_order)))).scalar_one_or_none()
    item = GalleryShowcase(
        product_id=payload.product_id, title=payload.title, customer_name=payload.customer_name,
        is_published=payload.is_published, sort_order=(last + 1) if last is not None else 0, images=images,
    )
    session.add(item)
    await session.commit()
    return showcase_out(await fresh(session, item.id), storage)


# Registered before `/{item_id}/` so "order" is never read as an id.
@router.put("/order/", response_model=list[ShowcaseOut])
async def reorder_showcase(
    payload: ShowcaseOrder, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    """Items listed get sort_order 0..n-1 in that order; any not listed
    keep their relative order after them."""
    if len(set(payload.ids)) != len(payload.ids):
        raise unprocessable("Ro'yxatda bir element ikki marta berilgan")
    items = await all_items(session)
    by_id = {i.id: i for i in items}
    missing = [i for i in payload.ids if i not in by_id]
    if missing:
        raise unprocessable(msg("Galereya elementi topilmadi: {id}", id=missing[0]))
    listed = set(payload.ids)
    ordered = [by_id[i] for i in payload.ids] + [i for i in items if i.id not in listed]
    for index, item in enumerate(ordered):
        item.sort_order = index
    await session.commit()
    return [showcase_out(i, storage) for i in await all_items(session)]


@router.patch("/{item_id}/", response_model=ShowcaseOut)
async def update_showcase(
    item_id: int, payload: ShowcasePatch, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    item = await item_or_404(session, item_id)
    sent = payload.model_fields_set
    if payload.product_id is not None:
        await check_product(session, payload.product_id)
        item.product_id = payload.product_id
    if payload.media_ids is not None:
        images = await images_of(session, payload.media_ids)
        item.images.clear()
        await session.flush()  # old rows go before the new ones are inserted
        item.images.extend(images)
    if "title" in sent:
        item.title = payload.title
    if "customer_name" in sent:
        item.customer_name = payload.customer_name
    if payload.is_published is not None:
        item.is_published = payload.is_published
    await session.commit()
    return showcase_out(await fresh(session, item_id), storage)


@router.delete("/{item_id}/", status_code=status.HTTP_204_NO_CONTENT)
async def delete_showcase(
    item_id: int, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
) -> Response:
    await session.delete(await item_or_404(session, item_id))
    await session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/submit/", response_model=ShowcaseOut, status_code=status.HTTP_201_CREATED)
async def submit_showcase_for_moderation(
    payload: ShowcaseSubmitIn,
    background_tasks: BackgroundTasks,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
    storage: R2Storage = Depends(get_storage),
) -> ShowcaseOut:
    """Branch workers/managers submit designs/photos to the gallery for moderation."""
    require_roles(user, *ALL_STAFF_ROLES)
    await check_product(session, payload.product_id)
    images = await images_of(session, payload.media_ids)
    last = (await session.execute(select(func.max(GalleryShowcase.sort_order)))).scalar_one_or_none()

    item = GalleryShowcase(
        product_id=payload.product_id,
        title=payload.title,
        customer_name=payload.customer_name,
        created_by_id=user.id,
        branch_id=user.branch_id,
        status="PENDING_APPROVAL",
        is_published=False,
        sort_order=(last + 1) if last is not None else 0,
        images=images,
    )
    session.add(item)
    await session.commit()
    await session.refresh(item)

    # Trigger background Telegram notification strictly to the configured moderator group
    product = await session.get(Product, payload.product_id)
    product_name = product.name if product else f"Mahsulot #{payload.product_id}"
    branch_name = user.branch.name if getattr(user, "branch", None) else None

    from app.models.setting import SystemSetting
    setting = await session.get(SystemSetting, "telegram_moderator_group_id")
    group_id = setting.value.strip() if setting and setting.value else None

    if group_id:
        background_tasks.add_task(
            notify_gallery_submission,
            item.id,
            product_name,
            user.full_name,
            branch_name,
            payload.title,
            group_id,
        )

    return showcase_out(await fresh(session, item.id), storage)


@router.patch("/{item_id}/moderate/", response_model=ShowcaseOut)
async def moderate_showcase(
    item_id: int,
    payload: ShowcaseModerateIn,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
    storage: R2Storage = Depends(get_storage),
) -> ShowcaseOut:
    """Moderators approve or reject showcase items."""
    require_roles(user, *GLOBAL_STAFF_ROLES)
    item = await item_or_404(session, item_id)
    if payload.status == "APPROVED":
        item.status = "APPROVED"
        item.is_published = True
        item.rejection_reason = None
    elif payload.status == "REJECTED":
        item.status = "REJECTED"
        item.is_published = False
        item.rejection_reason = payload.rejection_reason
    else:
        raise unprocessable("Noto'g'ri status. Faqat APPROVED yoki REJECTED bo'lishi mumkin.")

    await session.commit()
    return showcase_out(await fresh(session, item_id), storage)


class TelegramModeratePayload(BaseModel):
    item_id: int
    action: str  # "approve" or "reject"
    telegram_id: int


@router.post("/telegram-moderate/")
async def telegram_moderate_showcase(
    payload: TelegramModeratePayload,
    _bot: None = Depends(require_bot),
    session: AsyncSession = Depends(get_db),
) -> dict:
    """Internal endpoint called by the Telegram bot callback with strict role verification."""
    # Strict check: Find user by telegram_id and verify moderator/super_admin role
    user = (
        await session.execute(
            select(User).where(
                User.telegram_id == payload.telegram_id,
                User.is_active.is_(True),
            )
        )
    ).scalar_one_or_none()

    if not user or user.role not in GLOBAL_STAFF_ROLES:
        return {
            "ok": False,
            "reason": "unauthorized",
            "message": "Sizda ushbu amalni bajarish huquqi yo'q!",
        }

    item = await session.get(GalleryShowcase, payload.item_id)
    if not item:
        return {"ok": False, "reason": "not_found", "message": "Galereya namunasi topilmadi"}

    if payload.action == "approve":
        item.status = "APPROVED"
        item.is_published = True
        item.rejection_reason = None
    elif payload.action == "reject":
        item.status = "REJECTED"
        item.is_published = False
        item.rejection_reason = f"Rad etdi: {user.full_name}"

    await session.commit()
    return {
        "ok": True,
        "action": payload.action,
        "moderator_name": user.full_name,
    }

