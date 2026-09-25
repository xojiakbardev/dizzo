"""area methods get a sliding strip width (laser on curved bodies)

A laser reaches only so far round a mug: with strip_width_mm set, all of a
method's layers must fit one strip that wide, which the customer may put
anywhere across the zone. Null keeps the whole zone, as before.

Revision ID: 0012
Revises: 0011
Create Date: 2026-09-16 12:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0012'
down_revision: str | None = '0011'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column('area_methods', sa.Column('strip_width_mm', sa.Numeric(precision=8, scale=2), nullable=True))


def downgrade() -> None:
    op.drop_column('area_methods', 'strip_width_mm')
