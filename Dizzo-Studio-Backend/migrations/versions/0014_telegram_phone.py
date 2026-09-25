"""profile phones from Telegram logins

Telegram's login shares the user's verified phone; it was kept with the
login's other details but never reached the profile. Fills empty profile
phones from it (as +digits); a phone already there stays.

Revision ID: 0014
Revises: 0013
Create Date: 2026-09-16 21:00:00
"""

from collections.abc import Sequence

from alembic import op

revision: str = '0014'
down_revision: str | None = '0013'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    if op.get_bind().dialect.name != 'postgresql':
        return
    op.execute(
        """
        UPDATE users AS u
        SET phone_number = '+' || regexp_replace(s.extra_data::jsonb ->> 'phone_number', '[^0-9]', '', 'g')
        FROM social_connections AS s
        WHERE s.user_id = u.id
          AND s.provider = 'telegram'
          AND coalesce(u.phone_number, '') = ''
          AND regexp_replace(coalesce(s.extra_data::jsonb ->> 'phone_number', ''), '[^0-9]', '', 'g') <> ''
          AND coalesce(s.extra_data::jsonb ->> 'phone_number_verified', 'true') <> 'false'
        """
    )


def downgrade() -> None:
    pass  # the phones stay: they're the users' own
