"""BTS Pochta delivery calculation service.

Supports Uzbekistan-wide shipping.
Calculates dynamic estimated delivery turnaround based on branch queue load
and admin-configured daily order capacity parameters.
"""

from __future__ import annotations

import math
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.models.branch import Branch
from app.models.commerce import Order


class BTSDeliveryService:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    async def calculate_quote(
        self,
        session: AsyncSession,
        city: str = "",
        branch_id: int | None = None,
        dest_lat: float | None = None,
        dest_lon: float | None = None,
    ) -> dict[str, Any]:
        """Calculates dynamic BTS delivery quote and estimated days."""
        branch: Branch | None = None
        if branch_id:
            branch = await session.get(Branch, branch_id)

        # If no specific branch given, try to find matching branch by city
        if not branch and city:
            q = select(Branch).where(
                Branch.is_active.is_(True),
                func.lower(Branch.city).contains(city.strip().lower()),
            )
            branch = (await session.execute(q)).scalars().first()

        # Fallback to any active BTS branch or first branch
        if not branch:
            q = select(Branch).where(Branch.is_active.is_(True))
            branch = (await session.execute(q)).scalars().first()

        # Dynamic capacity & queue-based calculation
        daily_capacity = getattr(branch, "daily_order_capacity", 20) if branch else 20
        delivery_days = getattr(branch, "delivery_days", 3) if branch else 3
        base_cost = float(getattr(branch, "base_shipping_cost", self.settings.bts_delivery_default_cost) if branch else self.settings.bts_delivery_default_cost)

        # Count pending orders currently queued for this branch
        pending_orders = 0
        if branch:
            pending_query = select(func.count(Order.id)).where(
                Order.branch_id == branch.id,
                Order.status.notin_(["COMPLETED", "CANCELLED"]),
            )
            pending_orders = (await session.execute(pending_query)).scalar_one_or_none() or 0

        # Dynamic delay based on current backlog / queue
        added_queue_days = math.ceil(pending_orders / max(daily_capacity, 1)) if pending_orders > 0 else 0
        min_days = delivery_days + max(0, added_queue_days - 1)
        max_days = delivery_days + added_queue_days

        if min_days == max_days:
            estimated_str = f"{min_days} kun"
        else:
            estimated_str = f"{min_days}–{max_days} kun"

        # If no branch is found at all, fall back to backend configuration default
        if not branch:
            estimated_str = self.settings.delivery_estimated_days_bts

        return {
            "provider": "BTS",
            "available": True,
            "price": base_cost,
            "formatted_price": f"{int(base_cost):,} so'm".replace(",", " "),
            "estimated_days": estimated_str,
            "currency": "UZS",
            "branch_id": branch.id if branch else None,
            "branch_name": branch.name if branch else None,
            "current_pending_orders": pending_orders,
            "daily_capacity": daily_capacity,
            "source": "bts_branch_capacity",
        }
