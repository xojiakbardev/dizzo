"""Gallery showcase items: what an admin sends and gets back."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, BeforeValidator, Field

from app.schemas.catalog import Strict
from app.schemas.design import MediaId


def _blank_to_none(value: object) -> object:
    if isinstance(value, str):
        value = value.strip()
        return value or None
    return value


Title = Annotated[Annotated[str, Field(max_length=120)] | None, BeforeValidator(_blank_to_none)]
CustomerName = Annotated[Annotated[str, Field(max_length=80)] | None, BeforeValidator(_blank_to_none)]
# The 1-5 count is checked in the router, for a clear message.
MediaIds = Annotated[list[MediaId], Field(max_length=50)]


class ShowcaseIn(Strict):
    product_id: int
    media_ids: MediaIds
    title: Title = None
    customer_name: CustomerName = None
    is_published: bool = False


class ShowcasePatch(Strict):
    """Only the fields sent change; `media_ids` replaces the whole list.
    `title`/`customer_name` sent as null or blank clear them."""

    product_id: int | None = None
    media_ids: MediaIds | None = None
    title: Title = None
    customer_name: CustomerName = None
    is_published: bool | None = None


class ShowcaseSubmitIn(Strict):
    product_id: int
    media_ids: MediaIds
    title: Title = None
    customer_name: CustomerName = None


class ShowcaseModerateIn(Strict):
    status: str  # "APPROVED" or "REJECTED"
    rejection_reason: str | None = None


class ShowcaseOrder(Strict):
    ids: list[int] = Field(max_length=1000)


class ShowcaseImageOut(BaseModel):
    media_id: str
    url: str


class ShowcaseOut(BaseModel):
    id: int
    product_id: int
    product_name: str
    product_slug: str
    title: str | None
    customer_name: str | None
    sort_order: int
    is_published: bool
    status: str = "APPROVED"
    created_by_name: str | None = None
    branch_name: str | None = None
    rejection_reason: str | None = None
    created_at: datetime
    images: list[ShowcaseImageOut]

