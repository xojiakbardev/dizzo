"""Design assets (icons, stickers, curated photos) for Studio elements."""

from __future__ import annotations

from sqlalchemy import Boolean, ForeignKey, Integer, String, false, true
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin
from app.models.media import Media


class DesignAsset(TimestampMixin, Base):
    __tablename__ = "design_assets"

    id: Mapped[int] = mapped_column(primary_key=True)
    media_id: Mapped[str] = mapped_column(ForeignKey("media.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    category: Mapped[str] = mapped_column(String(50), nullable=False, default="boshqa", server_default="boshqa", index=True)
    type: Mapped[str] = mapped_column(String(20), nullable=False, default="icon", server_default="icon", index=True)  # icon, sticker, photo
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default=true(), index=True)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0", index=True)

    media: Mapped[Media] = relationship(lazy="selectin")
