"""product categories: storefront shelves managed in the admin

The shelves were a fixed list; now each is a row with a name, an SVG icon
(or a picture) and a place in the list. The old "krujka" and "uy" shelves
become "idish-tovoq" and "uy-buyumlari".

Revision ID: 0010
Revises: 0009
Create Date: 2026-09-15 21:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0010'
down_revision: str | None = '0009'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Icons: Lucide (ISC licence).
SEED = [
        {'slug': 'idish-tovoq', 'name': 'Idish-tovoq', 'icon_svg': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 2v2m4-2v2m2 4a1 1 0 0 1 1 1v8a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4V9a1 1 0 0 1 1-1h14a4 4 0 1 1 0 8h-1M6 2v2"/></svg>', 'sort_order': 10},
        {'slug': 'uy-buyumlari', 'name': 'Uy-buyumlari', 'icon_svg': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M20 9V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v3"/><path d="M2 16a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-5a2 2 0 0 0-4 0v1.5a.5.5 0 0 1-.5.5h-11a.5.5 0 0 1-.5-.5V11a2 2 0 0 0-4 0zm2 2v2m16-2v2M12 4v9"/></g></svg>', 'sort_order': 20},
        {'slug': 'kiyim', 'name': 'Kiyim', 'icon_svg': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.38 3.46L16 2a4 4 0 0 1-8 0L3.62 3.46a2 2 0 0 0-1.34 2.23l.58 3.47a1 1 0 0 0 .99.84H6v10c0 1.1.9 2 2 2h8a2 2 0 0 0 2-2V10h2.15a1 1 0 0 0 .99-.84l.58-3.47a2 2 0 0 0-1.34-2.23"/></svg>', 'sort_order': 30},
        {'slug': 'aksessuar', 'name': 'Aksessuarlar', 'icon_svg': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M12 10v2.2l1.6 1m2.53-5.54l-.81-4.05a2 2 0 0 0-2-1.61h-2.68a2 2 0 0 0-2 1.61l-.78 4.05m.02 8.7l.8 4a2 2 0 0 0 2 1.61h2.72a2 2 0 0 0 2-1.61l.81-4.05"/><circle cx="12" cy="12" r="6"/></g></svg>', 'sort_order': 40},
        {'slug': 'boshqa', 'name': 'Boshqalar', 'icon_svg': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"><path d="M11 21.73a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73zm1 .27V12"/><path d="M3.29 7L12 12l8.71-5M7.5 4.27l9 5.15"/></g></svg>', 'sort_order': 90},
]


def upgrade() -> None:
    table = op.create_table(
        'product_categories',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('slug', sa.String(length=40), nullable=False),
        sa.Column('name', sa.String(length=80), nullable=False),
        sa.Column('icon_svg', sa.Text(), nullable=False, server_default=''),
        sa.Column('image_media_id', sa.String(length=36), sa.ForeignKey('media.id', ondelete='SET NULL'), nullable=True),
        sa.Column('sort_order', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('ix_product_categories_slug', 'product_categories', ['slug'], unique=True)
    op.bulk_insert(table, [dict(row, is_active=True) for row in SEED])
    op.alter_column('products', 'category', type_=sa.String(length=40), existing_nullable=False)
    op.execute("UPDATE products SET category = 'idish-tovoq' WHERE category = 'krujka'")
    op.execute("UPDATE products SET category = 'uy-buyumlari' WHERE category = 'uy'")


def downgrade() -> None:
    op.execute("UPDATE products SET category = 'krujka' WHERE category = 'idish-tovoq'")
    op.execute("UPDATE products SET category = 'uy' WHERE category = 'uy-buyumlari'")
    op.execute("UPDATE products SET category = 'boshqa' WHERE category NOT IN ('kiyim', 'krujka', 'uy', 'aksessuar')")
    op.alter_column('products', 'category', type_=sa.String(length=20), existing_nullable=False)
    op.drop_index('ix_product_categories_slug', table_name='product_categories')
    op.drop_table('product_categories')
