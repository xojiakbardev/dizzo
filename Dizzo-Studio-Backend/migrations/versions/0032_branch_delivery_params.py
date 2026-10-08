"""Add the BTS delivery parameters to branches.

The Branch model gained these columns with the Yandex/BTS delivery work
(cad52f5) but no migration shipped with it, so every query on branches
would fail against a migrated database.

Revision ID: 0032
Revises: 0031
Create Date: 2026-10-08 12:00:00.000000

"""

from alembic import op
import sqlalchemy as sa


revision = '0032'
down_revision = '0031'
branch_labels = None
depends_on = None


COLUMNS = (
    sa.Column('branch_type', sa.String(length=32), server_default='BTS', nullable=False),
    sa.Column('daily_order_capacity', sa.Integer(), server_default='20', nullable=False),
    sa.Column('delivery_days', sa.Integer(), server_default='3', nullable=False),
    sa.Column('base_shipping_cost', sa.Float(), server_default='35000', nullable=False),
)


def upgrade() -> None:
    # Tolerate a column someone already added by hand on a server.
    existing = {c['name'] for c in sa.inspect(op.get_bind()).get_columns('branches')}
    for column in COLUMNS:
        if column.name not in existing:
            op.add_column('branches', column.copy())


def downgrade() -> None:
    for column in reversed(COLUMNS):
        op.drop_column('branches', column.name)
