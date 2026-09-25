"""The catalog and its admin: products, shapes, areas, variants, price tiers,
the gallery, templates, tutorials and reviews."""

MESSAGES: dict[str, dict[str, str]] = {
    # "{what} topilmadi" (not_found/fetch), catalogued whole per noun
    "Kategoriya topilmadi": {"ru": "Категория не найдена", "en": "Category not found"},
    "Mahsulot topilmadi": {"ru": "Товар не найден", "en": "Product not found"},
    "Usul topilmadi": {"ru": "Способ нанесения не найден", "en": "Print method not found"},
    "Shakl topilmadi": {"ru": "Форма не найдена", "en": "Shape not found"},
    "Hudud topilmadi": {"ru": "Область печати не найдена", "en": "Print area not found"},
    "Variant topilmadi": {"ru": "Вариант не найден", "en": "Variant not found"},
    "Rang topilmadi": {"ru": "Цвет не найден", "en": "Colour not found"},
    "Galereya elementi topilmadi": {"ru": "Элемент галереи не найден", "en": "Gallery item not found"},
    "Shablon topilmadi": {"ru": "Шаблон не найден", "en": "Template not found"},
    "Video darslik topilmadi": {"ru": "Видеоурок не найден", "en": "Video tutorial not found"},
    # nouns filled into other messages
    "Rasm": {"ru": "Изображение", "en": "Image"},
    "Ko'rinish rasmi": {"ru": "Превью", "en": "Preview image"},
    "O'lchamlar": {"ru": "Размеры", "en": "Dimensions"},
    "Joylashuv": {"ru": "Размещение", "en": "Placement"},
    "Mahsulot": {"ru": "Товар", "en": "Product"},
    # images
    "Bir rasm ikki marta berilgan": {
        "ru": "Одно и то же изображение указано дважды", "en": "The same image is listed twice",
    },
    "Bir rasm ikki marta qo'shilgan": {
        "ru": "Одно и то же изображение добавлено дважды", "en": "The same image was added twice",
    },
    "Rasm topilmadi: {media_id}": {
        "ru": "Изображение не найдено: {media_id}", "en": "Image not found: {media_id}",
    },
    "Rasm katalog uchun yuklanmagan yoki yuklash tugamagan: {media_id}": {
        "ru": "Изображение загружено не для каталога или загрузка не завершена: {media_id}",
        "en": "The image wasn't uploaded for the catalog, or its upload isn't finished: {media_id}",
    },
    "Rasm topilmadi yoki hali yuklanmagan: {media_id}": {
        "ru": "Изображение не найдено или ещё не загружено: {media_id}",
        "en": "Image not found or not uploaded yet: {media_id}",
    },
    "Rasm katalog uchun yuklangan bo'lishi kerak: {media_id}": {
        "ru": "Изображение должно быть загружено для каталога: {media_id}",
        "en": "The image must be uploaded for the catalog: {media_id}",
    },
    "Rasm topilmadi yoki sizga tegishli emas: {media_id}": {
        "ru": "Изображение не найдено или принадлежит не вам: {media_id}",
        "en": "Image not found or it doesn't belong to you: {media_id}",
    },
    "Bitta rang uchun ko'pi bilan {count} ta rasm qo'shish mumkin": {
        "ru": "Для одного цвета можно добавить не более {count} изображений",
        "en": "A colour can have at most {count} gallery images",
    },
    "{what} topilmadi: {media_id}": {
        "ru": "{what}: не найдено ({media_id})", "en": "{what} not found: {media_id}",
    },
    "{what} sizga tegishli emas: {media_id}": {
        "ru": "{what}: принадлежит не вам ({media_id})", "en": "{what} doesn't belong to you: {media_id}",
    },
    # categories and products
    "“{slug}” kategoriyasi yo'q": {
        "ru": "Категории «{slug}» не существует", "en": "There is no “{slug}” category",
    },
    "“{slug}” slug band": {
        "ru": "Slug «{slug}» уже занят", "en": "The slug “{slug}” is already taken",
    },
    "Bu slug band": {"ru": "Этот slug уже занят", "en": "This slug is already taken"},
    "Bu kategoriyada {count} ta mahsulot bor: avval ularni boshqa kategoriyaga o'tkazing": {
        "ru": "В этой категории есть товары ({count}): сначала перенесите их в другую категорию",
        "en": "This category still has {count} product(s): move them to another category first",
    },
    "Mahsulot topilmadi: {id}": {"ru": "Товар не найден: {id}", "en": "Product not found: {id}"},
    "Mahsulot arxivlangan": {"ru": "Товар в архиве", "en": "The product is archived"},
    "Mahsulot “mavjud emas” deb belgilangan": {
        "ru": "Товар отмечен как «нет в наличии»", "en": "The product is marked “unavailable”",
    },
    "Muqova rasmi yo'q (landingda rasmsiz ko'rinadi)": {
        "ru": "Нет обложки (на главной странице товар будет без изображения)",
        "en": "No cover image (the product shows without a picture on the landing page)",
    },
    "Faol variant yo'q": {"ru": "Нет активных вариантов", "en": "No active variants"},
    # variants and colours
    "Variantni saqlab bo'lmadi": {
        "ru": "Не удалось сохранить вариант", "en": "The variant couldn't be saved",
    },
    "Rangni saqlab bo'lmadi": {"ru": "Не удалось сохранить цвет", "en": "The colour couldn't be saved"},
    # 3D models
    "Model fayli topilmadi: {media_id}": {
        "ru": "Файл модели не найден: {media_id}", "en": "Model file not found: {media_id}",
    },
    "Fayl 3D model sifatida yuklanmagan yoki yuklash tugamagan": {
        "ru": "Файл загружен не как 3D-модель или загрузка не завершена",
        "en": "The file wasn't uploaded as a 3D model, or its upload isn't finished",
    },
    "GLB sozlamalari faqat “3D model” turidagi shakllar uchun": {
        "ru": "Настройки GLB доступны только для форм типа «3D-модель»",
        "en": "GLB settings are only for shapes of the “3D model” type",
    },
    "Modelni olib tashlab bo'lmaydi, faqat boshqasiga almashtirish mumkin": {
        "ru": "Модель нельзя удалить, её можно только заменить другой",
        "en": "The model can't be removed, only replaced with another one",
    },
    "Avval GLB modelni yuklang": {"ru": "Сначала загрузите GLB-модель", "en": "Upload the GLB model first"},
    "Masshtab uchun ikki xil nuqta tanlang": {
        "ru": "Для масштаба выберите две разные точки", "en": "Pick two different points for the scale",
    },
    "Masshtab g'ayritabiiy chiqdi: 1 birlik = {value} mm. Nuqtalar va masofani tekshiring": {
        "ru": "Получился необычный масштаб: 1 единица = {value} мм. Проверьте точки и расстояние",
        "en": "The scale looks wrong: 1 unit = {value} mm. Check the points and the distance",
    },
    "3D model (GLB) yuklanmagan": {"ru": "3D-модель (GLB) не загружена", "en": "The 3D model (GLB) isn't uploaded"},
    "Model masshtabi (mm) sozlanmagan": {
        "ru": "Масштаб модели (мм) не настроен", "en": "The model's scale (mm) isn't set",
    },
    # shapes
    "Shakl dizaynlarda ishlatilgan va qulflangan. Nusxa olib tahrirlang.": {
        "ru": "Форма используется в дизайнах и заблокирована. Создайте копию и редактируйте её.",
        "en": "This shape is used in designs and is locked. Duplicate it and edit the copy.",
    },
    "Tayyor shaklni tahrirlash uchun avval uni qoralamaga qaytaring": {
        "ru": "Чтобы изменить готовую форму, сначала верните её в черновики",
        "en": "To edit a finished shape, move it back to drafts first",
    },
    "Shakl arxivlanmagan turlarda ishlatilyapti": {
        "ru": "Форма используется в неархивных вариантах",
        "en": "The shape is used by variants that aren't archived",
    },
    "Shakl tayyor emas: {errors}": {"ru": "Форма не готова: {errors}", "en": "The shape isn't ready: {errors}"},
    "Shakl o'chirilgan": {"ru": "Форма удалена", "en": "The shape has been deleted"},
    "Shakl mijoz dizaynlarida ishlatilgan, uni o'chirib bo'lmaydi": {
        "ru": "Форма используется в дизайнах клиентов, её нельзя удалить",
        "en": "The shape is used in customers' designs and can't be deleted",
    },
    "Bu shakldan variantlar foydalanyapti: avval ularni boshqa shaklga o'tkazing": {
        "ru": "Эту форму используют варианты: сначала переведите их на другую форму",
        "en": "Variants use this shape: move them to another shape first",
    },
    "Shakl boshqa mahsulotga tegishli": {
        "ru": "Форма относится к другому товару", "en": "The shape belongs to another product",
    },
    "Shakl arxivlangan": {"ru": "Форма в архиве", "en": "The shape is archived"},
    "Shakl bir tomonli, orqa tomonda hudud bo'lmaydi": {
        "ru": "Форма односторонняя, на обратной стороне не может быть области печати",
        "en": "The shape is one-sided, so it can't have an area on the back",
    },
    # print areas
    "Juft hudud “{name}”: {problem}": {
        "ru": "Парная область «{name}»: {problem}", "en": "Paired area “{name}”: {problem}",
    },
    "Bu shaklda “{key}” kalitli hudud allaqachon bor": {
        "ru": "У этой формы уже есть область с ключом «{key}»",
        "en": "This shape already has an area with the key “{key}”",
    },
    "{method} zonasi yangi o'lchamga sig'maydi, avval zonani o'zgartiring": {
        "ru": "Зона {method} не помещается в новый размер, сначала измените зону",
        "en": "The {method} zone doesn't fit the new size, change the zone first",
    },
    "Bu shaklda “{key}” kalitli hudud yo'q": {
        "ru": "У этой формы нет области с ключом «{key}»",
        "en": "This shape has no area with the key “{key}”",
    },
    "Hudud o'zi bilan juft bo'lmaydi": {
        "ru": "Область не может быть парой самой себе", "en": "An area can't be paired with itself",
    },
    "Bir hudud ikki marta berilgan": {
        "ru": "Одна и та же область указана дважды", "en": "The same area is listed twice",
    },
    "Bu shaklda bunday hudud yo'q: {ids}": {
        "ru": "У этой формы нет таких областей: {ids}", "en": "This shape has no such areas: {ids}",
    },
    "“{key}” kaliti ikki hududda takrorlangan": {
        "ru": "Ключ «{key}» повторяется в двух областях", "en": "The key “{key}” is used by two areas",
    },
    "“{name}” juft hududi topilmadi yoki unga bog'lanmagan": {
        "ru": "Пара для области «{name}» не найдена или не связана с ней",
        "en": "The pair of “{name}” wasn't found or isn't linked back to it",
    },
    "“{name}” va “{partner}” juftligi bir xil emas": {
        "ru": "Пара «{name}» и «{partner}» настроена по-разному",
        "en": "“{name}” and “{partner}” are paired differently",
    },
    "“{name}” va “{partner}” juft, lekin o'lchami yoki usullari farq qiladi": {
        "ru": "«{name}» и «{partner}» — пара, но их размеры или способы нанесения различаются",
        "en": "“{name}” and “{partner}” are a pair, but their sizes or print methods differ",
    },
    "{method} zonasi hududdan chiqib ketadi ({width} × {height} mm)": {
        "ru": "Зона {method} выходит за пределы области ({width} × {height} мм)",
        "en": "The {method} zone goes outside the area ({width} × {height} mm)",
    },
    "Hududlar kalitlari takrorlanmasin": {
        "ru": "Ключи областей не должны повторяться", "en": "Area keys must be unique",
    },
    "Hudud aylana bo'ylab sig'maydi: {start} + {width} > {arc} mm (bosiladigan yoy)": {
        "ru": "Область не помещается по окружности: {start} + {width} > {arc} мм (печатная дуга)",
        "en": "The area doesn't fit around the body: {start} + {width} > {arc} mm (printable arc)",
    },
    "Hudud balandlikka sig'maydi: {top} + {height} > {limit} mm": {
        "ru": "Область не помещается по высоте: {top} + {height} > {limit} мм",
        "en": "The area doesn't fit the height: {top} + {height} > {limit} mm",
    },
    "Hudud tekislikdan chiqib ketadi ({width} × {height} mm)": {
        "ru": "Область выходит за пределы плоскости ({width} × {height} мм)",
        "en": "The area goes outside the flat surface ({width} × {height} mm)",
    },
    "Hudud diskdan chiqib ketadi (Ø{diameter} mm)": {
        "ru": "Область выходит за пределы диска (Ø{diameter} мм)",
        "en": "The area goes outside the disc (Ø{diameter} mm)",
    },
    "Kamida bitta bosma hududi kerak": {
        "ru": "Нужна хотя бы одна область печати", "en": "At least one print area is needed",
    },
    "“{name}” hududida usul yo'q": {
        "ru": "У области «{name}» нет способов нанесения", "en": "The area “{name}” has no print method",
    },
    "Joylashuv tekshiruvlari faqat 3D model shakllari uchun": {
        "ru": "Проверки размещения бывают только у форм-3D-моделей",
        "en": "Placement checks are only for 3D model shapes",
    },
    "Tekshiruvda bu shaklga tegishli bo'lmagan hudud bor: {ids}": {
        "ru": "В проверке есть области, не относящиеся к этой форме: {ids}",
        "en": "The check includes areas that don't belong to this shape: {ids}",
    },
    "“{name}” modelda joylashtirilmagan": {
        "ru": "Область «{name}» не размещена на модели", "en": "“{name}” isn't placed on the model",
    },
    "“{name}” joylashuvi tekshirilmagan": {
        "ru": "Размещение области «{name}» не проверено", "en": "The placement of “{name}” hasn't been checked",
    },
    "“{name}”: rasmning {coverage} qismi sirtga tushadi, "
    "kamida {minimum} kerak (hudud model chetidan chiqib ketgan)": {
        "ru": "«{name}»: на поверхность попадает {coverage} изображения, "
        "а нужно не меньше {minimum} (область выходит за край модели)",
        "en": "“{name}”: only {coverage} of the image lands on the surface, "
        "at least {minimum} is needed (the area runs off the model's edge)",
    },
    # variants, sizes and sellability
    "“{variant}” variantida o'lcham tanlanmaydi": {
        "ru": "У варианта «{variant}» размер не выбирается", "en": "“{variant}” has no sizes to choose from",
    },
    "“{variant}” uchun o'lchamni tanlang": {
        "ru": "Выберите размер для «{variant}»", "en": "Please choose a size for “{variant}”",
    },
    "“{size}” o'lchami bu variantda yo'q": {
        "ru": "Размера «{size}» нет у этого варианта", "en": "Size “{size}” isn't available for this variant",
    },
    "shakli arxivlangan": {"ru": "форма в архиве", "en": "its shape is archived"},
    "shakli (“{shape}”) hali tayyor emas": {
        "ru": "форма («{shape}») ещё не готова", "en": "its shape (“{shape}”) isn't ready yet",
    },
    "shaklda bu usul(lar) uchun hudud yo'q: {methods}": {
        "ru": "у формы нет областей для способов: {methods}",
        "en": "the shape has no area for these method(s): {methods}",
    },
    "mavjud rang yo'q": {"ru": "нет доступных цветов", "en": "no colours available"},
    "mavjud o'lcham yo'q": {"ru": "нет доступных размеров", "en": "no sizes available"},
    "narx pog'onalari yo'q: {methods}": {
        "ru": "нет ценовых ступеней: {methods}", "en": "no price tiers for: {methods}",
    },
    "Variant yoki rang topilmadi": {"ru": "Вариант или цвет не найден", "en": "Variant or colour not found"},
    "Bu variant hozir sotuvda emas": {
        "ru": "Этого варианта сейчас нет в продаже", "en": "This variant isn't on sale right now",
    },
    "Bu rang tanlangan variant uchun mavjud emas": {
        "ru": "Этот цвет недоступен для выбранного варианта",
        "en": "This colour isn't available for the selected variant",
    },
    "“{variant}” variantida bu usul yo'q: {method}": {
        "ru": "У варианта «{variant}» нет такого способа нанесения: {method}",
        "en": "“{variant}” doesn't offer this print method: {method}",
    },
    # price tiers
    "Birinchi pog'ona 0 cm² dan boshlanishi kerak": {
        "ru": "Первая ступень должна начинаться с 0 см²", "en": "The first tier must start at 0 cm²",
    },
    "Faqat oxirgi pog'ona cheksiz bo'lishi mumkin": {
        "ru": "Без верхней границы может быть только последняя ступень",
        "en": "Only the last tier can be open-ended",
    },
    "Oxirgi pog'ona cheksiz bo'lishi kerak (max_cm2 = null)": {
        "ru": "Последняя ступень должна быть без верхней границы (max_cm2 = null)",
        "en": "The last tier must be open-ended (max_cm2 = null)",
    },
    "{low}–{high} cm²: yuqori chegara pastkidan katta bo'lishi kerak": {
        "ru": "{low}–{high} см²: верхняя граница должна быть больше нижней",
        "en": "{low}–{high} cm²: the upper bound must be greater than the lower one",
    },
    "Pog'onalar orasida bo'shliq yoki kesishish bor: {end} dan keyingi pog'ona {start} dan boshlanyapti": {
        "ru": "Между ступенями есть разрыв или пересечение: после {end} следующая ступень начинается с {start}",
        "en": "The tiers have a gap or an overlap: after {end} the next tier starts at {start}",
    },
    # catalog schemas (app/schemas/catalog.py)
    "{what} nol uzunlikdagi vektor bo'lmasligi kerak": {
        "ru": "{what} не может быть вектором нулевой длины", "en": "{what} can't be a zero-length vector",
    },
    "Yuqori yo'nalish (up) normalga parallel bo'lmasligi kerak": {
        "ru": "Направление вверх (up) не должно быть параллельно нормали",
        "en": "The up direction (up) must not be parallel to the normal",
    },
    "Kamera nuqtasi va qarash nuqtasi bir xil bo'lmasligi kerak": {
        "ru": "Точка камеры и точка взгляда не должны совпадать",
        "en": "The camera position and the look-at point must differ",
    },
    "O'yishda rang bo'lmaydi: colors_allowed false bo'lishi kerak": {
        "ru": "При гравировке цвета не бывает: colors_allowed должно быть false",
        "en": "Engraving has no colour: colors_allowed must be false",
    },
    "O'yish uchun minimal shrift o'lchami (min_font_mm) kiritilishi shart": {
        "ru": "Для гравировки нужно указать минимальный размер шрифта (min_font_mm)",
        "en": "Engraving needs a minimum font size (min_font_mm)",
    },
    "max_width_mm zona enidan katta bo'lmasligi kerak": {
        "ru": "max_width_mm не может быть больше ширины зоны",
        "en": "max_width_mm can't be larger than the zone's width",
    },
    "max_height_mm zona bo'yidan katta bo'lmasligi kerak": {
        "ru": "max_height_mm не может быть больше высоты зоны",
        "en": "max_height_mm can't be larger than the zone's height",
    },
    "strip_width_mm zona enidan katta bo'lmasligi kerak": {
        "ru": "strip_width_mm не может быть больше ширины зоны",
        "en": "strip_width_mm can't be larger than the zone's width",
    },
    "Har bir usul hududda bir marta bo'ladi": {
        "ru": "Каждый способ нанесения указывается в области один раз",
        "en": "Each print method appears only once per area",
    },
    "O'lcham nomi bo'sh bo'lmasin": {"ru": "Название размера не может быть пустым", "en": "A size needs a name"},
    "O'lcham nomlari takrorlanmasin": {
        "ru": "Названия размеров не должны повторяться", "en": "Size names must be unique",
    },
    "Usullar takrorlanmasin": {
        "ru": "Способы нанесения не должны повторяться", "en": "Print methods must not repeat",
    },
    # gallery showcase (app/api/v1/admin_gallery.py, gallery.py)
    "1 tadan {count} tagacha rasm tanlang": {
        "ru": "Выберите от 1 до {count} изображений", "en": "Choose between 1 and {count} images",
    },
    "Ro'yxatda bir element ikki marta berilgan": {
        "ru": "Один и тот же элемент указан в списке дважды", "en": "The same item is listed twice",
    },
    "Galereya elementi topilmadi: {id}": {
        "ru": "Элемент галереи не найден: {id}", "en": "Gallery item not found: {id}",
    },
    "Galereyada bunday ish yo‘q": {
        "ru": "Такой работы в галерее нет", "en": "This piece isn't in the gallery",
    },
    # templates (app/api/v1/admin_templates.py)
    "Galereya rasmi topilmadi: {media_id}": {
        "ru": "Изображение для галереи не найдено: {media_id}", "en": "Gallery image not found: {media_id}",
    },
    "Rang bu dizayn variantlariga tegishli emas": {
        "ru": "Цвет не относится к вариантам этого дизайна",
        "en": "The colour doesn't belong to this design's variants",
    },
    "Variant topilmadi yoki bu mahsulotga tegishli emas: {id}": {
        "ru": "Вариант не найден или не относится к этому товару: {id}",
        "en": "Variant not found or it doesn't belong to this product: {id}",
    },
    "Shablonda joylashtirilmagan qatlam bo'lmasin: ularni joylang yoki o'chiring": {
        "ru": "В шаблоне не должно быть неразмещённых слоёв: разместите или удалите их",
        "en": "A template can't have unplaced layers: place or delete them",
    },
    "“{variant}” variantida: {problem}": {
        "ru": "В варианте «{variant}»: {problem}", "en": "On “{variant}”: {problem}",
    },
    # tutorials (app/api/v1/tutorials.py, app/schemas/tutorial.py)
    "Video darslik topilmadi: {id}": {
        "ru": "Видеоурок не найден: {id}", "en": "Video tutorial not found: {id}",
    },
    "Video havolasi http:// yoki https:// bilan boshlanishi kerak": {
        "ru": "Ссылка на видео должна начинаться с http:// или https://",
        "en": "The video link must start with http:// or https://",
    },
    # reviews (app/api/v1/reviews.py)
    "Fikrni buyurtma yakunlangach qoldirish mumkin": {
        "ru": "Отзыв можно оставить после завершения заказа",
        "en": "You can leave a review once your order is completed",
    },
    "Bu buyurtmaga fikr allaqachon qoldirilgan": {
        "ru": "Отзыв на этот заказ уже оставлен", "en": "A review has already been left for this order",
    },
    "Fikr topilmadi": {"ru": "Отзыв не найден", "en": "Review not found"},
}
