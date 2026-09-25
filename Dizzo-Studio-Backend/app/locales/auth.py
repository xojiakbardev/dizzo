"""Sign-in, accounts and users (app/api/v1/auth.py, users.py, app/services/auth.py)."""

MESSAGES: dict[str, dict[str, str]] = {
    # registration and login
    "Bu email allaqachon ro'yxatdan o'tgan": {
        "ru": "Этот email уже зарегистрирован",
        "en": "This email is already registered",
    },
    "Email yoki parol noto'g'ri": {
        "ru": "Неверный email или пароль",
        "en": "Incorrect email or password",
    },
    "Bu email bilan hisob allaqachon bor. Email va parol bilan kiring.": {
        "ru": "Аккаунт с этим email уже существует. Войдите по email и паролю.",
        "en": "An account with this email already exists. Please sign in with your email and password.",
    },
    "Bu email allaqachon boshqa hisobda ishlatilgan": {
        "ru": "Этот email уже используется в другом аккаунте",
        "en": "This email is already used by another account",
    },
    # tokens and sessions
    "Autentifikatsiya talab qilinadi": {
        "ru": "Необходимо войти в аккаунт",
        "en": "Please sign in to continue",
    },
    "Refresh token yaroqsiz": {
        "ru": "Токен обновления недействителен",
        "en": "The refresh token is invalid",
    },
    "Hisob faol emas": {
        "ru": "Аккаунт неактивен",
        "en": "This account is inactive",
    },
    # Google and Telegram sign-in
    "Google token yaroqsiz yoki Google OAuth sozlanmagan": {
        "ru": "Токен Google недействителен или вход через Google не настроен",
        "en": "The Google token is invalid or Google sign-in isn't set up",
    },
    "Telegram token yaroqsiz yoki bot sozlanmagan": {
        "ru": "Токен Telegram недействителен или бот не настроен",
        "en": "The Telegram token is invalid or the bot isn't set up",
    },
    "Telegram ma'lumotlari yaroqsiz yoki bot token sozlanmagan": {
        "ru": "Данные Telegram недействительны или токен бота не настроен",
        "en": "The Telegram data is invalid or the bot token isn't set up",
    },
    "Telegram bot sozlanmagan": {
        "ru": "Telegram-бот не настроен",
        "en": "The Telegram bot isn't set up",
    },
    "token va telegram_id kerak": {
        "ru": "Нужны token и telegram_id",
        "en": "token and telegram_id are required",
    },
    "Kirish havolasi muddati o'tgan": {
        "ru": "Срок действия ссылки для входа истёк",
        "en": "The sign-in link has expired",
    },
    # users (admin)
    "Noma'lum rol: {role}": {
        "ru": "Неизвестная роль: {role}",
        "en": "Unknown role: {role}",
    },
    "Foydalanuvchi topilmadi": {
        "ru": "Пользователь не найден",
        "en": "User not found",
    },
    "Administrator hisobini bu yerdan o'chirib bo'lmaydi": {
        "ru": "Аккаунт администратора нельзя удалить здесь",
        "en": "An administrator account can't be deleted here",
    },
    "Sizda yakunlanmagan buyurtma bor. Hisobni u yakunlangach yoki bekor qilingach o'chirish mumkin.": {
        "ru": "У вас есть незавершённый заказ. Аккаунт можно удалить после его завершения или отмены.",
        "en": "You have an order in progress. You can delete the account once it is completed or cancelled.",
    },
    "Faol buyurtmangiz bor. Uni yakunlagach yoki bekor qilgach hisobni o'chira olasiz.": {
        "ru": "У вас есть активный заказ. Аккаунт можно удалить после его завершения или отмены.",
        "en": "You have an active order. You can delete the account once it is completed or cancelled.",
    },
    "Faqat superadmin rollarni o'zgartira oladi va xodimlar yarata oladi": {
        "ru": "Менять роли и создавать сотрудников может только суперадмин",
        "en": "Only a super admin can change roles and create staff",
    },
    "Filialga faqat filial rollarini berish mumkin": {
        "ru": "Филиалу можно назначить только роли филиала",
        "en": "Only branch roles can be assigned when a branch is selected",
    },
    "Filial roli uchun filial tanlash shart": {
        "ru": "Для роли филиала нужно выбрать филиал",
        "en": "A branch is required for a branch role",
    },
    "Filial biriktirilmagan": {
        "ru": "Филиал не назначен",
        "en": "No branch is assigned",
    },
    "Hisobingizda parol allaqachon o'rnatilgan": {
        "ru": "В вашем аккаунте уже установлен пароль",
        "en": "Your account already has a password",
    },
}
