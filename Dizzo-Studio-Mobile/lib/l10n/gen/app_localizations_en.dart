// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Dizzo';

  @override
  String get authEmail => 'Email';

  @override
  String get authEmailInvalid => 'That email doesn’t look right';

  @override
  String get authEmailRequired => 'Enter your email';

  @override
  String get authFirstName => 'First name';

  @override
  String get authFirstNameRequired => 'Enter your name';

  @override
  String get authGoogleFailed => 'Couldn’t sign in with Google';

  @override
  String get authGoogleNoAccount => 'No Google account on this device';

  @override
  String get authGoogleNoResponse => 'Google didn’t respond';

  @override
  String get authGoogleNotConfigured => 'Google sign-in isn’t set up yet';

  @override
  String get authGoogleUnsupported =>
      'Google sign-in isn’t available on this device';

  @override
  String get authGoogleWindowFailed => 'Couldn’t open the Google window';

  @override
  String get authHaveAccount => 'I have an account';

  @override
  String get authLater => 'Later';

  @override
  String get authOr => 'or';

  @override
  String get authPassword => 'Password';

  @override
  String get authPasswordHide => 'Hide';

  @override
  String get authPasswordRequired => 'Enter your password';

  @override
  String get authPasswordShow => 'Show';

  @override
  String authPasswordTooShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'At least $count characters',
      one: 'At least $count character',
    );
    return '$_temp0';
  }

  @override
  String get authPrivacyNotice => 'By continuing you accept the privacy policy';

  @override
  String get authRegisterSubmit => 'Sign up';

  @override
  String get authRegisterSwitch => 'Create an account';

  @override
  String get authRegisterTitle => 'Create an account';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignInEmail => 'Sign in with email';

  @override
  String get authSignInFailed => 'Sign-in failed';

  @override
  String get authSignInGoogle => 'Sign in with Google';

  @override
  String get authSignInTelegram => 'Sign in with Telegram';

  @override
  String get authSignInTitle => 'Sign in to your account';

  @override
  String get authTelegramConfirm => 'Confirm in Telegram';

  @override
  String get authTelegramFailed => 'Couldn’t sign in with Telegram';

  @override
  String get authTelegramReopen => 'Open again';

  @override
  String get authTelegramVerifying => 'Verifying';

  @override
  String get authWelcomeHeadline => 'Create your\nown design';

  @override
  String get cartBrowseProducts => 'Browse products';

  @override
  String get cartCheckout => 'Checkout';

  @override
  String get cartClear => 'Clear';

  @override
  String get cartClearConfirm => 'Empty your cart?';

  @override
  String get cartDecrease => 'Decrease';

  @override
  String get cartEditItem => 'Edit';

  @override
  String get cartEmpty => 'Your cart is empty';

  @override
  String cartImageLabel(int index, int count) {
    return 'Image $index of $count';
  }

  @override
  String get cartIncrease => 'Increase';

  @override
  String get cartItemActions => 'Actions';

  @override
  String cartItemRemoved(String name) {
    return '$name removed from your cart';
  }

  @override
  String get cartItemUnavailable => 'Out of stock';

  @override
  String cartItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String cartPrintArea(String method, String area) {
    return '$method · $area cm²';
  }

  @override
  String get cartQuantity => 'Quantity';

  @override
  String get cartQuantityPieces => 'Pieces';

  @override
  String cartQuantityRange(int min, int max) {
    return 'From $min to $max';
  }

  @override
  String get cartSignInPrompt => 'Sign in to see your cart';

  @override
  String get cartSomeUnavailable => 'Some items are out of stock';

  @override
  String get cartTitle => 'Cart';

  @override
  String get cartTotal => 'Total';

  @override
  String get cartUndo => 'Undo';

  @override
  String cartUnitPrice(String price) {
    return 'Each: $price';
  }

  @override
  String get catalogAllCategories => 'All';

  @override
  String get catalogClearFilter => 'Clear filter';

  @override
  String get catalogNothingFound => 'Nothing found';

  @override
  String get catalogPopularBadge => 'Popular';

  @override
  String get catalogSearchClear => 'Clear';

  @override
  String get catalogSearchHint => 'Search';

  @override
  String get catalogTitle => 'Products';

  @override
  String get checkoutAddressHint => 'Street, building, apartment';

  @override
  String get checkoutAddressLabel => 'Address';

  @override
  String get checkoutAddressRequired => 'Enter your address';

  @override
  String get checkoutCartEmpty => 'Your cart is empty';

  @override
  String get checkoutChangeLocation => 'Change';

  @override
  String get checkoutChooseProduct => 'Browse products';

  @override
  String get checkoutConfirm => 'Confirm';

  @override
  String get checkoutContactTitle => 'Contact';

  @override
  String get checkoutDelivery => 'Delivery';

  @override
  String get checkoutFree => 'Free';

  @override
  String get checkoutHome => 'Back to home';

  @override
  String checkoutItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String get checkoutLocationDenied => 'Location permission denied';

  @override
  String get checkoutLocationFailed => 'Couldn’t find your location';

  @override
  String get checkoutLocationOff => 'Location services are off';

  @override
  String get checkoutMapTitle => 'Set your address';

  @override
  String get checkoutMethodTitle => 'How to get it';

  @override
  String get checkoutMyLocation => 'My location';

  @override
  String get checkoutNameLabel => 'Full name';

  @override
  String get checkoutNameRequired => 'Enter your name';

  @override
  String get checkoutNoteLabel => 'Note (optional)';

  @override
  String get checkoutNoteTitle => 'Note';

  @override
  String get checkoutOperatorQuotes => 'Confirmed by phone';

  @override
  String get checkoutOrderNumber => 'Order number';

  @override
  String get checkoutPhoneIncomplete => 'Enter the full phone number';

  @override
  String get checkoutPhoneLabel => 'Phone';

  @override
  String get checkoutPickOnMap => 'Pick on the map';

  @override
  String get checkoutPickup => 'Pickup';

  @override
  String get checkoutPickupAddress => 'Yunusabad district, Tashkent';

  @override
  String get checkoutPickupHours => 'Mon–Sat, 09:00–20:00';

  @override
  String get checkoutPickupName => 'Dizzo production centre';

  @override
  String get checkoutPlaceOrder => 'Place order';

  @override
  String get checkoutProducts => 'Items';

  @override
  String checkoutQuantity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pcs',
      one: '$count pc',
    );
    return '$_temp0';
  }

  @override
  String get checkoutSignInPrompt => 'Sign in to place an order';

  @override
  String get checkoutSomeUnavailable => 'Some items are no longer available';

  @override
  String get checkoutStatus => 'Status';

  @override
  String get checkoutSuccessTitle => 'Order placed';

  @override
  String get checkoutSummaryTitle => 'Order summary';

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get checkoutTotal => 'Total';

  @override
  String get checkoutViewOrder => 'View order';

  @override
  String get commonBack => 'Back';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonComingSoon => 'Coming soon';

  @override
  String get commonCustomer => 'Customer';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonDone => 'Done';

  @override
  String get commonLoading => 'Loading';

  @override
  String get commonNo => 'No';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonSave => 'Save';

  @override
  String get commonYes => 'Yes';

  @override
  String get currencySum => 'UZS';

  @override
  String get designsActions => 'Actions';

  @override
  String get designsCreate => 'Create a design';

  @override
  String get designsDeleteConfirm => 'Delete this design?';

  @override
  String get designsDeleted => 'Design deleted';

  @override
  String get designsEdit => 'Edit';

  @override
  String get designsEmpty => 'No designs yet';

  @override
  String get designsNew => 'New design';

  @override
  String get designsSignIn => 'Your saved designs live here';

  @override
  String editorCanvasSizeAngleBadge(String w, String h, String angle) {
    return '$w × $h mm · $angle°';
  }

  @override
  String editorCanvasSizeBadge(String w, String h) {
    return '$w × $h mm';
  }

  @override
  String get editorCropFree => 'Free';

  @override
  String get editorCropOriginal => 'Original';

  @override
  String get editorCropTitle => 'Crop';

  @override
  String get editorCropZone => 'Zone';

  @override
  String editorDomainIconLabel(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'heart': 'Heart',
      'heart_straight': 'Little heart',
      'heart_half': 'Half heart',
      'heart_break': 'Broken heart',
      'heartbeat': 'Heartbeat',
      'calendar_heart': 'Valentine’s Day',
      'gift': 'Gift',
      'confetti': 'Confetti',
      'balloon': 'Balloon',
      'cake': 'Cake',
      'champagne': 'Champagne',
      'cheers': 'Cheers',
      'crown': 'Crown',
      'crown_simple': 'Simple crown',
      'sparkle': 'Sparkle',
      'star': 'Star',
      'shooting_star': 'Shooting star',
      'flower_tulip': 'Tulip',
      'envelope_simple': 'Letter',
      'disco_ball': 'Disco ball',
      'bell_ringing': 'Bell',
      'baby': 'Baby',
      'magic_wand': 'Magic wand',
      'treasure_chest': 'Treasure chest',
      'sun': 'Sun',
      'sun_horizon': 'Sunrise',
      'moon': 'Moon',
      'moon_stars': 'Moon and stars',
      'cloud': 'Cloud',
      'cloud_sun': 'Partly sunny',
      'cloud_rain': 'Rain',
      'cloud_lightning': 'Thunderstorm',
      'snowflake': 'Snowflake',
      'rainbow': 'Rainbow',
      'lightning': 'Lightning',
      'drop': 'Drop',
      'fire': 'Fire',
      'leaf': 'Leaf',
      'tree': 'Tree',
      'tree_evergreen': 'Fir tree',
      'tree_palm': 'Palm tree',
      'plant': 'Sprout',
      'cactus': 'Cactus',
      'flower': 'Flower',
      'flower_lotus': 'Lotus',
      'clover': 'Clover',
      'mountains': 'Mountains',
      'waves': 'Waves',
      'cat': 'Cat',
      'dog': 'Dog',
      'paw_print': 'Paw print',
      'bird': 'Bird',
      'fish': 'Fish',
      'fish_simple': 'Little fish',
      'butterfly': 'Butterfly',
      'horse': 'Horse',
      'rabbit': 'Rabbit',
      'cow': 'Cow',
      'bug': 'Bug',
      'bug_beetle': 'Beetle',
      'shrimp': 'Shrimp',
      'feather': 'Feather',
      'bone': 'Bone',
      'coffee': 'Coffee',
      'tea_bag': 'Tea',
      'bowl_steam': 'Hot bowl',
      'cooking_pot': 'Cooking pot',
      'fork_knife': 'Fork and knife',
      'chef_hat': 'Chef’s hat',
      'pizza': 'Pizza',
      'hamburger': 'Burger',
      'bread': 'Bread',
      'egg': 'Egg',
      'ice_cream': 'Ice cream',
      'popsicle': 'Ice lolly',
      'cookie': 'Biscuit',
      'popcorn': 'Popcorn',
      'cherries': 'Cherries',
      'orange_slice': 'Orange slice',
      'avocado': 'Avocado',
      'carrot': 'Carrot',
      'pepper': 'Pepper',
      'wine': 'Wine',
      'beer_stein': 'Beer mug',
      'martini': 'Cocktail',
      'soccer_ball': 'Football',
      'basketball': 'Basketball',
      'volleyball': 'Volleyball',
      'tennis_ball': 'Tennis ball',
      'ping_pong': 'Table tennis',
      'football': 'Rugby',
      'bowling_ball': 'Bowling',
      'golf': 'Golf',
      'hockey': 'Hockey',
      'boxing_glove': 'Boxing glove',
      'barbell': 'Barbell',
      'trophy': 'Trophy',
      'medal': 'Medal',
      'flag_checkered': 'Finish flag',
      'sneaker': 'Trainer',
      'person_simple_run': 'Runner',
      'person_simple_swim': 'Swimmer',
      'person_simple_ski': 'Skier',
      'bicycle': 'Bicycle',
      'game_controller': 'Game controller',
      'puzzle_piece': 'Puzzle piece',
      'dice_five': 'Dice',
      'airplane': 'Aeroplane',
      'car': 'Car',
      'jeep': 'Jeep',
      'taxi': 'Taxi',
      'bus': 'Bus',
      'train': 'Train',
      'motorcycle': 'Motorbike',
      'boat': 'Ship',
      'sailboat': 'Sailing boat',
      'anchor': 'Anchor',
      'lighthouse': 'Lighthouse',
      'globe_hemisphere_east': 'Earth',
      'map_pin': 'Map pin',
      'map_trifold': 'Map',
      'compass': 'Compass',
      'suitcase_rolling': 'Suitcase',
      'backpack': 'Backpack',
      'tent': 'Tent',
      'campfire': 'Campfire',
      'island': 'Island',
      'sunglasses': 'Sunglasses',
      'city': 'City',
      'house': 'House',
      'music_note': 'Music note',
      'music_notes': 'Music notes',
      'headphones': 'Headphones',
      'guitar': 'Guitar',
      'microphone': 'Microphone',
      'microphone_stage': 'Stage microphone',
      'piano_keys': 'Piano',
      'vinyl_record': 'Vinyl record',
      'cassette_tape': 'Cassette',
      'radio': 'Radio',
      'palette': 'Palette',
      'paint_brush': 'Paintbrush',
      'pen_nib': 'Fountain pen',
      'camera': 'Camera',
      'video_camera': 'Video camera',
      'film_strip': 'Film strip',
      'film_slate': 'Clapperboard',
      'ticket': 'Ticket',
      'mask_happy': 'Happy mask',
      'mask_sad': 'Sad mask',
      'book': 'Book',
      'book_open': 'Open book',
      'books': 'Books',
      'notebook': 'Notebook',
      'graduation_cap': 'Graduation cap',
      'student': 'Student',
      'chalkboard_teacher': 'Teacher',
      'pencil': 'Pencil',
      'pencil_ruler': 'Pencil and ruler',
      'briefcase': 'Briefcase',
      'laptop': 'Laptop',
      'lightbulb': 'Light bulb',
      'rocket': 'Rocket',
      'target': 'Target',
      'chart_line_up': 'Growth chart',
      'calendar': 'Calendar',
      'clock': 'Clock',
      'hourglass': 'Hourglass',
      'atom': 'Atom',
      'flask': 'Flask',
      'globe_stand': 'Globe',
      'code': 'Code',
      'handshake': 'Handshake',
      'stethoscope': 'Stethoscope',
      'check_circle': 'Tick',
      'x_circle': 'Cross',
      'arrow_fat_right': 'Arrow',
      'infinity': 'Infinity',
      'peace': 'Peace',
      'yin_yang': 'Yin and yang',
      'smiley': 'Smile',
      'smiley_wink': 'Wink',
      'smiley_sad': 'Sad face',
      'smiley_angry': 'Angry face',
      'smiley_melting': 'Melting face',
      'thumbs_up': 'Thumbs up',
      'thumbs_down': 'Thumbs down',
      'hand_heart': 'Heart in hand',
      'hand_peace': 'Victory sign',
      'hand_waving': 'Hello',
      'hands_clapping': 'Applause',
      'flag': 'Flag',
      'shield': 'Shield',
      'star_four': 'Four-pointed star',
      'asterisk': 'Asterisk',
      'quotes': 'Quotation marks',
      'hash': 'Hashtag',
      'at': 'At sign',
      'circle': 'Circle',
      'square': 'Square',
      'triangle': 'Triangle',
      'hexagon': 'Hexagon',
      'diamond': 'Diamond',
      'ghost': 'Ghost',
      'alien': 'Alien',
      'robot': 'Robot',
      'other': '-',
    });
    return '$_temp0';
  }

  @override
  String get editorDomainLayerElement => 'Element';

  @override
  String get editorDomainLayerIcon => 'Icon';

  @override
  String get editorDomainLayerShape => 'Shape';

  @override
  String editorDomainMaxHeight(String max) {
    return 'height must be at most $max mm';
  }

  @override
  String editorDomainMaxWidth(String max) {
    return 'width must be at most $max mm';
  }

  @override
  String editorDomainMinFont(String min) {
    return 'text must be at least $min mm';
  }

  @override
  String editorDomainNoArea(String area) {
    return 'This type has no “$area” area';
  }

  @override
  String get editorDomainNoColor => 'this method prints without colour';

  @override
  String editorDomainNoMethod(String area) {
    return 'This print method isn’t available on “$area”';
  }

  @override
  String get editorDomainOneMethod =>
      'the design is printed one way — this element uses another';

  @override
  String get editorDomainOutOfZone => 'goes outside the print zone';

  @override
  String editorDomainProblemAt(String area, String problem) {
    return '$area: $problem';
  }

  @override
  String editorDomainShapeLabel(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'square': 'Square',
      'rounded': 'Rounded square',
      'circle': 'Circle',
      'triangle': 'Triangle',
      'star': 'Star',
      'heart': 'Heart',
      'hexagon': 'Hexagon',
      'diamond': 'Diamond',
      'burst': 'Badge',
      'semicircle': 'Semicircle',
      'bubble': 'Speech bubble',
      'arrow': 'Arrow',
      'plus': 'Plus',
      'ring': 'Ring',
      'frame': 'Frame',
      'frame_round': 'Rounded frame',
      'line': 'Line',
      'line_double': 'Double line',
      'other': '-',
    });
    return '$_temp0';
  }

  @override
  String get editorElementsAll => 'All';

  @override
  String get editorElementsClear => 'Clear';

  @override
  String get editorElementsIcons => 'Icons';

  @override
  String get editorElementsLoadFailed => 'Couldn’t load the elements';

  @override
  String get editorElementsNothingFound => 'Nothing found';

  @override
  String get editorElementsPopular => 'Popular';

  @override
  String get editorElementsSearch => 'Search';

  @override
  String get editorElementsShapes => 'Shapes';

  @override
  String get editorFontSample => 'Hello';

  @override
  String get editorImageCamera => 'Camera';

  @override
  String get editorImageGallery => 'Gallery';

  @override
  String get editorImageOpenFailed => 'Couldn’t open the image';

  @override
  String get editorImageUnsupported =>
      'Only PNG, JPG or WEBP images can be uploaded';

  @override
  String get editorImageUploadFailed => 'Couldn’t upload the image';

  @override
  String get editorLayersEmpty => 'No elements on this side yet';

  @override
  String get editorLayersHidden => 'Hidden';

  @override
  String get editorLayersHide => 'Hide';

  @override
  String get editorLayersLock => 'Lock';

  @override
  String get editorLayersOpen => 'Open';

  @override
  String get editorLayersShow => 'Show';

  @override
  String editorLayersSyncedWith(String area) {
    return 'Synced with “$area”';
  }

  @override
  String get editorLayersUnlock => 'Unlock';

  @override
  String get editorMain3dFailed => 'Couldn’t open the 3D view';

  @override
  String get editorMain3dLoading => 'Loading the 3D model…';

  @override
  String get editorMain3dView => '3D view';

  @override
  String get editorMainActions => 'Actions';

  @override
  String get editorMainAddSomethingFirst => 'Add an image or text first';

  @override
  String get editorMainAddToCart => 'Add to cart';

  @override
  String get editorMainAddToCartFailed => 'Couldn’t add to cart';

  @override
  String editorMainAreaNoMethod(String area) {
    return 'This method isn’t available on “$area”';
  }

  @override
  String editorMainAreaNoMethodClear(String area) {
    return 'This method isn’t available on “$area”: remove the elements there first';
  }

  @override
  String get editorMainAreaSynced => 'This side is synced with another side';

  @override
  String editorMainAreaSyncedWith(String area) {
    return 'This side is synced with “$area”, so edit it there';
  }

  @override
  String get editorMainBadImage => 'Invalid image';

  @override
  String get editorMainBringForward => 'Forward';

  @override
  String get editorMainCannotAddHere => 'You can’t add anything here';

  @override
  String get editorMainCapture => 'Take a picture';

  @override
  String get editorMainCenter => 'Center';

  @override
  String get editorMainCopy => 'Copy';

  @override
  String editorMainCroppedBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count get cropped',
      one: '$count gets cropped',
    );
    return '$_temp0';
  }

  @override
  String get editorMainDuplicate => 'Duplicate';

  @override
  String get editorMainEditTextShort => 'Text';

  @override
  String get editorMainEngineBroken => 'The 3D view isn’t working';

  @override
  String get editorMainEngineClosed => 'Closed';

  @override
  String get editorMainEngineConnectFailed => 'Couldn’t connect to the 3D view';

  @override
  String get editorMainEngineLoadFailed => 'The 3D view didn’t load';

  @override
  String get editorMainEngineNoAnswer => 'The 3D view isn’t responding';

  @override
  String get editorMainEngineNotReady => 'The 3D view isn’t ready yet';

  @override
  String get editorMainEngineReloaded => 'The 3D view was reloaded';

  @override
  String get editorMainEngineStartFailed => 'Couldn’t start the 3D view';

  @override
  String get editorMainError => 'Error';

  @override
  String editorMainErrorsBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count errors',
      one: '$count error',
    );
    return '$_temp0';
  }

  @override
  String editorMainFileSaveFailed(String status) {
    return 'Couldn’t save the file ($status). Please try again.';
  }

  @override
  String get editorMainFixRedItems => 'Fix the elements marked in red';

  @override
  String get editorMainFlatView => 'Flat view';

  @override
  String get editorMainHide => 'Hide';

  @override
  String get editorMainLock => 'Lock';

  @override
  String get editorMainLocked => 'Locked';

  @override
  String get editorMainMenuEditText => 'Edit text';

  @override
  String editorMainMethodSwitched(String method) {
    return 'Design switched to “$method”';
  }

  @override
  String get editorMainNoPrintFile => 'Couldn’t create the print file';

  @override
  String get editorMainNoViews => 'Couldn’t take the preview pictures';

  @override
  String get editorMainNotSaved => 'Not saved';

  @override
  String get editorMainPickSizeFirst => 'Pick a size first';

  @override
  String get editorMainPickTool => 'Pick a tool';

  @override
  String get editorMainPriceRecalculated => 'The price has been recalculated';

  @override
  String get editorMainProductColor => 'Product colour';

  @override
  String get editorMainProductColorBackground =>
      'Background in the product colour';

  @override
  String get editorMainRedo => 'Redo';

  @override
  String get editorMainReloadedNewer =>
      'The design was changed elsewhere, so we loaded the latest version';

  @override
  String get editorMainResetView => 'Reset view';

  @override
  String get editorMainSaveFailed => 'Couldn’t save';

  @override
  String get editorMainSaveFailedOffline =>
      'Couldn’t save. Check your internet connection';

  @override
  String get editorMainSaved => 'Design saved';

  @override
  String get editorMainSendBackward => 'Backward';

  @override
  String get editorMainSettings => 'Adjust';

  @override
  String get editorMainStepAddingToCart => 'Adding to cart…';

  @override
  String get editorMainStepPrintFiles => 'Preparing print files…';

  @override
  String get editorMainStepSaving => 'Saving the design…';

  @override
  String editorMainStepUploading(int current, int total) {
    return 'Uploading… $current/$total';
  }

  @override
  String get editorMainStepViews => 'Taking pictures…';

  @override
  String editorMainSyncedFrom(String area) {
    return 'Synced with “$area”';
  }

  @override
  String editorMainTemplateApplied(String name) {
    return 'Template “$name” applied';
  }

  @override
  String get editorMainTextPlaceholder => 'Your text here';

  @override
  String get editorMainTitle => 'Create a design';

  @override
  String editorMainTooManyLayers(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'A design can have at most $max elements',
      one: 'A design can have at most $max element',
    );
    return '$_temp0';
  }

  @override
  String get editorMainToolBackground => 'Background';

  @override
  String get editorMainToolElements => 'Elements';

  @override
  String get editorMainToolGallery => 'Gallery';

  @override
  String get editorMainToolImage => 'Image';

  @override
  String get editorMainToolLayers => 'Layers';

  @override
  String get editorMainToolText => 'Text';

  @override
  String get editorMainUndo => 'Undo';

  @override
  String get editorMainUndoAction => 'Undo';

  @override
  String get editorMainUnknownError => 'Unknown error';

  @override
  String get editorMainUnlock => 'Unlock';

  @override
  String get editorMainVariantNoMethod =>
      'This method isn’t available for this option';

  @override
  String get editorMainVariantReplaced =>
      'The option you picked earlier is no longer on sale, so we picked another';

  @override
  String get editorPropsAlignCenter => 'Align centre';

  @override
  String get editorPropsAlignLeft => 'Align left';

  @override
  String get editorPropsAlignRight => 'Align right';

  @override
  String get editorPropsBackground => 'Background';

  @override
  String get editorPropsBold => 'Bold';

  @override
  String get editorPropsCenterX => 'Centre horizontally';

  @override
  String get editorPropsCenterY => 'Centre vertically';

  @override
  String get editorPropsColor => 'Colour';

  @override
  String get editorPropsCropped => 'The part outside the zone won’t be printed';

  @override
  String get editorPropsDialNumerals => 'Clock numbers';

  @override
  String get editorPropsFontSize => 'Font size';

  @override
  String get editorPropsImage => 'Image';

  @override
  String get editorPropsItalic => 'Italic';

  @override
  String get editorPropsLowQuality => 'Low image quality';

  @override
  String get editorPropsMinuteTicks => 'Minute marks';

  @override
  String editorPropsMm(String value) {
    return '$value mm';
  }

  @override
  String get editorPropsNumeralsNone => 'None';

  @override
  String get editorPropsRemoveBackground => 'Remove background';

  @override
  String get editorPropsRotation => 'Rotation';

  @override
  String get editorPropsSize => 'Size';

  @override
  String get editorPropsSticker => 'Sticker';

  @override
  String get editorPropsStraighten => 'Straighten';

  @override
  String get editorSheet3dNotReady => 'The 3D view isn’t ready yet';

  @override
  String get editorSheetAddAtPrice => 'Add at this price';

  @override
  String get editorSheetAddedToCart => 'Added to cart';

  @override
  String get editorSheetCapture => 'Take a snapshot';

  @override
  String get editorSheetCaptureFailed => 'Couldn’t take a snapshot';

  @override
  String get editorSheetClear => 'Clear';

  @override
  String editorSheetClearConfirm(int count, String area) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count elements from $area?',
      one: 'Delete $count element from $area?',
    );
    return '$_temp0';
  }

  @override
  String get editorSheetClearSide => 'Clear side';

  @override
  String editorSheetClearSideCount(int count) {
    return 'Clear side ($count)';
  }

  @override
  String editorSheetColorNamed(String name) {
    return 'Colour: $name';
  }

  @override
  String get editorSheetContinue => 'Continue';

  @override
  String get editorSheetCurrentView => 'Current view';

  @override
  String get editorSheetGalleryDenied => 'No access to the gallery';

  @override
  String get editorSheetGallerySaveFailed => 'Couldn’t save to the gallery';

  @override
  String get editorSheetGoToCart => 'Go to cart';

  @override
  String get editorSheetGrid => 'Grid';

  @override
  String get editorSheetImageSaved => 'Image saved';

  @override
  String editorSheetImagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '$count image',
    );
    return '$_temp0';
  }

  @override
  String editorSheetImagesSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images saved',
      one: '$count image saved',
    );
    return '$_temp0';
  }

  @override
  String get editorSheetLinkedElsewhere => 'already linked to other sides';

  @override
  String editorSheetLostElements(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elements won’t fit this type',
      one: '$count element won’t fit this type',
    );
    return '$_temp0';
  }

  @override
  String editorSheetMirrored(String name) {
    return '$name (mirrored)';
  }

  @override
  String editorSheetOwnHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Its $count elements will be hidden',
      one: 'Its $count element will be hidden',
    );
    return '$_temp0';
  }

  @override
  String get editorSheetPrice => 'Price';

  @override
  String get editorSheetPriceRecalculated =>
      'The price was recalculated from the print files';

  @override
  String get editorSheetPrintMethod => 'Print method';

  @override
  String get editorSheetProduct => 'Product';

  @override
  String get editorSheetReplace => 'Switch';

  @override
  String get editorSheetSelfSynced =>
      'This side is itself synced from another side';

  @override
  String get editorSheetShare => 'Share';

  @override
  String get editorSheetSides => 'Sides';

  @override
  String get editorSheetSize => 'Size';

  @override
  String get editorSheetSnapping => 'Snapping';

  @override
  String get editorSheetSync => 'Sync';

  @override
  String editorSheetSyncedFrom(String area) {
    return 'Synced from “$area”';
  }

  @override
  String editorSheetSyncedTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Synced to $count sides',
      one: 'Synced to $count side',
    );
    return '$_temp0';
  }

  @override
  String get editorSheetText => 'Text';

  @override
  String get editorSheetToGallery => 'To gallery';

  @override
  String get editorSheetType => 'Type';

  @override
  String get editorTemplatesEmpty => 'No templates for this type';

  @override
  String get editorTextAdd => 'Add text';

  @override
  String get editorTextBestDad => 'Best dad ever';

  @override
  String get editorTextBigHeading => 'BIG HEADING';

  @override
  String get editorTextBirthday => 'Happy birthday!';

  @override
  String get editorTextCongrats => 'Congratulations!';

  @override
  String get editorTextElegant => 'Elegant heading';

  @override
  String get editorTextFonts => 'Fonts';

  @override
  String get editorTextGoodDays => 'All the best';

  @override
  String get editorTextHeading => 'Heading';

  @override
  String get editorTextPlaceholder => 'Your text here';

  @override
  String get editorTextSubheading => 'Subheading';

  @override
  String get editorTextWithLove => 'With love';

  @override
  String get errorCancelled => 'Cancelled';

  @override
  String get errorForbidden => 'Access denied';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get errorInsecure => 'Couldn’t connect securely';

  @override
  String get errorNoInternet => 'No internet connection';

  @override
  String get errorNotFound => 'Not found';

  @override
  String get errorServer => 'Server error';

  @override
  String get errorSignInAgain => 'Please sign in again';

  @override
  String get errorTimeout => 'The server didn’t respond';

  @override
  String get homeCategories => 'Categories';

  @override
  String get homeChooseProduct => 'Pick a product';

  @override
  String get homeCreateDesign => 'Create a design';

  @override
  String get homeGallery => 'Gallery';

  @override
  String get homeHeroTitle => 'Mugs, T-shirts, clocks —\nwith your own design';

  @override
  String get homeNoProducts => 'No products yet';

  @override
  String get homeSearch => 'Search';

  @override
  String get homeSeeAll => 'See all';

  @override
  String get languageChoose => 'Choose a language';

  @override
  String get languageSystemHint => 'App language';

  @override
  String get languageTitle => 'Language';

  @override
  String get materialCeramicGlossy => 'Ceramic, glossy';

  @override
  String get materialCeramicMatte => 'Ceramic, matte';

  @override
  String get materialFabric => 'Fabric';

  @override
  String get materialGlassClear => 'Glass, clear';

  @override
  String get materialGlassFrosted => 'Glass, frosted';

  @override
  String get materialMetal => 'Metal';

  @override
  String get materialPaper => 'Paper';

  @override
  String get materialPlastic => 'Plastic';

  @override
  String get materialWood => 'Wood';

  @override
  String get navCart => 'Cart';

  @override
  String get navDesigns => 'My designs';

  @override
  String get navHome => 'Home';

  @override
  String get navProducts => 'Products';

  @override
  String get navProfile => 'Profile';

  @override
  String get orderNextInProduction => 'Your order is being made';

  @override
  String get orderNextNew => 'Our team will contact you shortly';

  @override
  String get orderNextPaid => 'It goes into production soon';

  @override
  String get orderNextPaymentPending => 'We’re waiting for your payment';

  @override
  String get orderNextQualityCheck => 'We’re checking the quality';

  @override
  String get orderNextReadyForDelivery => 'Out for delivery soon';

  @override
  String get orderNextReadyForPickup => 'Ready for you to pick up';

  @override
  String get orderStatusCancelled => 'Cancelled';

  @override
  String get orderStatusCompleted => 'Completed';

  @override
  String get orderStatusInProduction => 'In production';

  @override
  String get orderStatusNew => 'New';

  @override
  String get orderStatusPaid => 'Paid';

  @override
  String get orderStatusPaymentPending => 'Awaiting payment';

  @override
  String get orderStatusQualityCheck => 'Quality check';

  @override
  String get orderStatusReadyForDelivery => 'Ready for delivery';

  @override
  String get orderStatusReadyForPickup => 'Ready for pickup';

  @override
  String get orderStatusReadyForProduction => 'Ready for production';

  @override
  String get orderStepAccepted => 'Received';

  @override
  String get orderStepDone => 'Done';

  @override
  String get orderStepPayment => 'Payment';

  @override
  String get orderStepProduction => 'Production';

  @override
  String get orderStepReady => 'Ready';

  @override
  String get ordersAll => 'All orders';

  @override
  String get ordersCancelAction => 'Cancel order';

  @override
  String get ordersCancelConfirm => 'Cancel this order?';

  @override
  String get ordersCancelKeep => 'Keep it';

  @override
  String get ordersCancelled => 'Order cancelled';

  @override
  String get ordersCancelledBanner => 'This order was cancelled';

  @override
  String get ordersChooseProduct => 'Browse products';

  @override
  String ordersDetailTitle(String number) {
    return 'Order #$number';
  }

  @override
  String get ordersDiscount => 'Discount';

  @override
  String get ordersEmpty => 'No orders yet';

  @override
  String get ordersFree => 'Free';

  @override
  String ordersItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String get ordersItems => 'Items';

  @override
  String get ordersLeaveReview => 'Leave a review';

  @override
  String get ordersMore => 'More';

  @override
  String get ordersNotFound => 'Order not found';

  @override
  String ordersNumber(String number) {
    return '#$number';
  }

  @override
  String get ordersOnlyNewCancellable => 'New orders only';

  @override
  String get ordersPayment => 'Payment';

  @override
  String get ordersPickup => 'Pickup';

  @override
  String ordersPieces(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pcs',
      one: '$count pc',
    );
    return '$_temp0';
  }

  @override
  String get ordersReviewSent => 'Thanks for your review';

  @override
  String get ordersShipping => 'Delivery';

  @override
  String get ordersShippingTbd => 'To be agreed';

  @override
  String get ordersShowMore => 'Show more';

  @override
  String get ordersSignInPrompt => 'Sign in to see your orders';

  @override
  String get ordersStatAwaitingPayment => 'Awaiting payment';

  @override
  String get ordersStatInProduction => 'In production';

  @override
  String get ordersStatSpent => 'Total spent';

  @override
  String get ordersStatTotal => 'Total orders';

  @override
  String get ordersTelegram => 'Message us on Telegram';

  @override
  String get ordersTitle => 'My orders';

  @override
  String get ordersTotal => 'Total';

  @override
  String get paymentUnpaid => 'Unpaid';

  @override
  String priceFrom(String price) {
    return 'from $price';
  }

  @override
  String get printMethodEngrave => 'Laser engraving';

  @override
  String get printMethodUv => 'Colour print';

  @override
  String get product3dLoading => 'Loading 3D model…';

  @override
  String get product3dOpenFailed => 'Couldn’t open the 3D view';

  @override
  String get product3dResetView => 'Reset view';

  @override
  String get product3dView => '3D view';

  @override
  String get productChooseSize => 'Choose one';

  @override
  String get productChooseSizeSnack => 'Choose a size';

  @override
  String get productColor => 'Colour';

  @override
  String get productDescription => 'Description';

  @override
  String get productDesign => 'Design it';

  @override
  String get productPrintMethod => 'Print method';

  @override
  String get productShare => 'Share';

  @override
  String get productShowLess => 'Show less';

  @override
  String get productShowMore => 'Show more';

  @override
  String get productSize => 'Size';

  @override
  String get productSoldOut => 'Sold out';

  @override
  String get productSpecMaterial => 'Material';

  @override
  String get productSpecs => 'Specifications';

  @override
  String get productVariant => 'Type';

  @override
  String get productionPacked => 'Packed';

  @override
  String get productionPrinted => 'Printed';

  @override
  String get productionPrinting => 'Printing';

  @override
  String get productionQueued => 'In queue';

  @override
  String get profileDeleteAccount => 'Delete account';

  @override
  String get profileDeleteAccountBody =>
      'Your account, saved designs and cart will be deleted. Completed orders are kept for accounting, without your personal details.\n\nThis cannot be undone.';

  @override
  String get profileDeleteAccountDone => 'Your account was deleted';

  @override
  String get profileDeleteAccountFailed =>
      'Couldn’t delete the account. Please try again';

  @override
  String get profileDeleteAccountSubmit => 'Delete';

  @override
  String get profileDeleteAccountTitle => 'Delete your account?';

  @override
  String get profileEdit => 'Edit';

  @override
  String get profileEditTitle => 'Edit profile';

  @override
  String get profileLastName => 'Last name';

  @override
  String get profileLinkOpenFailed => 'Couldn’t open the link';

  @override
  String get profileMyOrders => 'My orders';

  @override
  String get profilePhone => 'Phone';

  @override
  String get profilePhoneIncomplete => 'Enter the full phone number';

  @override
  String get profilePrivacyPolicy => 'Privacy policy';

  @override
  String get profileSaved => 'Saved';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get profileSignOutConfirm => 'Sign out of your account?';

  @override
  String get profileTelegramConnected => 'Telegram connected';

  @override
  String get profileTelegramLink => 'Connect';

  @override
  String get profileTelegramLinked => 'Connected';

  @override
  String get profileTelegramNotConfigured => 'The Telegram bot isn’t set up';

  @override
  String get profileTelegramNotConfirmed => 'The connection wasn’t confirmed';

  @override
  String get profileTelegramOpenFailed => 'Couldn’t open Telegram';

  @override
  String get profileTelegramRelink => 'Reconnect';

  @override
  String get profileTelegramTitle => 'Telegram notifications';

  @override
  String get profileTelegramUnlinked => 'Not connected';

  @override
  String get profileTelegramWaiting => 'Waiting';

  @override
  String get reviewsCity => 'City';

  @override
  String get reviewsEmpty => 'You haven’t left any reviews yet';

  @override
  String get reviewsFormTitle => 'Leave a review';

  @override
  String reviewsPhotoTooLarge(int size) {
    return 'Each photo must be $size MB or less';
  }

  @override
  String get reviewsPhotosOpenFailed => 'Couldn’t open the photos';

  @override
  String reviewsRatingLabel(int value) {
    return 'Rated $value out of 5';
  }

  @override
  String get reviewsSend => 'Send';

  @override
  String get reviewsSignIn => 'Sign in to see your reviews';

  @override
  String get reviewsStatusApproved => 'Published';

  @override
  String get reviewsStatusPending => 'Under review';

  @override
  String get reviewsStatusRejected => 'Rejected';

  @override
  String get reviewsTextLabel => 'Your review';

  @override
  String reviewsTextTooShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'At least $count characters',
      one: 'At least $count character',
    );
    return '$_temp0';
  }

  @override
  String get reviewsTitle => 'My reviews';
}
