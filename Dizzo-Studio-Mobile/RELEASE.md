# Dizzo: do‘konga chiqarish

Qisqa yo‘riqnoma: Google Play va App Store uchun build qilish.
Barcha buyruqlar repo ildizidan (`Dizzo-Mobile/`) ishga tushiriladi.

Ilova: **Dizzo**, `uz.dizzo.studio` (Android applicationId va iOS bundle id).
API: `https://api.dizzo.uz/api`, sayt: `https://dizzo.uz`. Ular
`config/prod.json` ichida, build paytida `--dart-define-from-file` bilan beriladi.

## 1. Upload keystore (bir marta)

Keystore’ni **repodan tashqarida** saqlang va zaxira nusxasini oling. Uni
yo‘qotsangiz, Play’ga yangilanish yuklab bo‘lmaydi.

```bash
mkdir -p /d/Hojiakbar/keys
keytool -genkeypair -v -keystore /d/Hojiakbar/keys/dizzo-upload.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`keytool` Android Studio bilan keladi:
`"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"`.

SHA-1 va SHA-256 barmoq izlari (Google Sign-In va App Links uchun kerak):

```bash
keytool -list -v -keystore /d/Hojiakbar/keys/dizzo-upload.jks -alias upload
```

## 2. key.properties

`android/key.properties.example` faylidan nusxa oling:

```bash
cp android/key.properties.example android/key.properties
```

Keyin parollarni kiriting:

```properties
storeFile=D:/Hojiakbar/keys/dizzo-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Bu fayl git’ga tushmaydi. Uni `android/` ichida emas, boshqa joyda saqlasa ham
bo‘ladi: bunda `DIZZO_KEY_PROPERTIES` o‘zgaruvchisiga uning yo‘lini bering:

```powershell
$env:DIZZO_KEY_PROPERTIES='D:\Hojiakbar\keys\key.properties'
```

> Agar `key.properties` topilmasa, release build **debug kalit** bilan
> imzolanadi va Gradle `WARNING: no android/key.properties` deb yozadi. Bunday
> `.aab` faylni Play qabul qilmaydi.

## 3. Versiya

`pubspec.yaml`: `version: 1.0.0+1`, ya’ni `nom+kod`.

- Har bir yuklashda `+kod` ni **albatta** bittaga oshiring (`1.0.0+2`). Play
  ham, App Store ham bir xil kodni ikkinchi marta qabul qilmaydi.
- Foydalanuvchiga ko‘rinadigan o‘zgarishda nomni oshiring: `1.0.1`, `1.1.0`.
- Bir martalik o‘zgartirish uchun: `--build-name=1.0.1 --build-number=2`.

## 4. Build

Android (Play uchun App Bundle):

```bash
flutter clean
flutter pub get
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/1.0.0+1 --dart-define-from-file=config/prod.json
```

Natija: `build/app/outputs/bundle/release/app-release.aab`.

iOS (macOS va Xcode kerak):

```bash
flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release --obfuscate --split-debug-info=build/symbols/1.0.0+1 --dart-define-from-file=config/prod.json
```

Natija: `build/ios/ipa/*.ipa`. Uni Transporter yoki Xcode Organizer orqali
yuklang. Xcode’da Runner > Signing & Capabilities bo‘limida Team tanlangan
bo‘lishi va **Associated Domains** yoqilgan bo‘lishi kerak.

`build/symbols/<versiya>` papkasini har bir reliz uchun saqlang. Busiz
obfuskatsiya qilingan xato izlarini o‘qib bo‘lmaydi. Play Console’da:
App bundle explorer > Downloads > Native debug symbols.

`--dart-define-from-file=config/prod.json` bayrog‘ini unutmang. Usiz ham
standart qiymatlar prod’ga qaraydi, lekin iOS Google/Telegram sozlamalari
shu fayldan olinadi.

## 5. Build’dan keyin: kalitlar va havolalar

1. **Play App Signing**: Play Console > Setup > App signing bo‘limidagi
   *App signing key* SHA-1/SHA-256 ni oling.
2. **Google Sign-In**: Google Cloud Console’da `uz.dizzo.studio` uchun Android
   OAuth client’ga upload va Play App Signing kalitlarining SHA-1 larini
   qo‘shing. Aks holda Play’dan o‘rnatilgan ilovada Google orqali kirish
   ishlamaydi.
3. **Telegram login**: @BotFather’da Android ilova uchun o‘sha SHA-256 larni
   kiriting.
4. **App Links (dizzo.uz)**: saytga
   `https://dizzo.uz/.well-known/assetlinks.json` faylini qo‘ying
   (Dizzo-Frontend: `public/.well-known/assetlinks.json`):

   ```json
   [{
     "relation": ["delegate_permission/common.handle_all_urls"],
     "target": {
       "namespace": "android_app",
       "package_name": "uz.dizzo.studio",
       "sha256_cert_fingerprints": ["PLAY_APP_SIGNING_SHA256", "UPLOAD_SHA256"]
     }
   }]
   ```

   Android 11 va undan eski versiyalarda bitta domen tekshiruvdan o‘tmasa,
   ilovaning hamma App Link’lari, shu jumladan Telegram login qaytishi ham,
   tasdiqlanmagan hisoblanadi. Shuning uchun bu faylni **relizdan oldin**
   joylang.
5. **Universal Links (iOS)**: `https://dizzo.uz/.well-known/apple-app-site-association`
   (kengaytmasiz, `Content-Type: application/json`):

   ```json
   {"applinks": {"details": [{"appIDs": ["TEAMID.uz.dizzo.studio"],
     "components": [{"/": "/products/*"}, {"/": "/studio/*"}, {"/": "/catalog"}, {"/": "/user/*"}]}]}}
   ```

   Tekshirish:
   `adb shell pm get-app-links uz.dizzo.studio` va
   `adb shell am start -a android.intent.action.VIEW -d https://dizzo.uz/products/krujka`.

## 6. Google Play Console ro‘yxati

- [ ] Store listing: `store/listing_uz.md` dagi matnlar (nom, qisqa va to‘liq tavsif).
- [ ] Ikonka 512×512 PNG (`assets/launcher/icon.png` dan), feature graphic 1024×500.
- [ ] Skrinshotlar: telefon uchun kamida 2 ta (tavsiya 4–8 ta, 1080×1920 yoki
      1080×2340). 7" va 10" planshet uchun ham qo‘shing, chunki ilova planshet
      maketini qo‘llaydi.
      Ekranlar: bosh sahifa, katalog, mahsulot, Studio muharriri, savat,
      buyurtma holati.
- [ ] **Privacy policy URL**: `https://dizzo.uz/privacy` (ruscha
      `https://dizzo.uz/ru/privacy`, inglizcha `https://dizzo.uz/en/privacy`).
      Ilovada: Profil → “Maxfiylik siyosati” (mehmonlar uchun ham) va kirish
      oynasidagi havola.
- [ ] **Hisobni o‘chirish** (Data safety > Data deletion): ilova ichida
      Profil → “Hisobni o‘chirish”; vebda `https://dizzo.uz/user/profile`
      sahifasida. Hisob, saqlangan dizaynlar va savat o‘chiriladi;
      yakunlangan buyurtmalar hisob-kitob uchun shaxsiy ma’lumotlarsiz
      qoladi (`DELETE /api/users/profile/me/`).
- [ ] App content > **Data safety**:
  - Shaxsiy ma’lumot: ism, email, telefon raqami, yetkazish manzili. Maqsadi:
    hisob va buyurtmani bajarish. Ma’lumot uzatishda shifrlanadi (HTTPS).
  - Aniq joylashuv: ixtiyoriy, faqat xaritada manzilni belgilash uchun.
    Koordinatalar manzilni aniqlash uchun OpenStreetMap Nominatim’ga
    yuboriladi.
  - Foto: foydalanuvchi dizayn yoki fikr uchun tanlagan rasmlar serverga
    yuklanadi.
  - Ilova faoliyati: savat, buyurtmalar, saqlangan dizaynlar.
  - Reklama va analitika yo‘q. Ma’lumot uchinchi tomonga sotilmaydi.
  - Kirish Google va Telegram orqali ham mumkin.
- [ ] App content: Ads = **yo‘q**; Target audience = 18+ (yoki 13+);
      Content rating anketasi; Government apps = yo‘q; Financial features:
      to‘lov ilova ichida bo‘lmasa, “yo‘q”.
- [ ] Kategoriya: **Shopping**. Aloqa uchun email va sayt manzili: `https://dizzo.uz`.
- [ ] Avval **Internal testing**, keyin Closed va Production. Yangi shaxsiy
      dasturchi hisobi bo‘lsa, Play production’dan oldin kamida 12 testerli
      14 kunlik yopiq test talab qiladi.
- [ ] Mamlakatlar: O‘zbekiston (va kerak bo‘lsa boshqalar).

## 7. App Store Connect ro‘yxati

- [ ] Yangi ilova: bundle id `uz.dizzo.studio`, SKU `dizzo-ios`, asosiy til: rus
      yoki ingliz. App Store o‘zbek tilini qo‘llab-quvvatlamaydi, shuning uchun
      o‘zbekcha matnni tanlangan til maydoniga kiriting.
- [ ] Nom (30), Subtitle (30), Keywords (100 belgi, vergul bilan), Description,
      Promotional text: `store/listing_uz.md` dan.
- [ ] Skrinshotlar: 6.9" (1320×2868) va 13" iPad (2064×2752).
- [ ] Privacy Policy URL: `https://dizzo.uz/privacy`. Support URL: `https://dizzo.uz`.
- [ ] **App Privacy**: yuqoridagi Data safety bilan bir xil. Contact Info,
      Location (Precise), Photos, User Content, Identifiers (User ID). Hech
      biri tracking uchun ishlatilmaydi.
- [ ] Sign in with Apple: ilovada Google orqali kirish bor. Apple 4.8-qoidasi
      bo‘yicha Telegram yoki email kirish ham borligi yetarli bo‘lishi mumkin,
      lekin review rad etsa, Apple login qo‘shish kerak.
- [ ] **Hisobni o‘chirish** (5.1.1(v)): ilovada Profil → “Hisobni o‘chirish”,
      vebda `https://dizzo.uz/user/profile`. Review izohida shuni ko‘rsating.
- [ ] Review uchun demo hisob (email va parol) va izoh bering.
- [ ] Export compliance: `ITSAppUsesNonExemptEncryption = NO` (faqat HTTPS
      ishlatiladi), Info.plist’da allaqachon belgilangan.
- [ ] Age rating anketasi, kategoriya: **Shopping**.
