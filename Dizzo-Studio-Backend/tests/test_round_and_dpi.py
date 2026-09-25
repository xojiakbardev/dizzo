"""Tests for round print areas, corner radiuses, and low DPI blocking."""

import io
import math
from decimal import Decimal
from types import SimpleNamespace

import pytest
from PIL import Image, ImageDraw

from app.models.catalog import AreaMethod, PrintArea, Shape, Variant
from app.schemas.catalog import Hex
from app.schemas.design import DesignDocument, ImageSource, Layer
from app.services import design_rules, print_files
from app.services.print_files import PrintFileError, analyse


def make_png(w: int, h: int, draw_fn=None) -> bytes:
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    if draw_fn:
        draw_fn(ImageDraw.Draw(im), im)
    buf = io.BytesIO()
    im.save(buf, format="PNG")
    return buf.getvalue()


def test_round_print_file_rejects_corner_ink() -> None:
    # 50 x 50 mm at 300 DPI is 591 x 591 px
    dpi = 300
    w_px = print_files.expected_pixels(Decimal("50"), dpi)
    h_px = print_files.expected_pixels(Decimal("50"), dpi)

    area = SimpleNamespace(
        width_mm=Decimal("50"),
        height_mm=Decimal("50"),
        anchor={"round": True},
    )
    method = SimpleNamespace(
        method="uv",
        zone_x_mm=Decimal("0"),
        zone_y_mm=Decimal("0"),
        zone_w_mm=Decimal("50"),
        zone_h_mm=Decimal("50"),
        strip_width_mm=None,
        colors_allowed=True,
        dpi=dpi,
    )

    # 1. Corner ink (outside circle)
    def draw_corner(draw, im):
        draw.rectangle([5, 5, 20, 20], fill=(255, 0, 0, 255))

    data_corner = make_png(w_px, h_px, draw_corner)
    with pytest.raises(PrintFileError, match="zonadan tashqarida"):
        analyse(data_corner, area, method)

    # 2. Centre ink (inside circle)
    def draw_centre(draw, im):
        cx, cy = w_px // 2, h_px // 2
        draw.rectangle([cx - 20, cy - 20, cx + 20, cy + 20], fill=(255, 0, 0, 255))

    data_centre = make_png(w_px, h_px, draw_centre)
    res = analyse(data_centre, area, method)
    assert res.painted_cm2 > 0


def test_corner_radius_print_file_rejects_corner_ink() -> None:
    dpi = 300
    w_px = print_files.expected_pixels(Decimal("50"), dpi)
    h_px = print_files.expected_pixels(Decimal("50"), dpi)

    area = SimpleNamespace(
        width_mm=Decimal("50"),
        height_mm=Decimal("50"),
        anchor={"corner_radius_mm": "10"},
    )
    method = SimpleNamespace(
        method="uv",
        zone_x_mm=Decimal("0"),
        zone_y_mm=Decimal("0"),
        zone_w_mm=Decimal("50"),
        zone_h_mm=Decimal("50"),
        strip_width_mm=None,
        colors_allowed=True,
        dpi=dpi,
    )

    # Pixel at (2, 2) is in the sharp corner, outside 10mm rounded rect
    def draw_corner(draw, im):
        draw.point((2, 2), fill=(0, 0, 0, 255))

    data_corner = make_png(w_px, h_px, draw_corner)
    with pytest.raises(PrintFileError, match="zonadan tashqarida"):
        analyse(data_corner, area, method)


def test_printable_cm2_accounts_for_round_and_corner_radius() -> None:
    method = SimpleNamespace(
        method="uv",
        zone_x_mm="0",
        zone_y_mm="0",
        zone_w_mm="100",
        zone_h_mm="100",
    )
    # 1. Round area: 100 x 100 mm = 100 cm2 * pi / 4 = 78.54 cm2
    round_area = SimpleNamespace(
        width_mm=Decimal("100"),
        height_mm=Decimal("100"),
        anchor={"round": True},
        methods=[method],
    )
    variant_round = SimpleNamespace(
        shape=SimpleNamespace(areas=[round_area]),
    )
    cm2 = design_rules.printable_cm2(variant_round, "uv")
    expected_cm2 = Decimal(str((math.pi / 4.0) * 100.0)).quantize(Decimal("0.01"))
    assert cm2 == expected_cm2

    # 2. Square area: 100 x 100 mm = 100 cm2
    square_area = SimpleNamespace(
        width_mm=Decimal("100"),
        height_mm=Decimal("100"),
        anchor={},
        methods=[method],
    )
    variant_square = SimpleNamespace(
        shape=SimpleNamespace(areas=[square_area]),
    )
    assert design_rules.printable_cm2(variant_square, "uv") == Decimal("100.00")


def test_low_dpi_blocking_in_document_problems() -> None:
    area = SimpleNamespace(
        key="front",
        name="Oldi",
        width_mm=Decimal("100"),
        height_mm=Decimal("100"),
        anchor={},
        methods=[
            SimpleNamespace(
                method="uv",
                zone_x_mm="0",
                zone_y_mm="0",
                zone_w_mm="100",
                zone_h_mm="100",
                strip_width_mm=None,
                max_width_mm=None,
                max_height_mm=None,
                min_font_mm=None,
                colors_allowed=True,
                dpi=300,
            )
        ],
    )
    variant = SimpleNamespace(
        methods=["uv"],
        shape=SimpleNamespace(areas=[area]),
    )

    # 100x100 px image stretched to 50x50 mm (50 mm = 1.9685 inches -> ~50.8 DPI < 100)
    low_dpi_layer = Layer(
        id="l1",
        kind="image",
        area="front",
        method="uv",
        x_mm=50,
        y_mm=50,
        w_mm=50,
        h_mm=50,
        rotation=0,
        image=ImageSource(media_id="m1", url="https://example.com/test.png", px_w=100, px_h=100),
    )
    doc_bad = DesignDocument(layers=[low_dpi_layer])
    problems = design_rules.document_problems(doc_bad, variant)
    assert any("kamida 100 DPI" in p for p in problems)

    # Same 100x100 px image scaled to 15x15 mm (15 mm = 0.59 inches -> ~169 DPI >= 100)
    good_dpi_layer = Layer(
        id="l1",
        kind="image",
        area="front",
        method="uv",
        x_mm=50,
        y_mm=50,
        w_mm=15,
        h_mm=15,
        rotation=0,
        image=ImageSource(media_id="m1", url="https://example.com/test.png", px_w=100, px_h=100),
    )
    doc_good = DesignDocument(layers=[good_dpi_layer])
    problems_good = design_rules.document_problems(doc_good, variant)
    assert not any("DPI" in p for p in problems_good)
