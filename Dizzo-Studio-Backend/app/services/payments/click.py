from __future__ import annotations

from decimal import Decimal
import hashlib
import hmac
import logging
from typing import Any
from urllib.parse import urlencode

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.models.commerce import Order, Payment
from app.services.orders import OrderStatus

logger = logging.getLogger("app.payments.click")

# Click error response codes
CLICK_SUCCESS = 0
CLICK_SIGN_CHECK_FAILED = -1
CLICK_INVALID_AMOUNT = -2
CLICK_ACTION_NOT_FOUND = -3
CLICK_ALREADY_PAID = -4
CLICK_ORDER_NOT_FOUND = -5
CLICK_TRANSACTION_NOT_FOUND = -6
CLICK_UPDATE_FAILED = -7
CLICK_BAD_REQUEST = -8
CLICK_TRANSACTION_CANCELLED = -9


class ClickService:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.service_id = str(settings.click_service_id or "").strip()
        self.merchant_id = str(settings.click_merchant_id or "").strip()
        self.secret_key = str(settings.click_secret_key or "").strip()
        self.merchant_user_id = str(settings.click_merchant_user_id or "").strip()

    def generate_payment_url(self, order: Order, return_url: str | None = None) -> str:
        """Generate checkout redirect URL for Click."""
        amount_val = f"{order.total_amount:.2f}".rstrip("0").rstrip(".")
        ret_url = return_url or f"{self.settings.frontend_url}/user/orders/{order.order_number}?payment=success"
        params = {
            "service_id": self.service_id,
            "merchant_id": self.merchant_id,
            "amount": amount_val,
            "transaction_param": order.order_number,
            "return_url": ret_url,
        }
        if self.merchant_user_id:
            params["merchant_user_id"] = self.merchant_user_id
        return f"https://my.click.uz/services/pay?{urlencode(params)}"

    def service_id_matches(self, service_id: str | int) -> bool:
        """The webhook must name the service this merchant account is
        configured for; an unconfigured service_id matches nothing."""
        return bool(self.service_id) and str(service_id).strip() == self.service_id

    def _extract_merchant_trans_id(self, data: dict[str, Any]) -> str:
        """Extract order number/merchant_trans_id from standard or custom Click fields."""
        if val := data.get("merchant_trans_id"):
            return str(val).strip()
        if val := data.get("transaction_param"):
            return str(val).strip()
        if val := data.get("order_id"):
            return str(val).strip()
        if val := data.get("order_number"):
            return str(val).strip()
        if val := data.get("account"):
            return str(val).strip()
        if val := data.get("param"):
            return str(val).strip()
        # Fallback to any unknown key in the payload
        known = {
            "click_trans_id", "service_id", "click_paydoc_id", "amount",
            "action", "error", "error_note", "sign_time", "sign_string",
            "merchant_prepare_id", "merchant_confirm_id",
        }
        for k, v in data.items():
            if k not in known and v:
                return str(v).strip()
        return ""

    def verify_signature(
        self,
        *,
        click_trans_id: str | int,
        service_id: str | int,
        merchant_trans_id: str,
        amount: str | float | Decimal,
        action: str | int,
        sign_time: str,
        sign_string: str,
        merchant_prepare_id: str | int | None = None,
    ) -> bool:
        """Verify MD5 signature sent by Click using constant-time comparison."""
        if not self.secret_key:
            logger.error("Click secret key is not configured in settings")
            return False

        # Prepare candidate amount strings to handle Click formatting differences (15000, 15000.0, 15000.00)
        amount_candidates: list[str] = [str(amount).strip()]
        try:
            dec = Decimal(str(amount))
            amount_candidates.extend([
                f"{dec:.2f}",
                f"{dec:.1f}",
                f"{int(dec)}" if dec == int(dec) else str(dec),
                str(float(dec)),
            ])
        except Exception:
            pass

        candidates = list(dict.fromkeys(amount_candidates))
        target_sign = str(sign_string or "").lower().strip()

        for cand in candidates:
            if str(action) == "1" and merchant_prepare_id is not None:
                raw = (
                    f"{click_trans_id}{service_id}{self.secret_key}"
                    f"{merchant_trans_id}{merchant_prepare_id}{cand}{action}{sign_time}"
                )
            else:
                raw = (
                    f"{click_trans_id}{service_id}{self.secret_key}"
                    f"{merchant_trans_id}{cand}{action}{sign_time}"
                )
            expected = hashlib.md5(raw.encode("utf-8")).hexdigest()
            if hmac.compare_digest(expected.lower(), target_sign):
                return True

        logger.warning(
            "Click signature mismatch: click_trans_id=%s, service_id=%s, merchant_trans_id=%s, amount=%s, action=%s, sign_time=%s, received_sign=%s",
            click_trans_id, service_id, merchant_trans_id, amount, action, sign_time, target_sign
        )
        return False

    async def prepare(self, session: AsyncSession, data: dict[str, Any]) -> dict[str, Any]:
        """Handle Click Action 0 (Prepare). Checks order existence, amount, and returns prepare ID."""
        click_trans_id = str(data.get("click_trans_id", ""))
        service_id = str(data.get("service_id", ""))
        click_paydoc_id = str(data.get("click_paydoc_id", ""))
        merchant_trans_id = self._extract_merchant_trans_id(data)
        raw_amount = data.get("amount", "0")
        action = str(data.get("action", "0"))
        sign_time = str(data.get("sign_time", ""))
        sign_string = str(data.get("sign_string", ""))

        response: dict[str, Any] = {
            "click_trans_id": click_trans_id,
            "merchant_trans_id": merchant_trans_id,
            "merchant_prepare_id": None,
            "error": CLICK_SUCCESS,
            "error_note": "Success",
        }

        # 1. Verify signature
        if not self.verify_signature(
            click_trans_id=click_trans_id,
            service_id=service_id,
            merchant_trans_id=merchant_trans_id,
            amount=raw_amount,
            action=action,
            sign_time=sign_time,
            sign_string=sign_string,
        ):
            response["error"] = CLICK_SIGN_CHECK_FAILED
            response["error_note"] = "SIGN CHECK FAILED"
            return response

        # 1b. The signature covers service_id, but only comparing it to our
        # own rules out a request signed for a different Click service.
        if not self.service_id_matches(service_id):
            logger.warning("Click prepare with unexpected service_id=%s", service_id)
            response["error"] = CLICK_BAD_REQUEST
            response["error_note"] = "Incorrect parameter service_id"
            return response

        # 2. Check Action
        if action != "0":
            response["error"] = CLICK_ACTION_NOT_FOUND
            response["error_note"] = "Action not found"
            return response

        # 3. Parse Amount
        try:
            amount_dec = Decimal(str(raw_amount))
        except Exception:
            response["error"] = CLICK_INVALID_AMOUNT
            response["error_note"] = "Incorrect parameter amount"
            return response

        # 4. Find Order by order_number (or integer ID)
        order_query = select(Order).where(Order.order_number == merchant_trans_id).with_for_update()
        res = await session.execute(order_query)
        order = res.scalar_one_or_none()
        if not order and merchant_trans_id.isdigit():
            res = await session.execute(select(Order).where(Order.id == int(merchant_trans_id)).with_for_update())
            order = res.scalar_one_or_none()

        if not order:
            response["error"] = CLICK_ORDER_NOT_FOUND
            response["error_note"] = "Order not found"
            return response

        # 5. Check if already paid or cancelled
        if order.status == OrderStatus.CANCELLED:
            response["error"] = CLICK_TRANSACTION_CANCELLED
            response["error_note"] = "Order is cancelled"
            return response

        if order.status in (OrderStatus.PAID, OrderStatus.MODERATED, OrderStatus.READY_FOR_PRODUCTION, OrderStatus.IN_PRODUCTION, OrderStatus.COMPLETED):
            # Check if this exact click transaction was already recorded
            existing_payment = (
                await session.execute(
                    select(Payment).where(
                        Payment.order_id == order.id,
                        Payment.provider == "CLICK",
                        Payment.provider_trans_id == click_trans_id,
                    )
                )
            ).scalar_one_or_none()
            if existing_payment:
                response["merchant_prepare_id"] = existing_payment.id
                return response
            response["error"] = CLICK_ALREADY_PAID
            response["error_note"] = "Already paid"
            return response

        # 6. Check amount equality
        if abs(order.total_amount - amount_dec) >= Decimal("0.01"):
            response["error"] = CLICK_INVALID_AMOUNT
            response["error_note"] = f"Incorrect parameter amount: expected {order.total_amount}, got {amount_dec}"
            return response

        # 7. Check if a payment for this click_trans_id already exists (idempotency)
        existing_payment = (
            await session.execute(
                select(Payment).where(
                    Payment.provider == "CLICK",
                    Payment.provider_trans_id == click_trans_id,
                )
            )
        ).scalar_one_or_none()

        if existing_payment:
            payment = existing_payment
        else:
            payment = Payment(
                order_id=order.id,
                provider="CLICK",
                provider_trans_id=click_trans_id,
                provider_paydoc_id=click_paydoc_id,
                amount=amount_dec,
                status="PENDING",
                meta={"prepare_time": sign_time, "click_paydoc_id": click_paydoc_id},
            )
            session.add(payment)
            if order.status == OrderStatus.NEW:
                order.status = OrderStatus.PAYMENT_PENDING
            await session.commit()
            await session.refresh(payment)

        response["merchant_prepare_id"] = payment.id
        return response

    async def complete(self, session: AsyncSession, data: dict[str, Any]) -> dict[str, Any]:
        """Handle Click Action 1 (Complete). Finalizes payment and marks order as PAID."""
        click_trans_id = str(data.get("click_trans_id", ""))
        service_id = str(data.get("service_id", ""))
        click_paydoc_id = str(data.get("click_paydoc_id", ""))
        merchant_trans_id = self._extract_merchant_trans_id(data)
        merchant_prepare_id = data.get("merchant_prepare_id")
        raw_amount = data.get("amount", "0")
        action = str(data.get("action", "1"))
        error_param = int(data.get("error", 0))
        sign_time = str(data.get("sign_time", ""))
        sign_string = str(data.get("sign_string", ""))

        response: dict[str, Any] = {
            "click_trans_id": click_trans_id,
            "merchant_trans_id": merchant_trans_id,
            "merchant_confirm_id": None,
            "error": CLICK_SUCCESS,
            "error_note": "Success",
        }

        # 1. Verify signature
        if not self.verify_signature(
            click_trans_id=click_trans_id,
            service_id=service_id,
            merchant_trans_id=merchant_trans_id,
            amount=raw_amount,
            action=action,
            sign_time=sign_time,
            sign_string=sign_string,
            merchant_prepare_id=merchant_prepare_id,
        ):
            response["error"] = CLICK_SIGN_CHECK_FAILED
            response["error_note"] = "SIGN CHECK FAILED"
            return response

        # 1b. The service the webhook names must be ours.
        if not self.service_id_matches(service_id):
            logger.warning("Click complete with unexpected service_id=%s", service_id)
            response["error"] = CLICK_BAD_REQUEST
            response["error_note"] = "Incorrect parameter service_id"
            return response

        # 2. Check Action
        if action != "1":
            response["error"] = CLICK_ACTION_NOT_FOUND
            response["error_note"] = "Action not found"
            return response

        # 3. Find payment record by merchant_prepare_id
        payment: Payment | None = None
        if merchant_prepare_id not in (None, ""):
            try:
                prepare_id = int(str(merchant_prepare_id).strip())
            except (TypeError, ValueError):
                # A non-numeric prepare id is a bad request, not a 500.
                logger.warning("Click complete with non-numeric merchant_prepare_id=%r", merchant_prepare_id)
                response["error"] = CLICK_BAD_REQUEST
                response["error_note"] = "Incorrect parameter merchant_prepare_id"
                return response
            res = await session.execute(select(Payment).where(Payment.id == prepare_id).with_for_update())
            payment = res.scalar_one_or_none()

        if not payment:
            # Fallback to provider_trans_id
            res = await session.execute(
                select(Payment).where(
                    Payment.provider == "CLICK",
                    Payment.provider_trans_id == click_trans_id,
                ).with_for_update()
            )
            payment = res.scalar_one_or_none()

        if not payment:
            response["error"] = CLICK_TRANSACTION_NOT_FOUND
            response["error_note"] = "Transaction not found"
            return response

        # 4. Handle Click cancellation if error_param < 0
        if error_param < 0:
            payment.status = "CANCELLED"
            payment.meta = {**(payment.meta or {}), "cancel_error": error_param, "cancel_time": sign_time}
            await session.commit()
            response["error"] = CLICK_TRANSACTION_CANCELLED
            response["error_note"] = "Transaction cancelled by provider"
            return response

        # 5. Check if already marked as PAID (Idempotent response)
        if payment.status == "PAID":
            response["merchant_confirm_id"] = payment.id
            return response

        # 6. Find Order and update status
        order_res = await session.execute(select(Order).where(Order.id == payment.order_id).with_for_update())
        order = order_res.scalar_one_or_none()
        if not order:
            response["error"] = CLICK_ORDER_NOT_FOUND
            response["error_note"] = "Order not found"
            return response

        # 6a. The prepare id and the order number must name the same order,
        # or a prepare for a cheap order could complete an expensive one.
        if merchant_trans_id and merchant_trans_id not in (order.order_number, str(order.id)):
            logger.warning(
                "Click complete names order %s but payment %s belongs to %s",
                merchant_trans_id, payment.id, order.order_number,
            )
            response["error"] = CLICK_ORDER_NOT_FOUND
            response["error_note"] = "Order not found"
            return response

        # 6b. Re-check the amount here too: the prepare step checked it, but
        # complete must never bank less than the order costs.
        try:
            amount_dec = Decimal(str(raw_amount))
        except Exception:
            response["error"] = CLICK_INVALID_AMOUNT
            response["error_note"] = "Incorrect parameter amount"
            return response
        if abs(order.total_amount - amount_dec) >= Decimal("0.01"):
            logger.warning(
                "Click complete amount %s does not match order %s total %s",
                amount_dec, order.order_number, order.total_amount,
            )
            response["error"] = CLICK_INVALID_AMOUNT
            response["error_note"] = f"Incorrect parameter amount: expected {order.total_amount}, got {amount_dec}"
            return response

        # Mark payment as PAID
        payment.status = "PAID"
        payment.provider_paydoc_id = click_paydoc_id
        payment.meta = {**(payment.meta or {}), "completed_at": sign_time}

        # Update order status to PAID
        order.status = OrderStatus.PAID
        await session.commit()

        logger.info("Order %s successfully paid via Click (Payment ID: %s)", order.order_number, payment.id)
        response["merchant_confirm_id"] = payment.id
        return response
