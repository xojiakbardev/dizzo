// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Dizzo';

  @override
  String get authEmail => 'Email';

  @override
  String get authEmailInvalid => 'Неверный email';

  @override
  String get authEmailRequired => 'Введите email';

  @override
  String get authFirstName => 'Имя';

  @override
  String get authFirstNameRequired => 'Введите имя';

  @override
  String get authGoogleFailed => 'Не удалось войти через Google';

  @override
  String get authGoogleNoAccount => 'На устройстве нет аккаунта Google';

  @override
  String get authGoogleNoResponse => 'Google не ответил';

  @override
  String get authGoogleNotConfigured => 'Вход через Google пока не настроен';

  @override
  String get authGoogleUnsupported =>
      'Вход через Google недоступен на этом устройстве';

  @override
  String get authGoogleWindowFailed => 'Не удалось открыть окно Google';

  @override
  String get authHaveAccount => 'У меня есть аккаунт';

  @override
  String get authLater => 'Позже';

  @override
  String get authOr => 'или';

  @override
  String get authPassword => 'Пароль';

  @override
  String get authPasswordHide => 'Скрыть';

  @override
  String get authPasswordRequired => 'Введите пароль';

  @override
  String get authPasswordShow => 'Показать';

  @override
  String authPasswordTooShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Минимум $count символа',
      many: 'Минимум $count символов',
      few: 'Минимум $count символа',
      one: 'Минимум $count символ',
    );
    return '$_temp0';
  }

  @override
  String get authPrivacyNotice =>
      'Продолжая, вы принимаете политику конфиденциальности';

  @override
  String get authRegisterSubmit => 'Зарегистрироваться';

  @override
  String get authRegisterSwitch => 'Создать аккаунт';

  @override
  String get authRegisterTitle => 'Регистрация';

  @override
  String get authSignIn => 'Войти';

  @override
  String get authSignInEmail => 'Войти по email';

  @override
  String get authSignInFailed => 'Не удалось войти';

  @override
  String get authSignInGoogle => 'Войти через Google';

  @override
  String get authSignInTelegram => 'Войти через Telegram';

  @override
  String get authSignInTitle => 'Войдите в аккаунт';

  @override
  String get authTelegramConfirm => 'Подтвердите вход в Telegram';

  @override
  String get authTelegramFailed => 'Не удалось войти через Telegram';

  @override
  String get authTelegramReopen => 'Открыть снова';

  @override
  String get authTelegramVerifying => 'Проверяем';

  @override
  String get authWelcomeHeadline => 'Создайте\nсвой дизайн';

  @override
  String get cartBrowseProducts => 'Выбрать товар';

  @override
  String get cartCheckout => 'Оформить';

  @override
  String get cartClear => 'Очистить';

  @override
  String get cartClearConfirm => 'Очистить корзину?';

  @override
  String get cartDecrease => 'Уменьшить';

  @override
  String get cartEditItem => 'Изменить';

  @override
  String get cartEmpty => 'Корзина пуста';

  @override
  String cartImageLabel(int index, int count) {
    return 'Изображение $index из $count';
  }

  @override
  String get cartIncrease => 'Увеличить';

  @override
  String get cartItemActions => 'Действия';

  @override
  String cartItemRemoved(String name) {
    return '$name удалён из корзины';
  }

  @override
  String get cartItemUnavailable => 'Нет в наличии';

  @override
  String cartItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count товара',
      many: '$count товаров',
      few: '$count товара',
      one: '$count товар',
    );
    return '$_temp0';
  }

  @override
  String cartPrintArea(String method, String area) {
    return '$method · $area см²';
  }

  @override
  String get cartQuantity => 'Количество';

  @override
  String get cartQuantityPieces => 'Штук';

  @override
  String cartQuantityRange(int min, int max) {
    return 'От $min до $max';
  }

  @override
  String get cartSignInPrompt => 'Войдите, чтобы увидеть корзину';

  @override
  String get cartSomeUnavailable => 'Некоторых товаров нет в наличии';

  @override
  String get cartTitle => 'Корзина';

  @override
  String get cartTotal => 'Итого';

  @override
  String get cartUndo => 'Вернуть';

  @override
  String cartUnitPrice(String price) {
    return 'За 1 шт.: $price';
  }

  @override
  String get catalogAllCategories => 'Все';

  @override
  String get catalogClearFilter => 'Сбросить фильтр';

  @override
  String get catalogNothingFound => 'Ничего не нашлось';

  @override
  String get catalogPopularBadge => 'Хит';

  @override
  String get catalogSearchClear => 'Очистить';

  @override
  String get catalogSearchHint => 'Поиск';

  @override
  String get catalogTitle => 'Товары';

  @override
  String get checkoutAddressHint => 'Улица, дом, квартира';

  @override
  String get checkoutAddressLabel => 'Адрес';

  @override
  String get checkoutAddressRequired => 'Введите адрес';

  @override
  String get checkoutCartEmpty => 'Корзина пуста';

  @override
  String get checkoutChangeLocation => 'Изменить';

  @override
  String get checkoutChooseProduct => 'Выбрать товар';

  @override
  String get checkoutConfirm => 'Подтвердить';

  @override
  String get checkoutContactTitle => 'Контакты';

  @override
  String get checkoutDelivery => 'Доставка';

  @override
  String get checkoutFree => 'Бесплатно';

  @override
  String get checkoutHome => 'На главную';

  @override
  String checkoutItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count шт.',
      many: '$count шт.',
      few: '$count шт.',
      one: '$count шт.',
    );
    return '$_temp0';
  }

  @override
  String get checkoutLocationDenied => 'Нет доступа к геолокации';

  @override
  String get checkoutLocationFailed => 'Не удалось определить местоположение';

  @override
  String get checkoutLocationOff => 'Геолокация выключена';

  @override
  String get checkoutMapTitle => 'Укажите адрес';

  @override
  String get checkoutMethodTitle => 'Способ получения';

  @override
  String get checkoutMyLocation => 'Моё местоположение';

  @override
  String get checkoutNameLabel => 'Имя и фамилия';

  @override
  String get checkoutNameRequired => 'Введите ваше имя';

  @override
  String get checkoutNoteLabel => 'Комментарий (необязательно)';

  @override
  String get checkoutNoteTitle => 'Комментарий';

  @override
  String get checkoutOperatorQuotes => 'Уточнит оператор';

  @override
  String get checkoutOrderNumber => 'Номер заказа';

  @override
  String get checkoutPhoneIncomplete => 'Введите номер телефона полностью';

  @override
  String get checkoutPhoneLabel => 'Телефон';

  @override
  String get checkoutPickOnMap => 'Указать на карте';

  @override
  String get checkoutPickup => 'Самовывоз';

  @override
  String get checkoutPickupAddress => 'г. Ташкент, Юнусабадский район';

  @override
  String get checkoutPickupHours => 'Пн–Сб, 09:00–20:00';

  @override
  String get checkoutPickupName => 'Производственный центр Dizzo';

  @override
  String get checkoutPlaceOrder => 'Оформить заказ';

  @override
  String get checkoutProducts => 'Товары';

  @override
  String checkoutQuantity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count шт.',
      many: '$count шт.',
      few: '$count шт.',
      one: '$count шт.',
    );
    return '$_temp0';
  }

  @override
  String get checkoutSignInPrompt => 'Войдите, чтобы оформить заказ';

  @override
  String get checkoutSomeUnavailable => 'Некоторых товаров нет в продаже';

  @override
  String get checkoutStatus => 'Статус';

  @override
  String get checkoutSuccessTitle => 'Заказ принят';

  @override
  String get checkoutSummaryTitle => 'Состав заказа';

  @override
  String get checkoutTitle => 'Оформление заказа';

  @override
  String get checkoutTotal => 'Итого';

  @override
  String get checkoutViewOrder => 'Посмотреть заказ';

  @override
  String get commonBack => 'Назад';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonComingSoon => 'Скоро';

  @override
  String get commonCustomer => 'Покупатель';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonDone => 'Готово';

  @override
  String get commonLoading => 'Загрузка';

  @override
  String get commonNo => 'Нет';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonYes => 'Да';

  @override
  String get currencySum => 'сум';

  @override
  String get designsActions => 'Действия';

  @override
  String get designsCreate => 'Создать дизайн';

  @override
  String get designsDeleteConfirm => 'Удалить дизайн?';

  @override
  String get designsDeleted => 'Дизайн удалён';

  @override
  String get designsEdit => 'Изменить';

  @override
  String get designsEmpty => 'Дизайнов пока нет';

  @override
  String get designsNew => 'Новый дизайн';

  @override
  String get designsSignIn => 'Здесь будут ваши сохранённые дизайны';

  @override
  String editorCanvasSizeAngleBadge(String w, String h, String angle) {
    return '$w × $h мм · $angle°';
  }

  @override
  String editorCanvasSizeBadge(String w, String h) {
    return '$w × $h мм';
  }

  @override
  String get editorCropFree => 'Свободно';

  @override
  String get editorCropOriginal => 'Оригинал';

  @override
  String get editorCropTitle => 'Обрезка';

  @override
  String get editorCropZone => 'Зона';

  @override
  String editorDomainIconLabel(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'heart': 'Сердце',
      'heart_straight': 'Сердечко',
      'heart_half': 'Половинка сердца',
      'heart_break': 'Разбитое сердце',
      'heartbeat': 'Сердцебиение',
      'calendar_heart': 'День влюблённых',
      'gift': 'Подарок',
      'confetti': 'Конфетти',
      'balloon': 'Воздушный шар',
      'cake': 'Торт',
      'champagne': 'Шампанское',
      'cheers': 'Бокалы',
      'crown': 'Корона',
      'crown_simple': 'Простая корона',
      'sparkle': 'Искорка',
      'star': 'Звезда',
      'shooting_star': 'Падающая звезда',
      'flower_tulip': 'Тюльпан',
      'envelope_simple': 'Письмо',
      'disco_ball': 'Диско-шар',
      'bell_ringing': 'Колокольчик',
      'baby': 'Малыш',
      'magic_wand': 'Волшебная палочка',
      'treasure_chest': 'Сундук с сокровищами',
      'sun': 'Солнце',
      'sun_horizon': 'Восход',
      'moon': 'Луна',
      'moon_stars': 'Луна и звёзды',
      'cloud': 'Облако',
      'cloud_sun': 'Солнце за облаком',
      'cloud_rain': 'Дождь',
      'cloud_lightning': 'Гроза',
      'snowflake': 'Снежинка',
      'rainbow': 'Радуга',
      'lightning': 'Молния',
      'drop': 'Капля',
      'fire': 'Огонь',
      'leaf': 'Лист',
      'tree': 'Дерево',
      'tree_evergreen': 'Ёлка',
      'tree_palm': 'Пальма',
      'plant': 'Росток',
      'cactus': 'Кактус',
      'flower': 'Цветок',
      'flower_lotus': 'Лотос',
      'clover': 'Клевер',
      'mountains': 'Горы',
      'waves': 'Волны',
      'cat': 'Кошка',
      'dog': 'Собака',
      'paw_print': 'След лапы',
      'bird': 'Птица',
      'fish': 'Рыба',
      'fish_simple': 'Рыбка',
      'butterfly': 'Бабочка',
      'horse': 'Лошадь',
      'rabbit': 'Кролик',
      'cow': 'Корова',
      'bug': 'Насекомое',
      'bug_beetle': 'Жук',
      'shrimp': 'Креветка',
      'feather': 'Перо',
      'bone': 'Кость',
      'coffee': 'Кофе',
      'tea_bag': 'Чай',
      'bowl_steam': 'Горячая миска',
      'cooking_pot': 'Казан',
      'fork_knife': 'Вилка и нож',
      'chef_hat': 'Поварской колпак',
      'pizza': 'Пицца',
      'hamburger': 'Гамбургер',
      'bread': 'Хлеб',
      'egg': 'Яйцо',
      'ice_cream': 'Мороженое',
      'popsicle': 'Эскимо',
      'cookie': 'Печенье',
      'popcorn': 'Попкорн',
      'cherries': 'Вишня',
      'orange_slice': 'Долька апельсина',
      'avocado': 'Авокадо',
      'carrot': 'Морковь',
      'pepper': 'Перец',
      'wine': 'Вино',
      'beer_stein': 'Пивная кружка',
      'martini': 'Коктейль',
      'soccer_ball': 'Футбольный мяч',
      'basketball': 'Баскетбол',
      'volleyball': 'Волейбол',
      'tennis_ball': 'Теннисный мяч',
      'ping_pong': 'Настольный теннис',
      'football': 'Регби',
      'bowling_ball': 'Боулинг',
      'golf': 'Гольф',
      'hockey': 'Хоккей',
      'boxing_glove': 'Боксёрская перчатка',
      'barbell': 'Штанга',
      'trophy': 'Кубок',
      'medal': 'Медаль',
      'flag_checkered': 'Финишный флаг',
      'sneaker': 'Кроссовок',
      'person_simple_run': 'Бегун',
      'person_simple_swim': 'Пловец',
      'person_simple_ski': 'Лыжник',
      'bicycle': 'Велосипед',
      'game_controller': 'Геймпад',
      'puzzle_piece': 'Пазл',
      'dice_five': 'Игральный кубик',
      'airplane': 'Самолёт',
      'car': 'Машина',
      'jeep': 'Джип',
      'taxi': 'Такси',
      'bus': 'Автобус',
      'train': 'Поезд',
      'motorcycle': 'Мотоцикл',
      'boat': 'Корабль',
      'sailboat': 'Парусник',
      'anchor': 'Якорь',
      'lighthouse': 'Маяк',
      'globe_hemisphere_east': 'Земной шар',
      'map_pin': 'Метка на карте',
      'map_trifold': 'Карта',
      'compass': 'Компас',
      'suitcase_rolling': 'Чемодан',
      'backpack': 'Рюкзак',
      'tent': 'Палатка',
      'campfire': 'Костёр',
      'island': 'Остров',
      'sunglasses': 'Солнцезащитные очки',
      'city': 'Город',
      'house': 'Дом',
      'music_note': 'Нота',
      'music_notes': 'Ноты',
      'headphones': 'Наушники',
      'guitar': 'Гитара',
      'microphone': 'Микрофон',
      'microphone_stage': 'Сценический микрофон',
      'piano_keys': 'Пианино',
      'vinyl_record': 'Пластинка',
      'cassette_tape': 'Кассета',
      'radio': 'Радио',
      'palette': 'Палитра',
      'paint_brush': 'Кисть',
      'pen_nib': 'Перьевая ручка',
      'camera': 'Фотоаппарат',
      'video_camera': 'Видеокамера',
      'film_strip': 'Киноплёнка',
      'film_slate': 'Хлопушка',
      'ticket': 'Билет',
      'mask_happy': 'Весёлая маска',
      'mask_sad': 'Грустная маска',
      'book': 'Книга',
      'book_open': 'Открытая книга',
      'books': 'Книги',
      'notebook': 'Тетрадь',
      'graduation_cap': 'Выпускная шапочка',
      'student': 'Ученик',
      'chalkboard_teacher': 'Учитель',
      'pencil': 'Карандаш',
      'pencil_ruler': 'Карандаш и линейка',
      'briefcase': 'Портфель',
      'laptop': 'Ноутбук',
      'lightbulb': 'Лампочка',
      'rocket': 'Ракета',
      'target': 'Мишень',
      'chart_line_up': 'График роста',
      'calendar': 'Календарь',
      'clock': 'Часы',
      'hourglass': 'Песочные часы',
      'atom': 'Атом',
      'flask': 'Колба',
      'globe_stand': 'Глобус',
      'code': 'Код',
      'handshake': 'Рукопожатие',
      'stethoscope': 'Стетоскоп',
      'check_circle': 'Галочка',
      'x_circle': 'Крестик',
      'arrow_fat_right': 'Стрелка',
      'infinity': 'Бесконечность',
      'peace': 'Мир',
      'yin_yang': 'Инь-ян',
      'smiley': 'Улыбка',
      'smiley_wink': 'Подмигивание',
      'smiley_sad': 'Грустный смайлик',
      'smiley_angry': 'Злой смайлик',
      'smiley_melting': 'Тающий смайлик',
      'thumbs_up': 'Лайк',
      'thumbs_down': 'Дизлайк',
      'hand_heart': 'Сердце в руке',
      'hand_peace': 'Знак победы',
      'hand_waving': 'Привет',
      'hands_clapping': 'Аплодисменты',
      'flag': 'Флаг',
      'shield': 'Щит',
      'star_four': 'Четырёхконечная звезда',
      'asterisk': 'Звёздочка',
      'quotes': 'Кавычки',
      'hash': 'Хештег',
      'at': 'Собачка',
      'circle': 'Круг',
      'square': 'Квадрат',
      'triangle': 'Треугольник',
      'hexagon': 'Шестиугольник',
      'diamond': 'Ромб',
      'ghost': 'Привидение',
      'alien': 'Инопланетянин',
      'robot': 'Робот',
      'other': '-',
    });
    return '$_temp0';
  }

  @override
  String get editorDomainLayerElement => 'Элемент';

  @override
  String get editorDomainLayerIcon => 'Иконка';

  @override
  String get editorDomainLayerShape => 'Фигура';

  @override
  String editorDomainMaxHeight(String max) {
    return 'высота — не больше $max мм';
  }

  @override
  String editorDomainMaxWidth(String max) {
    return 'ширина — не больше $max мм';
  }

  @override
  String editorDomainMinFont(String min) {
    return 'шрифт — не меньше $min мм';
  }

  @override
  String editorDomainNoArea(String area) {
    return 'Области «$area» нет в этом варианте';
  }

  @override
  String get editorDomainNoColor => 'этот способ печатает без цвета';

  @override
  String editorDomainNoMethod(String area) {
    return 'В области «$area» нет этого способа печати';
  }

  @override
  String get editorDomainOneMethod =>
      'дизайн печатается одним способом — у этого элемента другой';

  @override
  String get editorDomainOutOfZone => 'выходит за зону печати';

  @override
  String editorDomainProblemAt(String area, String problem) {
    return '$area: $problem';
  }

  @override
  String editorDomainShapeLabel(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'square': 'Квадрат',
      'rounded': 'Скруглённый квадрат',
      'circle': 'Круг',
      'triangle': 'Треугольник',
      'star': 'Звезда',
      'heart': 'Сердце',
      'hexagon': 'Шестиугольник',
      'diamond': 'Ромб',
      'burst': 'Значок',
      'semicircle': 'Полукруг',
      'bubble': 'Облачко реплики',
      'arrow': 'Стрелка',
      'plus': 'Плюс',
      'ring': 'Кольцо',
      'frame': 'Рамка',
      'frame_round': 'Скруглённая рамка',
      'line': 'Линия',
      'line_double': 'Двойная линия',
      'other': '-',
    });
    return '$_temp0';
  }

  @override
  String get editorElementsAll => 'Все';

  @override
  String get editorElementsClear => 'Очистить';

  @override
  String get editorElementsIcons => 'Иконки';

  @override
  String get editorElementsLoadFailed => 'Не удалось загрузить элементы';

  @override
  String get editorElementsNothingFound => 'Ничего не найдено';

  @override
  String get editorElementsPopular => 'Популярное';

  @override
  String get editorElementsSearch => 'Поиск';

  @override
  String get editorElementsShapes => 'Фигуры';

  @override
  String get editorFontSample => 'Привет';

  @override
  String get editorImageCamera => 'Камера';

  @override
  String get editorImageGallery => 'Галерея';

  @override
  String get editorImageOpenFailed => 'Не удалось открыть изображение';

  @override
  String get editorImageUnsupported =>
      'Можно загрузить только PNG, JPG или WEBP';

  @override
  String get editorImageUploadFailed => 'Не удалось загрузить изображение';

  @override
  String get editorLayersEmpty => 'На этой стороне пока нет элементов';

  @override
  String get editorLayersHidden => 'Скрытые';

  @override
  String get editorLayersHide => 'Скрыть';

  @override
  String get editorLayersLock => 'Заблокировать';

  @override
  String get editorLayersOpen => 'Открыть';

  @override
  String get editorLayersShow => 'Показать';

  @override
  String editorLayersSyncedWith(String area) {
    return 'Синхронизировано с «$area»';
  }

  @override
  String get editorLayersUnlock => 'Разблокировать';

  @override
  String get editorMain3dFailed => 'Не удалось открыть 3D-вид';

  @override
  String get editorMain3dLoading => 'Загружаем 3D-модель…';

  @override
  String get editorMain3dView => '3D-вид';

  @override
  String get editorMainActions => 'Действия';

  @override
  String get editorMainAddSomethingFirst => 'Сначала добавьте фото или текст';

  @override
  String get editorMainAddToCart => 'В корзину';

  @override
  String get editorMainAddToCartFailed => 'Не удалось добавить в корзину';

  @override
  String editorMainAreaNoMethod(String area) {
    return 'Для области «$area» этот способ недоступен';
  }

  @override
  String editorMainAreaNoMethodClear(String area) {
    return 'Для области «$area» этот способ недоступен — уберите оттуда элементы';
  }

  @override
  String get editorMainAreaSynced => 'Эта сторона синхронизирована с другой';

  @override
  String editorMainAreaSyncedWith(String area) {
    return 'Эта сторона синхронизирована с «$area» — редактируйте там';
  }

  @override
  String get editorMainBadImage => 'Некорректное изображение';

  @override
  String get editorMainBringForward => 'Вперёд';

  @override
  String get editorMainCannotAddHere => 'В эту область ничего нельзя добавить';

  @override
  String get editorMainCapture => 'Снимок';

  @override
  String get editorMainCenter => 'Центр';

  @override
  String get editorMainCopy => 'Копия';

  @override
  String editorMainCroppedBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count обрежутся',
      many: '$count обрежутся',
      few: '$count обрежутся',
      one: '$count обрежется',
    );
    return '$_temp0';
  }

  @override
  String get editorMainDuplicate => 'Дублировать';

  @override
  String get editorMainEditTextShort => 'Текст';

  @override
  String get editorMainEngineBroken => '3D-вид не работает';

  @override
  String get editorMainEngineClosed => 'Закрыто';

  @override
  String get editorMainEngineConnectFailed =>
      'Не удалось подключиться к 3D-виду';

  @override
  String get editorMainEngineLoadFailed => '3D-вид не загрузился';

  @override
  String get editorMainEngineNoAnswer => '3D-вид не отвечает';

  @override
  String get editorMainEngineNotReady => '3D-вид ещё не готов';

  @override
  String get editorMainEngineReloaded => '3D-вид перезагружен';

  @override
  String get editorMainEngineStartFailed => 'Не удалось запустить 3D-вид';

  @override
  String get editorMainError => 'Ошибка';

  @override
  String editorMainErrorsBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ошибки',
      many: '$count ошибок',
      few: '$count ошибки',
      one: '$count ошибка',
    );
    return '$_temp0';
  }

  @override
  String editorMainFileSaveFailed(String status) {
    return 'Не удалось сохранить файл ($status). Попробуйте ещё раз.';
  }

  @override
  String get editorMainFixRedItems => 'Исправьте элементы, отмеченные красным';

  @override
  String get editorMainFlatView => 'Плоский вид';

  @override
  String get editorMainHide => 'Скрыть';

  @override
  String get editorMainLock => 'Закрепить';

  @override
  String get editorMainLocked => 'Закреплён';

  @override
  String get editorMainMenuEditText => 'Изменить текст';

  @override
  String editorMainMethodSwitched(String method) {
    return 'Дизайн переведён на «$method»';
  }

  @override
  String get editorMainNoPrintFile => 'Не удалось создать файл для печати';

  @override
  String get editorMainNoViews => 'Не удалось сделать снимки';

  @override
  String get editorMainNotSaved => 'Не сохранено';

  @override
  String get editorMainPickSizeFirst => 'Сначала выберите размер';

  @override
  String get editorMainPickTool => 'Выберите инструмент';

  @override
  String get editorMainPriceRecalculated => 'Цена пересчитана';

  @override
  String get editorMainProductColor => 'Цвет товара';

  @override
  String get editorMainProductColorBackground => 'Фон в цвет товара';

  @override
  String get editorMainRedo => 'Повторить';

  @override
  String get editorMainReloadedNewer =>
      'Дизайн изменили на другом устройстве — загрузили последнюю версию';

  @override
  String get editorMainResetView => 'Сбросить вид';

  @override
  String get editorMainSaveFailed => 'Не удалось сохранить';

  @override
  String get editorMainSaveFailedOffline =>
      'Не удалось сохранить. Проверьте интернет';

  @override
  String get editorMainSaved => 'Дизайн сохранён';

  @override
  String get editorMainSendBackward => 'Назад';

  @override
  String get editorMainSettings => 'Настроить';

  @override
  String get editorMainStepAddingToCart => 'Добавляем в корзину…';

  @override
  String get editorMainStepPrintFiles => 'Готовим файлы для печати…';

  @override
  String get editorMainStepSaving => 'Сохраняем дизайн…';

  @override
  String editorMainStepUploading(int current, int total) {
    return 'Загружаем… $current/$total';
  }

  @override
  String get editorMainStepViews => 'Делаем снимки…';

  @override
  String editorMainSyncedFrom(String area) {
    return 'Синхронно с «$area»';
  }

  @override
  String editorMainTemplateApplied(String name) {
    return 'Шаблон «$name» применён';
  }

  @override
  String get editorMainTextPlaceholder => 'Ваш текст здесь';

  @override
  String get editorMainTitle => 'Создание дизайна';

  @override
  String editorMainTooManyLayers(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'В одном дизайне может быть не больше $max элемента',
      many: 'В одном дизайне может быть не больше $max элементов',
      few: 'В одном дизайне может быть не больше $max элементов',
      one: 'В одном дизайне может быть не больше $max элемента',
    );
    return '$_temp0';
  }

  @override
  String get editorMainToolBackground => 'Фон';

  @override
  String get editorMainToolElements => 'Элементы';

  @override
  String get editorMainToolGallery => 'Галерея';

  @override
  String get editorMainToolImage => 'Фото';

  @override
  String get editorMainToolLayers => 'Слои';

  @override
  String get editorMainToolText => 'Текст';

  @override
  String get editorMainUndo => 'Отменить';

  @override
  String get editorMainUndoAction => 'Отменить';

  @override
  String get editorMainUnknownError => 'Неизвестная ошибка';

  @override
  String get editorMainUnlock => 'Открепить';

  @override
  String get editorMainVariantNoMethod =>
      'Для этого варианта этот способ недоступен';

  @override
  String get editorMainVariantReplaced =>
      'Выбранного ранее варианта сейчас нет в продаже — мы подобрали другой';

  @override
  String get editorPropsAlignCenter => 'По центру';

  @override
  String get editorPropsAlignLeft => 'По левому краю';

  @override
  String get editorPropsAlignRight => 'По правому краю';

  @override
  String get editorPropsBackground => 'Фон';

  @override
  String get editorPropsBold => 'Жирный';

  @override
  String get editorPropsCenterX => 'По центру (ширина)';

  @override
  String get editorPropsCenterY => 'По центру (высота)';

  @override
  String get editorPropsColor => 'Цвет';

  @override
  String get editorPropsCropped => 'Часть за пределами зоны не напечатается';

  @override
  String get editorPropsDialNumerals => 'Цифры циферблата';

  @override
  String get editorPropsFontSize => 'Размер шрифта';

  @override
  String get editorPropsImage => 'Изображение';

  @override
  String get editorPropsItalic => 'Курсив';

  @override
  String get editorPropsLowQuality => 'Низкое качество изображения';

  @override
  String get editorPropsMinuteTicks => 'Минутные деления';

  @override
  String editorPropsMm(String value) {
    return '$value мм';
  }

  @override
  String get editorPropsNumeralsNone => 'Нет';

  @override
  String get editorPropsRemoveBackground => 'Убрать фон';

  @override
  String get editorPropsRotation => 'Поворот';

  @override
  String get editorPropsSize => 'Размер';

  @override
  String get editorPropsSticker => 'Стикер';

  @override
  String get editorPropsStraighten => 'Выровнять';

  @override
  String get editorSheet3dNotReady => '3D-вид ещё не готов';

  @override
  String get editorSheetAddAtPrice => 'Добавить по этой цене';

  @override
  String get editorSheetAddedToCart => 'Добавлено в корзину';

  @override
  String get editorSheetCapture => 'Сделать снимок';

  @override
  String get editorSheetCaptureFailed => 'Не удалось сделать снимок';

  @override
  String get editorSheetClear => 'Очистить';

  @override
  String editorSheetClearConfirm(int count, String area) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалить $count элемента со стороны «$area»?',
      many: 'Удалить $count элементов со стороны «$area»?',
      few: 'Удалить $count элемента со стороны «$area»?',
      one: 'Удалить $count элемент со стороны «$area»?',
    );
    return '$_temp0';
  }

  @override
  String get editorSheetClearSide => 'Очистить сторону';

  @override
  String editorSheetClearSideCount(int count) {
    return 'Очистить сторону ($count)';
  }

  @override
  String editorSheetColorNamed(String name) {
    return 'Цвет: $name';
  }

  @override
  String get editorSheetContinue => 'Продолжить';

  @override
  String get editorSheetCurrentView => 'Текущий вид';

  @override
  String get editorSheetGalleryDenied => 'Нет доступа к галерее';

  @override
  String get editorSheetGallerySaveFailed => 'Не удалось сохранить в галерею';

  @override
  String get editorSheetGoToCart => 'Перейти в корзину';

  @override
  String get editorSheetGrid => 'Сетка';

  @override
  String get editorSheetImageSaved => 'Снимок сохранён';

  @override
  String editorSheetImagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count снимка',
      many: '$count снимков',
      few: '$count снимка',
      one: '$count снимок',
    );
    return '$_temp0';
  }

  @override
  String editorSheetImagesSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count снимка сохранены',
      many: '$count снимков сохранены',
      few: '$count снимка сохранены',
      one: '$count снимок сохранён',
    );
    return '$_temp0';
  }

  @override
  String get editorSheetLinkedElsewhere => 'уже связана с другими сторонами';

  @override
  String editorSheetLostElements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элемента не поместятся в этом варианте',
      many: '$count элементов не поместятся в этом варианте',
      few: '$count элемента не поместятся в этом варианте',
      one: '$count элемент не поместится в этом варианте',
    );
    return '$_temp0';
  }

  @override
  String editorSheetMirrored(String name) {
    return '$name (зеркально)';
  }

  @override
  String editorSheetOwnHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Будут скрыты $count её элемента',
      many: 'Будут скрыты $count её элементов',
      few: 'Будут скрыты $count её элемента',
      one: 'Будет скрыт $count её элемент',
    );
    return '$_temp0';
  }

  @override
  String get editorSheetPrice => 'Цена';

  @override
  String get editorSheetPriceRecalculated =>
      'Цена пересчитана по файлам для печати';

  @override
  String get editorSheetPrintMethod => 'Способ печати';

  @override
  String get editorSheetProduct => 'Товар';

  @override
  String get editorSheetReplace => 'Сменить';

  @override
  String get editorSheetSelfSynced =>
      'Эта сторона сама синхронизирована с другой';

  @override
  String get editorSheetShare => 'Поделиться';

  @override
  String get editorSheetSides => 'Стороны';

  @override
  String get editorSheetSize => 'Размер';

  @override
  String get editorSheetSnapping => 'Привязка';

  @override
  String get editorSheetSync => 'Синхронизация';

  @override
  String editorSheetSyncedFrom(String area) {
    return 'Синхронизировано с «$area»';
  }

  @override
  String editorSheetSyncedTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Дублируется на $count стороны',
      many: 'Дублируется на $count сторон',
      few: 'Дублируется на $count стороны',
      one: 'Дублируется на $count сторону',
    );
    return '$_temp0';
  }

  @override
  String get editorSheetText => 'Текст';

  @override
  String get editorSheetToGallery => 'В галерею';

  @override
  String get editorSheetType => 'Вариант';

  @override
  String get editorTemplatesEmpty => 'Для этого варианта шаблонов нет';

  @override
  String get editorTextAdd => 'Добавить текст';

  @override
  String get editorTextBestDad => 'Лучший папа';

  @override
  String get editorTextBigHeading => 'БОЛЬШОЙ ЗАГОЛОВОК';

  @override
  String get editorTextBirthday => 'С днём рождения!';

  @override
  String get editorTextCongrats => 'Поздравляю!';

  @override
  String get editorTextElegant => 'Изящный заголовок';

  @override
  String get editorTextFonts => 'Шрифты';

  @override
  String get editorTextGoodDays => 'Всего доброго';

  @override
  String get editorTextHeading => 'Заголовок';

  @override
  String get editorTextPlaceholder => 'Ваш текст здесь';

  @override
  String get editorTextSubheading => 'Подзаголовок';

  @override
  String get editorTextWithLove => 'С любовью';

  @override
  String get errorCancelled => 'Отменено';

  @override
  String get errorForbidden => 'Нет доступа';

  @override
  String get errorGeneric => 'Что-то пошло не так';

  @override
  String get errorInsecure => 'Не удалось установить защищённое соединение';

  @override
  String get errorNoInternet => 'Нет подключения к интернету';

  @override
  String get errorNotFound => 'Не найдено';

  @override
  String get errorServer => 'Ошибка сервера';

  @override
  String get errorSignInAgain => 'Войдите снова';

  @override
  String get errorTimeout => 'Сервер не ответил';

  @override
  String get homeCategories => 'Категории';

  @override
  String get homeChooseProduct => 'Выберите товар';

  @override
  String get homeCreateDesign => 'Создать дизайн';

  @override
  String get homeGallery => 'Галерея';

  @override
  String get homeHeroTitle => 'Кружки, футболки, часы —\nс вашим дизайном';

  @override
  String get homeNoProducts => 'Товаров пока нет';

  @override
  String get homeSearch => 'Поиск';

  @override
  String get homeSeeAll => 'Все';

  @override
  String get languageChoose => 'Выберите язык';

  @override
  String get languageSystemHint => 'Язык приложения';

  @override
  String get languageTitle => 'Язык';

  @override
  String get materialCeramicGlossy => 'Керамика, глянцевая';

  @override
  String get materialCeramicMatte => 'Керамика, матовая';

  @override
  String get materialFabric => 'Ткань';

  @override
  String get materialGlassClear => 'Стекло, прозрачное';

  @override
  String get materialGlassFrosted => 'Стекло, матовое';

  @override
  String get materialMetal => 'Металл';

  @override
  String get materialPaper => 'Бумага';

  @override
  String get materialPlastic => 'Пластик';

  @override
  String get materialWood => 'Дерево';

  @override
  String get navCart => 'Корзина';

  @override
  String get navDesigns => 'Мои дизайны';

  @override
  String get navHome => 'Главная';

  @override
  String get navProducts => 'Товары';

  @override
  String get navProfile => 'Профиль';

  @override
  String get orderNextInProduction => 'Ваш заказ изготавливается';

  @override
  String get orderNextNew => 'Оператор скоро свяжется с вами';

  @override
  String get orderNextPaid => 'Скоро передадим в производство';

  @override
  String get orderNextPaymentPending => 'Ждём вашу оплату';

  @override
  String get orderNextQualityCheck => 'Проверяем качество';

  @override
  String get orderNextReadyForDelivery => 'Скоро доставим';

  @override
  String get orderNextReadyForPickup => 'Можно забирать';

  @override
  String get orderStatusCancelled => 'Отменён';

  @override
  String get orderStatusCompleted => 'Завершён';

  @override
  String get orderStatusInProduction => 'В производстве';

  @override
  String get orderStatusNew => 'Новый';

  @override
  String get orderStatusPaid => 'Оплачен';

  @override
  String get orderStatusPaymentPending => 'Ожидает оплаты';

  @override
  String get orderStatusQualityCheck => 'Проверка качества';

  @override
  String get orderStatusReadyForDelivery => 'Готов к доставке';

  @override
  String get orderStatusReadyForPickup => 'Готов к выдаче';

  @override
  String get orderStatusReadyForProduction => 'Готов к производству';

  @override
  String get orderStepAccepted => 'Принят';

  @override
  String get orderStepDone => 'Завершён';

  @override
  String get orderStepPayment => 'Оплата';

  @override
  String get orderStepProduction => 'Производство';

  @override
  String get orderStepReady => 'Готов';

  @override
  String get ordersAll => 'Все заказы';

  @override
  String get ordersCancelAction => 'Отменить';

  @override
  String get ordersCancelConfirm => 'Отменить заказ?';

  @override
  String get ordersCancelKeep => 'Нет';

  @override
  String get ordersCancelled => 'Заказ отменён';

  @override
  String get ordersCancelledBanner => 'Заказ отменён';

  @override
  String get ordersChooseProduct => 'Выбрать товар';

  @override
  String ordersDetailTitle(String number) {
    return 'Заказ №$number';
  }

  @override
  String get ordersDiscount => 'Скидка';

  @override
  String get ordersEmpty => 'Заказов пока нет';

  @override
  String get ordersFree => 'Бесплатно';

  @override
  String ordersItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count товара',
      many: '$count товаров',
      few: '$count товара',
      one: '$count товар',
    );
    return '$_temp0';
  }

  @override
  String get ordersItems => 'Товары';

  @override
  String get ordersLeaveReview => 'Оставить отзыв';

  @override
  String get ordersMore => 'Ещё';

  @override
  String get ordersNotFound => 'Заказ не найден';

  @override
  String ordersNumber(String number) {
    return '№$number';
  }

  @override
  String get ordersOnlyNewCancellable => 'Только новый заказ';

  @override
  String get ordersPayment => 'Оплата';

  @override
  String get ordersPickup => 'Самовывоз';

  @override
  String ordersPieces(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count шт.',
      many: '$count шт.',
      few: '$count шт.',
      one: '$count шт.',
    );
    return '$_temp0';
  }

  @override
  String get ordersReviewSent => 'Отзыв отправлен';

  @override
  String get ordersShipping => 'Доставка';

  @override
  String get ordersShippingTbd => 'По договорённости';

  @override
  String get ordersShowMore => 'Показать ещё';

  @override
  String get ordersSignInPrompt => 'Войдите, чтобы увидеть заказы';

  @override
  String get ordersStatAwaitingPayment => 'Ждут оплаты';

  @override
  String get ordersStatInProduction => 'В производстве';

  @override
  String get ordersStatSpent => 'Потрачено';

  @override
  String get ordersStatTotal => 'Всего заказов';

  @override
  String get ordersTelegram => 'Написать в Telegram';

  @override
  String get ordersTitle => 'Мои заказы';

  @override
  String get ordersTotal => 'Итого';

  @override
  String get paymentUnpaid => 'Не оплачен';

  @override
  String priceFrom(String price) {
    return 'от $price';
  }

  @override
  String get printMethodEngrave => 'Лазерная гравировка';

  @override
  String get printMethodUv => 'Цветная печать';

  @override
  String get product3dLoading => 'Загружаем 3D-модель…';

  @override
  String get product3dOpenFailed => 'Не удалось открыть 3D-просмотр';

  @override
  String get product3dResetView => 'Сбросить вид';

  @override
  String get product3dView => '3D-просмотр';

  @override
  String get productChooseSize => 'Выберите';

  @override
  String get productChooseSizeSnack => 'Выберите размер';

  @override
  String get productColor => 'Цвет';

  @override
  String get productDescription => 'Описание';

  @override
  String get productDesign => 'Создать дизайн';

  @override
  String get productPrintMethod => 'Способ печати';

  @override
  String get productShare => 'Поделиться';

  @override
  String get productShowLess => 'Свернуть';

  @override
  String get productShowMore => 'Подробнее';

  @override
  String get productSize => 'Размер';

  @override
  String get productSoldOut => 'Нет в наличии';

  @override
  String get productSpecMaterial => 'Материал';

  @override
  String get productSpecs => 'Характеристики';

  @override
  String get productVariant => 'Вид';

  @override
  String get productionPacked => 'Упаковано';

  @override
  String get productionPrinted => 'Напечатано';

  @override
  String get productionPrinting => 'Печатается';

  @override
  String get productionQueued => 'В очереди';

  @override
  String get profileDeleteAccount => 'Удалить аккаунт';

  @override
  String get profileDeleteAccountBody =>
      'Будут удалены ваш аккаунт, сохранённые дизайны и корзина. Завершённые заказы останутся для бухгалтерского учёта, но без ваших личных данных.\n\nЭто действие нельзя отменить.';

  @override
  String get profileDeleteAccountDone => 'Ваш аккаунт удалён';

  @override
  String get profileDeleteAccountFailed =>
      'Не удалось удалить аккаунт. Попробуйте ещё раз';

  @override
  String get profileDeleteAccountSubmit => 'Удалить';

  @override
  String get profileDeleteAccountTitle => 'Удалить аккаунт?';

  @override
  String get profileEdit => 'Изменить';

  @override
  String get profileEditTitle => 'Редактировать профиль';

  @override
  String get profileLastName => 'Фамилия';

  @override
  String get profileLinkOpenFailed => 'Не удалось открыть ссылку';

  @override
  String get profileMyOrders => 'Мои заказы';

  @override
  String get profilePhone => 'Телефон';

  @override
  String get profilePhoneIncomplete => 'Введите номер телефона полностью';

  @override
  String get profilePrivacyPolicy => 'Политика конфиденциальности';

  @override
  String get profileSaved => 'Сохранено';

  @override
  String get profileSignOut => 'Выйти';

  @override
  String get profileSignOutConfirm => 'Выйти из аккаунта?';

  @override
  String get profileTelegramConnected => 'Telegram подключён';

  @override
  String get profileTelegramLink => 'Подключить';

  @override
  String get profileTelegramLinked => 'Подключено';

  @override
  String get profileTelegramNotConfigured => 'Telegram-бот не настроен';

  @override
  String get profileTelegramNotConfirmed => 'Подключение не подтверждено';

  @override
  String get profileTelegramOpenFailed => 'Не удалось открыть Telegram';

  @override
  String get profileTelegramRelink => 'Переподключить';

  @override
  String get profileTelegramTitle => 'Уведомления в Telegram';

  @override
  String get profileTelegramUnlinked => 'Не подключено';

  @override
  String get profileTelegramWaiting => 'Ожидаем';

  @override
  String get reviewsCity => 'Город';

  @override
  String get reviewsEmpty => 'Вы ещё не оставляли отзывов';

  @override
  String get reviewsFormTitle => 'Оставить отзыв';

  @override
  String reviewsPhotoTooLarge(int size) {
    return 'Фото должно быть не больше $size МБ';
  }

  @override
  String get reviewsPhotosOpenFailed => 'Не удалось открыть фото';

  @override
  String reviewsRatingLabel(int value) {
    return 'Оценка $value из 5';
  }

  @override
  String get reviewsSend => 'Отправить';

  @override
  String get reviewsSignIn => 'Войдите, чтобы увидеть свои отзывы';

  @override
  String get reviewsStatusApproved => 'Опубликован';

  @override
  String get reviewsStatusPending => 'На проверке';

  @override
  String get reviewsStatusRejected => 'Отклонён';

  @override
  String get reviewsTextLabel => 'Ваш отзыв';

  @override
  String reviewsTextTooShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Минимум $count символа',
      many: 'Минимум $count символов',
      few: 'Минимум $count символа',
      one: 'Минимум $count символ',
    );
    return '$_temp0';
  }

  @override
  String get reviewsTitle => 'Мои отзывы';
}
