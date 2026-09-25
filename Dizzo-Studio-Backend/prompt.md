# Dizzo backend — qolgan ish

Holat: 2026-09-19. Katalog noldan qayta qurilgan, rasmlar biriktirilgan,
xavfsizlik teshiklari yopilgan. Quyidagilar **hali qilinmagan**.

---

## 1. Oq asos (white underbase) — BAJARILDI (2026-09-19)

Backend: `PublicVariant` da `white_underbase: bool` qo'shilgan va `public_detail` orqali yuborilmoqda.
Frontend: `app/types/catalog.ts` da `PublicVariant.white_underbase` kiritildi, `materials.ts` da shader orqali `white_underbase === false` bo'lganda bo'yoq haqiqiy yuza rangi bilan aralashtirilib chiziladi (`diffuseColor.rgb *= uSurfaceColor`). `studioScene.surfaceColors()` haqiqiy hex rangni saqlaydi va uzatadi. Foydalanuvchiga quyuq fonda oq asossiz xiralashish haqida ogohlantirish ko'rsatiladi.

## 2. Dumaloq zona burchaklari — BAJARILDI (2026-09-19)

- `app/services/design_rules.py` — `printable_cm2` da dumaloq hududlar (`round: true`) uchun bosma maydoni `(pi / 4) * w * h`, burchak radiusi (`corner_radius_mm`) bo'lsa `w * h - (4 - pi) * r^2` formula asosida hisoblanadi.
- `app/services/print_files.py` — `analyse()` da `anchor.get("round")` va `anchor.get("corner_radius_mm")` tekshiriladi: zonadan tashqaridagi burchaklarga siyoh tushgan bo'lsa rad etiladi.
- Frontend `render.ts` (`drawAreaNow`) — `faceOf(area)` orqali dumaloq hududlar `ctx.ellipse`, burchagi qayrilgan hududlar `ctx.roundRect` yordamida qirqiladi (clip), natijada chop etish fayli va sarflangan bo'yoq hisobi burchaklardagi ortiqcha siyohdan xoli bo'ladi.

## 3. Past DPI hech narsani to'xtatmaydi — BAJARILDI (2026-09-19)

- `document_problems` (`app/services/design_rules.py`) — har bir rasm qatlami uchun DPI (`min(px_w / (w_mm / 25.4), px_h / (h_mm / 25.4))`) hisoblanadi va `< 100 DPI` bo'lsa xatolik qaytariladi (savatga qo'shish va checkout to'xtatiladi).
- Frontend `document.ts` — `layerProblems` da `< 100 DPI` qat'iy xatolik sifatida qayd etiladi va dizayn muammolari qatoriga kiritiladi.
- Frontend `StudioLayerProps.vue` — `< 100 DPI` holatida qizil bloklovchi xabar, `100–150 DPI` oralig'ida sariq ogohlantirish ko'rsatiladi. 3 tildagi tarjimalar (uz, ru, en) kiritildi.

## 4. O'lchamga qarab print masshtabi — BAJARILDI (2026-09-19)

Backend: `0029_size_print_scale.py` migratsiyasi va `tests/test_print_scale.py` dagi barcha 12 ta test to'liq ishlaydi.
Frontend: `useStudio.ts` va `output.ts` da `printScaleOf` va `sizeBox` oqimi to'liq ulangan.

## 5. Description'lar — BAJARILDI (2026-09-19)

Barcha 7 ta mahsulot va 14 ta variant uchun `short_description`, `description`,
`specs` va 3 tildagi (uz, ru, en) to'liq tarjimalar kiritildi (`app/scripts/update_catalog_info.py`).
Takrorlanuvchi metodlar, o'lchamlar va ranglar prozada takrorlanmagan.
`specs` parametrlari 3 tilda pozitsiya va uzunlik bo'yicha to'liq sinxronlangan.

## 6. Migratsiyalarni `0001` ga siqish — ENG OXIRIDA

Egasi bilan kelishilgan: hamma ish tugagach 29 ta migratsiyani bitta
boshlang'ich migratsiyaga siqish.

---

## Ma'lum, tuzatilmagan testlar

Bular bu ishdan **oldin** ham yiqilardi, tegilmagan:
`test_account_deletion` (2), `test_auth_hardening` (3),
`test_i18n_messages` (1). Yangi yiqilish qo'shmang.

## Eslatma

- Server: `/opt/dizzo/backend`, `docker compose up -d --build backend`.
  Bitta mashinada **`mivo-*`** nomli boshqa loyiha ham bor — tegmang.
- `UPLOADS_PER_HOUR=120` (ommaviy rasm yuklashda vaqtincha ko'tarilgan edi,
  qaytarilgan).
- Tozalash skripti: `python -m app.scripts.cleanup_media --dry-run`.
