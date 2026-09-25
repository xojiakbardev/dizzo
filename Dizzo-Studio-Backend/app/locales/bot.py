"""The Telegram bot's replies (bot/main.py)."""

MESSAGES: dict[str, dict[str, str]] = {
    "Salom! 👋\n\nBu Dizzo bot — buyurtmalar haqidagi xabarlarni olish uchun dizzo.uz saytidagi "
    "Profil sahifasida Telegram’ni ulang.": {
        "ru": "Здравствуйте! 👋\n\nЭто бот Dizzo. Чтобы получать сообщения о заказах, "
        "подключите Telegram на странице «Профиль» на сайте dizzo.uz.",
        "en": "Hello! 👋\n\nThis is the Dizzo bot. To get updates about your orders, "
        "connect Telegram on the Profile page at dizzo.uz.",
    },
    # linking an account for order messages
    "✅ Ulandi, {name}!": {"ru": "✅ Подключено, {name}!", "en": "✅ Connected, {name}!"},
    "✅ Ulandi!": {"ru": "✅ Подключено!", "en": "✅ Connected!"},
    "Endi yangi buyurtmalar shu yerga yuboriladi.": {
        "ru": "Теперь новые заказы будут приходить сюда.",
        "en": "New orders will now be sent here.",
    },
    "Endi buyurtmalaringiz holati shu yerga yuboriladi.": {
        "ru": "Теперь сюда будут приходить обновления статуса ваших заказов.",
        "en": "Updates on your orders' status will now be sent here.",
    },
    "❌ Havola muddati o'tgan yoki noto'g'ri. Profil sahifasidan qaytadan urinib ko'ring.": {
        "ru": "❌ Ссылка устарела или недействительна. Попробуйте ещё раз со страницы профиля.",
        "en": "❌ This link has expired or is invalid. Please try again from your Profile page.",
    },
    # signing in to the mobile app
    "📱 Dizzo ilovasiga kirish so‘raldi.\n\n"
    "Agar buni o‘zingiz so‘ramagan bo‘lsangiz, tasdiqlamang — aks holda boshqa odam "
    "hisobingizga kirib oladi.": {
        "ru": "📱 Запрошен вход в приложение Dizzo.\n\n"
        "Если это были не вы, не подтверждайте — иначе другой человек получит доступ к вашему аккаунту.",
        "en": "📱 Someone asked to sign in to the Dizzo app.\n\n"
        "If this wasn't you, don't confirm — otherwise someone else will get into your account.",
    },
    "✅ Tasdiqlash": {"ru": "✅ Подтвердить", "en": "✅ Confirm"},
    "❌ Bekor qilish": {"ru": "❌ Отменить", "en": "❌ Cancel"},
    "Bu so‘rov sizga tegishli emas.": {
        "ru": "Этот запрос не для вас.", "en": "This request isn't yours.",
    },
    "🚫 Kirish bekor qilindi.": {"ru": "🚫 Вход отменён.", "en": "🚫 Sign-in cancelled."},
    "✅ Kirish tasdiqlandi, {name}!": {"ru": "✅ Вход подтверждён, {name}!", "en": "✅ Sign-in confirmed, {name}!"},
    "✅ Kirish tasdiqlandi!": {"ru": "✅ Вход подтверждён!", "en": "✅ Sign-in confirmed!"},
    "Endi Dizzo ilovasiga qaytishingiz mumkin.": {
        "ru": "Теперь можно вернуться в приложение Dizzo.",
        "en": "You can now return to the Dizzo app.",
    },
    "⌛ Kirish havolasining muddati o‘tgan. Ilovada qaytadan urinib ko‘ring.": {
        "ru": "⌛ Срок действия ссылки для входа истёк. Попробуйте ещё раз в приложении.",
        "en": "⌛ This sign-in link has expired. Please try again in the app.",
    },
    "❌ Bu hisob faol emas.": {"ru": "❌ Этот аккаунт неактивен.", "en": "❌ This account is inactive."},
    "❌ Kirish havolasi noto‘g‘ri yoki allaqachon ishlatilgan. Ilovada qaytadan urinib ko‘ring.": {
        "ru": "❌ Ссылка для входа недействительна или уже использована. Попробуйте ещё раз в приложении.",
        "en": "❌ This sign-in link is invalid or has already been used. Please try again in the app.",
    },
}
