"""Dynamic catalog: everything the storefront and the Studio show comes from
these tables, managed only through the admin panel.

Product -> Shape (dimensions, 3D rendering, print areas) and
Product -> Variant (picks a Shape, carries the base price) -> Color.
Nothing here is ever hard-deleted once it can be referenced by a cart or an
order: rows are archived (archived_at) instead.

Lengths are millimetres, stored as Numeric so validation is exact.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Table,
    Text,
    UniqueConstraint,
    false,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, TranslatableMixin
from app.models.media import Media

METHODS = ("uv", "engrave")
SHAPE_KINDS = ("cylinder", "plane", "disc", "model")
SHAPE_STATUSES = ("draft", "ready")
MATERIALS = (
    "ceramic_glossy",
    "ceramic_matte",
    "glass_clear",
    "glass_frosted",
    "fabric",
    "paper",
    "plastic",
    "metal",
    "wood",
)

MM = Numeric(8, 2)
MONEY = Numeric(12, 2)

# Where a gallery picture came from: a human upload, or a renderer. Only
# 'render' rows may be thrown away and rebuilt by a bulk regenerate.
IMAGE_SOURCES = ("manual", "render")


class Product(TimestampMixin, TranslatableMixin, Base):
    __tablename__ = "products"

    id: Mapped[int] = mapped_column(primary_key=True)
    slug: Mapped[str] = mapped_column(String(120), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(150))
    description: Mapped[str] = mapped_column(Text, default="")  # rich text: services.rich_text
    cover_media_id: Mapped[str | None] = mapped_column(ForeignKey("media.id", ondelete="SET NULL"), nullable=True)
    is_featured: Mapped[bool] = mapped_column(Boolean, default=True)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    # Storefront shelf: the slug of a ProductCategory.
    category: Mapped[str] = mapped_column(String(40), default="boshqa", server_default="boshqa")
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Eager ("selectin") everywhere: the catalog is small, always read as a
    # whole, and async sessions can't lazy-load while serializing.
    cover: Mapped[Media | None] = relationship(lazy="selectin")
    images: Mapped[list[CatalogImage]] = relationship(
        foreign_keys="CatalogImage.product_id", order_by="CatalogImage.sort_order", lazy="selectin",
        cascade="all, delete-orphan",
    )
    shapes: Mapped[list[Shape]] = relationship(back_populates="product", order_by="Shape.id", lazy="selectin")
    variants: Mapped[list[Variant]] = relationship(
        back_populates="product", order_by="(Variant.sort_order, Variant.id)", lazy="selectin"
    )
    price_tiers: Mapped[list[PriceTier]] = relationship(
        back_populates="product", cascade="all, delete-orphan", order_by="(PriceTier.method, PriceTier.min_cm2)",
        lazy="selectin",
    )
    templates: Mapped[list[DesignTemplate]] = relationship(
        "DesignTemplate",
        back_populates="product",
        order_by="(DesignTemplate.sort_order, DesignTemplate.id)",
        lazy="selectin",
        cascade="all, delete-orphan",
    )


class ProductCategory(TimestampMixin, TranslatableMixin, Base):
    """A storefront shelf ("Idish-tovoq", "Kiyim"…), managed in the admin:
    its name, an SVG icon or a picture, and its place in the list. Products
    point to it by slug."""

    __tablename__ = "product_categories"

    id: Mapped[int] = mapped_column(primary_key=True)
    slug: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(80))
    icon_svg: Mapped[str] = mapped_column(Text, default="", server_default="")
    image_media_id: Mapped[str | None] = mapped_column(ForeignKey("media.id", ondelete="SET NULL"), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    image: Mapped[Media | None] = relationship(lazy="selectin")


class Shape(TimestampMixin, TranslatableMixin, Base):
    """A physical body ("Krujka 330 ml"): its dimensions, how it is drawn in
    3D and where it can be printed. Variants pick a shape. Once a design
    uses it, it is locked; changes are made on a revision — a draft copy
    (`replaces_id`) that takes its place, variants and all, once ready."""

    __tablename__ = "shapes"
    __table_args__ = (
        CheckConstraint(f"kind IN {SHAPE_KINDS}", name="kind"),
        CheckConstraint(f"status IN {SHAPE_STATUSES}", name="status"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(150))
    # A short line under the name in the admin's shape pickers ("oq, 330 ml").
    description: Mapped[str] = mapped_column(String(200), default="", server_default="")
    kind: Mapped[str] = mapped_column(String(16))
    # Kind-specific, validated by app.schemas.catalog: cylinder
    # {diameter_mm, height_mm, handle, handle_gap_mm}, plane {width_mm,
    # height_mm, sides}, disc {diameter_mm}, model {} (size comes from the GLB).
    dims: Mapped[dict] = mapped_column(JSON, default=dict)
    model_media_id: Mapped[str | None] = mapped_column(ForeignKey("media.id", ondelete="RESTRICT"), nullable=True)
    model_transform: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    mm_per_unit: Mapped[Decimal | None] = mapped_column(Numeric(12, 6), nullable=True)
    status: Mapped[str] = mapped_column(String(16), default="draft")
    locked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    replaces_id: Mapped[int | None] = mapped_column(ForeignKey("shapes.id", ondelete="SET NULL"), nullable=True)

    product: Mapped[Product] = relationship(back_populates="shapes")
    model: Mapped[Media | None] = relationship(lazy="selectin")
    areas: Mapped[list[PrintArea]] = relationship(
        back_populates="shape", cascade="all, delete-orphan", order_by="(PrintArea.sort_order, PrintArea.id)",
        lazy="selectin",
    )


class PrintArea(TimestampMixin, TranslatableMixin, Base):
    """A printable region of a shape, with its real size. `key` is stable
    (front, back, wrap…): when a customer switches to a variant with a
    different shape, layers move to the area with the same key."""

    __tablename__ = "print_areas"
    __table_args__ = (UniqueConstraint("shape_id", "key"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    shape_id: Mapped[int] = mapped_column(ForeignKey("shapes.id", ondelete="CASCADE"), index=True)
    key: Mapped[str] = mapped_column(String(32))
    name: Mapped[str] = mapped_column(String(100))
    width_mm: Mapped[Decimal] = mapped_column(MM)
    height_mm: Mapped[Decimal] = mapped_column(MM)
    # Where the area sits on the shape, kind-specific: cylinder {start_mm,
    # top_mm}, plane {side, x_mm, y_mm}, disc {x_mm, y_mm}, model {point,
    # normal, rotation_deg, depth_mm, max_angle_deg}.
    anchor: Mapped[dict] = mapped_column(JSON, default=dict)
    camera: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    placement_note: Mapped[str] = mapped_column(Text, default="")
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    # Symmetric partner on the same shape (left ↔ right sleeve), by key. Both
    # sides point at each other and always share size and methods; with
    # pair_mirror the partner's zones — and a design copied onto it — are
    # mirrored left-right (content stays readable).
    pair_key: Mapped[str | None] = mapped_column(String(32), nullable=True)
    pair_mirror: Mapped[bool] = mapped_column(Boolean, default=True)

    shape: Mapped[Shape] = relationship(back_populates="areas")
    methods: Mapped[list[AreaMethod]] = relationship(
        back_populates="area", cascade="all, delete-orphan", order_by="AreaMethod.method", lazy="selectin"
    )


class AreaMethod(TimestampMixin, Base):
    """A decoration method allowed in an area, with the zone (inside the
    area, in area coordinates) it may be applied to and its limits."""

    __tablename__ = "area_methods"
    __table_args__ = (
        UniqueConstraint("area_id", "method"),
        CheckConstraint(f"method IN {METHODS}", name="method"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    area_id: Mapped[int] = mapped_column(ForeignKey("print_areas.id", ondelete="CASCADE"), index=True)
    method: Mapped[str] = mapped_column(String(16))
    zone_x_mm: Mapped[Decimal] = mapped_column(MM)
    zone_y_mm: Mapped[Decimal] = mapped_column(MM)
    zone_w_mm: Mapped[Decimal] = mapped_column(MM)
    zone_h_mm: Mapped[Decimal] = mapped_column(MM)
    max_width_mm: Mapped[Decimal | None] = mapped_column(MM, nullable=True)
    max_height_mm: Mapped[Decimal | None] = mapped_column(MM, nullable=True)
    # A laser reaches only so far round a curved body: all the method's
    # layers go into one strip this wide (as tall as the zone), which slides
    # anywhere across the zone. None: the whole zone.
    strip_width_mm: Mapped[Decimal | None] = mapped_column(MM, nullable=True)
    min_font_mm: Mapped[Decimal | None] = mapped_column(MM, nullable=True)
    colors_allowed: Mapped[bool] = mapped_column(Boolean, default=True)
    dpi: Mapped[int] = mapped_column(Integer, default=300)

    area: Mapped[PrintArea] = relationship(back_populates="methods")


class Variant(TimestampMixin, TranslatableMixin, Base):
    """What the customer picks ("Xameleon"): a shape, a base price, the
    decoration methods it supports and the 3D material."""

    __tablename__ = "variants"
    __table_args__ = (CheckConstraint(f"material IN {MATERIALS}", name="material"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"), index=True)
    shape_id: Mapped[int] = mapped_column(ForeignKey("shapes.id", ondelete="RESTRICT"), index=True)
    name: Mapped[str] = mapped_column(String(150))
    short_description: Mapped[str] = mapped_column(String(300), default="")
    description: Mapped[str] = mapped_column(Text, default="")
    specs: Mapped[list] = mapped_column(JSON, default=list)  # [{"label": "Hajmi", "value": "330 ml"}]
    # Clothing sizes, in the order the customer sees them:
    # [{"label": "M", "surcharge": "0.00", "is_available": true}]. Empty on
    # everything that has no size (a mug), and then none is ever chosen.
    sizes: Mapped[list] = mapped_column(JSON, default=list, server_default="[]")
    base_price: Mapped[Decimal] = mapped_column(MONEY)
    methods: Mapped[list] = mapped_column(JSON, default=list)  # subset of METHODS
    material: Mapped[str] = mapped_column(String(32), default="ceramic_glossy")
    # Transparent/dark bodies need a white ink layer under UV colours.
    white_underbase: Mapped[bool] = mapped_column(Boolean, default=False)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    product: Mapped[Product] = relationship(back_populates="variants", lazy="selectin")
    shape: Mapped[Shape] = relationship(lazy="selectin")
    images: Mapped[list[CatalogImage]] = relationship(
        foreign_keys="CatalogImage.variant_id", order_by="CatalogImage.sort_order", lazy="selectin",
        cascade="all, delete-orphan",
    )
    colors: Mapped[list[VariantColor]] = relationship(
        back_populates="variant", order_by="(VariantColor.sort_order, VariantColor.id)", lazy="selectin"
    )


class VariantColor(TimestampMixin, TranslatableMixin, Base):
    __tablename__ = "variant_colors"

    id: Mapped[int] = mapped_column(primary_key=True)
    variant_id: Mapped[int] = mapped_column(ForeignKey("variants.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(100))
    hex: Mapped[str] = mapped_column(String(7))
    surcharge: Mapped[Decimal] = mapped_column(MONEY, default=0)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    variant: Mapped[Variant] = relationship(back_populates="colors")
    images: Mapped[list[CatalogImage]] = relationship(
        foreign_keys="CatalogImage.color_id", order_by="CatalogImage.sort_order", lazy="selectin",
        cascade="all, delete-orphan",
    )


class CatalogImage(TimestampMixin, Base):
    """An ordered gallery image of exactly one product, variant or colour."""

    __tablename__ = "catalog_images"
    __table_args__ = (
        CheckConstraint(
            "(CASE WHEN product_id IS NULL THEN 0 ELSE 1 END)"
            " + (CASE WHEN variant_id IS NULL THEN 0 ELSE 1 END)"
            " + (CASE WHEN color_id IS NULL THEN 0 ELSE 1 END) = 1",
            name="one_owner",
        ),
        CheckConstraint(f"source IN {IMAGE_SOURCES}", name="source"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    product_id: Mapped[int | None] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"), nullable=True, index=True)
    variant_id: Mapped[int | None] = mapped_column(ForeignKey("variants.id", ondelete="CASCADE"), nullable=True, index=True)
    color_id: Mapped[int | None] = mapped_column(
        ForeignKey("variant_colors.id", ondelete="CASCADE"), nullable=True, index=True
    )
    media_id: Mapped[str] = mapped_column(ForeignKey("media.id", ondelete="RESTRICT"))
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    # "manual" (somebody uploaded it) or "render" (a renderer made it): a
    # bulk regenerate replaces its own output and leaves photographs alone.
    source: Mapped[str] = mapped_column(String(16), default="manual", server_default="manual")

    media: Mapped[Media] = relationship(lazy="selectin")


class PriceTier(TimestampMixin, Base):
    """Surcharge by painted area for one decoration method of a product. The
    tiers of a (product, method) always cover [0, ∞) without gaps or
    overlaps — they are replaced as a whole and validated on save."""

    __tablename__ = "price_tiers"
    __table_args__ = (
        UniqueConstraint("product_id", "method", "min_cm2"),
        CheckConstraint(f"method IN {METHODS}", name="method"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"), index=True)
    method: Mapped[str] = mapped_column(String(16))
    min_cm2: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    max_cm2: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)  # NULL = no upper bound
    surcharge: Mapped[Decimal] = mapped_column(MONEY)

    product: Mapped[Product] = relationship(back_populates="price_tiers")


template_variants = Table(
    "design_template_variants",
    Base.metadata,
    Column("template_id", ForeignKey("design_templates.id", ondelete="CASCADE"), primary_key=True),
    Column("variant_id", ForeignKey("variants.id", ondelete="CASCADE"), primary_key=True),
)


class DesignTemplate(TimestampMixin, TranslatableMixin, Base):
    """A ready design the admin made in the Studio, shown in the "Galereya":
    customers start from it and edit it. It is offered on the variants it was
    checked against, and its images are library media, so any design may use
    them. Its pictures (mockups) and `in_gallery` put it on the public
    gallery; `color_id` is the colour it is shown and opened in."""

    __tablename__ = "design_templates"

    id: Mapped[int] = mapped_column(primary_key=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(120))
    category: Mapped[str] = mapped_column(String(60), default="")  # a filter in the Studio ("Tug'ilgan kun")
    document: Mapped[dict] = mapped_column(JSON)
    preview_media_id: Mapped[str] = mapped_column(ForeignKey("media.id", ondelete="RESTRICT"))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    in_gallery: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false(), index=True)
    color_id: Mapped[int | None] = mapped_column(
        ForeignKey("variant_colors.id", ondelete="SET NULL"), nullable=True
    )

    preview: Mapped[Media] = relationship(lazy="selectin")
    product: Mapped[Product] = relationship(back_populates="templates", lazy="selectin")
    variants: Mapped[list[Variant]] = relationship(
        secondary=template_variants, order_by="(Variant.sort_order, Variant.id)", lazy="selectin"
    )
    images: Mapped[list[DesignTemplateImage]] = relationship(
        order_by="DesignTemplateImage.sort_order", cascade="all, delete-orphan", lazy="selectin"
    )


class DesignTemplateImage(Base):
    """One gallery picture of a template (a mockup), in order."""

    __tablename__ = "design_template_images"

    id: Mapped[int] = mapped_column(primary_key=True)
    template_id: Mapped[int] = mapped_column(ForeignKey("design_templates.id", ondelete="CASCADE"), index=True)
    media_id: Mapped[str] = mapped_column(ForeignKey("media.id", ondelete="RESTRICT"))
    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    media: Mapped[Media] = relationship(lazy="selectin")
