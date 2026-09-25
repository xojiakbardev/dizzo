"""Every user-facing message speaks Uzbek, Russian and English: the catalogs
are complete and consistent, every message the code raises is catalogued,
and requests, Telegram messages and the bot come out in the right language."""

import ast
from pathlib import Path
from string import Formatter

import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core import rate_limit
from app.core.i18n import OTHER_LANGUAGES, catalog
from app.models.commerce import Order
from app.models.user import User
from app.services import auth as auth_service
from app.services import telegram_notify
from app.services.orders import STATUS_LABELS
from bot.i18n import chat_language, telegram_language
from tests.conftest import make_admin, register
from tests.test_catalog import ok
from tests.test_reviews import order_for
from tests.test_telegram_link import link

ROOT = Path(__file__).resolve().parents[1]


def placeholders(text: str) -> set[str]:
    return {field for _, field, _, _ in Formatter().parse(text) if field is not None}


def test_every_catalog_entry_has_both_languages_and_the_same_placeholders() -> None:
    problems = []
    for msgid, texts in catalog().items():
        for language in OTHER_LANGUAGES:
            text = texts.get(language, "")
            if not text.strip():
                problems.append(f"{msgid!r}: no {language}")
            elif placeholders(text) != placeholders(msgid):
                problems.append(f"{msgid!r}: {language} has {placeholders(text)}, not {placeholders(msgid)}")
    assert not problems, "\n".join(problems)


# Calls whose first string argument is a message; calls whose last one is
# (commit: a conflict message; not_found/fetch: a noun that becomes
# "<noun> topilmadi"; the others: a noun filled into a message).
MESSAGE_CALLS = {"_", "msg", "translate", "unprocessable", "conflict", "ValueError", "PrintFileError"}
LAST_ARG_CALLS = {"commit", "not_found", "fetch", "to_library", "owned_media"}


def name_of(func: ast.expr) -> str:
    return func.id if isinstance(func, ast.Name) else func.attr if isinstance(func, ast.Attribute) else ""


def source_messages() -> set[str]:
    """The Uzbek messages the code raises or sends, found by reading it."""
    found: set[str] = set()
    files = [p for base in ("app", "bot") for p in (ROOT / base).rglob("*.py") if "locales" not in p.parts]
    for path in files:
        for node in ast.walk(ast.parse(path.read_text(encoding="utf-8"))):
            if not isinstance(node, ast.Call):
                continue
            name = name_of(node.func)
            strings = [a.value for a in node.args if isinstance(a, ast.Constant) and isinstance(a.value, str)]
            first = node.args[0] if node.args else None
            if name in MESSAGE_CALLS and isinstance(first, ast.Constant) and isinstance(first.value, str):
                found.add(first.value)
            elif name in LAST_ARG_CALLS and strings:
                noun = strings[-1]
                found.add(f"{noun} topilmadi" if name in ("not_found", "fetch") else noun)
            elif name == "HTTPException":
                found.update(
                    k.value.value for k in node.keywords
                    if k.arg == "detail" and isinstance(k.value, ast.Constant) and isinstance(k.value.value, str)
                )
        if path.name == "main.py" and path.parent.name == "bot":
            # The sign-in failures are kept in module constants.
            tree = ast.parse(path.read_text(encoding="utf-8"))
            for node in tree.body:
                if isinstance(node, ast.Assign) and name_of(node.targets[0]).startswith("APP_LOGIN_"):
                    found.update(
                        c.value for c in ast.walk(node.value) if isinstance(c, ast.Constant) and " " in str(c.value)
                    )
    return found


def test_every_message_in_the_code_is_catalogued() -> None:
    from app.api.v1 import users

    messages = source_messages() | set(STATUS_LABELS.values()) | {
        rate_limit.TOO_MANY, auth_service.INACTIVE, auth_service.INVALID_REFRESH, users.FORBIDDEN,
    }
    missing = sorted(m for m in messages if m not in catalog())
    assert len(messages) > 150
    assert not missing, "\n".join(missing)


@pytest.mark.asyncio
@pytest.mark.usefixtures("storage")
@pytest.mark.parametrize(
    ("language", "not_found", "bad_email", "wrong_login", "too_big"),
    [
        ("ru", "Товар не найден", "неверный адрес email", "Неверный email или пароль",
         "Размер файла не должен превышать 10 МБ"),
        ("en", "Product not found", "invalid email address", "Incorrect email or password",
         "The file must be no larger than 10 MB"),
        ("uz", "Mahsulot topilmadi", "noto'g'ri email manzil", "Email yoki parol noto'g'ri",
         "Fayl hajmi 10 MB dan oshmasligi kerak"),
    ],
)
async def test_errors_come_in_the_requested_language(
    client: httpx.AsyncClient, language: str, not_found: str, bad_email: str, wrong_login: str, too_big: str,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from dataclasses import replace

    from app.api.v1 import media

    monkeypatch.setitem(media.PURPOSES, "design", replace(media.PURPOSES["design"], max_bytes=10 * media.MB))
    headers = {"Accept-Language": f"{language},en;q=0.5"}

    missing = await client.get("/api/catalog/products/no-such-thing/", headers=headers)
    invalid = await client.post(
        "/api/auth/register/", headers=headers,
        json={"first_name": "Test", "email": "not-an-email", "password": "password123"},
    )
    refused = await client.post(
        "/api/auth/login/", headers=headers, json={"email": "nobody@example.com", "password": "password123"}
    )
    huge = await client.post(
        "/api/media/uploads/", headers=headers,
        json={"purpose": "design", "content_type": "image/png", "size_bytes": 11 * media.MB},
    )

    assert (missing.status_code, missing.json()["detail"]) == (404, not_found)
    assert invalid.status_code == 422 and invalid.json()["detail"][0]["msg"] == bad_email
    assert (refused.status_code, refused.json()["detail"]) == (401, wrong_login)
    assert (huge.status_code, huge.json()["detail"]) == (422, too_big)


@pytest.mark.asyncio
@pytest.mark.usefixtures("storage")
async def test_lang_query_wins_over_accept_language(client: httpx.AsyncClient) -> None:
    response = await client.get("/api/catalog/products/nothing/?lang=en", headers={"Accept-Language": "ru"})

    assert response.json()["detail"] == "Product not found"


@pytest.mark.asyncio
@pytest.mark.usefixtures("configure_oauth", "storage")
async def test_telegram_messages_speak_the_recipients_language(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession], sent: list[tuple[int, str]]
) -> None:
    customer = await register(client, "tg-ru@example.com")
    await link(client, 7001)
    order = await order_for(session_factory, customer["id"], "NEW", "TG-RU")
    await client.post("/api/auth/logout/")
    admin = await register(client, "tg-en-admin@example.com")
    await make_admin(session_factory, admin["id"])
    await link(client, 7002)
    async with session_factory() as session:
        (await session.get(User, customer["id"])).language = "ru"
        (await session.get(User, admin["id"])).language = "en"
        await session.commit()

    # The admin works in Uzbek; the customer still hears in Russian.
    ok(await client.post(f"/api/orders/{order}/status", json={"status": "PAID"}, headers={"Accept-Language": "uz"}))
    async with session_factory() as session:
        staff = await telegram_notify.staff_new_order_messages(session, await session.get(Order, order))

    site = "http://localhost:3000"
    assert sent == [(7001, f"📦 <b>Заказ #TG-RU</b>\nСтатус: Оплачен\nПодробнее: {site}/user/orders/TG-RU")]
    assert staff == [(7002, f"🆕 <b>New order #TG-RU</b>\nTotal: 65000.00 UZS\nDetails: {site}/admin/orders/{order}")]


@pytest.mark.asyncio
@pytest.mark.usefixtures("configure_oauth")
async def test_the_bot_learns_the_language_of_the_chats_account(
    client: httpx.AsyncClient, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    bot = {"x-bot-token": "123456:test-token"}
    user = await register(client, "tg-lang@example.com")
    async with session_factory() as session:
        (await session.get(User, user["id"])).language = "en"
        await session.commit()

    unknown = await client.post("/api/auth/telegram/language/", headers=bot, json={"telegram_id": 8001})
    linked = await link(client, 8001)
    known = await client.post("/api/auth/telegram/language/", headers=bot, json={"telegram_id": 8001})
    # A chat the bot meets first gets an account in its Telegram language.
    await client.post("/api/auth/telegram/bot", headers=bot, json={"telegram_id": 8002, "language": "ru"})
    started = await client.post("/api/auth/telegram/language/", headers=bot, json={"telegram_id": 8002})
    forged = await client.post("/api/auth/telegram/language/", json={"telegram_id": 8001})

    assert unknown.json() == {"language": None}
    assert linked["language"] == "en" and known.json() == {"language": "en"}
    assert started.json() == {"language": "ru"}
    assert forged.status_code == 403


def test_the_bot_falls_back_to_telegrams_language() -> None:
    assert [telegram_language(code) for code in ("ru", "en-US", "uz", "de", None)] == ["ru", "en", "uz", "uz", "uz"]
    assert chat_language("en", "ru") == "en"
    assert chat_language(None, "ru") == "ru"
    assert chat_language(None, "kk") == "uz"


@pytest.fixture
def sent(monkeypatch: pytest.MonkeyPatch) -> list[tuple[int, str]]:
    messages: list[tuple[int, str]] = []

    async def fake_send(chat_id: int, text: str) -> None:
        messages.append((chat_id, text))

    monkeypatch.setattr(telegram_notify, "_send_message", fake_send)
    return messages
