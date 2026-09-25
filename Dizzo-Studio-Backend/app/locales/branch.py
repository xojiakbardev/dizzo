"""Branches, their inventory and their staff (app/api/v1/branches.py) and
the gallery moderation replies (app/api/v1/admin_gallery.py)."""

MESSAGES: dict[str, dict[str, str]] = {
    # branches
    "Filial topilmadi": {"ru": "Филиал не найден", "en": "Branch not found"},
    "Tanlangan filial mavjud emas yoki vaqtincha yopiq": {
        "ru": "Выбранный филиал не существует или временно закрыт",
        "en": "The selected branch does not exist or is temporarily closed",
    },
    "Savatdagi ba'zi mahsulotlar tanlangan filialda vaqtincha mavjud emas": {
        "ru": "Некоторые товары из корзины временно недоступны в выбранном филиале",
        "en": "Some items in the cart are temporarily unavailable at the selected branch",
    },
    "Bunday slug'li filial allaqachon mavjud": {
        "ru": "Филиал с таким slug уже существует",
        "en": "A branch with this slug already exists",
    },
    "Faqat superadmin filialni o'chira oladi": {
        "ru": "Удалить филиал может только суперадмин",
        "en": "Only a super admin can delete a branch",
    },
    "Mahsulot mavjudligini o'zgartirish huquqi yo'q": {
        "ru": "Нет прав менять наличие товара",
        "en": "You may not change product availability",
    },
    # branch staff
    "Xodimlarni biriktirish huquqi yo'q": {
        "ru": "Нет прав назначать сотрудников",
        "en": "You may not assign staff",
    },
    "Xodimni o'chirish huquqi yo'q": {
        "ru": "Нет прав удалять сотрудника",
        "en": "You may not remove staff",
    },
    "Xodim ushbu filialda topilmadi": {
        "ru": "Сотрудник в этом филиале не найден",
        "en": "No such worker at this branch",
    },
    "O'zingizga rol biriktira olmaysiz": {
        "ru": "Вы не можете назначить роль самому себе",
        "en": "You can't assign a role to yourself",
    },
    "Bu rolni filial xodimiga berib bo'lmaydi": {
        "ru": "Эту роль нельзя выдать сотруднику филиала",
        "en": "This role can't be granted to a branch worker",
    },
    "Bu foydalanuvchining rolini o'zgartirish huquqi yo'q": {
        "ru": "Нет прав менять роль этого пользователя",
        "en": "You may not change this user's role",
    },
    # gallery moderation
    "Noto'g'ri status. Faqat APPROVED yoki REJECTED bo'lishi mumkin.": {
        "ru": "Неверный статус. Допустимо только APPROVED или REJECTED.",
        "en": "Invalid status. Only APPROVED or REJECTED are allowed.",
    },
}
