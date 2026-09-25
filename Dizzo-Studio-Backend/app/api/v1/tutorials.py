"""Tutorial videos ("Video darsliklar"): the public list and the admin API.

`GET /tutorials/` lists the published items in the admin's order. Admins
manage them under `/admin/tutorials/`: create, edit, publish, reorder and
delete. A cover is an uploaded catalog image.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.admin_catalog import admin_user, not_found, set_translations
from app.core.i18n import _ as msg  # `_` is taken: the endpoints' unused admin parameter
from app.core.i18n import tr
from app.db.session import get_db
from app.models.media import Media
from app.models.tutorial import TutorialVideo
from app.models.user import User
from app.schemas.tutorial import TutorialIn, TutorialOrder, TutorialOut, TutorialPatch, TutorialPublic
from app.services.catalog import unprocessable
from app.services.storage import R2Storage, get_storage

router = APIRouter(prefix="/tutorials", tags=["tutorials"])
admin_router = APIRouter(prefix="/admin/tutorials", tags=["admin-tutorials"])

ORDER = (TutorialVideo.sort_order, TutorialVideo.id)


def public_out(item: TutorialVideo, storage: R2Storage) -> TutorialPublic:
    return TutorialPublic(
        id=item.id, title=tr(item, "title"), cover_url=storage.public_url(item.cover.key),
        cover_width=item.cover_width, cover_height=item.cover_height, video_url=item.video_url,
    )


def admin_out(item: TutorialVideo, storage: R2Storage) -> TutorialOut:
    return TutorialOut(
        **{**public_out(item, storage).model_dump(), "title": item.title}, cover_media_id=item.cover_media_id,
        sort_order=item.sort_order, is_published=item.is_published, created_at=item.created_at,
        translations=item.translations or {},
    )


async def all_items(session: AsyncSession) -> list[TutorialVideo]:
    session.expunge_all()
    return list((await session.execute(select(TutorialVideo).order_by(*ORDER))).scalars().all())


async def fresh(session: AsyncSession, item_id: int) -> TutorialVideo:
    session.expunge_all()
    return (await session.execute(select(TutorialVideo).where(TutorialVideo.id == item_id))).scalar_one()


async def item_or_404(session: AsyncSession, item_id: int) -> TutorialVideo:
    item = await session.get(TutorialVideo, item_id)
    if item is None:
        raise not_found("Video darslik")
    return item


async def check_cover(session: AsyncSession, media_id: str) -> None:
    media = await session.get(Media, media_id)
    if media is None or media.status != "ready":
        raise unprocessable(msg("Rasm topilmadi yoki hali yuklanmagan: {media_id}", media_id=media_id))
    if media.purpose != "catalog" or not media.content_type.startswith("image/"):
        raise unprocessable(msg("Rasm katalog uchun yuklangan bo'lishi kerak: {media_id}", media_id=media_id))


@router.get("/", response_model=list[TutorialPublic])
async def list_tutorials(session: AsyncSession = Depends(get_db), storage: R2Storage = Depends(get_storage)):
    query = select(TutorialVideo).where(TutorialVideo.is_published.is_(True)).order_by(*ORDER)
    return [public_out(i, storage) for i in (await session.execute(query)).scalars().all()]


@admin_router.get("/", response_model=list[TutorialOut])
async def admin_list(
    session: AsyncSession = Depends(get_db), _: User = Depends(admin_user), storage: R2Storage = Depends(get_storage),
):
    return [admin_out(i, storage) for i in await all_items(session)]


@admin_router.post("/", response_model=TutorialOut, status_code=status.HTTP_201_CREATED)
async def create_tutorial(
    payload: TutorialIn, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    await check_cover(session, payload.cover_media_id)
    last = (await session.execute(select(func.max(TutorialVideo.sort_order)))).scalar_one_or_none()
    item = TutorialVideo(
        **payload.model_dump(exclude={"translations"}), translations=payload.translations or {},
        sort_order=(last + 1) if last is not None else 0,
    )
    session.add(item)
    await session.commit()
    return admin_out(await fresh(session, item.id), storage)


# Registered before `/{item_id}/` so "order" is never read as an id.
@admin_router.put("/order/", response_model=list[TutorialOut])
async def reorder_tutorials(
    payload: TutorialOrder, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
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
        raise unprocessable(msg("Video darslik topilmadi: {id}", id=missing[0]))
    listed = set(payload.ids)
    ordered = [by_id[i] for i in payload.ids] + [i for i in items if i.id not in listed]
    for index, item in enumerate(ordered):
        item.sort_order = index
    await session.commit()
    return [admin_out(i, storage) for i in await all_items(session)]


@admin_router.patch("/{item_id}/", response_model=TutorialOut)
async def update_tutorial(
    item_id: int, payload: TutorialPatch, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    item = await item_or_404(session, item_id)
    sent = payload.model_fields_set
    if payload.cover_media_id is not None:
        await check_cover(session, payload.cover_media_id)
        item.cover_media_id = payload.cover_media_id
        item.cover_width, item.cover_height = payload.cover_width, payload.cover_height
    elif {"cover_width", "cover_height"} & sent:
        item.cover_width, item.cover_height = payload.cover_width, payload.cover_height
    if payload.title is not None:
        item.title = payload.title
    if "video_url" in sent:
        item.video_url = payload.video_url
    if payload.is_published is not None:
        item.is_published = payload.is_published
    set_translations(item, payload.translations)
    await session.commit()
    return admin_out(await fresh(session, item_id), storage)


@admin_router.delete("/{item_id}/", status_code=status.HTTP_204_NO_CONTENT)
async def delete_tutorial(
    item_id: int, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
) -> Response:
    await session.delete(await item_or_404(session, item_id))
    await session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
