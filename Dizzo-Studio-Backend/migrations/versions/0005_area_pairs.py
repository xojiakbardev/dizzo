"""area pairs: symmetric print areas (left and right sleeve)

Revision ID: 0005
Revises: 0004
Create Date: 2026-09-12 20:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0005'
down_revision: str | None = '0004'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column('print_areas', sa.Column('pair_key', sa.String(length=32), nullable=True))
    op.add_column('print_areas', sa.Column('pair_mirror', sa.Boolean(), server_default=sa.true(), nullable=False))


def downgrade() -> None:
    op.drop_column('print_areas', 'pair_mirror')
    op.drop_column('print_areas', 'pair_key')
