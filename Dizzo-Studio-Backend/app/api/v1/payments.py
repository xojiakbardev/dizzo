from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import BRANCH_STAFF_ROLES, GLOBAL_STAFF_ROLES, get_current_user
from app.core.config import Settings, get_settings
from app.db.session import get_db
from app.models.commerce import Order
from app.models.user import User
from app.services.orders import OrderStatus
from app.services.payments.click import ClickService

import json
from urllib.parse import parse_qs

logger = logging.getLogger("app.api.payments")

router = APIRouter(prefix="/payments", tags=["payments"])


async def _extract_request_data(request: Request) -> dict[str, Any]:
    """Extract parameters from urlencoded form-data, json payload, or query-params."""
    data: dict[str, Any] = {}

    # 1. Read raw body bytes
    try:
        body_bytes = await request.body()
    except Exception:
        body_bytes = b""

    # 2. Try JSON parsing
    if body_bytes:
        try:
            parsed_json = json.loads(body_bytes.decode("utf-8"))
            if isinstance(parsed_json, dict):
                data.update(parsed_json)
        except Exception:
            pass

    # 3. If not JSON, try standard urlencoded parsing (doesn't need python-multipart)
    if not data and body_bytes:
        try:
            body_str = body_bytes.decode("utf-8")
            parsed_form = parse_qs(body_str, keep_blank_values=True)
            for k, v in parsed_form.items():
                data[k] = v[0] if (isinstance(v, list) and len(v) == 1) else v
        except Exception:
            pass

    # 4. Merge query params as fallback
    for k, v in request.query_params.items():
        if k not in data:
            data[k] = v

    logger.info("Click incoming webhook: url=%s, payload=%s", request.url.path, data)
    return data



@router.post("/click/prepare")
@router.post("/click/prepare/")
async def click_prepare(
    request: Request,
    db: AsyncSession = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> dict[str, Any]:
    """Click Merchant prepare webhook (Action 0)."""
    data = await _extract_request_data(request)
    service = ClickService(settings)
    return await service.prepare(db, data)


@router.post("/click/complete")
@router.post("/click/complete/")
async def click_complete(
    request: Request,
    db: AsyncSession = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> dict[str, Any]:
    """Click Merchant complete webhook (Action 1)."""
    data = await _extract_request_data(request)
    service = ClickService(settings)
    return await service.complete(db, data)


@router.get("/click/url/{order_number}")
async def get_click_payment_url(
    order_number: str,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
    settings: Settings = Depends(get_settings),
) -> dict[str, Any]:
    """Get Click payment URL for an existing order owned by current user."""
    res = await db.execute(select(Order).where(Order.order_number == order_number.strip()))
    order = res.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Buyurtma topilmadi")

    may_pay_for_others = user.role in GLOBAL_STAFF_ROLES or (
        user.role in BRANCH_STAFF_ROLES and user.branch_id is not None and order.branch_id == user.branch_id
    )
    if order.customer_id != user.id and not may_pay_for_others:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Ruxsat yo'q")

    if order.status in (OrderStatus.PAID, OrderStatus.MODERATED, OrderStatus.READY_FOR_PRODUCTION, OrderStatus.IN_PRODUCTION, OrderStatus.COMPLETED):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Buyurtma allaqachon to'langan")

    if order.status == OrderStatus.CANCELLED:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Buyurtma bekor qilingan")

    service = ClickService(settings)
    url = service.generate_payment_url(order)
    return {
        "payment_url": url,
        "order_number": order.order_number,
        "amount": str(order.total_amount),
    }
