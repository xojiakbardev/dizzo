import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.commerce import Order, OrderItem
from app.services import feed_cache
from tests.conftest import FakeStorage, register
from tests.test_catalog import A, build_mug, ok


async def order(session_factory, user_id: int, number: str, slug: str, quantity: int, status: str = "NEW") -> None:
    async with session_factory() as session:
        o = Order(order_number=number, customer_id=user_id, status=status, total_amount=0)
        o.items.append(OrderItem(product_name=slug, product_slug=slug, quantity=quantity, unit_price=0))
        session.add(o)
        await session.commit()
    feed_cache.clear()  # written past the API, which would clear it


async def popular(client: httpx.AsyncClient) -> list[str]:
    return [c["slug"] for c in ok(await client.get("/api/catalog/products/?sort=popular"))]


@pytest.mark.asyncio
async def test_popular_puts_the_most_ordered_first_then_the_newest(
    admin_client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    older = await build_mug(admin_client, storage)
    ok(await admin_client.patch(f"{A}/products/{older['id']}/", json={"slug": "krujka-eski"}))
    await build_mug(admin_client, storage)  # "krujka", the newer one

    assert await popular(admin_client) == ["krujka", "krujka-eski"]

    customer = await register(admin_client, "popular@example.com")
    await order(session_factory, customer["id"], "P-1", "krujka-eski", 3)
    await order(session_factory, customer["id"], "P-2", "krujka", 10, status="CANCELLED")

    assert await popular(admin_client) == ["krujka-eski", "krujka"]
    assert (await admin_client.get("/api/catalog/products/?sort=cheap")).status_code == 422
