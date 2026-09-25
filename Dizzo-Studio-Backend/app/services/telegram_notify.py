"""Outbound Telegram notifications — separate from app/services/telegram.py
(which only verifies *inbound* login-widget/WebApp payloads). Best-effort:
a failed send (bot not configured, chat blocked the bot, network hiccup)
must never break the order flow that triggered it."""

import logging
from html import escape

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import BRANCH_STAFF_ROLES, GLOBAL_STAFF_ROLES
from app.core.config import get_settings
from app.core.i18n import _
from app.models.commerce import Order
from app.models.user import User
from app.services.orders import status_label

logger = logging.getLogger(__name__)


async def _send_message(chat_id: int | str, text: str, reply_markup: dict | None = None) -> None:
    settings = get_settings()
    token = settings.effective_bot_token
    if not token:
        return
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    payload: dict = {"chat_id": chat_id, "text": text, "parse_mode": "HTML"}
    if reply_markup:
        payload["reply_markup"] = reply_markup
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(url, json=payload)
            if response.status_code != 200:
                logger.warning("Telegram sendMessage failed (chat_id=%s): %s", chat_id, response.text)
    except httpx.HTTPError as exc:
        logger.warning("Telegram sendMessage request failed (chat_id=%s): %s", chat_id, type(exc).__name__)


Message = tuple[int | str, str]


async def send_messages(messages: list[Message]) -> None:
    """Sends messages in a background task."""
    for chat_id, text in messages:
        await _send_message(chat_id, text)



async def staff_new_order_messages(session: AsyncSession, order: Order) -> list[Message]:
    """One message for every linked admin/staff user with a Telegram account,
    each in that user's language."""
    # Global staff always; branch staff only for their own branch's order.
    # `is_staff` is not consulted: it is True for every staff account, so it
    # sent every branch's orders to every branch.
    audience = User.role.in_(sorted(GLOBAL_STAFF_ROLES))
    if getattr(order, "branch_id", None):
        audience = audience | (User.role.in_(sorted(BRANCH_STAFF_ROLES)) & (User.branch_id == order.branch_id))
    recipients = (
        await session.execute(
            select(User.telegram_id, User.language).where(
                audience,
                User.is_active.is_(True),
                User.telegram_id.is_not(None),
            )
        )
    ).all()
    link = f"{get_settings().frontend_url}/admin/orders/{order.id}"
    return [
        (
            chat_id,
            _(
                "🆕 <b>Yangi buyurtma #{number}</b>\nSumma: {amount} so'm\nBatafsil: {link}",
                language=language, number=order.order_number, amount=order.total_amount, link=link,
            ),
        )
        for chat_id, language in recipients
    ]


async def customer_status_messages(session: AsyncSession, order: Order) -> list[Message]:
    """Tells the customer their order moved on, if they linked Telegram
    from their profile (telegram_id is only ever set by that bot handshake,
    so this reaches the account holder's own chat)."""
    if not order or not getattr(order, "customer_id", None):
        return []
    try:
        customer = await session.get(User, order.customer_id)
    except Exception as exc:
        logger.warning("Failed to lookup customer for telegram notify: %s", exc)
        return []
    if customer is None or customer.telegram_id is None:
        return []
    link = f"{get_settings().frontend_url}/user/orders/{order.order_number}"
    language = customer.language or "uz"
    try:
        st_text = status_label(order.status, language)
    except Exception:
        st_text = order.status
    text = _(
        "📦 <b>Buyurtma #{number}</b>\nHolati: {status}\nBatafsil: {link}",
        language=language, number=order.order_number, status=st_text, link=link,
    )
    return [(customer.telegram_id, text)]


async def notify_staff_new_order(session: AsyncSession, order: Order) -> None:
    await send_messages(await staff_new_order_messages(session, order))


async def notify_customer_order_status(session: AsyncSession, order: Order) -> None:
    await send_messages(await customer_status_messages(session, order))


async def notify_gallery_submission(
    item_id: int,
    product_name: str,
    worker_name: str,
    branch_name: str | None,
    title: str | None,
    group_id: str | None,
) -> None:
    """Sends notification with inline approval buttons strictly to the moderator group."""
    if not group_id:
        logger.warning("Telegram moderator group ID is not configured. Skipping gallery notification.")
        return

    # parse_mode is HTML and every value here is user-settable (a worker's
    # own name, a title they typed): escaped, or a worker could put a link
    # of their own in front of the moderators.
    branch_text = escape(branch_name or "Asosiy")
    title_text = escape(title or "—")
    caption = (
        f"🎨 <b>Yangi galereya namunasi tekshiruv uchun!</b>\n\n"
        f"📦 <b>Mahsulot:</b> {escape(product_name)}\n"
        f"🏢 <b>Filial:</b> {branch_text}\n"
        f"👤 <b>Xodim:</b> {escape(worker_name)}\n"
        f"📝 <b>Sarlavha:</b> {title_text}\n"
    )
    reply_markup = {
        "inline_keyboard": [
            [
                {"text": "✅ Tasdiqlash va Chiqarish", "callback_data": f"gal_appr:{item_id}"},
                {"text": "❌ Rad etish", "callback_data": f"gal_rejc:{item_id}"},
            ]
        ]
    }

    await _send_message(group_id, caption, reply_markup=reply_markup)



