"""Create (or promote) a super_admin user.

Usage:
    python -m app.scripts.create_superuser --email admin@example.com --password secret123

If a user with the given email already exists, it is promoted to super_admin and
its password is updated instead of creating a duplicate.
"""

from __future__ import annotations

import argparse
import asyncio

from sqlalchemy import select

from app import models  # noqa: F401  (ensure all models are registered on Base.metadata)
from app.core.security import hash_password, normalize_email
from app.db.session import async_session_factory
from app.models.user import User


async def create_superuser(email: str, password: str) -> User:
    # Expects a migrated database (`alembic upgrade head`).
    email = normalize_email(email)
    async with async_session_factory() as session:
        user = (await session.execute(select(User).where(User.email == email))).scalar_one_or_none()
        if user is None:
            user = User(email=email)
            session.add(user)

        user.password_hash = hash_password(password)
        user.role = "super_admin"
        user.is_staff = True
        user.is_active = True

        await session.commit()
        await session.refresh(user)
        return user


def main() -> None:
    parser = argparse.ArgumentParser(description="Create or promote a super_admin user")
    parser.add_argument("--email", required=True)
    parser.add_argument("--password", required=True)
    args = parser.parse_args()

    user = asyncio.run(create_superuser(args.email, args.password))
    print(f"OK: super_admin tayyor -> id={user.id} email={user.email}")


if __name__ == "__main__":
    main()
