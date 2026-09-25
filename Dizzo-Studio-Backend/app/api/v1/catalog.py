"""Public catalog: what the storefront and the Studio read, plus the price
quote. Only sellable products/variants/colours are ever exposed, and the
price is always computed here — the frontend never knows the formula."""

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.i18n import get_language, tr
from app.db.session import get_db
from app.models.catalog import DesignTemplate, Product, ProductCategory, Variant, VariantColor
from app.models.commerce import Order, OrderItem
from app.schemas.catalog import PublicCategory, PublicProductCard, PublicProductDetail, QuoteIn, QuoteOut
from app.schemas.design import DesignDocument
from app.schemas.template import PublicTemplate
from app.services.catalog import local_size, quote, sellable_variants, unprocessable
from app.services.catalog_views import public_card, public_detail
from app.services.feed_cache import cached
from app.services.storage import R2Storage, get_storage

router = APIRouter(prefix="/catalog", tags=["catalog"])


def fold(text: str) -> str:
    """Search text: lower case, Uzbek apostrophes as one."""
    for mark in "‘’ʻʼ`":
        text = text.replace(mark, "'")
    return text.lower()


async def card_list(sort: str | None, session: AsyncSession, storage: R2Storage) -> list[tuple[PublicProductCard, str]]:
    """Every card on sale in the request's language, with the text search
    matches (the name in all three languages); cached a minute."""

    async def build() -> list[tuple[PublicProductCard, str]]:
        products = await sellable_products(sort, session)
        return [
            (public_card(p, storage), fold(" ".join([p.name, *(t.get("name", "") for t in (p.translations or {}).values())])))
            for p in products
        ]

    return await cached(("cards", get_language(), sort), build)


@router.get("/products/", response_model=list[PublicProductCard])
async def list_products(
    response: Response,
    sort: Literal["popular"] | None = None,
    category: str | None = Query(default=None, max_length=40),
    q: str | None = Query(default=None, max_length=100),
    limit: int | None = Query(default=None, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_db), storage: R2Storage = Depends(get_storage),
):
    """In the admin's order; `sort=popular`: the most pieces ordered first
    (cancelled orders don't count), then the newest. `category` and `q`
    (the name, in any language) filter; `limit`/`offset` page (every card
    without them). X-Total-Count: how many match."""
    cards = await card_list(sort, session, storage)
    words = fold(q or "").split()
    found = [
        card for card, text in cards
        if (not category or card.category == category) and all(w in text for w in words)
    ]
    response.headers["X-Total-Count"] = str(len(found))
    return found[offset:offset + limit] if limit else found[offset:]


@router.get("/products/shelves/")
async def product_shelves(session: AsyncSession = Depends(get_db), storage: R2Storage = Depends(get_storage)):
    """How many products on sale each shelf has, and the total."""
    cards = await card_list(None, session, storage)
    counts: dict[str, int] = {}
    for card, _text in cards:
        counts[card.category] = counts.get(card.category, 0) + 1
    return {"total": len(cards), "counts": counts}


async def sellable_products(sort: str | None, session: AsyncSession) -> list[Product]:
    query = select(Product).where(Product.archived_at.is_(None), Product.is_available.is_(True))
    if sort == "popular":
        # Order lines keep a slug snapshot, not a foreign key.
        sold = (
            select(OrderItem.product_slug, func.sum(OrderItem.quantity).label("sold"))
            .join(Order, Order.id == OrderItem.order_id)
            .where(Order.status != "CANCELLED")
            .group_by(OrderItem.product_slug)
            .subquery()
        )
        query = query.outerjoin(sold, sold.c.product_slug == Product.slug).order_by(
            func.coalesce(sold.c.sold, 0).desc(), Product.created_at.desc(), Product.id.desc()
        )
    else:
        query = query.order_by(Product.sort_order, Product.name)
    products = (await session.execute(query)).scalars().all()
    return [p for p in products if sellable_variants(p)]


@router.get("/categories/", response_model=list[PublicCategory])
async def list_categories(session: AsyncSession = Depends(get_db), storage: R2Storage = Depends(get_storage)):
    """The storefront shelves, in the admin's order."""
    rows = (
        await session.execute(
            select(ProductCategory)
            .where(ProductCategory.is_active.is_(True))
            .order_by(ProductCategory.sort_order, ProductCategory.name)
        )
    ).scalars().all()
    return [
        PublicCategory(
            slug=c.slug, name=tr(c, "name"), icon_svg=c.icon_svg,
            image_url=storage.public_url(c.image.key) if c.image else None,
        )
        for c in rows
    ]


@router.get("/products/{slug}/", response_model=PublicProductDetail)
async def product_detail(slug: str, session: AsyncSession = Depends(get_db), storage: R2Storage = Depends(get_storage)):
    product = (await session.execute(select(Product).where(Product.slug == slug))).scalar_one_or_none()
    if product is None or not sellable_variants(product):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Mahsulot topilmadi")
    return public_detail(product, storage)


@router.get("/products/{slug}/templates/", response_model=list[PublicTemplate])
async def product_templates(
    slug: str, session: AsyncSession = Depends(get_db), storage: R2Storage = Depends(get_storage)
):
    """Active templates of a product, each with the variants on sale it fits;
    the Studio shows those of the chosen variant."""
    product = (await session.execute(select(Product).where(Product.slug == slug))).scalar_one_or_none()
    on_sale = {v.id for v in sellable_variants(product)} if product is not None else set()
    if not on_sale:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Mahsulot topilmadi")
    templates = (
        await session.execute(
            select(DesignTemplate)
            .where(DesignTemplate.product_id == product.id, DesignTemplate.is_active.is_(True))
            .order_by(DesignTemplate.sort_order, DesignTemplate.id)
        )
    ).scalars().all()
    out = []
    for t in templates:
        variant_ids = [v.id for v in t.variants if v.id in on_sale]
        if variant_ids:
            out.append(PublicTemplate(
                id=t.id, name=tr(t, "name"), category=t.category, preview_url=storage.public_url(t.preview.key),
                variant_ids=variant_ids, document=DesignDocument.model_validate(t.document),
            ))
    return out


@router.post("/quote/", response_model=QuoteOut)
async def price_quote(payload: QuoteIn, session: AsyncSession = Depends(get_db)):
    variant = (
        await session.execute(
            select(Variant).where(Variant.id == payload.variant_id).options(selectinload(Variant.product))
        )
    ).scalar_one_or_none()
    color = await session.get(VariantColor, payload.color_id)
    if variant is None or color is None:
        raise unprocessable("Variant yoki rang topilmadi")
    price = quote(variant, color, payload.quantity, payload.areas_cm2, payload.size)
    price.size = local_size(variant, price.size)
    return price
