"""Tutorial videos ("Video darsliklar") shown on the landing page.

Each item is a title, a cover picture (a catalog upload) and, once the
video is recorded, a link to it (YouTube / Telegram / an MP4 file). Only
published items are public; the admin orders them.
"""

from __future__ import annotations

from sqlalchemy import Boolean, ForeignKey, Integer, String, false
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, TranslatableMixin
from app.models.media import Media


class TutorialVideo(TimestampMixin, TranslatableMixin, Base):
    __tablename__ = "tutorial_videos"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(120))
    cover_media_id: Mapped[str] = mapped_column(ForeignKey("media.id", ondelete="RESTRICT"))
    # Pixel size of the cover, so the masonry grid keeps its shape while
    # the pictures load. Optional.
    cover_width: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cover_height: Mapped[int | None] = mapped_column(Integer, nullable=True)
    video_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    is_published: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false(), index=True)

    cover: Mapped[Media] = relationship(lazy="selectin")
