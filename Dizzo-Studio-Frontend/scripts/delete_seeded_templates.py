#!/usr/bin/env python3
"""Delete templates created by scripts/seed_quality_templates.py."""

from __future__ import annotations

import json
import os
import ssl
import sys
import urllib.error
import urllib.request

API = os.environ.get("DIZZO_API_URL", "https://api.dizzo.uz/api").rstrip("/")
EMAIL = os.environ.get("DIZZO_ADMIN_EMAIL", "")
PASSWORD = os.environ.get("DIZZO_ADMIN_PASSWORD", "")
UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
)
CTX = ssl.create_default_context()

SEEDED_NAMES = {
    # old photo dump
    "Chimgan", "Tumanli o'rmon", "Bahor gullari", "Yulduzli tun", "Tonggi ko'l",
    "Ismingiz · luxury", "Tug'ilgan kun", "Eng yaxshi dadam",
    "Toshkent tog'lari", "Botanika", "O'rmon", "Qum tepaliklari",
    "Toshkent varsity", "Ismingiz arkasi", "Yaxshi kunlar",
    "O'rmon yo'li", "Tun osmoni", "Cho'qqi", "Gullar",
    "Atelier hoodie", "Silence hoodie",
    "Tog' kepkasi", "Gul kepkasi", "Yulduz kepkasi", "Toshkent kepka", "Initsiallar",
    "Tog' soati", "O'rmon soati", "Gul soati", "Yulduz soati", "Ko'l soati", "Minimal rim",
    "Tog' vizitkasi", "Gul vizitkasi", "O'rmon vizitkasi", "Minimal oq", "Qora luxury",
    # poly placeholders
    "Juftlik", "Qahva", "Monogramma", "Sevgilim", "Rasm joyi",
    "Katta ism", "Yurak va ism", "Toshkent yulduzi", "Rasm ramkasi",
    "Yurakcha", "Toshkent", "Yulduz",
    "Oila soati", "Rim raqamlari", "Yubiley soati",
    "Ism va telefon", "Markaziy ism", "Shaxsiy karta",
}


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
        raise RuntimeError(f"{method} {path} -> {err.code}: {err.read()[:400]}") from err


def main() -> None:
    if not EMAIL or not PASSWORD:
        sys.exit("Set DIZZO_ADMIN_EMAIL and DIZZO_ADMIN_PASSWORD")
    token = req("POST", "/auth/login/", body={"email": EMAIL, "password": PASSWORD})["access_token"]
    rows = req("GET", "/admin/catalog/templates/", token) or []
    mine = [t for t in rows if t.get("name") in SEEDED_NAMES]
    print(f"catalog templates={len(rows)}  to_delete={len(mine)}", flush=True)
    deleted = 0
    for t in mine:
        req("DELETE", f"/admin/catalog/templates/{t['id']}/", token)
        deleted += 1
        print(f"  deleted #{t['id']} {t['product_slug']} — {t['name']}", flush=True)
    print(f"Done. deleted={deleted}", flush=True)


if __name__ == "__main__":
    main()
