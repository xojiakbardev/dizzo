"""studio: designs, package-based cart and orders; drop the category catalog

The old editor's drafts, product types and category tree are replaced by
the dynamic catalog (0003) and Studio designs. Cart items become frozen
packages; order items keep a package copy instead of category strings.
Existing carts are emptied (their drafts no longer exist).

Revision ID: 0004
Revises: 0003
Create Date: 2026-09-12 12:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0004'
down_revision: str | None = '0003'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def timestamps() -> list[sa.Column]:
    return [
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    ]


def upgrade() -> None:
    op.create_table(
        'designs',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('owner_id', sa.Integer(), nullable=False),
        sa.Column('product_id', sa.Integer(), nullable=False),
        sa.Column('variant_id', sa.Integer(), nullable=False),
        sa.Column('color_id', sa.Integer(), nullable=False),
        sa.Column('document', sa.JSON(), nullable=False),
        sa.Column('version', sa.Integer(), nullable=False),
        sa.Column('areas_cm2', sa.JSON(), nullable=False),
        sa.Column('preview_media_id', sa.String(length=36), nullable=True),
        *timestamps(),
        sa.ForeignKeyConstraint(['owner_id'], ['users.id'], name=op.f('fk_designs_owner_id_users'), ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['product_id'], ['products.id'], name=op.f('fk_designs_product_id_products'), ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['variant_id'], ['variants.id'], name=op.f('fk_designs_variant_id_variants'), ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(
            ['color_id'], ['variant_colors.id'], name=op.f('fk_designs_color_id_variant_colors'), ondelete='RESTRICT'
        ),
        sa.ForeignKeyConstraint(
            ['preview_media_id'], ['media.id'], name=op.f('fk_designs_preview_media_id_media'), ondelete='SET NULL'
        ),
        sa.PrimaryKeyConstraint('id', name=op.f('pk_designs')),
    )
    op.create_index(op.f('ix_designs_owner_id'), 'designs', ['owner_id'], unique=False)
    op.create_index(op.f('ix_designs_product_id'), 'designs', ['product_id'], unique=False)

    op.drop_index(op.f('ix_cart_items_draft_uuid'), table_name='cart_items')
    op.drop_table('cart_items')
    op.create_table(
        'cart_items',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('uuid', sa.String(length=36), nullable=False),
        sa.Column('cart_id', sa.Integer(), nullable=False),
        sa.Column('design_id', sa.String(length=36), nullable=True),
        sa.Column('variant_id', sa.Integer(), nullable=False),
        sa.Column('color_id', sa.Integer(), nullable=False),
        sa.Column('quantity', sa.Integer(), nullable=False),
        sa.Column('unit_price', sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column('package', sa.JSON(), nullable=False),
        *timestamps(),
        sa.ForeignKeyConstraint(['cart_id'], ['carts.id'], name=op.f('fk_cart_items_cart_id_carts'), ondelete='CASCADE'),
        sa.ForeignKeyConstraint(
            ['design_id'], ['designs.id'], name=op.f('fk_cart_items_design_id_designs'), ondelete='SET NULL'
        ),
        sa.ForeignKeyConstraint(
            ['variant_id'], ['variants.id'], name=op.f('fk_cart_items_variant_id_variants'), ondelete='RESTRICT'
        ),
        sa.ForeignKeyConstraint(
            ['color_id'], ['variant_colors.id'], name=op.f('fk_cart_items_color_id_variant_colors'), ondelete='RESTRICT'
        ),
        sa.PrimaryKeyConstraint('id', name=op.f('pk_cart_items')),
        sa.UniqueConstraint('uuid', name=op.f('uq_cart_items_uuid')),
    )
    op.create_index(op.f('ix_cart_items_cart_id'), 'cart_items', ['cart_id'], unique=False)

    op.drop_index(op.f('ix_order_items_draft_uuid'), table_name='order_items')
    for column in ('category_name', 'category_path', 'design_title', 'draft_uuid'):
        op.drop_column('order_items', column)
    op.add_column('order_items', sa.Column('product_slug', sa.String(length=120), server_default='', nullable=False))
    op.add_column('order_items', sa.Column('variant_name', sa.String(length=150), server_default='', nullable=False))
    op.add_column('order_items', sa.Column('color_name', sa.String(length=100), server_default='', nullable=False))
    op.add_column('order_items', sa.Column('color_hex', sa.String(length=7), server_default='', nullable=False))
    op.add_column('order_items', sa.Column('package', sa.JSON(), server_default=sa.text("'{}'"), nullable=False))

    op.drop_index(op.f('ix_drafts_uuid'), table_name='drafts')
    op.drop_index(op.f('ix_drafts_customer_id'), table_name='drafts')
    op.drop_table('drafts')
    op.drop_index(op.f('ix_categories_product_type_id'), table_name='categories')
    op.drop_index(op.f('ix_categories_parent_id'), table_name='categories')
    op.drop_table('categories')
    op.drop_index(op.f('ix_product_types_slug'), table_name='product_types')
    op.drop_index(op.f('ix_product_types_category'), table_name='product_types')
    op.drop_table('product_types')


def downgrade() -> None:
    op.create_table(
        'product_types',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('slug', sa.String(length=120), nullable=False),
        sa.Column('category', sa.String(length=32), nullable=False),
        sa.Column('description', sa.Text(), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('sort_order', sa.Integer(), nullable=False),
        *timestamps(),
        sa.PrimaryKeyConstraint('id', name=op.f('pk_product_types')),
    )
    op.create_index(op.f('ix_product_types_category'), 'product_types', ['category'], unique=False)
    op.create_index(op.f('ix_product_types_slug'), 'product_types', ['slug'], unique=True)
    op.create_table(
        'categories',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('product_type_id', sa.Integer(), nullable=False),
        sa.Column('parent_id', sa.Integer(), nullable=True),
        sa.Column('name', sa.String(length=150), nullable=False),
        sa.Column('price', sa.Numeric(precision=12, scale=2), nullable=True),
        sa.Column('color_hex', sa.String(length=7), nullable=False),
        sa.Column('image_url', sa.Text(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('sort_order', sa.Integer(), nullable=False),
        *timestamps(),
        sa.ForeignKeyConstraint(
            ['parent_id'], ['categories.id'], name=op.f('fk_categories_parent_id_categories'), ondelete='CASCADE'
        ),
        sa.ForeignKeyConstraint(
            ['product_type_id'], ['product_types.id'], name=op.f('fk_categories_product_type_id_product_types'),
            ondelete='CASCADE',
        ),
        sa.PrimaryKeyConstraint('id', name=op.f('pk_categories')),
    )
    op.create_index(op.f('ix_categories_parent_id'), 'categories', ['parent_id'], unique=False)
    op.create_index(op.f('ix_categories_product_type_id'), 'categories', ['product_type_id'], unique=False)
    op.create_table(
        'drafts',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('uuid', sa.String(length=36), nullable=False),
        sa.Column('customer_id', sa.Integer(), nullable=False),
        sa.Column('product_type_id', sa.Integer(), nullable=False),
        sa.Column('category_id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=200), nullable=False),
        sa.Column('text_layers', sa.JSON(), nullable=False),
        sa.Column('editor_state', sa.JSON(), nullable=False),
        sa.Column('status', sa.String(length=32), nullable=False),
        sa.Column('preview_image_url', sa.Text(), nullable=True),
        *timestamps(),
        sa.ForeignKeyConstraint(
            ['category_id'], ['categories.id'], name=op.f('fk_drafts_category_id_categories'), ondelete='RESTRICT'
        ),
        sa.ForeignKeyConstraint(['customer_id'], ['users.id'], name=op.f('fk_drafts_customer_id_users'), ondelete='CASCADE'),
        sa.ForeignKeyConstraint(
            ['product_type_id'], ['product_types.id'], name=op.f('fk_drafts_product_type_id_product_types')
        ),
        sa.PrimaryKeyConstraint('id', name=op.f('pk_drafts')),
    )
    op.create_index(op.f('ix_drafts_customer_id'), 'drafts', ['customer_id'], unique=False)
    op.create_index(op.f('ix_drafts_uuid'), 'drafts', ['uuid'], unique=True)

    for column in ('package', 'color_hex', 'color_name', 'variant_name', 'product_slug'):
        op.drop_column('order_items', column)
    op.add_column('order_items', sa.Column('category_name', sa.String(length=150), server_default='', nullable=False))
    op.add_column('order_items', sa.Column('category_path', sa.String(length=400), server_default='', nullable=False))
    op.add_column('order_items', sa.Column('design_title', sa.String(length=200), server_default='', nullable=False))
    op.add_column('order_items', sa.Column('draft_uuid', sa.String(length=36), server_default='', nullable=False))
    op.create_index(op.f('ix_order_items_draft_uuid'), 'order_items', ['draft_uuid'], unique=False)

    op.drop_index(op.f('ix_cart_items_cart_id'), table_name='cart_items')
    op.drop_table('cart_items')
    op.create_table(
        'cart_items',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('uuid', sa.String(length=36), nullable=False),
        sa.Column('cart_id', sa.Integer(), nullable=False),
        sa.Column('draft_uuid', sa.String(length=36), nullable=False),
        sa.Column('quantity', sa.Integer(), nullable=False),
        sa.Column('unit_price', sa.Numeric(precision=12, scale=2), nullable=False),
        *timestamps(),
        sa.ForeignKeyConstraint(['cart_id'], ['carts.id'], name=op.f('fk_cart_items_cart_id_carts'), ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id', name=op.f('pk_cart_items')),
        sa.UniqueConstraint('uuid', name=op.f('uq_cart_items_uuid')),
    )
    op.create_index(op.f('ix_cart_items_draft_uuid'), 'cart_items', ['draft_uuid'], unique=False)

    op.drop_index(op.f('ix_designs_product_id'), table_name='designs')
    op.drop_index(op.f('ix_designs_owner_id'), table_name='designs')
    op.drop_table('designs')
