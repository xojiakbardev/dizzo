from __future__ import annotations

import math
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import AfterValidator, BaseModel, ConfigDict, Field, field_validator, model_validator

from app.core.i18n import _
from app.schemas.i18n import (
    AREA_FIELDS,
    CATEGORY_FIELDS,
    COLOR_FIELDS,
    PRODUCT_FIELDS,
    SHAPE_FIELDS,
    VARIANT_FIELDS,
    Translations,
    TypedTranslations,
)
from app.services.rich_text import clean_html

Method = Literal["uv", "engrave"]
ShapeKind = Literal["cylinder", "plane", "disc", "model"]
# Where a gallery picture came from (models.catalog.IMAGE_SOURCES).
ImageSource = Literal["manual", "render"]
Material = Literal[
    "ceramic_glossy", "ceramic_matte", "glass_clear", "glass_frosted", "fabric", "paper", "plastic", "metal", "wood"
]
Mm = Annotated[Decimal, Field(ge=0, le=5000, max_digits=8, decimal_places=2)]
PositiveMm = Annotated[Decimal, Field(gt=0, le=5000, max_digits=8, decimal_places=2)]
Money = Annotated[Decimal, Field(ge=0, max_digits=12, decimal_places=2)]
Slug = Annotated[str, Field(min_length=1, max_length=120, pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")]
AreaKey = Annotated[str, Field(min_length=1, max_length=32, pattern=r"^[a-z][a-z0-9_]*$")]
Hex = Annotated[str, Field(pattern=r"^#[0-9a-fA-F]{6}$")]
# A clothing size as the customer reads it: "S", "XXL", "42".
SizeLabel = Annotated[str, Field(min_length=1, max_length=20)]
# How much of the print area a size may use. 1 = the largest size, which is
# what a shape's print_areas are measured for (the owner's rule: 40 x 40 cm
# is the maximum, on the biggest garment); a smaller size prints
# proportionally smaller. Never 0 and never above 1.
PrintScale = Annotated[Decimal, Field(gt=0, le=1, max_digits=3, decimal_places=2)]
# Storefront shelf a product sits on: the slug of a ProductCategory.
Category = Annotated[str, Field(min_length=1, max_length=40, pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")]
# A description from the admin's rich-text editor, cleaned to the safe subset
# the storefront and the app render (services.rich_text).
RichText = Annotated[str, AfterValidator(clean_html)]


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


# ── Shape dimensions and area anchors (kind-specific) ─────────────────────


class CylinderDims(Strict):
    diameter_mm: PositiveMm
    height_mm: PositiveMm
    handle: bool = True
    # Arc around the handle that can't be printed; the printable length
    # around the body is π·d − handle_gap_mm.
    handle_gap_mm: Mm = Decimal("0")


class PlaneDims(Strict):
    width_mm: PositiveMm
    height_mm: PositiveMm
    sides: Literal[1, 2] = 1


class DiscDims(Strict):
    diameter_mm: PositiveMm


class ModelDims(Strict):
    """A GLB's size comes from the model itself (mm_per_unit), not from here."""


DIMS_BY_KIND: dict[str, type[Strict]] = {
    "cylinder": CylinderDims,
    "plane": PlaneDims,
    "disc": DiscDims,
    "model": ModelDims,
}


class CylinderAnchor(Strict):
    start_mm: Mm  # along the printable arc, from the edge of the handle gap
    top_mm: Mm


class PlaneAnchor(Strict):
    side: Literal["front", "back"] = "front"
    x_mm: Mm
    y_mm: Mm


class DiscAnchor(Strict):
    x_mm: Mm
    y_mm: Mm


Coord = Annotated[float, Field(ge=-1e7, le=1e7, allow_inf_nan=False)]
Vec3 = Annotated[list[Coord], Field(min_length=3, max_length=3)]


def _unit(v: list[float], what: str) -> list[float]:
    length = math.sqrt(sum(c * c for c in v))
    if length < 1e-9:
        raise ValueError(_("{what} nol uzunlikdagi vektor bo'lmasligi kerak", what=what))
    return [c / length for c in v]


class ModelAnchor(Strict):
    """Decal projector on a GLB, in the GLB scene's own coordinates (the
    display rotation/centering never changes it). It sits at `point`, looks
    along -`normal` onto the surface, `up` is the print's top direction.
    Only surfaces within depth_mm/2 of `point` and facing the projector by
    less than max_angle_deg receive the print. An area whose anchor is {}
    is not placed yet. With wrap_radius_mm the print wraps round a cylinder
    of that radius whose axis runs along `up`, wrap_radius_mm behind
    `point` (a mug's print going round to the handle). A round area (a
    clock's dial) prints only the ellipse inside its rectangle, so its
    coverage is measured on that ellipse."""

    point: Vec3
    normal: Vec3
    up: Vec3
    depth_mm: PositiveMm
    max_angle_deg: float = Field(default=70, ge=10, le=89)
    wrap_radius_mm: PositiveMm | None = None
    round: bool = False
    # Rounded corners of a rectangular face (drawn in the editor, and the
    # clock numerals follow them).
    corner_radius_mm: Mm | None = None
    # A clock face: new designs start with the numerals and minute marks on it.
    dial: bool = False

    @model_validator(mode="after")
    def orthonormal(self) -> ModelAnchor:
        normal = _unit(self.normal, "normal")
        dot = sum(u * n for u, n in zip(self.up, normal, strict=True))
        up = [u - dot * n for u, n in zip(self.up, normal, strict=True)]
        if math.sqrt(sum(c * c for c in up)) < 1e-3:
            raise ValueError("Yuqori yo'nalish (up) normalga parallel bo'lmasligi kerak")
        self.normal = [round(c, 6) for c in normal]
        self.up = [round(c, 6) for c in _unit(up, "up")]
        return self


ANCHOR_BY_KIND: dict[str, type[Strict]] = {
    "cylinder": CylinderAnchor,
    "plane": PlaneAnchor,
    "disc": DiscAnchor,
    "model": ModelAnchor,
}


class Camera(Strict):
    """A saved view of an area, in the same coordinates as its anchor. No
    camera means the view is derived from the anchor (see the frontend's
    areaCamera)."""

    position: Vec3
    target: Vec3

    @model_validator(mode="after")
    def distinct(self) -> Camera:
        if sum((p - t) ** 2 for p, t in zip(self.position, self.target, strict=True)) < 1e-12:
            raise ValueError("Kamera nuqtasi va qarash nuqtasi bir xil bo'lmasligi kerak")
        return self


# ── GLB model settings ────────────────────────────────────────────────────


class ModelTransformIn(Strict):
    """How the GLB is shown: which of its axes points up, and the turn
    around that axis that brings its front towards the default camera."""

    up_axis: Literal["y", "z"]
    yaw_deg: Literal[0, 90, 180, 270]


class ScaleIn(Strict):
    """Two points picked on the model and their real distance."""

    a: Vec3
    b: Vec3
    mm: PositiveMm


class AreaCheck(Strict):
    """Placement checks measured by the 3D configurator for one area."""

    coverage: float = Field(ge=0, le=1)  # share of the print that lands on the surface
    stretched_share: float = Field(ge=0, le=1)  # share stretched by more than 15%


class ReadyIn(Strict):
    checks: dict[int, AreaCheck] = Field(default_factory=dict)


# ── Admin input ───────────────────────────────────────────────────────────


class ProductTexts(Strict):
    name: str | None = Field(default=None, max_length=150)
    description: RichText | None = Field(default=None, max_length=50000)


ProductTranslations = TypedTranslations(ProductTexts, PRODUCT_FIELDS)
ShapeTranslations = Translations(SHAPE_FIELDS)
AreaTranslations = Translations(AREA_FIELDS)
ColorTranslations = Translations(COLOR_FIELDS)
CategoryTranslations = Translations(CATEGORY_FIELDS)


class ProductIn(Strict):
    slug: Slug
    name: str = Field(min_length=1, max_length=150)
    # Shown above the variants on the product page (PublicProductDetail.description);
    # each variant still has its own as well.
    description: RichText = Field(default="", max_length=50000)
    cover_media_id: str | None = None
    is_featured: bool = True
    is_available: bool = True
    sort_order: int = Field(default=0, ge=0, le=100000)
    category: Category = "boshqa"
    translations: ProductTranslations | None = None


class ProductPatch(Strict):
    slug: Slug | None = None
    name: str | None = Field(default=None, min_length=1, max_length=150)
    description: RichText | None = Field(default=None, max_length=50000)
    cover_media_id: str | None = None
    is_featured: bool | None = None
    is_available: bool | None = None
    sort_order: int | None = Field(default=None, ge=0, le=100000)
    category: Category | None = None
    archived: bool | None = None
    translations: ProductTranslations | None = None


class ShapeIn(Strict):
    name: str = Field(min_length=1, max_length=150)
    description: str = Field(default="", max_length=200)
    kind: ShapeKind
    dims: dict
    translations: ShapeTranslations | None = None

    @model_validator(mode="after")
    def check_dims(self) -> ShapeIn:
        self.dims = DIMS_BY_KIND[self.kind].model_validate(self.dims).model_dump(mode="json")
        return self


class ShapePatch(Strict):
    name: str | None = Field(default=None, min_length=1, max_length=150)
    description: str | None = Field(default=None, max_length=200)
    dims: dict | None = None  # validated against the shape's kind by the service
    archived: bool | None = None
    # "model" shapes only. A new GLB resets the scale and every placement.
    model_media_id: str | None = None
    model_transform: ModelTransformIn | None = None
    scale: ScaleIn | None = None
    translations: ShapeTranslations | None = None


class AreaIn(Strict):
    key: AreaKey
    name: str = Field(min_length=1, max_length=100)
    width_mm: PositiveMm
    height_mm: PositiveMm
    anchor: dict  # validated against the shape's kind by the service
    camera: Camera | None = None
    placement_note: str = Field(default="", max_length=1000)
    sort_order: int = Field(default=0, ge=0, le=1000)
    # Left out (null): the area keeps the translations it has.
    translations: AreaTranslations | None = None


class PairIn(Strict):
    """Makes two areas of a shape a symmetric pair (or unpairs with null).
    The partner takes this area's size and methods."""

    pair_key: AreaKey | None
    mirror: bool = True  # left ↔ right: zones and copied designs mirrored


class AreaMethodIn(Strict):
    method: Method
    zone_x_mm: Mm
    zone_y_mm: Mm
    zone_w_mm: PositiveMm
    zone_h_mm: PositiveMm
    max_width_mm: PositiveMm | None = None
    max_height_mm: PositiveMm | None = None
    strip_width_mm: PositiveMm | None = None  # the sliding strip (curved bodies); None: the whole zone
    min_font_mm: PositiveMm | None = None
    colors_allowed: bool
    dpi: int = Field(ge=150, le=1200)

    @model_validator(mode="after")
    def engrave_rules(self) -> AreaMethodIn:
        if self.method == "engrave":
            if self.colors_allowed:
                raise ValueError("O'yishda rang bo'lmaydi: colors_allowed false bo'lishi kerak")
            if self.min_font_mm is None:
                raise ValueError("O'yish uchun minimal shrift o'lchami (min_font_mm) kiritilishi shart")
        if self.max_width_mm is not None and self.max_width_mm > self.zone_w_mm:
            raise ValueError("max_width_mm zona enidan katta bo'lmasligi kerak")
        if self.max_height_mm is not None and self.max_height_mm > self.zone_h_mm:
            raise ValueError("max_height_mm zona bo'yidan katta bo'lmasligi kerak")
        if self.strip_width_mm is not None and self.strip_width_mm > self.zone_w_mm:
            raise ValueError("strip_width_mm zona enidan katta bo'lmasligi kerak")
        return self


def unique_methods(value: list[AreaMethodIn]) -> list[AreaMethodIn]:
    if len({m.method for m in value}) != len(value):
        raise ValueError("Har bir usul hududda bir marta bo'ladi")
    return value


class AreaMethodsIn(Strict):
    methods: list[AreaMethodIn] = Field(min_length=1, max_length=2)

    @field_validator("methods")
    @classmethod
    def unique_methods(cls, value: list[AreaMethodIn]) -> list[AreaMethodIn]:
        return unique_methods(value)


class LayoutAreaIn(AreaIn):
    """An area as the shape editor has it: with its pair and its methods.
    `id` null: a new area."""

    id: int | None = None
    pair_key: AreaKey | None = None
    pair_mirror: bool = True
    methods: list[AreaMethodIn] = Field(min_length=1, max_length=2)

    @field_validator("methods")
    @classmethod
    def unique_methods(cls, value: list[AreaMethodIn]) -> list[AreaMethodIn]:
        return unique_methods(value)


class ShapeLayoutIn(Strict):
    """Everything the shape editor saves, in one transaction: the name, the
    body (dims of a built shape; the GLB, its turn and scale of a model) and
    the whole list of areas — areas left out are deleted. A new GLB keeps
    the areas as sent (the editor has moved them onto it)."""

    name: str | None = Field(default=None, min_length=1, max_length=150)
    description: str | None = Field(default=None, max_length=200)
    dims: dict | None = None
    model_media_id: str | None = None
    model_transform: ModelTransformIn | None = None
    scale: ScaleIn | None = None
    translations: ShapeTranslations | None = None
    areas: list[LayoutAreaIn] = Field(max_length=50)


class SpecItem(Strict):
    label: str = Field(min_length=1, max_length=60)
    value: str = Field(min_length=1, max_length=120)


class SizeItem(Strict):
    label: SizeLabel
    surcharge: Money = Decimal("0")
    is_available: bool = True
    # This size's share of the print area (see PrintScale). The default 1
    # keeps a variant that was set up before sizes were scaled exactly as
    # it was: everything printed at the area's full millimetres.
    print_scale: PrintScale = Decimal("1")

    @model_validator(mode="after")
    def tidy(self) -> SizeItem:
        # Stored as JSON, so the money is written the way the catalog's
        # Numeric columns give it back: always two decimals.
        self.label = self.label.strip()
        if not self.label:
            raise ValueError("O'lcham nomi bo'sh bo'lmasin")
        self.surcharge = self.surcharge.quantize(Decimal("0.01"))
        self.print_scale = self.print_scale.quantize(Decimal("0.01"))
        return self


class SizesIn(Strict):
    """A variant's sizes, in the order the customer sees them. An empty list
    means the product has no sizes (a mug) and none is ever chosen."""

    sizes: list[SizeItem] = Field(default_factory=list, max_length=30)

    @field_validator("sizes")
    @classmethod
    def unique_labels(cls, value: list[SizeItem]) -> list[SizeItem]:
        labels = [s.label.strip() for s in value]
        if len({label.casefold() for label in labels}) != len(labels):
            raise ValueError("O'lcham nomlari takrorlanmasin")
        return value


class SizeName(Strict):
    """A size's label in another language, found by its Uzbek label."""

    label: SizeLabel
    name: SizeLabel


class VariantTexts(Strict):
    """A variant in another language. `specs` is the whole translated list
    (it replaces the Uzbek one). `sizes` names only the sizes whose label is
    a word ("Katta" -> "Большой"); codes like S/M/XL or 42 are left out and
    stay as they are. The Uzbek label stays the size's key: the cart and the
    quote accept either spelling and keep the Uzbek one."""

    name: str | None = Field(default=None, max_length=150)
    short_description: str | None = Field(default=None, max_length=300)
    description: RichText | None = Field(default=None, max_length=10000)
    specs: list[SpecItem] | None = Field(default=None, max_length=20)
    sizes: list[SizeName] | None = Field(default=None, max_length=30)


VariantTranslations = TypedTranslations(VariantTexts, VARIANT_FIELDS)


class VariantIn(Strict):
    shape_id: int
    name: str = Field(min_length=1, max_length=150)
    short_description: str = Field(default="", max_length=300)
    description: RichText = Field(default="", max_length=10000)
    specs: list[SpecItem] = Field(default_factory=list, max_length=20)
    base_price: Money
    methods: list[Method] = Field(min_length=1, max_length=2)
    material: Material
    white_underbase: bool = False
    is_available: bool = True
    sort_order: int = Field(default=0, ge=0, le=100000)
    translations: VariantTranslations | None = None

    @field_validator("methods")
    @classmethod
    def unique(cls, value: list[str]) -> list[str]:
        if len(set(value)) != len(value):
            raise ValueError("Usullar takrorlanmasin")
        return value


class VariantPatch(Strict):
    shape_id: int | None = None
    name: str | None = Field(default=None, min_length=1, max_length=150)
    short_description: str | None = Field(default=None, max_length=300)
    description: RichText | None = Field(default=None, max_length=10000)
    specs: list[SpecItem] | None = Field(default=None, max_length=20)
    base_price: Money | None = None
    methods: list[Method] | None = Field(default=None, min_length=1, max_length=2)
    material: Material | None = None
    white_underbase: bool | None = None
    is_available: bool | None = None
    sort_order: int | None = Field(default=None, ge=0, le=100000)
    archived: bool | None = None
    translations: VariantTranslations | None = None


class ColorIn(Strict):
    name: str = Field(min_length=1, max_length=100)
    hex: Hex
    surcharge: Money = Decimal("0")
    is_available: bool = True
    sort_order: int = Field(default=0, ge=0, le=100000)
    translations: ColorTranslations | None = None


class ColorPatch(Strict):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    hex: Hex | None = None
    surcharge: Money | None = None
    is_available: bool | None = None
    sort_order: int | None = Field(default=None, ge=0, le=100000)
    archived: bool | None = None
    translations: ColorTranslations | None = None


class ImagesIn(Strict):
    """A gallery, replaced whole and in this order. `source` stamps every row
    written, so a bulk regenerate can recognise its own output later; a
    colour's gallery is capped tighter than this (admin_catalog.MAX_COLOR_IMAGES)."""

    media_ids: list[str] = Field(max_length=20)
    source: ImageSource = "manual"


class TierIn(Strict):
    min_cm2: Annotated[Decimal, Field(ge=0, max_digits=10, decimal_places=2)]
    max_cm2: Annotated[Decimal, Field(gt=0, max_digits=10, decimal_places=2)] | None
    surcharge: Money


class TiersIn(Strict):
    tiers: list[TierIn] = Field(min_length=1, max_length=50)


# ── Output ────────────────────────────────────────────────────────────────


class Out(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class AreaMethodOut(Out):
    method: Method
    zone_x_mm: Decimal
    zone_y_mm: Decimal
    zone_w_mm: Decimal
    zone_h_mm: Decimal
    max_width_mm: Decimal | None
    max_height_mm: Decimal | None
    strip_width_mm: Decimal | None
    min_font_mm: Decimal | None
    colors_allowed: bool
    dpi: int


class AreaOut(Out):
    id: int
    key: str
    name: str
    width_mm: Decimal
    height_mm: Decimal
    anchor: dict
    camera: dict | None
    placement_note: str
    sort_order: int
    pair_key: str | None
    pair_mirror: bool
    methods: list[AreaMethodOut]


class AdminAreaOut(AreaOut):
    translations: dict = {}


class ShapeOut(Out):
    id: int
    name: str
    description: str = ""
    kind: ShapeKind
    dims: dict
    model_url: str | None
    model_media_id: str | None = None  # the GLB, so the editor can put a replaced model back
    model_transform: dict | None
    mm_per_unit: Decimal | None
    status: Literal["draft", "ready"]
    locked: bool
    archived: bool
    replaces_id: int | None  # a revision: takes that shape's place once ready
    areas: list[AdminAreaOut]
    translations: dict = {}


class ImageOut(Out):
    media_id: str
    url: str
    source: ImageSource = "manual"


class ColorOut(Out):
    id: int
    name: str
    hex: str
    surcharge: Decimal
    is_available: bool
    sort_order: int
    archived: bool
    # The colour-card picture, read back so the admin UI can show what it set.
    card_image: ImageOut | None = None
    card_media_id: str | None = None
    card_image_url: str | None = None
    images: list[ImageOut]
    translations: dict = {}


class SizeOut(Out):
    label: str
    surcharge: Decimal
    is_available: bool
    # Sizes stored before print scaling have none: they print full size.
    print_scale: Decimal = Decimal("1.00")


class VariantOut(Out):
    id: int
    shape_id: int
    name: str
    short_description: str
    description: str
    specs: list[dict]
    base_price: Decimal
    methods: list[Method]
    material: Material
    white_underbase: bool
    is_available: bool
    sort_order: int
    archived: bool
    main_image: ImageOut | None = None
    main_image_media_id: str | None = None
    main_image_url: str | None = None
    sizes: list[SizeOut]
    images: list[ImageOut]
    colors: list[ColorOut]
    translations: dict = {}


class TierOut(Out):
    method: Method
    min_cm2: Decimal
    max_cm2: Decimal | None
    surcharge: Decimal


class AdminProductOut(Out):
    id: int
    slug: str
    name: str
    description: str
    cover: ImageOut | None
    is_featured: bool
    is_available: bool
    sort_order: int
    category: Category
    archived: bool
    images: list[ImageOut]
    shapes: list[ShapeOut]
    variants: list[VariantOut]
    price_tiers: list[TierOut]
    sellable: bool  # at least one variant is on the storefront right now
    issues: list[str]  # why the product (or parts of it) can't be sold yet
    # Russian and English next to the Uzbek fields (app/schemas/i18n.py);
    # every nested shape, area, variant and colour carries its own.
    translations: dict = {}


class AdminProductListItem(Out):
    id: int
    slug: str
    name: str
    cover_url: str | None
    is_featured: bool
    is_available: bool
    archived: bool
    sort_order: int
    category: Category
    variant_count: int
    shape_count: int
    sellable: bool
    from_price: Decimal | None  # the cheapest sellable type and colour
    translations: dict = {}


class CategoryIn(Strict):
    slug: Category
    name: str = Field(min_length=1, max_length=80)
    icon_svg: str = Field(default="", max_length=20000)
    image_media_id: str | None = None
    sort_order: int = Field(default=0, ge=0, le=100000)
    is_active: bool = True
    translations: CategoryTranslations | None = None


class CategoryPatch(Strict):
    slug: Category | None = None
    name: str | None = Field(default=None, min_length=1, max_length=80)
    icon_svg: str | None = Field(default=None, max_length=20000)
    image_media_id: str | None = None
    sort_order: int | None = Field(default=None, ge=0, le=100000)
    is_active: bool | None = None
    translations: CategoryTranslations | None = None


class CategoryOut(Out):
    id: int
    slug: str
    name: str
    icon_svg: str
    image_media_id: str | None
    image_url: str | None
    sort_order: int
    is_active: bool
    product_count: int
    translations: dict = {}


class PublicCategory(Out):
    slug: str
    name: str
    icon_svg: str
    image_url: str | None


class PublicProductCard(Out):
    slug: str
    name: str
    cover_url: str | None
    from_price: Decimal
    is_featured: bool
    category: Category


class PublicColor(Out):
    id: int
    name: str
    hex: str
    surcharge: Decimal
    # The clean picture for the colour-picking card. null when the admin has
    # not set one — the caller then falls back to whatever it likes
    # (`images[0]`, the variant's `main_image_url`). It is never taken out of
    # `images`: the gallery stays whole.
    card_image_url: str | None = None
    images: list[str]


class PublicVariant(Out):
    id: int
    shape_id: int
    name: str
    short_description: str
    description: str
    specs: list[dict]
    base_price: Decimal
    # Methods the customer can actually use: variant ∩ the shape's areas.
    methods: list[Method]
    material: Material
    # Whether ink for this variant prints on a white underbase. When false,
    # pale ink goes straight onto the body colour and previews muted.
    white_underbase: bool
    main_image_url: str | None = None
    # Deprecated alias of main_image_url, kept for one release because the
    # Flutter app still reads the old name. Remove once it has shipped a
    # build that reads main_image_url.
    variant_main_image: str | None = None
    images: list[str]
    colors: list[PublicColor]
    # Sizes the customer picks from, in order; empty when the product has
    # none. An out-of-stock size is still listed, greyed out.
    sizes: list[SizeOut]


class PublicShape(Out):
    id: int
    kind: ShapeKind
    dims: dict
    model_url: str | None
    model_transform: dict | None
    mm_per_unit: Decimal | None
    areas: list[AreaOut]


class PublicProductDetail(Out):
    slug: str
    name: str
    # The product's own rich-text description in the request's language. Each
    # variant still has its own (PublicVariant.description); this is the one
    # the storefront and the app show above them.
    description: str = ""
    cover_url: str | None
    images: list[str]
    from_price: Decimal
    variants: list[PublicVariant]
    shapes: list[PublicShape]


# ── Quote ─────────────────────────────────────────────────────────────────

Cm2 = Annotated[Decimal, Field(ge=0, le=1_000_000, max_digits=12, decimal_places=2)]


class QuoteIn(Strict):
    variant_id: int
    color_id: int
    quantity: int = Field(ge=1, le=1000)
    # The chosen size, on products that have sizes.
    size: SizeLabel | None = None
    # Painted area per decoration method, measured by the editor.
    areas_cm2: dict[Method, Cm2] = Field(default_factory=dict)


class QuoteMethodLine(Out):
    method: Method
    area_cm2: Decimal
    tier_min_cm2: Decimal
    tier_max_cm2: Decimal | None
    surcharge: Decimal


class QuoteOut(Out):
    variant_id: int
    color_id: int
    base_price: Decimal
    color_surcharge: Decimal
    size: str | None
    size_surcharge: Decimal
    # The chosen size's print scale, and the biggest painted area it can
    # hold per method (cm²) — what the price was capped to.
    print_scale: Decimal = Decimal("1.00")
    print_area_cm2: dict[Method, Decimal] = Field(default_factory=dict)
    methods: list[QuoteMethodLine]
    unit_price: Decimal
    quantity: int
    total: Decimal
