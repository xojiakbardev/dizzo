"""Telegram sign-in codes for the mobile app

The app opens t.me/<bot>?start=login_<token>; the Telegram user confirms
(or cancels) the code in the bot, and the app polls it for a token pair, once.

Revision ID: 0016
Revises: 0015
Create Date: 2026-09-17 12:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0016'
down_revision: str | None = '0015'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table('telegram_app_logins',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('token', sa.String(length=64), nullable=False),
    sa.Column('requester_ip', sa.String(length=64), nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=True),
    sa.Column('confirmed_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('used_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('cancelled_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], name=op.f('fk_telegram_app_logins_user_id_users'), ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id', name=op.f('pk_telegram_app_logins'))
    )
    op.create_index(op.f('ix_telegram_app_logins_token'), 'telegram_app_logins', ['token'], unique=True)
    op.create_index(op.f('ix_telegram_app_logins_requester_ip'), 'telegram_app_logins', ['requester_ip'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_telegram_app_logins_requester_ip'), table_name='telegram_app_logins')
    op.drop_index(op.f('ix_telegram_app_logins_token'), table_name='telegram_app_logins')
    op.drop_table('telegram_app_logins')
