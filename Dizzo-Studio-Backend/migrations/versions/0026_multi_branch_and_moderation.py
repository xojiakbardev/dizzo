"""multi-branch infrastructure and gallery moderation

Revision ID: 0026
Revises: 0025
Create Date: 2026-09-17 22:10:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0026'
down_revision: str | None = '0025'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. branches table
    op.create_table(
        'branches',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=120), nullable=False),
        sa.Column('slug', sa.String(length=120), nullable=False),
        sa.Column('phone', sa.String(length=32), nullable=True),
        sa.Column('address', sa.String(length=255), nullable=False),
        sa.Column('city', sa.String(length=80), server_default='Toshkent', nullable=False),
        sa.Column('latitude', sa.Float(), nullable=False),
        sa.Column('longitude', sa.Float(), nullable=False),
        sa.Column('work_hours', sa.String(length=120), server_default='09:00 - 20:00', nullable=False),
        sa.Column('is_active', sa.Boolean(), server_default=sa.text('true'), nullable=False),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_branches_name', 'branches', ['name'], unique=False)
    op.create_index('ix_branches_slug', 'branches', ['slug'], unique=True)
    op.create_index('ix_branches_city', 'branches', ['city'], unique=False)
    op.create_index('ix_branches_is_active', 'branches', ['is_active'], unique=False)

    # 2. branch_products table (branch-level inventory/availability)
    op.create_table(
        'branch_products',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('branch_id', sa.Integer(), nullable=False),
        sa.Column('product_id', sa.Integer(), nullable=False),
        sa.Column('is_available', sa.Boolean(), server_default=sa.text('true'), nullable=False),
        sa.Column('reason', sa.String(length=255), nullable=True),
        sa.ForeignKeyConstraint(['branch_id'], ['branches.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['product_id'], ['products.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('branch_id', 'product_id', name='uq_branch_product'),
    )
    op.create_index('ix_branch_products_branch_id', 'branch_products', ['branch_id'], unique=False)
    op.create_index('ix_branch_products_product_id', 'branch_products', ['product_id'], unique=False)
    op.create_index('ix_branch_products_is_available', 'branch_products', ['is_available'], unique=False)

    # 3. users table: add branch_id
    op.add_column('users', sa.Column('branch_id', sa.Integer(), nullable=True))
    op.create_foreign_key('fk_users_branch_id_branches', 'users', 'branches', ['branch_id'], ['id'], ondelete='SET NULL')
    op.create_index('ix_users_branch_id', 'users', ['branch_id'], unique=False)

    # 4. orders table: add branch_id
    op.add_column('orders', sa.Column('branch_id', sa.Integer(), nullable=True))
    op.create_foreign_key('fk_orders_branch_id_branches', 'orders', 'branches', ['branch_id'], ['id'], ondelete='SET NULL')
    op.create_index('ix_orders_branch_id', 'orders', ['branch_id'], unique=False)

    # 5. gallery_showcase table: moderation and creator tracking
    op.add_column('gallery_showcase', sa.Column('created_by_id', sa.Integer(), nullable=True))
    op.add_column('gallery_showcase', sa.Column('branch_id', sa.Integer(), nullable=True))
    op.add_column('gallery_showcase', sa.Column('status', sa.String(length=32), server_default='APPROVED', nullable=False))
    op.add_column('gallery_showcase', sa.Column('rejection_reason', sa.String(length=255), nullable=True))
    op.create_foreign_key('fk_gallery_showcase_created_by_id_users', 'gallery_showcase', 'users', ['created_by_id'], ['id'], ondelete='SET NULL')
    op.create_foreign_key('fk_gallery_showcase_branch_id_branches', 'gallery_showcase', 'branches', ['branch_id'], ['id'], ondelete='SET NULL')
    op.create_index('ix_gallery_showcase_created_by_id', 'gallery_showcase', ['created_by_id'], unique=False)
    op.create_index('ix_gallery_showcase_branch_id', 'gallery_showcase', ['branch_id'], unique=False)
    op.create_index('ix_gallery_showcase_status', 'gallery_showcase', ['status'], unique=False)

    # 6. system_settings table
    op.create_table(
        'system_settings',
        sa.Column('key', sa.String(length=64), nullable=False),
        sa.Column('value', sa.Text(), server_default='', nullable=False),
        sa.Column('description', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint('key'),
    )


def downgrade() -> None:
    # 6. system_settings
    op.drop_table('system_settings')

    # 5. gallery_showcase
    op.drop_index('ix_gallery_showcase_status', table_name='gallery_showcase')
    op.drop_index('ix_gallery_showcase_branch_id', table_name='gallery_showcase')
    op.drop_index('ix_gallery_showcase_created_by_id', table_name='gallery_showcase')
    op.drop_constraint('fk_gallery_showcase_branch_id_branches', 'gallery_showcase', type_='foreignkey')
    op.drop_constraint('fk_gallery_showcase_created_by_id_users', 'gallery_showcase', type_='foreignkey')
    op.drop_column('gallery_showcase', 'rejection_reason')
    op.drop_column('gallery_showcase', 'status')
    op.drop_column('gallery_showcase', 'branch_id')
    op.drop_column('gallery_showcase', 'created_by_id')

    # 4. orders
    op.drop_index('ix_orders_branch_id', table_name='orders')
    op.drop_constraint('fk_orders_branch_id_branches', 'orders', type_='foreignkey')
    op.drop_column('orders', 'branch_id')

    # 3. users
    op.drop_index('ix_users_branch_id', table_name='users')
    op.drop_constraint('fk_users_branch_id_branches', 'users', type_='foreignkey')
    op.drop_column('users', 'branch_id')

    # 2. branch_products
    op.drop_index('ix_branch_products_is_available', table_name='branch_products')
    op.drop_index('ix_branch_products_product_id', table_name='branch_products')
    op.drop_index('ix_branch_products_branch_id', table_name='branch_products')
    op.drop_table('branch_products')

    # 1. branches
    op.drop_index('ix_branches_is_active', table_name='branches')
    op.drop_index('ix_branches_city', table_name='branches')
    op.drop_index('ix_branches_slug', table_name='branches')
    op.drop_index('ix_branches_name', table_name='branches')
    op.drop_table('branches')
