"""Branch and multi-location inventory models."""

from __future__ import annotations

from sqlalchemy import Boolean, Float, ForeignKey, Integer, String, Text, UniqueConstraint, true
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin


class Branch(TimestampMixin, Base):
    """Physical branch / pickup location."""

    __tablename__ = "branches"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120), index=True)
    slug: Mapped[str] = mapped_column(String(120), unique=True, index=True)
    phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    address: Mapped[str] = mapped_column(String(255))
    city: Mapped[str] = mapped_column(String(80), default="Toshkent", index=True)
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)
    work_hours: Mapped[str] = mapped_column(String(120), default="09:00 - 20:00")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default=true(), index=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Dynamic BTS branch capacity & delivery parameters (admin-configurable)
    branch_type: Mapped[str] = mapped_column(String(32), default="BTS", server_default="BTS")
    daily_order_capacity: Mapped[int] = mapped_column(Integer, default=20, server_default="20")
    delivery_days: Mapped[int] = mapped_column(Integer, default=3, server_default="3")
    base_shipping_cost: Mapped[float] = mapped_column(Float, default=35000.0, server_default="35000")

    products_availability: Mapped[list[BranchProduct]] = relationship(
        back_populates="branch", cascade="all, delete-orphan", lazy="selectin"
    )


class BranchProduct(Base):
    """Product availability state at a specific branch (out of stock, machine broken, etc.)."""

    __tablename__ = "branch_products"
    __table_args__ = (
        UniqueConstraint("branch_id", "product_id", name="uq_branch_product"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    branch_id: Mapped[int] = mapped_column(ForeignKey("branches.id", ondelete="CASCADE"), index=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"), index=True)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True, server_default=true(), index=True)
    reason: Mapped[str | None] = mapped_column(String(255), nullable=True)

    branch: Mapped[Branch] = relationship(back_populates="products_availability")
