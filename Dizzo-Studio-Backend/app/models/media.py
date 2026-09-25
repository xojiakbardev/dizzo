from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin


class Media(TimestampMixin, Base):
    """A file stored in R2. Created `pending` when an upload URL is issued,
    flipped to `ready` once the backend has seen the object in the bucket.

    Guest uploads (owner_id NULL) live under designs/guests/ and are moved
    to the user's designs/u<id>/ prefix when claimed after login. What no
    login ever claims, what never finished uploading and what nothing
    references any more is deleted in time by app/scripts/cleanup_media.py;
    the windows are settings (app/core/config.py)."""

    __tablename__ = "media"
    __table_args__ = (Index("ix_media_uploader_ip_created_at", "uploader_ip", "created_at"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    # The R2 object key; its folder says what the file is (object_key in
    # api/v1/media.py): catalog/ models/ templates/ designs/ prints/ avatars/.
    key: Mapped[str] = mapped_column(String(300), unique=True)
    # design | catalog | model (GLB) | print (cart print files) | avatar |
    # library (images of admin templates: any design may use them).
    # Catalog pictures published as DesignAsset rows may also sit on a design.
    purpose: Mapped[str] = mapped_column(String(16))
    content_type: Mapped[str] = mapped_column(String(100))
    size_bytes: Mapped[int] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(16), default="pending")  # pending | ready
    owner_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    uploader_ip: Mapped[str] = mapped_column(String(45), default="")
