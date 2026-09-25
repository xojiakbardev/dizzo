"""tutorial videos for the landing page ("Video darsliklar")

Revision ID: 0021
Revises: 0020
Create Date: 2026-09-16 18:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0021'
down_revision: str | None = '0020'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table('tutorial_videos',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('title', sa.String(length=120), nullable=False),
    sa.Column('cover_media_id', sa.String(length=36), nullable=False),
    sa.Column('cover_width', sa.Integer(), nullable=True),
    sa.Column('cover_height', sa.Integer(), nullable=True),
    sa.Column('video_url', sa.String(length=500), nullable=True),
    sa.Column('sort_order', sa.Integer(), server_default='0', nullable=False),
    sa.Column('is_published', sa.Boolean(), server_default=sa.false(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['cover_media_id'], ['media.id'], name=op.f('fk_tutorial_videos_cover_media_id_media'), ondelete='RESTRICT'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_tutorial_videos'))
    )
    op.create_index(op.f('ix_tutorial_videos_is_published'), 'tutorial_videos', ['is_published'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_tutorial_videos_is_published'), table_name='tutorial_videos')
    op.drop_table('tutorial_videos')
