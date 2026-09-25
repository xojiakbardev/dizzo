"""The language the bot speaks to a chat: its Dizzo account's when it has
one, else the Telegram app's (ru → ru, en → en, anything else → uz).
Messages are Uzbek in the code and translated from app/locales/bot.py."""

from app.core.i18n import DEFAULT_LANGUAGE, LANGUAGES


def telegram_language(code: str | None) -> str:
    """Telegram's `language_code` ("ru", "en-US", …) as one of ours."""
    code = (code or "").lower()[:2]
    return code if code in ("ru", "en") else DEFAULT_LANGUAGE


def chat_language(account: str | None, code: str | None) -> str:
    return account if account in LANGUAGES else telegram_language(code)
