"""admin-curated gallery showcase items with ordered images

Revision ID: 0017
Revises: 0016
Create Date: 2026-09-16 12:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0017'
down_revision: str | None = '0016'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table('gallery_showcase',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('product_id', sa.Integer(), nullable=False),
    sa.Column('title', sa.String(length=120), nullable=True),
    sa.Column('customer_name', sa.String(length=80), nullable=True),
    sa.Column('sort_order', sa.Integer(), server_default='0', nullable=False),
    sa.Column('is_published', sa.Boolean(), server_default=sa.false(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['product_id'], ['products.id'], name=op.f('fk_gallery_showcase_product_id_products'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_gallery_showcase'))
    )
    op.create_index(op.f('ix_gallery_showcase_product_id'), 'gallery_showcase', ['product_id'], unique=False)
    op.create_index(op.f('ix_gallery_showcase_is_published'), 'gallery_showcase', ['is_published'], unique=False)
    op.create_table('gallery_showcase_images',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('showcase_id', sa.Integer(), nullable=False),
    sa.Column('media_id', sa.String(length=36), nullable=False),
    sa.Column('sort_order', sa.Integer(), nullable=False),
    sa.ForeignKeyConstraint(['showcase_id'], ['gallery_showcase.id'], name=op.f('fk_gallery_showcase_images_showcase_id_gallery_showcase'), ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['media_id'], ['media.id'], name=op.f('fk_gallery_showcase_images_media_id_media'), ondelete='RESTRICT'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_gallery_showcase_images'))
    )
    op.create_index(op.f('ix_gallery_showcase_images_showcase_id'), 'gallery_showcase_images', ['showcase_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_gallery_showcase_images_showcase_id'), table_name='gallery_showcase_images')
    op.drop_table('gallery_showcase_images')
    op.drop_index(op.f('ix_gallery_showcase_is_published'), table_name='gallery_showcase')
    op.drop_index(op.f('ix_gallery_showcase_product_id'), table_name='gallery_showcase')
    op.drop_table('gallery_showcase')
