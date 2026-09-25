# Dizzo frontend — qolgan ish

Holat: 2026-09-19. Mahsulot rasmlari, rang kartochkalari va brend coverlar
ishlayapti. Quyidagilar **hali qilinmagan**.

---

## 1. Oq asos (white underbase) — KRITIK

`app/lib/three/materials.ts:47-58` — `printMaterial()` bo'yoqni tanaga
**to'liq qoplab** chizadi. Shuning uchun qora futbolkada och sariq logotip
3D da yorqin va toza ko'rinadi.

Haqiqatda: bo'yoq oq asos ustiga tushishi `Variant.white_underbase` ga
bog'liq. `false` bo'lsa bo'yoq to'g'ridan-to'g'ri qora matoga tushadi va
loyqa yoki ko'rinmas chiqadi. Ya'ni preview yolg'on gapiryapti.

Qilish kerak:
- `PublicVariant` dan `white_underbase` ni o'qish (backend uni yuboradi —
  backend tarafi tayyor) va `app/types/catalog.ts` ga qo'shish.
- `false` bo'lganda bo'yoqni **yuza rangi ustiga aralashtirib** chizish.
  `studioScene.surfaceColors()` har bir hudud uchun haqiqiy yuza rangini
  qaytaradi — shuni ishlating. `true` bo'lsa hozirgi to'liq qoplash qoladi
  (oq asos aynan shuni qiladi).
- Mijozga qisqa izoh: tanlangan rang to'q va oq asos yo'q bo'lsa, och
  bo'yoq xiraroq chiqishini aytib qo'yish. Buyurtmani **bloklamang**.

> Bu ish boshlangan edi va yarmida to'xtatilgan; yarim tahrirlar orqaga
> qaytarilgan, ya'ni noldan boshlash mumkin.

## 2. "Fon" tugmasi — tuzoq, KRITIK

- `app/composables/useStudio.ts:411-415` — `canBackground` `surfaceColors[area] !== color.hex` bo'lganda rost.
- `app/lib/three/studioScene.ts:119` — mato uchun tana `clothColour(hex)` bilan bo'yaladi, `hex` bilan emas.
- `studioScene.ts:492-500` — `clothColour` yorqinlikni `[0.032, 0.62]` ga siqadi.
- `studioScene.ts:199` — `surfaceColors()` o'sha **siqilgan** rangni o'qiydi.

Natijada tanlangan rang bilan modeldagi rang **hech qachon teng chiqmaydi**,
ya'ni "Fon" tugmasi doim yoqiq. Oq futbolkadagi mijoz "yuzani oq qilib
bosish" tugmasini ko'radi, bezak deb bosadi — va `setBackground`
(`useStudio.ts:417-433`) butun uv zonaga to'ldirilgan qatlam qo'shadi.
Uni `measurePainted` ham, serverdagi `print_files.analyse` ham hisoblaydi,
shuning uchun narx **eng yuqori cm² tarifiga sakraydi** va fabrikaga "oq
futbolkaga oq to'rtburchak bosing" degan fayl ketadi.

Yechim: siqilmagan **haqiqiy** rang bilan solishtirish. Bo'yashda asl hex'ni
yonida saqlang (masalan `material.userData.trueHex`) va `surfaceColors()`
shuni qaytarsin. Oq, qora va o'rtacha rangda, mato va keramikada sinang.

## 3. Dumaloq zona burchaklari — HIGH

Dumaloq hudud (soat siferblati) ikkala previewda dumaloq, print faylida
esa **to'rtburchak**:

- `app/lib/three/projector.ts:214-219` — dekal to'rtburchakka qirqiladi;
  `box.round` faqat coverage hisobida ishlatiladi (:250, :264-269).
- `app/lib/three/parametric.ts:200-201` — parametrik `disc` doiradan
  tashqaridagi kataklarni tashlaydi, ya'ni 3D burchaklarni yashiradi.
- `app/components/studio/StudioEditor.vue:65-68, 250, 255` — tekis muharrir
  CSS `border-radius: 50%` bilan qirqadi.
- `app/lib/design/document.ts:178-185` — `printZone` **to'rtburchak**.
- `app/lib/design/render.ts:391-404` — `renderPrintFile` ham shunga qirqadi.

Mijoz logotipni siferblat burchagiga surganda: bir ko'rinishda yo'qoladi,
boshqasida ramkada turadi, print faylida esa bor — va u siyoh uchun **pul
to'laydi**.

Yechim: `round` ni bezak emas, haqiqiy qirqim qilish — `printZone` va hudud
chizish yo'lida ellips bo'yicha clip (rect emas), `corner_radius_mm` ham
shunday. Backendda `design_rules.print_zone` va `print_files.analyse` bir
xil qoidaga kelishi shart.

## 4. Past DPI hech narsani to'xtatmaydi — HIGH

- `app/lib/design/render.ts:406-411` — `imageDpi()` va `LOW_DPI = 150` bor.
- Lekin ular faqat `StudioLayerProps.vue:364-369` dagi sarg'ish yozuv va
  `StudioLayers.vue:66-67` dagi belgi sifatida ishlatiladi — ya'ni qatlam
  tanlangandagina ko'rinadi.
- `document.ts:402-428` (`layerProblems`) va `:441-457` (`designProblems`)
  da DPI qoidasi **yo'q**, shuning uchun `blocked` hech qachon ishlamaydi.

Ustiga 3D tekstura `min(6 px/mm, 2048/max(w,h))` bilan chiziladi
(`render.ts:329-341`) — 400 mm hududda 2.56 px/mm ≈ 65 DPI. Ya'ni 100 DPI
va 600 DPI **ekranda bir xil** ko'rinadi.

Yechim: `layerProblems` ga DPI qoidasi — ~100 DPI dan past qat'iy blok,
100–150 oralig'ida hozirgi sarg'ish ogohlantirish. Backendda ham
(`design_rules.document_problems`) bir xil qoida bo'lsin.

## 5. O'lchamga qarab print masshtabi

Hozir tanlangan o'lcham geometriyaga **umuman ta'sir qilmaydi** — S va 3XL
bir xil print fayli beradi. Egasining qoidasi: **40×40 sm eng katta o'lcham
uchun maksimum**, kichiklari mutanosib kichrayadi.

Kelishilgan yechim: `SizeItem.print_scale` (backendda migratsiya `0029`
tayyor). Hudud o'lchami maksimum, tanlangan o'lcham uchun
`width_mm * print_scale`. Standart: 3XL 1.00, XXL 0.95, XL 0.90, L 0.85,
M 0.80, S 0.75.

Ulanishi kerak: Studio zonasi va yo'riqchilari (`useStudio.ts`,
`document.ts`, `parametric.ts`, `projector.ts`), 3D dekal
(`studioScene.ts`), **print fayli** (`output.ts` `printJobs` /
`render.ts` `renderPrintFile`), o'lchov → narx (`measureAreas`), va o'lcham
tanlagichida natijani ko'rsatish (masalan yonida cm² yozib qo'yish).

---

## Eslatma

- `pnpm exec eslint --fix` va `pnpm exec vue-tsc --build --force` — tegilgan
  fayllarda toza bo'lsin.
- Ma'lum, oldindan buzuq: `BranchLocationPicker`, `LocationPickerMap`,
  `GalleryDesigns`, `admin/tutorials`, `user/orders` (eski auto-import /
  leaflet turlari) va `scripts/strip-rules.test.mjs` (`~` alias). Tegmang.
- Deploy Cloudflare Workers'ga avtomatik — **push qilishdan oldin build
  qiling**, build jimgina yiqilishi mumkin.
