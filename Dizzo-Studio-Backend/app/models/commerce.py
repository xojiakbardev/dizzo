"""Designs, the cart and orders.

A Design is the customer's editable work in the Studio. Adding it to the
cart freezes a *package*: the design document, the print files (checked
and measured by the backend), mockup frames and the price breakdown. The
design stays editable; the cart item does not change with it. Checkout
copies every package file under orders/, so an order never depends on
anything the customer or the admin changes later.
"""

from __future__ import annotations

import uuid
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import JSON, ForeignKey, Index, Integer, Numeric, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, TranslatableMixin
from app.models.catalog import Product, Variant, VariantColor
from app.models.media import Media

if TYPE_CHECKING:
    from app.models.branch import Branch
    from app.models.user import User


def new_uuid() -> str:
    return str(uuid.uuid4())


class Design(TimestampMixin, Base):
    __tablename__ = "designs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_uuid)
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id", ondelete="RESTRICT"), index=True)
    variant_id: Mapped[int] = mapped_column(ForeignKey("variants.id", ondelete="RESTRICT"))
    color_id: Mapped[int] = mapped_column(ForeignKey("variant_colors.id", ondelete="RESTRICT"))
    document: Mapped[dict] = mapped_column(JSON, default=dict)  # app.schemas.design.DesignDocument
    # Bumped on every save; a save based on an older version is refused so
    # two open tabs can't silently overwrite each other.
    version: Mapped[int] = mapped_column(Integer, default=1)
    areas_cm2: Mapped[dict] = mapped_column(JSON, default=dict)  # painted area per method, measured by the editor
    preview_media_id: Mapped[str | None] = mapped_column(ForeignKey("media.id", ondelete="SET NULL"), nullable=True)
    # Storage keys of the Studio's five views ("Dizaynlarim"), first one first.
    previews: Mapped[list] = mapped_column(JSON, default=list, server_default="[]")

    product: Mapped[Product] = relationship(lazy="selectin")
    variant: Mapped[Variant] = relationship(lazy="selectin")
    color: Mapped[VariantColor] = relationship(lazy="selectin")
    preview: Mapped[Media | None] = relationship(lazy="selectin")


class Cart(TimestampMixin, Base):
    __tablename__ = "carts"
    id: Mapped[int] = mapped_column(primary_key=True)
    uuid: Mapped[str] = mapped_column(String(36), unique=True, default=new_uuid)
    customer_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    customer: Mapped[User] = relationship(back_populates="cart")
    items: Mapped[list[CartItem]] = relationship(
        back_populates="cart", cascade="all, delete-orphan", order_by="CartItem.id", lazy="selectin"
    )


class CartItem(TimestampMixin, Base):
    __tablename__ = "cart_items"
    id: Mapped[int] = mapped_column(primary_key=True)
    uuid: Mapped[str] = mapped_column(String(36), unique=True, default=new_uuid)
    cart_id: Mapped[int] = mapped_column(ForeignKey("carts.id", ondelete="CASCADE"), index=True)
    design_id: Mapped[str | None] = mapped_column(ForeignKey("designs.id", ondelete="SET NULL"), nullable=True)
    variant_id: Mapped[int] = mapped_column(ForeignKey("variants.id", ondelete="RESTRICT"))
    color_id: Mapped[int] = mapped_column(ForeignKey("variant_colors.id", ondelete="RESTRICT"))
    # The size the customer picked ("M"), as the variant spells it; empty on
    # products that have no sizes.
    size: Mapped[str] = mapped_column(String(20), default="", server_default="")
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    unit_price: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    # Frozen when added: document, files, mockups, placements, quote and
    # the product/variant/colour names (see app.services.packages).
    package: Mapped[dict] = mapped_column(JSON, default=dict)

    cart: Mapped[Cart] = relationship(back_populates="items")
    variant: Mapped[Variant] = relationship(lazy="selectin")
    color: Mapped[VariantColor] = relationship(lazy="selectin")


class Order(TimestampMixin, Base):
    __tablename__ = "orders"
    __table_args__ = (
        # One order per checkout attempt: the client's Idempotency-Key.
        UniqueConstraint("customer_id", "idempotency_key"),
        Index("ix_orders_created_at", "created_at"),
    )
    id: Mapped[int] = mapped_column(primary_key=True)
    order_number: Mapped[str] = mapped_column(String(32), unique=True)
    customer_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    idempotency_key: Mapped[str | None] = mapped_column(String(64), nullable=True)
    status: Mapped[str] = mapped_column(String(32), default="NEW", index=True)
    delivery_method: Mapped[str] = mapped_column(String(16), default="DELIVERY")
    subtotal: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0)
    tax_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0)
    shipping_cost: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0)
    discount_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0)
    total_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0)
    # Delivery pin dropped on the checkout map.
    latitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6), nullable=True)
    longitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6), nullable=True)
    shipping_name: Mapped[str] = mapped_column(String(200), default="")
    shipping_email: Mapped[str] = mapped_column(String(320), default="")
    shipping_phone: Mapped[str] = mapped_column(String(32), default="")
    shipping_address: Mapped[str] = mapped_column(Text, default="")
    shipping_city: Mapped[str] = mapped_column(String(120), default="")
    shipping_state: Mapped[str] = mapped_column(String(120), default="")
    shipping_postal_code: Mapped[str] = mapped_column(String(32), default="")
    shipping_country: Mapped[str] = mapped_column(String(120), default="")
    customer_notes: Mapped[str] = mapped_column(Text, default="")
    admin_notes: Mapped[str] = mapped_column(Text, default="")
    tracking_number: Mapped[str] = mapped_column(String(120), default="")
    carrier: Mapped[str] = mapped_column(String(120), default="")
    branch_id: Mapped[int | None] = mapped_column(ForeignKey("branches.id", ondelete="SET NULL"), nullable=True, index=True)
    branch: Mapped[Branch | None] = relationship(lazy="selectin")
    customer: Mapped[User] = relationship()
    items: Mapped[list[OrderItem]] = relationship(back_populates="order", cascade="all, delete-orphan")
    payments: Mapped[list["Payment"]] = relationship(back_populates="order", cascade="all, delete-orphan", lazy="selectin")


class OrderItem(TimestampMixin, TranslatableMixin, Base):
    __tablename__ = "order_items"
    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id", ondelete="CASCADE"), index=True)
    # Snapshots, not foreign keys to the catalog: an order line keeps
    # showing what was bought even after the catalog changes.
    product_name: Mapped[str] = mapped_column(String(200))
    product_slug: Mapped[str] = mapped_column(String(120), default="")
    variant_name: Mapped[str] = mapped_column(String(150), default="")
    color_name: Mapped[str] = mapped_column(String(100), default="")
    color_hex: Mapped[str] = mapped_column(String(7), default="")
    size: Mapped[str] = mapped_column(String(20), default="", server_default="")
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    unit_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0)
    production_status: Mapped[str] = mapped_column(String(32), default="PENDING")
    # The cart package with every file copied under orders/<order number>/,
    # plus the white underbase masks when the variant needs them.
    package: Mapped[dict] = mapped_column(JSON, default=dict)
    order: Mapped[Order] = relationship(back_populates="items")


class Payment(TimestampMixin, Base):
    __tablename__ = "payments"
    __table_args__ = (
        Index("ix_payments_provider_trans", "provider", "provider_trans_id"),
        Index("ix_payments_created_at", "created_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id", ondelete="CASCADE"), index=True)
    provider: Mapped[str] = mapped_column(String(32), default="CLICK")  # CLICK, PAYME
    provider_trans_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    provider_paydoc_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0)
    status: Mapped[str] = mapped_column(String(32), default="PENDING", index=True)  # PENDING, PAID, CANCELLED, FAILED
    meta: Mapped[dict] = mapped_column(JSON, default=dict)

    order: Mapped[Order] = relationship(back_populates="payments")
