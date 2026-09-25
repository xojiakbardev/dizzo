// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appTitle => 'Dizzo';

  @override
  String get authEmail => 'Email';

  @override
  String get authEmailInvalid => 'Email noto‘g‘ri';

  @override
  String get authEmailRequired => 'Emailni kiriting';

  @override
  String get authFirstName => 'Ism';

  @override
  String get authFirstNameRequired => 'Ismingizni kiriting';

  @override
  String get authGoogleFailed => 'Google orqali kirib bo‘lmadi';

  @override
  String get authGoogleNoAccount => 'Qurilmada Google hisobi topilmadi';

  @override
  String get authGoogleNoResponse => 'Google javob bermadi';

  @override
  String get authGoogleNotConfigured => 'Google orqali kirish hali sozlanmagan';

  @override
  String get authGoogleUnsupported =>
      'Google orqali kirish bu qurilmada ishlamaydi';

  @override
  String get authGoogleWindowFailed => 'Google oynasini ochib bo‘lmadi';

  @override
  String get authHaveAccount => 'Hisobim bor';

  @override
  String get authLater => 'Keyinroq';

  @override
  String get authOr => 'yoki';

  @override
  String get authPassword => 'Parol';

  @override
  String get authPasswordHide => 'Yashirish';

  @override
  String get authPasswordRequired => 'Parolni kiriting';

  @override
  String get authPasswordShow => 'Ko‘rsatish';

  @override
  String authPasswordTooShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kamida $count ta belgi',
      one: 'Kamida $count ta belgi',
    );
    return '$_temp0';
  }

  @override
  String get authPrivacyNotice =>
      'Davom etish orqali siz maxfiylik siyosatini qabul qilasiz';

  @override
  String get authRegisterSubmit => 'Ro‘yxatdan o‘tish';

  @override
  String get authRegisterSwitch => 'Ro‘yxatdan o‘tish';

  @override
  String get authRegisterTitle => 'Ro‘yxatdan o‘tish';

  @override
  String get authSignIn => 'Kirish';

  @override
  String get authSignInEmail => 'Email orqali kirish';

  @override
  String get authSignInFailed => 'Kirishda xatolik';

  @override
  String get authSignInGoogle => 'Google orqali kirish';

  @override
  String get authSignInTelegram => 'Telegram orqali kirish';

  @override
  String get authSignInTitle => 'Hisobingizga kiring';

  @override
  String get authTelegramConfirm => 'Telegramda tasdiqlang';

  @override
  String get authTelegramFailed => 'Telegram orqali kirib bo‘lmadi';

  @override
  String get authTelegramReopen => 'Qayta ochish';

  @override
  String get authTelegramVerifying => 'Tekshirilmoqda';

  @override
  String get authWelcomeHeadline => 'O‘z dizayningizni\nyarating';

  @override
  String get cartBrowseProducts => 'Mahsulot tanlash';

  @override
  String get cartCheckout => 'Rasmiylashtirish';

  @override
  String get cartClear => 'Tozalash';

  @override
  String get cartClearConfirm => 'Savatni tozalaysizmi?';

  @override
  String get cartDecrease => 'Kamaytirish';

  @override
  String get cartEditItem => 'Tahrirlash';

  @override
  String get cartEmpty => 'Savat bo‘sh';

  @override
  String cartImageLabel(int index, int count) {
    return 'Rasm $index / $count';
  }

  @override
  String get cartIncrease => 'Ko‘paytirish';

  @override
  String get cartItemActions => 'Amallar';

  @override
  String cartItemRemoved(String name) {
    return '$name olib tashlandi';
  }

  @override
  String get cartItemUnavailable => 'Sotuvda yo‘q';

  @override
  String cartItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta mahsulot',
      one: '$count ta mahsulot',
    );
    return '$_temp0';
  }

  @override
  String cartPrintArea(String method, String area) {
    return '$method · $area cm²';
  }

  @override
  String get cartQuantity => 'Miqdor';

  @override
  String get cartQuantityPieces => 'Dona';

  @override
  String cartQuantityRange(int min, int max) {
    return '$min dan $max gacha';
  }

  @override
  String get cartSignInPrompt => 'Savatni ko‘rish uchun kiring';

  @override
  String get cartSomeUnavailable => 'Ba’zi mahsulotlar sotuvda yo‘q';

  @override
  String get cartTitle => 'Savat';

  @override
  String get cartTotal => 'Jami';

  @override
  String get cartUndo => 'Qaytarish';

  @override
  String cartUnitPrice(String price) {
    return '1 dona: $price';
  }

  @override
  String get catalogAllCategories => 'Barchasi';

  @override
  String get catalogClearFilter => 'Filtrni tozalash';

  @override
  String get catalogNothingFound => 'Hech narsa topilmadi';

  @override
  String get catalogPopularBadge => 'Ommabop';

  @override
  String get catalogSearchClear => 'Tozalash';

  @override
  String get catalogSearchHint => 'Qidirish';

  @override
  String get catalogTitle => 'Mahsulotlar';

  @override
  String get checkoutAddressHint => 'Ko‘cha, uy, xonadon';

  @override
  String get checkoutAddressLabel => 'Manzil';

  @override
  String get checkoutAddressRequired => 'Manzilni kiriting';

  @override
  String get checkoutCartEmpty => 'Savat bo‘sh';

  @override
  String get checkoutChangeLocation => 'O‘zgartirish';

  @override
  String get checkoutChooseProduct => 'Mahsulot tanlash';

  @override
  String get checkoutConfirm => 'Tasdiqlash';

  @override
  String get checkoutContactTitle => 'Aloqa';

  @override
  String get checkoutDelivery => 'Yetkazib berish';

  @override
  String get checkoutFree => 'Bepul';

  @override
  String get checkoutHome => 'Bosh sahifa';

  @override
  String checkoutItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta',
      one: '$count ta',
    );
    return '$_temp0';
  }

  @override
  String get checkoutLocationDenied => 'Joylashuvga ruxsat berilmadi';

  @override
  String get checkoutLocationFailed => 'Joylashuvni aniqlab bo‘lmadi';

  @override
  String get checkoutLocationOff => 'Joylashuv xizmati o‘chiq';

  @override
  String get checkoutMapTitle => 'Manzilni belgilash';

  @override
  String get checkoutMethodTitle => 'Qabul qilish usuli';

  @override
  String get checkoutMyLocation => 'Joylashuvim';

  @override
  String get checkoutNameLabel => 'Ism va familiya';

  @override
  String get checkoutNameRequired => 'Ismingizni kiriting';

  @override
  String get checkoutNoteLabel => 'Izoh (ixtiyoriy)';

  @override
  String get checkoutNoteTitle => 'Izoh';

  @override
  String get checkoutOperatorQuotes => 'Operator aytadi';

  @override
  String get checkoutOrderNumber => 'Buyurtma raqami';

  @override
  String get checkoutPhoneIncomplete => 'Telefon raqamini to‘liq kiriting';

  @override
  String get checkoutPhoneLabel => 'Telefon';

  @override
  String get checkoutPickOnMap => 'Xaritadan belgilash';

  @override
  String get checkoutPickup => 'Olib ketish';

  @override
  String get checkoutPickupAddress => 'Toshkent shahri, Yunusobod tumani';

  @override
  String get checkoutPickupHours => 'Dushanba–Shanba, 09:00–20:00';

  @override
  String get checkoutPickupName => 'Dizzo ishlab chiqarish markazi';

  @override
  String get checkoutPlaceOrder => 'Buyurtma berish';

  @override
  String get checkoutProducts => 'Mahsulotlar';

  @override
  String checkoutQuantity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dona',
      one: '$count dona',
    );
    return '$_temp0';
  }

  @override
  String get checkoutSignInPrompt => 'Buyurtma berish uchun kiring';

  @override
  String get checkoutSomeUnavailable => 'Ba’zi mahsulotlar sotuvda yo‘q';

  @override
  String get checkoutStatus => 'Holat';

  @override
  String get checkoutSuccessTitle => 'Buyurtma qabul qilindi';

  @override
  String get checkoutSummaryTitle => 'Buyurtma tarkibi';

  @override
  String get checkoutTitle => 'Rasmiylashtirish';

  @override
  String get checkoutTotal => 'Jami';

  @override
  String get checkoutViewOrder => 'Buyurtmani ko‘rish';

  @override
  String get commonBack => 'Orqaga';

  @override
  String get commonCancel => 'Bekor qilish';

  @override
  String get commonClose => 'Yopish';

  @override
  String get commonComingSoon => 'Tez orada';

  @override
  String get commonCustomer => 'Mijoz';

  @override
  String get commonDelete => 'O‘chirish';

  @override
  String get commonDone => 'Tayyor';

  @override
  String get commonLoading => 'Yuklanmoqda';

  @override
  String get commonNo => 'Yo‘q';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Qayta urinish';

  @override
  String get commonSave => 'Saqlash';

  @override
  String get commonYes => 'Ha';

  @override
  String get currencySum => 'so‘m';

  @override
  String get designsActions => 'Amallar';

  @override
  String get designsCreate => 'Dizayn yaratish';

  @override
  String get designsDeleteConfirm => 'Dizaynni o‘chirasizmi?';

  @override
  String get designsDeleted => 'Dizayn o‘chirildi';

  @override
  String get designsEdit => 'Tahrirlash';

  @override
  String get designsEmpty => 'Hali dizayn yo‘q';

  @override
  String get designsNew => 'Yangi dizayn';

  @override
  String get designsSignIn => 'Dizaynlaringiz shu yerda saqlanadi';

  @override
  String editorCanvasSizeAngleBadge(String w, String h, String angle) {
    return '$w × $h mm · $angle°';
  }

  @override
  String editorCanvasSizeBadge(String w, String h) {
    return '$w × $h mm';
  }

  @override
  String get editorCropFree => 'Erkin';

  @override
  String get editorCropOriginal => 'Asli';

  @override
  String get editorCropTitle => 'Kesish';

  @override
  String get editorCropZone => 'Zona';

  @override
  String editorDomainIconLabel(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'heart': 'Yurak',
      'heart_straight': 'Yurakcha',
      'heart_half': 'Yarim yurak',
      'heart_break': 'Singan yurak',
      'heartbeat': 'Yurak urishi',
      'calendar_heart': 'Sevgi kuni',
      'gift': 'Sovg‘a',
      'confetti': 'Konfetti',
      'balloon': 'Havo shari',
      'cake': 'Tort',
      'champagne': 'Shampan',
      'cheers': 'Qadahlar',
      'crown': 'Toj',
      'crown_simple': 'Oddiy toj',
      'sparkle': 'Uchqun',
      'star': 'Yulduz',
      'shooting_star': 'Uchar yulduz',
      'flower_tulip': 'Lola',
      'envelope_simple': 'Maktub',
      'disco_ball': 'Disko shar',
      'bell_ringing': 'Qo‘ng‘iroq',
      'baby': 'Chaqaloq',
      'magic_wand': 'Sehrli tayoqcha',
      'treasure_chest': 'Xazina sandig‘i',
      'sun': 'Quyosh',
      'sun_horizon': 'Quyosh chiqishi',
      'moon': 'Oy',
      'moon_stars': 'Oy va yulduzlar',
      'cloud': 'Bulut',
      'cloud_sun': 'Bulutli quyosh',
      'cloud_rain': 'Yomg‘ir',
      'cloud_lightning': 'Momaqaldiroq',
      'snowflake': 'Qor parchasi',
      'rainbow': 'Kamalak',
      'lightning': 'Chaqmoq',
      'drop': 'Tomchi',
      'fire': 'Olov',
      'leaf': 'Barg',
      'tree': 'Daraxt',
      'tree_evergreen': 'Archa',
      'tree_palm': 'Palma',
      'plant': 'Nihol',
      'cactus': 'Kaktus',
      'flower': 'Gul',
      'flower_lotus': 'Nilufar',
      'clover': 'Beda',
      'mountains': 'Tog‘lar',
      'waves': 'To‘lqinlar',
      'cat': 'Mushuk',
      'dog': 'It',
      'paw_print': 'Panja izi',
      'bird': 'Qush',
      'fish': 'Baliq',
      'fish_simple': 'Baliqcha',
      'butterfly': 'Kapalak',
      'horse': 'Ot',
      'rabbit': 'Quyon',
      'cow': 'Sigir',
      'bug': 'Hasharot',
      'bug_beetle': 'Qo‘ng‘iz',
      'shrimp': 'Krevetka',
      'feather': 'Pat',
      'bone': 'Suyak',
      'coffee': 'Qahva',
      'tea_bag': 'Choy',
      'bowl_steam': 'Issiq kosa',
      'cooking_pot': 'Qozon',
      'fork_knife': 'Vilka va pichoq',
      'chef_hat': 'Oshpaz qalpog‘i',
      'pizza': 'Pitsa',
      'hamburger': 'Gamburger',
      'bread': 'Non',
      'egg': 'Tuxum',
      'ice_cream': 'Muzqaymoq',
      'popsicle': 'Eskimo',
      'cookie': 'Pechenye',
      'popcorn': 'Popkorn',
      'cherries': 'Gilos',
      'orange_slice': 'Apelsin bo‘lagi',
      'avocado': 'Avokado',
      'carrot': 'Sabzi',
      'pepper': 'Qalampir',
      'wine': 'Vino',
      'beer_stein': 'Pivo krujkasi',
      'martini': 'Kokteyl',
      'soccer_ball': 'Futbol to‘pi',
      'basketball': 'Basketbol',
      'volleyball': 'Voleybol',
      'tennis_ball': 'Tennis to‘pi',
      'ping_pong': 'Stol tennisi',
      'football': 'Regbi',
      'bowling_ball': 'Bouling',
      'golf': 'Golf',
      'hockey': 'Xokkey',
      'boxing_glove': 'Boks qo‘lqopi',
      'barbell': 'Shtanga',
      'trophy': 'Kubok',
      'medal': 'Medal',
      'flag_checkered': 'Marra bayrog‘i',
      'sneaker': 'Krossovka',
      'person_simple_run': 'Yuguruvchi',
      'person_simple_swim': 'Suzuvchi',
      'person_simple_ski': 'Chang‘ichi',
      'bicycle': 'Velosiped',
      'game_controller': 'O‘yin pulti',
      'puzzle_piece': 'Boshqotirma',
      'dice_five': 'O‘yin soqqasi',
      'airplane': 'Samolyot',
      'car': 'Mashina',
      'jeep': 'Jip',
      'taxi': 'Taksi',
      'bus': 'Avtobus',
      'train': 'Poyezd',
      'motorcycle': 'Mototsikl',
      'boat': 'Kema',
      'sailboat': 'Yelkanli qayiq',
      'anchor': 'Langar',
      'lighthouse': 'Mayoq',
      'globe_hemisphere_east': 'Yer shari',
      'map_pin': 'Manzil',
      'map_trifold': 'Xarita',
      'compass': 'Kompas',
      'suitcase_rolling': 'Chamadon',
      'backpack': 'Ryukzak',
      'tent': 'Chodir',
      'campfire': 'Gulxan',
      'island': 'Orol',
      'sunglasses': 'Quyosh ko‘zoynagi',
      'city': 'Shahar',
      'house': 'Uy',
      'music_note': 'Nota',
      'music_notes': 'Notalar',
      'headphones': 'Quloqchin',
      'guitar': 'Gitara',
      'microphone': 'Mikrofon',
      'microphone_stage': 'Sahna mikrofoni',
      'piano_keys': 'Pianino',
      'vinyl_record': 'Plastinka',
      'cassette_tape': 'Kasseta',
      'radio': 'Radio',
      'palette': 'Palitra',
      'paint_brush': 'Mo‘yqalam',
      'pen_nib': 'Pero',
      'camera': 'Fotoapparat',
      'video_camera': 'Videokamera',
      'film_strip': 'Kinolenta',
      'film_slate': 'Kino xlopushkasi',
      'ticket': 'Chipta',
      'mask_happy': 'Kulgili niqob',
      'mask_sad': 'G‘amgin niqob',
      'book': 'Kitob',
      'book_open': 'Ochiq kitob',
      'books': 'Kitoblar',
      'notebook': 'Daftar',
      'graduation_cap': 'Bitiruv qalpog‘i',
      'student': 'O‘quvchi',
      'chalkboard_teacher': 'O‘qituvchi',
      'pencil': 'Qalam',
      'pencil_ruler': 'Qalam va chizg‘ich',
      'briefcase': 'Portfel',
      'laptop': 'Noutbuk',
      'lightbulb': 'Lampochka',
      'rocket': 'Raketa',
      'target': 'Nishon',
      'chart_line_up': 'O‘sish grafigi',
      'calendar': 'Kalendar',
      'clock': 'Soat',
      'hourglass': 'Qum soat',
      'atom': 'Atom',
      'flask': 'Kolba',
      'globe_stand': 'Globus',
      'code': 'Kod',
      'handshake': 'Qo‘l siqish',
      'stethoscope': 'Stetoskop',
      'check_circle': 'Tasdiq',
      'x_circle': 'Bekor qilish',
      'arrow_fat_right': 'Strelka',
      'infinity': 'Cheksizlik',
      'peace': 'Tinchlik',
      'yin_yang': 'In-yan',
      'smiley': 'Tabassum',
      'smiley_wink': 'Ko‘z qisish',
      'smiley_sad': 'Xafa smayl',
      'smiley_angry': 'Jahldor smayl',
      'smiley_melting': 'Eriyotgan smayl',
      'thumbs_up': 'Layk',
      'thumbs_down': 'Dizlayk',
      'hand_heart': 'Qo‘ldagi yurak',
      'hand_peace': 'G‘alaba ishorasi',
      'hand_waving': 'Salom',
      'hands_clapping': 'Qarsak',
      'flag': 'Bayroq',
      'shield': 'Qalqon',
      'star_four': 'To‘rt qirrali yulduz',
      'asterisk': 'Yulduzcha',
      'quotes': 'Qo‘shtirnoq',
      'hash': 'Xeshteg',
      'at': 'Kuchukcha',
      'circle': 'Doira',
      'square': 'Kvadrat',
      'triangle': 'Uchburchak',
      'hexagon': 'Oltiburchak',
      'diamond': 'Romb',
      'ghost': 'Arvoh',
      'alien': 'O‘zga sayyoralik',
      'robot': 'Robot',
      'other': '-',
    });
    return '$_temp0';
  }

  @override
  String get editorDomainLayerElement => 'Element';

  @override
  String get editorDomainLayerIcon => 'Ikonka';

  @override
  String get editorDomainLayerShape => 'Shakl';

  @override
  String editorDomainMaxHeight(String max) {
    return 'bo‘yi $max mm dan oshmasin';
  }

  @override
  String editorDomainMaxWidth(String max) {
    return 'eni $max mm dan oshmasin';
  }

  @override
  String editorDomainMinFont(String min) {
    return 'shrift kamida $min mm bo‘lsin';
  }

  @override
  String editorDomainNoArea(String area) {
    return '“$area” hududi bu turda yo‘q';
  }

  @override
  String get editorDomainNoColor => 'bu usulda rang bo‘lmaydi';

  @override
  String editorDomainNoMethod(String area) {
    return '“$area” hududida bu usul yo‘q';
  }

  @override
  String get editorDomainOneMethod =>
      'dizayn bitta usulda bosiladi — bu element boshqa usulda';

  @override
  String get editorDomainOutOfZone => 'bosma zonasidan chiqib ketgan';

  @override
  String editorDomainProblemAt(String area, String problem) {
    return '$area: $problem';
  }

  @override
  String editorDomainShapeLabel(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'square': 'Kvadrat',
      'rounded': 'Yumaloq burchakli',
      'circle': 'Doira',
      'triangle': 'Uchburchak',
      'star': 'Yulduz',
      'heart': 'Yurak',
      'hexagon': 'Oltiburchak',
      'diamond': 'Romb',
      'burst': 'Nishon',
      'semicircle': 'Yarim doira',
      'bubble': 'Nutq pufagi',
      'arrow': 'Strelka',
      'plus': 'Plyus',
      'ring': 'Halqa',
      'frame': 'Ramka',
      'frame_round': 'Yumaloq ramka',
      'line': 'Chiziq',
      'line_double': 'Qo‘sh chiziq',
      'other': '-',
    });
    return '$_temp0';
  }

  @override
  String get editorElementsAll => 'Hammasi';

  @override
  String get editorElementsClear => 'Tozalash';

  @override
  String get editorElementsIcons => 'Ikonkalar';

  @override
  String get editorElementsLoadFailed => 'Elementlarni yuklab bo‘lmadi';

  @override
  String get editorElementsNothingFound => 'Hech narsa topilmadi';

  @override
  String get editorElementsPopular => 'Ommabop';

  @override
  String get editorElementsSearch => 'Qidirish';

  @override
  String get editorElementsShapes => 'Shakllar';

  @override
  String get editorFontSample => 'Salom';

  @override
  String get editorImageCamera => 'Kamera';

  @override
  String get editorImageGallery => 'Galereya';

  @override
  String get editorImageOpenFailed => 'Rasmni ochib bo‘lmadi';

  @override
  String get editorImageUnsupported =>
      'Faqat PNG, JPG yoki WEBP rasm yuklash mumkin';

  @override
  String get editorImageUploadFailed => 'Rasmni yuklab bo‘lmadi';

  @override
  String get editorLayersEmpty => 'Bu tomonda hali element yo‘q';

  @override
  String get editorLayersHidden => 'Yashirilgan';

  @override
  String get editorLayersHide => 'Yashirish';

  @override
  String get editorLayersLock => 'Qulflash';

  @override
  String get editorLayersOpen => 'Ochish';

  @override
  String get editorLayersShow => 'Ko‘rsatish';

  @override
  String editorLayersSyncedWith(String area) {
    return '“$area” bilan sinxron';
  }

  @override
  String get editorLayersUnlock => 'Qulfdan chiqarish';

  @override
  String get editorMain3dFailed => '3D ko‘rinishni ochib bo‘lmadi';

  @override
  String get editorMain3dLoading => '3D model yuklanmoqda…';

  @override
  String get editorMain3dView => '3D ko‘rinish';

  @override
  String get editorMainActions => 'Amallar';

  @override
  String get editorMainAddSomethingFirst => 'Avval rasm yoki matn qo‘shing';

  @override
  String get editorMainAddToCart => 'Savatga';

  @override
  String get editorMainAddToCartFailed => 'Savatga qo‘shib bo‘lmadi';

  @override
  String editorMainAreaNoMethod(String area) {
    return '“$area” hududida bu usul yo‘q';
  }

  @override
  String editorMainAreaNoMethodClear(String area) {
    return '“$area” hududida bu usul yo‘q: u yerdagi elementlarni olib tashlang';
  }

  @override
  String get editorMainAreaSynced => 'Bu tomon boshqa tomon bilan sinxron';

  @override
  String editorMainAreaSyncedWith(String area) {
    return 'Bu tomon “$area” bilan sinxron: “$area”da tahrirlang';
  }

  @override
  String get editorMainBadImage => 'Rasm noto‘g‘ri';

  @override
  String get editorMainBringForward => 'Oldinga';

  @override
  String get editorMainCannotAddHere => 'Bu hududga qo‘shib bo‘lmaydi';

  @override
  String get editorMainCapture => 'Rasmga olish';

  @override
  String get editorMainCenter => 'Markaz';

  @override
  String get editorMainCopy => 'Nusxa';

  @override
  String editorMainCroppedBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta kesiladi',
      one: '$count ta kesiladi',
    );
    return '$_temp0';
  }

  @override
  String get editorMainDuplicate => 'Nusxa olish';

  @override
  String get editorMainEditTextShort => 'Matn';

  @override
  String get editorMainEngineBroken => '3D ko‘rinish ishlamayapti';

  @override
  String get editorMainEngineClosed => 'Yopildi';

  @override
  String get editorMainEngineConnectFailed => '3D ko‘rinishga ulanib bo‘lmadi';

  @override
  String get editorMainEngineLoadFailed => '3D ko‘rinish yuklanmadi';

  @override
  String get editorMainEngineNoAnswer => '3D ko‘rinish javob bermadi';

  @override
  String get editorMainEngineNotReady => '3D ko‘rinish hali tayyor emas';

  @override
  String get editorMainEngineReloaded => '3D ko‘rinish qayta yuklandi';

  @override
  String get editorMainEngineStartFailed =>
      '3D ko‘rinishni ishga tushirib bo‘lmadi';

  @override
  String get editorMainError => 'Xato';

  @override
  String editorMainErrorsBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta xato',
      one: '$count ta xato',
    );
    return '$_temp0';
  }

  @override
  String editorMainFileSaveFailed(String status) {
    return 'Faylni saqlab bo‘lmadi ($status). Qayta urinib ko‘ring.';
  }

  @override
  String get editorMainFixRedItems => 'Qizil belgilangan elementlarni tuzating';

  @override
  String get editorMainFlatView => 'Tekis ko‘rinish';

  @override
  String get editorMainHide => 'Yashirish';

  @override
  String get editorMainLock => 'Qulflash';

  @override
  String get editorMainLocked => 'Qulfli';

  @override
  String get editorMainMenuEditText => 'Matnni o‘zgartirish';

  @override
  String editorMainMethodSwitched(String method) {
    return 'Dizayn “$method” usuliga o‘tkazildi';
  }

  @override
  String get editorMainNoPrintFile => 'Bosma fayl chiqmadi';

  @override
  String get editorMainNoViews => 'Ko‘rinish rasmlari olinmadi';

  @override
  String get editorMainNotSaved => 'Saqlanmadi';

  @override
  String get editorMainPickSizeFirst => 'Avval o‘lchamni tanlang';

  @override
  String get editorMainPickTool => 'Asbobni tanlang';

  @override
  String get editorMainPriceRecalculated => 'Narx qayta hisoblandi';

  @override
  String get editorMainProductColor => 'Mahsulot rangi';

  @override
  String get editorMainProductColorBackground => 'Mahsulot rangida fon';

  @override
  String get editorMainRedo => 'Qaytarish';

  @override
  String get editorMainReloadedNewer =>
      'Dizayn boshqa joyda o‘zgartirilgan edi: oxirgi holati yuklandi';

  @override
  String get editorMainResetView => 'Ko‘rinishni tiklash';

  @override
  String get editorMainSaveFailed => 'Saqlab bo‘lmadi';

  @override
  String get editorMainSaveFailedOffline =>
      'Saqlab bo‘lmadi. Internetni tekshiring';

  @override
  String get editorMainSaved => 'Dizayn saqlandi';

  @override
  String get editorMainSendBackward => 'Orqaga';

  @override
  String get editorMainSettings => 'Sozlash';

  @override
  String get editorMainStepAddingToCart => 'Savatga qo‘shilmoqda…';

  @override
  String get editorMainStepPrintFiles => 'Bosma fayllar tayyorlanmoqda…';

  @override
  String get editorMainStepSaving => 'Dizayn saqlanmoqda…';

  @override
  String editorMainStepUploading(int current, int total) {
    return 'Yuklanmoqda… $current/$total';
  }

  @override
  String get editorMainStepViews => 'Rasmlar olinmoqda…';

  @override
  String editorMainSyncedFrom(String area) {
    return '“$area”dan sinxron';
  }

  @override
  String editorMainTemplateApplied(String name) {
    return '“$name” shabloni qo‘yildi';
  }

  @override
  String get editorMainTextPlaceholder => 'Matningiz shu yerda';

  @override
  String get editorMainTitle => 'Dizayn yaratish';

  @override
  String editorMainTooManyLayers(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Bitta dizaynda $max tadan ko‘p element bo‘lmaydi',
      one: 'Bitta dizaynda $max tadan ko‘p element bo‘lmaydi',
    );
    return '$_temp0';
  }

  @override
  String get editorMainToolBackground => 'Fon';

  @override
  String get editorMainToolElements => 'Elementlar';

  @override
  String get editorMainToolGallery => 'Galereya';

  @override
  String get editorMainToolImage => 'Rasm';

  @override
  String get editorMainToolLayers => 'Qatlamlar';

  @override
  String get editorMainToolText => 'Matn';

  @override
  String get editorMainUndo => 'Ortga qaytarish';

  @override
  String get editorMainUndoAction => 'Ortga';

  @override
  String get editorMainUnknownError => 'Noma’lum xato';

  @override
  String get editorMainUnlock => 'Qulfdan chiqarish';

  @override
  String get editorMainVariantNoMethod => 'Bu variantda bu usul yo‘q';

  @override
  String get editorMainVariantReplaced =>
      'Oldin tanlangan variant hozir sotuvda yo‘q, boshqasi tanlandi';

  @override
  String get editorPropsAlignCenter => 'Markazga';

  @override
  String get editorPropsAlignLeft => 'Chapga';

  @override
  String get editorPropsAlignRight => 'O‘ngga';

  @override
  String get editorPropsBackground => 'Fon';

  @override
  String get editorPropsBold => 'Qalin';

  @override
  String get editorPropsCenterX => 'Markaz (eni)';

  @override
  String get editorPropsCenterY => 'Markaz (bo‘yi)';

  @override
  String get editorPropsColor => 'Rang';

  @override
  String get editorPropsCropped => 'Zonadan chiqqan qismi bosilmaydi';

  @override
  String get editorPropsDialNumerals => 'Soat raqamlari';

  @override
  String get editorPropsFontSize => 'Shrift';

  @override
  String get editorPropsImage => 'Rasm';

  @override
  String get editorPropsItalic => 'Kursiv';

  @override
  String get editorPropsLowQuality => 'Rasm sifati past';

  @override
  String get editorPropsMinuteTicks => 'Daqiqa chiziqlari';

  @override
  String editorPropsMm(String value) {
    return '$value mm';
  }

  @override
  String get editorPropsNumeralsNone => 'Yo‘q';

  @override
  String get editorPropsRemoveBackground => 'Fonni olib tashlash';

  @override
  String get editorPropsRotation => 'Burchak';

  @override
  String get editorPropsSize => 'O‘lcham';

  @override
  String get editorPropsSticker => 'Stiker';

  @override
  String get editorPropsStraighten => 'Tekislash';

  @override
  String get editorSheet3dNotReady => '3D ko‘rinish hali tayyor emas';

  @override
  String get editorSheetAddAtPrice => 'Shu narxda qo‘shish';

  @override
  String get editorSheetAddedToCart => 'Savatga qo‘shildi';

  @override
  String get editorSheetCapture => 'Rasmga olish';

  @override
  String get editorSheetCaptureFailed => 'Rasmga olib bo‘lmadi';

  @override
  String get editorSheetClear => 'Tozalash';

  @override
  String editorSheetClearConfirm(int count, String area) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${area}dagi $count ta element o‘chirilsinmi?',
      one: '${area}dagi $count ta element o‘chirilsinmi?',
    );
    return '$_temp0';
  }

  @override
  String get editorSheetClearSide => 'Tomonni tozalash';

  @override
  String editorSheetClearSideCount(int count) {
    return 'Tomonni tozalash ($count)';
  }

  @override
  String editorSheetColorNamed(String name) {
    return 'Rang: $name';
  }

  @override
  String get editorSheetContinue => 'Davom etish';

  @override
  String get editorSheetCurrentView => 'Hozirgi ko‘rinish';

  @override
  String get editorSheetGalleryDenied => 'Galereyaga ruxsat berilmadi';

  @override
  String get editorSheetGallerySaveFailed => 'Galereyaga saqlab bo‘lmadi';

  @override
  String get editorSheetGoToCart => 'Savatga o‘tish';

  @override
  String get editorSheetGrid => 'To‘r';

  @override
  String get editorSheetImageSaved => 'Rasm saqlandi';

  @override
  String editorSheetImagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta rasm',
      one: '$count ta rasm',
    );
    return '$_temp0';
  }

  @override
  String editorSheetImagesSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta rasm saqlandi',
      one: '$count ta rasm saqlandi',
    );
    return '$_temp0';
  }

  @override
  String get editorSheetLinkedElsewhere => 'o‘zi boshqa tomonlarga ulangan';

  @override
  String editorSheetLostElements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta element bu turda joylashmaydi',
      one: '$count ta element bu turda joylashmaydi',
    );
    return '$_temp0';
  }

  @override
  String editorSheetMirrored(String name) {
    return '$name (ko‘zgu)';
  }

  @override
  String editorSheetOwnHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta elementi yashiriladi',
      one: '$count ta elementi yashiriladi',
    );
    return '$_temp0';
  }

  @override
  String get editorSheetPrice => 'Narxi';

  @override
  String get editorSheetPriceRecalculated =>
      'Narx bosma fayllar bo‘yicha qayta hisoblandi';

  @override
  String get editorSheetPrintMethod => 'Bosish usuli';

  @override
  String get editorSheetProduct => 'Mahsulot';

  @override
  String get editorSheetReplace => 'Almashtirish';

  @override
  String get editorSheetSelfSynced => 'Bu tomon o‘zi boshqa tomondan sinxron';

  @override
  String get editorSheetShare => 'Ulashish';

  @override
  String get editorSheetSides => 'Tomonlar';

  @override
  String get editorSheetSize => 'O‘lcham';

  @override
  String get editorSheetSnapping => 'Yopishish';

  @override
  String get editorSheetSync => 'Sinxronlash';

  @override
  String editorSheetSyncedFrom(String area) {
    return '“$area”dan sinxron';
  }

  @override
  String editorSheetSyncedTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta tomonga sinxron',
      one: '$count ta tomonga sinxron',
    );
    return '$_temp0';
  }

  @override
  String get editorSheetText => 'Matn';

  @override
  String get editorSheetToGallery => 'Galereyaga';

  @override
  String get editorSheetType => 'Tur';

  @override
  String get editorTemplatesEmpty => 'Bu tur uchun shablon yo‘q';

  @override
  String get editorTextAdd => 'Matn qo‘shish';

  @override
  String get editorTextBestDad => 'Eng yaxshi dadam';

  @override
  String get editorTextBigHeading => 'KATTA SARLAVHA';

  @override
  String get editorTextBirthday => 'Tug‘ilgan kuning bilan!';

  @override
  String get editorTextCongrats => 'Tabriklayman!';

  @override
  String get editorTextElegant => 'Nafis sarlavha';

  @override
  String get editorTextFonts => 'Shriftlar';

  @override
  String get editorTextGoodDays => 'Yaxshi kunlar';

  @override
  String get editorTextHeading => 'Sarlavha';

  @override
  String get editorTextPlaceholder => 'Matningiz shu yerda';

  @override
  String get editorTextSubheading => 'Kichik sarlavha';

  @override
  String get editorTextWithLove => 'Sevgi bilan';

  @override
  String get errorCancelled => 'Bekor qilindi';

  @override
  String get errorForbidden => 'Ruxsat yo‘q';

  @override
  String get errorGeneric => 'Nimadir xato ketdi';

  @override
  String get errorInsecure => 'Xavfsiz ulanib bo‘lmadi';

  @override
  String get errorNoInternet => 'Internet aloqasi yo‘q';

  @override
  String get errorNotFound => 'Topilmadi';

  @override
  String get errorServer => 'Serverda xatolik';

  @override
  String get errorSignInAgain => 'Qaytadan kiring';

  @override
  String get errorTimeout => 'Server javob bermadi';

  @override
  String get homeCategories => 'Turkumlar';

  @override
  String get homeChooseProduct => 'Mahsulot tanlang';

  @override
  String get homeCreateDesign => 'Dizayn yaratish';

  @override
  String get homeGallery => 'Galereya';

  @override
  String get homeHeroTitle => 'Krujka, futbolka, soat —\no‘z dizayningiz bilan';

  @override
  String get homeNoProducts => 'Mahsulotlar yo‘q';

  @override
  String get homeSearch => 'Qidirish';

  @override
  String get homeSeeAll => 'Barchasi';

  @override
  String get languageChoose => 'Tilni tanlang';

  @override
  String get languageSystemHint => 'Ilova tili';

  @override
  String get languageTitle => 'Til';

  @override
  String get materialCeramicGlossy => 'Keramika, yaltiroq';

  @override
  String get materialCeramicMatte => 'Keramika, matoviy';

  @override
  String get materialFabric => 'Mato';

  @override
  String get materialGlassClear => 'Shisha, tiniq';

  @override
  String get materialGlassFrosted => 'Shisha, matoviy';

  @override
  String get materialMetal => 'Metall';

  @override
  String get materialPaper => 'Qog‘oz';

  @override
  String get materialPlastic => 'Plastik';

  @override
  String get materialWood => 'Yog‘och';

  @override
  String get navCart => 'Savat';

  @override
  String get navDesigns => 'Dizaynlarim';

  @override
  String get navHome => 'Asosiy';

  @override
  String get navProducts => 'Mahsulotlar';

  @override
  String get navProfile => 'Profil';

  @override
  String get orderNextInProduction => 'Mahsulotingiz tayyorlanmoqda';

  @override
  String get orderNextNew => 'Operator tez orada bog‘lanadi';

  @override
  String get orderNextPaid => 'Tez orada ishlab chiqarishga beriladi';

  @override
  String get orderNextPaymentPending => 'To‘lovingiz kutilmoqda';

  @override
  String get orderNextQualityCheck => 'Sifati tekshirilmoqda';

  @override
  String get orderNextReadyForDelivery => 'Tez orada yetkaziladi';

  @override
  String get orderNextReadyForPickup => 'Olib ketishingiz mumkin';

  @override
  String get orderStatusCancelled => 'Bekor qilingan';

  @override
  String get orderStatusCompleted => 'Yakunlangan';

  @override
  String get orderStatusInProduction => 'Ishlab chiqarilmoqda';

  @override
  String get orderStatusNew => 'Yangi';

  @override
  String get orderStatusPaid => 'To‘langan';

  @override
  String get orderStatusPaymentPending => 'To‘lov kutilmoqda';

  @override
  String get orderStatusQualityCheck => 'Sifat nazorati';

  @override
  String get orderStatusReadyForDelivery => 'Yetkazishga tayyor';

  @override
  String get orderStatusReadyForPickup => 'Olib ketishga tayyor';

  @override
  String get orderStatusReadyForProduction => 'Ishlab chiqarishga tayyor';

  @override
  String get orderStepAccepted => 'Qabul qilindi';

  @override
  String get orderStepDone => 'Yakunlandi';

  @override
  String get orderStepPayment => 'To‘lov';

  @override
  String get orderStepProduction => 'Ishlab chiqarish';

  @override
  String get orderStepReady => 'Tayyor';

  @override
  String get ordersAll => 'Barcha buyurtmalar';

  @override
  String get ordersCancelAction => 'Bekor qilish';

  @override
  String get ordersCancelConfirm => 'Buyurtmani bekor qilasizmi?';

  @override
  String get ordersCancelKeep => 'Yo‘q';

  @override
  String get ordersCancelled => 'Buyurtma bekor qilindi';

  @override
  String get ordersCancelledBanner => 'Buyurtma bekor qilingan';

  @override
  String get ordersChooseProduct => 'Mahsulot tanlash';

  @override
  String ordersDetailTitle(String number) {
    return 'Buyurtma №$number';
  }

  @override
  String get ordersDiscount => 'Chegirma';

  @override
  String get ordersEmpty => 'Hali buyurtma yo‘q';

  @override
  String get ordersFree => 'Bepul';

  @override
  String ordersItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ta mahsulot',
      one: '$count ta mahsulot',
    );
    return '$_temp0';
  }

  @override
  String get ordersItems => 'Mahsulotlar';

  @override
  String get ordersLeaveReview => 'Fikr qoldirish';

  @override
  String get ordersMore => 'Yana';

  @override
  String get ordersNotFound => 'Buyurtma topilmadi';

  @override
  String ordersNumber(String number) {
    return '№$number';
  }

  @override
  String get ordersOnlyNewCancellable => 'Faqat yangi buyurtmani';

  @override
  String get ordersPayment => 'To‘lov';

  @override
  String get ordersPickup => 'Olib ketish';

  @override
  String ordersPieces(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dona',
      one: '$count dona',
    );
    return '$_temp0';
  }

  @override
  String get ordersReviewSent => 'Fikringiz yuborildi';

  @override
  String get ordersShipping => 'Yetkazish';

  @override
  String get ordersShippingTbd => 'Kelishiladi';

  @override
  String get ordersShowMore => 'Yana ko‘rsatish';

  @override
  String get ordersSignInPrompt => 'Buyurtmalarni ko‘rish uchun kiring';

  @override
  String get ordersStatAwaitingPayment => 'To‘lov kutilmoqda';

  @override
  String get ordersStatInProduction => 'Ishlab chiqarishda';

  @override
  String get ordersStatSpent => 'Umumiy sarf';

  @override
  String get ordersStatTotal => 'Jami buyurtma';

  @override
  String get ordersTelegram => 'Telegram orqali yozish';

  @override
  String get ordersTitle => 'Buyurtmalarim';

  @override
  String get ordersTotal => 'Jami';

  @override
  String get paymentUnpaid => 'To‘lanmagan';

  @override
  String priceFrom(String price) {
    return '$price dan';
  }

  @override
  String get printMethodEngrave => 'Lazer o‘yma';

  @override
  String get printMethodUv => 'Rangli bosma';

  @override
  String get product3dLoading => '3D model yuklanmoqda…';

  @override
  String get product3dOpenFailed => '3D ko‘rinishni ochib bo‘lmadi';

  @override
  String get product3dResetView => 'Ko‘rinishni tiklash';

  @override
  String get product3dView => '3D ko‘rinish';

  @override
  String get productChooseSize => 'Tanlang';

  @override
  String get productChooseSizeSnack => 'O‘lchamni tanlang';

  @override
  String get productColor => 'Rang';

  @override
  String get productDescription => 'Tavsif';

  @override
  String get productDesign => 'Dizayn qilish';

  @override
  String get productPrintMethod => 'Bosma usuli';

  @override
  String get productShare => 'Ulashish';

  @override
  String get productShowLess => 'Yig‘ish';

  @override
  String get productShowMore => 'Batafsil';

  @override
  String get productSize => 'O‘lcham';

  @override
  String get productSoldOut => 'Tugagan';

  @override
  String get productSpecMaterial => 'Material';

  @override
  String get productSpecs => 'Xususiyatlari';

  @override
  String get productVariant => 'Turi';

  @override
  String get productionPacked => 'Qadoqlandi';

  @override
  String get productionPrinted => 'Bosildi';

  @override
  String get productionPrinting => 'Bosilmoqda';

  @override
  String get productionQueued => 'Navbatda';

  @override
  String get profileDeleteAccount => 'Hisobni o‘chirish';

  @override
  String get profileDeleteAccountBody =>
      'Hisobingiz, saqlangan dizaynlaringiz va savatingiz o‘chiriladi. Yakunlangan buyurtmalar hisob-kitob uchun shaxsiy ma’lumotlaringizsiz saqlanib qoladi.\n\nBu amalni ortga qaytarib bo‘lmaydi.';

  @override
  String get profileDeleteAccountDone => 'Hisobingiz o‘chirildi';

  @override
  String get profileDeleteAccountFailed =>
      'Hisobni o‘chirib bo‘lmadi. Qayta urinib ko‘ring';

  @override
  String get profileDeleteAccountSubmit => 'O‘chirish';

  @override
  String get profileDeleteAccountTitle => 'Hisobni o‘chirasizmi?';

  @override
  String get profileEdit => 'Tahrirlash';

  @override
  String get profileEditTitle => 'Profilni tahrirlash';

  @override
  String get profileLastName => 'Familiya';

  @override
  String get profileLinkOpenFailed => 'Havolani ochib bo‘lmadi';

  @override
  String get profileMyOrders => 'Buyurtmalarim';

  @override
  String get profilePhone => 'Telefon';

  @override
  String get profilePhoneIncomplete => 'Telefon raqamini to‘liq kiriting';

  @override
  String get profilePrivacyPolicy => 'Maxfiylik siyosati';

  @override
  String get profileSaved => 'Saqlandi';

  @override
  String get profileSignOut => 'Chiqish';

  @override
  String get profileSignOutConfirm => 'Hisobdan chiqasizmi?';

  @override
  String get profileTelegramConnected => 'Telegram ulandi';

  @override
  String get profileTelegramLink => 'Ulash';

  @override
  String get profileTelegramLinked => 'Ulangan';

  @override
  String get profileTelegramNotConfigured => 'Telegram bot sozlanmagan';

  @override
  String get profileTelegramNotConfirmed => 'Ulanish tasdiqlanmadi';

  @override
  String get profileTelegramOpenFailed => 'Telegram ochilmadi';

  @override
  String get profileTelegramRelink => 'Qayta ulash';

  @override
  String get profileTelegramTitle => 'Telegram xabarnomalari';

  @override
  String get profileTelegramUnlinked => 'Ulanmagan';

  @override
  String get profileTelegramWaiting => 'Kutilmoqda';

  @override
  String get reviewsCity => 'Shahar';

  @override
  String get reviewsEmpty => 'Hali fikr qoldirmagansiz';

  @override
  String get reviewsFormTitle => 'Fikr qoldirish';

  @override
  String reviewsPhotoTooLarge(int size) {
    return 'Surat $size MB dan oshmasin';
  }

  @override
  String get reviewsPhotosOpenFailed => 'Suratlarni ochib bo‘lmadi';

  @override
  String reviewsRatingLabel(int value) {
    return '$value / 5';
  }

  @override
  String get reviewsSend => 'Yuborish';

  @override
  String get reviewsSignIn => 'Fikrlaringizni ko‘rish uchun kiring';

  @override
  String get reviewsStatusApproved => 'Saytda ko‘rinadi';

  @override
  String get reviewsStatusPending => 'Tekshirilmoqda';

  @override
  String get reviewsStatusRejected => 'Rad etilgan';

  @override
  String get reviewsTextLabel => 'Fikringiz';

  @override
  String reviewsTextTooShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kamida $count ta belgi',
      one: 'Kamida $count ta belgi',
    );
    return '$_temp0';
  }

  @override
  String get reviewsTitle => 'Fikrlarim';
}
