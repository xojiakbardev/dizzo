"""token revocation: users.token_version and refresh_sessions

Every token now carries the user's token_version; bumping it revokes them
all. Refresh tokens carry a jti naming their refresh_sessions row, spent on
use (rotation). Tokens issued before this have neither claim: they count as
version 0 and keep working until refreshed once (or until the user's
version is bumped).

Revision ID: 0018
Revises: 0017
Create Date: 2026-09-16 15:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0018'
down_revision: str | None = '0017'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column('users', sa.Column('token_version', sa.Integer(), server_default='0', nullable=False))
    op.create_table('refresh_sessions',
    sa.Column('jti', sa.String(length=64), nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('rotated_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('replaced_by', sa.String(length=64), nullable=True),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_refresh_sessions_user_id_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('jti', name=op.f('pk_refresh_sessions'))
    )
    op.create_index(op.f('ix_refresh_sessions_user_id'), 'refresh_sessions', ['user_id'], unique=False)
    op.create_index(op.f('ix_refresh_sessions_expires_at'), 'refresh_sessions', ['expires_at'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_refresh_sessions_expires_at'), table_name='refresh_sessions')
    op.drop_index(op.f('ix_refresh_sessions_user_id'), table_name='refresh_sessions')
    op.drop_table('refresh_sessions')
    op.drop_column('users', 'token_version')
