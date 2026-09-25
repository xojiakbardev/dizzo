"""Customer reviews: what a customer sends, what an admin enters or
changes, and what the site shows."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

from app.schemas.catalog import Strict
from app.schemas.design import MediaId

Rating = Annotated[int, Field(ge=1, le=5)]
ReviewText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=10, max_length=1000)]
Name = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=80)]
City = Annotated[str, StringConstraints(strip_whitespace=True, max_length=80)]
Photos = Annotated[list[MediaId], Field(max_length=6)]
Status = Literal["pending", "approved", "rejected"]


class ReviewIn(Strict):
    """A customer's review of one of their completed orders."""

    order_id: int
    rating: Rating
    text: ReviewText
    city: City = ""
    photo_ids: Photos = Field(default_factory=list)


class AdminReviewIn(Strict):
    """A review a customer sent the shop elsewhere, entered by an admin."""

    name: Name
    city: City = ""
    rating: Rating
    text: ReviewText
    product_slug: str = Field(default="", max_length=120)
    photo_ids: Photos = Field(default_factory=list)


class ReviewPatch(Strict):
    status: Status | None = None
    name: Name | None = None
    city: City | None = None
    rating: Rating | None = None
    text: ReviewText | None = None
    sort_order: int | None = Field(default=None, ge=0, le=100000)


class Out(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class PublicReview(Out):
    id: int
    name: str
    city: str
    rating: int
    text: str
    product_name: str
    product_slug: str
    photos: list[str]
    created_at: datetime


class ReviewOut(PublicReview):
    """With what a customer or an admin sees about its moderation."""

    status: Status
    order_id: int | None
    order_number: str | None
    from_customer: bool  # sent through the site (else entered by an admin)
    sort_order: int
