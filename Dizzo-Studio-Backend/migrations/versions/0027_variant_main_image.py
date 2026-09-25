"""Add main_image_media_id to variants for clean product preview without templates.

Revision ID: 0027_variant_main_image
Revises: 0026_multi_branch_and_moderation
Create Date: 2026-09-17 22:39:00.000000

"""

from alembic import op
import sqlalchemy as sa

revision = '0027'
down_revision = '0026'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('variants', sa.Column('main_image_media_id', sa.String(length=36), nullable=True))
    op.create_foreign_key(
        'fk_variants_main_image_media_id_media',
        'variants',
        'media',
        ['main_image_media_id'],
        ['id'],
        ondelete='SET NULL',
    )
    op.create_index('ix_variants_main_image_media_id', 'variants', ['main_image_media_id'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_variants_main_image_media_id', table_name='variants')
    op.drop_constraint('fk_variants_main_image_media_id_media', 'variants', type_='foreignkey')
    op.drop_column('variants', 'main_image_media_id')
