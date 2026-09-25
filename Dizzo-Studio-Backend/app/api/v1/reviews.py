"""Customer reviews ("Mijozlarimiz"): customers review a completed order
with photos, admins approve (or enter a review sent to them elsewhere),
and the site shows approved ones."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.api.v1.admin_catalog import admin_user
from app.core.i18n import _ as msg  # `_` is taken: the endpoints' unused admin parameter
from app.db.session import get_db
from app.models.catalog import Product
from app.models.commerce import Order
from app.models.media import Media
from app.models.review import Review, ReviewPhoto
from app.models.user import User
from app.schemas.review import AdminReviewIn, PublicReview, ReviewIn, ReviewOut, ReviewPatch, Status
from app.services.storage import R2Storage, get_storage

router = APIRouter(prefix="/reviews", tags=["reviews"])
admin_router = APIRouter(prefix="/admin/reviews", tags=["admin-reviews"])

REVIEWABLE = "COMPLETED"


def unprocessable(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=detail)


def public_out(review: Review, storage: R2Storage) -> PublicReview:
    return PublicReview(
        id=review.id, name=review.name, city=review.city, rating=review.rating, text=review.text,
        product_name=review.product_name, product_slug=review.product_slug,
        photos=[storage.public_url(p.media.key) for p in review.photos], created_at=review.created_at,
    )


async def order_numbers(session: AsyncSession, reviews: list[Review]) -> dict[int, str]:
    """Order numbers of the reviews' orders, in one query."""
    ids = {r.order_id for r in reviews if r.order_id is not None}
    if not ids:
        return {}
    return dict((await session.execute(select(Order.id, Order.order_number).where(Order.id.in_(ids)))).all())


async def reviews_out(session: AsyncSession, reviews: list[Review], storage: R2Storage) -> list[ReviewOut]:
    numbers = await order_numbers(session, reviews)
    return [review_out_with(review, numbers.get(review.order_id), storage) for review in reviews]


async def review_out(session: AsyncSession, review: Review, storage: R2Storage) -> ReviewOut:
    return (await reviews_out(session, [review], storage))[0]


def review_out_with(review: Review, number: str | None, storage: R2Storage) -> ReviewOut:
    return ReviewOut(
        **public_out(review, storage).model_dump(), status=review.status, order_id=review.order_id,
        order_number=number, from_customer=review.user_id is not None and review.order_id is not None,
        sort_order=review.sort_order,
    )


async def photos_of(session: AsyncSession, ids: list[str], allowed) -> list[ReviewPhoto]:
    """Checks every photo with `allowed(media)`; keeps their order."""
    if len(set(ids)) != len(ids):
        raise unprocessable("Bir rasm ikki marta qo'shilgan")
    rows = {m.id: m for m in (await session.execute(select(Media).where(Media.id.in_(ids)))).scalars()}
    for media_id in ids:
        media = rows.get(media_id)
        if media is None or media.status != "ready" or not media.content_type.startswith("image/") or not allowed(media):
            raise unprocessable(msg("Rasm topilmadi yoki sizga tegishli emas: {media_id}", media_id=media_id))
    return [ReviewPhoto(media_id=media_id, sort_order=i) for i, media_id in enumerate(ids)]


async def fresh(session: AsyncSession, review_id: int) -> Review:
    session.expunge_all()
    return (await session.execute(select(Review).where(Review.id == review_id))).scalar_one()


# ── Public and customers ──


@router.get("/", response_model=list[PublicReview])
async def list_reviews(
    limit: int = Query(default=12, ge=1, le=50), session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
):
    rows = (
        await session.execute(
            select(Review).where(Review.status == "approved")
            .order_by(Review.sort_order, Review.created_at.desc()).limit(limit)
        )
    ).scalars().all()
    return [public_out(r, storage) for r in rows]


@router.get("/mine/", response_model=list[ReviewOut])
async def my_reviews(
    user: User = Depends(get_current_user), session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
):
    rows = (await session.execute(select(Review).where(Review.user_id == user.id).order_by(Review.created_at.desc()))).scalars().all()
    return await reviews_out(session, list(rows), storage)


@router.post("/", response_model=ReviewOut, status_code=status.HTTP_201_CREATED)
async def create_review(
    payload: ReviewIn, user: User = Depends(get_current_user), session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
):
    order = (
        await session.execute(
            select(Order).options(selectinload(Order.items)).where(Order.id == payload.order_id, Order.customer_id == user.id)
        )
    ).scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Buyurtma topilmadi")
    if order.status != REVIEWABLE:
        raise unprocessable("Fikrni buyurtma yakunlangach qoldirish mumkin")
    if (await session.execute(select(Review.id).where(Review.order_id == order.id))).first():
        raise unprocessable("Bu buyurtmaga fikr allaqachon qoldirilgan")
    photos = await photos_of(session, payload.photo_ids, lambda m: m.purpose == "design" and m.owner_id == user.id)
    first = order.items[0] if order.items else None
    review = Review(
        user_id=user.id, order_id=order.id, name=(user.first_name or user.full_name or "Mijoz").strip()[:80],
        city=payload.city, product_name=first.product_name if first else "", product_slug=first.product_slug if first else "",
        rating=payload.rating, text=payload.text, status="pending", photos=photos,
    )
    session.add(review)
    await session.commit()
    return await review_out(session, await fresh(session, review.id), storage)


# ── Admin ──


@admin_router.get("/", response_model=list[ReviewOut])
async def admin_list(
    state: Status | None = Query(default=None, alias="status"), session: AsyncSession = Depends(get_db),
    _: User = Depends(admin_user), storage: R2Storage = Depends(get_storage),
):
    query = select(Review).order_by(Review.sort_order, Review.created_at.desc())
    if state:
        query = query.where(Review.status == state)
    return await reviews_out(session, list((await session.execute(query)).scalars().all()), storage)


@admin_router.post("/", response_model=ReviewOut, status_code=status.HTTP_201_CREATED)
async def admin_create(
    payload: AdminReviewIn, session: AsyncSession = Depends(get_db), admin: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    product_name = ""
    if payload.product_slug:
        product = (await session.execute(select(Product).where(Product.slug == payload.product_slug))).scalar_one_or_none()
        if product is None:
            raise unprocessable("Mahsulot topilmadi")
        product_name = product.name
    photos = await photos_of(
        session, payload.photo_ids, lambda m: m.purpose == "catalog" or (m.purpose == "design" and m.owner_id == admin.id)
    )
    review = Review(
        name=payload.name, city=payload.city, rating=payload.rating, text=payload.text, product_slug=payload.product_slug,
        product_name=product_name, status="approved", photos=photos,
    )
    session.add(review)
    await session.commit()
    return await review_out(session, await fresh(session, review.id), storage)


async def review_or_404(session: AsyncSession, review_id: int) -> Review:
    review = await session.get(Review, review_id)
    if review is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Fikr topilmadi")
    return review


@admin_router.patch("/{review_id}/", response_model=ReviewOut)
async def admin_update(
    review_id: int, payload: ReviewPatch, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user),
    storage: R2Storage = Depends(get_storage),
):
    review = await review_or_404(session, review_id)
    for field, value in payload.model_dump(exclude_none=True).items():
        setattr(review, field, value)
    await session.commit()
    return await review_out(session, await fresh(session, review_id), storage)


@admin_router.delete("/{review_id}/", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete(review_id: int, session: AsyncSession = Depends(get_db), _: User = Depends(admin_user)) -> Response:
    await session.delete(await review_or_404(session, review_id))
    await session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
