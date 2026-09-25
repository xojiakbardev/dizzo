from __future__ import annotations

from enum import StrEnum

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.i18n import _, translate
from app.models.commerce import Order
from app.models.user import User
from app.services.packages import order_item_payload
from app.services.storage import R2Storage


class OrderStatus(StrEnum):
    NEW = "NEW"
    PAYMENT_PENDING = "PAYMENT_PENDING"
    PAID = "PAID"
    MODERATED = "MODERATED"
    READY_FOR_PRODUCTION = "READY_FOR_PRODUCTION"
    IN_PRODUCTION = "IN_PRODUCTION"
    QUALITY_CHECK = "QUALITY_CHECK"
    READY_FOR_PICKUP = "READY_FOR_PICKUP"
    READY_FOR_DELIVERY = "READY_FOR_DELIVERY"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"


# The pipeline, in order. Staff may move an order forward any number of
# steps (the admin page often skips some), send it back from quality check
# to production, swap pickup/delivery readiness, or cancel it until it is
# completed. Completed and cancelled orders stay as they are.
_PIPELINE = [
    OrderStatus.NEW,
    OrderStatus.PAYMENT_PENDING,
    OrderStatus.PAID,
    OrderStatus.MODERATED,
    OrderStatus.READY_FOR_PRODUCTION,
    OrderStatus.IN_PRODUCTION,
    OrderStatus.QUALITY_CHECK,
    OrderStatus.READY_FOR_PICKUP,
    OrderStatus.READY_FOR_DELIVERY,
    OrderStatus.COMPLETED,
]
_READY = {OrderStatus.READY_FOR_PICKUP, OrderStatus.READY_FOR_DELIVERY}
ALLOWED_TRANSITIONS: dict[OrderStatus, frozenset[OrderStatus]] = {
    current: frozenset(
        {*_PIPELINE[i + 1:], OrderStatus.CANCELLED}
        | ({OrderStatus.IN_PRODUCTION} if current == OrderStatus.QUALITY_CHECK else set())
        | ({OrderStatus.PAID} if current == OrderStatus.MODERATED else set())
        | (_READY - {current} if current in _READY else set())
    )
    for i, current in enumerate(_PIPELINE[:-1])
}
ALLOWED_TRANSITIONS[OrderStatus.COMPLETED] = frozenset()
ALLOWED_TRANSITIONS[OrderStatus.CANCELLED] = frozenset()


ORDER_STATUS_VALUES: frozenset[str] = frozenset(s.value for s in OrderStatus)


def check_transition(current: str, new: str) -> None:
    """422 unless staff may move an order from `current` to `new` (same status is a no-op)."""
    if current == new:
        return
    if current not in ORDER_STATUS_VALUES or new not in ORDER_STATUS_VALUES:
        allowed = frozenset()
    else:
        allowed = ALLOWED_TRANSITIONS.get(OrderStatus(current), frozenset())

    if OrderStatus(new) not in allowed and new not in allowed:
        raise HTTPException(
            status_code=422,
            detail=_(
                "Buyurtmani \"{current}\" holatidan \"{new}\" holatiga o'tkazib bo'lmaydi",
                current=status_label(current), new=status_label(new),
            ),
        )


STATUS_LABELS = {
    "NEW": "Yangi",
    "PAYMENT_PENDING": "To'lov kutilmoqda",
    "PAID": "To'langan",
    "MODERATED": "Moderatsiya qilindi",
    "READY_FOR_PRODUCTION": "Ishlab chiqarishga tayyor",
    "IN_PRODUCTION": "Ishlab chiqarilmoqda",
    "QUALITY_CHECK": "Sifat nazorati",
    "READY_FOR_PICKUP": "Olib ketishga tayyor",
    "READY_FOR_DELIVERY": "Yetkazishga tayyor",
    "COMPLETED": "Yakunlangan",
    "CANCELLED": "Bekor qilingan",
}


def status_label(status: str, language: str | None = None) -> str:
    """A status's name in `language` (the request's by default)."""
    return translate(STATUS_LABELS.get(status, status), language)


async def get_order(session: AsyncSession, order_id: int) -> Order | None:
    return (
        await session.execute(
            select(Order)
            .options(selectinload(Order.items), selectinload(Order.payments), selectinload(Order.branch))
            .where(Order.id == order_id)
            .execution_options(populate_existing=True)
        )
    ).scalar_one_or_none()


def _branch_out(order: Order) -> dict | None:
    branch = getattr(order, "branch", None)
    if branch is None:
        return None
    return {
        "id": branch.id,
        "name": branch.name,
        "address": branch.address,
        "city": branch.city,
        "work_hours": branch.work_hours,
        "phone": branch.phone,
        "latitude": branch.latitude,
        "longitude": branch.longitude,
    }


def order_summary_payload(order: Order, customer: User | None = None) -> dict:
    return {
        "id": order.id,
        "order_number": order.order_number,
        "customer_name": customer.full_name if customer else (order.shipping_name or None),
        "status": order.status,
        "delivery_method": order.delivery_method,
        "branch_id": order.branch_id,
        "branch_name": order.branch.name if getattr(order, "branch", None) else None,
        "total_amount": str(order.total_amount),
        "item_count": sum(item.quantity for item in (order.items or [])),
        "created_at": order.created_at.isoformat() if order.created_at else None,
        "updated_at": order.updated_at.isoformat() if order.updated_at else None,
    }


async def order_detail_payload(session: AsyncSession, order: Order, customer: User | None, storage: R2Storage) -> dict:
    customer_data = (
        {
            "id": customer.id,
            "email": customer.email,
            "full_name": customer.full_name,
            "phone_number": customer.phone_number,
        }
        if customer
        else {
            "id": None,
            "email": order.shipping_email or "",
            "full_name": order.shipping_name or "",
            "phone_number": order.shipping_phone or "",
        }
    )
    return {
        "id": order.id,
        "order_number": order.order_number,
        "customer": customer_data,
        "status": order.status,
        "subtotal": str(order.subtotal) if order.subtotal is not None else "0",
        "tax_amount": str(order.tax_amount) if order.tax_amount is not None else "0",
        "shipping_cost": str(order.shipping_cost) if order.shipping_cost is not None else "0",
        "discount_amount": str(order.discount_amount) if order.discount_amount is not None else "0",
        "total_amount": str(order.total_amount) if order.total_amount is not None else "0",
        "delivery_method": order.delivery_method,
        "branch_id": order.branch_id,
        "branch_name": order.branch.name if getattr(order, "branch", None) else None,
        "branch": _branch_out(order),
        "latitude": str(order.latitude) if order.latitude is not None else None,
        "longitude": str(order.longitude) if order.longitude is not None else None,
        "shipping_name": order.shipping_name or "",
        "shipping_email": order.shipping_email or "",
        "shipping_phone": order.shipping_phone or "",
        "shipping_address": order.shipping_address or "",
        "shipping_city": order.shipping_city or "",
        "shipping_state": order.shipping_state or "",
        "shipping_postal_code": order.shipping_postal_code or "",
        "shipping_country": order.shipping_country or "",
        "customer_notes": order.customer_notes or "",
        "admin_notes": order.admin_notes or "",
        "tracking_number": order.tracking_number or "",
        "carrier": order.carrier or "",
        "items": [order_item_payload(item, storage) for item in (order.items or [])],
        "payments": [
            {
                "id": p.id,
                "provider": p.provider,
                "amount": str(p.amount),
                "status": p.status,
                "provider_trans_id": p.provider_trans_id,
                "created_at": p.created_at.isoformat() if p.created_at else None,
            }
            for p in (getattr(order, "payments", []) or [])
        ],
        "created_at": order.created_at.isoformat() if order.created_at else None,
        "updated_at": order.updated_at.isoformat() if order.updated_at else None,
    }
