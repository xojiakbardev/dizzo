#!/usr/bin/env python3
"""Seed editable vizitka templates (90×50 mm, front + back).

Layouts follow common internet business-card patterns. Sample names, phones
and titles are filled in so the user only swaps their own details. Matching
background photos are uploaded as replaceable image layers.

Gallery stays empty: previews are flat print layouts for the template picker.
"""

from __future__ import annotations

import io
import json
import os
import ssl
import sys
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ASSETS = Path(__file__).resolve().parent / "seed-assets"
API = os.environ.get("DIZZO_API_URL", "https://api.dizzo.uz/api").rstrip("/")
EMAIL = os.environ.get("DIZZO_ADMIN_EMAIL", "")
PASSWORD = os.environ.get("DIZZO_ADMIN_PASSWORD", "")
UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
)
CTX = ssl.create_default_context()
DPI = 170
W, H = 90.0, 50.0
FRONT, BACK = "old", "orqa"

NAVY, GOLD, TEAL, ORANGE, ROSE = "#1b2a4a", "#c4a35a", "#0f766e", "#c2410c", "#9f1239"
INK, LIGHT, MUTED, CREAM = "#18181b", "#f7f4ef", "#6b7280", "#f4efe6"
WHITE = "#ffffff"

FONT_SANS = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
FONT_SANS_B = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_SERIF = "/System/Library/Fonts/Supplemental/Georgia.ttf"
FONT_SERIF_B = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"


def log(*a):
    print(*a, flush=True)


def req(method, path, token=None, body=None):
    headers = {"User-Agent": UA, "Origin": "https://dizzo.uz", "Referer": "https://dizzo.uz/"}
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode()
    if token:
        headers["Authorization"] = f"Bearer {token}"
    r = urllib.request.Request(f"{API}{path}", data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(r, context=CTX, timeout=60) as res:
            raw = res.read()
            if res.status == 204 or not raw:
                return None
            return json.loads(raw) if "json" in (res.headers.get("Content-Type") or "") else raw
    except urllib.error.HTTPError as err:
        raise RuntimeError(f"{method} {path} -> {err.code}: {err.read()[:600]}") from err


class Api:
    def __init__(self, token: str):
        self.token = token

    def get(self, p):
        return req("GET", p, self.token)

    def post(self, p, body=None):
        return req("POST", p, self.token, body)


def px(mm: float) -> int:
    return max(8, int(mm / 25.4 * DPI + 0.5))


def cover(im: Image.Image, w: int, h: int) -> Image.Image:
    scale = max(w / im.width, h / im.height)
    nw, nh = max(1, int(im.width * scale)), max(1, int(im.height * scale))
    resized = im.convert("RGB").resize((nw, nh), Image.Resampling.LANCZOS)
    left, top = (nw - w) // 2, (nh - h) // 2
    return resized.crop((left, top, left + w, top + h))


def encode_webp(im: Image.Image, quality: int = 84) -> bytes:
    buf = io.BytesIO()
    im.save(buf, format="WEBP", quality=quality, method=6)
    return buf.getvalue()


def upload(api: Api, data: bytes) -> dict:
    ticket = api.post("/media/uploads/", {
        "purpose": "design", "content_type": "image/webp", "size_bytes": len(data),
    })
    put = urllib.request.Request(
        ticket["upload_url"], data=data, method="PUT", headers=ticket["upload_headers"],
    )
    with urllib.request.urlopen(put, context=CTX, timeout=120) as res:
        res.read()
    api.post(f"/media/{ticket['id']}/complete/")
    info = Image.open(io.BytesIO(data))
    return {"id": ticket["id"], "px_w": info.size[0], "px_h": info.size[1]}


def named(uz, ru, en):
    return {"name": uz, "translations": {"ru": {"name": ru}, "en": {"name": en}}}


def box(left, top, w, h):
    return round(left + w / 2, 2), round(top + h / 2, 2), round(w, 2), round(h, 2)


def text(id_, area, left, top, w, h, content, font, size, color, align="left", bold=False, italic=False):
    x, y, ww, hh = box(left, top, w, h)
    return {
        "id": id_, "area": area, "method": "uv", "kind": "text",
        "x_mm": x, "y_mm": y, "w_mm": ww, "h_mm": hh, "rotation": 0,
        "text": {"content": content, "font": font, "size_mm": size, "color": color, "align": align, "bold": bold, "italic": italic},
    }


def icon(id_, area, left, top, s, name, color):
    x, y, ww, hh = box(left, top, s, s)
    return {
        "id": id_, "area": area, "method": "uv", "kind": "graphic",
        "x_mm": x, "y_mm": y, "w_mm": ww, "h_mm": hh, "rotation": 0,
        "graphic": {"library": "icon", "name": name, "color": color},
    }


def shape(id_, area, left, top, w, h, name, color):
    x, y, ww, hh = box(left, top, w, h)
    return {
        "id": id_, "area": area, "method": "uv", "kind": "graphic",
        "x_mm": x, "y_mm": y, "w_mm": ww, "h_mm": hh, "rotation": 0,
        "graphic": {"library": "shape", "name": name, "color": color},
    }


def image(id_, area, media, left=0, top=0, w=W, h=H):
    x, y, ww, hh = box(left, top, w, h)
    return {
        "id": id_, "area": area, "method": "uv", "kind": "image",
        "x_mm": x, "y_mm": y, "w_mm": ww, "h_mm": hh, "rotation": 0,
        "image": {"media_id": media["id"], "url": "", "px_w": media["px_w"], "px_h": media["px_h"]},
    }


def line(id_, area, left, top, w, color):
    return shape(id_, area, left, top, w, 0.45, "line", color)


def doc(*layers):
    return {"version": 1, "layers": list(layers), "links": [], "strips": []}


def contacts(area, ink, muted, phone, mail, tg, city, y0=12.0, prefix="b"):
    return [
        text(f"{prefix}p", area, 10, y0, 70, 6, phone, "Montserrat", 2.6, ink, align="left"),
        text(f"{prefix}m", area, 10, y0 + 8, 70, 6, mail, "Montserrat", 2.5, muted, align="left"),
        text(f"{prefix}t", area, 10, y0 + 16, 70, 6, tg, "Montserrat", 2.5, muted, align="left"),
        text(f"{prefix}c", area, 10, y0 + 24, 70, 6, city, "Montserrat", 2.4, muted, align="left"),
    ]


def pack(detail, category, n, layers, preview_id):
    return {
        **n,
        "category": category,
        "variant_ids": [v["id"] for v in detail["variants"] if v.get("colors")],
        "color_id": detail["variants"][0]["colors"][0]["id"],
        "in_gallery": False,
        "preview_media_id": preview_id,
        "images": [],
        "document": doc(*layers),
    }


def font(path, size_px):
    try:
        return ImageFont.truetype(path, size_px)
    except OSError:
        return ImageFont.load_default()


def hex_rgb(value: str) -> tuple[int, int, int]:
    v = value.lstrip("#")
    return int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16)


def paint_preview(bg: Image.Image | None, fill: str | None, bars: list, labels: list) -> bytes:
    canvas = Image.new("RGB", (px(W), px(H)), hex_rgb(fill or WHITE))
    if bg is not None:
        canvas = cover(bg, px(W), px(H))
    draw = ImageDraw.Draw(canvas)
    for left, top, w, h, color in bars:
        draw.rectangle([px(left), px(top), px(left + w), px(top + h)], fill=hex_rgb(color))
    for left, top, content, size_mm, color, bold, serif in labels:
        face = (FONT_SERIF_B if serif else FONT_SANS_B) if bold else (FONT_SERIF if serif else FONT_SANS)
        draw.text((px(left), px(top)), content, fill=hex_rgb(color), font=font(face, px(size_mm)))
    return encode_webp(canvas)


def cards(media):
    ivory, navy, charcoal, coffee, sage, rose = (
        media["ivory"], media["navy"], media["charcoal"], media["coffee"], media["sage"], media["rose"],
    )

    yield (
        "Advokat", "Адвокат", "Lawyer", "Biznes",
        [
            image("bg", FRONT, ivory),
            shape("bar", FRONT, 0, 0, 22, H, "square", NAVY),
            text("in", FRONT, 4, 16, 14, 18, "AK", "Playfair Display", 9, GOLD, align="center", bold=True),
            text("n", FRONT, 28, 14, 56, 10, "Aziza Karimova", "Playfair Display", 5.2, NAVY, align="left", bold=True),
            text("r", FRONT, 28, 25, 56, 6, "Advokat", "Montserrat", 2.8, GOLD, align="left"),
            line("ln", FRONT, 28, 33, 22, GOLD),
            text("f", FRONT, 28, 37, 56, 6, "Karimova Law", "Montserrat", 2.4, MUTED, align="left"),
            shape("bb", BACK, 0, 0, W, H, "square", NAVY),
            text("b1", BACK, 10, 10, 70, 8, "Bog'lanish", "Montserrat", 2.4, GOLD, align="left"),
            *contacts(BACK, LIGHT, "#c5c9d4", "+998 90 112 45 67", "aziza@karimova.uz", "@karimova_law", "Toshkent, Amir Temur 14", 20),
        ],
        "ivory", NAVY,
        [(0, 0, 22, H, NAVY)],
        [(5, 17, "AK", 8, GOLD, True, True), (29, 14, "Aziza Karimova", 5.2, NAVY, True, True), (29, 26, "Advokat", 2.8, GOLD, False, False)],
    )

    yield (
        "Minimal", "Минимал", "Minimal", "Biznes",
        [
            text("n", FRONT, 8, 12, 74, 10, "Jasur Mirzaev", "Montserrat", 5.4, INK, align="left", bold=True),
            line("ln", FRONT, 8, 24, 18, GOLD),
            text("r", FRONT, 8, 28, 74, 6, "Creative director", "Montserrat", 2.6, MUTED, align="left"),
            text("p", FRONT, 8, 38, 74, 6, "+998 97 700 18 18", "Montserrat", 2.5, INK, align="left"),
            text("b1", BACK, 8, 14, 74, 8, "Dizzo Studio", "Montserrat", 3.4, INK, align="left", bold=True),
            text("b2", BACK, 8, 24, 74, 6, "jasur@dizzo.uz", "Montserrat", 2.5, MUTED, align="left"),
            text("b3", BACK, 8, 32, 74, 6, "@mirzaev_studio", "Montserrat", 2.5, MUTED, align="left"),
            text("b4", BACK, 8, 40, 74, 6, "Toshkent", "Montserrat", 2.4, MUTED, align="left"),
        ],
        None, WHITE,
        [],
        [(8, 12, "Jasur Mirzaev", 5.4, INK, True, False), (8, 28, "Creative director", 2.6, MUTED, False, False), (8, 38, "+998 97 700 18 18", 2.5, INK, False, False)],
    )

    yield (
        "Shifokor", "Врач", "Doctor", "Tibbiyot",
        [
            shape("bar", FRONT, 0, 0, W, 8, "square", TEAL),
            icon("ic", FRONT, 8, 16, 8, "stethoscope", TEAL),
            text("n", FRONT, 20, 14, 62, 10, "Dr. Kamola Yusupova", "Playfair Display", 4.6, INK, align="left", bold=True),
            text("r", FRONT, 20, 25, 62, 6, "Terapevt · Semeynaya klinika", "Montserrat", 2.5, TEAL, align="left"),
            text("p", FRONT, 8, 38, 74, 6, "+998 71 200 45 90", "Montserrat", 2.6, INK, align="left"),
            shape("bb", BACK, 0, 0, W, H, "square", TEAL),
            text("b1", BACK, 10, 12, 70, 8, "Qabul soatlari  09:00 — 18:00", "Montserrat", 2.6, WHITE, align="left"),
            text("b2", BACK, 10, 24, 70, 6, "kamola@semeya.uz", "Montserrat", 2.5, CREAM, align="left"),
            text("b3", BACK, 10, 32, 70, 6, "Yunusobod 12, Toshkent", "Montserrat", 2.5, CREAM, align="left"),
        ],
        None, WHITE,
        [(0, 0, W, 8, TEAL)],
        [(20, 15, "Dr. Kamola Yusupova", 4.4, INK, True, True), (20, 26, "Terapevt", 2.6, TEAL, False, False), (8, 38, "+998 71 200 45 90", 2.6, INK, False, False)],
    )

    yield (
        "Rieltor", "Риелтор", "Realtor", "Biznes",
        [
            image("bg", FRONT, navy),
            icon("ic", FRONT, 8, 10, 8, "house", GOLD),
            text("co", FRONT, 20, 11, 60, 7, "NEST HOME", "Montserrat", 3.2, GOLD, align="left", bold=True),
            text("n", FRONT, 8, 24, 74, 10, "Bekzod Raximov", "Montserrat", 5.0, WHITE, align="left", bold=True),
            text("r", FRONT, 8, 35, 74, 6, "Ko'chmas mulk maslahatchisi", "Montserrat", 2.5, "#d6d3d1", align="left"),
            image("bg2", BACK, navy),
            *contacts(BACK, WHITE, "#d6d3d1", "+998 93 501 22 11", "bekzod@nesthome.uz", "@nest_home", "Chilonzor, Toshkent", 12),
        ],
        "navy", NAVY,
        [],
        [(20, 11, "NEST HOME", 3.2, GOLD, True, False), (8, 24, "Bekzod Raximov", 5.0, WHITE, True, False), (8, 36, "Ko'chmas mulk", 2.5, "#d6d3d1", False, False)],
    )

    yield (
        "Qahvaxona", "Кофейня", "Cafe", "Oziq-ovqat",
        [
            image("bg", FRONT, coffee),
            icon("ic", FRONT, 41, 8, 8, "coffee", INK),
            text("n", FRONT, 8, 20, 74, 10, "Dilnoza Cafe", "Playfair Display", 6.0, INK, align="center", italic=True),
            text("r", FRONT, 8, 32, 74, 6, "Qahva  ·  desert  ·  nonushta", "Montserrat", 2.4, "#7c2d12", align="center"),
            image("bg2", BACK, coffee),
            text("b1", BACK, 8, 12, 74, 8, "Har kuni 08:00 — 22:00", "Montserrat", 2.8, INK, align="center"),
            text("b2", BACK, 8, 24, 74, 6, "+998 90 808 17 17", "Montserrat", 2.6, INK, align="center"),
            text("b3", BACK, 8, 32, 74, 6, "@dilnoza_cafe", "Montserrat", 2.5, "#7c2d12", align="center"),
            text("b4", BACK, 8, 40, 74, 6, "Sergeli, Toshkent", "Montserrat", 2.4, INK, align="center"),
        ],
        "coffee", CREAM,
        [],
        [(18, 20, "Dilnoza Cafe", 6.0, INK, True, True), (18, 33, "Qahva  ·  desert", 2.5, "#7c2d12", False, False)],
    )

    yield (
        "Fotograf", "Фотограф", "Photographer", "Ijod",
        [
            image("bg", FRONT, charcoal),
            icon("ic", FRONT, 8, 9, 7, "camera", GOLD),
            text("n", FRONT, 8, 20, 74, 10, "Malika Saidova", "Playfair Display", 5.4, WHITE, align="left", italic=True),
            text("r", FRONT, 8, 32, 74, 6, "To'y  ·  portret  ·  oila", "Montserrat", 2.5, GOLD, align="left"),
            image("bg2", BACK, charcoal),
            *contacts(BACK, WHITE, "#d4d4d8", "+998 99 321 09 09", "hello@malika.photo", "@malika.photo", "Toshkent", 12),
        ],
        "charcoal", INK,
        [],
        [(8, 20, "Malika Saidova", 5.4, WHITE, True, True), (8, 33, "To'y  ·  portret  ·  oila", 2.5, GOLD, False, False)],
    )

    yield (
        "IT mutaxassis", "IT специалист", "IT specialist", "IT",
        [
            image("bg", FRONT, navy),
            icon("ic", FRONT, 8, 9, 7, "code", GOLD),
            text("n", FRONT, 8, 20, 74, 10, "Xojiakbar Nasriddinov", "Montserrat", 4.4, WHITE, align="left", bold=True),
            text("r", FRONT, 8, 32, 74, 6, "Fullstack developer", "Montserrat", 2.6, GOLD, align="left"),
            text("tg", FRONT, 8, 40, 74, 6, "@nasriddinov_dev", "Montserrat", 2.4, "#cbd5e1", align="left"),
            image("bg2", BACK, navy),
            text("b1", BACK, 8, 14, 74, 8, "+998 77 306 70 67", "Montserrat", 3.2, WHITE, align="left", bold=True),
            text("b2", BACK, 8, 26, 74, 6, "xojiakbar@nasriddinov.dev", "Montserrat", 2.5, "#cbd5e1", align="left"),
            text("b3", BACK, 8, 36, 74, 6, "Toshkent", "Montserrat", 2.4, GOLD, align="left"),
        ],
        "navy", NAVY,
        [],
        [(8, 20, "Xojiakbar Nasriddinov", 4.2, WHITE, True, False), (8, 32, "Fullstack developer", 2.6, GOLD, False, False)],
    )

    yield (
        "Gulchi", "Цветочный", "Florist", "Ijod",
        [
            image("bg", FRONT, sage),
            icon("ic", FRONT, 41, 7, 8, "flower-tulip", "#3f6212"),
            text("n", FRONT, 8, 18, 74, 10, "Nilufar Guli", "Playfair Display", 5.6, "#14532d", align="center", italic=True),
            text("r", FRONT, 8, 30, 74, 6, "Gul do'koni  ·  buketlar", "Montserrat", 2.5, "#3f6212", align="center"),
            text("p", FRONT, 8, 40, 74, 6, "+998 90 444 21 21", "Montserrat", 2.5, INK, align="center"),
            image("bg2", BACK, sage),
            text("b1", BACK, 8, 16, 74, 8, "@nilufar_guli", "Montserrat", 3.0, "#14532d", align="center"),
            text("b2", BACK, 8, 28, 74, 6, "hello@nilufar.uz", "Montserrat", 2.5, "#3f6212", align="center"),
            text("b3", BACK, 8, 38, 74, 6, "Mirzo Ulug'bek, Toshkent", "Montserrat", 2.4, INK, align="center"),
        ],
        "sage", "#e8f0e3",
        [],
        [(16, 18, "Nilufar Guli", 5.6, "#14532d", True, True), (16, 31, "Gul do'koni", 2.5, "#3f6212", False, False)],
    )

    yield (
        "Quruvchi", "Строитель", "Contractor", "Xizmat",
        [
            shape("bar", FRONT, 0, 0, 8, H, "square", ORANGE),
            text("co", FRONT, 14, 8, 68, 6, "ALIYEV BUILD", "Oswald", 3.4, ORANGE, align="left", bold=True),
            text("n", FRONT, 14, 18, 68, 10, "Sardor Aliyev", "Montserrat", 5.2, INK, align="left", bold=True),
            text("r", FRONT, 14, 30, 68, 6, "Qurilish  ·  ta'mirlash", "Montserrat", 2.6, MUTED, align="left"),
            text("p", FRONT, 14, 40, 68, 6, "+998 91 155 70 70", "Montserrat", 2.6, INK, align="left"),
            shape("bb", BACK, 0, 0, W, H, "square", ORANGE),
            icon("bic", BACK, 10, 12, 8, "briefcase", WHITE),
            text("b1", BACK, 22, 13, 58, 7, "15 yillik tajriba", "Montserrat", 2.8, WHITE, align="left", bold=True),
            text("b2", BACK, 10, 28, 70, 6, "sardor@aliyevbuild.uz", "Montserrat", 2.5, CREAM, align="left"),
            text("b3", BACK, 10, 38, 70, 6, "Olmazor, Toshkent", "Montserrat", 2.4, CREAM, align="left"),
        ],
        None, WHITE,
        [(0, 0, 8, H, ORANGE)],
        [(14, 8, "ALIYEV BUILD", 3.2, ORANGE, True, False), (14, 18, "Sardor Aliyev", 5.2, INK, True, False), (14, 40, "+998 91 155 70 70", 2.6, INK, False, False)],
    )

    yield (
        "Go'zallik saloni", "Салон красоты", "Beauty salon", "Xizmat",
        [
            image("bg", FRONT, rose),
            icon("ic", FRONT, 41, 7, 7, "sparkle", WHITE),
            text("n", FRONT, 8, 18, 74, 10, "Madina Beauty", "Playfair Display", 5.6, WHITE, align="center", italic=True),
            text("r", FRONT, 8, 30, 74, 6, "Soch  ·  makeup  ·  nail", "Montserrat", 2.5, "#fff1f2", align="center"),
            text("p", FRONT, 8, 40, 74, 6, "+998 95 007 77 07", "Montserrat", 2.5, WHITE, align="center"),
            image("bg2", BACK, rose),
            text("b1", BACK, 8, 16, 74, 8, "@madina.beauty", "Montserrat", 3.0, WHITE, align="center"),
            text("b2", BACK, 8, 28, 74, 6, "Yakkasaroy, Toshkent", "Montserrat", 2.5, WHITE, align="center"),
            text("b3", BACK, 8, 38, 74, 6, "10:00 — 20:00", "Montserrat", 2.4, WHITE, align="center"),
        ],
        "rose", ROSE,
        [],
        [(16, 18, "Madina Beauty", 5.6, WHITE, True, True), (16, 32, "Soch  ·  makeup  ·  nail", 2.5, WHITE, False, False)],
    )

    yield (
        "O'qituvchi", "Учитель", "Teacher", "Ta'lim",
        [
            icon("ic", FRONT, 8, 10, 8, "chalkboard-teacher", NAVY),
            text("n", FRONT, 20, 10, 62, 10, "Nodira Toshkentova", "Lora", 4.6, NAVY, align="left", bold=True),
            text("r", FRONT, 20, 22, 62, 6, "Ingliz tili o'qituvchisi", "Montserrat", 2.6, GOLD, align="left"),
            line("ln", FRONT, 8, 32, 30, GOLD),
            text("p", FRONT, 8, 38, 74, 6, "+998 94 560 33 22", "Montserrat", 2.6, INK, align="left"),
            text("b1", BACK, 8, 12, 74, 8, "IELTS  ·  maktab  ·  online", "Montserrat", 2.8, NAVY, align="left", bold=True),
            text("b2", BACK, 8, 24, 74, 6, "nodira@english.uz", "Montserrat", 2.5, MUTED, align="left"),
            text("b3", BACK, 8, 32, 74, 6, "@nodira_english", "Montserrat", 2.5, MUTED, align="left"),
            text("b4", BACK, 8, 40, 74, 6, "Toshkent", "Montserrat", 2.4, MUTED, align="left"),
        ],
        None, WHITE,
        [],
        [(20, 11, "Nodira Toshkentova", 4.4, NAVY, True, True), (20, 23, "Ingliz tili o'qituvchisi", 2.6, GOLD, False, False), (8, 38, "+998 94 560 33 22", 2.6, INK, False, False)],
    )

    yield (
        "Buxgalter", "Бухгалтер", "Accountant", "Biznes",
        [
            image("bg", FRONT, navy),
            icon("ic", FRONT, 8, 9, 7, "chart-line-up", GOLD),
            text("n", FRONT, 8, 20, 74, 10, "Alisher Qodirov", "Montserrat", 5.0, WHITE, align="left", bold=True),
            text("r", FRONT, 8, 32, 74, 6, "Buxgalter  ·  soliq maslahati", "Montserrat", 2.5, GOLD, align="left"),
            image("bg2", BACK, navy),
            *contacts(BACK, WHITE, "#cbd5e1", "+998 98 765 43 21", "alisher@qodirov.uz", "@qodirov_finance", "Shayxontohur, Toshkent", 12),
        ],
        "navy", NAVY,
        [],
        [(8, 20, "Alisher Qodirov", 5.0, WHITE, True, False), (8, 33, "Buxgalter  ·  soliq", 2.5, GOLD, False, False)],
    )


def load_bg(name: str) -> Image.Image:
    path = ASSETS / name
    if not path.exists():
        raise RuntimeError(f"missing {path}")
    return Image.open(path).convert("RGB")


def main() -> None:
    if not EMAIL or not PASSWORD:
        sys.exit("Set DIZZO_ADMIN_EMAIL and DIZZO_ADMIN_PASSWORD")
    token = req("POST", "/auth/login/", body={"email": EMAIL, "password": PASSWORD})["access_token"]
    api = Api(token)
    me = api.get("/auth/me")
    log(f"Logged in as {me.get('email')} ({me.get('role')})")
    products = {p["slug"]: p for p in api.get("/admin/catalog/products/")}
    admin = products.get("vizitka")
    if not admin:
        sys.exit("vizitka product missing")
    detail = api.get("/catalog/products/vizitka/")
    have = {t["name"] for t in (api.get("/admin/catalog/templates/") or []) if t.get("product_id") == admin["id"]}
    log(f"Existing vizitka templates: {len(have)}")

    files = {
        "ivory": "vizitka-bg-ivory.png",
        "navy": "vizitka-bg-navy.png",
        "charcoal": "vizitka-bg-charcoal.png",
        "coffee": "vizitka-bg-coffee.png",
        "sage": "vizitka-bg-sage.png",
        "rose": "vizitka-bg-rose.png",
    }
    media = {}
    originals = {}
    for key, name in files.items():
        im = load_bg(name)
        originals[key] = im
        data = encode_webp(cover(im, px(W), px(H)))
        media[key] = upload(api, data)
        log(f"  uploaded {name}")

    created = skipped = errors = 0
    for uz, ru, en, cat, layers, bg_key, fill, bars, labels in cards(media):
        if uz in have:
            skipped += 1
            log(f"  · exists {uz}")
            continue
        bg = originals.get(bg_key)
        try:
            preview = upload(api, paint_preview(bg, fill, bars, labels))
            body = pack(detail, cat, named(uz, ru, en), layers, preview["id"])
            saved = api.post(f"/admin/catalog/products/{admin['id']}/templates/", body)
            have.add(uz)
            created += 1
            log(f"  ✓ #{saved['id']} {saved['name']}")
        except Exception as err:
            errors += 1
            log(f"  ✗ {uz}: {err}")
    log(f"\nDone. created={created} skipped={skipped} errors={errors}")
    if errors:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
