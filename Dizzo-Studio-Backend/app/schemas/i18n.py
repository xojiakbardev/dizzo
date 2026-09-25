"""The `translations` of content in admin requests and responses.

{"ru": {"name": "Кружка", "description": "…"}, "en": {"name": "Mug"}} —
only the other languages (Uzbek lives in the fields themselves) and only
the fields a model translates. Empty values are dropped, so a missing
translation falls back to Uzbek (app/core/i18n.py `tr`).
"""

from typing import Annotated, Any

from pydantic import AfterValidator, BaseModel, PlainSerializer

from app.core.i18n import OTHER_LANGUAGES, _

# What each kind of content translates.
PRODUCT_FIELDS = frozenset({"name", "description"})
CATEGORY_FIELDS = frozenset({"name"})
SHAPE_FIELDS = frozenset({"name", "description"})
AREA_FIELDS = frozenset({"name", "placement_note"})
VARIANT_FIELDS = frozenset({"name", "short_description", "description", "specs", "sizes"})
COLOR_FIELDS = frozenset({"name"})
TEMPLATE_FIELDS = frozenset({"name"})
TUTORIAL_FIELDS = frozenset({"title"})

MAX_TEXT = 20000


def _clean(value: Any, field: str) -> Any:
    if isinstance(value, str):
        text = value.strip()
        if len(text) > MAX_TEXT:
            raise ValueError(_("{max_length} ta belgidan oshmasligi kerak", max_length=MAX_TEXT))
        return text
    if isinstance(value, list):
        # specs: [{"label", "value"}]; sizes: [{"label", ...}] — kept as given.
        return value
    raise ValueError(_("matn bo'lishi kerak"))


def checker(fields: frozenset[str]):
    def check(value: dict[str, dict[str, Any]]) -> dict[str, dict[str, Any]]:
        out: dict[str, dict[str, Any]] = {}
        for language, texts in (value or {}).items():
            if language not in OTHER_LANGUAGES:
                raise ValueError(_("tarjimada noma'lum til: {language}", language=language))
            kept: dict[str, Any] = {}
            for field, text in (texts or {}).items():
                if field not in fields:
                    raise ValueError(_("tarjimada noma'lum maydon: {field}", field=field))
                cleaned = _clean(text, field)
                if cleaned not in ("", [], None):
                    kept[field] = cleaned
            if kept:
                out[language] = kept
        return out

    return check


def Translations(fields: frozenset[str]):  # noqa: N802 — used as a type
    return Annotated[dict[str, dict[str, Any]], AfterValidator(checker(fields))]


def TypedTranslations(texts: type[BaseModel], fields: frozenset[str]):  # noqa: N802 — used as a type
    """`Translations` whose texts are checked by a model first: rich text
    cleaned, list items (specs, sizes) shaped like the Uzbek ones."""
    check = checker(fields)

    def convert(value: dict[str, BaseModel]) -> dict[str, dict[str, Any]]:
        return check({language: t.model_dump(mode="json", exclude_none=True) for language, t in value.items()})

    # Validated into plain dicts, so they are dumped as they are.
    return Annotated[dict[str, texts], AfterValidator(convert), PlainSerializer(lambda value: value)]


def merge_translations(current: dict | None, incoming: dict | None) -> dict:
    """A PATCH replaces the languages it sends, field by field."""
    merged = {lang: dict(texts) for lang, texts in (current or {}).items()}
    for language, texts in (incoming or {}).items():
        merged[language] = dict(texts)
    return {lang: texts for lang, texts in merged.items() if texts}
