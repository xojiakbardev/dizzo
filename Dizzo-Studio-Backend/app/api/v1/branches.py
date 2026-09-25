"""Branch and branch-inventory endpoints for customers and staff."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    ALL_STAFF_ROLES,
    GLOBAL_STAFF_ROLES,
    PRIVILEGED_ROLES,
    get_current_user,
    get_db,
    is_super_admin,
    optional_user,
    require_roles,
)
from app.db.session import get_db
from app.models.branch import Branch, BranchProduct
from app.models.catalog import Product
from app.models.user import User
from app.schemas.branch import (
    ASSIGNABLE_BRANCH_ROLES,
    BranchCreate,
    BranchOut,
    BranchProductAvailabilityIn,
    BranchProductOut,
    BranchUpdate,
    BranchWorkerAssignIn,
    BranchWorkerOut,
)
from app.services.auth import revoke_all_tokens
from app.services.storage import R2Storage, get_storage

router = APIRouter(prefix="/branches", tags=["branches"])

# Branch staff who may run their own branch (workers may not).
BRANCH_LEAD_ROLES = frozenset({"branch_admin", "branch_manager"})


def _branch_out(branch: Branch, pending_orders: int | None = None) -> BranchOut:
    unavailable_ids = [
        bp.product_id for bp in (branch.products_availability or []) if not bp.is_available
    ]
    daily_cap = getattr(branch, "daily_order_capacity", 20) or 20
    base_days = getattr(branch, "delivery_days", 3) or 3
    estimated_days = f"{base_days}–{base_days + 1} kun"
    if pending_orders is not None and pending_orders > 0:
        import math
        added_days = math.ceil(pending_orders / max(daily_cap, 1))
        min_d = base_days + added_days - 1
        max_d = base_days + added_days
        estimated_days = f"{min_d}–{max_d} kun"

    return BranchOut(
        id=branch.id,
        name=branch.name,
        slug=branch.slug,
        phone=branch.phone,
        address=branch.address,
        city=branch.city,
        latitude=branch.latitude,
        longitude=branch.longitude,
        work_hours=branch.work_hours,
        is_active=branch.is_active,
        notes=branch.notes,
        branch_type=getattr(branch, "branch_type", "BTS") or "BTS",
        daily_order_capacity=daily_cap,
        delivery_days=base_days,
        base_shipping_cost=float(getattr(branch, "base_shipping_cost", 35000.0) or 35000.0),
        estimated_delivery_days=estimated_days,
        current_pending_orders=pending_orders,
        created_at=branch.created_at,
        updated_at=branch.updated_at,
        unavailable_product_ids=unavailable_ids,
    )


@router.get("", response_model=list[BranchOut])
async def list_branches(
    include_inactive: bool = False,
    user: User | None = Depends(optional_user),
    session: AsyncSession = Depends(get_db),
) -> list[BranchOut]:
    """List branches. Guests and customers only see active branches."""
    query = select(Branch)
    is_staff = user is not None and user.role in ALL_STAFF_ROLES
    if not (include_inactive and is_staff):
        query = query.where(Branch.is_active.is_(True))

    query = query.order_by(Branch.city, Branch.name)
    branches = (await session.execute(query)).scalars().all()
    return [_branch_out(b) for b in branches]


@router.get("/{branch_id}", response_model=BranchOut)
async def get_branch(
    branch_id: int,
    session: AsyncSession = Depends(get_db),
) -> BranchOut:
    branch = await session.get(Branch, branch_id)
    if not branch:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Filial topilmadi")
    return _branch_out(branch)


@router.post("", response_model=BranchOut, status_code=status.HTTP_201_CREATED)
async def create_branch(
    payload: BranchCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> BranchOut:
    require_roles(user, *GLOBAL_STAFF_ROLES)
    existing = (await session.execute(select(Branch).where(Branch.slug == payload.slug))).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Bunday slug'li filial allaqachon mavjud")

    branch = Branch(**payload.model_dump())
    session.add(branch)
    await session.commit()
    await session.refresh(branch)
    return _branch_out(branch)


@router.patch("/{branch_id}", response_model=BranchOut)
async def update_branch(
    branch_id: int,
    payload: BranchUpdate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> BranchOut:
    require_roles(user, *GLOBAL_STAFF_ROLES)
    branch = await session.get(Branch, branch_id)
    if not branch:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Filial topilmadi")

    data = payload.model_dump(exclude_unset=True)
    for field, val in data.items():
        setattr(branch, field, val)

    await session.commit()
    await session.refresh(branch)
    return _branch_out(branch)


@router.delete("/{branch_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_branch(
    branch_id: int,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    if not is_super_admin(user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Faqat superadmin filialni o'chira oladi")

    branch = await session.get(Branch, branch_id)
    if not branch:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Filial topilmadi")

    await session.delete(branch)
    await session.commit()


# --- Branch Product Inventory / Availability ---


@router.get("/{branch_id}/products", response_model=list[BranchProductOut])
async def list_branch_products(
    branch_id: int,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
) -> list[BranchProductOut]:
    """List all products with this branch's availability toggle."""
    if not (user.role in GLOBAL_STAFF_ROLES or (user.role in ALL_STAFF_ROLES and user.branch_id == branch_id)):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Ruxsat yo'q")

    # Fetch all published products
    products = (
        await session.execute(
            select(Product).where(Product.is_published.is_(True)).order_by(Product.name)
        )
    ).scalars().all()

    # Fetch existing availability overrides for this branch
    overrides = (
        await session.execute(
            select(BranchProduct).where(BranchProduct.branch_id == branch_id)
        )
    ).scalars().all()
    override_map = {bp.product_id: bp for bp in overrides}

    out: list[BranchProductOut] = []
    for p in products:
        bp = override_map.get(p.id)
        image_url = None
        if p.images:
            image_url = storage.public_url(p.images[0].media.key) if p.images[0].media else None

        category_name = p.category.name if p.category else None
        out.append(
            BranchProductOut(
                product_id=p.id,
                product_name=p.name,
                product_slug=p.slug,
                category_name=category_name,
                image_url=image_url,
                base_price=float(p.base_price),
                is_available=bp.is_available if bp else True,
                reason=bp.reason if bp else None,
            )
        )
    return out


@router.patch("/{branch_id}/products/{product_id}/availability", response_model=BranchProductOut)
async def set_branch_product_availability(
    branch_id: int,
    product_id: int,
    payload: BranchProductAvailabilityIn,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
    storage: R2Storage = Depends(get_storage),
) -> BranchProductOut:
    """Toggle whether a product is available at this branch."""
    can_manage = (
        user.role in GLOBAL_STAFF_ROLES
        or (user.role in BRANCH_LEAD_ROLES and user.branch_id == branch_id)
    )
    if not can_manage:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Mahsulot mavjudligini o'zgartirish huquqi yo'q")

    product = await session.get(Product, product_id)
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Mahsulot topilmadi")

    bp = (
        await session.execute(
            select(BranchProduct).where(
                BranchProduct.branch_id == branch_id,
                BranchProduct.product_id == product_id,
            )
        )
    ).scalar_one_or_none()

    if not bp:
        bp = BranchProduct(
            branch_id=branch_id,
            product_id=product_id,
            is_available=payload.is_available,
            reason=payload.reason,
        )
        session.add(bp)
    else:
        bp.is_available = payload.is_available
        bp.reason = payload.reason

    await session.commit()

    image_url = None
    if product.images:
        image_url = storage.public_url(product.images[0].media.key) if product.images[0].media else None

    return BranchProductOut(
        product_id=product.id,
        product_name=product.name,
        product_slug=product.slug,
        category_name=product.category.name if product.category else None,
        image_url=image_url,
        base_price=float(product.base_price),
        is_available=bp.is_available,
        reason=bp.reason,
    )


# --- Branch Workers Management ---


@router.get("/{branch_id}/workers", response_model=list[BranchWorkerOut])
async def list_branch_workers(
    branch_id: int,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[BranchWorkerOut]:
    can_view = (
        user.role in GLOBAL_STAFF_ROLES
        or (user.role in BRANCH_LEAD_ROLES and user.branch_id == branch_id)
    )
    if not can_view:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Ruxsat yo'q")

    workers = (
        await session.execute(
            select(User).where(User.branch_id == branch_id).order_by(User.first_name, User.last_name)
        )
    ).scalars().all()

    return [
        BranchWorkerOut(
            id=w.id,
            full_name=w.full_name,
            phone_number=w.phone_number,
            email=w.email,
            role=w.role,
            branch_id=w.branch_id,
        )
        for w in workers
    ]


@router.post("/{branch_id}/workers", response_model=BranchWorkerOut)
async def assign_branch_worker(
    branch_id: int,
    payload: BranchWorkerAssignIn,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> BranchWorkerOut:
    can_manage = (
        user.role in PRIVILEGED_ROLES
        or (user.role in BRANCH_LEAD_ROLES and user.branch_id == branch_id)
    )
    if not can_manage:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Xodimlarni biriktirish huquqi yo'q")

    # Nobody promotes themselves through the branch roster.
    if payload.user_id == user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="O'zingizga rol biriktira olmaysiz")

    target_user = await session.get(User, payload.user_id)
    if not target_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Foydalanuvchi topilmadi")

    # Branch managers can only assign branch_worker role, not admin/manager roles
    role_to_set = payload.role
    if user.role in BRANCH_LEAD_ROLES:
        role_to_set = "branch_worker"
    # The schema already narrows `role`; this is the server-side backstop, so
    # a global role can never be handed out from a branch roster endpoint.
    if role_to_set not in ASSIGNABLE_BRANCH_ROLES:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Bu rolni filial xodimiga berib bo'lmaydi")

    # Demoting a global admin/moderator into a branch is an admin's decision.
    if target_user.role in GLOBAL_STAFF_ROLES and user.role not in PRIVILEGED_ROLES:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Bu foydalanuvchining rolini o'zgartirish huquqi yo'q")

    changed = (target_user.role, target_user.branch_id, target_user.is_staff) != (role_to_set, branch_id, True)
    target_user.branch_id = branch_id
    target_user.role = role_to_set
    target_user.is_staff = True
    if changed:
        # A role change must not leave the old rights alive in an issued token.
        await revoke_all_tokens(session, target_user)

    await session.commit()
    await session.refresh(target_user)

    return BranchWorkerOut(
        id=target_user.id,
        full_name=target_user.full_name,
        phone_number=target_user.phone_number,
        email=target_user.email,
        role=target_user.role,
        branch_id=target_user.branch_id,
    )


@router.delete("/{branch_id}/workers/{worker_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_branch_worker(
    branch_id: int,
    worker_id: int,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    can_manage = (
        user.role in PRIVILEGED_ROLES
        or (user.role in BRANCH_LEAD_ROLES and user.branch_id == branch_id)
    )
    if not can_manage:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Xodimni o'chirish huquqi yo'q")

    target_user = await session.get(User, worker_id)
    if not target_user or target_user.branch_id != branch_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Xodim ushbu filialda topilmadi")

    if target_user.role in GLOBAL_STAFF_ROLES and user.role not in PRIVILEGED_ROLES:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Bu foydalanuvchining rolini o'zgartirish huquqi yo'q")

    target_user.branch_id = None
    target_user.role = "customer"
    target_user.is_staff = False
    await revoke_all_tokens(session, target_user)
    await session.commit()
