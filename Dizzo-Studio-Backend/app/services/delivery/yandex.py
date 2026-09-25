"""Yandex Delivery B2B API integration service.

Uses Yandex Delivery B2B check-price/calculate API (host: https://b2b.taxi.yandex.net)
to calculate real-time delivery quotes within Tashkent city.
"""

from __future__ import annotations

import logging
from typing import Any

import httpx

from app.core.config import Settings

logger = logging.getLogger(__name__)

# Approximate geographical bounding box for Tashkent city
TASHKENT_LAT_MIN = 41.15
TASHKENT_LAT_MAX = 41.45
TASHKENT_LON_MIN = 69.10
TASHKENT_LON_MAX = 69.45


def is_within_tashkent(latitude: float | None, longitude: float | None, city: str = "") -> bool:
    """Checks whether the destination address or pin is inside Tashkent city."""
    if city and ("toshkent" in city.lower() or "ташкент" in city.lower() or "tashkent" in city.lower()):
        return True
    if latitude is not None and longitude is not None:
        if TASHKENT_LAT_MIN <= latitude <= TASHKENT_LAT_MAX and TASHKENT_LON_MIN <= longitude <= TASHKENT_LON_MAX:
            return True
    return False


class YandexDeliveryService:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.oauth_token = settings.yandex_delivery_oauth_token.strip()
        self.base_url = settings.yandex_delivery_api_url.rstrip("/")
        self.origin_lat = settings.dizzo_warehouse_lat
        self.origin_lon = settings.dizzo_warehouse_lon
        self.origin_address = settings.dizzo_warehouse_address

    async def calculate_quote(
        self,
        dest_lat: float | None,
        dest_lon: float | None,
        dest_address: str,
        dest_city: str = "Toshkent",
    ) -> dict[str, Any]:
        """Calculates real-time delivery quote using Yandex Delivery B2B API."""
        if not is_within_tashkent(dest_lat, dest_lon, dest_city):
            return {
                "provider": "YANDEX",
                "available": False,
                "price": 0,
                "formatted_price": "0 so'm",
                "estimated_days": self.settings.delivery_estimated_days_yandex,
                "currency": "UZS",
                "error": "Yandex Dastavka faqat Toshkent shahri ichida ishlaydi. Viloyatlar uchun BTS Pochta xizmatini tanlang.",
            }

        # If OAuth token is not configured, fall back to configured default price
        if not self.oauth_token:
            default_price = float(self.settings.yandex_delivery_default_cost)
            return {
                "provider": "YANDEX",
                "available": True,
                "price": default_price,
                "formatted_price": f"{int(default_price):,} so'm".replace(",", " "),
                "estimated_days": self.settings.delivery_estimated_days_yandex,
                "currency": "UZS",
                "source": "config_fallback",
                "notice": "Yandex Delivery OAuth token sozlanmagan. Standart tarif qo'llanilmoqda.",
            }

        # Real API call to Yandex Delivery B2B check-price
        headers = {
            "Authorization": f"Bearer {self.oauth_token}",
            "Accept-Language": "uz",
            "Content-Type": "application/json",
        }

        payload = {
            "items": [
                {
                    "quantity": 1,
                    "size": {"length": 0.25, "width": 0.25, "height": 0.15},
                    "weight": 0.5,
                }
            ],
            "route_points": [
                {
                    "coordinates": [self.origin_lon, self.origin_lat],
                    "fullname": self.origin_address,
                },
                {
                    "coordinates": [dest_lon if dest_lon is not None else self.origin_lon, dest_lat if dest_lat is not None else self.origin_lat],
                    "fullname": dest_address or "Toshkent shahri",
                },
            ],
        }

        try:
            async with httpx.AsyncClient(timeout=6.0) as client:
                resp = await client.post(f"{self.base_url}/b2b/taxi/check-price", headers=headers, json=payload)
                if resp.status_code == 200:
                    data = resp.json()
                    price = float(data.get("price", self.settings.yandex_delivery_default_cost))
                    return {
                        "provider": "YANDEX",
                        "available": True,
                        "price": price,
                        "formatted_price": f"{int(price):,} so'm".replace(",", " "),
                        "estimated_days": self.settings.delivery_estimated_days_yandex,
                        "currency": "UZS",
                        "source": "yandex_b2b_api",
                    }
                else:
                    logger.warning("Yandex Delivery B2B API returned status %s: %s", resp.status_code, resp.text)
        except Exception as exc:
            logger.warning("Yandex Delivery API call failed: %s", exc)

        # Graceful fallback on API error
        default_price = float(self.settings.yandex_delivery_default_cost)
        return {
            "provider": "YANDEX",
            "available": True,
            "price": default_price,
            "formatted_price": f"{int(default_price):,} so'm".replace(",", " "),
            "estimated_days": self.settings.delivery_estimated_days_yandex,
            "currency": "UZS",
            "source": "fallback",
        }
