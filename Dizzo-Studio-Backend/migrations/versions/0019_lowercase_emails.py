"""lowercase users.email (emails are case-insensitive from now on)

The app now stores and looks emails up lowercased. Existing addresses are
lowercased here, except where that would collide: of the accounts whose
emails differ only in case, the lowest id gets the lowercase address
(unless one of them already has it) and the others keep theirs untouched.
Those left over can't sign in by email any more: each is printed as a
warning here and needs a manual merge or an address change.

Check before upgrading:
    SELECT lower(email), array_agg(id ORDER BY id) FROM users
    WHERE email IS NOT NULL GROUP BY lower(email) HAVING count(*) > 1;

Downgrade is a no-op: the original case isn't kept.

Revision ID: 0019
Revises: 0018
Create Date: 2026-09-16 15:10:00
"""

import logging
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0019'
down_revision: str | None = '0018'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

logger = logging.getLogger("alembic.runtime.migration")

LOWERCASE = sa.text("""
    UPDATE users SET email = lower(email)
    WHERE email IS NOT NULL
      AND email <> lower(email)
      AND id = (SELECT min(u2.id) FROM users u2 WHERE lower(u2.email) = lower(users.email))
      AND NOT EXISTS (SELECT 1 FROM users u3 WHERE u3.email = lower(users.email))
""")
LEFT_OVER = sa.text("""
    SELECT id, email FROM users WHERE email IS NOT NULL AND email <> lower(email) ORDER BY id
""")


def lowercase_emails(connection: sa.Connection) -> list[tuple[int, str]]:
    """Lowercases what it safely can; returns the (id, email) rows left as they were."""
    connection.execute(LOWERCASE)
    return [(row.id, row.email) for row in connection.execute(LEFT_OVER)]


def upgrade() -> None:
    if op.get_context().as_sql:
        op.execute(LOWERCASE)
        return
    for user_id, email in lowercase_emails(op.get_bind()):
        logger.warning("0019: user %s keeps email %r: another account already has it in lowercase", user_id, email)


def downgrade() -> None:
    pass
