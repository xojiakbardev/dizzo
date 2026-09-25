"""Role checks that `is_staff` used to wave through.

`users.is_staff` is a legacy flag that is True for every non-customer
account, so anywhere it stood in front of a role check — `require_roles`
itself, the branch roster, the per-order branch scope — a branch worker
passed. These tests pin the rule that only `user.role` decides, that a
branch account is confined to its own branch, and that a branch roster can
never hand out a global role.
"""

import httpx
import pytest
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.config import Settings
from app.models.branch import Branch
from app.models.commerce import Order, OrderItem
from app.models.user import User
from tests.conftest import register

PASSWORD = "password123"

GOOD_SECRET = "a-real-production-secret-of-at-least-32-chars"


async def make_branch(session_factory: async_sessionmaker[AsyncSession], slug: str) -> int:
    async with session_factory() as session:
        branch = Branch(
            name=f"Filial {slug}", slug=slug, address="Test ko'chasi 1", latitude=41.31, longitude=69.24
        )
        session.add(branch)
        await session.commit()
        return branch.id


async def set_role(
    session_factory: async_sessionmaker[AsyncSession], user_id: int, role: str, branch_id: int | None = None
) -> None:
    """The legacy flag is set too — that is exactly the state the holes lived in."""
    async with session_factory() as session:
        user = await session.get(User, user_id)
        user.role = role
        user.is_staff = role != "customer"
        user.branch_id = branch_id
        await session.commit()


async def staff(
    client: httpx.AsyncClient,
    session_factory: async_sessionmaker[AsyncSession],
    email: str,
    role: str,
    branch_id: int | None = None,
) -> dict:
    user = await register(client, email)
    await set_role(session_factory, user["id"], role, branch_id)
    client.cookies.clear()
    return user


async def bearer(client: httpx.AsyncClient, email: str) -> dict[str, str]:
    response = await client.post("/api/auth/login/", json={"email": email, "password": PASSWORD})
    assert response.status_code == 200, response.text
    client.cookies.clear()  # a cookie would win over the header
    return {"authorization": f"Bearer {response.json()['access_token']}"}


async def order_at(
    session_factory: async_sessionmaker[AsyncSession], customer_id: int, branch_id: int | None, number: str
) -> tuple[int, int]:
    async with session_factory() as session:
        order = Order(
            order_number=number, customer_id=customer_id, status="NEW", total_amount=65000, branch_id=branch_id,
            shipping_name="Xaridor", shipping_phone="+998901112233",
        )
        order.items.append(OrderItem(product_name="Krujka", product_slug="krujka", quantity=1, unit_price=65000))
        session.add(order)
        await session.commit()
        return order.id, order.items[0].id


async def role_of(session_factory: async_sessionmaker[AsyncSession], user_id: int) -> str:
    async with session_factory() as session:
        return (await session.get(User, user_id)).role


# ── require_roles is not a no-op any more ──


@pytest.mark.asyncio
async def test_a_branch_worker_cannot_read_the_customer_list(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    branch = await make_branch(session_factory, "chilonzor")
    await staff(client, session_factory, "worker-list@example.com", "branch_worker", branch)
    worker = await bearer(client, "worker-list@example.com")

    refused = await client.get("/api/users/admin/list/", headers=worker)

    assert refused.status_code == 403, refused.text
    assert refused.json()["detail"] == "Ruxsat yo'q"


@pytest.mark.asyncio
async def test_a_branch_worker_cannot_write_the_admin_catalog(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    branch = await make_branch(session_factory, "yunusobod")
    await staff(client, session_factory, "worker-catalog@example.com", "branch_worker", branch)
    worker = await bearer(client, "worker-catalog@example.com")

    refused = await client.post(
        "/api/admin/catalog/categories/", json={"name": "Yangi bo'lim", "slug": "yangi-bolim"}, headers=worker
    )

    assert refused.status_code == 403, refused.text


@pytest.mark.asyncio
async def test_a_branch_worker_cannot_moderate_the_gallery(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    branch = await make_branch(session_factory, "sergeli")
    await staff(client, session_factory, "worker-gallery@example.com", "branch_worker", branch)
    worker = await bearer(client, "worker-gallery@example.com")

    gallery = await client.get("/api/admin/gallery/", headers=worker)
    create = await client.post(
        "/api/admin/gallery/",
        json={"product_id": 1, "media_ids": ["aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"]},
        headers=worker,
    )

    assert gallery.status_code == 200, gallery.text
    assert gallery.json() == []
    assert create.status_code == 403, create.text
    submit = await client.post(
        "/api/admin/gallery/submit/", json={"product_id": 1, "media_ids": []}, headers=worker
    )
    assert submit.status_code == 422, submit.text


# ── The branch roster hands out branch roles only ──


@pytest.mark.asyncio
async def test_a_branch_worker_cannot_assign_roles_or_promote_itself(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    branch = await make_branch(session_factory, "olmazor")
    other = await make_branch(session_factory, "mirzo-ulugbek")
    me = await staff(client, session_factory, "climber@example.com", "branch_worker", branch)
    worker = await bearer(client, "climber@example.com")

    # The headline hole: POST my own id with role super_admin.
    coup = await client.post(
        f"/api/branches/{branch}/workers", json={"user_id": me["id"], "role": "super_admin"}, headers=worker
    )
    # Any other branch is no better, and neither is a role the schema allows.
    elsewhere = await client.post(
        f"/api/branches/{other}/workers", json={"user_id": me["id"], "role": "super_admin"}, headers=worker
    )
    allowed_role = await client.post(
        f"/api/branches/{branch}/workers", json={"user_id": me["id"], "role": "branch_admin"}, headers=worker
    )
    roster = await client.get(f"/api/branches/{branch}/workers", headers=worker)

    # 422 (the schema refuses the role) or 403 (the role check does) — never 200.
    assert coup.status_code in (403, 422), coup.text
    assert elsewhere.status_code in (403, 422), elsewhere.text
    assert allowed_role.status_code == 403, allowed_role.text
    assert roster.status_code == 403  # a worker doesn't even read the roster
    assert await role_of(session_factory, me["id"]) == "branch_worker"


@pytest.mark.asyncio
async def test_a_branch_manager_hands_out_branch_roles_only(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    branch = await make_branch(session_factory, "shayxontohur")
    boss = await staff(client, session_factory, "manager@example.com", "branch_manager", branch)
    hire = await register(client, "hire@example.com")
    client.cookies.clear()
    mod = await staff(client, session_factory, "global-mod@example.com", "moderator")
    manager = await bearer(client, "manager@example.com")

    promote_self = await client.post(
        f"/api/branches/{branch}/workers", json={"user_id": boss["id"], "role": "branch_admin"}, headers=manager
    )
    global_role = await client.post(
        f"/api/branches/{branch}/workers", json={"user_id": hire["id"], "role": "super_admin"}, headers=manager
    )
    demote_moderator = await client.post(
        f"/api/branches/{branch}/workers", json={"user_id": mod["id"], "role": "branch_worker"}, headers=manager
    )
    hired = await client.post(
        f"/api/branches/{branch}/workers", json={"user_id": hire["id"], "role": "branch_admin"}, headers=manager
    )

    assert promote_self.status_code == 403  # never yourself
    assert global_role.status_code == 422  # the schema knows only branch roles
    assert demote_moderator.status_code == 403  # a global role is an admin's business
    # A manager's grant is coerced down to branch_worker, whatever was asked for.
    assert hired.status_code == 200 and hired.json()["role"] == "branch_worker"
    assert await role_of(session_factory, boss["id"]) == "branch_manager"
    assert await role_of(session_factory, mod["id"]) == "moderator"


@pytest.mark.asyncio
async def test_a_role_change_from_the_roster_signs_the_worker_out(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    branch = await make_branch(session_factory, "bektemir")
    await staff(client, session_factory, "roster-boss@example.com", "branch_admin", branch)
    hire = await register(client, "roster-hire@example.com")
    client.cookies.clear()
    hire_token = await bearer(client, "roster-hire@example.com")
    boss = await bearer(client, "roster-boss@example.com")

    assert (await client.get("/api/auth/me", headers=hire_token)).status_code == 200
    assert (
        await client.post(
            f"/api/branches/{branch}/workers", json={"user_id": hire["id"], "role": "branch_worker"}, headers=boss
        )
    ).status_code == 200

    assert (await client.get("/api/auth/me", headers=hire_token)).status_code == 401


# ── Branch scoping on orders is live code again ──


@pytest.mark.asyncio
@pytest.mark.usefixtures("storage")
async def test_a_branch_worker_only_reaches_its_own_branchs_orders(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    mine = await make_branch(session_factory, "branch-mine")
    theirs = await make_branch(session_factory, "branch-theirs")
    customer = await register(client, "buyer@example.com")
    client.cookies.clear()
    await staff(client, session_factory, "scoped@example.com", "branch_worker", mine)
    worker = await bearer(client, "scoped@example.com")
    ours, our_item = await order_at(session_factory, customer["id"], mine, "B-MINE")
    other, other_item = await order_at(session_factory, customer["id"], theirs, "B-THEIRS")
    loose, _loose_item = await order_at(session_factory, customer["id"], None, "B-NONE")

    own = await client.get(f"/api/orders/admin/orders/{ours}/", headers=worker)
    foreign = await client.get(f"/api/orders/admin/orders/{other}/", headers=worker)
    unbranched = await client.get(f"/api/orders/admin/orders/{loose}/", headers=worker)
    edit_foreign = await client.patch(
        f"/api/orders/admin/orders/{other}/", json={"status": "PAYMENT_PENDING"}, headers=worker
    )
    edit_foreign_item = await client.patch(
        f"/api/orders/admin/orders/{other}/items/{other_item}/",
        json={"production_status": "PRINTING"}, headers=worker,
    )
    edit_own_item = await client.patch(
        f"/api/orders/admin/orders/{ours}/items/{our_item}/",
        json={"production_status": "PRINTING"}, headers=worker,
    )
    missing_order = await client.patch(
        "/api/orders/admin/orders/999999/items/1/", json={"production_status": "PRINTING"}, headers=worker
    )

    assert own.status_code == 200, own.text
    assert own.json()["order_number"] == "B-MINE"
    assert foreign.status_code == 403, foreign.text
    assert "filialingiz" in foreign.json()["detail"]
    assert unbranched.status_code == 403  # a NULL branch is nobody's branch
    assert edit_foreign.status_code == 403
    assert edit_foreign_item.status_code == 403  # the item route checked nothing at all
    assert edit_own_item.status_code == 200, edit_own_item.text
    assert missing_order.status_code == 404  # 404 before order.items is touched


# ── Credentials ──


@pytest.mark.asyncio
async def test_set_credentials_is_refused_when_a_password_exists(client: httpx.AsyncClient) -> None:
    await register(client, "has-password@example.com")

    refused = await client.post(
        "/api/auth/set-credentials/", json={"email": "taken-over@example.com", "password": "brand-new-pass-1"}
    )

    assert refused.status_code == 409, refused.text
    assert refused.json()["detail"] == "Hisobingizda parol allaqachon o'rnatilgan"
    # The email is untouched and the old password still signs in.
    assert (await client.post(
        "/api/auth/login/", json={"email": "has-password@example.com", "password": PASSWORD}
    )).status_code == 200


# ── Configuration ──


def test_production_refuses_the_placeholder_jwt_secret() -> None:
    safe = dict(environment="production", jwt_secret_key=GOOD_SECRET, cookie_secure=True, debug=False)

    # A correctly configured production boot still works.
    assert Settings(**safe).is_production

    with pytest.raises(ValidationError, match="JWT_SECRET_KEY"):
        Settings(**{**safe, "jwt_secret_key": "change-me-in-local"})
    with pytest.raises(ValidationError, match="JWT_SECRET_KEY"):
        Settings(**{**safe, "jwt_secret_key": "too-short"})
    with pytest.raises(ValidationError, match="COOKIE_SECURE"):
        Settings(**{**safe, "cookie_secure": False})
    with pytest.raises(ValidationError, match="DEBUG"):
        Settings(**{**safe, "debug": True})

    # Development is left alone: the placeholder is what a local run uses.
    assert Settings(environment="development").jwt_secret_key == "change-me-in-local"


# ── Telegram: a worker's own name reaches the moderators as text ──


@pytest.mark.asyncio
async def test_a_workers_name_cannot_inject_html_into_the_moderator_group(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from app.services import telegram_notify

    sent: list[tuple[object, str]] = []

    async def fake_send(chat_id: object, text: str, reply_markup: dict | None = None) -> None:
        sent.append((chat_id, text))

    monkeypatch.setattr(telegram_notify, "_send_message", fake_send)

    await telegram_notify.notify_gallery_submission(
        item_id=7,
        product_name="Krujka & Co",
        worker_name='<a href="https://evil.example/login">Admin</a>',
        branch_name="<b>Filial</b>",
        title="5 < 6",
        group_id="-100123",
    )

    (chat_id, text), = sent
    assert chat_id == "-100123"
    assert "evil.example" in text  # the text is still there…
    assert '<a href=' not in text  # …but not as a link
    assert "&lt;a href=&quot;https://evil.example/login&quot;&gt;Admin&lt;/a&gt;" in text
    assert "Krujka &amp; Co" in text and "&lt;b&gt;Filial&lt;/b&gt;" in text and "5 &lt; 6" in text
    # The message's own markup is untouched.
    assert text.startswith("🎨 <b>Yangi galereya namunasi tekshiruv uchun!</b>")
