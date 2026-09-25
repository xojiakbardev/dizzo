"""orders: Idempotency-Key per customer; indexes for the order lists

orders.idempotency_key (unique per customer, NULL for orders placed without
one) makes a repeated checkout return the same order. Indexes: order lines
by order (every order load), orders by status (admin filter, dashboard
pipeline) and by created_at (lists, analytics). The media table needs
nothing new: it is read by primary key, `key` (unique), owner_id (indexed)
and the guest quota query (ix_media_uploader_ip_created_at).

Revision ID: 0020
Revises: 0019
Create Date: 2026-09-16 15:20:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0020'
down_revision: str | None = '0019'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column('orders', sa.Column('idempotency_key', sa.String(length=64), nullable=True))
    op.create_unique_constraint(
        op.f('uq_orders_customer_id_idempotency_key'), 'orders', ['customer_id', 'idempotency_key']
    )
    op.create_index(op.f('ix_orders_status'), 'orders', ['status'], unique=False)
    op.create_index('ix_orders_created_at', 'orders', ['created_at'], unique=False)
    op.create_index(op.f('ix_order_items_order_id'), 'order_items', ['order_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_order_items_order_id'), table_name='order_items')
    op.drop_index('ix_orders_created_at', table_name='orders')
    op.drop_index(op.f('ix_orders_status'), table_name='orders')
    op.drop_constraint(op.f('uq_orders_customer_id_idempotency_key'), 'orders', type_='unique')
    op.drop_column('orders', 'idempotency_key')
