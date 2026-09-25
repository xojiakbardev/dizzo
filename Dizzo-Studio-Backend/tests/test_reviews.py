import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.commerce import Order, OrderItem
from tests.conftest import FakeStorage, make_admin, register
from tests.test_catalog import ok
from tests.test_studio import png, upload


async def order_for(session_factory, user_id: int, status: str, number: str) -> int:
    async with session_factory() as session:
        order = Order(order_number=number, customer_id=user_id, status=status, total_amount=65000)
        order.items.append(OrderItem(product_name="Krujka", product_slug="krujka", quantity=1, unit_price=65000))
        session.add(order)
        await session.commit()
        return order.id


TEXT = "Krujka juda chiroyli chiqdi, rasm tiniq, rahmat!"


@pytest.mark.asyncio
async def test_a_customer_reviews_a_completed_order_and_an_admin_approves(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    customer = await register(client, "rev-customer@example.com")
    done = await order_for(session_factory, customer["id"], "COMPLETED", "D-1")
    open_order = await order_for(session_factory, customer["id"], "IN_PRODUCTION", "D-2")
    photos = [await upload(client, storage, "design", png((20, 20), (0, 0, 20, 20, (200, 50, 50, 255)))) for _ in range(2)]

    too_early = await client.post("/api/reviews/", json={"order_id": open_order, "rating": 5, "text": TEXT})
    review = ok(await client.post("/api/reviews/", json={"order_id": done, "rating": 5, "text": TEXT, "city": "Toshkent", "photo_ids": photos}), 201)
    twice = await client.post("/api/reviews/", json={"order_id": done, "rating": 4, "text": TEXT})

    assert too_early.status_code == 422 and "yakunlangach" in too_early.json()["detail"]
    assert twice.status_code == 422
    assert review["status"] == "pending" and review["product_name"] == "Krujka" and len(review["photos"]) == 2
    assert review["order_number"] == "D-1" and review["from_customer"] is True
    assert ok(await client.get("/api/reviews/")) == []  # not public until approved
    assert [r["status"] for r in ok(await client.get("/api/reviews/mine/"))] == ["pending"]

    await client.post("/api/auth/logout/")
    admin = await register(client, "rev-admin@example.com")
    await make_admin(session_factory, admin["id"])
    pending = ok(await client.get("/api/admin/reviews/?status=pending"))
    assert [r["id"] for r in pending] == [review["id"]]
    ok(await client.patch(f"/api/admin/reviews/{review['id']}/", json={"status": "approved"}))

    public = ok(await client.get("/api/reviews/"))
    assert [(r["id"], r["city"], r["rating"], len(r["photos"])) for r in public] == [(review["id"], "Toshkent", 5, 2)]
    assert public[0]["name"] and "status" not in public[0]  # moderation details stay private


@pytest.mark.asyncio
async def test_review_rules(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    owner = await register(client, "owner@example.com")
    done = await order_for(session_factory, owner["id"], "COMPLETED", "D-3")
    await client.post("/api/auth/logout/")
    stranger = await register(client, "stranger-rev@example.com")
    theirs = await upload(client, storage, "design", png((10, 10)))
    not_mine = await client.post("/api/reviews/", json={"order_id": done, "rating": 5, "text": TEXT})
    mine_done = await order_for(session_factory, stranger["id"], "COMPLETED", "D-4")
    await client.post("/api/auth/logout/")
    await client.post("/api/auth/login/", json={"email": "owner@example.com", "password": "password123"})
    foreign_photo = await client.post("/api/reviews/", json={"order_id": done, "rating": 5, "text": TEXT, "photo_ids": [theirs]})
    short = await client.post("/api/reviews/", json={"order_id": done, "rating": 5, "text": "zo'r"})
    bad_rating = await client.post("/api/reviews/", json={"order_id": done, "rating": 6, "text": TEXT})
    guest_list = await client.get("/api/admin/reviews/")

    assert not_mine.status_code == 404
    assert foreign_photo.status_code == 422 and "tegishli emas" in foreign_photo.json()["detail"]
    assert short.status_code == 422 and bad_rating.status_code == 422
    assert guest_list.status_code in (401, 403)
    assert mine_done


@pytest.mark.asyncio
async def test_an_admin_enters_a_review_sent_elsewhere(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    admin = await register(client, "rev-admin2@example.com")
    await make_admin(session_factory, admin["id"])
    photo = await upload(client, storage, "design", png((10, 10)))

    review = ok(await client.post("/api/admin/reviews/", json={
        "name": "Madina", "city": "Samarqand", "rating": 5, "text": TEXT, "photo_ids": [photo],
    }), 201)
    unknown_product = await client.post("/api/admin/reviews/", json={"name": "A", "rating": 4, "text": TEXT, "product_slug": "yoq"})
    hidden = ok(await client.patch(f"/api/admin/reviews/{review['id']}/", json={"status": "rejected"}))
    deleted = await client.delete(f"/api/admin/reviews/{review['id']}/")

    assert review["status"] == "approved" and review["from_customer"] is False
    assert unknown_product.status_code == 422
    assert hidden["status"] == "rejected"
    assert deleted.status_code == 204 and ok(await client.get("/api/reviews/")) == []


@pytest.mark.asyncio
async def test_customers_cancel_only_new_orders(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    customer = await register(client, "cancel@example.com")
    new = await order_for(session_factory, customer["id"], "NEW", "C-1")
    started = await order_for(session_factory, customer["id"], "IN_PRODUCTION", "C-2")

    assert (await client.post(f"/api/orders/{new}/cancel/")).status_code == 200
    refused = await client.post(f"/api/orders/{started}/cancel/")
    assert refused.status_code == 422 and "yangi" in refused.json()["detail"]
