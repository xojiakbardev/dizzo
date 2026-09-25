"""Catalog rules: geometry checks, what is sellable, price tiers and quotes.

"Sellable" is decided in one place (is_sellable_variant) and used by the
storefront listing, the product page and the quote — so a variant can never
be shown, priced or ordered while it is missing something it needs.
"""

from __future__ import annotations

import math
from datetime import UTC, datetime
from decimal import Decimal

from fastapi import HTTPException
from pydantic import ValidationError

from app.core.i18n import OTHER_LANGUAGES, _, get_language
from app.core.validation_messages import validation_message
from app.models.catalog import AreaMethod, PrintArea, Product, Shape, Variant, VariantColor
from app.services.design_rules import FULL_SCALE, printable_cm2
from app.schemas.catalog import (
    ANCHOR_BY_KIND,
    DIMS_BY_KIND,
    AreaCheck,
    AreaMethodIn,
    QuoteMethodLine,
    QuoteOut,
    ScaleIn,
)

HUNDRED = Decimal("100")


def unprocessable(detail: str) -> HTTPException:
    return HTTPException(status_code=422, detail=detail)


def validated(model: type, data: dict, what: str) -> dict:
    try:
        return model.model_validate(data).model_dump(mode="json")
    except ValidationError as exc:
        first = exc.errors()[0]
        field = ".".join(str(p) for p in first["loc"]) or what
        raise unprocessable(f"{_(what)}: {field} — {validation_message(first)}") from exc


def validate_dims(kind: str, dims: dict) -> dict:
    return validated(DIMS_BY_KIND[kind], dims, "O'lchamlar")


def validate_anchor(kind: str, anchor: dict) -> dict:
    if kind == "model" and anchor == {}:
        return {}  # added, not placed on the model yet
    return validated(ANCHOR_BY_KIND[kind], anchor, "Joylashuv")


# ── GLB models ────────────────────────────────────────────────────────────

# A print may wrap a little past a garment model's silhouette (a 40 cm
# print on a slim 3D tee) — but no more than this.
MIN_COVERAGE = 0.95
MM_PER_UNIT_RANGE = (Decimal("0.0001"), Decimal("100000"))


def default_model_transform() -> dict:
    return {"up_axis": "y", "yaw_deg": 0, "scale_ref": None}


def mm_per_unit(scale: ScaleIn) -> Decimal:
    distance = math.dist(scale.a, scale.b)
    if distance < 1e-9:
        raise unprocessable("Masshtab uchun ikki xil nuqta tanlang")
    value = (scale.mm / Decimal(repr(distance))).quantize(Decimal("0.000001"))
    low, high = MM_PER_UNIT_RANGE
    if not low <= value <= high:
        raise unprocessable(_(
            "Masshtab g'ayritabiiy chiqdi: 1 birlik = {value} mm. Nuqtalar va masofani tekshiring", value=value
        ))
    return value


# ── Geometry ──────────────────────────────────────────────────────────────


def printable_arc_mm(dims: dict) -> Decimal:
    circumference = Decimal(str(math.pi)) * Decimal(str(dims["diameter_mm"]))
    return (circumference - Decimal(str(dims["handle_gap_mm"]))).quantize(Decimal("0.01"))


def area_fit_error(shape: Shape, width: Decimal, height: Decimal, anchor: dict) -> str | None:
    """Why an area of this size at this anchor doesn't fit on the shape, or None."""
    # JSON stores mm values as strings (Decimal serialisation); compare exactly.
    d = {k: Decimal(str(v)) for k, v in shape.dims.items() if k.endswith("_mm")}
    a = {k: Decimal(str(v)) if k.endswith("_mm") and v is not None else v for k, v in anchor.items()}
    if shape.kind == "cylinder":
        arc = printable_arc_mm(shape.dims)
        if a["start_mm"] + width > arc:
            return _(
                "Hudud aylana bo'ylab sig'maydi: {start} + {width} > {arc} mm (bosiladigan yoy)",
                start=a["start_mm"], width=width, arc=arc,
            )
        if a["top_mm"] + height > d["height_mm"]:
            return _(
                "Hudud balandlikka sig'maydi: {top} + {height} > {limit} mm",
                top=a["top_mm"], height=height, limit=d["height_mm"],
            )
    elif shape.kind == "plane":
        if a["side"] == "back" and shape.dims["sides"] == 1:
            return _("Shakl bir tomonli, orqa tomonda hudud bo'lmaydi")
        if a["x_mm"] + width > d["width_mm"] or a["y_mm"] + height > d["height_mm"]:
            return _(
                "Hudud tekislikdan chiqib ketadi ({width} × {height} mm)", width=d["width_mm"], height=d["height_mm"]
            )
    elif shape.kind == "disc":
        if a["x_mm"] + width > d["diameter_mm"] or a["y_mm"] + height > d["diameter_mm"]:
            return _("Hudud diskdan chiqib ketadi (Ø{diameter} mm)", diameter=d["diameter_mm"])
    return None  # "model": placement is checked in the 3D configurator


def zone_fit_error(area: PrintArea, method: AreaMethodIn) -> str | None:
    if method.zone_x_mm + method.zone_w_mm > area.width_mm or method.zone_y_mm + method.zone_h_mm > area.height_mm:
        return _(
            "{method} zonasi hududdan chiqib ketadi ({width} × {height} mm)",
            method=method.method, width=area.width_mm, height=area.height_mm,
        )
    return None


# ── Area pairs ────────────────────────────────────────────────────────────

METHOD_FIELDS = (
    "method", "zone_x_mm", "zone_y_mm", "zone_w_mm", "zone_h_mm", "max_width_mm", "max_height_mm", "strip_width_mm",
    "min_font_mm", "colors_allowed", "dpi",
)


def partner_of(shape: Shape, area: PrintArea) -> PrintArea | None:
    return next((a for a in shape.areas if area.pair_key and a.key == area.pair_key and a.id != area.id), None)


def partner_method_fields(area: PrintArea, method: AreaMethod | AreaMethodIn) -> dict:
    """A method of `area` as its partner has it: identical, or with the
    zone mirrored left-right."""
    fields = {f: getattr(method, f) for f in METHOD_FIELDS}
    if area.pair_mirror:
        fields["zone_x_mm"] = area.width_mm - method.zone_x_mm - method.zone_w_mm
    return fields


def pair_errors(shape: Shape) -> list[str]:
    errors: list[str] = []
    for area in shape.areas:
        if not area.pair_key:
            continue
        partner = partner_of(shape, area)
        if partner is None or partner.pair_key != area.key:
            errors.append(_("“{name}” juft hududi topilmadi yoki unga bog'lanmagan", name=area.name))
            continue
        same_size = (area.width_mm, area.height_mm) == (partner.width_mm, partner.height_mm)
        expected = sorted((tuple(partner_method_fields(area, m).values()) for m in area.methods), key=str)
        actual = sorted((tuple(getattr(m, f) for f in METHOD_FIELDS) for m in partner.methods), key=str)
        if not same_size or expected != actual or area.pair_mirror != partner.pair_mirror:
            errors.append(_(
                "“{name}” va “{partner}” juft, lekin o'lchami yoki usullari farq qiladi",
                name=area.name, partner=partner.name,
            ))
    return errors


def shape_methods(shape: Shape) -> set[str]:
    return {m.method for area in shape.areas for m in area.methods}


def shape_ready_errors(shape: Shape, checks: dict[int, AreaCheck]) -> list[str]:
    """Why the shape can't be marked ready. For GLB shapes `checks` are the
    placement measurements the 3D configurator made on the saved state."""
    errors: list[str] = []
    if not shape.areas:
        errors.append(_("Kamida bitta bosma hududi kerak"))
    for area in shape.areas:
        if not area.methods:
            errors.append(_("“{name}” hududida usul yo'q", name=area.name))
        fit = area_fit_error(shape, area.width_mm, area.height_mm, area.anchor)
        if fit:
            errors.append(f"“{area.name}”: {fit}")
    errors.extend(pair_errors(shape))
    if shape.kind != "model":
        if checks:
            errors.append(_("Joylashuv tekshiruvlari faqat 3D model shakllari uchun"))
        return errors

    if shape.model_media_id is None:
        errors.append(_("3D model (GLB) yuklanmagan"))
    if shape.mm_per_unit is None:
        errors.append(_("Model masshtabi (mm) sozlanmagan"))
    unknown = set(checks) - {a.id for a in shape.areas}
    if unknown:
        errors.append(_("Tekshiruvda bu shaklga tegishli bo'lmagan hudud bor: {ids}", ids=sorted(unknown)))
    for area in shape.areas:
        if not area.anchor:
            errors.append(_("“{name}” modelda joylashtirilmagan", name=area.name))
            continue
        check = checks.get(area.id)
        if check is None:
            errors.append(_("“{name}” joylashuvi tekshirilmagan", name=area.name))
        elif check.coverage < MIN_COVERAGE:
            errors.append(_(
                "“{name}”: rasmning {coverage} qismi sirtga tushadi, "
                "kamida {minimum} kerak (hudud model chetidan chiqib ketgan)",
                name=area.name, coverage=f"{check.coverage:.1%}", minimum=f"{MIN_COVERAGE:.0%}",
            ))
    return errors


def lock_shape(shape: Shape) -> None:
    """Once a customer designs on a shape it can't change any more; the
    admin edits a duplicate instead, so saved designs and carts keep fitting."""
    if shape.locked_at is None:
        shape.locked_at = datetime.now(UTC)


# ── Sellability ───────────────────────────────────────────────────────────


def is_sellable_color(color: VariantColor) -> bool:
    return color.archived_at is None and color.is_available


def sellable_sizes(variant: Variant) -> list[dict]:
    """The variant's sizes that are in stock, in the admin's order. Empty
    means the product has no sizes at all (a mug) — or all of them ran out,
    which variant_issues reports."""
    return [size for size in variant.sizes if size.get("is_available", True)]


def resolve_size(variant: Variant, label: str | None, *, required: bool = False) -> dict | None:
    """The size the customer chose, checked against what is on sale. None
    when the product has no sizes; `required` (the cart) refuses an empty
    choice where there are sizes to pick from."""
    sizes = sellable_sizes(variant)
    if not sizes:
        if label:
            raise unprocessable(_("“{variant}” variantida o'lcham tanlanmaydi", variant=variant.name))
        return None
    if not label:
        if required:
            raise unprocessable(_("“{variant}” uchun o'lchamni tanlang", variant=variant.name))
        return None
    # A translated label ("Большой") picks the size it names ("Katta").
    uzbek = {name: uz for language in OTHER_LANGUAGES for uz, name in size_names(variant, language).items()}
    chosen = next((size for size in sizes if size["label"] == label), None) or next(
        (size for size in sizes if size["label"] == uzbek.get(label)), None
    )
    if chosen is None:
        raise unprocessable(_("“{size}” o'lchami bu variantda yo'q", size=label))
    return chosen


def size_names(variant: Variant, language: str | None = None) -> dict[str, str]:
    """{Uzbek label: label in `language`} for the sizes the variant's
    translations name (app/schemas/catalog.py VariantTexts)."""
    texts = (variant.translations or {}).get(language or get_language()) or {}
    return {item["label"]: item["name"] for item in texts.get("sizes") or []}


def local_size(variant: Variant, label: str | None) -> str | None:
    """A size label as the request's language spells it."""
    return size_names(variant).get(label, label) if label else label


def size_surcharge(size: dict | None) -> Decimal:
    return Decimal(str(size["surcharge"])) if size else Decimal("0")


def size_scale(size: dict | None) -> Decimal:
    """How much of the print area this size may use (schemas.catalog
    PrintScale). Sizes stored before print scaling, and everything with no
    size at all, print at the area's full millimetres."""
    if not size:
        return FULL_SCALE
    try:
        scale = Decimal(str(size.get("print_scale", "1")))
    except (ArithmeticError, TypeError, ValueError):
        return FULL_SCALE
    return scale if Decimal("0") < scale <= FULL_SCALE else FULL_SCALE


# Sizes as a garment is normally set up: 40 x 40 cm on the largest, and
# proportionally less further down. The admin may set any scale; these are
# what the size editor offers and what migration 0029 filled in.
DEFAULT_PRINT_SCALES: dict[str, Decimal] = {
    "3XL": Decimal("1.00"), "XXXL": Decimal("1.00"), "XXL": Decimal("0.95"), "2XL": Decimal("0.95"),
    "XL": Decimal("0.90"), "L": Decimal("0.85"), "M": Decimal("0.80"), "S": Decimal("0.75"),
}


def default_print_scale(label: str) -> Decimal:
    return DEFAULT_PRINT_SCALES.get(label.strip().upper(), FULL_SCALE)


def tiers_for(product: Product, method: str) -> list:
    return [t for t in product.price_tiers if t.method == method]


def variant_issues(variant: Variant) -> list[str]:
    """Everything that keeps an otherwise enabled variant off the storefront."""
    issues: list[str] = []
    shape = variant.shape
    if shape.archived_at is not None:
        issues.append(_("shakli arxivlangan"))
    elif shape.status != "ready":
        issues.append(_("shakli (“{shape}”) hali tayyor emas", shape=shape.name))
    missing = [m for m in variant.methods if m not in shape_methods(shape)]
    if missing:
        issues.append(_("shaklda bu usul(lar) uchun hudud yo'q: {methods}", methods=", ".join(missing)))
    if not any(is_sellable_color(c) for c in variant.colors):
        issues.append(_("mavjud rang yo'q"))
    if variant.sizes and not sellable_sizes(variant):
        issues.append(_("mavjud o'lcham yo'q"))
    no_tiers = [m for m in variant.methods if not tiers_for(variant.product, m)]
    if no_tiers:
        issues.append(_("narx pog'onalari yo'q: {methods}", methods=", ".join(no_tiers)))
    return issues


def is_sellable_variant(variant: Variant) -> bool:
    return variant.archived_at is None and variant.is_available and not variant_issues(variant)


def sellable_variants(product: Product) -> list[Variant]:
    if product.archived_at is not None or not product.is_available:
        return []
    return [v for v in product.variants if is_sellable_variant(v)]


def cheapest_print_surcharge(variant: Variant, tiers: list) -> Decimal:
    """What the smallest possible print adds to this type. Every order carries
    one — a design with nothing painted on it cannot be bought — so leaving it
    out of the "from" price advertises a number nobody is ever charged."""
    by_method: dict[str, list] = {}
    for tier in tiers:
        by_method.setdefault(tier.method, []).append(tier)
    costs = [
        pick_tier(by_method[method], Decimal("0")).surcharge
        for method in variant.methods
        if by_method.get(method)
    ]
    return min(costs, default=Decimal("0"))


def from_price(variants: list[Variant], tiers: list | None = None) -> Decimal:
    """The cheapest a customer can actually leave with: the cheapest type, its
    cheapest colour and size, plus the cheapest print it must carry."""
    return min(
        v.base_price
        + min(c.surcharge for c in v.colors if is_sellable_color(c))
        + min((size_surcharge(s) for s in sellable_sizes(v)), default=Decimal("0"))
        + cheapest_print_surcharge(v, tiers or [])
        for v in variants
    )


def product_issues(product: Product) -> list[str]:
    issues: list[str] = []
    if product.archived_at is not None:
        issues.append(_("Mahsulot arxivlangan"))
    if not product.is_available:
        issues.append(_("Mahsulot “mavjud emas” deb belgilangan"))
    if product.cover is None:
        issues.append(_("Muqova rasmi yo'q (landingda rasmsiz ko'rinadi)"))
    active = [v for v in product.variants if v.archived_at is None and v.is_available]
    if not active:
        issues.append(_("Faol variant yo'q"))
    for variant in active:
        issues.extend(f"“{variant.name}”: {problem}" for problem in variant_issues(variant))
    return issues


# ── Price tiers ───────────────────────────────────────────────────────────


def validate_tiers(tiers: list) -> list:
    """Tiers must cover [0, ∞) exactly: start at 0, each one starts where the
    previous ended, only the last is open-ended."""
    ordered = sorted(tiers, key=lambda t: t.min_cm2)
    if ordered[0].min_cm2 != 0:
        raise unprocessable("Birinchi pog'ona 0 cm² dan boshlanishi kerak")
    for i, tier in enumerate(ordered):
        last = i == len(ordered) - 1
        if tier.max_cm2 is None and not last:
            raise unprocessable("Faqat oxirgi pog'ona cheksiz bo'lishi mumkin")
        if last and tier.max_cm2 is not None:
            raise unprocessable("Oxirgi pog'ona cheksiz bo'lishi kerak (max_cm2 = null)")
        if tier.max_cm2 is not None and tier.max_cm2 <= tier.min_cm2:
            raise unprocessable(_(
                "{low}–{high} cm²: yuqori chegara pastkidan katta bo'lishi kerak", low=tier.min_cm2, high=tier.max_cm2
            ))
        if not last and ordered[i + 1].min_cm2 != tier.max_cm2:
            raise unprocessable(_(
                "Pog'onalar orasida bo'shliq yoki kesishish bor: {end} dan keyingi pog'ona {start} dan boshlanyapti",
                end=tier.max_cm2, start=ordered[i + 1].min_cm2,
            ))
    return ordered


def pick_tier(tiers: list, area_cm2: Decimal):
    for tier in tiers:
        if tier.min_cm2 <= area_cm2 and (tier.max_cm2 is None or area_cm2 < tier.max_cm2):
            return tier
    raise AssertionError("validated tiers always cover [0, ∞)")


# ── Quote ─────────────────────────────────────────────────────────────────


def quote(
    variant: Variant, color: VariantColor, quantity: int, areas_cm2: dict[str, Decimal], size: str | None = None
) -> QuoteOut:
    if not is_sellable_variant(variant) or variant.product.archived_at is not None or not variant.product.is_available:
        raise unprocessable("Bu variant hozir sotuvda emas")
    if color.variant_id != variant.id or not is_sellable_color(color):
        raise unprocessable("Bu rang tanlangan variant uchun mavjud emas")
    chosen = resolve_size(variant, size)
    scale = size_scale(chosen)
    # What this size can print per method. A smaller size prints a smaller
    # picture, so it is never charged for more ink than fits on it — the
    # editor measures inside the same box, so both sides agree.
    caps = {
        method: printable_cm2(variant, method, scale)
        for method in variant.methods
    } if scale < FULL_SCALE else {}
    lines: list[QuoteMethodLine] = []
    for method, given in sorted(areas_cm2.items()):
        area = min(given, caps[method]) if method in caps else given
        if area == 0:
            continue
        if method not in variant.methods:
            raise unprocessable(_("“{variant}” variantida bu usul yo'q: {method}", variant=variant.name, method=method))
        tier = pick_tier(tiers_for(variant.product, method), area)
        lines.append(
            QuoteMethodLine(
                method=method, area_cm2=area, tier_min_cm2=tier.min_cm2, tier_max_cm2=tier.max_cm2,
                surcharge=tier.surcharge,
            )
        )
    extra = size_surcharge(chosen)
    unit = variant.base_price + color.surcharge + extra + sum((line.surcharge for line in lines), Decimal("0"))
    return QuoteOut(
        variant_id=variant.id, color_id=color.id, base_price=variant.base_price, color_surcharge=color.surcharge,
        size=chosen["label"] if chosen else None, size_surcharge=extra,
        print_scale=scale, print_area_cm2=caps,
        methods=lines, unit_price=unit, quantity=quantity, total=unit * quantity,
    )
