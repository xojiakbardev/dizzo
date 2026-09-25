from decimal import Decimal
import hashlib
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.config import get_settings
from app.models.commerce import Order, Payment
from app.models.user import User
from app.services.payments.click import (
    CLICK_ALREADY_PAID,
    CLICK_BAD_REQUEST,
    CLICK_INVALID_AMOUNT,
    CLICK_ORDER_NOT_FOUND,
    CLICK_SIGN_CHECK_FAILED,
    CLICK_SUCCESS,
    CLICK_TRANSACTION_CANCELLED,
    CLICK_TRANSACTION_NOT_FOUND,
    ClickService,
)


@pytest.fixture
def click_settings(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("CLICK_SERVICE_ID", "12345")
    monkeypatch.setenv("CLICK_MERCHANT_ID", "67890")
    monkeypatch.setenv("CLICK_SECRET_KEY", "secret_click_key")
    monkeypatch.setenv("CLICK_MERCHANT_USER_ID", "9999")
    get_settings.cache_clear()
    yield get_settings()
    get_settings.cache_clear()


@pytest.fixture
async def sample_order(session_factory: async_sessionmaker[AsyncSession]) -> Order:
    async with session_factory() as session:
        user = User(
            email="clicker@dizzo.uz",
            password_hash="fake",
            first_name="Click",
            last_name="Tester",
            phone_number="+998901234567",
        )
        session.add(user)
        await session.flush()

        order = Order(
            order_number="0009999",
            customer_id=user.id,
            status="NEW",
            total_amount=Decimal("150000.00"),
            shipping_name="Click Tester",
            shipping_phone="+998901234567",
        )
        session.add(order)
        await session.commit()
        await session.refresh(order)
        return order


def make_prepare_sign(click_trans_id, service_id, secret_key, merchant_trans_id, amount, action, sign_time):
    raw = f"{click_trans_id}{service_id}{secret_key}{merchant_trans_id}{amount}{action}{sign_time}"
    return hashlib.md5(raw.encode("utf-8")).hexdigest()


def make_complete_sign(click_trans_id, service_id, secret_key, merchant_trans_id, merchant_prepare_id, amount, action, sign_time):
    raw = f"{click_trans_id}{service_id}{secret_key}{merchant_trans_id}{merchant_prepare_id}{amount}{action}{sign_time}"
    return hashlib.md5(raw.encode("utf-8")).hexdigest()


@pytest.mark.anyio
async def test_click_payment_url_generation(click_settings, sample_order):
    service = ClickService(click_settings)
    url = service.generate_payment_url(sample_order)
    assert "https://my.click.uz/services/pay?" in url
    assert "service_id=12345" in url
    assert "merchant_id=67890" in url
    assert "amount=150000" in url
    assert "transaction_param=0009999" in url
    assert "merchant_user_id=9999" in url


@pytest.mark.anyio
async def test_click_prepare_and_complete_flow(client: AsyncClient, click_settings, sample_order, session_factory):
    # 1. Prepare with valid data
    sign_time = "2026-09-17 12:00:00"
    amount = "150000.00"
    sign = make_prepare_sign(
        click_trans_id="111222",
        service_id=click_settings.click_service_id,
        secret_key=click_settings.click_secret_key,
        merchant_trans_id=sample_order.order_number,
        amount=amount,
        action="0",
        sign_time=sign_time,
    )

    prepare_payload = {
        "click_trans_id": 111222,
        "service_id": int(click_settings.click_service_id),
        "click_paydoc_id": 333444,
        "merchant_trans_id": sample_order.order_number,
        "amount": 150000.00,
        "action": 0,
        "error": 0,
        "error_note": "Success",
        "sign_time": sign_time,
        "sign_string": sign,
    }

    res = await client.post("/api/payments/click/prepare", json=prepare_payload)
    assert res.status_code == 200
    data = res.json()
    assert data["error"] == CLICK_SUCCESS
    prepare_id = data["merchant_prepare_id"]
    assert prepare_id is not None

    # Verify Payment row created in DB
    async with session_factory() as session:
        payment = await session.get(Payment, prepare_id)
        assert payment is not None
        assert payment.order_id == sample_order.id
        assert payment.status == "PENDING"
        assert payment.provider_trans_id == "111222"

    # 2. Complete with valid data
    complete_sign_time = "2026-09-17 12:00:10"
    complete_sign = make_complete_sign(
        click_trans_id="111222",
        service_id=click_settings.click_service_id,
        secret_key=click_settings.click_secret_key,
        merchant_trans_id=sample_order.order_number,
        merchant_prepare_id=prepare_id,
        amount=amount,
        action="1",
        sign_time=complete_sign_time,
    )

    complete_payload = {
        "click_trans_id": 111222,
        "service_id": int(click_settings.click_service_id),
        "click_paydoc_id": 333444,
        "merchant_trans_id": sample_order.order_number,
        "merchant_prepare_id": prepare_id,
        "amount": 150000.00,
        "action": 1,
        "error": 0,
        "error_note": "Success",
        "sign_time": complete_sign_time,
        "sign_string": complete_sign,
    }

    res2 = await client.post("/api/payments/click/complete", json=complete_payload)
    assert res2.status_code == 200
    data2 = res2.json()
    assert data2["error"] == CLICK_SUCCESS
    assert data2["merchant_confirm_id"] == prepare_id

    # Verify Order and Payment updated to PAID
    async with session_factory() as session:
        updated_order = await session.get(Order, sample_order.id)
        assert updated_order.status == "PAID"
        updated_payment = await session.get(Payment, prepare_id)
        assert updated_payment.status == "PAID"


@pytest.mark.anyio
async def test_click_invalid_signature(client: AsyncClient, click_settings, sample_order):
    payload = {
        "click_trans_id": 999,
        "service_id": 12345,
        "merchant_trans_id": sample_order.order_number,
        "amount": 150000.00,
        "action": 0,
        "sign_time": "2026-09-17 12:00:00",
        "sign_string": "wrong_hash",
    }
    res = await client.post("/api/payments/click/prepare", json=payload)
    assert res.status_code == 200
    assert res.json()["error"] == CLICK_SIGN_CHECK_FAILED


@pytest.mark.anyio
async def test_click_order_not_found(client: AsyncClient, click_settings):
    sign_time = "2026-09-17 12:00:00"
    sign = make_prepare_sign("123", "12345", click_settings.click_secret_key, "non_existent", "50000", "0", sign_time)
    payload = {
        "click_trans_id": 123,
        "service_id": 12345,
        "merchant_trans_id": "non_existent",
        "amount": 50000,
        "action": 0,
        "sign_time": sign_time,
        "sign_string": sign,
    }
    res = await client.post("/api/payments/click/prepare", json=payload)
    assert res.json()["error"] == CLICK_ORDER_NOT_FOUND


@pytest.mark.anyio
async def test_click_incorrect_amount(client: AsyncClient, click_settings, sample_order):
    sign_time = "2026-09-17 12:00:00"
    wrong_amount = "50000.00"
    sign = make_prepare_sign("123", "12345", click_settings.click_secret_key, sample_order.order_number, wrong_amount, "0", sign_time)
    payload = {
        "click_trans_id": 123,
        "service_id": 12345,
        "merchant_trans_id": sample_order.order_number,
        "amount": wrong_amount,
        "action": 0,
        "sign_time": sign_time,
        "sign_string": sign,
    }
    res = await client.post("/api/payments/click/prepare", json=payload)
    assert res.json()["error"] == CLICK_INVALID_AMOUNT


@pytest.mark.anyio
async def test_click_cancellation(client: AsyncClient, click_settings, sample_order):
    # Prepare first
    sign_time = "2026-09-17 12:00:00"
    amount = "150000.00"
    sign = make_prepare_sign("555", click_settings.click_service_id, click_settings.click_secret_key, sample_order.order_number, amount, "0", sign_time)
    prep_res = await client.post("/api/payments/click/prepare", json={
        "click_trans_id": 555,
        "service_id": int(click_settings.click_service_id),
        "click_paydoc_id": 777,
        "merchant_trans_id": sample_order.order_number,
        "amount": 150000.00,
        "action": 0,
        "sign_time": sign_time,
        "sign_string": sign,
    })
    prep_id = prep_res.json()["merchant_prepare_id"]

    # Complete with error < 0 (Click cancellation)
    comp_sign = make_complete_sign("555", click_settings.click_service_id, click_settings.click_secret_key, sample_order.order_number, prep_id, amount, "1", sign_time)
    cancel_res = await client.post("/api/payments/click/complete", json={
        "click_trans_id": 555,
        "service_id": int(click_settings.click_service_id),
        "click_paydoc_id": 777,
        "merchant_trans_id": sample_order.order_number,
        "merchant_prepare_id": prep_id,
        "amount": 150000.00,
        "action": 1,
        "error": -5017,  # Click error code for user cancelled
        "sign_time": sign_time,
        "sign_string": comp_sign,
    })
    assert cancel_res.json()["error"] == CLICK_TRANSACTION_CANCELLED


@pytest.mark.anyio
async def test_get_payment_url_endpoint(client: AsyncClient, click_settings, sample_order, session_factory):
    from app.core.security import create_access_token

    # Authenticated as the order owner
    token = create_access_token(sample_order.customer_id)
    res = await client.get(
        f"/api/payments/click/url/{sample_order.order_number}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 200
    data = res.json()
    assert "https://my.click.uz/services/pay?" in data["payment_url"]
    assert data["order_number"] == sample_order.order_number
    assert data["amount"] == "150000.00"

    # Other user forbidden
    async with session_factory() as session:
        other_user = User(
            email="other@dizzo.uz",
            password_hash="fake",
            first_name="Other",
            last_name="User",
            phone_number="+998909876543",
        )
        session.add(other_user)
        await session.commit()
        await session.refresh(other_user)
        other_user_id = other_user.id

    other_token = create_access_token(other_user_id)
    res_forbidden = await client.get(
        f"/api/payments/click/url/{sample_order.order_number}",
        headers={"Authorization": f"Bearer {other_token}"},
    )
    assert res_forbidden.status_code == 403

    # Already paid order
    async with session_factory() as session:
        ord_obj = await session.get(Order, sample_order.id)
        ord_obj.status = "PAID"
        await session.commit()

    res_paid = await client.get(
        f"/api/payments/click/url/{sample_order.order_number}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_paid.status_code == 400
    assert "allaqachon to'langan" in res_paid.json()["detail"]

    # Cancelled order
    async with session_factory() as session:
        ord_obj = await session.get(Order, sample_order.id)
        ord_obj.status = "CANCELLED"
        await session.commit()

    res_cancelled = await client.get(
        f"/api/payments/click/url/{sample_order.order_number}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_cancelled.status_code == 400
    assert "bekor qilingan" in res_cancelled.json()["detail"]



async def prepared(client: AsyncClient, click_settings, order, click_trans_id: str = "424242") -> int:
    """A signed, accepted Prepare; returns its merchant_prepare_id."""
    sign_time = "2026-09-17 12:00:00"
    sign = make_prepare_sign(
        click_trans_id, click_settings.click_service_id, click_settings.click_secret_key,
        order.order_number, "150000.00", "0", sign_time,
    )
    res = await client.post("/api/payments/click/prepare", json={
        "click_trans_id": int(click_trans_id),
        "service_id": int(click_settings.click_service_id),
        "click_paydoc_id": 1,
        "merchant_trans_id": order.order_number,
        "amount": 150000.00,
        "action": 0,
        "sign_time": sign_time,
        "sign_string": sign,
    })
    assert res.json()["error"] == CLICK_SUCCESS, res.text
    return res.json()["merchant_prepare_id"]


def complete_body(click_settings, order, prepare_id, amount: str, merchant_trans_id: str | None = None) -> dict:
    """A correctly signed Complete — the signature covers whatever is passed,
    so only the server's own re-checks can refuse it."""
    sign_time = "2026-09-17 12:05:00"
    trans = order.order_number if merchant_trans_id is None else merchant_trans_id
    return {
        "click_trans_id": 424242,
        "service_id": int(click_settings.click_service_id),
        "click_paydoc_id": 1,
        "merchant_trans_id": trans,
        "merchant_prepare_id": prepare_id,
        "amount": amount,
        "action": 1,
        "error": 0,
        "sign_time": sign_time,
        "sign_string": make_complete_sign(
            "424242", click_settings.click_service_id, click_settings.click_secret_key,
            trans, prepare_id, amount, "1", sign_time,
        ),
    }


@pytest.mark.anyio
async def test_complete_refuses_an_amount_that_is_not_the_orders(
    client: AsyncClient, click_settings, sample_order, session_factory
):
    """A signed Complete for 1 000 so'm must not pay off a 150 000 so'm order."""
    prepare_id = await prepared(client, click_settings, sample_order)

    res = await client.post(
        "/api/payments/click/complete",
        json=complete_body(click_settings, sample_order, prepare_id, "1000.00"),
    )

    assert res.json()["error"] == CLICK_INVALID_AMOUNT
    async with session_factory() as session:
        assert (await session.get(Order, sample_order.id)).status != "PAID"
        assert (await session.get(Payment, prepare_id)).status == "PENDING"


@pytest.mark.anyio
async def test_complete_refuses_a_prepare_id_from_another_order(
    client: AsyncClient, click_settings, sample_order, session_factory
):
    """merchant_trans_id and merchant_prepare_id have to name the same order."""
    prepare_id = await prepared(client, click_settings, sample_order)

    res = await client.post(
        "/api/payments/click/complete",
        json=complete_body(click_settings, sample_order, prepare_id, "150000.00", merchant_trans_id="0000001"),
    )

    assert res.json()["error"] == CLICK_ORDER_NOT_FOUND
    async with session_factory() as session:
        assert (await session.get(Order, sample_order.id)).status != "PAID"


@pytest.mark.anyio
async def test_complete_survives_a_non_numeric_prepare_id(client: AsyncClient, click_settings, sample_order):
    """`int(merchant_prepare_id)` used to raise straight out of the webhook."""
    res = await client.post(
        "/api/payments/click/complete",
        json=complete_body(click_settings, sample_order, "not-a-number", "150000.00"),
    )

    assert res.status_code == 200
    assert res.json()["error"] == CLICK_BAD_REQUEST


@pytest.mark.anyio
async def test_a_webhook_for_another_click_service_is_refused(client: AsyncClient, click_settings, sample_order):
    """The signature covers service_id, but nothing compared it to ours."""
    sign_time = "2026-09-17 12:00:00"
    sign = make_prepare_sign(
        "777", "99999", click_settings.click_secret_key, sample_order.order_number, "150000.00", "0", sign_time
    )
    res = await client.post("/api/payments/click/prepare", json={
        "click_trans_id": 777,
        "service_id": 99999,
        "merchant_trans_id": sample_order.order_number,
        "amount": 150000.00,
        "action": 0,
        "sign_time": sign_time,
        "sign_string": sign,
    })

    assert res.json()["error"] == CLICK_BAD_REQUEST
