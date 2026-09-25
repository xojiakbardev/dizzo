from datetime import UTC, date, datetime, time, timedelta, timezone
from decimal import Decimal
import logging

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from sqlalchemy import case, false, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

logger = logging.getLogger(__name__)

from app.api.deps import (
    ALL_STAFF_ROLES,
    BRANCH_STAFF_ROLES,
    GLOBAL_STAFF_ROLES,
    get_current_user,
    require_roles,
)
from app.core.i18n import translate
from app.db.session import get_db
from app.models.commerce import Order
from app.models.user import User
from app.schemas.orders import AdminOrderItemUpdate, AdminOrderUpdate, OrderStatusUpdate
from app.services.orders import (
    STATUS_LABELS,
    check_transition,
    get_order,
    order_detail_payload,
    order_summary_payload,
    status_label,
)
from app.services.storage import R2Storage, get_storage
from app.services.telegram_notify import customer_status_messages, send_messages

# Analytics count days as the shop does: Asia/Tashkent (UTC+5, no DST).
SHOP_TZ = timezone(timedelta(hours=5))
PAID_STATUSES = (
    "PAID", "READY_FOR_PRODUCTION", "IN_PRODUCTION", "QUALITY_CHECK", "READY_FOR_PICKUP", "READY_FOR_DELIVERY",
    "COMPLETED",
)
STAFF_ROLES = tuple(ALL_STAFF_ROLES)

router = APIRouter(prefix="/orders", tags=["orders"])


def require_center_staff(user: User) -> None:
    require_roles(user, *ALL_STAFF_ROLES)


def check_order_access(order: Order, user: User) -> None:
    """Global staff see every order; branch staff only their own branch's
    (an order with no branch belongs to no branch worker); everyone else
    only their own. `is_staff` is deliberately not consulted: it is True for
    every staff account and used to make the branch check unreachable."""
    if user.role in GLOBAL_STAFF_ROLES:
        return
    if user.role in BRANCH_STAFF_ROLES:
        if user.branch_id is None or order.branch_id is None or order.branch_id != user.branch_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Siz faqat o'z filialingiz buyurtmalarini ko'ra olasiz",
            )
        return
    if order.customer_id != user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Ruxsat yo'q")



@router.get("/")
async def list_orders(user: User = Depends(get_current_user), session: AsyncSession = Depends(get_db)):
    orders = (
        (
            await session.execute(
                select(Order)
                .options(selectinload(Order.items))
                .where(Order.customer_id == user.id)
                .order_by(Order.created_at.desc())
            )
        )
        .scalars()
        .unique()
        .all()
    )
    return {"count": len(orders), "next": None, "previous": None, "results": [order_summary_payload(o, user) for o in orders]}


@router.get("/stats/")
async def order_stats(user: User = Depends(get_current_user), session: AsyncSession = Depends(get_db)):
    def count_where(condition):
        return func.coalesce(func.sum(case((condition, 1), else_=0)), 0)

    def total_where(condition):
        return func.coalesce(func.sum(case((condition, Order.total_amount), else_=0)), 0)

    query = select(
        func.count(Order.id),
        count_where(Order.status == "NEW"),
        count_where(Order.status == "PAYMENT_PENDING"),
        count_where(Order.status == "PAID"),
        count_where(Order.status.in_(["READY_FOR_PRODUCTION", "IN_PRODUCTION", "QUALITY_CHECK"])),
        count_where(Order.status == "COMPLETED"),
        total_where(Order.status == "COMPLETED"),
        total_where(Order.status.not_in(["CANCELLED", "NEW"])),
    )
    if user.role not in STAFF_ROLES:
        query = query.where(Order.customer_id == user.id)
    elif user.role in BRANCH_STAFF_ROLES:
        # A branch account counts its own branch, never the whole shop.
        query = query.where(Order.branch_id == user.branch_id if user.branch_id else false())
    row = (await session.execute(query)).one()

    def money(value) -> str:
        return str(Decimal(str(value or 0)).quantize(Decimal("0.01")))

    return {
        "total_orders": int(row[0]),
        "new_orders": int(row[1]),
        "payment_pending_orders": int(row[2]),
        "paid_orders": int(row[3]),
        "in_production_orders": int(row[4]),
        "done_orders": int(row[5]),
        "total_spent": money(row[6]),
        "total_revenue": money(row[7]),
    }


def shop_day(moment: datetime) -> date:
    aware = moment if moment.tzinfo else moment.replace(tzinfo=UTC)
    return aware.astimezone(SHOP_TZ).date()


@router.get("/analytics/")
async def order_analytics(
    days: int = Query(14, ge=1, le=366),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    require_center_staff(user)
    # The last `days` Tashkent calendar days, today included.
    today = datetime.now(SHOP_TZ).date()
    first_day = today - timedelta(days=days - 1)
    cutoff = datetime.combine(first_day, time.min, SHOP_TZ).astimezone(UTC)
    query = select(Order).options(selectinload(Order.items)).where(Order.created_at >= cutoff)
    orders = (await session.execute(query)).scalars().unique().all()

    revenue_dict = {
        (first_day + timedelta(days=i)).isoformat(): {"orders": 0, "revenue": Decimal("0")} for i in range(days)
    }

    for o in orders:
        if o.created_at:
            d_str = shop_day(o.created_at).isoformat()
            if d_str in revenue_dict:
                revenue_dict[d_str]["orders"] += 1
                if o.status in PAID_STATUSES:
                    revenue_dict[d_str]["revenue"] += (o.total_amount or Decimal("0"))

    revenue_by_day = [
        {"date": d, "orders": val["orders"], "revenue": str(val["revenue"])}
        for d, val in revenue_dict.items()
    ]

    status_counts = {s_key: {"status": s_key, "label": status_label(s_key), "count": 0} for s_key in STATUS_LABELS}
    for o in orders:
        if o.status in status_counts:
            status_counts[o.status]["count"] += 1

    delivery_counts = {
        "DELIVERY": {"method": "DELIVERY", "label": "Yetkazib berish", "count": 0},
        "PICKUP": {"method": "PICKUP", "label": "Olib ketish", "count": 0},
    }
    for o in orders:
        m = o.delivery_method or "DELIVERY"
        if m in delivery_counts:
            delivery_counts[m]["count"] += 1

    product_stats = {}
    for o in orders:
        for item in o.items:
            p_name = item.product_name or translate("Mahsulot")
            if p_name not in product_stats:
                product_stats[p_name] = {"product_name": p_name, "units_sold": 0, "revenue": Decimal("0")}
            product_stats[p_name]["units_sold"] += item.quantity
            product_stats[p_name]["revenue"] += item.unit_price * item.quantity

    top_products = [
        {"product_name": p["product_name"], "units_sold": p["units_sold"], "revenue": str(p["revenue"])}
        for p in sorted(product_stats.values(), key=lambda x: x["units_sold"], reverse=True)[:5]
    ]

    return {
        "revenue_by_day": revenue_by_day,
        "orders_by_status": list(status_counts.values()),
        "orders_by_delivery_method": list(delivery_counts.values()),
        "top_products": top_products,
    }


@router.get("/admin/orders/")
async def admin_list_orders(
    status: str | None = None,
    status_filter: str | None = None,
    delivery_method: str | None = None,
    branch_id: int | None = None,
    search: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    require_center_staff(user)
    effective_status = status_filter or status
    query = select(Order).options(
        selectinload(Order.items), selectinload(Order.customer), selectinload(Order.branch)
    )
    count_query = select(func.count()).select_from(Order)

    # Scoping by branch for branch workers / managers
    if user.role in BRANCH_STAFF_ROLES:
        query = query.where(Order.branch_id == user.branch_id)
        count_query = count_query.where(Order.branch_id == user.branch_id)
    elif branch_id:
        query = query.where(Order.branch_id == branch_id)
        count_query = count_query.where(Order.branch_id == branch_id)

    if effective_status and effective_status != "ALL":
        query = query.where(Order.status == effective_status)
        count_query = count_query.where(Order.status == effective_status)
    if delivery_method and delivery_method != "ALL":
        query = query.where(Order.delivery_method == delivery_method)
        count_query = count_query.where(Order.delivery_method == delivery_method)
    if search:
        query = query.where(Order.order_number.ilike(f"%{search}%"))
        count_query = count_query.where(Order.order_number.ilike(f"%{search}%"))
    query = query.order_by(Order.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    orders = (await session.execute(query)).scalars().unique().all()
    total = await session.scalar(count_query) or 0
    return {
        "count": total,
        "next": None,
        "previous": None,
        "results": [order_summary_payload(o, o.customer) for o in orders],
    }


@router.get("/admin/orders/{order_id}/")
async def admin_order_detail(
    order_id: int, session: AsyncSession = Depends(get_db), user: User = Depends(get_current_user),
    storage: R2Storage = Depends(get_storage),
):
    require_center_staff(user)
    order = await get_order(session, order_id)
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Buyurtma topilmadi")
    check_order_access(order, user)
    customer = await session.get(User, order.customer_id) if order.customer_id else None
    return await order_detail_payload(session, order, customer, storage)


@router.patch("/admin/orders/{order_id}/")
async def admin_update_order(
    order_id: int,
    payload: AdminOrderUpdate,
    background: BackgroundTasks,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
    storage: R2Storage = Depends(get_storage),
):
    require_center_staff(user)
    order = await get_order(session, order_id)
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Buyurtma topilmadi")
    check_order_access(order, user)
    previous_status = order.status
    changes = payload.model_dump(exclude_unset=True, mode="json")
    if changes.get("status") is None:
        changes.pop("status", None)
    else:
        check_transition(previous_status, changes["status"])
    for field, value in changes.items():
        setattr(order, field, value)
    await session.commit()
    order = await get_order(session, order_id)
    if order and order.status != previous_status:
        try:
            msgs = await customer_status_messages(session, order)
            if msgs:
                background.add_task(send_messages, msgs)
        except Exception as exc:
            logger.warning("Failed to prepare customer status telegram message: %s", exc)
    customer = await session.get(User, order.customer_id) if (order and order.customer_id) else None
    return await order_detail_payload(session, order, customer, storage)


@router.patch("/admin/orders/{order_id}/items/{item_id}/")
async def admin_update_order_item(
    order_id: int,
    item_id: int,
    payload: AdminOrderItemUpdate,
    session: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
    storage: R2Storage = Depends(get_storage),
):
    require_center_staff(user)
    order = await get_order(session, order_id)
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Buyurtma topilmadi")
    check_order_access(order, user)
    item = next((i for i in order.items if i.id == item_id), None)
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Buyurtma qatori topilmadi")
    item.production_status = payload.production_status
    await session.commit()
    order = await get_order(session, order_id)
    customer = await session.get(User, order.customer_id) if (order and order.customer_id) else None
    return await order_detail_payload(session, order, customer, storage)


@router.post("/{order_id}/status")
async def update_order_status(
    order_id: int,
    payload: OrderStatusUpdate,
    background: BackgroundTasks,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
):
    require_center_staff(user)
    order = await get_order(session, order_id)
    if order is None:
        raise HTTPException(status_code=404, detail="Buyurtma topilmadi")
    check_order_access(order, user)
    new_status = payload.status.value
    if new_status != order.status:
        check_transition(order.status, new_status)
        order.status = new_status
        await session.commit()
        # updated_at is set by the database on commit: read the order back.
        order = await get_order(session, order_id)
        try:
            msgs = await customer_status_messages(session, order)
            if msgs:
                background.add_task(send_messages, msgs)
        except Exception as exc:
            logger.warning("Failed to prepare customer status telegram message: %s", exc)
    customer = await session.get(User, order.customer_id) if (order and order.customer_id) else None
    return await order_detail_payload(session, order, customer, storage)


@router.get("/{lookup}/")
async def order_detail(
    lookup: str, user: User = Depends(get_current_user), session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
):
    query = select(Order).options(selectinload(Order.items)).where(
        Order.customer_id == user.id,
        (Order.order_number == lookup) | (Order.id == int(lookup) if lookup.isdigit() else False),
    )
    order = (await session.execute(query)).scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Buyurtma topilmadi")
    return await order_detail_payload(session, order, user, storage)


@router.post("/{order_id}/cancel/")
async def cancel_order(
    order_id: int, user: User = Depends(get_current_user), session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
):
    order = (
        await session.execute(
            select(Order)
            .options(selectinload(Order.items))
            .where(Order.id == order_id, Order.customer_id == user.id)
        )
    ).scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Buyurtma topilmadi")
    if order.status != "NEW":
        # Once confirmed, paid or in production it is the shop's to cancel.
        raise HTTPException(status_code=422, detail="Buyurtmani faqat u yangi (tasdiqlanmagan) paytda bekor qilish mumkin")
    order.status = "CANCELLED"
    await session.commit()
    # updated_at is set by the database on commit: read it back before answering.
    await session.refresh(order)
    return await order_detail_payload(session, order, user, storage)
