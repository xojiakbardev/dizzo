"""Delivery is priced by the backend, whatever price the client sends."""

import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.config import get_settings
from tests.conftest import FakeStorage
from tests.test_catalog import ok
from tests.test_orders_hardening import fill_cart
from tests.test_studio import shop

TASHKENT = {"latitude": "41.311081", "longitude": "69.240562", "shipping_address": "Amir Temur 1"}
SAMARKAND = {"latitude": "39.654", "longitude": "66.959", "shipping_address": "Registon 1", "shipping_city": "Toshkent"}


@pytest.fixture(autouse=True)
def offline_yandex(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("YANDEX_DELIVERY_OAUTH_TOKEN", "")
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def form(**extra) -> dict:
    return {"contact_name": "Test", "delivery_method": "DELIVERY", **extra}


@pytest.mark.asyncio
async def test_a_free_delivery_sent_by_the_client_is_priced_by_the_backend(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    await fill_cart(client, storage, s)

    order = ok(await client.post("/api/checkout/", json=form(carrier="YANDEX", shipping_cost=0, **TASHKENT)))["order"]

    price = get_settings().yandex_delivery_default_cost
    assert order["carrier"] == "YANDEX"
    assert float(order["shipping_cost"]) == price
    assert float(order["total_amount"]) == float(order["subtotal"]) + price


@pytest.mark.asyncio
async def test_a_client_without_a_carrier_gets_one_by_the_pin(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    await fill_cart(client, storage, s)

    # A pin in Samarkand is outside Tashkent even with the default city name.
    order = ok(await client.post("/api/checkout/", json=form(**SAMARKAND)))["order"]

    assert order["carrier"] == "BTS"
    assert float(order["shipping_cost"]) > 0


@pytest.mark.asyncio
async def test_yandex_outside_tashkent_and_unknown_carriers_are_refused(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    await fill_cart(client, storage, s)

    assert (await client.post("/api/checkout/", json=form(carrier="YANDEX", **SAMARKAND))).status_code == 422
    assert (await client.post("/api/checkout/", json=form(carrier="DHL", **TASHKENT))).status_code == 422
