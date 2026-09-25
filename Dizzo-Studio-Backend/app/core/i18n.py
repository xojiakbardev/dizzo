"""Three languages: Uzbek (the source), Russian and English.

The language of a request comes from `?lang=`, else `Accept-Language`, else
Uzbek (`LanguageMiddleware` puts it in a context variable). Messages are
written in Uzbek in the code and looked up by that text in the catalogs of
`app/locales/` (one module per area, each with a `MESSAGES` dict:
{"uz text with {placeholders}": {"ru": "...", "en": "..."}}):

    raise HTTPException(404, detail=_("{what} topilmadi", what=_("Mahsulot")))

A message raised as a plain Uzbek string (a module constant) is still
translated on its way out by the HTTPException handler. Content (a
product's name, a colour…) keeps Uzbek in its own columns and the other
languages in the row's `translations` JSON: {"ru": {"name": …}, "en": {…}};
`tr()` reads the request's language with Uzbek as the fallback.
"""

from __future__ import annotations

import importlib
import pkgutil
from contextvars import ContextVar
from typing import Any

LANGUAGES = ("uz", "ru", "en")
DEFAULT_LANGUAGE = "uz"
OTHER_LANGUAGES = ("ru", "en")

_language: ContextVar[str] = ContextVar("language", default=DEFAULT_LANGUAGE)


def get_language() -> str:
    return _language.get()


def set_language(language: str) -> None:
    _language.set(language if language in LANGUAGES else DEFAULT_LANGUAGE)


def pick_language(query: str | None, accept: str | None) -> str:
    """`?lang=` wins; else the first supported language of Accept-Language
    (by its q weight); else Uzbek."""
    if query and query.lower()[:2] in LANGUAGES:
        return query.lower()[:2]
    ranked: list[tuple[float, int, str]] = []
    for index, part in enumerate((accept or "").split(",")):
        piece = part.strip()
        if not piece:
            continue
        tag, _, params = piece.partition(";")
        weight = 1.0
        if params.strip().startswith("q="):
            try:
                weight = float(params.strip()[2:])
            except ValueError:
                weight = 0.0
        code = tag.strip().lower()[:2]
        if code in LANGUAGES and weight > 0:
            ranked.append((-weight, index, code))
    return min(ranked)[2] if ranked else DEFAULT_LANGUAGE


def _load_catalog() -> dict[str, dict[str, str]]:
    from app import locales

    catalog: dict[str, dict[str, str]] = {}
    for module in pkgutil.iter_modules(locales.__path__):
        messages = getattr(importlib.import_module(f"app.locales.{module.name}"), "MESSAGES", {})
        catalog.update(messages)
    return catalog


_catalog: dict[str, dict[str, str]] | None = None


def catalog() -> dict[str, dict[str, str]]:
    global _catalog
    if _catalog is None:
        _catalog = _load_catalog()
    return _catalog


def translate(message: str, language: str | None = None) -> str:
    """The message in `language` (the request's by default); itself when
    there is no translation."""
    language = language or get_language()
    if language == DEFAULT_LANGUAGE:
        return message
    return catalog().get(message, {}).get(language) or message


def _(message: str, /, language: str | None = None, **params: Any) -> str:
    """Translate an Uzbek message, then fill its {placeholders}."""
    text = translate(message, language)
    return text.format(**params) if params else text


def tr(row: Any, field: str, language: str | None = None) -> Any:
    """A content field in the request's language, Uzbek when missing."""
    language = language or get_language()
    base = getattr(row, field)
    if language == DEFAULT_LANGUAGE:
        return base
    value = ((getattr(row, "translations", None) or {}).get(language) or {}).get(field)
    return value if value not in (None, "", []) else base


def tr_dict(translations: dict | None, field: str, base: Any, language: str | None = None) -> Any:
    """`tr` for a snapshot kept as plain data (an order line)."""
    language = language or get_language()
    if language == DEFAULT_LANGUAGE:
        return base
    value = ((translations or {}).get(language) or {}).get(field)
    return value if value not in (None, "", []) else base


class LanguageMiddleware:
    """Sets the request's language for everything that runs inside it."""

    def __init__(self, app: Any) -> None:
        self.app = app

    async def __call__(self, scope: dict, receive: Any, send: Any) -> None:
        if scope["type"] in ("http", "websocket"):
            from urllib.parse import parse_qs

            query = parse_qs(scope.get("query_string", b"").decode("latin-1")).get("lang", [None])[0]
            headers = dict(scope.get("headers") or [])
            accept = headers.get(b"accept-language", b"").decode("latin-1")
            token = _language.set(pick_language(query, accept))
            try:
                await self.app(scope, receive, send)
            finally:
                _language.reset(token)
            return
        await self.app(scope, receive, send)
