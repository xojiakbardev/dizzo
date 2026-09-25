from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    BRANCH_STAFF_ROLES,
    PRIVILEGED_ROLES,
    ROLES,
    get_current_user,
    is_super_admin,
    require_roles,
)
from app.core.i18n import _
from app.core.security import hash_password, normalize_email
from app.db.session import get_db
from app.models.branch import Branch
from app.models.commerce import Cart, Design, Order
from app.models.review import Review
from app.models.user import SocialConnection, TelegramAppLogin, TelegramLinkToken, User
from app.schemas.auth import AdminUserCreateRequest, AdminUserRoleUpdateRequest, ProfileUpdateRequest, UserOut
from app.services.auth import clear_auth_cookies, revoke_all_tokens, user_payload
from app.services.orders import OrderStatus

router = APIRouter(prefix="/users", tags=["users"])

FORBIDDEN = "Ruxsat yo'q"


def check_grant(admin: User, target: User | None, role: str | None, is_staff: bool | None) -> None:
    """Only super_admin can create staff/admins and change roles."""
    if role is not None and role not in ROLES:
        raise HTTPException(status_code=422, detail=_("Noma'lum rol: {role}", role=role))
    if not is_super_admin(admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Faqat superadmin rollarni o'zgartira oladi va xodimlar yarata oladi",
        )


def assert_role_matches_branch(role: str | None, branch_id: int | None) -> None:
    """A branch account is only a branch role; HQ roles never carry a branch."""
    branched = branch_id is not None and branch_id > 0
    if role is None:
        return
    if branched and role not in BRANCH_STAFF_ROLES:
        raise HTTPException(status_code=422, detail=_("Filialga faqat filial rollarini berish mumkin"))
    if not branched and role in BRANCH_STAFF_ROLES:
        raise HTTPException(status_code=422, detail=_("Filial roli uchun filial tanlash shart"))


async def resolve_branch_id(session: AsyncSession, branch_id: int | None) -> int | None:
    if branch_id is None or branch_id <= 0:
        return None
    branch = await session.get(Branch, branch_id)
    if branch is None:
        raise HTTPException(status_code=422, detail=_("Filial topilmadi"))
    return branch.id


@router.get("/profile/me/")
async def profile(user: User = Depends(get_current_user)):
    return user_payload(user)


@router.patch("/profile/me/")
async def update_profile(
    payload: ProfileUpdateRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    data = payload.model_dump(exclude_unset=True)
    if data.get("language", "") is None:
        del data["language"]
    for field, value in data.items():
        setattr(user, field, value)
    await session.commit()
    await session.refresh(user)
    return user_payload(user)


@router.delete("/profile/me/", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    response: Response,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    """Deletes the account (the stores require it). Orders are business
    records and stay, without the person: the account is emptied of every
    personal detail, its sign-ins, saved designs and cart go, reviews stay
    anonymous, and it can never sign in again. Not while an order is still
    in progress, and not for admins (they would lock the shop out)."""
    if user.role in PRIVILEGED_ROLES or user.is_staff:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=_("Administrator hisobini bu yerdan o'chirib bo'lmaydi"))
    open_orders = (await session.execute(
        select(Order.id).where(
            Order.customer_id == user.id,
            Order.status.not_in([OrderStatus.COMPLETED.value, OrderStatus.CANCELLED.value]),
        ).limit(1)
    )).scalar_one_or_none()
    if open_orders:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=_("Faol buyurtmangiz bor. Uni yakunlagach yoki bekor qilgach hisobni o'chira olasiz."),
        )
    await session.execute(delete(SocialConnection).where(SocialConnection.user_id == user.id))
    await session.execute(delete(TelegramAppLogin).where(TelegramAppLogin.user_id == user.id))
    await session.execute(delete(TelegramLinkToken).where(TelegramLinkToken.user_id == user.id))
    await session.execute(delete(Design).where(Design.user_id == user.id))
    await session.execute(delete(Cart).where(Cart.customer_id == user.id))
    await session.execute(update(Review).where(Review.author_id == user.id).values(author_id=None))
    await revoke_all_tokens(session, user)
    user.email = None
    user.password_hash = None
    user.first_name = ""
    user.last_name = ""
    user.phone_number = ""
    user.avatar = None
    user.telegram_id = None
    user.telegram_linked_at = None
    user.is_active = False
    await session.commit()
    clear_auth_cookies(response)


@router.get("/admin/list/", response_model=list[UserOut])
async def admin_list_users(
    search: str | None = None,
    branch_id: int | None = None,
    role: str | None = None,
    session: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_user),
):
    require_roles(admin, "super_admin", "admin", "moderator")
    query = select(User).order_by(User.id.desc())
    if search:
        search_term = f"%{search.strip()}%"
        query = query.where(
            User.email.ilike(search_term)
            | User.first_name.ilike(search_term)
            | User.last_name.ilike(search_term)
            | User.phone_number.ilike(search_term)
        )
    if branch_id is not None:
        if branch_id == 0:
            query = query.where(User.branch_id.is_(None))
        else:
            query = query.where(User.branch_id == branch_id)
    if role:
        query = query.where(User.role == role)
    users = (await session.execute(query)).scalars().all()
    return [user_payload(u) for u in users]


@router.post("/admin/create/", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def admin_create_user(
    payload: AdminUserCreateRequest,
    session: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_user),
):
    require_roles(admin, "super_admin")
    check_grant(admin, None, payload.role, payload.is_staff)
    branch_id = await resolve_branch_id(session, payload.branch_id)
    assert_role_matches_branch(payload.role, branch_id)
    email = normalize_email(payload.email)
    exists = (await session.execute(select(User).where(User.email == email))).scalar_one_or_none()
    if exists:
        raise HTTPException(status_code=409, detail="Bu email allaqachon ro'yxatdan o'tgan")
    is_staff = payload.is_staff or payload.role != "customer"
    user = User(
        email=email,
        first_name=payload.first_name,
        last_name=payload.last_name,
        password_hash=hash_password(payload.password),
        role=payload.role,
        branch_id=branch_id,
        is_staff=is_staff,
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user_payload(user)


@router.patch("/admin/{user_id}/role/", response_model=UserOut)
async def admin_update_user_role(
    user_id: int,
    payload: AdminUserRoleUpdateRequest,
    session: AsyncSession = Depends(get_db),
    admin: User = Depends(get_current_user),
):
    require_roles(admin, "super_admin")
    target = await session.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="Foydalanuvchi topilmadi")
    check_grant(admin, target, payload.role, payload.is_staff)
    next_role = payload.role if payload.role is not None else target.role
    if "branch_id" in payload.model_fields_set:
        next_branch = await resolve_branch_id(session, payload.branch_id)
    else:
        next_branch = target.branch_id
    assert_role_matches_branch(next_role, next_branch)
    before = (target.role, target.is_staff, target.is_active, target.branch_id)
    if payload.first_name is not None:
        target.first_name = payload.first_name
    if payload.last_name is not None:
        target.last_name = payload.last_name
    if payload.phone_number is not None:
        target.phone_number = payload.phone_number
    if payload.role is not None:
        target.role = payload.role
        if payload.role != "customer":
            target.is_staff = True
    if payload.is_staff is not None:
        target.is_staff = payload.is_staff
    if payload.is_active is not None:
        target.is_active = payload.is_active
    if "branch_id" in payload.model_fields_set:
        target.branch_id = next_branch
    if (target.role, target.is_staff, target.is_active, target.branch_id) != before:
        await revoke_all_tokens(session, target)
    await session.commit()
    session.expire(target, ["branch"])
    await session.refresh(target)
    return user_payload(target)
