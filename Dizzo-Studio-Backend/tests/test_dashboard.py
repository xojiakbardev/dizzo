from decimal import Decimal

import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from tests.conftest import FakeStorage, register
from tests.test_catalog import ok
from tests.test_privilege_escalation import bearer, make_branch, order_at, staff
from tests.test_studio import UV_LAYER, UV_PX, cart_item, document, png, shop


async def login(client: httpx.AsyncClient, email: str) -> None:
    await client.post("/api/auth/logout/")
    ok(await client.post("/api/auth/login/", json={"email": email, "password": "password123"}))


@pytest.mark.asyncio
async def test_dashboard_summarises_the_period(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    ok(await client.post("/api/studio/designs/", json={
        "variant_id": s["variant_id"], "color_id": s["black"], "document": document(UV_LAYER),
    }), 201)
    body = png(UV_PX, (500, 60, 2000, 860, (200, 30, 40, 255)))
    ok(await cart_item(client, storage, s, [("wrap", "uv", body)], UV_LAYER, expected="149000"), 201)
    order = ok(await client.post("/api/checkout/", json={"contact_name": "Test", "delivery_method": "PICKUP"}))
    forbidden = await client.get("/api/admin/dashboard/")

    await login(client, "shop-admin@example.com")
    unpaid = ok(await client.get("/api/admin/dashboard/", params={"days": 7}))
    ok(await client.patch(f"/api/orders/admin/orders/{order['order_id']}/", json={"status": "PAID"}))
    board = ok(await client.get("/api/admin/dashboard/", params={"days": 7}))

    assert forbidden.status_code == 403
    assert board["scope"] == {"kind": "shop"}
    assert Decimal(unpaid["summary"]["revenue"]["current"]) == 0  # a NEW order isn't revenue yet
    summary = board["summary"]
    assert summary["orders"] == {"current": 1, "previous": 0}
    assert Decimal(summary["revenue"]["current"]) == Decimal("298000")
    assert Decimal(summary["avg_order"]["current"]) == Decimal("298000")
    assert summary["items_sold"]["current"] == 2
    assert summary["new_customers"]["current"] == 1  # the admin isn't a customer
    assert summary["designs"]["current"] == 1
    assert board["conversion"] == {"designers": 1, "buyers": 1}
    assert board["open_carts"]["carts"] == 0  # checkout emptied the cart
    assert board["reviews_pending"] == 0
    assert len(board["by_day"]) == 7 and board["by_day"][-1]["orders"] == 1
    assert Decimal(board["by_day"][-1]["revenue"]) == Decimal("298000")
    assert {r["status"]: r["count"] for r in board["pipeline"]}["PAID"] == 1
    assert {r["method"]: r["count"] for r in board["orders_by_delivery_method"]} == {"DELIVERY": 0, "PICKUP": 1}
    [product] = board["top_products"]
    assert product["product_slug"] == "krujka" and product["units_sold"] == 2
    [variant] = board["top_variants"]
    assert variant["variant_name"] == "Xameleon" and Decimal(variant["revenue"]) == Decimal("298000")


@pytest.mark.asyncio
async def test_dashboard_period_is_bounded(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    await shop(client, storage, session_factory)
    await login(client, "shop-admin@example.com")

    too_long = await client.get("/api/admin/dashboard/", params={"days": 365})
    empty = ok(await client.get("/api/admin/dashboard/", params={"days": 30}))

    assert too_long.status_code == 422
    assert len(empty["by_day"]) == 30 and empty["top_products"] == [] and empty["summary"]["orders"]["current"] == 0


HQ_ROLES = ("customer", "moderator", "admin", "super_admin")
SHOP_ONLY = ("conversion", "open_carts", "reviews_pending")


@pytest.mark.asyncio
async def test_a_branch_cannot_be_given_head_office_roles(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    branch = await make_branch(session_factory, "yakkasaroy")
    await staff(client, session_factory, "boss-roles@example.com", "super_admin")
    boss = await bearer(client, "boss-roles@example.com")
    body = {"email": "filialchi@example.com", "password": "password123", "first_name": "Ali", "branch_id": branch}

    for role in HQ_ROLES:
        refused = await client.post(
            "/api/users/admin/create/", json={**body, "email": f"{role}@example.com", "role": role}, headers=boss
        )
        assert refused.status_code == 422, (role, refused.text)

    created = ok(
        await client.post(
            "/api/users/admin/create/",
            json={**body, "email": "worker-ok@example.com", "role": "branch_worker"},
            headers=boss,
        ),
        201,
    )
    assert created["role"] == "branch_worker" and created["branch_id"] == branch

    no_branch = await client.post(
        "/api/users/admin/create/",
        json={"email": "homeless@example.com", "password": "password123", "role": "branch_manager"},
        headers=boss,
    )
    assert no_branch.status_code == 422, no_branch.text


@pytest.mark.asyncio
async def test_changing_role_keeps_branch_and_head_office_apart(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    branch = await make_branch(session_factory, "uchtepa")
    await staff(client, session_factory, "boss-patch@example.com", "super_admin")
    customer = await register(client, "to-promote@example.com")
    boss = await bearer(client, "boss-patch@example.com")
    url = f"/api/users/admin/{customer['id']}/role/"

    assert (await client.patch(url, json={"role": "admin", "branch_id": branch}, headers=boss)).status_code == 422
    promoted = ok(await client.patch(url, json={"role": "branch_admin", "branch_id": branch}, headers=boss))
    assert promoted["role"] == "branch_admin" and promoted["branch_id"] == branch
    assert (await client.patch(url, json={"role": "moderator"}, headers=boss)).status_code == 422
    cleared = ok(await client.patch(url, json={"role": "moderator", "branch_id": None}, headers=boss))
    assert cleared["role"] == "moderator" and cleared["branch_id"] is None


@pytest.mark.asyncio
async def test_branch_dashboard_is_scoped_and_hides_shop_figures(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    mine = await make_branch(session_factory, "mirabad")
    other = await make_branch(session_factory, "bektemir")
    customer = await register(client, "buyer-dash@example.com")
    await order_at(session_factory, customer["id"], mine, "MINE-1")
    await order_at(session_factory, customer["id"], other, "OTHER-1")
    await staff(client, session_factory, "dash-worker@example.com", "branch_worker", mine)
    await staff(client, session_factory, "dash-lead@example.com", "branch_manager", mine)
    await staff(client, session_factory, "dash-admin@example.com", "branch_admin", mine)
    await staff(client, session_factory, "dash-homeless@example.com", "branch_worker")

    worker = await client.get("/api/admin/dashboard/", params={"days": 7}, headers=await bearer(client, "dash-worker@example.com"))
    lead = ok(await client.get("/api/admin/dashboard/", params={"days": 7}, headers=await bearer(client, "dash-lead@example.com")))
    branch_admin = ok(await client.get("/api/admin/dashboard/", params={"days": 7}, headers=await bearer(client, "dash-admin@example.com")))
    homeless = await client.get("/api/admin/dashboard/", headers=await bearer(client, "dash-homeless@example.com"))

    assert worker.status_code == 403, worker.text
    assert homeless.status_code == 403

    assert lead["scope"]["kind"] == "branch" and lead["scope"]["role"] == "branch_lead"
    assert lead["scope"]["branch_id"] == mine
    assert lead["summary"]["orders"]["current"] == 1
    assert "revenue" in lead["summary"] and "paid_orders" in lead["summary"]
    assert "top_products" in lead and "orders_by_delivery_method" in lead
    for key in SHOP_ONLY:
        assert key not in lead
    assert "new_customers" not in lead["summary"] and "designs" not in lead["summary"]
    assert lead["branch"]["workers"] >= 2
    assert branch_admin["scope"]["role"] == "branch_lead" and "revenue" in branch_admin["summary"]
