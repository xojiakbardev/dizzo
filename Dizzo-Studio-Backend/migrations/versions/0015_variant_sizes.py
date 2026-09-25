"""clothing sizes on a variant, and the chosen one on the cart and the order

A variant keeps its sizes as an ordered JSON list
([{"label": "M", "surcharge": "0.00", "is_available": true}]); everything
that has no sizes (a mug, a clock) keeps an empty list and never asks for
one. The customer's choice is stored on the cart item and copied to the
order item, so whoever produces the order reads it there.

Revision ID: 0015
Revises: 0014
Create Date: 2026-09-16 23:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0015'
down_revision: str | None = '0014'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column('variants', sa.Column('sizes', sa.JSON(), server_default='[]', nullable=False))
    op.add_column('cart_items', sa.Column('size', sa.String(length=20), server_default='', nullable=False))
    op.add_column('order_items', sa.Column('size', sa.String(length=20), server_default='', nullable=False))


def downgrade() -> None:
    op.drop_column('order_items', 'size')
    op.drop_column('cart_items', 'size')
    op.drop_column('variants', 'sizes')
