"""Branch schemas for client and staff portals."""

from __future__ import annotations

from datetime import datetime
from typing import Literal, get_args

from pydantic import BaseModel, Field

from app.schemas.catalog import Strict

# The only roles a branch roster may hand out. A global role (moderator,
# admin, super_admin) is granted from /users/admin/{id}/role/ by a
# super_admin and never from here.
BranchWorkerRole = Literal["branch_worker", "branch_manager", "branch_admin"]
ASSIGNABLE_BRANCH_ROLES: frozenset[str] = frozenset(get_args(BranchWorkerRole))


class BranchBase(Strict):
    name: str = Field(min_length=1, max_length=120)
    slug: str = Field(min_length=1, max_length=120)
    phone: str | None = Field(default=None, max_length=32)
    address: str = Field(min_length=1, max_length=255)
    city: str = Field(default="Toshkent", max_length=80)
    latitude: float
    longitude: float
    work_hours: str = Field(default="09:00 - 20:00", max_length=120)
    is_active: bool = True
    notes: str | None = None
    branch_type: str = Field(default="BTS", max_length=32)
    daily_order_capacity: int = Field(default=20, ge=1)
    delivery_days: int = Field(default=3, ge=1)
    base_shipping_cost: float = Field(default=35000.0, ge=0)


class BranchCreate(BranchBase):
    pass


class BranchUpdate(Strict):
    name: str | None = Field(default=None, max_length=120)
    slug: str | None = Field(default=None, max_length=120)
    phone: str | None = Field(default=None, max_length=32)
    address: str | None = Field(default=None, max_length=255)
    city: str | None = Field(default=None, max_length=80)
    latitude: float | None = None
    longitude: float | None = None
    work_hours: str | None = Field(default=None, max_length=120)
    is_active: bool | None = None
    notes: str | None = None
    branch_type: str | None = Field(default=None, max_length=32)
    daily_order_capacity: int | None = Field(default=None, ge=1)
    delivery_days: int | None = Field(default=None, ge=1)
    base_shipping_cost: float | None = Field(default=None, ge=0)


class BranchOut(BranchBase):
    id: int
    created_at: datetime
    updated_at: datetime
    unavailable_product_ids: list[int] = []
    estimated_delivery_days: str | None = None
    current_pending_orders: int | None = None


class BranchProductAvailabilityIn(Strict):
    is_available: bool
    reason: str | None = Field(default=None, max_length=255)


class BranchProductOut(BaseModel):
    product_id: int
    product_name: str
    product_slug: str
    category_name: str | None = None
    image_url: str | None = None
    base_price: float = 0
    is_available: bool = True
    reason: str | None = None


class BranchWorkerAssignIn(Strict):
    user_id: int
    role: BranchWorkerRole = "branch_worker"


class BranchWorkerOut(BaseModel):
    id: int
    full_name: str
    phone_number: str
    email: str | None
    role: str
    branch_id: int | None
