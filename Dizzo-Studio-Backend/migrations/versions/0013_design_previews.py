"""designs keep the Studio's five views ("Dizaynlarim" shows them)

Storage keys of the pictures taken on "Saqlash" or when the design went to
the cart, first one first. Older designs keep an empty list.

Revision ID: 0013
Revises: 0012
Create Date: 2026-09-16 18:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0013'
down_revision: str | None = '0012'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column('designs', sa.Column('previews', sa.JSON(), server_default='[]', nullable=False))


def downgrade() -> None:
    op.drop_column('designs', 'previews')
