"""customer reviews with photos, approved by an admin

Revision ID: 0007
Revises: 0006
Create Date: 2026-09-13 00:30:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0007'
down_revision: str | None = '0006'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        'reviews',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('order_id', sa.Integer(), sa.ForeignKey('orders.id', ondelete='SET NULL'), nullable=True, unique=True),
        sa.Column('name', sa.String(length=80), nullable=False),
        sa.Column('city', sa.String(length=80), server_default='', nullable=False),
        sa.Column('product_name', sa.String(length=200), server_default='', nullable=False),
        sa.Column('product_slug', sa.String(length=120), server_default='', nullable=False),
        sa.Column('rating', sa.Integer(), nullable=False),
        sa.Column('text', sa.Text(), nullable=False),
        sa.Column('status', sa.String(length=16), server_default='pending', nullable=False),
        sa.Column('sort_order', sa.Integer(), server_default='0', nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    )
    op.create_index('ix_reviews_user_id', 'reviews', ['user_id'])
    op.create_index('ix_reviews_status', 'reviews', ['status'])
    op.create_table(
        'review_photos',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('review_id', sa.Integer(), sa.ForeignKey('reviews.id', ondelete='CASCADE'), nullable=False),
        sa.Column('media_id', sa.String(length=36), sa.ForeignKey('media.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('sort_order', sa.Integer(), server_default='0', nullable=False),
    )
    op.create_index('ix_review_photos_review_id', 'review_photos', ['review_id'])


def downgrade() -> None:
    op.drop_index('ix_review_photos_review_id', table_name='review_photos')
    op.drop_table('review_photos')
    op.drop_index('ix_reviews_status', table_name='reviews')
    op.drop_index('ix_reviews_user_id', table_name='reviews')
    op.drop_table('reviews')
