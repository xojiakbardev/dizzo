"""Request validation, rate limits and the shared error words."""

MESSAGES: dict[str, dict[str, str]] = {
    # request validation (app/core/validation_messages.py)
    "majburiy maydon": {"ru": "обязательное поле", "en": "required field"},
    "{gt} dan katta bo'lishi kerak": {"ru": "должно быть больше {gt}", "en": "must be greater than {gt}"},
    "{ge} yoki undan katta bo'lishi kerak": {"ru": "должно быть не меньше {ge}", "en": "must be {ge} or more"},
    "{lt} dan kichik bo'lishi kerak": {"ru": "должно быть меньше {lt}", "en": "must be less than {lt}"},
    "{le} dan oshmasligi kerak": {"ru": "должно быть не больше {le}", "en": "must be {le} or less"},
    "kamida {min_length} ta belgi bo'lishi kerak": {
        "ru": "минимум {min_length} символов", "en": "must be at least {min_length} characters",
    },
    "{max_length} ta belgidan oshmasligi kerak": {
        "ru": "не более {max_length} символов", "en": "must be at most {max_length} characters",
    },
    "kamida {min_length} ta element kerak": {
        "ru": "нужно минимум {min_length} элементов", "en": "needs at least {min_length} items",
    },
    "{max_length} ta elementdan oshmasligi kerak": {
        "ru": "не более {max_length} элементов", "en": "must have at most {max_length} items",
    },
    "noto'g'ri format": {"ru": "неверный формат", "en": "invalid format"},
    "quyidagilardan biri bo'lishi kerak: {expected}": {
        "ru": "должно быть одним из: {expected}", "en": "must be one of: {expected}",
    },
    "butun son bo'lishi kerak": {"ru": "должно быть целым числом", "en": "must be a whole number"},
    "son bo'lishi kerak": {"ru": "должно быть числом", "en": "must be a number"},
    "verguldan keyin ko'pi bilan {decimal_places} xona": {
        "ru": "не более {decimal_places} знаков после запятой", "en": "at most {decimal_places} decimal places",
    },
    "son juda katta": {"ru": "слишком большое число", "en": "the number is too large"},
    "ha/yo'q qiymati bo'lishi kerak": {"ru": "должно быть да/нет", "en": "must be true or false"},
    "matn bo'lishi kerak": {"ru": "должно быть текстом", "en": "must be text"},
    "ro'yxat bo'lishi kerak": {"ru": "должно быть списком", "en": "must be a list"},
    "obyekt bo'lishi kerak": {"ru": "должно быть объектом", "en": "must be an object"},
    "noma'lum maydon": {"ru": "неизвестное поле", "en": "unknown field"},
    "noto'g'ri JSON": {"ru": "неверный JSON", "en": "invalid JSON"},
    "noto'g'ri email manzil": {"ru": "неверный адрес email", "en": "invalid email address"},
    "noto'g'ri qiymat": {"ru": "неверное значение", "en": "invalid value"},
    # translations of content (app/schemas/i18n.py)
    "tarjimada noma'lum til: {language}": {
        "ru": "неизвестный язык перевода: {language}", "en": "unknown translation language: {language}",
    },
    "tarjimada noma'lum maydon: {field}": {
        "ru": "неизвестное поле перевода: {field}", "en": "unknown translation field: {field}",
    },
    # settings
    "Faqat superadmin sozlamalarni o'zgartira oladi": {
        "ru": "Только суперадминистратор может изменять настройки",
        "en": "Only a superadmin can change settings",
    },
    "Sozlama kaliti bo'sh bo'lishi mumkin emas": {
        "ru": "Ключ настройки не может быть пустым",
        "en": "Setting key cannot be empty",
    },
    "Sozlama topilmadi": {
        "ru": "Настройка не найдена",
        "en": "Setting not found",
    },
    "Faqat superadmin sozlamalarni o'chira oladi": {
        "ru": "Только суперадминистратор может удалять настройки",
        "en": "Only a superadmin can delete settings",
    },
    # generic
    "Ruxsat yo'q": {"ru": "Нет доступа", "en": "Access denied"},
    "Juda ko'p urinish. Birozdan keyin qayta urinib ko'ring.": {
        "ru": "Слишком много попыток. Попробуйте чуть позже.",
        "en": "Too many attempts. Please try again a bit later.",
    },
    "Ichki xatolik yuz berdi": {"ru": "Произошла внутренняя ошибка", "en": "An internal error occurred"},
}
