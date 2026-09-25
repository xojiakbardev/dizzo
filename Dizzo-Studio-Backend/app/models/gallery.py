"""Admin-curated gallery showcase ("Galereya").

Until completed orders fill the public gallery, admins add showcase
items: a product, 1–5 photos (catalog uploads) and an optional title and
customer name. Only published items are public.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import Boolean, ForeignKey, Integer, String, false
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin
from app.models.catalog import Product
from app.models.media import Media

if TYPE_CHECKING:
    from app.models.branch import Branch
    from app.models.user import User

MAX_SHOWCASE_IMAGES = 5


class GalleryShowcase(TimestampMixin, Base):
    __tablename__ = "gallery_showcase"

    id: Mapped[int] = mapped_column(primary_key=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"), index=True)
    title: Mapped[str | None] = mapped_column(String(120), nullable=True)
    customer_name: Mapped[str | None] = mapped_column(String(80), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    is_published: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false(), index=True)

    created_by_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    branch_id: Mapped[int | None] = mapped_column(ForeignKey("branches.id", ondelete="SET NULL"), nullable=True, index=True)
    status: Mapped[str] = mapped_column(String(32), default="APPROVED", server_default="APPROVED", index=True)  # PENDING_APPROVAL, APPROVED, REJECTED
    rejection_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)

    product: Mapped[Product] = relationship(lazy="selectin")
    created_by: Mapped[User | None] = relationship(lazy="selectin")
    branch: Mapped[Branch | None] = relationship(lazy="selectin")
    images: Mapped[list[GalleryShowcaseImage]] = relationship(
        order_by="GalleryShowcaseImage.sort_order", cascade="all, delete-orphan", lazy="selectin"
    )


class GalleryShowcaseImage(Base):
    __tablename__ = "gallery_showcase_images"

    id: Mapped[int] = mapped_column(primary_key=True)
    showcase_id: Mapped[int] = mapped_column(ForeignKey("gallery_showcase.id", ondelete="CASCADE"), index=True)
    media_id: Mapped[str] = mapped_column(ForeignKey("media.id", ondelete="RESTRICT"))
    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    media: Mapped[Media] = relationship(lazy="selectin")
