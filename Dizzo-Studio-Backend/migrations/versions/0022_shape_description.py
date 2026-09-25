"""shape description: a short line under the name in the admin's shape pickers

Revision ID: 0022
Revises: 0021
Create Date: 2026-09-16 20:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0022'
down_revision: str | None = '0021'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column('shapes', sa.Column('description', sa.String(length=200), server_default='', nullable=False))


def downgrade() -> None:
    op.drop_column('shapes', 'description')
