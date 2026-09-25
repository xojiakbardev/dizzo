"""Per-size print scaling: every clothing size gets a print_scale.

A shape's print area is one rectangle in millimetres shared by every size,
and it is measured for the LARGEST size — the owner's rule is that 40 x 40
cm is the maximum, on the biggest garment. A size S body is far smaller, so
printing the same rectangle on it overflows the garment (and already
overflows the torso in the 3D preview). Each size therefore carries
`print_scale`: the share of the print area it may use, centred on the same
anchor.

`variants.sizes` is a JSON list, so there is no column to add. What this
migration does is fill in the scale for the sizes that already exist, so a
shop that is running today starts with sensible proportions instead of
every size printing at the maximum: 3XL 1.00, XXL 0.95, XL 0.90, L 0.85,
M 0.80, S 0.75, and 1.00 (unchanged behaviour) for any label that isn't one
of those — a numeric shoe size, a one-size product, anything the admin
invented. A size that already has a print_scale is left alone.

The downgrade takes the key out again, which is exactly what the code does
with a size that has none: it prints full size.

Revision ID: 0029
Revises: 0028
Create Date: 2026-09-19 00:00:00.000000

"""

import json
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = '0029'
down_revision: str | None = '0028'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# app/services/catalog.py DEFAULT_PRINT_SCALES — kept in step with it.
DEFAULTS = {
    '3XL': '1.00', 'XXXL': '1.00', 'XXL': '0.95', '2XL': '0.95',
    'XL': '0.90', 'L': '0.85', 'M': '0.80', 'S': '0.75',
}


def _rows(connection):
    return connection.execute(sa.text('SELECT id, sizes FROM variants')).fetchall()


def _sizes(raw) -> list | None:
    """The stored JSON as a list, whether the driver hands back text or
    already-decoded JSON. None: nothing worth rewriting."""
    value = json.loads(raw) if isinstance(raw, (str, bytes)) else raw
    return value if isinstance(value, list) and value else None


def _save(connection, variant_id: int, sizes: list) -> None:
    connection.execute(
        sa.text('UPDATE variants SET sizes = :sizes WHERE id = :id'),
        {'sizes': json.dumps(sizes, ensure_ascii=False), 'id': variant_id},
    )


def upgrade() -> None:
    connection = op.get_bind()
    for variant_id, raw in _rows(connection):
        sizes = _sizes(raw)
        if sizes is None:
            continue
        changed = False
        for size in sizes:
            if not isinstance(size, dict) or 'print_scale' in size:
                continue
            size['print_scale'] = DEFAULTS.get(str(size.get('label', '')).strip().upper(), '1.00')
            changed = True
        if changed:
            _save(connection, variant_id, sizes)


def downgrade() -> None:
    connection = op.get_bind()
    for variant_id, raw in _rows(connection):
        sizes = _sizes(raw)
        if sizes is None:
            continue
        changed = False
        for size in sizes:
            if isinstance(size, dict) and size.pop('print_scale', None) is not None:
                changed = True
        if changed:
            _save(connection, variant_id, sizes)
