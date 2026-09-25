"""The admin "Boshqaruv paneli": one read-only summary of the shop for a
period (the last N days, in Tashkent time) next to the same-length period
before it, so every figure can show which way it moved.

Revenue counts orders from "paid" onwards (as /orders/analytics/ does); an
order that was placed and later cancelled still counts as placed, and shows
up as cancelled in the status breakdown. The cart is emptied at checkout, so
there is no cart→order history to measure: conversion here is "customers who
saved a design in the period and also ordered in it".
"""

from datetime import UTC, date, datetime, time, timedelta, timezone
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import BRANCH_LEAD_ROLES, BRANCH_STAFF_ROLES, get_current_user, require_roles
from app.core.i18n import _
from app.db.session import get_db
from app.models.branch import Branch, BranchProduct
from app.models.commerce import CartItem, Design, Order
from app.models.review import Review
from app.models.user import User
from app.services.orders import STATUS_LABELS, status_label

router = APIRouter(prefix="/admin/dashboard", tags=["dashboard"])

SHOP_TZ = timezone(timedelta(hours=5))  # Asia/Tashkent, no DST

PAID_STATUSES = frozenset({
    "PAID", "READY_FOR_PRODUCTION", "IN_PRODUCTION", "QUALITY_CHECK",
    "READY_FOR_PICKUP", "READY_FOR_DELIVERY", "COMPLETED",
})
OPEN_STATUSES = tuple(s for s in STATUS_LABELS if s not in ("COMPLETED", "CANCELLED"))
DELIVERY_LABELS = {"DELIVERY": "Yetkazib berish", "PICKUP": "Olib ketish"}
TOP_N = 5


def _local_day(moment: datetime) -> date:
    aware = moment if moment.tzinfo else moment.replace(tzinfo=UTC)
    return aware.astimezone(SHOP_TZ).date()


def _pair(current: int | Decimal, previous: int | Decimal) -> dict:
    as_json = (lambda v: str(v)) if isinstance(current, Decimal) else (lambda v: v)
    return {"current": as_json(current), "previous": as_json(previous)}


def _period_figures(orders: list[Order]) -> dict:
    placed = len(orders)
    paid = [o for o in orders if o.status in PAID_STATUSES]
    revenue = sum((o.total_amount or Decimal("0") for o in paid), Decimal("0"))
    return {
        "orders": placed,
        "paid_orders": len(paid),
        "revenue": revenue,
        "avg_order": (revenue / len(paid)).quantize(Decimal("1")) if paid else Decimal("0"),
        "items_sold": sum(i.quantity for o in orders if o.status != "CANCELLED" for i in o.items),
        "cancelled": sum(o.status == "CANCELLED" for o in orders),
    }


def _top(rows: dict[tuple, dict]) -> list[dict]:
    ranked = sorted(rows.values(), key=lambda r: (r["units_sold"], r["revenue"]), reverse=True)[:TOP_N]
    return [{**r, "revenue": str(r["revenue"])} for r in ranked]


LEAD_SUMMARY = ("orders", "paid_orders", "revenue", "avg_order", "items_sold", "cancelled")


def _scope_for(user: User) -> tuple[str, int | None]:
    if user.role in BRANCH_LEAD_ROLES:
        if not user.branch_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=_("Filial biriktirilmagan"))
        return "branch_lead", user.branch_id
    return "shop", None


@router.get("/")
async def admin_dashboard(
    days: int = Query(14, ge=1, le=90),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    require_roles(user, "super_admin", "admin", "production_admin", "production_manager", *BRANCH_LEAD_ROLES)
    view, branch_id = _scope_for(user)
    today = datetime.now(SHOP_TZ).date()
    start_day = today - timedelta(days=days - 1)
    prev_start_day = start_day - timedelta(days=days)
    cutoff = datetime.combine(prev_start_day, time.min, SHOP_TZ).astimezone(UTC)

    def period_of(moment: datetime | None) -> str | None:
        if moment is None:
            return None
        day = _local_day(moment)
        if start_day <= day <= today:
            return "current"
        if prev_start_day <= day < start_day:
            return "previous"
        return None

    orders_q = select(Order).options(selectinload(Order.items)).where(Order.created_at >= cutoff)
    open_q = select(Order.status, func.count(Order.id)).where(Order.status.in_(OPEN_STATUSES))
    if branch_id is not None:
        orders_q = orders_q.where(Order.branch_id == branch_id)
        open_q = open_q.where(Order.branch_id == branch_id)
    orders = (await session.execute(orders_q)).scalars().unique().all()

    current_orders = [o for o in orders if period_of(o.created_at) == "current"]
    previous_orders = [o for o in orders if period_of(o.created_at) == "previous"]
    now_figures, before_figures = _period_figures(current_orders), _period_figures(previous_orders)

    by_day = {
        (start_day + timedelta(days=i)).isoformat(): {"orders": 0, "revenue": Decimal("0"), "new_customers": 0, "designs": 0}
        for i in range(days)
    }
    for o in current_orders:
        row = by_day[_local_day(o.created_at).isoformat()]
        row["orders"] += 1
        if o.status in PAID_STATUSES:
            row["revenue"] += o.total_amount or Decimal("0")

    status_counts = dict.fromkeys(STATUS_LABELS, 0)
    delivery_counts = dict.fromkeys(DELIVERY_LABELS, 0)
    products: dict[tuple, dict] = {}
    variants: dict[tuple, dict] = {}
    for o in current_orders:
        status_counts[o.status] = status_counts.get(o.status, 0) + 1
        method = o.delivery_method or "DELIVERY"
        delivery_counts[method] = delivery_counts.get(method, 0) + 1
        if o.status == "CANCELLED":
            continue
        for item in o.items:
            line_total = (item.unit_price or Decimal("0")) * item.quantity
            p = products.setdefault(
                (item.product_slug or item.product_name,),
                {"product_name": item.product_name, "product_slug": item.product_slug, "units_sold": 0,
                 "revenue": Decimal("0"), "orders": 0},
            )
            p["units_sold"] += item.quantity
            p["revenue"] += line_total
            p["orders"] += 1
            v = variants.setdefault(
                (item.product_slug or item.product_name, item.variant_name),
                {"product_name": item.product_name, "variant_name": item.variant_name, "units_sold": 0,
                 "revenue": Decimal("0")},
            )
            v["units_sold"] += item.quantity
            v["revenue"] += line_total

    pipeline_rows = dict((await session.execute(open_q.group_by(Order.status))).all())
    pickup_ready = int(pipeline_rows.get("READY_FOR_PICKUP", 0))

    branch_name = None
    workers = unavailable = 0
    if branch_id is not None:
        branch = await session.get(Branch, branch_id)
        branch_name = branch.name if branch else None
        workers = int(await session.scalar(
            select(func.count(User.id)).where(
                User.branch_id == branch_id,
                User.is_active.is_(True),
                User.role.in_(BRANCH_STAFF_ROLES),
            )
        ) or 0)
        unavailable = int(await session.scalar(
            select(func.count(BranchProduct.id)).where(
                BranchProduct.branch_id == branch_id, BranchProduct.is_available.is_(False)
            )
        ) or 0)

    summary = {
        "orders": _pair(now_figures["orders"], before_figures["orders"]),
        "paid_orders": _pair(now_figures["paid_orders"], before_figures["paid_orders"]),
        "revenue": _pair(now_figures["revenue"], before_figures["revenue"]),
        "avg_order": _pair(now_figures["avg_order"], before_figures["avg_order"]),
        "items_sold": _pair(now_figures["items_sold"], before_figures["items_sold"]),
        "cancelled": _pair(now_figures["cancelled"], before_figures["cancelled"]),
    }

    payload = {
        "days": days,
        "start": start_day.isoformat(),
        "end": today.isoformat(),
        "scope": (
            {"kind": "shop"}
            if view == "shop"
            else {"kind": "branch", "role": view, "branch_id": branch_id, "branch_name": branch_name}
        ),
        "pipeline": [
            {"status": s, "label": status_label(s), "count": int(pipeline_rows.get(s, 0))} for s in OPEN_STATUSES
        ],
        "by_day": [
            {"date": d, "orders": r["orders"], "revenue": str(r["revenue"]), "new_customers": r["new_customers"],
             "designs": r["designs"]}
            for d, r in by_day.items()
        ],
        "orders_by_status": [
            {"status": s, "label": status_label(s), "count": c} for s, c in status_counts.items()
        ],
        "pickup_ready": pickup_ready,
    }

    if view == "shop":
        customers = (
            await session.execute(select(User.created_at).where(User.role == "customer", User.created_at >= cutoff))
        ).scalars().all()
        designs = (
            await session.execute(select(Design.created_at, Design.owner_id).where(Design.created_at >= cutoff))
        ).all()
        new_customers = {"current": 0, "previous": 0}
        for created_at in customers:
            if (p := period_of(created_at)) is not None:
                new_customers[p] += 1
        design_counts = {"current": 0, "previous": 0}
        designers: set[int] = set()
        for created_at, owner_id in designs:
            if (p := period_of(created_at)) is not None:
                design_counts[p] += 1
                if p == "current":
                    designers.add(owner_id)
        buyers = {o.customer_id for o in current_orders if o.status != "CANCELLED"}
        for created_at in customers:
            if period_of(created_at) == "current":
                by_day[_local_day(created_at).isoformat()]["new_customers"] += 1
        for created_at, _owner in designs:
            if period_of(created_at) == "current":
                by_day[_local_day(created_at).isoformat()]["designs"] += 1
        payload["by_day"] = [
            {"date": d, "orders": r["orders"], "revenue": str(r["revenue"]), "new_customers": r["new_customers"],
             "designs": r["designs"]}
            for d, r in by_day.items()
        ]
        summary["new_customers"] = _pair(new_customers["current"], new_customers["previous"])
        summary["designs"] = _pair(design_counts["current"], design_counts["previous"])
        payload["summary"] = summary
        payload["conversion"] = {"designers": len(designers), "buyers": len(designers & buyers)}
        reviews_pending = await session.scalar(select(func.count(Review.id)).where(Review.status == "pending")) or 0
        cart_row = (await session.execute(
            select(
                func.count(func.distinct(CartItem.cart_id)),
                func.coalesce(func.sum(CartItem.quantity), 0),
                func.coalesce(func.sum(CartItem.unit_price * CartItem.quantity), 0),
            )
        )).one()
        payload["open_carts"] = {
            "carts": int(cart_row[0] or 0),
            "items": int(cart_row[1] or 0),
            "value": str(Decimal(str(cart_row[2] or 0)).quantize(Decimal("0.01"))),
        }
        payload["reviews_pending"] = int(reviews_pending)
        payload["orders_by_delivery_method"] = [
            {"method": m, "label": DELIVERY_LABELS.get(m, m), "count": c} for m, c in delivery_counts.items()
        ]
        payload["top_products"] = _top(products)
        payload["top_variants"] = _top(variants)
        return payload

    payload["summary"] = {k: summary[k] for k in LEAD_SUMMARY}
    payload["branch"] = {"workers": workers, "unavailable_products": unavailable}
    payload["orders_by_delivery_method"] = [
        {"method": m, "label": DELIVERY_LABELS.get(m, m), "count": c} for m, c in delivery_counts.items()
    ]
    payload["top_products"] = _top(products)
    payload["top_variants"] = _top(variants)
    return payload
