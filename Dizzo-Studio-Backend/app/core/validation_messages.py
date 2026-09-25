"""Request validation errors in the request's language.

The response keeps FastAPI's shape — {"detail": [{"loc", "msg", "type"}]} —
only `msg` is translated, so clients that read it keep working and admins
see "0 dan katta bo'lishi kerak" (or its Russian/English) instead of
pydantic's own text. Messages raised by our own validators (ValueError)
are Uzbek and go through the same catalogs (app/locales/).
"""

from fastapi import Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import HTTPException, RequestValidationError
from fastapi.responses import JSONResponse

from app.core.i18n import _, translate

TEMPLATES: dict[str, str] = {
    "missing": "majburiy maydon",
    "greater_than": "{gt} dan katta bo'lishi kerak",
    "greater_than_equal": "{ge} yoki undan katta bo'lishi kerak",
    "less_than": "{lt} dan kichik bo'lishi kerak",
    "less_than_equal": "{le} dan oshmasligi kerak",
    "string_too_short": "kamida {min_length} ta belgi bo'lishi kerak",
    "string_too_long": "{max_length} ta belgidan oshmasligi kerak",
    "too_short": "kamida {min_length} ta element kerak",
    "too_long": "{max_length} ta elementdan oshmasligi kerak",
    "string_pattern_mismatch": "noto'g'ri format",
    "literal_error": "quyidagilardan biri bo'lishi kerak: {expected}",
    "enum": "quyidagilardan biri bo'lishi kerak: {expected}",
    "int_parsing": "butun son bo'lishi kerak",
    "int_type": "butun son bo'lishi kerak",
    "decimal_parsing": "son bo'lishi kerak",
    "decimal_type": "son bo'lishi kerak",
    "float_parsing": "son bo'lishi kerak",
    "decimal_max_places": "verguldan keyin ko'pi bilan {decimal_places} xona",
    "decimal_max_digits": "son juda katta",
    "decimal_whole_digits": "son juda katta",
    "bool_parsing": "ha/yo'q qiymati bo'lishi kerak",
    "bool_type": "ha/yo'q qiymati bo'lishi kerak",
    "string_type": "matn bo'lishi kerak",
    "list_type": "ro'yxat bo'lishi kerak",
    "dict_type": "obyekt bo'lishi kerak",
    "extra_forbidden": "noma'lum maydon",
    "json_invalid": "noto'g'ri JSON",
}


def validation_message(error: dict) -> str:
    kind = error["type"]
    ctx = error.get("ctx", {})
    if kind == "value_error":
        # Our validators raise ValueError with Uzbek text (kept in ctx["error"]);
        # EmailStr raises its own value_error carrying ctx["reason"] instead.
        if "error" in ctx:
            return translate(str(ctx["error"]))
        if "reason" in ctx:
            return _("noto'g'ri email manzil")
        return _("noto'g'ri qiymat")
    template = TEMPLATES.get(kind)
    if template is None:
        return _("noto'g'ri qiymat")
    return _(template, **{k: str(v) for k, v in ctx.items()})


async def validation_error_handler(_request: Request, exc: RequestValidationError) -> JSONResponse:
    detail = [
        {"loc": err["loc"], "msg": validation_message(err), "type": err["type"]}
        for err in exc.errors()
    ]
    return JSONResponse(status_code=422, content=jsonable_encoder({"detail": detail}))


async def http_error_handler(_request: Request, exc: HTTPException) -> JSONResponse:
    """An HTTPException raised with plain Uzbek text leaves translated."""
    detail = exc.detail
    if isinstance(detail, str):
        detail = translate(detail)
    return JSONResponse(status_code=exc.status_code, content={"detail": detail}, headers=exc.headers)
