import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.services import telegram_notify
from tests.conftest import make_admin, register
from tests.test_catalog import ok
from tests.test_reviews import order_for

BOT = {"x-bot-token": "123456:test-token"}


async def link(client: httpx.AsyncClient, telegram_id: int) -> dict:
    token = ok(await client.post("/api/auth/telegram/link-token/"))
    assert token["deep_link"] == f"https://t.me/enjoy_test_bot?start=link_{token['token']}"
    return ok(await client.post("/api/auth/telegram/link/", headers=BOT, json={"token": token["token"], "telegram_id": telegram_id}))


@pytest.fixture
def sent(monkeypatch: pytest.MonkeyPatch) -> list[tuple[int, str]]:
    messages: list[tuple[int, str]] = []

    async def fake_send(chat_id: int, text: str) -> None:
        messages.append((chat_id, text))

    monkeypatch.setattr(telegram_notify, "_send_message", fake_send)
    return messages


@pytest.mark.asyncio
@pytest.mark.usefixtures("configure_oauth")
async def test_a_customer_links_telegram_from_their_profile(client: httpx.AsyncClient) -> None:
    await register(client, "tg-customer@example.com")
    token = ok(await client.post("/api/auth/telegram/link-token/"))["token"]

    forged = await client.post("/api/auth/telegram/link/", headers={"x-bot-token": "wrong"}, json={"token": token, "telegram_id": 5050150433})
    linked = ok(await client.post("/api/auth/telegram/link/", headers=BOT, json={"token": token, "telegram_id": 5050150433}))
    again = ok(await client.post("/api/auth/telegram/link/", headers=BOT, json={"token": token, "telegram_id": 42}))
    me = ok(await client.get("/api/auth/me"))

    assert forged.status_code == 403
    assert linked == {"ok": True, "full_name": "Test", "staff": False, "language": "uz"}
    assert again == {"ok": False, "reason": "invalid"}  # single use
    assert me["telegram_linked"] is True and me["telegram_linked_at"]

    await client.post("/api/auth/logout/")
    assert (await client.post("/api/auth/telegram/link-token/")).status_code == 401


@pytest.mark.asyncio
@pytest.mark.usefixtures("configure_oauth")
async def test_staff_linking_is_flagged_for_the_bot(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    admin = await register(client, "tg-admin@example.com")
    await make_admin(session_factory, admin["id"])
    assert (await link(client, 777))["staff"] is True


@pytest.mark.asyncio
@pytest.mark.usefixtures("configure_oauth", "storage")
async def test_a_linked_customer_hears_about_status_changes(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession], sent: list[tuple[int, str]]
) -> None:
    customer = await register(client, "tg-buyer@example.com")
    await link(client, 9001)
    order = await order_for(session_factory, customer["id"], "NEW", "TG-1")
    await client.post("/api/auth/logout/")
    quiet = await register(client, "tg-quiet@example.com")
    quiet_order = await order_for(session_factory, quiet["id"], "NEW", "TG-2")
    await client.post("/api/auth/logout/")
    admin = await register(client, "tg-center@example.com")
    await make_admin(session_factory, admin["id"])

    ok(await client.post(f"/api/orders/{order}/status", json={"status": "PAID"}))
    ok(await client.post(f"/api/orders/{order}/status", json={"status": "PAID"}))  # unchanged: no message
    ok(await client.patch(f"/api/orders/admin/orders/{order}/", json={"status": "IN_PRODUCTION"}))
    ok(await client.patch(f"/api/orders/admin/orders/{order}/", json={"admin_notes": "qo'ng'iroq qilindi"}))
    ok(await client.post(f"/api/orders/{quiet_order}/status", json={"status": "PAID"}))  # not linked

    assert [chat for chat, _ in sent] == [9001, 9001]
    assert "TG-1" in sent[0][1] and "To'langan" in sent[0][1] and "/user/orders/TG-1" in sent[0][1]
    assert "Ishlab chiqarilmoqda" in sent[1][1]
