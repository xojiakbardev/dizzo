"""Print files are size-checked from the PNG header, before decoding."""

import struct
import zlib
from decimal import Decimal
from types import SimpleNamespace

import pytest

from app.services import print_files
from app.services.print_files import MAX_PIXELS, PrintFileError, analyse


def png_header_only(width: int, height: int) -> bytes:
    """A PNG signature and IHDR claiming width×height, then a stub IDAT
    (Image.open stops there) with next to no pixel data."""

    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)  # 8-bit RGBA
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(b"\x00" * 16))


def area_for(width_px: int, height_px: int, dpi: int = 300) -> tuple[SimpleNamespace, SimpleNamespace]:
    mm = lambda px: (Decimal(px) * Decimal("25.4") / dpi).quantize(Decimal("0.01"))  # noqa: E731
    return SimpleNamespace(width_mm=mm(width_px), height_mm=mm(height_px)), SimpleNamespace(dpi=dpi)


@pytest.mark.filterwarnings("ignore::PIL.Image.DecompressionBombWarning")
def test_an_oversized_print_file_is_refused_before_decoding(monkeypatch: pytest.MonkeyPatch) -> None:
    decoded: list[bool] = []
    monkeypatch.setattr(print_files.Image.Image, "load", lambda self: decoded.append(True))
    area, method = area_for(7000, 7000)  # 49 MP: more than the cap, less than Pillow's hard 2× limit
    assert 7000 * 7000 > MAX_PIXELS

    with pytest.raises(PrintFileError, match="juda katta"):
        analyse(png_header_only(7000, 7000), area, method)
    assert decoded == []


def test_a_wrong_size_is_refused_before_decoding(monkeypatch: pytest.MonkeyPatch) -> None:
    decoded: list[bool] = []
    monkeypatch.setattr(print_files.Image.Image, "load", lambda self: decoded.append(True))
    area, method = area_for(2669, 933)

    with pytest.raises(PrintFileError, match="bo'lishi kerak"):
        analyse(png_header_only(6000, 6000), area, method)
    assert decoded == []


def test_a_decompression_bomb_is_unreadable() -> None:
    area, method = area_for(30000, 30000)
    with pytest.raises(PrintFileError, match="o'qib bo'lmadi"):
        analyse(png_header_only(30000, 30000), area, method)


def test_a_truncated_file_of_the_right_size_is_unreadable() -> None:
    area, method = area_for(100, 50)
    with pytest.raises(PrintFileError, match="o'qib bo'lmadi"):
        analyse(png_header_only(100, 50), area, method)
