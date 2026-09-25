"""Update catalog products, variants, shapes, areas, colors, and categories with translations."""

import asyncio
from sqlalchemy import select
from app.db.session import async_session_factory
from app.models.catalog import (
    PrintArea,
    Product,
    ProductCategory,
    Shape,
    Variant,
    VariantColor,
)


CATALOG_DATA = {
    "krujka": {
        "description": (
            "Kundalik foydalanish va sovg'a uchun mo'ljallangan yuqori sifatli krujkalar. "
            "Issiq va sovuq ichimliklarga to'liq chidamli bo'lib, ofisda yoki uyda shaxsiy kayfiyat bag'ishlaydi. "
            "Maxsus UV va termo texnologiyada tushirilgan tasvirlar yillar davomida o'zining yorqinligini yo'qotmaydi."
        ),
        "translations": {
            "ru": {
                "name": "Кружка",
                "description": (
                    "Качественные кружки для ежедневного использования и памятных подарков. "
                    "Устойчивы к горячим и холодным напиткам, создают уют дома и в офисе. "
                    "Стойкая печать сохраняет первозданную яркость и четкость на долгие годы."
                ),
            },
            "en": {
                "name": "Mug",
                "description": (
                    "High-quality mugs crafted for everyday use and meaningful gifts. "
                    "Fully resilient to hot and cold drinks, adding a personal touch to your home or office. "
                    "Advanced print technology ensures vibrant, durable designs that will not fade over time."
                ),
            },
        },
        "variants": {
            1: {  # Oddiy oq
                "short_description": "Klassik yaltiroq oq keramika — har qanday rangli logotip va fotolar uchun ideal asos.",
                "description": (
                    "Qalin va sifatli keramika material. Bosilgan tasvir matoga singgandek silliq va yorqin chiqadi. "
                    "Idish yuvish mashinasida yuvish mumkin (ehtiyotkorlik rejimida tavsiya etiladi), abraziv gubkalar ishlatilmasin."
                ),
                "specs": [
                    {"label": "Hajmi", "value": "330 ml"},
                    {"label": "Material", "value": "Yaltiroq keramika"},
                    {"label": "Balandligi", "value": "9.5 sm"},
                    {"label": "Diametri", "value": "8.2 sm"},
                ],
                "translations": {
                    "ru": {
                        "name": "Классическая белая",
                        "short_description": "Классическая глянцевая белая керамика — идеальная основа для логотипов и фотографий.",
                        "description": (
                            "Прочная качественная керамика с гладким покрытием. Цвета передаются максимально сочно и контрастно. "
                            "Допускается мытье в посудомоечной машине (в деликатном режиме), избегайте жестких абразивных губок."
                        ),
                        "specs": [
                            {"label": "Объём", "value": "330 мл"},
                            {"label": "Материал", "value": "Глянцевая керамика"},
                            {"label": "Высота", "value": "9.5 см"},
                            {"label": "Диаметр", "value": "8.2 см"},
                        ],
                    },
                    "en": {
                        "name": "Classic White",
                        "short_description": "Classic glossy white ceramic — the ideal canvas for vibrant logos and photos.",
                        "description": (
                            "Sturdy, high-grade ceramic with a smooth gloss finish. Prints look sharp with vivid color saturation. "
                            "Dishwasher safe on gentle cycles; abrasive cleaning pads should be avoided."
                        ),
                        "specs": [
                            {"label": "Volume", "value": "330 ml"},
                            {"label": "Material", "value": "Glossy ceramic"},
                            {"label": "Height", "value": "9.5 cm"},
                            {"label": "Diameter", "value": "8.2 cm"},
                        ],
                    },
                },
            },
            2: {  # Ichi rangli
                "short_description": "Ichki qismi va ushlagichi yorqin rangli keramika krujka.",
                "description": (
                    "Korpus tashqarisi oq bo'lib, dizayningiz rangiga mos ichki rang bilan uyg'unlashadi. "
                    "Korporativ brending yoki do'stlarga esdalik sovg'a uchun juda mos. Tasvirlar uzoq vaqt tiniq saqlanadi."
                ),
                "specs": [
                    {"label": "Hajmi", "value": "330 ml"},
                    {"label": "Material", "value": "Keramika"},
                    {"label": "Balandligi", "value": "9.5 sm"},
                    {"label": "Diametri", "value": "8.2 sm"},
                ],
                "translations": {
                    "ru": {
                        "name": "С цветной ручкой и внутри",
                        "short_description": "Керамическая кружка с яркой цветной ручкой и внутренней поверхностью.",
                        "description": (
                            "Белоснежная внешняя сторона гармонично сочетается с цветным акцентом внутри. "
                            "Отличный выбор для фирменного корпоративного стиля или подарка друзьям."
                        ),
                        "specs": [
                            {"label": "Объём", "value": "330 мл"},
                            {"label": "Материал", "value": "Керамика"},
                            {"label": "Высота", "value": "9.5 см"},
                            {"label": "Диаметр", "value": "8.2 см"},
                        ],
                    },
                    "en": {
                        "name": "Color Inside & Handle",
                        "short_description": "Ceramic mug featuring a colorful interior and matching handle.",
                        "description": (
                            "Crisp white exterior paired with a vibrant inner glaze to accent your design. "
                            "A favorite pick for corporate branding and thoughtful personal gifts."
                        ),
                        "specs": [
                            {"label": "Volume", "value": "330 ml"},
                            {"label": "Material", "value": "Ceramic"},
                            {"label": "Height", "value": "9.5 cm"},
                            {"label": "Diameter", "value": "8.2 cm"},
                        ],
                    },
                },
            },
            3: {  # Xameleon
                "short_description": "Issiq suv quyilganda dizayn ochiladigan sehrli krujka.",
                "description": (
                    "Sovuq holatida tashqi qavati to'q rangda bo'ladi. Ichiga 60°C dan yuqori issiq suyuqlik quyilganda "
                    "termosezgir qavat oqarib, ostidagi dizayn to'liq ko'rinadi. "
                    "Mikroto'lqinli pech va idish yuvish mashinasiga qo'ymaslik, qo'lda yumshoq yuvish qat'iy tavsiya etiladi."
                ),
                "specs": [
                    {"label": "Hajmi", "value": "330 ml"},
                    {"label": "Material", "value": "Termosezgir keramika"},
                    {"label": "Xususiyati", "value": "Issiqda rang o'zgaradi"},
                    {"label": "Balandligi", "value": "9.5 sm"},
                ],
                "translations": {
                    "ru": {
                        "name": "Хамелеон",
                        "short_description": "Магическая кружка, раскрывающая принт при наливании горячей воды.",
                        "description": (
                            "В холодном состоянии кружка темная. При контакте с горячей водой (от 60°C) "
                            "термочувствительный слой становится прозрачным, проявляя изображение. "
                            "Рекомендуется бережная ручная мойка, без микроволновки и посудомоечной машины."
                        ),
                        "specs": [
                            {"label": "Объём", "value": "330 мл"},
                            {"label": "Материал", "value": "Термокерамика"},
                            {"label": "Особенность", "value": "Меняет цвет от тепла"},
                            {"label": "Высота", "value": "9.5 см"},
                        ],
                    },
                    "en": {
                        "name": "Chameleon Magic",
                        "short_description": "Magic heat-sensitive mug that reveals the print when hot liquid is poured.",
                        "description": (
                            "Dark when cool; when filled with hot liquid above 60°C, the thermochromic coating disappears "
                            "to reveal your artwork. Hand-wash only, not microwave or dishwasher safe."
                        ),
                        "specs": [
                            {"label": "Volume", "value": "330 ml"},
                            {"label": "Material", "value": "Heat-sensitive ceramic"},
                            {"label": "Feature", "value": "Color-changing with heat"},
                            {"label": "Height", "value": "9.5 cm"},
                        ],
                    },
                },
            },
            4: {  # Soft-touch matoviy
                "short_description": "Qo'lga yoqimli baxmalsimon (matoviy) qoplamali premium krujka.",
                "description": (
                    "Sirpanmaydigan silliq baxmalsimon yuza. Ham rangli UV-bosma, ham nafis lazer o'ymakorlik (gravirovka) usuliga mos. "
                    "Gravirovkada yuqori qatlam tozalanib, keramikaning o'z tabiiy qatlami ochiladi va o'chmas effekt beradi."
                ),
                "specs": [
                    {"label": "Hajmi", "value": "330 ml"},
                    {"label": "Qoplama", "value": "Soft-touch matoviy"},
                    {"label": "Material", "value": "Keramika"},
                    {"label": "Balandligi", "value": "9.5 sm"},
                ],
                "translations": {
                    "ru": {
                        "name": "Soft-touch матовая",
                        "short_description": "Премиальная керамическая кружка с бархатистым покрытием Soft-touch.",
                        "description": (
                            "Тактильно приятная нескользящая поверхность. Подходит как для сочной УФ-печати, "
                            "так и для лазерной гравировки, открывающей базовый слой керамики с эффектом рельефа."
                        ),
                        "specs": [
                            {"label": "Объём", "value": "330 мл"},
                            {"label": "Покрытие", "value": "Матовое Soft-touch"},
                            {"label": "Материал", "value": "Керамика"},
                            {"label": "Высота", "value": "9.5 см"},
                        ],
                    },
                    "en": {
                        "name": "Soft-touch Matte",
                        "short_description": "Premium ceramic mug with a velvety soft-touch matte finish.",
                        "description": (
                            "Pleasant non-slip tactile feel. Supports both rich UV printing and precision laser engraving, "
                            "revealing the ceramic body for an everlasting engraved finish."
                        ),
                        "specs": [
                            {"label": "Volume", "value": "330 ml"},
                            {"label": "Finish", "value": "Soft-touch matte"},
                            {"label": "Material", "value": "Ceramic"},
                            {"label": "Height", "value": "9.5 cm"},
                        ],
                    },
                },
            },
            5: {  # Matoviy shisha
                "short_description": "Xira (matoviy) yarim shaffof shisha krujka.",
                "description": (
                    "Sovuq kofe, choy yoki desertlar uchun estetik idish. "
                    "Och rangli va minimalist dizaynlar oq fon qavati bilan juda nafis va zamonaviy ko'rinadi."
                ),
                "specs": [
                    {"label": "Hajmi", "value": "330 ml"},
                    {"label": "Material", "value": "Matoviy shisha"},
                    {"label": "Balandligi", "value": "9.5 sm"},
                    {"label": "Diametri", "value": "8.0 sm"},
                ],
                "translations": {
                    "ru": {
                        "name": "Матовое стекло",
                        "short_description": "Полупрозрачная кружка из матового матированного стекла.",
                        "description": (
                            "Эстетичная посуда для айс-кофе, чая и прохладительных напитков. "
                            "Минималистичные и контрастные принты смотрятся на матовой поверхности особенно стильно."
                        ),
                        "specs": [
                            {"label": "Объём", "value": "330 мл"},
                            {"label": "Материал", "value": "Матовое стекло"},
                            {"label": "Высота", "value": "9.5 см"},
                            {"label": "Диаметр", "value": "8.0 см"},
                        ],
                    },
                    "en": {
                        "name": "Frosted Glass",
                        "short_description": "Semi-translucent mug crafted from frosted glass.",
                        "description": (
                            "Sleek and aesthetic drinkware for iced coffee, tea, and refreshments. "
                            "Minimalist artwork and bold contrasts look exceptionally stylish on frosted glass."
                        ),
                        "specs": [
                            {"label": "Volume", "value": "330 ml"},
                            {"label": "Material", "value": "Frosted glass"},
                            {"label": "Height", "value": "9.5 cm"},
                            {"label": "Diameter", "value": "8.0 cm"},
                        ],
                    },
                },
            },
            6: {  # Toza shaffof shisha
                "short_description": "Toza tiniq shisha krujka.",
                "description": (
                    "Ichimlikning rangi va qatlamlari to'liq ko'rinib turadigan klassik shaffof krujka. "
                    "Dizayn tiniq shisha yuzasida alohida ajralib turishi uchun oq asos (underbase) bilan birga bosiladi."
                ),
                "specs": [
                    {"label": "Hajmi", "value": "330 ml"},
                    {"label": "Material", "value": "Shaffof shisha"},
                    {"label": "Balandligi", "value": "9.5 sm"},
                    {"label": "Diametri", "value": "8.0 sm"},
                ],
                "translations": {
                    "ru": {
                        "name": "Прозрачное стекло",
                        "short_description": "Классическая прозрачная стеклянная кружка.",
                        "description": (
                            "Стеклянная кружка, передающая цвет и слоистость напитка. "
                            "Печать выполняется со специальной белой подложкой, сохраняя плотность и читаемость графики."
                        ),
                        "specs": [
                            {"label": "Объём", "value": "330 мл"},
                            {"label": "Материал", "value": "Прозрачное стекло"},
                            {"label": "Высота", "value": "9.5 см"},
                            {"label": "Диаметр", "value": "8.0 см"},
                        ],
                    },
                    "en": {
                        "name": "Clear Glass",
                        "short_description": "Classic transparent clear glass mug.",
                        "description": (
                            "Showcases the natural color and layers of your beverages. "
                            "Artwork is printed with an opaque white underbase to guarantee outstanding vibrancy on glass."
                        ),
                        "specs": [
                            {"label": "Volume", "value": "330 ml"},
                            {"label": "Material", "value": "Clear glass"},
                            {"label": "Height", "value": "9.5 cm"},
                            {"label": "Diameter", "value": "8.0 cm"},
                        ],
                    },
                },
            },
        },
    },
    "soat": {
        "description": (
            "Uy, ofis yoki jamoat joylari interyerini to'ldiruvchi original devor soatlari. "
            "Shaxsiy foto, korporativ logotip yoki badiiy suratlar bilan bezatilgan soat ajoyib esdalik sovg'asidir. "
            "Sokin mexanizmi tinchlik va qulaylikni ta'minlaydi."
        ),
        "translations": {
            "ru": {
                "name": "Настенные часы",
                "description": (
                    "Оригинальные настенные часы для дома, офиса или подарка партнерам. "
                    "Персонализированный циферблат с вашим фото, фирменной символикой или артом. "
                    "Бесшумный плавный кварцевый механизм не нарушит тишину."
                ),
            },
            "en": {
                "name": "Wall Clock",
                "description": (
                    "Distinctive wall clocks designed for homes, corporate offices, and memorable gifts. "
                    "Personalize the dial with photos, brand emblems, or custom illustrations. "
                    "Silent sweeping quartz movement ensures whisper-quiet timekeeping."
                ),
            },
        },
        "variants": {
            7: {  # Dumaloq soat Ø30 sm
                "short_description": "Diametri 30 sm bo'lgan klassik dumaloq devor soati.",
                "description": (
                    "Sokin (tovushsiz) suzuvchi kvarts mexanizmi bilan jihozlangan, yotoqxona va ish xonalarida bezovta qilmaydi. "
                    "Oldi mineral shisha bilan qoplangan, siferblatga bosilgan rasm chang va quyosh nurlaridan himoyalangan. "
                    "1 dona AA batareyasi bilan ishlaydi (komplektga kirmaydi)."
                ),
                "specs": [
                    {"label": "Diametri", "value": "30 sm"},
                    {"label": "Mexanizm", "value": "Sokin (tovushsiz) kvarts"},
                    {"label": "Himoya oyna", "value": "Mineral shisha"},
                    {"label": "Quvvat", "value": "1x AA batareya"},
                ],
                "translations": {
                    "ru": {
                        "name": "Круглые часы Ø30 см",
                        "short_description": "Классические круглые настенные часы диаметром 30 см.",
                        "description": (
                            "Оснащены бесшумным плавным кварцевым механизмом. "
                            "Минеральное стекло защищает циферблат от пыли и выгорания. "
                            "Работают от 1 батарейки типа АА."
                        ),
                        "specs": [
                            {"label": "Диаметр", "value": "30 см"},
                            {"label": "Механизм", "value": "Бесшумный кварцевый"},
                            {"label": "Защитное стекло", "value": "Минеральное"},
                            {"label": "Питание", "value": "1x AA батарейка"},
                        ],
                    },
                    "en": {
                        "name": "Round Clock Ø30 cm",
                        "short_description": "Classic circular wall clock with a 30 cm diameter.",
                        "description": (
                            "Features silent, sweep-movement quartz technology for quiet surroundings. "
                            "Mineral glass front protects the printed dial from dust and UV fading. "
                            "Powered by a single AA battery."
                        ),
                        "specs": [
                            {"label": "Diameter", "value": "30 cm"},
                            {"label": "Movement", "value": "Silent quartz"},
                            {"label": "Front Cover", "value": "Mineral glass"},
                            {"label": "Power", "value": "1x AA battery"},
                        ],
                    },
                },
            },
            8: {  # Kvadrat soat 30×30 sm
                "short_description": "Zamonaviy interyerlar uchun 30×30 sm kvadrat devor soati.",
                "description": (
                    "To'g'ri burchakli zamonaviy dizayn. Geometrik kompozitsiyalar, logotiplar va to'rtburchak formatdagi fotosuratlar uchun juda qulay. "
                    "Mexanizmi sokin va ishonchli. 1 dona AA batareyasi bilan ishlaydi."
                ),
                "specs": [
                    {"label": "O'lchami", "value": "30×30 sm"},
                    {"label": "Mexanizm", "value": "Sokin (tovushsiz) kvarts"},
                    {"label": "Himoya oyna", "value": "Mineral shisha"},
                    {"label": "Quvvat", "value": "1x AA batareya"},
                ],
                "translations": {
                    "ru": {
                        "name": "Квадратные часы 30×30 см",
                        "short_description": "Современные квадратные настенные часы размером 30×30 см.",
                        "description": (
                            "Лаконичная квадратная форма, идеально подходящая для современных интерьеров и строгой графики. "
                            "Бесшумный надежный механизм, защита циферблата минеральным стеклом."
                        ),
                        "specs": [
                            {"label": "Размер", "value": "30×30 см"},
                            {"label": "Механизм", "value": "Бесшумный кварцевый"},
                            {"label": "Защитное стекло", "value": "Минеральное"},
                            {"label": "Питание", "value": "1x AA батарейка"},
                        ],
                    },
                    "en": {
                        "name": "Square Clock 30×30 cm",
                        "short_description": "Contemporary square wall clock measuring 30×30 cm.",
                        "description": (
                            "Clean geometric shape perfectly suited for modern aesthetics and square photography. "
                            "Features silent quartz machinery and a protective mineral glass lens."
                        ),
                        "specs": [
                            {"label": "Dimensions", "value": "30×30 cm"},
                            {"label": "Movement", "value": "Silent quartz"},
                            {"label": "Front Cover", "value": "Mineral glass"},
                            {"label": "Power", "value": "1x AA battery"},
                        ],
                    },
                },
            },
        },
    },
    "futbolka": {
        "description": (
            "Premium sifatli tabiiy paxtadan tikilgan, kundalik kiyish uchun qulay uniseks futbolkalar. "
            "Tanaga yoqimli, nafas oluvchi mato yozning issiq kunlarida ham, qatlamli kiyinishda ham erkinlik baxsh etadi. "
            "To'g'ri bichimi har qanday qomatga yarashadi."
        ),
        "translations": {
            "ru": {
                "name": "Футболка",
                "description": (
                    "Базовая футболка унисекс из премиального натурального хлопка. "
                    "Мягкая, дышащая и приятная к телу ткань дарит максимальный комфорт в течение всего дня. "
                    "Идеальный крой отлично садится на любую фигуру."
                ),
            },
            "en": {
                "name": "T-Shirt",
                "description": (
                    "Premium unisex t-shirt made from natural, breathable combed cotton. "
                    "Soft to the touch and comfortable all day long, whether worn alone or layered. "
                    "Classic regular fit tailored to flatter all body types."
                ),
            },
        },
        "variants": {
            9: {  # Klassik futbolka
                "short_description": "100% taroqlangan (penye) paxtadan tayyorlangan asosiy model.",
                "description": (
                    "Zich va mayin to'qima sababli mato yuvilganda shaklini yo'qotmaydi va cho'zilmaydi. "
                    "Bosilgan tasvir elastik bo'lib, mato cho'zilganda yorilmaydi. "
                    "30°C da teskarisi o'girilib yuvilishi, bosilgan joy ustidan to'g'ridan-to'g'ri dazmol bosmaslik tavsiya etiladi."
                ),
                "specs": [
                    {"label": "Tarkibi", "value": "100% paxta (penye)"},
                    {"label": "Zichligi", "value": "180 g/m²"},
                    {"label": "Bichimi", "value": "Regular fit (uniseks)"},
                    {"label": "Yoqa turi", "value": "Dumaloq (ribana)"},
                ],
                "translations": {
                    "ru": {
                        "name": "Классическая футболка",
                        "short_description": "Базовая модель из 100% гребенного хлопка пенье.",
                        "description": (
                            "Плотное и гладкое полотно отлично держит форму после многочисленных стирок. "
                            "Принт эластичен и устойчив к деформациям. "
                            "Стирка при 30°C наизнанку, гладить только с изнаночной стороны."
                        ),
                        "specs": [
                            {"label": "Состав", "value": "100% хлопок (пенье)"},
                            {"label": "Плотность", "value": "180 г/м²"},
                            {"label": "Фасон", "value": "Regular fit (унисекс)"},
                            {"label": "Ворот", "value": "Круглый (рибана)"},
                        ],
                    },
                    "en": {
                        "name": "Classic T-Shirt",
                        "short_description": "Everyday essential crafted from 100% ring-spun combed cotton.",
                        "description": (
                            "Dense, smooth fabric retains shape and softness after repeated washes. "
                            "The print is flexible and crack-resistant. "
                            "Machine wash inside out at 30°C; do not iron directly over the print."
                        ),
                        "specs": [
                            {"label": "Composition", "value": "100% combed cotton"},
                            {"label": "Weight", "value": "180 g/m²"},
                            {"label": "Fit", "value": "Regular fit (unisex)"},
                            {"label": "Neckline", "value": "Crew neck (ribbed)"},
                        ],
                    },
                },
            },
        },
    },
    "futbolka-uzun-yeng": {
        "description": (
            "Salqin ob-havo va mavsum oralig'i uchun mo'ljallangan qulay longsliv (uzun yengli futbolka). "
            "Elastik yeng manjetlari qo'lda qulay o'tiradi va harakatga xalaqit bermaydi. "
            "Shaxsiy va korporativ kiyim sifatida ajoyib tanlov."
        ),
        "translations": {
            "ru": {
                "name": "Лонгслив (футболка с длинным рукавом)",
                "description": (
                    "Удобный лонгслив из плотного хлопка для прохладной погоды и демисезона. "
                    "Эластичные манжеты на рукавах обеспечивают аккуратную и надежную посадку. "
                    "Отличный вариант для повседневной носки и корпоративного мерча."
                ),
            },
            "en": {
                "name": "Long Sleeve T-Shirt",
                "description": (
                    "Comfortable long-sleeve tee designed for transitional seasons and cool evenings. "
                    "Ribbed cuffs provide a neat, snug wrist fit without restricting movement. "
                    "A great wardrobe staple and team apparel solution."
                ),
            },
        },
        "variants": {
            10: {  # Uzun yengli futbolka
                "short_description": "Zich paxtali, yengli manjetli klassik longsliv.",
                "description": (
                    "Ko'krak va orqa qismiga katta formatli tasvirlar, yozuvlar va ramzlar mukammal tushadi. "
                    "Tabiiy tola sababli terlatmaydi va allergiyaga sabab bo'lmaydi. "
                    "Parvarish: 30°C haroratda teskarisini o'girib yuvish, oqartiruvchi vositalardan foydalanmaslik."
                ),
                "specs": [
                    {"label": "Tarkibi", "value": "100% paxta"},
                    {"label": "Zichligi", "value": "190 g/m²"},
                    {"label": "Yeng turi", "value": "Uzun (manjetli)"},
                    {"label": "Bichimi", "value": "Regular fit"},
                ],
                "translations": {
                    "ru": {
                        "name": "Классический лонгслив",
                        "short_description": "Плотный хлопковый лонгслив с манжетами на рукавах.",
                        "description": (
                            "Прекрасно подходит для нанесения как аккуратных логотипов, так и масштабных принтов. "
                            "Натуральные дышащие волокна обеспечивают комфортный микроклимат тела. "
                            "Стирка при 30°C в деликатном режиме без отбеливателей."
                        ),
                        "specs": [
                            {"label": "Состав", "value": "100% хлопок"},
                            {"label": "Плотность", "value": "190 г/м²"},
                            {"label": "Рукав", "value": "Длинный (с манжетой)"},
                            {"label": "Фасон", "value": "Regular fit"},
                        ],
                    },
                    "en": {
                        "name": "Classic Long Sleeve",
                        "short_description": "Substantial cotton long sleeve shirt with ribbed cuffs.",
                        "description": (
                            "Ideal for bold front, back, or sleeve graphics. "
                            "Breathable natural cotton ensures all-day comfort. "
                            "Care instructions: Wash inside out at 30°C, avoid bleach and direct heat."
                        ),
                        "specs": [
                            {"label": "Composition", "value": "100% cotton"},
                            {"label": "Weight", "value": "190 g/m²"},
                            {"label": "Sleeve", "value": "Long (ribbed cuff)"},
                            {"label": "Fit", "value": "Regular fit"},
                        ],
                    },
                },
            },
        },
    },
    "hudi": {
        "description": (
            "Issiq va qulay kapyushonli hudi (tolstovka). Kuz-qish mavsumi uchun ideal tanlov bo'lib, "
            "old qismidagi kenguru cho'ntak qo'llarni issiq tutadi. "
            "Erkin bichimi harakatlanishda qulaylik va zamonaviy ko'rinish beradi."
        ),
        "translations": {
            "ru": {
                "name": "Худи",
                "description": (
                    "Теплое и уютное худи с капюшоном и вместительным карманом-кенгуру. "
                    "Идеальный выбор для прохладного сезона, путешествий и повседневного городского стиля. "
                    "Свободный силуэт дарит свободу движений и современный образ."
                ),
            },
            "en": {
                "name": "Hoodie",
                "description": (
                    "Warm, cozy hooded sweatshirt featuring a front kangaroo pocket. "
                    "The go-to choice for chillier weather, travel, and effortless streetwear. "
                    "Relaxed silhouette provides both mobility and contemporary style."
                ),
            },
        },
        "variants": {
            11: {  # Kapyushonli hudi
                "short_description": "Uch ipli qalin futerdan tikilgan issiq va keng bichimli hudi.",
                "description": (
                    "Ichki qismi yumshoq momiqli (nachesli yoki halqali futer). Keng kapyushoni shamoldan ishonchli himoya qiladi. "
                    "Bosma tasvir qalin mato ustida yorqin va tekis saqlanadi. "
                    "30°C da nozik rejimda yuvish, print qismini teskarisidan dazmollash tavsiya etiladi."
                ),
                "specs": [
                    {"label": "Tarkibi", "value": "80% paxta, 20% poliester"},
                    {"label": "Zichligi", "value": "320 g/m² (3 ipli futer)"},
                    {"label": "Cho'ntak", "value": "Kenguru cho'ntak"},
                    {"label": "Kapyushon", "value": "Ikki qavatli, bog'ichli"},
                ],
                "translations": {
                    "ru": {
                        "name": "Худи с капюшоном",
                        "short_description": "Плотный теплый худи из трехниточного футера высшего качества.",
                        "description": (
                            "Мягкая внутренняя поверхность сохраняет тепло. Двухслойный глубокий капюшон защищает от ветра. "
                            "Принт на плотном полотне ложится ровно и сохраняет сочность. "
                            "Деликатная стирка при 30°C, гладить с изнаночной стороны."
                        ),
                        "specs": [
                            {"label": "Состав", "value": "80% хлопок, 20% полиэстер"},
                            {"label": "Плотность", "value": "320 г/м² (3-х нитка)"},
                            {"label": "Карман", "value": "Кенгуру"},
                            {"label": "Капюшон", "value": "Двойной, со шнурком"},
                        ],
                    },
                    "en": {
                        "name": "Hooded Sweatshirt",
                        "short_description": "Heavyweight hoodie tailored from premium 3-thread fleece.",
                        "description": (
                            "Soft brushed interior locks in warmth. Double-layered hood shields against wind. "
                            "Prints cure evenly with brilliant definition on heavy fleece fabric. "
                            "Gentle wash at 30°C inside out; iron on reverse."
                        ),
                        "specs": [
                            {"label": "Composition", "value": "80% cotton, 20% polyester"},
                            {"label": "Weight", "value": "320 g/m² (3-thread fleece)"},
                            {"label": "Pocket", "value": "Kangaroo pouch"},
                            {"label": "Hood", "value": "Double-lined with drawstring"},
                        ],
                    },
                },
            },
        },
    },
    "kepka": {
        "description": (
            "Quyoshdan himoyalovchi va shaxsiy uslubni namoyon etuvchi zamonaviy beysbolka va kepkalar. "
            "Sifatli paxta matosi va qulay sozlagichi tufayli boshda yengil va mustahkam o'tiradi."
        ),
        "translations": {
            "ru": {
                "name": "Кепка",
                "description": (
                    "Стильные бейсболки и кепки для защиты от солнца и создания индивидуального образа. "
                    "Плотный дышащий хлопок и регулируемый ремешок обеспечивают комфортную посадку."
                ),
            },
            "en": {
                "name": "Cap",
                "description": (
                    "Modern baseball caps and snapbacks designed for sun protection and custom styling. "
                    "Breathable cotton twill and an adjustable strap deliver an effortless, tailored fit."
                ),
            },
        },
        "variants": {
            12: {  # Oddiy kepka
                "short_description": "Bukilgan (klassik) kozirekli 6 ponali beysbolka.",
                "description": (
                    "Qattiq peshona qismi bosilgan logotip yoki yozuvning doimo tekis va aniq ko'rinishini ta'minlaydi. "
                    "Orqa tarafidagi metall qisqich o'lchamni bosh aylanasiga moslab olish imkonini beradi. Shamollatish ko'zchalari mavjud."
                ),
                "specs": [
                    {"label": "Tarkibi", "value": "100% paxta (twill)"},
                    {"label": "Peshona", "value": "Qattiqlashtirilgan 6 ponali"},
                    {"label": "Qisqich", "value": "Metall sozlagich"},
                    {"label": "O'lchami", "value": "Universal (56-60 sm)"},
                ],
                "translations": {
                    "ru": {
                        "name": "Классическая бейсболка",
                        "short_description": "Шестиклинная бейсболка с изогнутым козырьком.",
                        "description": (
                            "Жесткий лобовой щиток держит правильную геометрию и делает принт четким. "
                            "Металлическая застежка регулирует обхват головы. Вентиляционные люверсы обеспечивают комфорт."
                        ),
                        "specs": [
                            {"label": "Состав", "value": "100% хлопок (твил)"},
                            {"label": "Конструкция", "value": "6-клинная с жестким лобом"},
                            {"label": "Застежка", "value": "Металлическая пряжка"},
                            {"label": "Размер", "value": "Универсальный (56-60 см)"},
                        ],
                    },
                    "en": {
                        "name": "Classic Baseball Cap",
                        "short_description": "6-panel baseball cap with a pre-curved visor.",
                        "description": (
                            "Structured front panels maintain crown shape and keep printed graphics crisp. "
                            "Metal buckle back strap adjusts for head size. Embroidered eyelets enhance airflow."
                        ),
                        "specs": [
                            {"label": "Composition", "value": "100% cotton twill"},
                            {"label": "Structure", "value": "6-panel structured"},
                            {"label": "Closure", "value": "Metal slide buckle"},
                            {"label": "Size", "value": "Universal (56-60 cm)"},
                        ],
                    },
                },
            },
            13: {  # Tekis kozirekli
                "short_description": "Urban va street-style yo'nalishidagi snekbek (tekis kozirekli kepka).",
                "description": (
                    "Baland peshona profili va qat'iy tekis kozirek. "
                    "Yoshlar, musiqachilar va zamonaviy brendlar atributikasi uchun eng ommabop model. "
                    "Plastik tugmali sozlagich bilan jihozlangan."
                ),
                "specs": [
                    {"label": "Tarkibi", "value": "100% paxta"},
                    {"label": "Kozirek", "value": "Tekis (snapback)"},
                    {"label": "Qisqich", "value": "Plastik sozlagich"},
                    {"label": "O'lchami", "value": "Universal (56-60 sm)"},
                ],
                "translations": {
                    "ru": {
                        "name": "Кепка с прямым козырьком",
                        "short_description": "Снэпбек с прямым козырьком в уличном стиле.",
                        "description": (
                            "Высокая посадка и строгий плоский козырек. Популярный выбор для уличной моды и клубного мерча. "
                            "Пластиковый регулируемый фиксатор на затылке."
                        ),
                        "specs": [
                            {"label": "Состав", "value": "100% хлопок"},
                            {"label": "Козырек", "value": "Прямой (снэпбек)"},
                            {"label": "Застежка", "value": "Пластиковый ремешок"},
                            {"label": "Размер", "value": "Универсальный (56-60 см)"},
                        ],
                    },
                    "en": {
                        "name": "Flat Peak Snapback",
                        "short_description": "Streetwear snapback cap with a signature flat brim.",
                        "description": (
                            "High crown profile paired with a flat visor. A staple for urban lifestyle brands and artist merchandise. "
                            "Equipped with classic plastic snap adjustment."
                        ),
                        "specs": [
                            {"label": "Composition", "value": "100% cotton"},
                            {"label": "Visor", "value": "Flat (snapback)"},
                            {"label": "Closure", "value": "Plastic snap strap"},
                            {"label": "Size", "value": "Universal (56-60 cm)"},
                        ],
                    },
                },
            },
        },
    },
    "vizitka": {
        "description": (
            "Biznes va shaxsiy tanishuvlar uchun ixcham va yuqori sifatli tashrif qog'ozlari (vizitkalar). "
            "Birinchi taassurotni mustahkamlash va aloqalarni saqlash uchun qulay vosita."
        ),
        "translations": {
            "ru": {
                "name": "Визитка",
                "description": (
                    "Компактные и качественные визитные карточки для деловых и личных контактов. "
                    "Безупречный инструмент для создания первого впечатления и презентации бренда."
                ),
            },
            "en": {
                "name": "Business Card",
                "description": (
                    "Compact, professional business cards designed for corporate and personal introductions. "
                    "Make a lasting first impression and keep connections within easy reach."
                ),
            },
        },
        "variants": {
            14: {  # Oq vizitka
                "short_description": "Qalin bo'rli (melovanniy) oq qog'ozdagi standart vizitkalar.",
                "description": (
                    "Qalinligi 350 g/m² bo'lgan qog'oz qo'lda mustahkam ushlanadi va oson g'ijimlanmaydi. "
                    "Yuqori aniqlikdagi chop etish mayda matnlar, logotiplar va QR-kodlarning juda tiniq va o'qiluvchan chiqishini ta'minlaydi."
                ),
                "specs": [
                    {"label": "Material", "value": "Bo'rli qog'oz (Melovannaya)"},
                    {"label": "Zichligi", "value": "350 g/m²"},
                    {"label": "Standart o'lcham", "value": "90×50 mm"},
                    {"label": "Burchaklar", "value": "To'g'ri burchakli"},
                ],
                "translations": {
                    "ru": {
                        "name": "Белая визитка",
                        "short_description": "Стандартная визитка на плотной мелованной бумаге.",
                        "description": (
                            "Плотная бумага 350 г/м² не мнется в кошельке и выглядит солидно. "
                            "Высокая четкость печати передает мельчайшие детали контактов, логотипов и QR-кодов."
                        ),
                        "specs": [
                            {"label": "Материал", "value": "Мелованная бумага"},
                            {"label": "Плотность", "value": "350 г/м²"},
                            {"label": "Стандартный размер", "value": "90×50 мм"},
                            {"label": "Углы", "value": "Прямые"},
                        ],
                    },
                    "en": {
                        "name": "White Business Card",
                        "short_description": "Classic card printed on premium heavy coated art paper.",
                        "description": (
                            "Heavyweight 350 g/m² cardstock delivers a rigid, solid hand-feel that resists bends. "
                            "Crisp high-resolution print ensures that fine text, brand marks, and QR codes remain sharp and readable."
                        ),
                        "specs": [
                            {"label": "Material", "value": "Coated art paper"},
                            {"label": "Weight", "value": "350 g/m²"},
                            {"label": "Standard Size", "value": "90×50 mm"},
                            {"label": "Corners", "value": "Square corners"},
                        ],
                    },
                },
            },
        },
    },
}


CATEGORY_TRANSLATIONS: dict[str, dict[str, dict[str, str]]] = {
    "idish-tovoq": {
        "ru": {"name": "Посуда"},
        "en": {"name": "Tableware"},
    },
    "uy-buyumlari": {
        "ru": {"name": "Товары для дома"},
        "en": {"name": "Home goods"},
    },
    "kiyimlar": {
        "ru": {"name": "Одежда"},
        "en": {"name": "Apparel"},
    },
    "aksessuarlar": {
        "ru": {"name": "Аксессуары"},
        "en": {"name": "Accessories"},
    },
    "boshqalar": {
        "ru": {"name": "Другое"},
        "en": {"name": "Other"},
    },
}

SHAPE_TRANSLATIONS: dict[str, dict[str, dict[str, str]]] = {
    "oddiy oq krujka 330 ml": {
        "ru": {"name": "Классическая белая кружка 330 мл"},
        "en": {"name": "Classic White Mug 330 ml"},
    },
    "ichi rangli krujka 330 ml": {
        "ru": {"name": "Кружка с цветной внутренней частью 330 мл"},
        "en": {"name": "Color Inside Mug 330 ml"},
    },
    "xameleon krujka 330 ml": {
        "ru": {"name": "Кружка-хамелеон 330 мл"},
        "en": {"name": "Color Changing Mug 330 ml"},
    },
    "soft-touch matoviy krujka 350 ml": {
        "ru": {"name": "Матовая кружка Soft-Touch 350 мл"},
        "en": {"name": "Soft-Touch Matte Mug 350 ml"},
    },
    "matoviy shisha krujka 330 ml": {
        "ru": {"name": "Матовая стеклянная кружка 330 мл"},
        "en": {"name": "Frosted Glass Mug 330 ml"},
    },
    "toza shaffof shisha krujka 330 ml": {
        "ru": {"name": "Прозрачная стеклянная кружка 330 мл"},
        "en": {"name": "Clear Glass Mug 330 ml"},
    },
    "devor soati ø300": {
        "ru": {"name": "Настенные часы Ø300"},
        "en": {"name": "Wall Clock Ø300"},
    },
    "devor soati 30×30 (kvadrat)": {
        "ru": {"name": "Квадратные настенные часы 30×30"},
        "en": {"name": "Square Wall Clock 30×30"},
    },
    "devor soati 30x30 (kvadrat)": {
        "ru": {"name": "Квадратные настенные часы 30×30"},
        "en": {"name": "Square Wall Clock 30×30"},
    },
    "futbolka (kalta yeng)": {
        "ru": {"name": "Футболка (короткий рукав)"},
        "en": {"name": "T-Shirt (Short Sleeve)"},
    },
    "futbolka (uzun yeng)": {
        "ru": {"name": "Футболка (длинный рукав)"},
        "en": {"name": "T-Shirt (Long Sleeve)"},
    },
    "hudi": {
        "ru": {"name": "Худи"},
        "en": {"name": "Hoodie"},
    },
    "kepka (oddiy)": {
        "ru": {"name": "Бейсболка (классическая)"},
        "en": {"name": "Baseball Cap (Classic)"},
    },
    "kepka (tekis kozirek)": {
        "ru": {"name": "Кепка с прямым козырьком"},
        "en": {"name": "Flat Peak Snapback"},
    },
    "vizitka 90 x 50 mm": {
        "ru": {"name": "Визитка 90 × 50 мм"},
        "en": {"name": "Business Card 90 × 50 mm"},
    },
    "vizitka 90 × 50 mm": {
        "ru": {"name": "Визитка 90 × 50 мм"},
        "en": {"name": "Business Card 90 × 50 mm"},
    },
}

PRINT_AREA_TRANSLATIONS: dict[str, dict[str, dict[str, str]]] = {
    "atrofi": {
        "ru": {"name": "Круговая поверхность"},
        "en": {"name": "Wrap around"},
    },
    "siferblat": {
        "ru": {"name": "Циферблат"},
        "en": {"name": "Clock face"},
    },
    "old tomon": {
        "ru": {"name": "Передняя сторона"},
        "en": {"name": "Front"},
    },
    "old": {
        "ru": {"name": "Передняя сторона"},
        "en": {"name": "Front"},
    },
    "orqa tomon": {
        "ru": {"name": "Задняя сторона"},
        "en": {"name": "Back"},
    },
    "orqa": {
        "ru": {"name": "Задняя сторона"},
        "en": {"name": "Back"},
    },
}

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


def _norm(text: str) -> str:
    return text.strip().lower().replace("‘", "'").replace("`", "'").replace("’", "'")


async def main():
    async with async_session_factory() as session:
        # 1. Update Products and Variants
        for slug, pdata in CATALOG_DATA.items():
            res = await session.execute(select(Product).where(Product.slug == slug))
            product = res.scalar_one_or_none()
            if not product:
                print(f"[!] Product not found: {slug}")
                continue

            product.description = pdata["description"]
            product.translations = pdata["translations"]
            print(f"[+] Updated product: {product.name} ({slug})")

            for var_id, vdata in pdata["variants"].items():
                vres = await session.execute(select(Variant).where(Variant.id == var_id))
                variant = vres.scalar_one_or_none()
                if not variant:
                    print(f"    [!] Variant not found: {var_id}")
                    continue

                variant.short_description = vdata["short_description"]
                variant.description = vdata["description"]
                variant.specs = vdata["specs"]
                variant.translations = vdata["translations"]
                print(f"    [+] Updated variant: {variant.name} (id={var_id})")

        # 2. Update Categories
        cat_res = await session.execute(select(ProductCategory))
        for cat in cat_res.scalars().all():
            key = _norm(cat.slug)
            if key in CATEGORY_TRANSLATIONS:
                cat.translations = CATEGORY_TRANSLATIONS[key]
                print(f"[+] Updated category: {cat.name} ({cat.slug})")

        # 3. Update Shapes
        shape_res = await session.execute(select(Shape))
        for shape in shape_res.scalars().all():
            key = _norm(shape.name)
            if key in SHAPE_TRANSLATIONS:
                shape.translations = SHAPE_TRANSLATIONS[key]
                print(f"[+] Updated shape: {shape.name} (id={shape.id})")
            else:
                print(f"[!] Shape translation missing for: {shape.name}")

        # 4. Update Print Areas
        area_res = await session.execute(select(PrintArea))
        for area in area_res.scalars().all():
            key = _norm(area.name)
            if key in PRINT_AREA_TRANSLATIONS:
                area.translations = PRINT_AREA_TRANSLATIONS[key]
                print(f"[+] Updated print area: {area.name} (id={area.id})")
            else:
                print(f"[!] Print area translation missing for: {area.name}")

        # 5. Update Variant Colors
        color_res = await session.execute(select(VariantColor))
        for color in color_res.scalars().all():
            key = _norm(color.name)
            if key in COLOR_TRANSLATIONS:
                merged = dict(color.translations or {})
                for lang, texts in COLOR_TRANSLATIONS[key].items():
                    merged[lang] = {**merged.get(lang, {}), **texts}
                color.translations = merged
                print(f"[+] Updated color: {color.name} (id={color.id})")

        await session.commit()
        print("\nAll catalog data (products, variants, categories, shapes, areas, colors) successfully updated!")


if __name__ == "__main__":
    asyncio.run(main())
