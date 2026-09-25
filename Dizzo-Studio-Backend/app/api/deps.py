from fastapi import Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.rate_limit import client_ip  # noqa: F401  (re-exported for the routers)
from app.db.session import get_db
from app.models.user import User
from app.services.auth import current_user, request_access_token

DbSession = AsyncSession


async def get_current_user(request: Request, session: AsyncSession = Depends(get_db)) -> User:
    return await current_user(request, session)


async def optional_user(request: Request, session: AsyncSession = Depends(get_db)) -> User | None:
    """None for a guest (no token sent). A token that is sent but invalid or
    expired is a 401 — the client refreshes it — never silently a guest."""
    if not request_access_token(request):
        return None
    return await current_user(request, session)


# Role definitions:
# - super_admin: Platform owner, manages all settings, admins, and role assignments.
# - admin: Global admin, cannot assign roles or create admins.
# - moderator: Global moderator, manages catalog, pricing, categories, and branch gallery moderation.
# - branch_admin / branch_manager: Branch manager, oversees branch orders, inventory, and workers.
# - branch_worker: Branch employee, processes orders and submits gallery showcases.
# - customer: Standard buyer.
ROLES = (
    "customer",
    "branch_worker",
    "branch_manager",
    "branch_admin",
    "moderator",
    "admin",
    "super_admin",
)
GLOBAL_STAFF_ROLES = frozenset({"moderator", "admin", "super_admin"})
BRANCH_LEAD_ROLES = frozenset({"branch_manager", "branch_admin"})
BRANCH_STAFF_ROLES = frozenset({"branch_worker"}) | BRANCH_LEAD_ROLES
ALL_STAFF_ROLES = GLOBAL_STAFF_ROLES | BRANCH_STAFF_ROLES
PRIVILEGED_ROLES = frozenset({"admin", "super_admin"})


def is_super_admin(user: User) -> bool:
    return user.role == "super_admin"


def require_roles(user: User, *roles: str) -> None:
    """Only `user.role` decides. `is_staff` is a legacy flag that is True for
    every non-customer account, so letting it pass here turned every role
    check in the codebase into a no-op for branch staff."""
    if user.role == "super_admin" or user.role in roles:
        return
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Ruxsat yo'q")

