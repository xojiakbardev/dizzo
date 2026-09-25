"""Customer reviews ("Mijozlarimiz").

A customer reviews a completed order, with photos of what arrived; an
admin approves it before it shows on the site. Admins may also enter a
review a customer sent them elsewhere (Instagram, Telegram) — with the
customer's consent. Only approved reviews are public.
"""

from __future__ import annotations

from sqlalchemy import ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin
from app.models.media import Media

REVIEW_STATUSES = ("pending", "approved", "rejected")


class Review(TimestampMixin, Base):
    __tablename__ = "reviews"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    # One review per order; NULL for reviews an admin entered.
    order_id: Mapped[int | None] = mapped_column(
        ForeignKey("orders.id", ondelete="SET NULL"), nullable=True, unique=True
    )
    name: Mapped[str] = mapped_column(String(80))
    city: Mapped[str] = mapped_column(String(80), default="")
    product_name: Mapped[str] = mapped_column(String(200), default="")
    product_slug: Mapped[str] = mapped_column(String(120), default="")
    rating: Mapped[int] = mapped_column(Integer)
    text: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(16), default="pending", index=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    photos: Mapped[list[ReviewPhoto]] = relationship(
        order_by="ReviewPhoto.sort_order", cascade="all, delete-orphan", lazy="selectin"
    )


class ReviewPhoto(Base):
    __tablename__ = "review_photos"

    id: Mapped[int] = mapped_column(primary_key=True)
    review_id: Mapped[int] = mapped_column(ForeignKey("reviews.id", ondelete="CASCADE"), index=True)
    media_id: Mapped[str] = mapped_column(ForeignKey("media.id", ondelete="RESTRICT"))
    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    media: Mapped[Media] = relationship(lazy="selectin")
