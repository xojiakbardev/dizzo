"""Checkout idempotency, order status transitions, order lists and stats."""

from datetime import UTC, datetime
from decimal import Decimal

import httpx
import pytest
from sqlalchemy import event, func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.api.v1 import checkout as checkout_module
from app.api.v1 import orders as orders_module
from app.models.commerce import Order
from app.models.review import Review
from app.models.user import User
from app.services import telegram_notify
from app.services.orders import ALLOWED_TRANSITIONS, OrderStatus
from app.services.thumbnails import make_thumbnails
from tests.conftest import FakeStorage, make_admin, register
from tests.test_catalog import ok
from tests.test_reviews import order_for
from tests.test_studio import UV_LAYER, UV_PX, cart_item, png, shop

FORM = {"contact_name": "Test", "delivery_method": "PICKUP"}


async def fill_cart(client: httpx.AsyncClient, storage: FakeStorage, s: dict) -> None:
    body = png(UV_PX, (500, 60, 2000, 860, (200, 30, 40, 255)))
    ok(await cart_item(client, storage, s, [("wrap", "uv", body)], UV_LAYER, expected="149000"), 201)


async def order_count(session_factory: async_sessionmaker[AsyncSession]) -> int:
    async with session_factory() as session:
        return await session.scalar(select(func.count(Order.id)))


@pytest.mark.asyncio
async def test_a_repeated_checkout_with_the_same_key_places_one_order(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    await fill_cart(client, storage, s)
    key = {"Idempotency-Key": "0b6f7c1e-7d0c-4a55-9d1f-2f0f3c1c9a10"}

    first = ok(await client.post("/api/checkout/", json=FORM, headers=key))
    again = ok(await client.post("/api/checkout/", json=FORM, headers=key))
    fresh_key = await client.post("/api/checkout/", json=FORM, headers={"Idempotency-Key": "another-key-123"})
    no_key = await client.post("/api/checkout/", json=FORM)
    bad_key = await client.post("/api/checkout/", json=FORM, headers={"Idempotency-Key": "bad key!"})

    assert again["order_id"] == first["order_id"] and again["order_number"] == first["order_number"]
    assert again["order"]["items"] == first["order"]["items"]
    assert fresh_key.status_code == 400 and no_key.status_code == 400  # the cart is empty now
    assert bad_key.status_code == 422
    assert await order_count(session_factory) == 1


@pytest.mark.asyncio
async def test_keys_belong_to_one_customer(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    await fill_cart(client, storage, s)
    key = {"Idempotency-Key": "shared-key-0001"}
    ok(await client.post("/api/checkout/", json=FORM, headers=key))

    await client.post("/api/auth/logout/")
    await register(client, "second-buyer@example.com")
    await fill_cart(client, storage, s)
    theirs = ok(await client.post("/api/checkout/", json=FORM, headers=key))

    assert theirs["order"]["customer"]["email"] == "second-buyer@example.com"
    assert await order_count(session_factory) == 2


@pytest.mark.asyncio
async def test_a_free_order_is_refused(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    s = await shop(client, storage, session_factory)
    await fill_cart(client, storage, s)
    real_quote = checkout_module.quote
    monkeypatch.setattr(
        checkout_module, "quote",
        lambda *args: real_quote(*args).model_copy(update={"unit_price": Decimal("0"), "total": Decimal("0")}),
    )

    repriced = await client.post("/api/checkout/", json=FORM)
    refused = await client.post("/api/checkout/", json=FORM)

    assert repriced.status_code == 409
    assert refused.status_code == 422 and "0 so'm" in refused.json()["detail"]
    assert await order_count(session_factory) == 0
    assert ok(await client.get("/api/cart/"))["is_empty"] is False


@pytest.mark.asyncio
async def test_staff_hear_about_new_orders_after_the_response(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    sent: list[tuple[int, str]] = []

    async def fake_send(chat_id: int, text: str) -> None:
        sent.append((chat_id, text))

    monkeypatch.setattr(telegram_notify, "_send_message", fake_send)
    queued: list = []
    real_add = checkout_module.BackgroundTasks.add_task

    def spy(self, func, *args, **kwargs):
        queued.append(func)
        return real_add(self, func, *args, **kwargs)

    monkeypatch.setattr(checkout_module.BackgroundTasks, "add_task", spy)
    s = await shop(client, storage, session_factory)
    async with session_factory() as session:
        admin = (await session.execute(select(User).where(User.email == "shop-admin@example.com"))).scalar_one()
        admin.telegram_id = 4242
        await session.commit()
    await fill_cart(client, storage, s)

    order = ok(await client.post("/api/checkout/", json=FORM))

    # Catalog uploads in the setup queue their thumbnails too.
    assert [task for task in queued if task is not make_thumbnails] == [telegram_notify.send_messages]
    assert [chat for chat, _ in sent] == [4242] and order["order_number"] in sent[0][1]


# ── Status ──


def test_the_transition_map() -> None:
    assert OrderStatus.COMPLETED in ALLOWED_TRANSITIONS[OrderStatus.NEW]
    assert OrderStatus.IN_PRODUCTION in ALLOWED_TRANSITIONS[OrderStatus.QUALITY_CHECK]
    assert OrderStatus.READY_FOR_PICKUP in ALLOWED_TRANSITIONS[OrderStatus.READY_FOR_DELIVERY]
    assert OrderStatus.NEW not in ALLOWED_TRANSITIONS[OrderStatus.PAID]
    assert ALLOWED_TRANSITIONS[OrderStatus.COMPLETED] == ALLOWED_TRANSITIONS[OrderStatus.CANCELLED] == frozenset()
    assert set(ALLOWED_TRANSITIONS) == set(OrderStatus)


async def staff_client(client: httpx.AsyncClient, session_factory) -> dict:
    customer = await register(client, "status-customer@example.com")
    await client.post("/api/auth/logout/")
    admin = await register(client, "status-admin@example.com")
    await make_admin(session_factory, admin["id"])
    return customer


@pytest.mark.asyncio
async def test_staff_can_only_move_orders_along_the_pipeline(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    customer = await staff_client(client, session_factory)
    order = await order_for(session_factory, customer["id"], "NEW", "S-1")
    admin_url = f"/api/orders/admin/orders/{order}/"

    assert ok(await client.post(f"/api/orders/{order}/status", json={"status": "PAID"}))["status"] == "PAID"
    backwards = await client.post(f"/api/orders/{order}/status", json={"status": "NEW"})
    unknown = await client.post(f"/api/orders/{order}/status", json={"status": "SHIPPED"})
    missing = await client.post(f"/api/orders/{order}/status", json={})
    same = await client.post(f"/api/orders/{order}/status", json={"status": "PAID"})
    ok(await client.patch(admin_url, json={"status": "QUALITY_CHECK"}))
    ok(await client.patch(admin_url, json={"status": "IN_PRODUCTION"}))  # rework after a failed check
    ok(await client.patch(admin_url, json={"status": "COMPLETED", "tracking_number": "T-1"}))
    reopened = await client.patch(admin_url, json={"status": "IN_PRODUCTION"})
    notes = await client.patch(admin_url, json={"admin_notes": "yetkazildi"})
    bad_patch = await client.patch(admin_url, json={"status": "DONE"})

    assert backwards.status_code == 422 and "o'tkazib bo'lmaydi" in backwards.json()["detail"]
    assert unknown.status_code == 422 and missing.status_code == 422 and bad_patch.status_code == 422
    assert same.status_code == 200
    assert reopened.status_code == 422
    assert notes.status_code == 200 and notes.json()["status"] == "COMPLETED"


# ── Lists and figures ──


@pytest.mark.asyncio
async def test_admin_order_pages_start_at_one(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    await staff_client(client, session_factory)
    assert (await client.get("/api/orders/admin/orders/", params={"page": 0})).status_code == 422
    assert (await client.get("/api/orders/admin/orders/", params={"page_size": 0})).status_code == 422
    assert (await client.get("/api/orders/admin/orders/", params={"page": 1})).status_code == 200


@pytest.mark.asyncio
async def test_order_stats_are_summed_in_the_database(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    customer = await staff_client(client, session_factory)
    for number, status in [("A", "NEW"), ("B", "PAID"), ("C", "IN_PRODUCTION"), ("D", "COMPLETED"), ("E", "CANCELLED")]:
        await order_for(session_factory, customer["id"], status, number)
    other = await order_for(session_factory, (await register_quietly(session_factory)), "COMPLETED", "F")
    assert other

    staff = ok(await client.get("/api/orders/stats/"))
    await client.post("/api/auth/logout/")
    ok(await client.post("/api/auth/login/", json={"email": "status-customer@example.com", "password": "password123"}))
    mine = ok(await client.get("/api/orders/stats/"))

    assert staff == {
        "total_orders": 6, "new_orders": 1, "payment_pending_orders": 0, "paid_orders": 1,
        "in_production_orders": 1, "done_orders": 2, "total_spent": "130000.00", "total_revenue": "260000.00",
    }
    assert mine["total_orders"] == 5 and mine["done_orders"] == 1
    assert mine["total_spent"] == "65000.00" and mine["total_revenue"] == "195000.00"


async def register_quietly(session_factory) -> int:
    async with session_factory() as session:
        user = User(email="elsewhere@example.com")
        session.add(user)
        await session.commit()
        return user.id


@pytest.mark.asyncio
async def test_analytics_days_are_tashkent_days(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    customer = await staff_client(client, session_factory)
    # 21:30 UTC on the 15th is already 02:30 on the 16th in Tashkent.
    late = await order_for(session_factory, customer["id"], "PAID", "LATE")
    async with session_factory() as session:
        (await session.get(Order, late)).created_at = datetime(2026, 9, 15, 21, 30, tzinfo=UTC)
        await session.commit()

    class FrozenDatetime(datetime):
        @classmethod
        def now(cls, tz=None):
            return datetime(2026, 9, 16, 6, 0, tzinfo=UTC).astimezone(tz) if tz else datetime(2026, 9, 16, 6, 0)

    monkeypatch.setattr(orders_module, "datetime", FrozenDatetime)
    days = ok(await client.get("/api/orders/analytics/", params={"days": 2}))["revenue_by_day"]

    assert [d["date"] for d in days] == ["2026-09-15", "2026-09-16"]
    assert days[1]["orders"] == 1 and Decimal(days[1]["revenue"]) == Decimal("65000")
    assert days[0]["orders"] == 0
    assert (await client.get("/api/orders/analytics/", params={"days": 0})).status_code == 422


@pytest.mark.asyncio
async def test_admin_reviews_list_does_not_query_per_review(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    customer = await staff_client(client, session_factory)
    async with session_factory() as session:
        for i in range(5):
            order_id = await order_for(session_factory, customer["id"], "COMPLETED", f"R-{i}")
            session.add(Review(user_id=customer["id"], order_id=order_id, name="Ali", rating=5, text="Juda yaxshi mahsulot"))
        await session.commit()

    engine = session_factory.kw["bind"].sync_engine
    statements: list[str] = []

    def count(conn, cursor, statement, *args):
        if statement.lstrip().upper().startswith("SELECT"):
            statements.append(statement)

    event.listen(engine, "before_cursor_execute", count)
    try:
        reviews = ok(await client.get("/api/admin/reviews/"))
    finally:
        event.remove(engine, "before_cursor_execute", count)

    assert sorted(r["order_number"] for r in reviews) == [f"R-{i}" for i in range(5)]
    assert len(statements) <= 5  # user, reviews, photos, orders — not one per review


@pytest.mark.asyncio
async def test_status_update_with_missing_customer_and_partial_package(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    customer = await staff_client(client, session_factory)

    # 1. Create order with partial/broken package in item (no "files" key, null mockups)
    async with session_factory() as session:
        from app.models.commerce import OrderItem
        order = Order(
            order_number="HARDEN-1",
            customer_id=customer["id"],
            status="NEW",
            total_amount=50000,
            shipping_name="Xaridor",
            shipping_phone="+998901234567",
        )
        # Package with only quote, no files, null mockups/underbase
        order.items.append(
            OrderItem(
                product_name="Futbolka",
                product_slug="futbolka",
                quantity=1,
                unit_price=50000,
                package={"quote": {"size": "L"}, "mockups": None, "underbase": None},
            )
        )
        session.add(order)
        await session.commit()
        order_id = order.id

    # Advance status to PAID
    res = ok(await client.post(f"/api/orders/{order_id}/status", json={"status": "PAID"}))
    assert res["status"] == "PAID"
    assert res["customer"]["full_name"] == "Test"
    assert len(res["items"]) == 1
    assert res["items"][0]["files"] == []
    assert res["items"][0]["mockups"] == []

    # 2. Test status change when customer_id points to nonexistent user
    async with session_factory() as session:
        order_db = await session.get(Order, order_id)
        # Temporarily set customer_id to a non-existent user ID or delete user without cascade
        # Using a dummy order with a high ID
        dummy_order = Order(
            order_number="HARDEN-2",
            customer_id=999999,  # does not exist
            status="NEW",
            total_amount=30000,
            shipping_name="Mehmon",
            shipping_email="guest@example.com",
            shipping_phone="+998990000000",
        )
        dummy_order.items.append(
            OrderItem(
                product_name="Stiker",
                product_slug="stiker",
                quantity=2,
                unit_price=15000,
                package=None,
            )
        )
        session.add(dummy_order)
        await session.commit()
        dummy_id = dummy_order.id

    # Advance status on order with non-existent customer and package=None
    res2 = ok(await client.post(f"/api/orders/{dummy_id}/status", json={"status": "PAID"}))
    assert res2["status"] == "PAID"
    assert res2["customer"]["id"] is None
    assert res2["customer"]["full_name"] == "Mehmon"
    assert res2["customer"]["email"] == "guest@example.com"
    assert res2["items"][0]["files"] == []
    assert res2["items"][0]["mockups"] == []

    # 3. Test status change when customer_status_messages raises an exception
    async def broken_messages(*args, **kwargs):
        raise RuntimeError("Telegram network down")

    monkeypatch.setattr(orders_module, "customer_status_messages", broken_messages)

    res3 = ok(await client.patch(f"/api/orders/admin/orders/{dummy_id}/", json={"status": "IN_PRODUCTION"}))
    assert res3["status"] == "IN_PRODUCTION"


@pytest.mark.asyncio
async def test_pickup_order_includes_the_chosen_branch(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    from tests.test_privilege_escalation import make_branch

    s = await shop(client, storage, session_factory)
    branch_id = await make_branch(session_factory, "chilonzor-pickup")
    await fill_cart(client, storage, s)
    placed = ok(await client.post("/api/checkout/", json={
        **FORM, "branch_id": branch_id, "latitude": "41.310000", "longitude": "69.240000",
    }, headers={"Idempotency-Key": "pickup-branch-detail-1"}))
    order = placed["order"]

    assert order["delivery_method"] == "PICKUP"
    assert order["branch_id"] == branch_id
    assert order["branch"]["name"] == "Filial chilonzor-pickup"
    assert order["branch"]["address"] == "Test ko'chasi 1"
    assert order["branch"]["latitude"] == 41.31
    assert order["latitude"] == "41.310000"

