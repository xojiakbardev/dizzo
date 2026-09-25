"""The signed-in customer's cart. Each item is a frozen package built from
the Studio (see app.services.packages): the backend checks the design and
every print file and prices the item from the files themselves."""

from __future__ import annotations

from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.i18n import _
from app.db.session import get_db
from app.models.commerce import Cart, CartItem, Design
from app.models.user import User
from app.schemas.design import CartItemIn, CartOut, DesignDocument, QuantityIn
from app.services.catalog import lock_shape, quote, resolve_size, size_scale
from app.services.design_rules import document_problems
from app.services.packages import build_package, cart_item_out, resize_item, sellable, variant_and_color
from app.services.storage import R2Storage, get_storage

router = APIRouter(prefix="/cart", tags=["cart"])


async def get_cart(session: AsyncSession, user: User) -> Cart:
    cart = (await session.execute(select(Cart).where(Cart.customer_id == user.id))).scalar_one_or_none()
    if cart is None:
        cart = Cart(customer_id=user.id)
        session.add(cart)
        await session.commit()
    return await reload_cart(session, user)


async def reload_cart(session: AsyncSession, user: User) -> Cart:
    session.expunge_all()
    return (await session.execute(select(Cart).where(Cart.customer_id == user.id))).scalar_one()


def cart_out(cart: Cart, storage: R2Storage) -> CartOut:
    items = [cart_item_out(item, storage) for item in cart.items]
    subtotal = sum((item.total_price for item in items), Decimal("0"))
    return CartOut(
        uuid=cart.uuid, items=items, total_items=sum(item.quantity for item in items), subtotal=subtotal,
        total_amount=subtotal, is_empty=not items, blocked=any(not item.available for item in items),
    )


@router.get("/", response_model=CartOut)
async def read_cart(
    user: User = Depends(get_current_user), session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
):
    return cart_out(await get_cart(session, user), storage)


@router.post("/items/", response_model=CartOut, status_code=status.HTTP_201_CREATED)
async def add_item(
    payload: CartItemIn, user: User = Depends(get_current_user), session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
):
    cart = await get_cart(session, user)
    variant, color = await variant_and_color(session, payload.variant_id, payload.color_id)
    if not sellable(variant, color):
        raise HTTPException(status_code=422, detail="Bu variant yoki rang hozir sotuvda emas")
    if payload.design_id is not None:
        design = await session.get(Design, payload.design_id)
        if design is None or design.owner_id != user.id:
            raise HTTPException(status_code=404, detail="Dizayn topilmadi")
    package, price = await build_package(session, user, payload, variant, color, storage)
    if price.unit_price != payload.expected_unit_price:
        # The customer confirms the new price and sends it again.
        return JSONResponse(
            status_code=status.HTTP_409_CONFLICT,
            content={
                "detail": _("Narx bosma fayllar bo'yicha qayta hisoblandi: {price} so'm", price=price.unit_price),
                "quote": price.model_dump(mode="json"),
            },
        )
    lock_shape(variant.shape)
    session.add(CartItem(
        cart_id=cart.id, design_id=payload.design_id, variant_id=variant.id, color_id=color.id,
        size=price.size or "", quantity=payload.quantity, unit_price=price.unit_price, package=package,
    ))
    await session.commit()
    return cart_out(await reload_cart(session, user), storage)


async def own_item(session: AsyncSession, cart: Cart, item_uuid: str) -> CartItem:
    item = (
        await session.execute(select(CartItem).where(CartItem.uuid == item_uuid, CartItem.cart_id == cart.id))
    ).scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Savatdagi mahsulot topilmadi")
    return item


@router.patch("/items/{item_uuid}/", response_model=CartOut)
async def update_item(
    item_uuid: str, payload: QuantityIn, user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db), storage: R2Storage = Depends(get_storage),
):
    """Quantity, size, or both. A new size is the design's print size too
    (SizeItem.print_scale), so it is taken only when the design still fits
    it: the document is checked again against the size asked for, the print
    files are re-cut to it and the item is priced from what they now hold."""
    item = await own_item(session, await get_cart(session, user), item_uuid)
    if payload.quantity is not None:
        item.quantity = payload.quantity
    if payload.size is not None:
        size = resolve_size(item.variant, payload.size or None, required=True)
        document = DesignDocument.model_validate(item.package["document"])
        problems = document_problems(
            document, item.variant, size_scale(size), size["label"] if size else ""
        )
        if problems:
            raise HTTPException(status_code=422, detail=problems[0])
        package, areas_cm2 = await resize_item(item, size, storage)
        price = quote(item.variant, item.color, item.quantity, areas_cm2, size["label"] if size else None)
        item.size = price.size or ""
        item.unit_price = price.unit_price
        item.package = {**package, "quote": price.model_dump(mode="json")}
    await session.commit()
    return cart_out(await reload_cart(session, user), storage)


@router.delete("/items/{item_uuid}/", response_model=CartOut)
async def delete_item(
    item_uuid: str, user: User = Depends(get_current_user), session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
):
    item = await own_item(session, await get_cart(session, user), item_uuid)
    await session.delete(item)
    await session.commit()
    return cart_out(await reload_cart(session, user), storage)


@router.delete("/clear/", response_model=CartOut)
async def clear_cart(
    user: User = Depends(get_current_user), session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
):
    cart = await get_cart(session, user)
    for item in list(cart.items):
        await session.delete(item)
    await session.commit()
    return cart_out(await reload_cart(session, user), storage)
