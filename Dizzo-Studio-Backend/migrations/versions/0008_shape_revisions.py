"""shape revisions: a draft copy that replaces a shape once ready

Revision ID: 0008
Revises: 0007
Create Date: 2026-09-13 12:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0008'
down_revision: str | None = '0007'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column('shapes', sa.Column('replaces_id', sa.Integer(), nullable=True))
    op.create_foreign_key('fk_shapes_replaces_id_shapes', 'shapes', 'shapes', ['replaces_id'], ['id'], ondelete='SET NULL')


def downgrade() -> None:
    op.drop_constraint('fk_shapes_replaces_id_shapes', 'shapes', type_='foreignkey')
    op.drop_column('shapes', 'replaces_id')
