"""The Studio's design document and the cart/order package built from it.

Coordinates are millimetres in the print area: origin at the area's
top-left corner, x to the right, y down. A layer is its centre, its
unrotated size and a clockwise rotation — the same numbers the Studio's
editor uses, so nothing depends on screen pixels. `area: null` marks a
layer that has no matching area on the current shape (after switching to a
variant with a different shape); it is kept but never printed.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Annotated, Literal, get_args

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.schemas.catalog import AreaKey, Cm2, Hex, Method, Money, QuoteOut, SizeLabel, Strict

# Served by the frontend (self-hosted, Latin + Cyrillic). Text layers may use
# only these, so the print file is rendered with exactly the font shown.
Font = Literal[
    "Montserrat", "Roboto", "Open Sans", "Rubik", "Oswald", "Lora", "Playfair Display", "PT Serif", "Comfortaa",
    "Caveat", "Lobster", "Pacifico",
]
FONTS: tuple[str, ...] = get_args(Font)

Coordinate = Annotated[float, Field(ge=-5000, le=5000, allow_inf_nan=False)]
Size = Annotated[float, Field(gt=0, le=5000, allow_inf_nan=False)]
MediaId = Annotated[str, Field(min_length=1, max_length=36)]


class ImageSource(Strict):
    media_id: MediaId
    # Rewritten by the backend from the media record on every save, so a
    # document can only reference the customer's own uploads.
    url: str = Field(default="", max_length=1000)
    px_w: int = Field(ge=1, le=30000)
    px_h: int = Field(ge=1, le=30000)


class TextSource(Strict):
    content: str = Field(min_length=1, max_length=500)
    font: Font
    size_mm: float = Field(gt=0, le=500, allow_inf_nan=False)
    color: Hex
    align: Literal["left", "center", "right"] = "center"
    bold: bool = False
    italic: bool = False


class GraphicSource(Strict):
    """A vector from the Studio's bundled library: a basic shape or an icon,
    filled with one colour, or a sticker (a many-coloured emoji or face part,
    drawn as it is; its `color` stays black, which is what a single-colour
    method prints it in). The Studio draws it from its own copy of the
    library; the backend only checks the print files."""

    library: Literal["shape", "icon", "sticker"]
    name: str = Field(max_length=60, pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
    color: Hex


class DialSource(Strict):
    """A clock face's numerals and minute marks, laid out by the Studio
    round the area (a circle on a round face, the rectangle's edge on a
    square one). The customer picks the font, size and colour; the layer
    covers the whole face and doesn't move."""

    font: Font
    size_mm: float = Field(gt=0, le=200, allow_inf_nan=False)
    color: Hex
    bold: bool = False
    italic: bool = False
    numerals: Literal["arabic", "roman", "none"] = "arabic"
    ticks: bool = True
    # The face they follow: a circle (an ellipse in a non-square box) or a
    # rectangle with rounded corners.
    face: Literal["round", "rect"] = "round"
    corner_radius_mm: float = Field(default=0, ge=0, le=500, allow_inf_nan=False)


class Layer(Strict):
    id: str = Field(pattern=r"^[A-Za-z0-9_-]{1,40}$")
    area: AreaKey | None
    method: Method
    kind: Literal["image", "text", "graphic", "dial"]
    x_mm: Coordinate
    y_mm: Coordinate
    w_mm: Size
    h_mm: Size
    rotation: float = Field(default=0, ge=-360, le=360, allow_inf_nan=False)
    image: ImageSource | None = None
    text: TextSource | None = None
    graphic: GraphicSource | None = None
    dial: DialSource | None = None
    # "user": the customer locked it; "system": the Studio did (clock
    # numerals, a coloured face) and the customer can't unlock it.
    locked: Literal["user", "system"] | None = None

    @model_validator(mode="after")
    def source_matches_kind(self) -> Layer:
        sources = {"image": self.image, "text": self.text, "graphic": self.graphic, "dial": self.dial}
        if sources[self.kind] is None or any(v is not None for k, v in sources.items() if k != self.kind):
            raise ValueError({
                "image": "Rasm qatlamida faqat rasm manbasi bo'ladi",
                "text": "Matn qatlamida faqat matn bo'ladi",
                "graphic": "Grafika qatlamida faqat shakl yoki ikonka bo'ladi",
                "dial": "Soat raqamlari qatlamida faqat raqamlar bo'ladi",
            }[self.kind])
        return self

    @property
    def color(self) -> str | None:
        """The single ink colour of a text or graphic layer (images have none)."""
        if self.text is not None:
            return self.text.color
        if self.graphic is not None:
            return self.graphic.color
        if self.dial is not None:
            return self.dial.color
        return None


class AreaLink(Strict):
    """The customer synced two areas of the same size (or an admin-made
    pair): the target shows the source's layers — mirrored for a mirrored
    pair — and has none of its own. One source may feed several targets."""

    source: AreaKey
    target: AreaKey


class StripPosition(Strict):
    """Where a method's strip (AreaMethod.strip_width_mm) sits in an area:
    its left edge, in area millimetres. It stays put while the design moves
    inside it and moves with the design once it reaches an edge, never
    leaving the zone. An area with no entry has the strip centred on its
    layers (documents saved before strips were stored)."""

    area: AreaKey
    method: Method
    x_mm: Coordinate


class DesignDocument(Strict):
    version: Literal[1] = 1
    layers: list[Layer] = Field(default_factory=list, max_length=40)
    links: list[AreaLink] = Field(default_factory=list, max_length=10)
    strips: list[StripPosition] = Field(default_factory=list, max_length=20)

    @field_validator("layers")
    @classmethod
    def unique_ids(cls, layers: list[Layer]) -> list[Layer]:
        if len({layer.id for layer in layers}) != len(layers):
            raise ValueError("Qatlam identifikatorlari takrorlanmasin")
        return layers

    @field_validator("links")
    @classmethod
    def one_source_per_target(cls, links: list[AreaLink]) -> list[AreaLink]:
        targets = [link.target for link in links]
        if len(set(targets)) != len(targets):
            raise ValueError("Har bir hudud faqat bitta hududdan sinxronlanadi")
        if any(link.source == link.target for link in links) or set(targets) & {link.source for link in links}:
            raise ValueError("Sinxronlangan hudud o'zi manba bo'lolmaydi")
        return links

    @field_validator("strips")
    @classmethod
    def one_strip_per_method(cls, strips: list[StripPosition]) -> list[StripPosition]:
        if len({(strip.area, strip.method) for strip in strips}) != len(strips):
            raise ValueError("Har bir hudud va usul uchun bitta tasma bo'ladi")
        return strips


# ── Designs (Studio autosave) ─────────────────────────────────────────────


class DesignIn(Strict):
    variant_id: int
    color_id: int
    # The size being designed for, on a product that has sizes. It is not
    # stored with the design (the size is picked again in the cart); it
    # decides the print area the draft is judged and priced against, so the
    # editor's issues and its price are the ones of the size on screen.
    size: SizeLabel | None = None
    document: DesignDocument
    # Painted area per method as measured by the editor: prices the draft.
    # The cart re-measures it from the print files.
    areas_cm2: dict[Method, Cm2] = Field(default_factory=dict)
    preview_media_id: MediaId | None = None
    # The Studio's five views (uploads, purpose "design"); None keeps the saved ones.
    previews: list[MediaId] | None = Field(default=None, max_length=6)


class DesignPut(DesignIn):
    version: int = Field(ge=1)  # the version this edit was based on


class Out(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class DesignOut(Out):
    id: str
    version: int
    product_slug: str
    product_name: str
    variant_id: int
    color_id: int
    document: DesignDocument
    areas_cm2: dict[str, Decimal]
    preview_url: str | None
    updated_at: datetime
    quote: QuoteOut | None  # None while the variant or colour is not on sale
    issues: list[str]


class DesignSummary(Out):
    id: str
    product_slug: str
    product_name: str
    variant_name: str
    color_name: str
    color_hex: str
    preview_url: str | None
    previews: list[str]  # the five views; an older design has its one preview or none
    updated_at: datetime


# ── Cart ──────────────────────────────────────────────────────────────────


class PrintFileIn(Strict):
    area: AreaKey
    method: Method
    media_id: MediaId


class CartItemIn(Strict):
    design_id: MediaId | None = None
    variant_id: int
    color_id: int
    # The size the customer picked; required on a variant that has sizes.
    size: SizeLabel | None = None
    quantity: int = Field(default=1, ge=1, le=1000)
    document: DesignDocument
    files: list[PrintFileIn] = Field(min_length=1, max_length=20)
    mockups: list[MediaId] = Field(min_length=1, max_length=6)
    # The unit price the customer was shown; if the print files price
    # differently the item is not added and the new price comes back (409).
    expected_unit_price: Money


class QuantityIn(Strict):
    quantity: int | None = Field(default=None, ge=1, le=1000)
    # Another size for an item already in the cart. The design is checked
    # again against it and the print files are re-cut, so an item can never
    # sit in the cart with a size its design does not fit.
    size: SizeLabel | None = None


class PackageFile(Out):
    area: str
    area_name: str
    method: Method
    url: str
    width_px: int
    height_px: int
    dpi: int
    painted_cm2: Decimal


class PackagePlacement(Out):
    area: str
    area_name: str
    width_mm: Decimal
    height_mm: Decimal
    placement_note: str
    anchor: dict


class CartItemOut(Out):
    uuid: str
    design_id: str | None
    product_slug: str
    product_name: str
    variant_id: int
    variant_name: str
    color_id: int
    color_name: str
    color_hex: str
    size: str  # empty on products without sizes
    quantity: int
    unit_price: Decimal
    total_price: Decimal
    quote: QuoteOut
    mockups: list[str]
    files: list[PackageFile]
    # The variant, colour and size are still on sale and the design still
    # fits the size's print area.
    available: bool
    # Why it is not: the first problem, so the cart can say what to change.
    issue: str | None = None
    created_at: datetime


class CartOut(Out):
    uuid: str
    items: list[CartItemOut]
    total_items: int
    subtotal: Decimal
    total_amount: Decimal
    is_empty: bool
    # Some item's variant or colour went off sale: checkout is blocked
    # until it is removed.
    blocked: bool
