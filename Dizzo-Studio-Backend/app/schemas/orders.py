from __future__ import annotations

from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.services.orders import OrderStatus


class CheckoutRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    contact_name: str = Field(min_length=1, max_length=200)
    # Optional: Telegram-login accounts have no email, and the checkout form
    # only asks for name + phone.
    contact_email: str = Field(default="", max_length=320)
    contact_phone: str = Field(default="", max_length=32)
    delivery_method: str = Field(default="DELIVERY", pattern=r"^(DELIVERY|PICKUP)$")
    branch_id: int | None = None
    latitude: Decimal | None = None
    longitude: Decimal | None = None
    shipping_address: str = Field(default="", max_length=500)
    shipping_city: str = Field(default="", max_length=120)
    shipping_state: str = Field(default="", max_length=120)
    shipping_postal_code: str = Field(default="", max_length=32)
    shipping_country: str = Field(default="", max_length=120)
    carrier: str = Field(default="", max_length=120)
    shipping_cost: Decimal = Field(default=Decimal("0"), ge=0)
    customer_notes: str = Field(default="", max_length=2000)


class AdminOrderUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    status: OrderStatus | None = None
    branch_id: int | None = None
    admin_notes: str | None = Field(default=None, max_length=5000)
    tracking_number: str | None = Field(default=None, max_length=120)
    carrier: str | None = Field(default=None, max_length=120)


class OrderStatusUpdate(BaseModel):
    """POST /orders/{id}/status: the one status to move the order to."""

    status: OrderStatus


class AdminOrderItemUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    production_status: Literal["PENDING", "PRINTING", "PRINTED", "PACKED"]


__all__ = ["CheckoutRequest", "AdminOrderUpdate", "AdminOrderItemUpdate", "OrderStatusUpdate"]
