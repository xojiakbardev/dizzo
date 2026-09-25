from datetime import datetime

from sqlalchemy import JSON, DateTime, MetaData, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

# Deterministic constraint/index names, so Alembic migrations can always
# refer to (and drop) a constraint by a name known in advance.
NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    # column_0_N_name: every column of a multi-column constraint, so two
    # constraints starting with the same column never share a name.
    "uq": "uq_%(table_name)s_%(column_0_N_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}


class Base(DeclarativeBase):
    metadata = MetaData(naming_convention=NAMING_CONVENTION)


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class TranslatableMixin:
    """Content in three languages: Uzbek in the row's own columns, Russian
    and English here — {"ru": {"name": ...}, "en": {...}} (app/core/i18n.py)."""

    translations: Mapped[dict] = mapped_column(JSON, default=dict, server_default="{}")
