"""Checks a print file against its area and measures the painted area.

A print file is a PNG exactly the size of the print area at the method's
DPI — or, on a garment sold by size, of that size's share of it
(design_rules.size_box), so what the factory prints is the size ordered.
Everything painted (alpha > 0) must lie inside the method's zone (and
be no wider than its strip, when it has one, and inside the strip where the
design stored it), a mono method's file may only
contain black ink, and the painted pixels are what the price is computed
from — the editor's own measurement is only an estimate.
"""

from __future__ import annotations

import io
import math
from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal

from PIL import Image, ImageDraw, ImageStat

from app.core.i18n import _
from app.models.catalog import AreaMethod, PrintArea
from app.services.design_rules import FULL_SCALE, Box, overlap, print_zone, size_box, size_mm, zone_box

MM_PER_INCH = Decimal("25.4")
# Largest channel value still counted as black ink in mono files
# (anti-aliased edges are black with partial alpha, not grey).
MONO_MAX_CHANNEL = 40
# Decoding is ~4 bytes a pixel, and the checks below hold about three
# copies: 40 MP peaks near 500 MB. That is 2.3× an A3 area (297×420 mm) at
# 300 DPI (17.4 MP) and 4× the mug's engraving file (5339×1866 at 600 DPI);
# browsers can't draw much bigger canvases anyway (iOS: 16.7 MP). Pillow
# refuses anything over twice this outright; analyse() checks the header's
# size against the area before decoding a single pixel.
MAX_PIXELS = 40_000_000
Image.MAX_IMAGE_PIXELS = MAX_PIXELS


class PrintFileError(ValueError):
    pass


@dataclass(frozen=True)
class PrintFile:
    width_px: int
    height_px: int
    dpi: int
    painted_cm2: Decimal


def expected_pixels(length_mm: Decimal, dpi: int) -> int:
    """Pixels for a length at a DPI, rounded half up — the Studio computes
    Math.floor(mm * dpi / 25.4 + 0.5) the same way."""
    return int((length_mm * dpi / MM_PER_INCH).quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def analyse(
    data: bytes, area: PrintArea, method: AreaMethod, strip_x: float | None = None,
    scale: Decimal | float = FULL_SCALE,
) -> PrintFile:
    """`strip_x`: the strip's left edge stored in the design, if any.
    `scale`: the chosen size's print scale — the file is then the size box
    (design_rules.size_box), not the whole area, so a smaller size really
    goes to production as a smaller print."""
    try:
        image = Image.open(io.BytesIO(data))  # reads the header only
    except (OSError, Image.DecompressionBombError) as exc:
        raise PrintFileError(_("Bosma faylni o'qib bo'lmadi")) from exc
    if image.format != "PNG":
        raise PrintFileError(_("Bosma fayl PNG bo'lishi kerak"))

    file_w_mm, file_h_mm = size_mm(area, scale)
    want_w = expected_pixels(file_w_mm, method.dpi)
    want_h = expected_pixels(file_h_mm, method.dpi)
    # ±1 px: float rounding in the browser at exact .5 boundaries.
    if abs(image.width - want_w) > 1 or abs(image.height - want_h) > 1:
        raise PrintFileError(_(
            "Bosma fayl o'lchami {width}×{height} px, {want_width}×{want_height} px bo'lishi kerak "
            "({width_mm}×{height_mm} mm, {dpi} DPI)",
            width=image.width, height=image.height, want_width=want_w, want_height=want_h,
            width_mm=file_w_mm, height_mm=file_h_mm, dpi=method.dpi,
        ))
    if image.width * image.height > MAX_PIXELS:
        raise PrintFileError(_(
            "Bosma fayl juda katta: {width}×{height} px "
            "({megapixels} MP dan oshmasligi kerak). DPI yoki hudud o'lchamini kamaytiring.",
            width=image.width, height=image.height, megapixels=MAX_PIXELS // 1_000_000,
        ))
    try:
        image.load()
    except (OSError, Image.DecompressionBombError) as exc:
        raise PrintFileError(_("Bosma faylni o'qib bo'lmadi")) from exc

    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    painted_px = image.width * image.height - alpha.histogram()[0]
    bbox = alpha.getbbox()
    if bbox is not None:
        px_per_mm_x = image.width / float(file_w_mm)
        px_per_mm_y = image.height / float(file_h_mm)
        # The file starts at the size box's corner, so everything measured in
        # area millimetres is shifted by it.
        limit = size_box(area, scale)
        off_x, off_y = (limit.x0, limit.y0) if limit is not None else (0.0, 0.0)
        # The whole zone (never its strip: a strip may sit anywhere in it),
        # cut down to what this size prints.
        cut = zone_box(method) if limit is None else overlap(zone_box(method), limit)
        zone = (
            math.floor((cut.x0 - off_x) * px_per_mm_x) - 1,
            math.floor((cut.y0 - off_y) * px_per_mm_y) - 1,
            math.ceil((cut.x1 - off_x) * px_per_mm_x) + 1,
            math.ceil((cut.y1 - off_y) * px_per_mm_y) + 1,
        )
        if bbox[0] < zone[0] or bbox[1] < zone[1] or bbox[2] > zone[2] or bbox[3] > zone[3]:
            raise PrintFileError(_("Bosma faylda zonadan tashqarida bo'yalgan joy bor"))
        anchor = getattr(area, "anchor", None) or {}
        if not isinstance(anchor, dict):
            anchor = {}
        is_round = bool(anchor.get("round"))
        corner_radius = float(anchor["corner_radius_mm"]) if anchor.get("corner_radius_mm") else 0.0
        if is_round or corner_radius > 0:
            shape_mask = Image.new("L", (image.width, image.height), 0)
            draw = ImageDraw.Draw(shape_mask)
            zx0 = max(0, zone[0])
            zy0 = max(0, zone[1])
            zx1 = min(image.width - 1, zone[2])
            zy1 = min(image.height - 1, zone[3])
            if is_round:
                draw.ellipse([zx0, zy0, zx1, zy1], fill=255)
            elif corner_radius > 0:
                r_px = corner_radius * ((px_per_mm_x + px_per_mm_y) / 2.0)
                draw.rounded_rectangle([zx0, zy0, zx1, zy1], radius=r_px, fill=255)
            outside = alpha.copy()
            outside.paste(0, mask=shape_mask)
            if outside.getbbox() is not None:
                raise PrintFileError(_("Bosma faylda zonadan tashqarida bo'yalgan joy bor"))
        # A strip (design_rules.print_zone) may sit anywhere in the zone:
        # what is painted only has to be no wider than it.
        strip = method.strip_width_mm
        if strip is not None and bbox[2] - bbox[0] > math.ceil(float(strip) * px_per_mm_x) + 2:
            raise PrintFileError(_("Bosma fayldagi dizayn {mm} mm lik tasmadan keng", mm=strip))
        if strip is not None and strip_x is not None:
            box = print_zone(method, [], strip_x, limit)
            if (
                bbox[0] < math.floor((box.x0 - off_x) * px_per_mm_x) - 1
                or bbox[2] > math.ceil((box.x1 - off_x) * px_per_mm_x) + 1
            ):
                raise PrintFileError(_("Bosma fayldagi dizayn {mm} mm lik tasmadan chiqib ketgan", mm=strip))
        if not method.colors_allowed:
            mask = alpha.point(lambda value: 255 if value else 0)
            extrema = ImageStat.Stat(rgba.convert("RGB"), mask).extrema
            if any(high > MONO_MAX_CHANNEL for _, high in extrema):
                raise PrintFileError(_("Bu usulning bosma fayli faqat bir rangli (qora) bo'lishi kerak"))

    mm2_per_px = (file_w_mm / image.width) * (file_h_mm / image.height)
    painted_cm2 = (painted_px * mm2_per_px / 100).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    return PrintFile(width_px=image.width, height_px=image.height, dpi=method.dpi, painted_cm2=painted_cm2)


def recut(data: bytes, area: PrintArea, method: AreaMethod, was: Decimal | float, now: Decimal | float) -> bytes:
    """The same print file cut for another size: the ink stays exactly where
    it is on the garment, the sheet around it grows or shrinks to the new
    size box. Used when the size changes in the cart — the design must not
    move, and the factory must never be handed a sheet cut for another size."""
    image = Image.open(io.BytesIO(data)).convert("RGBA")
    blank = Box(0.0, 0.0, 0.0, 0.0)
    old_origin = size_box(area, was) or blank
    new_origin = size_box(area, now) or blank
    was_w, was_h = size_mm(area, was)
    now_w, now_h = size_mm(area, now)
    left = round((new_origin.x0 - old_origin.x0) * image.width / float(was_w))
    top = round((new_origin.y0 - old_origin.y0) * image.height / float(was_h))
    # Pillow pads a crop that reaches outside the image with transparency,
    # which is exactly the blank sheet a bigger size needs.
    cut = image.crop((left, top, left + expected_pixels(now_w, method.dpi), top + expected_pixels(now_h, method.dpi)))
    out = io.BytesIO()
    cut.save(out, format="PNG", optimize=True)
    return out.getvalue()


def underbase(data: bytes) -> bytes:
    """White ink mask under a UV print on clear/dark bodies: every painted
    pixel becomes opaque white, the rest stays transparent."""
    alpha = Image.open(io.BytesIO(data)).convert("RGBA").getchannel("A").point(lambda value: 255 if value else 0)
    mask = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
    mask.putalpha(alpha)
    out = io.BytesIO()
    mask.save(out, format="PNG", optimize=True)
    return out.getvalue()
