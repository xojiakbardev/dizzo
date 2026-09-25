"""What a design may contain on a given variant.

The Studio enforces the same rules while editing; here they are checked
again on the document itself before anything goes into the cart, and the
print files are then checked against the zones pixel by pixel
(app.services.print_files).
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from decimal import Decimal

from app.core.i18n import _
from app.models.catalog import AreaMethod, PrintArea, Variant
from app.schemas.design import DesignDocument, Layer

# Rounding slack between the editor's floats and the stored millimetres.
TOLERANCE_MM = 0.5
MONO_COLOR = "#000000"
# A size's share of the print area when nothing says otherwise: the whole of
# it (schemas.catalog.PrintScale).
FULL_SCALE = Decimal("1")


@dataclass(frozen=True)
class Box:
    x0: float
    y0: float
    x1: float
    y1: float

    @property
    def width(self) -> float:
        return self.x1 - self.x0

    @property
    def height(self) -> float:
        return self.y1 - self.y0


def layer_box(layer: Layer) -> Box:
    """Axis-aligned bounds of the rotated layer, in area millimetres."""
    angle = math.radians(layer.rotation)
    half_w = abs(layer.w_mm / 2 * math.cos(angle)) + abs(layer.h_mm / 2 * math.sin(angle))
    half_h = abs(layer.w_mm / 2 * math.sin(angle)) + abs(layer.h_mm / 2 * math.cos(angle))
    return Box(layer.x_mm - half_w, layer.y_mm - half_h, layer.x_mm + half_w, layer.y_mm + half_h)


def crops(layer: Layer) -> bool:
    """Anything may stick out of the zone: the print file keeps only what is
    inside it. Clock numerals are laid out on the face and must fit."""
    return layer.dial is None


def zone_box(method: AreaMethod) -> Box:
    x, y = float(method.zone_x_mm), float(method.zone_y_mm)
    return Box(x, y, x + float(method.zone_w_mm), y + float(method.zone_h_mm))


def overlap(a: Box, b: Box) -> Box:
    """`a` cut down to `b`; empty (width or height ≤ 0) when they miss."""
    return Box(max(a.x0, b.x0), max(a.y0, b.y0), min(a.x1, b.x1), min(a.y1, b.y1))


def size_box(area: PrintArea, scale: Decimal | float = FULL_SCALE) -> Box | None:
    """What a chosen size may print of `area`: a box `scale` of its width and
    height, centred on the same anchor — so the print shrinks with the
    garment and stays where it was. None at scale 1 (the largest size, and
    everything without sizes): the whole area, exactly as before print
    scaling existed."""
    s = float(scale)
    if s >= 1:
        return None
    w, h = float(area.width_mm), float(area.height_mm)
    return Box(w * (1 - s) / 2, h * (1 - s) / 2, w * (1 + s) / 2, h * (1 + s) / 2)


def size_mm(area: PrintArea, scale: Decimal | float = FULL_SCALE) -> tuple[Decimal, Decimal]:
    """The print file's millimetres for a size: the size box's, rounded the
    way a stored millimetre is (two decimals)."""
    cents = Decimal("0.01")
    factor = Decimal(str(scale))
    return (area.width_mm * factor).quantize(cents), (area.height_mm * factor).quantize(cents)


def strip_width(method: AreaMethod) -> float | None:
    """The strip's width, when the method has one (never wider than the zone)."""
    if method.strip_width_mm is None:
        return None
    return min(float(method.strip_width_mm), zone_box(method).width)


def content_span(method: AreaMethod, layers: list[Layer]) -> tuple[float, float] | None:
    """Across the zone, what `layers` cover of it (what lies outside is
    cropped anyway); None when nothing is in the zone."""
    zone = zone_box(method)
    spans = [
        (max(b.x0, zone.x0), min(b.x1, zone.x1)) for b in map(layer_box, layers)
        if b.x1 > zone.x0 and b.x0 < zone.x1 and b.y1 > zone.y0 and b.y0 < zone.y1
    ]
    return (min(a for a, _ in spans), max(b for _, b in spans)) if spans else None


def follow_strip(x: float, span: tuple[float, float] | None, zone: Box, width: float) -> float:
    """The strip's left edge once the design covers `span`: it stays while
    the design is inside it and is pushed by the design's edge otherwise,
    always inside the zone. A design wider than the strip (only older ones,
    the Studio keeps new ones in it) doesn't move it. The Studio's
    followStrip."""
    if span is not None and span[1] - span[0] <= width + 1e-6:
        lo, hi = span
        if lo < x:
            x = lo
        elif hi > x + width:
            x = hi - width
    return min(max(x, zone.x0), zone.x1 - width)


def print_zone(
    method: AreaMethod, layers: list[Layer], strip_x: float | None = None, limit: Box | None = None
) -> Box:
    """Where the method's layers are printed: its zone, or — with a strip
    width (a laser reaches only so far round a curved body) — a strip that
    wide and as tall as the zone, at `strip_x` (the document's stored
    position) or, without one, centred on the layers; always inside the
    zone. `layers`: the area's layers on this method (the Studio's printZone).
    `limit` (the chosen size's box): the zone is cut down to it."""
    zone = zone_box(method)
    width = strip_width(method)
    if width is None:
        return zone if limit is None else overlap(zone, limit)
    if strip_x is None:
        span = content_span(method, layers)
        centre = (span[0] + span[1]) / 2 if span else (zone.x0 + zone.x1) / 2
        strip_x = centre - width / 2
    x0 = min(max(strip_x, zone.x0), zone.x1 - width)
    strip = Box(x0, zone.y0, x0 + width, zone.y1)
    return strip if limit is None else overlap(strip, limit)


def sized_zone(
    area: PrintArea, method: AreaMethod, layers: list[Layer], strip_x: float | None = None,
    scale: Decimal | float = FULL_SCALE,
) -> Box:
    """print_zone as the chosen size leaves it — what the print file holds."""
    return print_zone(method, layers, strip_x, size_box(area, scale))


def printable_cm2(variant: Variant, method: str, scale: Decimal | float = FULL_SCALE) -> Decimal:
    """The most ink a design can put on the variant with one method at this
    size: every area's zone, cut to the size box, added up. What the quote
    caps `areas_cm2` at — nobody pays for more than the size can print."""
    total = 0.0
    for area in variant.shape.areas:
        limit = size_box(area, scale)
        anchor = getattr(area, "anchor", None) or {}
        if not isinstance(anchor, dict):
            anchor = {}
        is_round = bool(anchor.get("round"))
        corner_radius = float(anchor["corner_radius_mm"]) if anchor.get("corner_radius_mm") else 0.0
        for m in area.methods:
            if m.method != method:
                continue
            box = zone_box(m) if limit is None else overlap(zone_box(m), limit)
            w = max(box.width, 0.0)
            h = max(box.height, 0.0)
            if is_round:
                area_val = (math.pi / 4.0) * w * h
            elif corner_radius > 0:
                r = min(corner_radius, w / 2.0, h / 2.0)
                area_val = w * h - (4.0 - math.pi) * (r ** 2)
            else:
                area_val = w * h
            total += area_val
    return (Decimal(str(total)) / 100).quantize(Decimal("0.01"))


def stored_strip(document: DesignDocument, area: str, method: str) -> float | None:
    return next((s.x_mm for s in document.strips if s.area == area and s.method == method), None)


def strip_problems(document: DesignDocument, variant: Variant) -> list[str]:
    """Stored strips that don't fit the variant: an area or a strip it lacks,
    or a position outside the zone."""
    areas = {area.key: area for area in variant.shape.areas}
    problems: list[str] = []
    for strip in document.strips:
        area = areas.get(strip.area)
        method = next((m for m in area.methods if m.method == strip.method), None) if area else None
        width = strip_width(method) if method else None
        if area is None:
            problems.append(_("Tasma: “{area}” hududi bu variantda yo'q", area=strip.area))
        elif width is None:
            problems.append(_(
                "Tasma: “{area}” hududida bu usulning tasmasi yo'q ({method})", area=area.name, method=strip.method
            ))
        else:
            zone = zone_box(method)
            if not zone.x0 - TOLERANCE_MM <= strip.x_mm <= zone.x1 - width + TOLERANCE_MM:
                problems.append(_("Tasma “{area}” hududidagi bosma zonasidan chiqib ketgan", area=area.name))
    return problems


def settle_strips(document: DesignDocument, variant: Variant) -> DesignDocument:
    """A stored document as the variant takes it: strips it has no place for
    are dropped, the rest kept inside their zones."""
    areas = {area.key: area for area in variant.shape.areas}
    kept = []
    for strip in document.strips:
        area = areas.get(strip.area)
        method = next((m for m in area.methods if m.method == strip.method), None) if area else None
        if method is None or strip_width(method) is None:
            continue
        x = print_zone(method, [], strip.x_mm).x0
        kept.append(strip if x == strip.x_mm else strip.model_copy(update={"x_mm": x}))
    return document if kept == document.strips else document.model_copy(update={"strips": kept})


def label(layer: Layer) -> str:
    if layer.text is not None:
        content = layer.text.content.replace("\n", " ")
        return _("“{text}” matni", text=f"{content[:24]}{'…' if len(content) > 24 else ''}")
    if layer.graphic is not None:
        return _({"shape": "shakl", "icon": "ikonka"}.get(layer.graphic.library, "stiker"))
    if layer.dial is not None:
        return _("soat raqamlari")
    return _("rasm")


def placed_layers(document: DesignDocument) -> list[Layer]:
    return [layer for layer in document.layers if layer.area is not None]


def is_pair(source: PrintArea, target: PrintArea) -> bool:
    return source.pair_key == target.key and target.pair_key == source.key


def linkable(source: PrintArea, target: PrintArea) -> bool:
    """An admin-made pair, or any two areas of the same size."""
    same_size = source.width_mm == target.width_mm and source.height_mm == target.height_mm
    return source.key != target.key and (is_pair(source, target) or same_size)


def copy_to_partner(layer: Layer, source: PrintArea, target: PrintArea) -> Layer:
    """The layer as it appears on a synced area: same place, or mirrored
    left-right for a mirrored pair (the content itself stays readable)."""
    if not (is_pair(source, target) and target.pair_mirror):
        return layer.model_copy(update={"area": target.key})
    return layer.model_copy(update={
        "area": target.key, "x_mm": float(target.width_mm) - layer.x_mm, "rotation": -layer.rotation,
    })


def valid_links(document: DesignDocument, variant: Variant) -> list[tuple[PrintArea, PrintArea]]:
    areas = {area.key: area for area in variant.shape.areas}
    out = []
    for link in document.links:
        source, target = areas.get(link.source), areas.get(link.target)
        if source is not None and target is not None and linkable(source, target):
            out.append((source, target))
    return out


def link_problems(document: DesignDocument, variant: Variant) -> list[str]:
    areas = {area.key: area for area in variant.shape.areas}
    problems: list[str] = []
    for link in document.links:
        source, target = areas.get(link.source), areas.get(link.target)
        if source is None or target is None or not linkable(source, target):
            problems.append(_(
                "“{source}” va “{target}” bu variantda sinxronlanmaydi: o'lchamlari farq qiladi",
                source=link.source, target=link.target,
            ))
        elif any(layer.area == target.key for layer in document.layers):
            problems.append(_(
                "“{target}” “{source}” bilan sinxron, unda alohida qatlam bo'lmaydi",
                target=target.name, source=source.name,
            ))
    return problems


def effective_layers(document: DesignDocument, variant: Variant) -> list[Layer]:
    """Placed layers plus the copies that synced areas add — what is printed."""
    layers = placed_layers(document)
    for source, target in valid_links(document, variant):
        layers += [copy_to_partner(layer, source, target) for layer in document.layers if layer.area == source.key]
    return layers


def document_problems(
    document: DesignDocument, variant: Variant, scale: Decimal | float = FULL_SCALE, size_label: str = ""
) -> list[str]:
    """Everything that keeps this document from being printed on the
    variant at the chosen size. Unplaced layers (area None) are allowed:
    they are not printed.

    `scale` is the size's print_scale: below 1 the printable box shrinks to
    the middle of each area (size_box) and a design that does not fit it is
    refused — never quietly cropped, because the customer is shown that box
    while designing and must be able to believe it."""
    areas: dict[str, PrintArea] = {area.key: area for area in variant.shape.areas}
    problems = link_problems(document, variant)
    placed = effective_layers(document, variant)
    if not placed:
        problems.append(_("Dizayn bo'sh: kamida bitta rasm, matn yoki shakl joylashtiring"))
    if len({layer.method for layer in placed}) > 1:
        # One way of printing per design: all colour print or all engraving.
        problems.append(_("Butun dizayn bitta usulda bosiladi: rangli bosma yoki lazer o'yma"))
    for layer in placed:
        area = areas.get(layer.area)
        if area is None:
            problems.append(_("{layer}: “{area}” hududi bu variantda yo'q", layer=label(layer), area=layer.area))
            continue
        method = next((m for m in area.methods if m.method == layer.method), None)
        if layer.method not in variant.methods or method is None:
            problems.append(_(
                "{layer}: “{area}” hududida bu usul yo'q ({method})",
                layer=label(layer), area=area.name, method=layer.method,
            ))
            continue
        same = [other for other in placed if other.area == layer.area and other.method == layer.method]
        strip_x = stored_strip(document, area.key, method.method)
        limit = size_box(area, scale)
        box, zone = layer_box(layer), print_zone(method, same, strip_x, limit)
        if limit is not None and not (
            limit.x0 - TOLERANCE_MM <= box.x0 and limit.y0 - TOLERANCE_MM <= box.y0
            and box.x1 <= limit.x1 + TOLERANCE_MM and box.y1 <= limit.y1 + TOLERANCE_MM
        ):
            width, height = size_mm(area, scale)
            problems.append(_(
                "{layer}: “{size}” o'lchamida bosma maydoni {width}×{height} mm — dizayn unga sig'maydi",
                layer=label(layer), size=size_label or _("tanlangan"), width=width, height=height,
            ))
        if crops(layer):
            # Cropped to the zone (or its strip): only what is inside is printed.
            box = Box(max(box.x0, zone.x0), max(box.y0, zone.y0), min(box.x1, zone.x1), min(box.y1, zone.y1))
        elif (
            box.x0 < zone.x0 - TOLERANCE_MM or box.y0 < zone.y0 - TOLERANCE_MM
            or box.x1 > zone.x1 + TOLERANCE_MM or box.y1 > zone.y1 + TOLERANCE_MM
        ):
            problems.append(_(
                "{layer} “{area}” hududidagi bosma zonasidan chiqib ketgan", layer=label(layer), area=area.name
            ))
        if method.max_width_mm is not None and box.width > float(method.max_width_mm) + TOLERANCE_MM:
            problems.append(_(
                "{layer} eni {mm} mm dan oshmasligi kerak", layer=label(layer), mm=method.max_width_mm
            ))
        if method.max_height_mm is not None and box.height > float(method.max_height_mm) + TOLERANCE_MM:
            problems.append(_(
                "{layer} bo'yi {mm} mm dan oshmasligi kerak", layer=label(layer), mm=method.max_height_mm
            ))
        if layer.color is not None and not method.colors_allowed and layer.color.lower() != MONO_COLOR:
            problems.append(_("{layer}: bu usulda rang bo'lmaydi", layer=label(layer)))
        size = layer.text.size_mm if layer.text is not None else layer.dial.size_mm if layer.dial is not None else None
        if size is not None:
            if method.min_font_mm is not None and size < float(method.min_font_mm) - 1e-6:
                problems.append(_(
                    "{layer}: shrift kamida {mm} mm bo'lishi kerak", layer=label(layer), mm=method.min_font_mm
                ))
        if layer.image is not None and layer.w_mm > 0 and layer.h_mm > 0:
            dpi = min(
                layer.image.px_w / (layer.w_mm / 25.4),
                layer.image.px_h / (layer.h_mm / 25.4),
            )
            if dpi < 100.0 - 1e-3:
                problems.append(_(
                    "{layer}: rasm sifati juda past ({dpi} DPI, kamida 100 DPI bo'lishi kerak)",
                    layer=label(layer), dpi=round(dpi),
                ))
    return problems + strip_problems(document, variant)


def required_files(document: DesignDocument, variant: Variant) -> set[tuple[str, str]]:
    """(area key, method) pairs that need a print file — linked partners included."""
    return {(layer.area, layer.method) for layer in effective_layers(document, variant)}
