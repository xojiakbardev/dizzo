"""Public and Admin API for Design Assets (Studio icons, stickers, and curated photos)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.admin_catalog import admin_user, not_found
from app.db.session import get_db
from app.models.design_asset import DesignAsset
from app.models.media import Media
from app.models.user import User
from app.schemas.design_asset import (
    DesignAssetBulkCreate,
    DesignAssetCreate,
    DesignAssetOrder,
    DesignAssetOut,
    DesignAssetUpdate,
)
from app.services.storage import R2Storage, get_storage

public_router = APIRouter(prefix="/catalog/assets", tags=["catalog-assets"])
admin_router = APIRouter(prefix="/admin/catalog/assets", tags=["admin-catalog-assets"])


def to_out(asset: DesignAsset, storage: R2Storage) -> DesignAssetOut:
    return DesignAssetOut(
        id=asset.id,
        media_id=asset.media_id,
        name=asset.name,
        category=asset.category,
        type=asset.type,
        is_active=asset.is_active,
        sort_order=asset.sort_order,
        url=storage.public_url(asset.media.key),
        created_at=asset.created_at,
        updated_at=asset.updated_at,
    )


DEFAULT_CATEGORIES = [
    {"key": "all", "label": {"uz": "Barchasi", "ru": "Все", "en": "All"}, "icon": "lucide:layout-grid"},
    {"key": "yuz-qismlari", "label": {"uz": "Ko‘z & Yuz qismlari", "ru": "Части лица (глаза, рот)", "en": "Face Parts"}, "icon": "lucide:eye"},
    {"key": "yuzlar", "label": {"uz": "Yuzlar va Emojilar", "ru": "Лица и эмодзи", "en": "Faces & Emojis"}, "icon": "lucide:smile"},
    {"key": "fonlar", "label": {"uz": "Fonlar (Background)", "ru": "Фоны", "en": "Backgrounds"}, "icon": "lucide:wallpaper"},
    {"key": "ramkalar", "label": {"uz": "Ramkalar (Foto)", "ru": "Рамки для фото", "en": "Photo Frames"}, "icon": "lucide:frame"},
    {"key": "love", "label": {"uz": "Sevgi & Romantika", "ru": "Любовь & Романтика", "en": "Love & Romance"}, "icon": "lucide:heart"},
    {"key": "party", "label": {"uz": "Bayram & Party", "ru": "Праздник & Вечеринка", "en": "Party & Celebration"}, "icon": "lucide:party-popper"},
    {"key": "mushuklar", "label": {"uz": "Mushuklar & Hayvonlar", "ru": "Котики & Животные", "en": "Cats & Animals"}, "icon": "lucide:cat"},
    {"key": "teddy", "label": {"uz": "Teddy ayiqchalar", "ru": "Мишки Тедди", "en": "Teddy Bears"}, "icon": "lucide:sparkles"},
    {"key": "multfilm", "label": {"uz": "Multfilm qahramonlar", "ru": "Герои мультфильмов", "en": "Cartoon Heroes"}, "icon": "lucide:clapperboard"},
    {"key": "tabiat", "label": {"uz": "Tabiat & Gullar", "ru": "Природа & Цветы", "en": "Nature & Flowers"}, "icon": "lucide:trees"},
    {"key": "boshqa", "label": {"uz": "Boshqa iconlar", "ru": "Другое", "en": "Other"}, "icon": "lucide:shapes"},
]

DEFAULT_TYPES = [
    {"key": "all", "label": {"uz": "Barcha turlar", "ru": "Все типы", "en": "All Types"}},
    {"key": "icon", "label": {"uz": "Icon", "ru": "Иконка", "en": "Icon"}},
    {"key": "sticker", "label": {"uz": "Stiker", "ru": "Стикер", "en": "Sticker"}},
    {"key": "photo", "label": {"uz": "Rasm", "ru": "Фотография", "en": "Photo"}},
]

CATEGORY_LABELS = {c["key"]: c for c in DEFAULT_CATEGORIES}


@public_router.get("/meta/")
async def get_assets_meta(
    session: AsyncSession = Depends(get_db),
) -> dict:
    """Return asset categories and types with multi-language labels (uz, ru, en)."""
    # Fetch all distinct categories present in the database
    res = await session.execute(select(DesignAsset.category).distinct())
    db_cats = [r[0] for r in res.all() if r[0]]

    # Ensure all DB categories are included
    categories = list(DEFAULT_CATEGORIES)
    existing_keys = {c["key"] for c in categories}

    for cat in db_cats:
        if cat not in existing_keys:
            human_name = cat.replace("-", " ").title()
            categories.append({
                "key": cat,
                "label": {"uz": human_name, "ru": human_name, "en": human_name},
                "icon": "lucide:folder",
            })

    return {
        "categories": categories,
        "types": DEFAULT_TYPES,
    }


# ── Public Endpoints ──

@public_router.get("/", response_model=list[DesignAssetOut])
async def list_public_assets(
    category: str | None = Query(default=None),
    type: str | None = Query(default=None),
    session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
) -> list[DesignAssetOut]:
    """Public active icons and stickers for Studio users."""
    stmt = select(DesignAsset).where(DesignAsset.is_active == True)  # noqa: E712
    if category and category != "all":
        stmt = stmt.where(DesignAsset.category == category)
    if type and type != "all":
        stmt = stmt.where(DesignAsset.type == type)
    stmt = stmt.order_by(DesignAsset.sort_order.asc(), DesignAsset.id.desc())

    result = await session.execute(stmt)
    rows = result.scalars().all()
    return [to_out(r, storage) for r in rows]


# ── Admin Endpoints ──

@admin_router.get("/", response_model=list[DesignAssetOut])
async def list_admin_assets(
    category: str | None = Query(default=None),
    type: str | None = Query(default=None),
    _: User = Depends(admin_user),
    session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
) -> list[DesignAssetOut]:
    """Admin view of all assets (both active and hidden)."""
    stmt = select(DesignAsset)
    if category and category != "all":
        stmt = stmt.where(DesignAsset.category == category)
    if type and type != "all":
        stmt = stmt.where(DesignAsset.type == type)
    stmt = stmt.order_by(DesignAsset.sort_order.asc(), DesignAsset.id.desc())

    result = await session.execute(stmt)
    rows = result.scalars().all()
    return [to_out(r, storage) for r in rows]


@admin_router.post("/", response_model=DesignAssetOut, status_code=status.HTTP_201_CREATED)
async def create_asset(
    body: DesignAssetCreate,
    _: User = Depends(admin_user),
    session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
) -> DesignAssetOut:
    """Insert a single asset."""
    media = (await session.execute(select(Media).where(Media.id == body.media_id))).scalar_one_or_none()
    if not media:
        raise not_found("Media topilmadi")

    asset = DesignAsset(
        media_id=body.media_id,
        name=body.name.strip(),
        category=body.category.strip().lower(),
        type=body.type.strip().lower(),
        is_active=body.is_active,
        sort_order=body.sort_order,
    )
    session.add(asset)
    await session.commit()
    await session.refresh(asset)
    return to_out(asset, storage)


@admin_router.post("/bulk/", response_model=list[DesignAssetOut], status_code=status.HTTP_201_CREATED)
async def bulk_create_assets(
    body: DesignAssetBulkCreate,
    _: User = Depends(admin_user),
    session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
) -> list[DesignAssetOut]:
    """Bulk insert multiple uploaded assets with a common category and type."""
    if not body.items:
        return []

    media_ids = [item.media_id for item in body.items]
    rows = (await session.execute(select(Media).where(Media.id.in_(media_ids)))).scalars().all()
    found_map = {m.id: m for m in rows}

    assets: list[DesignAsset] = []
    for item in body.items:
        if item.media_id not in found_map:
            continue
        asset = DesignAsset(
            media_id=item.media_id,
            name=item.name.strip() or "Nomsiz icon",
            category=body.category.strip().lower(),
            type=body.type.strip().lower(),
            is_active=True,
            sort_order=0,
        )
        session.add(asset)
        assets.append(asset)

    await session.commit()
    for a in assets:
        await session.refresh(a)
    return [to_out(a, storage) for a in assets]


@admin_router.patch("/{id}/", response_model=DesignAssetOut)
async def update_asset(
    id: int,
    body: DesignAssetUpdate,
    _: User = Depends(admin_user),
    session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
) -> DesignAssetOut:
    """Update an asset's details or toggle active status (Show/Hide)."""
    asset = (await session.execute(select(DesignAsset).where(DesignAsset.id == id))).scalar_one_or_none()
    if not asset:
        raise not_found("Asset topilmadi")

    if body.name is not None:
        asset.name = body.name.strip()
    if body.category is not None:
        asset.category = body.category.strip().lower()
    if body.type is not None:
        asset.type = body.type.strip().lower()
    if body.is_active is not None:
        asset.is_active = body.is_active
    if body.sort_order is not None:
        asset.sort_order = body.sort_order

    await session.commit()
    await session.refresh(asset)
    return to_out(asset, storage)


@admin_router.delete("/{id}/", status_code=status.HTTP_204_NO_CONTENT)
async def delete_asset(
    id: int,
    _: User = Depends(admin_user),
    session: AsyncSession = Depends(get_db),
) -> Response:
    """Delete an asset."""
    asset = (await session.execute(select(DesignAsset).where(DesignAsset.id == id))).scalar_one_or_none()
    if not asset:
        raise not_found("Asset topilmadi")

    await session.delete(asset)
    await session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@admin_router.put("/order/", response_model=list[DesignAssetOut])
async def reorder_assets(
    body: DesignAssetOrder,
    _: User = Depends(admin_user),
    session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
) -> list[DesignAssetOut]:
    """Reorder assets."""
    rows = (await session.execute(select(DesignAsset).where(DesignAsset.id.in_(body.ids)))).scalars().all()
    order_map = {id_: idx for idx, id_ in enumerate(body.ids)}
    for r in rows:
        r.sort_order = order_map.get(r.id, 0)

    await session.commit()
    stmt = select(DesignAsset).order_by(DesignAsset.sort_order.asc(), DesignAsset.id.desc())
    all_assets = (await session.execute(stmt)).scalars().all()
    return [to_out(a, storage) for a in all_assets]
