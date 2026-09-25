"""three languages: content translations and the user's language

Revision ID: 0024
Revises: 0023
Create Date: 2026-09-17 01:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0024'
down_revision: str | None = '0023'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TABLES = (
    'products', 'product_categories', 'shapes', 'print_areas', 'variants', 'variant_colors',
    'design_templates', 'tutorial_videos', 'order_items',
)


def upgrade() -> None:
    for table in TABLES:
        op.add_column(table, sa.Column('translations', sa.JSON(), server_default='{}', nullable=False))
    op.add_column('users', sa.Column('language', sa.String(length=8), server_default='uz', nullable=False))


def downgrade() -> None:
    op.drop_column('users', 'language')
    for table in TABLES:
        op.drop_column(table, 'translations')
