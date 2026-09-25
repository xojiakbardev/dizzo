from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.i18n import get_language, tr, tr_dict
from app.db.session import get_db
from app.models.catalog import DesignTemplate, Product
from app.models.commerce import Order, OrderItem
from app.models.user import User
from app.services.feed_cache import cached
from app.services.storage import R2Storage, get_storage

router = APIRouter(prefix="/gallery", tags=["gallery"])

# The newest completed orders the feed looks at.
ORDER_WINDOW = 1000


async def gallery_feed(session: AsyncSession, storage: R2Storage) -> list[dict]:
    """`build_feed`, cached a minute per language."""
    return await cached(("gallery", get_language()), lambda: build_feed(session, storage))


async def build_feed(session: AsyncSession, storage: R2Storage) -> list[dict]:
    """The whole public gallery, in order: first the items of completed
    orders (never drafts or open carts), newest first, with their mockup
    frames; then the published designs (templates) of the admin's
    "Galereya" whose product is on sale, by sort_order, id.

    Every item has `id` ("order-<id>" / "template-<id>"), `kind`,
    `order_item_id` (negative template id for designs), `product_name`,
    `product_slug`, `category` (the product's catalog shelf, or null),
    `title`, `customer_name`, `preview_image_url`, `image_urls` (the
    preview first) and `created_at`; designs add `template_id`,
    `variant_id` and `color_id` to open them in the Studio. Names and
    titles are in the request's language.
    """
    shelves = dict((await session.execute(select(Product.slug, Product.category))).all())
    rows = (
        await session.execute(
            select(OrderItem, User)
            .join(Order, Order.id == OrderItem.order_id)
            .join(User, User.id == Order.customer_id)
            .where(Order.status == "COMPLETED")
            .order_by(Order.updated_at.desc())
            .limit(ORDER_WINDOW)
        )
    ).all()
    items = []
    for item, customer in rows:
        mockups = [m["key"] for m in (item.package or {}).get("mockups") or [] if m.get("key")]
        if not mockups:
            continue
        urls = [storage.public_url(key) for key in mockups]
        items.append({
            "id": f"order-{item.id}",
            "kind": "order",
            "order_item_id": item.id,
            "product_name": tr_dict(item.translations, "product_name", item.product_name),
            "product_slug": item.product_slug or None,
            "category": shelves.get(item.product_slug),
            "title": None,
            "customer_name": customer.first_name or customer.full_name,
            "preview_image_url": urls[0],
            "image_urls": urls,
            "created_at": item.created_at.isoformat(),
        })

    designs = (
        await session.execute(
            select(DesignTemplate)
            .join(Product, Product.id == DesignTemplate.product_id)
            .where(
                DesignTemplate.in_gallery.is_(True),
                DesignTemplate.is_active.is_(True),
                Product.archived_at.is_(None),
                Product.is_available.is_(True),
            )
            .order_by(DesignTemplate.sort_order, DesignTemplate.id)
        )
    ).scalars().all()
    for design in designs:
        on_sale = [v for v in design.variants if v.archived_at is None and v.is_available]
        if not on_sale:
            continue
        urls = [storage.public_url(image.media.key) for image in design.images] or [
            storage.public_url(design.preview.key)
        ]
        colour = next(
            (c for v in on_sale for c in v.colors if c.id == design.color_id and c.archived_at is None), None
        )
        variant = next((v for v in on_sale if colour is not None and colour.variant_id == v.id), on_sale[0])
        items.append({
            "id": f"template-{design.id}",
            "kind": "template",
            "order_item_id": -design.id,
            "template_id": design.id,
            "variant_id": variant.id,
            "color_id": colour.id if colour is not None else None,
            "product_name": tr(design.product, "name"),
            "product_slug": design.product.slug,
            "category": design.product.category,
            "title": tr(design, "name"),
            "customer_name": "",
            "preview_image_url": urls[0],
            "image_urls": urls,
            "created_at": design.created_at.isoformat(),
        })
    return items


@router.get("/")
async def list_gallery(
    response: Response,
    limit: int = Query(default=24, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    category: str | None = Query(default=None, max_length=40),
    session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
):
    """Public gallery, a page at a time (see `gallery_feed` for the order
    and the fields); `category` keeps one catalog shelf."""
    items = await gallery_feed(session, storage)
    if category:
        items = [i for i in items if i["category"] == category]
    response.headers["X-Total-Count"] = str(len(items))
    return items[offset:offset + limit]


@router.get("/item/{item_id}/")
async def gallery_item(
    item_id: str,
    session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
):
    """One piece of the public gallery by its `id` ("order-5",
    "template-12"): a shared link's preview and the piece it opens."""
    for item in await gallery_feed(session, storage):
        if item["id"] == item_id:
            return item
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Galereyada bunday ish yo‘q")


@router.get("/shelves/")
async def gallery_shelves(
    session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
):
    """How many gallery pieces each catalog shelf has, and the total."""
    items = await gallery_feed(session, storage)
    counts: dict[str, int] = {}
    for item in items:
        if item["category"]:
            counts[item["category"]] = counts.get(item["category"], 0) + 1
    return {"total": len(items), "counts": counts}
