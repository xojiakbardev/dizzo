"""Delivery options, real-time price calculation and configuration endpoints."""

from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.db.session import get_db
from app.services.delivery.bts import BTSDeliveryService
from app.services.delivery.yandex import YandexDeliveryService

router = APIRouter(prefix="/delivery", tags=["delivery"])


class DeliveryCalculateRequest(BaseModel):
    provider: Literal["YANDEX", "BTS"]
    latitude: float | None = None
    longitude: float | None = None
    address: str = ""
    city: str = "Toshkent"
    branch_id: int | None = None


@router.get("/config/")
async def get_delivery_config(settings: Settings = Depends(get_settings)) -> dict:
    """Returns backend configuration for estimated delivery durations and provider rules.

    Eliminates hardcoded estimates on the client.
    """
    return {
        "providers": {
            "YANDEX": {
                "id": "YANDEX",
                "name": "Yandex Dastavka",
                "scope": "Faqat Toshkent shahri ichida",
                "estimated_days": settings.delivery_estimated_days_yandex,
                "only_tashkent": True,
                "token_configured": bool(settings.yandex_delivery_oauth_token),
            },
            "BTS": {
                "id": "BTS",
                "name": "BTS Pochta",
                "scope": "O'zbekiston bo'ylab",
                "estimated_days": settings.delivery_estimated_days_bts,
                "only_tashkent": False,
                "token_configured": False,  # BTS public API not documented; uses branch queue engine
            },
        },
        "warehouse": {
            "address": settings.dizzo_warehouse_address,
            "latitude": settings.dizzo_warehouse_lat,
            "longitude": settings.dizzo_warehouse_lon,
        },
    }


@router.post("/calculate/")
async def calculate_delivery(
    payload: DeliveryCalculateRequest,
    session: AsyncSession = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> dict:
    """Calculates delivery price and estimated days dynamically."""
    if payload.provider == "YANDEX":
        service = YandexDeliveryService(settings)
        return await service.calculate_quote(
            dest_lat=payload.latitude,
            dest_lon=payload.longitude,
            dest_address=payload.address,
            dest_city=payload.city,
        )

    # BTS calculation
    service = BTSDeliveryService(settings)
    return await service.calculate_quote(
        session=session,
        city=payload.city,
        branch_id=payload.branch_id,
        dest_lat=payload.latitude,
        dest_lon=payload.longitude,
    )
