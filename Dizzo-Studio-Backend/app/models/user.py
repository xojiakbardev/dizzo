from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import JSON, BigInteger, Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.branch import Branch
    from app.models.commerce import Cart


class User(TimestampMixin, Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str | None] = mapped_column(String(320), unique=True, nullable=True, index=True)
    password_hash: Mapped[str | None] = mapped_column(Text, nullable=True)
    first_name: Mapped[str] = mapped_column(String(150), default="")
    last_name: Mapped[str] = mapped_column(String(150), default="")
    phone_number: Mapped[str] = mapped_column(String(32), default="")
    avatar: Mapped[str | None] = mapped_column(Text, nullable=True)
    role: Mapped[str] = mapped_column(String(32), default="customer", index=True)
    # BigInteger, not Integer — Telegram's newer numeric user ids exceed the
    # 32-bit signed range (e.g. 5050150433), which used to blow up any query
    # touching this column with a Postgres "value out of int32 range" error.
    telegram_id: Mapped[int | None] = mapped_column(BigInteger, unique=True, nullable=True, index=True)
    # When telegram_id was last (re)linked — surfaced on "Mening markazim" so
    # staff can see the connection isn't stale, not just that it exists.
    telegram_linked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    is_staff: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    # In every token; bumped to revoke them all (app/core/security.py).
    # "uz" | "ru" | "en": the site, the app and Telegram messages speak it.
    language: Mapped[str] = mapped_column(String(8), default="uz", server_default="uz")
    token_version: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    branch_id: Mapped[int | None] = mapped_column(ForeignKey("branches.id", ondelete="SET NULL"), nullable=True, index=True)

    branch: Mapped[Branch | None] = relationship(lazy="selectin")
    social_connections: Mapped[list[SocialConnection]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    cart: Mapped[Cart | None] = relationship(back_populates="customer", uselist=False, cascade="all, delete-orphan")

    @property
    def full_name(self) -> str:
        return " ".join(part for part in (self.first_name, self.last_name) if part).strip() or self.email or f"user-{self.id}"


class RefreshSession(Base):
    """One refresh token (by its jti). Refreshing spends it and names the
    successor; a spent token presented again after the grace period is a
    replayed (stolen) token and logs the user out everywhere. Revoking
    deletes the user's rows (and bumps users.token_version)."""

    __tablename__ = "refresh_sessions"

    jti: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    rotated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    replaced_by: Mapped[str | None] = mapped_column(String(64), nullable=True)


class SocialConnection(TimestampMixin, Base):
    __tablename__ = "social_connections"
    __table_args__ = (UniqueConstraint("provider", "provider_id", name="uq_social_provider_id"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    provider: Mapped[str] = mapped_column(String(32), index=True)
    provider_id: Mapped[str] = mapped_column(String(255), index=True)
    provider_username: Mapped[str] = mapped_column(String(255), default="")
    extra_data: Mapped[dict] = mapped_column(JSON, default=dict)
    user: Mapped[User] = relationship(back_populates="social_connections")


class TelegramLinkToken(TimestampMixin, Base):
    """A short-lived, single-use code a logged-in admin/staff user requests
    from the "Mening markazim" page and opens as a t.me deep link
    (`?start=link_<token>`) — the bot reads the payload and calls back to
    consume it, linking that Telegram account (its numeric id doubles as
    the private-chat id for sendMessage) to the requesting user without
    ever exposing a password or session to the bot."""

    __tablename__ = "telegram_link_tokens"

    id: Mapped[int] = mapped_column(primary_key=True)
    token: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class TelegramAppLogin(TimestampMixin, Base):
    """Telegram sign-in for the mobile app, which has no Telegram SDK: the
    app requests a code and opens t.me/<bot>?start=login_<token>; the bot
    asks that Telegram user to confirm or cancel it. The app polls the code
    and collects a token pair once (used_at), within the TTL."""

    __tablename__ = "telegram_app_logins"

    id: Mapped[int] = mapped_column(primary_key=True)
    token: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    requester_ip: Mapped[str] = mapped_column(String(64), default="", index=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
