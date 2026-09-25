"""Update all variant colors in the database with translations in Uzbek, Russian, and English."""

import asyncio
from sqlalchemy import select
from app.db.session import async_session_factory
from app.models.catalog import VariantColor


COLOR_TRANSLATIONS: dict[str, dict[str, dict[str, str]]] = {
    "oq": {
        "ru": {"name": "Белый"},
        "en": {"name": "White"},
    },
    "qora": {
        "ru": {"name": "Черный"},
        "en": {"name": "Black"},
    },
    "to'q ko'k": {
        "ru": {"name": "Темно-синий"},
        "en": {"name": "Navy Blue"},
    },
    "bardoviy qizil": {
        "ru": {"name": "Бордовый"},
        "en": {"name": "Burgundy"},
    },
    "qizil": {
        "ru": {"name": "Красный"},
        "en": {"name": "Red"},
    },
    "ko'k": {
        "ru": {"name": "Синий"},
        "en": {"name": "Blue"},
    },
    "yashil": {
        "ru": {"name": "Зеленый"},
        "en": {"name": "Green"},
    },
    "pushti": {
        "ru": {"name": "Розовый"},
        "en": {"name": "Pink"},
    },
    "shaffof": {
        "ru": {"name": "Прозрачный"},
        "en": {"name": "Transparent"},
    },
    "kulrang": {
        "ru": {"name": "Серый"},
        "en": {"name": "Gray"},
    },
    "sariq": {
        "ru": {"name": "Желтый"},
        "en": {"name": "Yellow"},
    },
    "to'q kulrang": {
        "ru": {"name": "Темно-серый"},
        "en": {"name": "Dark Gray"},
    },
    "olovrang": {
        "ru": {"name": "Оранжевый"},
        "en": {"name": "Orange"},
    },
    "binafsharang": {
        "ru": {"name": "Фиолетовый"},
        "en": {"name": "Purple"},
    },
    "jigarrang": {
        "ru": {"name": "Коричневый"},
        "en": {"name": "Brown"},
    },
    "bej": {
        "ru": {"name": "Бежевый"},
        "en": {"name": "Beige"},
    },
}


def normalize_name(name: str) -> str:
    return name.strip().lower().replace("‘", "'").replace("`", "'").replace("’", "'")


async def main():
    async with async_session_factory() as session:
        result = await session.execute(select(VariantColor))
        colors = result.scalars().all()
        updated_count = 0

        for color in colors:
            key = normalize_name(color.name)
            if key in COLOR_TRANSLATIONS:
                tr_data = COLOR_TRANSLATIONS[key]
                # Merge existing translations if any
                merged = dict(color.translations or {})
                for lang, texts in tr_data.items():
                    merged[lang] = {**merged.get(lang, {}), **texts}
                color.translations = merged
                updated_count += 1
                print(f"[+] Updated color {color.id} ({color.name}): {color.translations}")
            else:
                print(f"[!] No translation mapping for color {color.id} ({color.name})")

        await session.commit()
        print(f"\nSuccessfully updated translations for {updated_count}/{len(colors)} variant colors!")


if __name__ == "__main__":
    asyncio.run(main())
