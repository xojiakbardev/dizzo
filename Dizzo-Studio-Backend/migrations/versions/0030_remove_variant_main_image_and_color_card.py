"""Remove variant main_image_media_id and variant_color card_media_id.

Revision ID: 0030
Revises: 0029
Create Date: 2026-09-19 12:45:00.000000

"""

from alembic import op
import sqlalchemy as sa


revision = '0030'
down_revision = '0029'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── Remove variant main_image_media_id ────────────────────────────────────
    op.drop_index('ix_variants_main_image_media_id', table_name='variants')
    op.drop_constraint('fk_variants_main_image_media_id_media', 'variants', type_='foreignkey')
    op.drop_column('variants', 'main_image_media_id')

    # ── Remove variant_colors card_media_id ───────────────────────────────────
    op.drop_index(op.f('ix_variant_colors_card_media_id'), table_name='variant_colors')
    op.drop_constraint(op.f('fk_variant_colors_card_media_id_media'), 'variant_colors', type_='foreignkey')
    op.drop_column('variant_colors', 'card_media_id')


def downgrade() -> None:
    op.add_column('variant_colors', sa.Column('card_media_id', sa.String(length=36), nullable=True))
    op.create_foreign_key(
        op.f('fk_variant_colors_card_media_id_media'),
        'variant_colors',
        'media',
        ['card_media_id'],
        ['id'],
        ondelete='SET NULL',
    )
    op.create_index(op.f('ix_variant_colors_card_media_id'), 'variant_colors', ['card_media_id'], unique=False)

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
