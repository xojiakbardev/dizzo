"""Schemas for Design Assets (icons, stickers, and photos)."""

from __future__ import annotations

from datetime import datetime
from pydantic import BaseModel, Field

from app.schemas.catalog import Strict


class DesignAssetCreate(Strict):
    media_id: str
    name: str = Field(max_length=120)
    category: str = Field(default="boshqa", max_length=50)
    type: str = Field(default="icon", max_length=20)  # icon, sticker, photo
    is_active: bool = True
    sort_order: int = 0


class DesignAssetBulkItem(Strict):
    media_id: str
    name: str = Field(max_length=120)


class DesignAssetBulkCreate(Strict):
    category: str = Field(default="boshqa", max_length=50)
    type: str = Field(default="icon", max_length=20)  # icon, sticker, photo
    items: list[DesignAssetBulkItem] = Field(max_length=200)


class DesignAssetUpdate(Strict):
    name: str | None = Field(default=None, max_length=120)
    category: str | None = Field(default=None, max_length=50)
    type: str | None = Field(default=None, max_length=20)
    is_active: bool | None = None
    sort_order: int | None = None


class DesignAssetOrder(Strict):
    ids: list[int] = Field(max_length=1000)


class DesignAssetOut(BaseModel):
    id: int
    media_id: str
    name: str
    category: str
    type: str
    is_active: bool
    sort_order: int
    url: str
    px_w: int | None = None
    px_h: int | None = None
    created_at: datetime
    updated_at: datetime
