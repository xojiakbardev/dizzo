"""products lose their short description; order numbers run 0000001, 0000002…

The product's description is now rich text (a safe HTML subset); the
short line under it is gone. Orders are numbered by their id, seven digits.

Revision ID: 0011
Revises: 0010
Create Date: 2026-09-16 10:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0011'
down_revision: str | None = '0010'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.drop_column('products', 'short_description')
    op.execute("UPDATE orders SET order_number = lpad(id::text, 7, '0')")


def downgrade() -> None:
    op.add_column('products', sa.Column('short_description', sa.String(length=300), nullable=False, server_default=''))
