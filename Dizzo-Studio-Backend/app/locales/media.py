"""File uploads (app/api/v1/media.py)."""

MESSAGES: dict[str, dict[str, str]] = {
    "Bu fayl turi qabul qilinmaydi": {
        "ru": "Этот тип файла не поддерживается", "en": "This file type isn't accepted",
    },
    "Bu fayl turi qabul qilinmaydi. Ruxsat etilgan: {allowed}": {
        "ru": "Этот тип файла не поддерживается. Разрешены: {allowed}",
        "en": "This file type isn't accepted. Allowed types: {allowed}",
    },
    "Fayl hajmi {size} MB dan oshmasligi kerak": {
        "ru": "Размер файла не должен превышать {size} МБ",
        "en": "The file must be no larger than {size} MB",
    },
    "Juda ko'p yuklash. Bir soatdan keyin urinib ko'ring yoki hisobga kiring.": {
        "ru": "Слишком много загрузок. Попробуйте через час или войдите в аккаунт.",
        "en": "Too many uploads. Please try again in an hour, or sign in.",
    },
    "Juda ko'p fayl yuklandi. Bir soatdan keyin urinib ko'ring.": {
        "ru": "Загружено слишком много файлов. Попробуйте через час.",
        "en": "Too many files uploaded. Please try again in an hour.",
    },
    "Fayl topilmadi": {"ru": "Файл не найден", "en": "File not found"},
    "Fayl hali yuklanmagan": {"ru": "Файл ещё не загружен", "en": "The file hasn't been uploaded yet"},
    "Yuklangan fayl so'ralgan fayl bilan mos kelmadi": {
        "ru": "Загруженный файл не совпадает с заявленным",
        "en": "The uploaded file doesn't match the one requested",
    },
    "Faqat yuklab bo'lingan mehmon fayllarini biriktirish mumkin": {
        "ru": "Привязать можно только полностью загруженные гостевые файлы",
        "en": "Only guest files that have finished uploading can be attached",
    },
    # what the bytes turned out to be
    "Fayl GLB emas": {"ru": "Файл не в формате GLB", "en": "The file isn't a GLB"},
    "Faqat glTF 2.0 qo'llab-quvvatlanadi (fayl versiyasi {version})": {
        "ru": "Поддерживается только glTF 2.0 (версия файла: {version})",
        "en": "Only glTF 2.0 is supported (the file is version {version})",
    },
    "GLB fayl buzilgan: sarlavhadagi uzunlik fayl hajmiga teng emas": {
        "ru": "GLB-файл повреждён: длина в заголовке не совпадает с размером файла",
        "en": "The GLB file is damaged: the length in its header doesn't match the file size",
    },
    "Fayl {format} rasm emas": {
        "ru": "Файл не является изображением {format}", "en": "The file isn't a {format} image",
    },
    "Rasm fayli buzilgan yoki o'qib bo'lmadi": {
        "ru": "Файл изображения повреждён или не читается",
        "en": "The image file is damaged or couldn't be read",
    },
    "Fayl PDF emas": {"ru": "Файл не в формате PDF", "en": "The file isn't a PDF"},
}
