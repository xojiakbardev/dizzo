"""templates are the gallery: pictures, a gallery flag and a shown colour

Revision ID: 0023
Revises: 0022
Create Date: 2026-09-16 22:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0023'
down_revision: str | None = '0022'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column('design_templates', sa.Column('in_gallery', sa.Boolean(), server_default=sa.false(), nullable=False))
    op.add_column('design_templates', sa.Column('color_id', sa.Integer(), nullable=True))
    op.create_foreign_key(
        op.f('fk_design_templates_color_id_variant_colors'), 'design_templates', 'variant_colors',
        ['color_id'], ['id'], ondelete='SET NULL',
    )
    op.create_index(op.f('ix_design_templates_in_gallery'), 'design_templates', ['in_gallery'], unique=False)
    op.create_table('design_template_images',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('template_id', sa.Integer(), nullable=False),
    sa.Column('media_id', sa.String(length=36), nullable=False),
    sa.Column('sort_order', sa.Integer(), nullable=False),
    sa.ForeignKeyConstraint(['media_id'], ['media.id'], name=op.f('fk_design_template_images_media_id_media'), ondelete='RESTRICT'),
    sa.ForeignKeyConstraint(['template_id'], ['design_templates.id'], name=op.f('fk_design_template_images_template_id_design_templates'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_design_template_images'))
    )
    op.create_index(op.f('ix_design_template_images_template_id'), 'design_template_images', ['template_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_design_template_images_template_id'), table_name='design_template_images')
    op.drop_table('design_template_images')
    op.drop_index(op.f('ix_design_templates_in_gallery'), table_name='design_templates')
    op.drop_constraint(op.f('fk_design_templates_color_id_variant_colors'), 'design_templates', type_='foreignkey')
    op.drop_column('design_templates', 'color_id')
    op.drop_column('design_templates', 'in_gallery')
