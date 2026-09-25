"""Designs, the cart, checkout and orders: the Studio's rules, print files
and order statuses."""

MESSAGES: dict[str, dict[str, str]] = {
    # order statuses (app/services/orders.py STATUS_LABELS)
    "Yangi": {"ru": "Новый", "en": "New"},
    "To'lov kutilmoqda": {"ru": "Ожидает оплаты", "en": "Awaiting payment"},
    "To'langan": {"ru": "Оплачен", "en": "Paid"},
    "Moderatsiya qilindi": {"ru": "Прошло модерацию", "en": "Moderated"},
    "Ishlab chiqarishga tayyor": {"ru": "Готов к производству", "en": "Ready for production"},
    "Ishlab chiqarilmoqda": {"ru": "В производстве", "en": "In production"},
    "Sifat nazorati": {"ru": "Контроль качества", "en": "Quality check"},
    "Olib ketishga tayyor": {"ru": "Готов к самовывозу", "en": "Ready for pickup"},
    "Yetkazishga tayyor": {"ru": "Готов к доставке", "en": "Ready for delivery"},
    "Yakunlangan": {"ru": "Выполнен", "en": "Completed"},
    "Bekor qilingan": {"ru": "Отменён", "en": "Cancelled"},
    "Moderatsiyadan o'tmadi": {"ru": "Не прошло модерацию", "en": "Did not pass moderation"},
    # orders
    "Buyurtma topilmadi": {"ru": "Заказ не найден", "en": "Order not found"},
    "Buyurtma allaqachon to'langan": {"ru": "Заказ уже оплачен", "en": "The order is already paid"},
    "Buyurtma bekor qilingan": {"ru": "Заказ отменён", "en": "The order is cancelled"},
    "Buyurtma qatori topilmadi": {"ru": "Позиция заказа не найдена", "en": "Order line not found"},
    'Buyurtmani "{current}" holatidan "{new}" holatiga o\'tkazib bo\'lmaydi': {
        "ru": "Заказ нельзя перевести из статуса «{current}» в статус «{new}»",
        "en": "The order can't be moved from “{current}” to “{new}”",
    },
    "Buyurtmani faqat u yangi (tasdiqlanmagan) paytda bekor qilish mumkin": {
        "ru": "Заказ можно отменить, только пока он новый (ещё не подтверждён)",
        "en": "An order can only be cancelled while it's new (not yet confirmed)",
    },
    # cart and checkout
    "Bu variant yoki rang hozir sotuvda emas": {
        "ru": "Этого варианта или цвета сейчас нет в продаже",
        "en": "This variant or colour isn't on sale right now",
    },
    "Dizayn topilmadi": {"ru": "Дизайн не найден", "en": "Design not found"},
    "Narx bosma fayllar bo'yicha qayta hisoblandi: {price} so'm": {
        "ru": "Цена пересчитана по файлам для печати: {price} сум",
        "en": "The price was recalculated from the print files: {price} UZS",
    },
    "Savatdagi mahsulot topilmadi": {"ru": "Товар в корзине не найден", "en": "Cart item not found"},
    "Savat bo'sh": {"ru": "Корзина пуста", "en": "Your cart is empty"},
    "Sotuvda yo'q: {names}. Savatdan olib tashlang.": {
        "ru": "Нет в продаже: {names}. Удалите из корзины.",
        "en": "No longer available: {names}. Please remove them from your cart.",
    },
    "Savatdagi narxlar yangilandi. Tekshirib, qayta tasdiqlang.": {
        "ru": "Цены в корзине обновились. Проверьте их и подтвердите заказ ещё раз.",
        "en": "Prices in your cart have been updated. Please review them and confirm again.",
    },
    "Buyurtma summasi 0 so'm bo'lishi mumkin emas. Savatni tekshiring yoki biz bilan bog'laning.": {
        "ru": "Сумма заказа не может быть 0 сум. Проверьте корзину или свяжитесь с нами.",
        "en": "The order total can't be 0 UZS. Please check your cart or contact us.",
    },
    # Studio designs (app/api/v1/studio.py)
    "Tanlangan variant yoki rang hozir sotuvda emas": {
        "ru": "Выбранного варианта или цвета сейчас нет в продаже",
        "en": "The selected variant or colour isn't on sale right now",
    },
    "Dizayn boshqa mahsulotga tegishli; yangi dizayn boshlang": {
        "ru": "Дизайн относится к другому товару — начните новый дизайн",
        "en": "This design is for another product — please start a new design",
    },
    "Dizayn boshqa oynada o'zgartirilgan (versiya {version}). Oxirgi holati yuklanadi.": {
        "ru": "Дизайн изменён в другом окне (версия {version}). Загрузим его последнюю версию.",
        "en": "The design was changed in another window (version {version}). Its latest version will be loaded.",
    },
    # cart packages (app/services/packages.py)
    "Bosma fayl": {"ru": "Файл для печати", "en": "Print file"},
    "Kadr": {"ru": "Кадр", "en": "Mockup frame"},
    "{what} topilmadi yoki sizga tegishli emas: {media_id}": {
        "ru": "{what}: не найдено или принадлежит не вам ({media_id})",
        "en": "{what} not found or it doesn't belong to you: {media_id}",
    },
    "Bu rang tanlangan variant uchun emas": {
        "ru": "Этот цвет не относится к выбранному варианту",
        "en": "This colour isn't for the selected variant",
    },
    "Bir hudud va usul uchun bitta bosma fayl bo'ladi": {
        "ru": "Для одной области и способа нанесения нужен один файл для печати",
        "en": "Each area and print method takes exactly one print file",
    },
    "Bosma fayllar dizaynga mos emas (yetishmaydi: {missing}, ortiqcha: {extra})": {
        "ru": "Файлы для печати не соответствуют дизайну (не хватает: {missing}, лишние: {extra})",
        "en": "The print files don't match the design (missing: {missing}, extra: {extra})",
    },
    # design rules (app/services/design_rules.py); a layer's name starts a sentence
    "“{text}” matni": {"ru": "Текст «{text}»", "en": "The text “{text}”"},
    "shakl": {"ru": "Фигура", "en": "The shape"},
    "ikonka": {"ru": "Иконка", "en": "The icon"},
    "stiker": {"ru": "Стикер", "en": "The sticker"},
    "soat raqamlari": {"ru": "Цифры циферблата", "en": "The clock numerals"},
    "rasm": {"ru": "Изображение", "en": "The image"},
    "Tasma: “{area}” hududi bu variantda yo'q": {
        "ru": "Полоса: области «{area}» нет у этого варианта",
        "en": "Strip: this variant has no “{area}” area",
    },
    "Tasma: “{area}” hududida bu usulning tasmasi yo'q ({method})": {
        "ru": "Полоса: в области «{area}» у этого способа нет полосы ({method})",
        "en": "Strip: the “{area}” area has no strip for this method ({method})",
    },
    "Tasma “{area}” hududidagi bosma zonasidan chiqib ketgan": {
        "ru": "Полоса выходит за зону печати в области «{area}»",
        "en": "The strip goes outside the print zone of “{area}”",
    },
    "“{source}” va “{target}” bu variantda sinxronlanmaydi: o'lchamlari farq qiladi": {
        "ru": "«{source}» и «{target}» нельзя синхронизировать у этого варианта: у них разные размеры",
        "en": "“{source}” and “{target}” can't be synced on this variant: their sizes differ",
    },
    "“{target}” “{source}” bilan sinxron, unda alohida qatlam bo'lmaydi": {
        "ru": "«{target}» синхронизирована с «{source}», отдельных слоёв в ней быть не может",
        "en": "“{target}” is synced with “{source}”, so it can't have layers of its own",
    },
    "Dizayn bo'sh: kamida bitta rasm, matn yoki shakl joylashtiring": {
        "ru": "Дизайн пуст: добавьте хотя бы одно изображение, текст или фигуру",
        "en": "The design is empty: add at least one image, text or shape",
    },
    "Butun dizayn bitta usulda bosiladi: rangli bosma yoki lazer o'yma": {
        "ru": "Весь дизайн наносится одним способом: цветная печать или лазерная гравировка",
        "en": "A design uses a single print method: colour print or laser engraving",
    },
    "{layer}: “{area}” hududi bu variantda yo'q": {
        "ru": "{layer}: области «{area}» нет у этого варианта",
        "en": "{layer}: this variant has no “{area}” area",
    },
    "{layer}: “{area}” hududida bu usul yo'q ({method})": {
        "ru": "{layer}: в области «{area}» нет этого способа нанесения ({method})",
        "en": "{layer}: the “{area}” area doesn't offer this print method ({method})",
    },
    "{layer} “{area}” hududidagi bosma zonasidan chiqib ketgan": {
        "ru": "{layer}: выходит за зону печати в области «{area}»",
        "en": "{layer} goes outside the print zone of “{area}”",
    },
    "{layer} eni {mm} mm dan oshmasligi kerak": {
        "ru": "{layer}: ширина не должна превышать {mm} мм",
        "en": "{layer} must be no wider than {mm} mm",
    },
    "{layer} bo'yi {mm} mm dan oshmasligi kerak": {
        "ru": "{layer}: высота не должна превышать {mm} мм",
        "en": "{layer} must be no taller than {mm} mm",
    },
    "{layer}: bu usulda rang bo'lmaydi": {
        "ru": "{layer}: этот способ нанесения не поддерживает цвет",
        "en": "{layer}: this print method doesn't support colour",
    },
    "{layer}: shrift kamida {mm} mm bo'lishi kerak": {
        "ru": "{layer}: размер шрифта должен быть не меньше {mm} мм",
        "en": "{layer}: the font must be at least {mm} mm",
    },
    "{layer}: rasm sifati juda past ({dpi} DPI, kamida 100 DPI bo'lishi kerak)": {
        "ru": "{layer}: качество изображения слишком низкое ({dpi} DPI, требуется не менее 100 DPI)",
        "en": "{layer}: image quality is too low ({dpi} DPI, at least 100 DPI is required)",
    },
    # per-size print scaling (SizeItem.print_scale)
    "{layer}: “{size}” o'lchamida bosma maydoni {width}×{height} mm — dizayn unga sig'maydi": {
        "ru": "{layer}: у размера «{size}» область печати {width}×{height} мм — дизайн в неё не помещается",
        "en": "{layer}: size “{size}” prints {width}×{height} mm — the design doesn't fit in it",
    },
    "tanlangan": {"ru": "выбранный", "en": "the chosen one"},
    "“{area}” hududi bu variantda yo'q": {
        "ru": "Области «{area}» нет у этого варианта", "en": "This variant has no “{area}” area",
    },
    "Sotuvda yo'q": {"ru": "Нет в продаже", "en": "Not on sale"},
    "{product}: {problem} Savatda o'lchamni o'zgartiring yoki dizaynni qayta tahrirlang.": {
        "ru": "{product}: {problem} Измените размер в корзине или отредактируйте дизайн.",
        "en": "{product}: {problem} Change the size in the cart, or edit the design.",
    },
    # design document (app/schemas/design.py)
    "Rasm qatlamida faqat rasm manbasi bo'ladi": {
        "ru": "В слое изображения может быть только изображение",
        "en": "An image layer can only hold an image",
    },
    "Matn qatlamida faqat matn bo'ladi": {
        "ru": "В текстовом слое может быть только текст", "en": "A text layer can only hold text",
    },
    "Grafika qatlamida faqat shakl yoki ikonka bo'ladi": {
        "ru": "В графическом слое может быть только фигура или иконка",
        "en": "A graphic layer can only hold a shape or an icon",
    },
    "Soat raqamlari qatlamida faqat raqamlar bo'ladi": {
        "ru": "В слое циферблата могут быть только цифры",
        "en": "A clock numerals layer can only hold numerals",
    },
    "Qatlam identifikatorlari takrorlanmasin": {
        "ru": "Идентификаторы слоёв не должны повторяться", "en": "Layer IDs must be unique",
    },
    "Har bir hudud faqat bitta hududdan sinxronlanadi": {
        "ru": "Каждая область может синхронизироваться только с одной областью",
        "en": "Each area can be synced from only one other area",
    },
    "Sinxronlangan hudud o'zi manba bo'lolmaydi": {
        "ru": "Синхронизированная область не может сама быть источником",
        "en": "A synced area can't be a source itself",
    },
    "Har bir hudud va usul uchun bitta tasma bo'ladi": {
        "ru": "Для каждой области и способа нанесения может быть только одна полоса",
        "en": "Each area and print method can have only one strip",
    },
    # print files (app/services/print_files.py)
    "Bosma faylni o'qib bo'lmadi": {
        "ru": "Не удалось прочитать файл для печати", "en": "The print file couldn't be read",
    },
    "Bosma fayl PNG bo'lishi kerak": {
        "ru": "Файл для печати должен быть в формате PNG", "en": "The print file must be a PNG",
    },
    "Bosma fayl o'lchami {width}×{height} px, {want_width}×{want_height} px bo'lishi kerak "
    "({width_mm}×{height_mm} mm, {dpi} DPI)": {
        "ru": "Размер файла для печати {width}×{height} px, а должен быть {want_width}×{want_height} px "
        "({width_mm}×{height_mm} мм, {dpi} DPI)",
        "en": "The print file is {width}×{height} px, but it must be {want_width}×{want_height} px "
        "({width_mm}×{height_mm} mm, {dpi} DPI)",
    },
    "Bosma fayl juda katta: {width}×{height} px "
    "({megapixels} MP dan oshmasligi kerak). DPI yoki hudud o'lchamini kamaytiring.": {
        "ru": "Файл для печати слишком большой: {width}×{height} px "
        "(допустимо не более {megapixels} МП). Уменьшите DPI или размер области.",
        "en": "The print file is too large: {width}×{height} px "
        "(the limit is {megapixels} MP). Lower the DPI or the area size.",
    },
    "Bosma faylda zonadan tashqarida bo'yalgan joy bor": {
        "ru": "В файле для печати есть закрашенные места за пределами зоны",
        "en": "The print file has painted pixels outside the zone",
    },
    "Bosma fayldagi dizayn {mm} mm lik tasmadan keng": {
        "ru": "Дизайн в файле для печати шире полосы {mm} мм",
        "en": "The design in the print file is wider than the {mm} mm strip",
    },
    "Bosma fayldagi dizayn {mm} mm lik tasmadan chiqib ketgan": {
        "ru": "Дизайн в файле для печати выходит за полосу {mm} мм",
        "en": "The design in the print file goes outside the {mm} mm strip",
    },
    "Bu usulning bosma fayli faqat bir rangli (qora) bo'lishi kerak": {
        "ru": "Файл для печати этим способом должен быть одноцветным (чёрным)",
        "en": "Print files for this method must be single-colour (black)",
    },
    "Siz faqat o'z filialingiz buyurtmalarini ko'ra olasiz": {
        "ru": "Вы видите только заказы своего филиала",
        "en": "You can only see your own branch's orders",
    },
}
