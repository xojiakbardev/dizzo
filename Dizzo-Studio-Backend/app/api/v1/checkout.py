from decimal import Decimal
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.i18n import _
from app.db.session import get_db
from app.models.commerce import Cart, Order, OrderItem
from app.models.user import User
from app.schemas.orders import CheckoutRequest
from app.services.catalog import quote
from app.services.orders import get_order, order_detail_payload
from app.services.packages import (
    copy_into_order,
    line_translations,
    package_problems,
    painted_areas,
    sellable,
)
from app.services.storage import R2Storage, get_storage
from app.services.telegram_notify import send_messages, staff_new_order_messages

router = APIRouter(tags=["checkout"])


def provisional_order_number() -> str:
    """Holds the unique column until the id is known (see below)."""
    return f"tmp-{uuid4().hex[:24]}"


def order_number_for(order_id: int) -> str:
    """Orders are numbered in turn by their id, seven digits: 0000001, 0000002…"""
    return f"{order_id:07d}"


async def placed_order(session: AsyncSession, user: User, key: str) -> Order | None:
    return (
        await session.execute(select(Order).where(Order.customer_id == user.id, Order.idempotency_key == key))
    ).scalar_one_or_none()


from app.core.config import get_settings
from app.services.payments.click import ClickService


async def checkout_response(session: AsyncSession, order_id: int, user: User, storage: R2Storage) -> dict:
    order = await get_order(session, order_id)
    detail = await order_detail_payload(session, order, user, storage)
    settings = get_settings()
    payment_url = ClickService(settings).generate_payment_url(order) if settings.click_service_id else None
    return {
        "order": detail,
        "order_number": order.order_number,
        "order_id": order.id,
        "total_amount": str(order.total_amount),
        "status": order.status,
        "payment_url": payment_url,
    }


@router.post("/checkout/")
async def checkout(
    payload: CheckoutRequest,
    background: BackgroundTasks,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
    idempotency_key: str | None = Header(
        default=None, alias="Idempotency-Key", min_length=8, max_length=64, pattern=r"^[A-Za-z0-9_.:-]+$"
    ),
):
    """Places the order. A client that sends an Idempotency-Key (a fresh UUID
    per checkout attempt, reused on retries) gets the same order back for a
    repeated request. The cart row is locked, so two submits at once can't
    both turn the same cart into orders."""
    # FOR UPDATE: a second concurrent checkout waits here until the first has
    # committed (and emptied the cart). SQLite ignores it (tests only).
    cart = (
        await session.execute(
            select(Cart).where(Cart.customer_id == user.id).with_for_update().execution_options(populate_existing=True)
        )
    ).scalar_one_or_none()
    if idempotency_key and (done := await placed_order(session, user, idempotency_key)) is not None:
        await session.commit()  # releases the lock
        return await checkout_response(session, done.id, user, storage)
    if cart is None or not cart.items:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Savat bo'sh")

    # Nothing is ordered at a price the customer hasn't seen or for
    # something that went off sale since it was added.
    unavailable = [item for item in cart.items if not sellable(item.variant, item.color, item.size)]
    if unavailable:
        names = ", ".join(f"{i.package['product']['name']} ({i.package['variant']['name']})" for i in unavailable)
        raise HTTPException(status_code=409, detail=_("Sotuvda yo'q: {names}. Savatdan olib tashlang.", names=names))
    # The design is checked once more against the size actually ordered: a
    # size's print scale (SizeItem.print_scale) may have been changed by an
    # admin while the item sat in the cart, and nothing may go to production
    # that does not fit the size it is printed on.
    for item in cart.items:
        if problems := package_problems(item.package, item.variant, item.size):
            raise HTTPException(status_code=409, detail=_(
                "{product}: {problem} Savatda o'lchamni o'zgartiring yoki dizaynni qayta tahrirlang.",
                product=item.package["product"]["name"], problem=problems[0],
            ))
    repriced = False
    for item in cart.items:
        price = quote(item.variant, item.color, item.quantity, painted_areas(item.package), item.size or None)
        if price.unit_price != item.unit_price:
            item.unit_price = price.unit_price
            item.package = {**item.package, "quote": price.model_dump(mode="json")}
            repriced = True
    if repriced:
        await session.commit()
        raise HTTPException(status_code=409, detail="Savatdagi narxlar yangilandi. Tekshirib, qayta tasdiqlang.")

    shipping_addr = payload.shipping_address
    if payload.delivery_method == "PICKUP":
        if payload.branch_id:
            from app.models.branch import Branch, BranchProduct
            branch = await session.get(Branch, payload.branch_id)
            if not branch or not branch.is_active:
                raise HTTPException(status_code=422, detail="Tanlangan filial mavjud emas yoki vaqtincha yopiq")
            product_ids = [item.variant.product_id for item in cart.items if item.variant]
            if product_ids:
                unavail = (
                    await session.execute(
                        select(BranchProduct).where(
                            BranchProduct.branch_id == branch.id,
                            BranchProduct.product_id.in_(product_ids),
                            BranchProduct.is_available.is_(False),
                        )
                    )
                ).scalars().all()
                if unavail:
                    raise HTTPException(
                        status_code=422,
                        detail="Savatdagi ba'zi mahsulotlar tanlangan filialda vaqtincha mavjud emas",
                    )
            if not shipping_addr:
                shipping_addr = f"{branch.name}, {branch.address}"
        elif not shipping_addr:
            shipping_addr = "Toshkent shahri, Dizzo markaziy ofisi"

    subtotal = sum((item.unit_price * item.quantity for item in cart.items), Decimal("0"))
    if subtotal <= 0:
        raise HTTPException(
            status_code=422,
            detail="Buyurtma summasi 0 so'm bo'lishi mumkin emas. Savatni tekshiring yoki biz bilan bog'laning.",
        )
    shipping_cost = payload.shipping_cost if payload.delivery_method == "DELIVERY" else Decimal("0")
    order = Order(
        order_number=provisional_order_number(),
        customer_id=user.id,
        idempotency_key=idempotency_key,
        status="NEW",
        delivery_method=payload.delivery_method,
        carrier=payload.carrier if payload.delivery_method == "DELIVERY" else "",
        branch_id=payload.branch_id if payload.delivery_method == "PICKUP" else None,
        subtotal=subtotal,
        shipping_cost=shipping_cost,
        total_amount=subtotal + shipping_cost,
        latitude=payload.latitude,
        longitude=payload.longitude,
        shipping_name=payload.contact_name,
        shipping_email=payload.contact_email,
        shipping_phone=payload.contact_phone,
        shipping_address=shipping_addr,
        shipping_city=payload.shipping_city,
        shipping_state=payload.shipping_state,
        shipping_postal_code=payload.shipping_postal_code,
        shipping_country=payload.shipping_country,
        customer_notes=payload.customer_notes,
    )
    session.add(order)
    try:
        await session.flush()
    except IntegrityError:
        # The same key committed by a request that didn't wait on the lock.
        await session.rollback()
        done = await placed_order(session, user, idempotency_key) if idempotency_key else None
        if done is None:
            raise
        return await checkout_response(session, done.id, user, storage)
    order.order_number = order_number_for(order.id)

    for line, item in enumerate(cart.items, start=1):
        package = item.package
        session.add(OrderItem(
            order_id=order.id,
            product_name=package["product"]["name"],
            product_slug=package["product"]["slug"],
            variant_name=package["variant"]["name"],
            color_name=package["color"]["name"],
            color_hex=package["color"]["hex"],
            size=item.size,
            translations=line_translations(item.variant, item.color, item.size),
            quantity=item.quantity,
            unit_price=item.unit_price,
            package=await copy_into_order(package, order.order_number, line, storage),
        ))
    for item in list(cart.items):
        await session.delete(item)
    await session.commit()

    # Telegram is slow and best-effort: sent after the response.
    background.add_task(send_messages, await staff_new_order_messages(session, order))
    return await checkout_response(session, order.id, user, storage)
