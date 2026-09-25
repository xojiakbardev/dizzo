"""design templates: ready designs per variant, made by admins in the Studio

Revision ID: 0006
Revises: 0005
Create Date: 2026-09-12 21:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0006'
down_revision: str | None = '0005'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        'design_templates',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('product_id', sa.Integer(), sa.ForeignKey('products.id', ondelete='CASCADE'), nullable=False),
        sa.Column('name', sa.String(length=120), nullable=False),
        sa.Column('category', sa.String(length=60), server_default='', nullable=False),
        sa.Column('document', sa.JSON(), nullable=False),
        sa.Column('preview_media_id', sa.String(length=36), sa.ForeignKey('media.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('is_active', sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column('sort_order', sa.Integer(), server_default='0', nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    )
    op.create_index('ix_design_templates_product_id', 'design_templates', ['product_id'])
    op.create_table(
        'design_template_variants',
        sa.Column('template_id', sa.Integer(), sa.ForeignKey('design_templates.id', ondelete='CASCADE'), primary_key=True),
        sa.Column('variant_id', sa.Integer(), sa.ForeignKey('variants.id', ondelete='CASCADE'), primary_key=True),
    )


def downgrade() -> None:
    op.drop_table('design_template_variants')
    op.drop_index('ix_design_templates_product_id', table_name='design_templates')
    op.drop_table('design_templates')
