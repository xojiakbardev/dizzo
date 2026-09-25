import html
import logging
from contextlib import suppress

from aiogram import Bot, Dispatcher, F, Router
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ParseMode
from aiogram.exceptions import TelegramAPIError
from aiogram.filters import CommandObject, CommandStart
from aiogram.types import (
    CallbackQuery,
    InlineKeyboardButton,
    InlineKeyboardMarkup,
    MenuButtonDefault,
    Message,
    User,
)

from app.core.i18n import _
from bot.config import settings
from bot.i18n import chat_language
from bot.loading import loading
from bot.services.api import APIClient

logger = logging.getLogger(__name__)
router = Router()


async def language_of(api: APIClient, user: User | None) -> str:
    """The language to answer this Telegram user in."""
    if user is None:
        return chat_language(None, None)
    return chat_language(await api.language(user.id), user.language_code)


@router.message(CommandStart(deep_link=True))
async def start_with_payload(message: Message, api: APIClient, command: CommandObject) -> None:
    """Handles deep links: account-linking from a profile page
    (`?start=link_<token>`) for Telegram order messages — staff get new
    orders, customers their own orders' status — and the mobile app's
    Telegram sign-in (`?start=login_<token>`)."""
    args = command.args or ""
    if args.startswith("login_"):
        # Never confirmed on /start: a link someone else sent would sign them
        # into this Telegram account. The user has to press "Tasdiqlash".
        token = args[len("login_"):]
        language = await language_of(api, message.from_user)
        buttons = InlineKeyboardMarkup(
            inline_keyboard=[
                [
                    InlineKeyboardButton(
                        text=_("✅ Tasdiqlash", language=language), callback_data=f"{APP_LOGIN_YES}{token}"
                    ),
                    InlineKeyboardButton(
                        text=_("❌ Bekor qilish", language=language), callback_data=f"{APP_LOGIN_NO}{token}"
                    ),
                ]
            ]
        )
        await message.answer(
            _(
                "📱 Dizzo ilovasiga kirish so‘raldi.\n\n"
                "Agar buni o‘zingiz so‘ramagan bo‘lsangiz, tasdiqlamang — aks holda boshqa odam "
                "hisobingizga kirib oladi.",
                language=language,
            ),
            reply_markup=buttons,
        )
        return
    if args.startswith("link_"):
        token = args[len("link_"):]
        language = await language_of(api, message.from_user)
        async with loading(message):
            result = await api.link_telegram(token, message.from_user.id) if message.from_user else {"ok": False}
        if result.get("ok"):
            # From now on the chat speaks the language of the account it joined.
            language = chat_language(result.get("language"), language)
            name = html.escape(result.get("full_name") or "")
            if name:
                hello = _("✅ Ulandi, {name}!", language=language, name=name)
            else:
                hello = _("✅ Ulandi!", language=language)
            if result.get("staff"):
                what = _("Endi yangi buyurtmalar shu yerga yuboriladi.", language=language)
            else:
                what = _("Endi buyurtmalaringiz holati shu yerga yuboriladi.", language=language)
            await message.answer(f"{hello}\n\n{what}")
        else:
            await message.answer(_(
                "❌ Havola muddati o'tgan yoki noto'g'ri. Profil sahifasidan qaytadan urinib ko'ring.",
                language=language,
            ))
        return
    await start(message, api)


# Callback data is capped at 64 bytes by Telegram: a 5-byte prefix plus the
# token (the start payload after "login_", at most 58 chars) always fits.
APP_LOGIN_YES = "al:y:"
APP_LOGIN_NO = "al:n:"
# Uzbek, like every message here: translated when sent.
APP_LOGIN_FAILED = {
    "expired": "⌛ Kirish havolasining muddati o‘tgan. Ilovada qaytadan urinib ko‘ring.",
    "inactive": "❌ Bu hisob faol emas.",
}
APP_LOGIN_INVALID = "❌ Kirish havolasi noto‘g‘ri yoki allaqachon ishlatilgan. Ilovada qaytadan urinib ko‘ring."


@router.callback_query(F.data.startswith(APP_LOGIN_YES) | F.data.startswith(APP_LOGIN_NO))
async def app_login_choice(callback: CallbackQuery, api: APIClient) -> None:
    message = callback.message
    language = await language_of(api, callback.from_user)
    # The prompt went to the private chat of whoever opened the link, whose
    # chat id is their user id: only that user may answer it.
    if not isinstance(message, Message) or callback.from_user.id != message.chat.id:
        await callback.answer(_("Bu so‘rov sizga tegishli emas.", language=language), show_alert=True)
        return
    await callback.answer()
    data = callback.data or ""
    token = data[len(APP_LOGIN_YES):]
    if data.startswith(APP_LOGIN_NO):
        result = await api.cancel_app_login(token)
        text = _("🚫 Kirish bekor qilindi.", language=language)
        if not result.get("ok"):
            text = _(APP_LOGIN_FAILED.get(result.get("reason"), APP_LOGIN_INVALID), language=language)
    else:
        async with loading(message):
            result = await api.confirm_app_login(token, callback.from_user)
        if result.get("ok"):
            language = chat_language(result.get("language"), language)
            name = html.escape(result.get("full_name") or "")
            if name:
                hello = _("✅ Kirish tasdiqlandi, {name}!", language=language, name=name)
            else:
                hello = _("✅ Kirish tasdiqlandi!", language=language)
            text = f"{hello}\n\n{_('Endi Dizzo ilovasiga qaytishingiz mumkin.', language=language)}"
        else:
            text = _(APP_LOGIN_FAILED.get(result.get("reason"), APP_LOGIN_INVALID), language=language)
    with suppress(TelegramAPIError):
        await message.edit_text(text, reply_markup=None)


@router.callback_query(F.data.startswith("gal_appr:") | F.data.startswith("gal_rejc:"))
async def handle_gallery_moderation(callback: CallbackQuery, api: APIClient) -> None:
    data = callback.data or ""
    if not callback.from_user or not callback.message:
        return

    is_approve = data.startswith("gal_appr:")
    action = "approve" if is_approve else "reject"
    prefix = "gal_appr:" if is_approve else "gal_rejc:"
    item_id_str = data[len(prefix):]

    try:
        item_id = int(item_id_str)
    except ValueError:
        await callback.answer("Noto'g'ri so'rov!", show_alert=True)
        return

    result = await api.moderate_gallery(item_id, action, callback.from_user.id)
    if not result.get("ok"):
        error_msg = result.get("message") or "Sizda ushbu amalni bajarish huquqi yo'q!"
        await callback.answer(f"❌ {error_msg}", show_alert=True)
        return

    moderator_name = result.get("moderator_name") or callback.from_user.full_name
    old_text = callback.message.html_text if isinstance(callback.message, Message) else ""
    status_badge = (
        f"\n\n<b>Holati:</b> ✅ <i>Saytga chiqarildi</i> (Tasdiqladi: <b>{moderator_name}</b>)"
        if is_approve
        else f"\n\n<b>Holati:</b> ❌ <i>Rad etildi</i> (Rad etdi: <b>{moderator_name}</b>)"
    )
    new_text = old_text + status_badge

    await callback.answer("Bajarildi!")
    with suppress(TelegramAPIError):
        if isinstance(callback.message, Message):
            await callback.message.edit_text(new_text, reply_markup=None)



@router.message(CommandStart())
async def start(message: Message, api: APIClient) -> None:
    # No web app / mini-app here — this bot only sends order messages.
    if message.from_user:
        await api.upsert_user(message.from_user)
    await message.answer(_(
        "Salom! 👋\n\nBu Dizzo bot — buyurtmalar haqidagi xabarlarni olish uchun dizzo.uz saytidagi "
        "Profil sahifasida Telegram’ni ulang.",
        language=await language_of(api, message.from_user),
    ))


async def main() -> None:
    if not settings.token:
        raise RuntimeError("TELEGRAM_BOT_TOKEN yoki BOT_TOKEN .env’da sozlanmagan")
    logging.basicConfig(level=logging.INFO)
    bot = Bot(settings.token, default=DefaultBotProperties(parse_mode=ParseMode.HTML))
    api = APIClient(settings.bot_api_url, settings.token)
    dp = Dispatcher()
    dp["api"] = api
    dp.include_router(router)
    # Reset the persistent menu button — an earlier deploy set a WebApp
    # button here and Telegram keeps it server-side per bot until something
    # explicitly overwrites it, so just not setting it again isn't enough.
    await bot.set_chat_menu_button(menu_button=MenuButtonDefault())
    try:
        await dp.start_polling(bot)
    finally:
        await api.close()
        await bot.session.close()
