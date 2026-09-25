import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.commerce import Order
from app.models.user import User
from tests.conftest import make_admin, register
from tests.test_gallery import completed_order


@pytest.mark.asyncio
async def test_deleting_the_account_empties_it_and_keeps_finished_orders(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    user = await register(client, "leaving@example.com")
    order_id = await completed_order(session_factory, user["id"], "D-1", [])

    gone = await client.delete("/api/users/profile/me/")
    assert gone.status_code == 204

    async with session_factory() as session:
        row = await session.get(User, user["id"])
        assert row.email is None and row.first_name == "" and row.password_hash is None
        assert row.is_active is False
        assert (await session.get(Order, order_id)) is not None
    # Signed out, and the old password no longer works.
    assert (await client.get("/api/users/profile/me/")).status_code == 401
    login = await client.post("/api/auth/login/", json={"email": "leaving@example.com", "password": "password123"})
    assert login.status_code in (400, 401)
    # The address is free for a new account.
    await register(client, "leaving@example.com")


@pytest.mark.asyncio
async def test_an_order_in_progress_blocks_deletion(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    user = await register(client, "busy@example.com")
    async with session_factory() as session:
        session.add(Order(order_number="D-2", customer_id=user["id"], status="NEW", total_amount=1000))
        await session.commit()

    blocked = await client.delete("/api/users/profile/me/", headers={"Accept-Language": "en"})
    assert blocked.status_code == 409
    assert "order in progress" in blocked.json()["detail"]


@pytest.mark.asyncio
async def test_admins_cannot_delete_themselves(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    user = await register(client, "boss@example.com")
    await make_admin(session_factory, user["id"])

    assert (await client.delete("/api/users/profile/me/")).status_code == 403
