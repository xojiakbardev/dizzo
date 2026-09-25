"""A colour's own card picture, and where a gallery image came from.

Two independent changes, both about telling one kind of picture from another:

`variant_colors.card_media_id` is the clean, single photo of that colour —
the one the variant/colour selection cards show. Until now the card took
element 0 of the colour's gallery, so the admin had to put a card-shaped
photo first and the gallery started on it. The card now has its own column
and the gallery is free.

`catalog_images.source` says whether a gallery row was uploaded by a human
("manual") or produced by a renderer ("render"). A bulk regenerate can then
replace every 'render' row of an owner and never touch a photo somebody
took. Everything that exists today was uploaded by hand, so the column is
NOT NULL with 'manual' as its server default: existing rows are correct
before the CHECK that follows is ever applied.

Revision ID: 0028
Revises: 0027
Create Date: 2026-09-19 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0028'
down_revision: str | None = '0027'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

SOURCES = "source IN ('manual', 'render')"


def upgrade() -> None:
    # ── The colour's card picture ─────────────────────────────────────────
    # SET NULL, not RESTRICT: losing the card must never block deleting a
    # file, and a colour with no card simply has no card.
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

    # ── Where a gallery image came from ───────────────────────────────────
    op.add_column(
        'catalog_images',
        sa.Column('source', sa.String(length=16), server_default='manual', nullable=False),
    )
    # The server default already filled every existing row; said again in
    # SQL so this is safe on a database that was migrated by hand, and so
    # the CHECK below can never meet a value it would refuse.
    op.execute(f"UPDATE catalog_images SET source = 'manual' WHERE source IS NULL OR NOT ({SOURCES})")
    op.create_check_constraint(op.f('ck_catalog_images_source'), 'catalog_images', SOURCES)


def downgrade() -> None:
    op.drop_constraint(op.f('ck_catalog_images_source'), 'catalog_images', type_='check')
    op.drop_column('catalog_images', 'source')

    op.drop_index(op.f('ix_variant_colors_card_media_id'), table_name='variant_colors')
    op.drop_constraint(op.f('fk_variant_colors_card_media_id_media'), 'variant_colors', type_='foreignkey')
    op.drop_column('variant_colors', 'card_media_id')
