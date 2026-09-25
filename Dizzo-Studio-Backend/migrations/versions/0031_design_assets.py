"""Create design_assets table for Studio elements, icons, and stickers.

Revision ID: 0031
Revises: 0030
Create Date: 2026-09-19 16:50:00.000000

"""

from alembic import op
import sqlalchemy as sa


revision = '0031'
down_revision = '0030'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'design_assets',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('media_id', sa.String(length=36), nullable=False),
        sa.Column('name', sa.String(length=120), nullable=False),
        sa.Column('category', sa.String(length=50), server_default='boshqa', nullable=False),
        sa.Column('type', sa.String(length=20), server_default='icon', nullable=False),
        sa.Column('is_active', sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column('sort_order', sa.Integer(), server_default='0', nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['media_id'], ['media.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_design_assets_media_id'), 'design_assets', ['media_id'], unique=False)
    op.create_index(op.f('ix_design_assets_category'), 'design_assets', ['category'], unique=False)
    op.create_index(op.f('ix_design_assets_type'), 'design_assets', ['type'], unique=False)
    op.create_index(op.f('ix_design_assets_is_active'), 'design_assets', ['is_active'], unique=False)
    op.create_index(op.f('ix_design_assets_sort_order'), 'design_assets', ['sort_order'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_design_assets_sort_order'), table_name='design_assets')
    op.drop_index(op.f('ix_design_assets_is_active'), table_name='design_assets')
    op.drop_index(op.f('ix_design_assets_type'), table_name='design_assets')
    op.drop_index(op.f('ix_design_assets_category'), table_name='design_assets')
    op.drop_index(op.f('ix_design_assets_media_id'), table_name='design_assets')
    op.drop_table('design_assets')
