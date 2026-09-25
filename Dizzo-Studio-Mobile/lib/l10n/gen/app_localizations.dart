import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('uz'),
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In uz, this message translates to:
  /// **'Dizzo'**
  String get appTitle;

  /// No description provided for @authEmail.
  ///
  /// In uz, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authEmailInvalid.
  ///
  /// In uz, this message translates to:
  /// **'Email noto‘g‘ri'**
  String get authEmailInvalid;

  /// No description provided for @authEmailRequired.
  ///
  /// In uz, this message translates to:
  /// **'Emailni kiriting'**
  String get authEmailRequired;

  /// No description provided for @authFirstName.
  ///
  /// In uz, this message translates to:
  /// **'Ism'**
  String get authFirstName;

  /// No description provided for @authFirstNameRequired.
  ///
  /// In uz, this message translates to:
  /// **'Ismingizni kiriting'**
  String get authFirstNameRequired;

  /// No description provided for @authGoogleFailed.
  ///
  /// In uz, this message translates to:
  /// **'Google orqali kirib bo‘lmadi'**
  String get authGoogleFailed;

  /// No description provided for @authGoogleNoAccount.
  ///
  /// In uz, this message translates to:
  /// **'Qurilmada Google hisobi topilmadi'**
  String get authGoogleNoAccount;

  /// No description provided for @authGoogleNoResponse.
  ///
  /// In uz, this message translates to:
  /// **'Google javob bermadi'**
  String get authGoogleNoResponse;

  /// No description provided for @authGoogleNotConfigured.
  ///
  /// In uz, this message translates to:
  /// **'Google orqali kirish hali sozlanmagan'**
  String get authGoogleNotConfigured;

  /// No description provided for @authGoogleUnsupported.
  ///
  /// In uz, this message translates to:
  /// **'Google orqali kirish bu qurilmada ishlamaydi'**
  String get authGoogleUnsupported;

  /// No description provided for @authGoogleWindowFailed.
  ///
  /// In uz, this message translates to:
  /// **'Google oynasini ochib bo‘lmadi'**
  String get authGoogleWindowFailed;

  /// No description provided for @authHaveAccount.
  ///
  /// In uz, this message translates to:
  /// **'Hisobim bor'**
  String get authHaveAccount;

  /// No description provided for @authLater.
  ///
  /// In uz, this message translates to:
  /// **'Keyinroq'**
  String get authLater;

  /// Divider between the social sign-in buttons and email sign-in.
  ///
  /// In uz, this message translates to:
  /// **'yoki'**
  String get authOr;

  /// No description provided for @authPassword.
  ///
  /// In uz, this message translates to:
  /// **'Parol'**
  String get authPassword;

  /// No description provided for @authPasswordHide.
  ///
  /// In uz, this message translates to:
  /// **'Yashirish'**
  String get authPasswordHide;

  /// No description provided for @authPasswordRequired.
  ///
  /// In uz, this message translates to:
  /// **'Parolni kiriting'**
  String get authPasswordRequired;

  /// No description provided for @authPasswordShow.
  ///
  /// In uz, this message translates to:
  /// **'Ko‘rsatish'**
  String get authPasswordShow;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{Kamida {count} ta belgi} other{Kamida {count} ta belgi}}'**
  String authPasswordTooShort(int count);

  /// No description provided for @authPrivacyNotice.
  ///
  /// In uz, this message translates to:
  /// **'Davom etish orqali siz maxfiylik siyosatini qabul qilasiz'**
  String get authPrivacyNotice;

  /// Submit button of the sign-up form.
  ///
  /// In uz, this message translates to:
  /// **'Ro‘yxatdan o‘tish'**
  String get authRegisterSubmit;

  /// Link under the sign-in form that switches to sign-up.
  ///
  /// In uz, this message translates to:
  /// **'Ro‘yxatdan o‘tish'**
  String get authRegisterSwitch;

  /// Heading of the sign-up form.
  ///
  /// In uz, this message translates to:
  /// **'Ro‘yxatdan o‘tish'**
  String get authRegisterTitle;

  /// No description provided for @authSignIn.
  ///
  /// In uz, this message translates to:
  /// **'Kirish'**
  String get authSignIn;

  /// No description provided for @authSignInEmail.
  ///
  /// In uz, this message translates to:
  /// **'Email orqali kirish'**
  String get authSignInEmail;

  /// No description provided for @authSignInFailed.
  ///
  /// In uz, this message translates to:
  /// **'Kirishda xatolik'**
  String get authSignInFailed;

  /// No description provided for @authSignInGoogle.
  ///
  /// In uz, this message translates to:
  /// **'Google orqali kirish'**
  String get authSignInGoogle;

  /// No description provided for @authSignInTelegram.
  ///
  /// In uz, this message translates to:
  /// **'Telegram orqali kirish'**
  String get authSignInTelegram;

  /// No description provided for @authSignInTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hisobingizga kiring'**
  String get authSignInTitle;

  /// No description provided for @authTelegramConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Telegramda tasdiqlang'**
  String get authTelegramConfirm;

  /// No description provided for @authTelegramFailed.
  ///
  /// In uz, this message translates to:
  /// **'Telegram orqali kirib bo‘lmadi'**
  String get authTelegramFailed;

  /// No description provided for @authTelegramReopen.
  ///
  /// In uz, this message translates to:
  /// **'Qayta ochish'**
  String get authTelegramReopen;

  /// No description provided for @authTelegramVerifying.
  ///
  /// In uz, this message translates to:
  /// **'Tekshirilmoqda'**
  String get authTelegramVerifying;

  /// No description provided for @authWelcomeHeadline.
  ///
  /// In uz, this message translates to:
  /// **'O‘z dizayningizni\nyarating'**
  String get authWelcomeHeadline;

  /// No description provided for @cartBrowseProducts.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot tanlash'**
  String get cartBrowseProducts;

  /// No description provided for @cartCheckout.
  ///
  /// In uz, this message translates to:
  /// **'Rasmiylashtirish'**
  String get cartCheckout;

  /// No description provided for @cartClear.
  ///
  /// In uz, this message translates to:
  /// **'Tozalash'**
  String get cartClear;

  /// No description provided for @cartClearConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Savatni tozalaysizmi?'**
  String get cartClearConfirm;

  /// No description provided for @cartDecrease.
  ///
  /// In uz, this message translates to:
  /// **'Kamaytirish'**
  String get cartDecrease;

  /// No description provided for @cartEditItem.
  ///
  /// In uz, this message translates to:
  /// **'Tahrirlash'**
  String get cartEditItem;

  /// No description provided for @cartEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Savat bo‘sh'**
  String get cartEmpty;

  /// No description provided for @cartImageLabel.
  ///
  /// In uz, this message translates to:
  /// **'Rasm {index} / {count}'**
  String cartImageLabel(int index, int count);

  /// No description provided for @cartIncrease.
  ///
  /// In uz, this message translates to:
  /// **'Ko‘paytirish'**
  String get cartIncrease;

  /// No description provided for @cartItemActions.
  ///
  /// In uz, this message translates to:
  /// **'Amallar'**
  String get cartItemActions;

  /// No description provided for @cartItemRemoved.
  ///
  /// In uz, this message translates to:
  /// **'{name} olib tashlandi'**
  String cartItemRemoved(String name);

  /// No description provided for @cartItemUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Sotuvda yo‘q'**
  String get cartItemUnavailable;

  /// No description provided for @cartItemsCount.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{{count} ta mahsulot} other{{count} ta mahsulot}}'**
  String cartItemsCount(int count);

  /// No description provided for @cartPrintArea.
  ///
  /// In uz, this message translates to:
  /// **'{method} · {area} cm²'**
  String cartPrintArea(String method, String area);

  /// No description provided for @cartQuantity.
  ///
  /// In uz, this message translates to:
  /// **'Miqdor'**
  String get cartQuantity;

  /// Label of the quantity input
  ///
  /// In uz, this message translates to:
  /// **'Dona'**
  String get cartQuantityPieces;

  /// No description provided for @cartQuantityRange.
  ///
  /// In uz, this message translates to:
  /// **'{min} dan {max} gacha'**
  String cartQuantityRange(int min, int max);

  /// No description provided for @cartSignInPrompt.
  ///
  /// In uz, this message translates to:
  /// **'Savatni ko‘rish uchun kiring'**
  String get cartSignInPrompt;

  /// No description provided for @cartSomeUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Ba’zi mahsulotlar sotuvda yo‘q'**
  String get cartSomeUnavailable;

  /// No description provided for @cartTitle.
  ///
  /// In uz, this message translates to:
  /// **'Savat'**
  String get cartTitle;

  /// No description provided for @cartTotal.
  ///
  /// In uz, this message translates to:
  /// **'Jami'**
  String get cartTotal;

  /// No description provided for @cartUndo.
  ///
  /// In uz, this message translates to:
  /// **'Qaytarish'**
  String get cartUndo;

  /// No description provided for @cartUnitPrice.
  ///
  /// In uz, this message translates to:
  /// **'1 dona: {price}'**
  String cartUnitPrice(String price);

  /// Category chip that shows every category
  ///
  /// In uz, this message translates to:
  /// **'Barchasi'**
  String get catalogAllCategories;

  /// No description provided for @catalogClearFilter.
  ///
  /// In uz, this message translates to:
  /// **'Filtrni tozalash'**
  String get catalogClearFilter;

  /// No description provided for @catalogNothingFound.
  ///
  /// In uz, this message translates to:
  /// **'Hech narsa topilmadi'**
  String get catalogNothingFound;

  /// Badge on a featured product card
  ///
  /// In uz, this message translates to:
  /// **'Ommabop'**
  String get catalogPopularBadge;

  /// No description provided for @catalogSearchClear.
  ///
  /// In uz, this message translates to:
  /// **'Tozalash'**
  String get catalogSearchClear;

  /// No description provided for @catalogSearchHint.
  ///
  /// In uz, this message translates to:
  /// **'Qidirish'**
  String get catalogSearchHint;

  /// No description provided for @catalogTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlar'**
  String get catalogTitle;

  /// No description provided for @checkoutAddressHint.
  ///
  /// In uz, this message translates to:
  /// **'Ko‘cha, uy, xonadon'**
  String get checkoutAddressHint;

  /// No description provided for @checkoutAddressLabel.
  ///
  /// In uz, this message translates to:
  /// **'Manzil'**
  String get checkoutAddressLabel;

  /// No description provided for @checkoutAddressRequired.
  ///
  /// In uz, this message translates to:
  /// **'Manzilni kiriting'**
  String get checkoutAddressRequired;

  /// No description provided for @checkoutCartEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Savat bo‘sh'**
  String get checkoutCartEmpty;

  /// No description provided for @checkoutChangeLocation.
  ///
  /// In uz, this message translates to:
  /// **'O‘zgartirish'**
  String get checkoutChangeLocation;

  /// No description provided for @checkoutChooseProduct.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot tanlash'**
  String get checkoutChooseProduct;

  /// No description provided for @checkoutConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlash'**
  String get checkoutConfirm;

  /// No description provided for @checkoutContactTitle.
  ///
  /// In uz, this message translates to:
  /// **'Aloqa'**
  String get checkoutContactTitle;

  /// No description provided for @checkoutDelivery.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazib berish'**
  String get checkoutDelivery;

  /// No description provided for @checkoutFree.
  ///
  /// In uz, this message translates to:
  /// **'Bepul'**
  String get checkoutFree;

  /// No description provided for @checkoutHome.
  ///
  /// In uz, this message translates to:
  /// **'Bosh sahifa'**
  String get checkoutHome;

  /// No description provided for @checkoutItemsCount.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{{count} ta} other{{count} ta}}'**
  String checkoutItemsCount(int count);

  /// No description provided for @checkoutLocationDenied.
  ///
  /// In uz, this message translates to:
  /// **'Joylashuvga ruxsat berilmadi'**
  String get checkoutLocationDenied;

  /// No description provided for @checkoutLocationFailed.
  ///
  /// In uz, this message translates to:
  /// **'Joylashuvni aniqlab bo‘lmadi'**
  String get checkoutLocationFailed;

  /// No description provided for @checkoutLocationOff.
  ///
  /// In uz, this message translates to:
  /// **'Joylashuv xizmati o‘chiq'**
  String get checkoutLocationOff;

  /// No description provided for @checkoutMapTitle.
  ///
  /// In uz, this message translates to:
  /// **'Manzilni belgilash'**
  String get checkoutMapTitle;

  /// No description provided for @checkoutMethodTitle.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilish usuli'**
  String get checkoutMethodTitle;

  /// No description provided for @checkoutMyLocation.
  ///
  /// In uz, this message translates to:
  /// **'Joylashuvim'**
  String get checkoutMyLocation;

  /// No description provided for @checkoutNameLabel.
  ///
  /// In uz, this message translates to:
  /// **'Ism va familiya'**
  String get checkoutNameLabel;

  /// No description provided for @checkoutNameRequired.
  ///
  /// In uz, this message translates to:
  /// **'Ismingizni kiriting'**
  String get checkoutNameRequired;

  /// No description provided for @checkoutNoteLabel.
  ///
  /// In uz, this message translates to:
  /// **'Izoh (ixtiyoriy)'**
  String get checkoutNoteLabel;

  /// No description provided for @checkoutNoteTitle.
  ///
  /// In uz, this message translates to:
  /// **'Izoh'**
  String get checkoutNoteTitle;

  /// No description provided for @checkoutOperatorQuotes.
  ///
  /// In uz, this message translates to:
  /// **'Operator aytadi'**
  String get checkoutOperatorQuotes;

  /// No description provided for @checkoutOrderNumber.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma raqami'**
  String get checkoutOrderNumber;

  /// No description provided for @checkoutPhoneIncomplete.
  ///
  /// In uz, this message translates to:
  /// **'Telefon raqamini to‘liq kiriting'**
  String get checkoutPhoneIncomplete;

  /// No description provided for @checkoutPhoneLabel.
  ///
  /// In uz, this message translates to:
  /// **'Telefon'**
  String get checkoutPhoneLabel;

  /// No description provided for @checkoutPickOnMap.
  ///
  /// In uz, this message translates to:
  /// **'Xaritadan belgilash'**
  String get checkoutPickOnMap;

  /// No description provided for @checkoutPickup.
  ///
  /// In uz, this message translates to:
  /// **'Olib ketish'**
  String get checkoutPickup;

  /// No description provided for @checkoutPickupAddress.
  ///
  /// In uz, this message translates to:
  /// **'Toshkent shahri, Yunusobod tumani'**
  String get checkoutPickupAddress;

  /// No description provided for @checkoutPickupHours.
  ///
  /// In uz, this message translates to:
  /// **'Dushanba–Shanba, 09:00–20:00'**
  String get checkoutPickupHours;

  /// No description provided for @checkoutPickupName.
  ///
  /// In uz, this message translates to:
  /// **'Dizzo ishlab chiqarish markazi'**
  String get checkoutPickupName;

  /// No description provided for @checkoutPlaceOrder.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma berish'**
  String get checkoutPlaceOrder;

  /// No description provided for @checkoutProducts.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlar'**
  String get checkoutProducts;

  /// No description provided for @checkoutQuantity.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{{count} dona} other{{count} dona}}'**
  String checkoutQuantity(int count);

  /// No description provided for @checkoutSignInPrompt.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma berish uchun kiring'**
  String get checkoutSignInPrompt;

  /// No description provided for @checkoutSomeUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Ba’zi mahsulotlar sotuvda yo‘q'**
  String get checkoutSomeUnavailable;

  /// No description provided for @checkoutStatus.
  ///
  /// In uz, this message translates to:
  /// **'Holat'**
  String get checkoutStatus;

  /// No description provided for @checkoutSuccessTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma qabul qilindi'**
  String get checkoutSuccessTitle;

  /// No description provided for @checkoutSummaryTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma tarkibi'**
  String get checkoutSummaryTitle;

  /// No description provided for @checkoutTitle.
  ///
  /// In uz, this message translates to:
  /// **'Rasmiylashtirish'**
  String get checkoutTitle;

  /// No description provided for @checkoutTotal.
  ///
  /// In uz, this message translates to:
  /// **'Jami'**
  String get checkoutTotal;

  /// No description provided for @checkoutViewOrder.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani ko‘rish'**
  String get checkoutViewOrder;

  /// No description provided for @commonBack.
  ///
  /// In uz, this message translates to:
  /// **'Orqaga'**
  String get commonBack;

  /// No description provided for @commonCancel.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In uz, this message translates to:
  /// **'Yopish'**
  String get commonClose;

  /// No description provided for @commonComingSoon.
  ///
  /// In uz, this message translates to:
  /// **'Tez orada'**
  String get commonComingSoon;

  /// Name shown for a signed-in user with no name.
  ///
  /// In uz, this message translates to:
  /// **'Mijoz'**
  String get commonCustomer;

  /// No description provided for @commonDelete.
  ///
  /// In uz, this message translates to:
  /// **'O‘chirish'**
  String get commonDelete;

  /// No description provided for @commonDone.
  ///
  /// In uz, this message translates to:
  /// **'Tayyor'**
  String get commonDone;

  /// No description provided for @commonLoading.
  ///
  /// In uz, this message translates to:
  /// **'Yuklanmoqda'**
  String get commonLoading;

  /// No description provided for @commonNo.
  ///
  /// In uz, this message translates to:
  /// **'Yo‘q'**
  String get commonNo;

  /// No description provided for @commonOk.
  ///
  /// In uz, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonRetry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get commonRetry;

  /// No description provided for @commonSave.
  ///
  /// In uz, this message translates to:
  /// **'Saqlash'**
  String get commonSave;

  /// No description provided for @commonYes.
  ///
  /// In uz, this message translates to:
  /// **'Ha'**
  String get commonYes;

  /// Currency word after an amount: 149 000 so‘m.
  ///
  /// In uz, this message translates to:
  /// **'so‘m'**
  String get currencySum;

  /// No description provided for @designsActions.
  ///
  /// In uz, this message translates to:
  /// **'Amallar'**
  String get designsActions;

  /// No description provided for @designsCreate.
  ///
  /// In uz, this message translates to:
  /// **'Dizayn yaratish'**
  String get designsCreate;

  /// No description provided for @designsDeleteConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Dizaynni o‘chirasizmi?'**
  String get designsDeleteConfirm;

  /// No description provided for @designsDeleted.
  ///
  /// In uz, this message translates to:
  /// **'Dizayn o‘chirildi'**
  String get designsDeleted;

  /// No description provided for @designsEdit.
  ///
  /// In uz, this message translates to:
  /// **'Tahrirlash'**
  String get designsEdit;

  /// No description provided for @designsEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hali dizayn yo‘q'**
  String get designsEmpty;

  /// No description provided for @designsNew.
  ///
  /// In uz, this message translates to:
  /// **'Yangi dizayn'**
  String get designsNew;

  /// No description provided for @designsSignIn.
  ///
  /// In uz, this message translates to:
  /// **'Dizaynlaringiz shu yerda saqlanadi'**
  String get designsSignIn;

  /// No description provided for @editorCanvasSizeAngleBadge.
  ///
  /// In uz, this message translates to:
  /// **'{w} × {h} mm · {angle}°'**
  String editorCanvasSizeAngleBadge(String w, String h, String angle);

  /// No description provided for @editorCanvasSizeBadge.
  ///
  /// In uz, this message translates to:
  /// **'{w} × {h} mm'**
  String editorCanvasSizeBadge(String w, String h);

  /// No description provided for @editorCropFree.
  ///
  /// In uz, this message translates to:
  /// **'Erkin'**
  String get editorCropFree;

  /// No description provided for @editorCropOriginal.
  ///
  /// In uz, this message translates to:
  /// **'Asli'**
  String get editorCropOriginal;

  /// No description provided for @editorCropTitle.
  ///
  /// In uz, this message translates to:
  /// **'Kesish'**
  String get editorCropTitle;

  /// Crop aspect matching the print zone
  ///
  /// In uz, this message translates to:
  /// **'Zona'**
  String get editorCropZone;

  /// Name of a bundled icon, selected by its id with - replaced by _ (a lone - means unknown)
  ///
  /// In uz, this message translates to:
  /// **'{name, select, heart{Yurak} heart_straight{Yurakcha} heart_half{Yarim yurak} heart_break{Singan yurak} heartbeat{Yurak urishi} calendar_heart{Sevgi kuni} gift{Sovg‘a} confetti{Konfetti} balloon{Havo shari} cake{Tort} champagne{Shampan} cheers{Qadahlar} crown{Toj} crown_simple{Oddiy toj} sparkle{Uchqun} star{Yulduz} shooting_star{Uchar yulduz} flower_tulip{Lola} envelope_simple{Maktub} disco_ball{Disko shar} bell_ringing{Qo‘ng‘iroq} baby{Chaqaloq} magic_wand{Sehrli tayoqcha} treasure_chest{Xazina sandig‘i} sun{Quyosh} sun_horizon{Quyosh chiqishi} moon{Oy} moon_stars{Oy va yulduzlar} cloud{Bulut} cloud_sun{Bulutli quyosh} cloud_rain{Yomg‘ir} cloud_lightning{Momaqaldiroq} snowflake{Qor parchasi} rainbow{Kamalak} lightning{Chaqmoq} drop{Tomchi} fire{Olov} leaf{Barg} tree{Daraxt} tree_evergreen{Archa} tree_palm{Palma} plant{Nihol} cactus{Kaktus} flower{Gul} flower_lotus{Nilufar} clover{Beda} mountains{Tog‘lar} waves{To‘lqinlar} cat{Mushuk} dog{It} paw_print{Panja izi} bird{Qush} fish{Baliq} fish_simple{Baliqcha} butterfly{Kapalak} horse{Ot} rabbit{Quyon} cow{Sigir} bug{Hasharot} bug_beetle{Qo‘ng‘iz} shrimp{Krevetka} feather{Pat} bone{Suyak} coffee{Qahva} tea_bag{Choy} bowl_steam{Issiq kosa} cooking_pot{Qozon} fork_knife{Vilka va pichoq} chef_hat{Oshpaz qalpog‘i} pizza{Pitsa} hamburger{Gamburger} bread{Non} egg{Tuxum} ice_cream{Muzqaymoq} popsicle{Eskimo} cookie{Pechenye} popcorn{Popkorn} cherries{Gilos} orange_slice{Apelsin bo‘lagi} avocado{Avokado} carrot{Sabzi} pepper{Qalampir} wine{Vino} beer_stein{Pivo krujkasi} martini{Kokteyl} soccer_ball{Futbol to‘pi} basketball{Basketbol} volleyball{Voleybol} tennis_ball{Tennis to‘pi} ping_pong{Stol tennisi} football{Regbi} bowling_ball{Bouling} golf{Golf} hockey{Xokkey} boxing_glove{Boks qo‘lqopi} barbell{Shtanga} trophy{Kubok} medal{Medal} flag_checkered{Marra bayrog‘i} sneaker{Krossovka} person_simple_run{Yuguruvchi} person_simple_swim{Suzuvchi} person_simple_ski{Chang‘ichi} bicycle{Velosiped} game_controller{O‘yin pulti} puzzle_piece{Boshqotirma} dice_five{O‘yin soqqasi} airplane{Samolyot} car{Mashina} jeep{Jip} taxi{Taksi} bus{Avtobus} train{Poyezd} motorcycle{Mototsikl} boat{Kema} sailboat{Yelkanli qayiq} anchor{Langar} lighthouse{Mayoq} globe_hemisphere_east{Yer shari} map_pin{Manzil} map_trifold{Xarita} compass{Kompas} suitcase_rolling{Chamadon} backpack{Ryukzak} tent{Chodir} campfire{Gulxan} island{Orol} sunglasses{Quyosh ko‘zoynagi} city{Shahar} house{Uy} music_note{Nota} music_notes{Notalar} headphones{Quloqchin} guitar{Gitara} microphone{Mikrofon} microphone_stage{Sahna mikrofoni} piano_keys{Pianino} vinyl_record{Plastinka} cassette_tape{Kasseta} radio{Radio} palette{Palitra} paint_brush{Mo‘yqalam} pen_nib{Pero} camera{Fotoapparat} video_camera{Videokamera} film_strip{Kinolenta} film_slate{Kino xlopushkasi} ticket{Chipta} mask_happy{Kulgili niqob} mask_sad{G‘amgin niqob} book{Kitob} book_open{Ochiq kitob} books{Kitoblar} notebook{Daftar} graduation_cap{Bitiruv qalpog‘i} student{O‘quvchi} chalkboard_teacher{O‘qituvchi} pencil{Qalam} pencil_ruler{Qalam va chizg‘ich} briefcase{Portfel} laptop{Noutbuk} lightbulb{Lampochka} rocket{Raketa} target{Nishon} chart_line_up{O‘sish grafigi} calendar{Kalendar} clock{Soat} hourglass{Qum soat} atom{Atom} flask{Kolba} globe_stand{Globus} code{Kod} handshake{Qo‘l siqish} stethoscope{Stetoskop} check_circle{Tasdiq} x_circle{Bekor qilish} arrow_fat_right{Strelka} infinity{Cheksizlik} peace{Tinchlik} yin_yang{In-yan} smiley{Tabassum} smiley_wink{Ko‘z qisish} smiley_sad{Xafa smayl} smiley_angry{Jahldor smayl} smiley_melting{Eriyotgan smayl} thumbs_up{Layk} thumbs_down{Dizlayk} hand_heart{Qo‘ldagi yurak} hand_peace{G‘alaba ishorasi} hand_waving{Salom} hands_clapping{Qarsak} flag{Bayroq} shield{Qalqon} star_four{To‘rt qirrali yulduz} asterisk{Yulduzcha} quotes{Qo‘shtirnoq} hash{Xeshteg} at{Kuchukcha} circle{Doira} square{Kvadrat} triangle{Uchburchak} hexagon{Oltiburchak} diamond{Romb} ghost{Arvoh} alien{O‘zga sayyoralik} robot{Robot} other{-}}'**
  String editorDomainIconLabel(String name);

  /// No description provided for @editorDomainLayerElement.
  ///
  /// In uz, this message translates to:
  /// **'Element'**
  String get editorDomainLayerElement;

  /// No description provided for @editorDomainLayerIcon.
  ///
  /// In uz, this message translates to:
  /// **'Ikonka'**
  String get editorDomainLayerIcon;

  /// No description provided for @editorDomainLayerShape.
  ///
  /// In uz, this message translates to:
  /// **'Shakl'**
  String get editorDomainLayerShape;

  /// No description provided for @editorDomainMaxHeight.
  ///
  /// In uz, this message translates to:
  /// **'bo‘yi {max} mm dan oshmasin'**
  String editorDomainMaxHeight(String max);

  /// No description provided for @editorDomainMaxWidth.
  ///
  /// In uz, this message translates to:
  /// **'eni {max} mm dan oshmasin'**
  String editorDomainMaxWidth(String max);

  /// No description provided for @editorDomainMinFont.
  ///
  /// In uz, this message translates to:
  /// **'shrift kamida {min} mm bo‘lsin'**
  String editorDomainMinFont(String min);

  /// No description provided for @editorDomainNoArea.
  ///
  /// In uz, this message translates to:
  /// **'“{area}” hududi bu turda yo‘q'**
  String editorDomainNoArea(String area);

  /// No description provided for @editorDomainNoColor.
  ///
  /// In uz, this message translates to:
  /// **'bu usulda rang bo‘lmaydi'**
  String get editorDomainNoColor;

  /// No description provided for @editorDomainNoMethod.
  ///
  /// In uz, this message translates to:
  /// **'“{area}” hududida bu usul yo‘q'**
  String editorDomainNoMethod(String area);

  /// No description provided for @editorDomainOneMethod.
  ///
  /// In uz, this message translates to:
  /// **'dizayn bitta usulda bosiladi — bu element boshqa usulda'**
  String get editorDomainOneMethod;

  /// No description provided for @editorDomainOutOfZone.
  ///
  /// In uz, this message translates to:
  /// **'bosma zonasidan chiqib ketgan'**
  String get editorDomainOutOfZone;

  /// No description provided for @editorDomainProblemAt.
  ///
  /// In uz, this message translates to:
  /// **'{area}: {problem}'**
  String editorDomainProblemAt(String area, String problem);

  /// Name of a bundled shape, selected by its id with - replaced by _ (a lone - means unknown)
  ///
  /// In uz, this message translates to:
  /// **'{name, select, square{Kvadrat} rounded{Yumaloq burchakli} circle{Doira} triangle{Uchburchak} star{Yulduz} heart{Yurak} hexagon{Oltiburchak} diamond{Romb} burst{Nishon} semicircle{Yarim doira} bubble{Nutq pufagi} arrow{Strelka} plus{Plyus} ring{Halqa} frame{Ramka} frame_round{Yumaloq ramka} line{Chiziq} line_double{Qo‘sh chiziq} other{-}}'**
  String editorDomainShapeLabel(String name);

  /// No description provided for @editorElementsAll.
  ///
  /// In uz, this message translates to:
  /// **'Hammasi'**
  String get editorElementsAll;

  /// No description provided for @editorElementsClear.
  ///
  /// In uz, this message translates to:
  /// **'Tozalash'**
  String get editorElementsClear;

  /// No description provided for @editorElementsIcons.
  ///
  /// In uz, this message translates to:
  /// **'Ikonkalar'**
  String get editorElementsIcons;

  /// No description provided for @editorElementsLoadFailed.
  ///
  /// In uz, this message translates to:
  /// **'Elementlarni yuklab bo‘lmadi'**
  String get editorElementsLoadFailed;

  /// No description provided for @editorElementsNothingFound.
  ///
  /// In uz, this message translates to:
  /// **'Hech narsa topilmadi'**
  String get editorElementsNothingFound;

  /// No description provided for @editorElementsPopular.
  ///
  /// In uz, this message translates to:
  /// **'Ommabop'**
  String get editorElementsPopular;

  /// No description provided for @editorElementsSearch.
  ///
  /// In uz, this message translates to:
  /// **'Qidirish'**
  String get editorElementsSearch;

  /// No description provided for @editorElementsShapes.
  ///
  /// In uz, this message translates to:
  /// **'Shakllar'**
  String get editorElementsShapes;

  /// Sample word written in each font
  ///
  /// In uz, this message translates to:
  /// **'Salom'**
  String get editorFontSample;

  /// No description provided for @editorImageCamera.
  ///
  /// In uz, this message translates to:
  /// **'Kamera'**
  String get editorImageCamera;

  /// No description provided for @editorImageGallery.
  ///
  /// In uz, this message translates to:
  /// **'Galereya'**
  String get editorImageGallery;

  /// No description provided for @editorImageOpenFailed.
  ///
  /// In uz, this message translates to:
  /// **'Rasmni ochib bo‘lmadi'**
  String get editorImageOpenFailed;

  /// No description provided for @editorImageUnsupported.
  ///
  /// In uz, this message translates to:
  /// **'Faqat PNG, JPG yoki WEBP rasm yuklash mumkin'**
  String get editorImageUnsupported;

  /// No description provided for @editorImageUploadFailed.
  ///
  /// In uz, this message translates to:
  /// **'Rasmni yuklab bo‘lmadi'**
  String get editorImageUploadFailed;

  /// No description provided for @editorLayersEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Bu tomonda hali element yo‘q'**
  String get editorLayersEmpty;

  /// No description provided for @editorLayersHidden.
  ///
  /// In uz, this message translates to:
  /// **'Yashirilgan'**
  String get editorLayersHidden;

  /// No description provided for @editorLayersHide.
  ///
  /// In uz, this message translates to:
  /// **'Yashirish'**
  String get editorLayersHide;

  /// No description provided for @editorLayersLock.
  ///
  /// In uz, this message translates to:
  /// **'Qulflash'**
  String get editorLayersLock;

  /// No description provided for @editorLayersOpen.
  ///
  /// In uz, this message translates to:
  /// **'Ochish'**
  String get editorLayersOpen;

  /// No description provided for @editorLayersShow.
  ///
  /// In uz, this message translates to:
  /// **'Ko‘rsatish'**
  String get editorLayersShow;

  /// No description provided for @editorLayersSyncedWith.
  ///
  /// In uz, this message translates to:
  /// **'“{area}” bilan sinxron'**
  String editorLayersSyncedWith(String area);

  /// No description provided for @editorLayersUnlock.
  ///
  /// In uz, this message translates to:
  /// **'Qulfdan chiqarish'**
  String get editorLayersUnlock;

  /// No description provided for @editorMain3dFailed.
  ///
  /// In uz, this message translates to:
  /// **'3D ko‘rinishni ochib bo‘lmadi'**
  String get editorMain3dFailed;

  /// No description provided for @editorMain3dLoading.
  ///
  /// In uz, this message translates to:
  /// **'3D model yuklanmoqda…'**
  String get editorMain3dLoading;

  /// No description provided for @editorMain3dView.
  ///
  /// In uz, this message translates to:
  /// **'3D ko‘rinish'**
  String get editorMain3dView;

  /// No description provided for @editorMainActions.
  ///
  /// In uz, this message translates to:
  /// **'Amallar'**
  String get editorMainActions;

  /// No description provided for @editorMainAddSomethingFirst.
  ///
  /// In uz, this message translates to:
  /// **'Avval rasm yoki matn qo‘shing'**
  String get editorMainAddSomethingFirst;

  /// No description provided for @editorMainAddToCart.
  ///
  /// In uz, this message translates to:
  /// **'Savatga'**
  String get editorMainAddToCart;

  /// No description provided for @editorMainAddToCartFailed.
  ///
  /// In uz, this message translates to:
  /// **'Savatga qo‘shib bo‘lmadi'**
  String get editorMainAddToCartFailed;

  /// No description provided for @editorMainAreaNoMethod.
  ///
  /// In uz, this message translates to:
  /// **'“{area}” hududida bu usul yo‘q'**
  String editorMainAreaNoMethod(String area);

  /// No description provided for @editorMainAreaNoMethodClear.
  ///
  /// In uz, this message translates to:
  /// **'“{area}” hududida bu usul yo‘q: u yerdagi elementlarni olib tashlang'**
  String editorMainAreaNoMethodClear(String area);

  /// No description provided for @editorMainAreaSynced.
  ///
  /// In uz, this message translates to:
  /// **'Bu tomon boshqa tomon bilan sinxron'**
  String get editorMainAreaSynced;

  /// No description provided for @editorMainAreaSyncedWith.
  ///
  /// In uz, this message translates to:
  /// **'Bu tomon “{area}” bilan sinxron: “{area}”da tahrirlang'**
  String editorMainAreaSyncedWith(String area);

  /// No description provided for @editorMainBadImage.
  ///
  /// In uz, this message translates to:
  /// **'Rasm noto‘g‘ri'**
  String get editorMainBadImage;

  /// No description provided for @editorMainBringForward.
  ///
  /// In uz, this message translates to:
  /// **'Oldinga'**
  String get editorMainBringForward;

  /// No description provided for @editorMainCannotAddHere.
  ///
  /// In uz, this message translates to:
  /// **'Bu hududga qo‘shib bo‘lmaydi'**
  String get editorMainCannotAddHere;

  /// No description provided for @editorMainCapture.
  ///
  /// In uz, this message translates to:
  /// **'Rasmga olish'**
  String get editorMainCapture;

  /// No description provided for @editorMainCenter.
  ///
  /// In uz, this message translates to:
  /// **'Markaz'**
  String get editorMainCenter;

  /// No description provided for @editorMainCopy.
  ///
  /// In uz, this message translates to:
  /// **'Nusxa'**
  String get editorMainCopy;

  /// No description provided for @editorMainCroppedBadge.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{{count} ta kesiladi} other{{count} ta kesiladi}}'**
  String editorMainCroppedBadge(int count);

  /// No description provided for @editorMainDuplicate.
  ///
  /// In uz, this message translates to:
  /// **'Nusxa olish'**
  String get editorMainDuplicate;

  /// Selection bar: edit the selected text
  ///
  /// In uz, this message translates to:
  /// **'Matn'**
  String get editorMainEditTextShort;

  /// No description provided for @editorMainEngineBroken.
  ///
  /// In uz, this message translates to:
  /// **'3D ko‘rinish ishlamayapti'**
  String get editorMainEngineBroken;

  /// No description provided for @editorMainEngineClosed.
  ///
  /// In uz, this message translates to:
  /// **'Yopildi'**
  String get editorMainEngineClosed;

  /// No description provided for @editorMainEngineConnectFailed.
  ///
  /// In uz, this message translates to:
  /// **'3D ko‘rinishga ulanib bo‘lmadi'**
  String get editorMainEngineConnectFailed;

  /// No description provided for @editorMainEngineLoadFailed.
  ///
  /// In uz, this message translates to:
  /// **'3D ko‘rinish yuklanmadi'**
  String get editorMainEngineLoadFailed;

  /// No description provided for @editorMainEngineNoAnswer.
  ///
  /// In uz, this message translates to:
  /// **'3D ko‘rinish javob bermadi'**
  String get editorMainEngineNoAnswer;

  /// No description provided for @editorMainEngineNotReady.
  ///
  /// In uz, this message translates to:
  /// **'3D ko‘rinish hali tayyor emas'**
  String get editorMainEngineNotReady;

  /// No description provided for @editorMainEngineReloaded.
  ///
  /// In uz, this message translates to:
  /// **'3D ko‘rinish qayta yuklandi'**
  String get editorMainEngineReloaded;

  /// No description provided for @editorMainEngineStartFailed.
  ///
  /// In uz, this message translates to:
  /// **'3D ko‘rinishni ishga tushirib bo‘lmadi'**
  String get editorMainEngineStartFailed;

  /// No description provided for @editorMainError.
  ///
  /// In uz, this message translates to:
  /// **'Xato'**
  String get editorMainError;

  /// No description provided for @editorMainErrorsBadge.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{{count} ta xato} other{{count} ta xato}}'**
  String editorMainErrorsBadge(int count);

  /// No description provided for @editorMainFileSaveFailed.
  ///
  /// In uz, this message translates to:
  /// **'Faylni saqlab bo‘lmadi ({status}). Qayta urinib ko‘ring.'**
  String editorMainFileSaveFailed(String status);

  /// No description provided for @editorMainFixRedItems.
  ///
  /// In uz, this message translates to:
  /// **'Qizil belgilangan elementlarni tuzating'**
  String get editorMainFixRedItems;

  /// No description provided for @editorMainFlatView.
  ///
  /// In uz, this message translates to:
  /// **'Tekis ko‘rinish'**
  String get editorMainFlatView;

  /// No description provided for @editorMainHide.
  ///
  /// In uz, this message translates to:
  /// **'Yashirish'**
  String get editorMainHide;

  /// No description provided for @editorMainLock.
  ///
  /// In uz, this message translates to:
  /// **'Qulflash'**
  String get editorMainLock;

  /// No description provided for @editorMainLocked.
  ///
  /// In uz, this message translates to:
  /// **'Qulfli'**
  String get editorMainLocked;

  /// No description provided for @editorMainMenuEditText.
  ///
  /// In uz, this message translates to:
  /// **'Matnni o‘zgartirish'**
  String get editorMainMenuEditText;

  /// No description provided for @editorMainMethodSwitched.
  ///
  /// In uz, this message translates to:
  /// **'Dizayn “{method}” usuliga o‘tkazildi'**
  String editorMainMethodSwitched(String method);

  /// No description provided for @editorMainNoPrintFile.
  ///
  /// In uz, this message translates to:
  /// **'Bosma fayl chiqmadi'**
  String get editorMainNoPrintFile;

  /// No description provided for @editorMainNoViews.
  ///
  /// In uz, this message translates to:
  /// **'Ko‘rinish rasmlari olinmadi'**
  String get editorMainNoViews;

  /// No description provided for @editorMainNotSaved.
  ///
  /// In uz, this message translates to:
  /// **'Saqlanmadi'**
  String get editorMainNotSaved;

  /// No description provided for @editorMainPickSizeFirst.
  ///
  /// In uz, this message translates to:
  /// **'Avval o‘lchamni tanlang'**
  String get editorMainPickSizeFirst;

  /// No description provided for @editorMainPickTool.
  ///
  /// In uz, this message translates to:
  /// **'Asbobni tanlang'**
  String get editorMainPickTool;

  /// No description provided for @editorMainPriceRecalculated.
  ///
  /// In uz, this message translates to:
  /// **'Narx qayta hisoblandi'**
  String get editorMainPriceRecalculated;

  /// No description provided for @editorMainProductColor.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot rangi'**
  String get editorMainProductColor;

  /// No description provided for @editorMainProductColorBackground.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot rangida fon'**
  String get editorMainProductColorBackground;

  /// No description provided for @editorMainRedo.
  ///
  /// In uz, this message translates to:
  /// **'Qaytarish'**
  String get editorMainRedo;

  /// No description provided for @editorMainReloadedNewer.
  ///
  /// In uz, this message translates to:
  /// **'Dizayn boshqa joyda o‘zgartirilgan edi: oxirgi holati yuklandi'**
  String get editorMainReloadedNewer;

  /// No description provided for @editorMainResetView.
  ///
  /// In uz, this message translates to:
  /// **'Ko‘rinishni tiklash'**
  String get editorMainResetView;

  /// No description provided for @editorMainSaveFailed.
  ///
  /// In uz, this message translates to:
  /// **'Saqlab bo‘lmadi'**
  String get editorMainSaveFailed;

  /// No description provided for @editorMainSaveFailedOffline.
  ///
  /// In uz, this message translates to:
  /// **'Saqlab bo‘lmadi. Internetni tekshiring'**
  String get editorMainSaveFailedOffline;

  /// No description provided for @editorMainSaved.
  ///
  /// In uz, this message translates to:
  /// **'Dizayn saqlandi'**
  String get editorMainSaved;

  /// No description provided for @editorMainSendBackward.
  ///
  /// In uz, this message translates to:
  /// **'Orqaga'**
  String get editorMainSendBackward;

  /// No description provided for @editorMainSettings.
  ///
  /// In uz, this message translates to:
  /// **'Sozlash'**
  String get editorMainSettings;

  /// No description provided for @editorMainStepAddingToCart.
  ///
  /// In uz, this message translates to:
  /// **'Savatga qo‘shilmoqda…'**
  String get editorMainStepAddingToCart;

  /// No description provided for @editorMainStepPrintFiles.
  ///
  /// In uz, this message translates to:
  /// **'Bosma fayllar tayyorlanmoqda…'**
  String get editorMainStepPrintFiles;

  /// No description provided for @editorMainStepSaving.
  ///
  /// In uz, this message translates to:
  /// **'Dizayn saqlanmoqda…'**
  String get editorMainStepSaving;

  /// No description provided for @editorMainStepUploading.
  ///
  /// In uz, this message translates to:
  /// **'Yuklanmoqda… {current}/{total}'**
  String editorMainStepUploading(int current, int total);

  /// No description provided for @editorMainStepViews.
  ///
  /// In uz, this message translates to:
  /// **'Rasmlar olinmoqda…'**
  String get editorMainStepViews;

  /// No description provided for @editorMainSyncedFrom.
  ///
  /// In uz, this message translates to:
  /// **'“{area}”dan sinxron'**
  String editorMainSyncedFrom(String area);

  /// No description provided for @editorMainTemplateApplied.
  ///
  /// In uz, this message translates to:
  /// **'“{name}” shabloni qo‘yildi'**
  String editorMainTemplateApplied(String name);

  /// No description provided for @editorMainTextPlaceholder.
  ///
  /// In uz, this message translates to:
  /// **'Matningiz shu yerda'**
  String get editorMainTextPlaceholder;

  /// No description provided for @editorMainTitle.
  ///
  /// In uz, this message translates to:
  /// **'Dizayn yaratish'**
  String get editorMainTitle;

  /// No description provided for @editorMainTooManyLayers.
  ///
  /// In uz, this message translates to:
  /// **'{max, plural, one{Bitta dizaynda {max} tadan ko‘p element bo‘lmaydi} other{Bitta dizaynda {max} tadan ko‘p element bo‘lmaydi}}'**
  String editorMainTooManyLayers(int max);

  /// No description provided for @editorMainToolBackground.
  ///
  /// In uz, this message translates to:
  /// **'Fon'**
  String get editorMainToolBackground;

  /// No description provided for @editorMainToolElements.
  ///
  /// In uz, this message translates to:
  /// **'Elementlar'**
  String get editorMainToolElements;

  /// No description provided for @editorMainToolGallery.
  ///
  /// In uz, this message translates to:
  /// **'Galereya'**
  String get editorMainToolGallery;

  /// No description provided for @editorMainToolImage.
  ///
  /// In uz, this message translates to:
  /// **'Rasm'**
  String get editorMainToolImage;

  /// No description provided for @editorMainToolLayers.
  ///
  /// In uz, this message translates to:
  /// **'Qatlamlar'**
  String get editorMainToolLayers;

  /// No description provided for @editorMainToolText.
  ///
  /// In uz, this message translates to:
  /// **'Matn'**
  String get editorMainToolText;

  /// No description provided for @editorMainUndo.
  ///
  /// In uz, this message translates to:
  /// **'Ortga qaytarish'**
  String get editorMainUndo;

  /// No description provided for @editorMainUndoAction.
  ///
  /// In uz, this message translates to:
  /// **'Ortga'**
  String get editorMainUndoAction;

  /// No description provided for @editorMainUnknownError.
  ///
  /// In uz, this message translates to:
  /// **'Noma’lum xato'**
  String get editorMainUnknownError;

  /// No description provided for @editorMainUnlock.
  ///
  /// In uz, this message translates to:
  /// **'Qulfdan chiqarish'**
  String get editorMainUnlock;

  /// No description provided for @editorMainVariantNoMethod.
  ///
  /// In uz, this message translates to:
  /// **'Bu variantda bu usul yo‘q'**
  String get editorMainVariantNoMethod;

  /// No description provided for @editorMainVariantReplaced.
  ///
  /// In uz, this message translates to:
  /// **'Oldin tanlangan variant hozir sotuvda yo‘q, boshqasi tanlandi'**
  String get editorMainVariantReplaced;

  /// No description provided for @editorPropsAlignCenter.
  ///
  /// In uz, this message translates to:
  /// **'Markazga'**
  String get editorPropsAlignCenter;

  /// No description provided for @editorPropsAlignLeft.
  ///
  /// In uz, this message translates to:
  /// **'Chapga'**
  String get editorPropsAlignLeft;

  /// No description provided for @editorPropsAlignRight.
  ///
  /// In uz, this message translates to:
  /// **'O‘ngga'**
  String get editorPropsAlignRight;

  /// No description provided for @editorPropsBackground.
  ///
  /// In uz, this message translates to:
  /// **'Fon'**
  String get editorPropsBackground;

  /// No description provided for @editorPropsBold.
  ///
  /// In uz, this message translates to:
  /// **'Qalin'**
  String get editorPropsBold;

  /// No description provided for @editorPropsCenterX.
  ///
  /// In uz, this message translates to:
  /// **'Markaz (eni)'**
  String get editorPropsCenterX;

  /// No description provided for @editorPropsCenterY.
  ///
  /// In uz, this message translates to:
  /// **'Markaz (bo‘yi)'**
  String get editorPropsCenterY;

  /// No description provided for @editorPropsColor.
  ///
  /// In uz, this message translates to:
  /// **'Rang'**
  String get editorPropsColor;

  /// No description provided for @editorPropsCropped.
  ///
  /// In uz, this message translates to:
  /// **'Zonadan chiqqan qismi bosilmaydi'**
  String get editorPropsCropped;

  /// No description provided for @editorPropsDialNumerals.
  ///
  /// In uz, this message translates to:
  /// **'Soat raqamlari'**
  String get editorPropsDialNumerals;

  /// No description provided for @editorPropsFontSize.
  ///
  /// In uz, this message translates to:
  /// **'Shrift'**
  String get editorPropsFontSize;

  /// No description provided for @editorPropsImage.
  ///
  /// In uz, this message translates to:
  /// **'Rasm'**
  String get editorPropsImage;

  /// No description provided for @editorPropsItalic.
  ///
  /// In uz, this message translates to:
  /// **'Kursiv'**
  String get editorPropsItalic;

  /// No description provided for @editorPropsLowQuality.
  ///
  /// In uz, this message translates to:
  /// **'Rasm sifati past'**
  String get editorPropsLowQuality;

  /// No description provided for @editorPropsMinuteTicks.
  ///
  /// In uz, this message translates to:
  /// **'Daqiqa chiziqlari'**
  String get editorPropsMinuteTicks;

  /// No description provided for @editorPropsMm.
  ///
  /// In uz, this message translates to:
  /// **'{value} mm'**
  String editorPropsMm(String value);

  /// Clock face without numerals
  ///
  /// In uz, this message translates to:
  /// **'Yo‘q'**
  String get editorPropsNumeralsNone;

  /// No description provided for @editorPropsRemoveBackground.
  ///
  /// In uz, this message translates to:
  /// **'Fonni olib tashlash'**
  String get editorPropsRemoveBackground;

  /// No description provided for @editorPropsRotation.
  ///
  /// In uz, this message translates to:
  /// **'Burchak'**
  String get editorPropsRotation;

  /// No description provided for @editorPropsSize.
  ///
  /// In uz, this message translates to:
  /// **'O‘lcham'**
  String get editorPropsSize;

  /// No description provided for @editorPropsSticker.
  ///
  /// In uz, this message translates to:
  /// **'Stiker'**
  String get editorPropsSticker;

  /// No description provided for @editorPropsStraighten.
  ///
  /// In uz, this message translates to:
  /// **'Tekislash'**
  String get editorPropsStraighten;

  /// No description provided for @editorSheet3dNotReady.
  ///
  /// In uz, this message translates to:
  /// **'3D ko‘rinish hali tayyor emas'**
  String get editorSheet3dNotReady;

  /// No description provided for @editorSheetAddAtPrice.
  ///
  /// In uz, this message translates to:
  /// **'Shu narxda qo‘shish'**
  String get editorSheetAddAtPrice;

  /// No description provided for @editorSheetAddedToCart.
  ///
  /// In uz, this message translates to:
  /// **'Savatga qo‘shildi'**
  String get editorSheetAddedToCart;

  /// No description provided for @editorSheetCapture.
  ///
  /// In uz, this message translates to:
  /// **'Rasmga olish'**
  String get editorSheetCapture;

  /// No description provided for @editorSheetCaptureFailed.
  ///
  /// In uz, this message translates to:
  /// **'Rasmga olib bo‘lmadi'**
  String get editorSheetCaptureFailed;

  /// No description provided for @editorSheetClear.
  ///
  /// In uz, this message translates to:
  /// **'Tozalash'**
  String get editorSheetClear;

  /// No description provided for @editorSheetClearConfirm.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{{area}dagi {count} ta element o‘chirilsinmi?} other{{area}dagi {count} ta element o‘chirilsinmi?}}'**
  String editorSheetClearConfirm(int count, String area);

  /// No description provided for @editorSheetClearSide.
  ///
  /// In uz, this message translates to:
  /// **'Tomonni tozalash'**
  String get editorSheetClearSide;

  /// No description provided for @editorSheetClearSideCount.
  ///
  /// In uz, this message translates to:
  /// **'Tomonni tozalash ({count})'**
  String editorSheetClearSideCount(int count);

  /// No description provided for @editorSheetColorNamed.
  ///
  /// In uz, this message translates to:
  /// **'Rang: {name}'**
  String editorSheetColorNamed(String name);

  /// No description provided for @editorSheetContinue.
  ///
  /// In uz, this message translates to:
  /// **'Davom etish'**
  String get editorSheetContinue;

  /// No description provided for @editorSheetCurrentView.
  ///
  /// In uz, this message translates to:
  /// **'Hozirgi ko‘rinish'**
  String get editorSheetCurrentView;

  /// No description provided for @editorSheetGalleryDenied.
  ///
  /// In uz, this message translates to:
  /// **'Galereyaga ruxsat berilmadi'**
  String get editorSheetGalleryDenied;

  /// No description provided for @editorSheetGallerySaveFailed.
  ///
  /// In uz, this message translates to:
  /// **'Galereyaga saqlab bo‘lmadi'**
  String get editorSheetGallerySaveFailed;

  /// No description provided for @editorSheetGoToCart.
  ///
  /// In uz, this message translates to:
  /// **'Savatga o‘tish'**
  String get editorSheetGoToCart;

  /// No description provided for @editorSheetGrid.
  ///
  /// In uz, this message translates to:
  /// **'To‘r'**
  String get editorSheetGrid;

  /// No description provided for @editorSheetImageSaved.
  ///
  /// In uz, this message translates to:
  /// **'Rasm saqlandi'**
  String get editorSheetImageSaved;

  /// No description provided for @editorSheetImagesCount.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{{count} ta rasm} other{{count} ta rasm}}'**
  String editorSheetImagesCount(int count);

  /// No description provided for @editorSheetImagesSaved.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{{count} ta rasm saqlandi} other{{count} ta rasm saqlandi}}'**
  String editorSheetImagesSaved(int count);

  /// No description provided for @editorSheetLinkedElsewhere.
  ///
  /// In uz, this message translates to:
  /// **'o‘zi boshqa tomonlarga ulangan'**
  String get editorSheetLinkedElsewhere;

  /// No description provided for @editorSheetLostElements.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{{count} ta element bu turda joylashmaydi} other{{count} ta element bu turda joylashmaydi}}'**
  String editorSheetLostElements(int count);

  /// No description provided for @editorSheetMirrored.
  ///
  /// In uz, this message translates to:
  /// **'{name} (ko‘zgu)'**
  String editorSheetMirrored(String name);

  /// No description provided for @editorSheetOwnHidden.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{{count} ta elementi yashiriladi} other{{count} ta elementi yashiriladi}}'**
  String editorSheetOwnHidden(int count);

  /// No description provided for @editorSheetPrice.
  ///
  /// In uz, this message translates to:
  /// **'Narxi'**
  String get editorSheetPrice;

  /// No description provided for @editorSheetPriceRecalculated.
  ///
  /// In uz, this message translates to:
  /// **'Narx bosma fayllar bo‘yicha qayta hisoblandi'**
  String get editorSheetPriceRecalculated;

  /// No description provided for @editorSheetPrintMethod.
  ///
  /// In uz, this message translates to:
  /// **'Bosish usuli'**
  String get editorSheetPrintMethod;

  /// No description provided for @editorSheetProduct.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot'**
  String get editorSheetProduct;

  /// No description provided for @editorSheetReplace.
  ///
  /// In uz, this message translates to:
  /// **'Almashtirish'**
  String get editorSheetReplace;

  /// No description provided for @editorSheetSelfSynced.
  ///
  /// In uz, this message translates to:
  /// **'Bu tomon o‘zi boshqa tomondan sinxron'**
  String get editorSheetSelfSynced;

  /// No description provided for @editorSheetShare.
  ///
  /// In uz, this message translates to:
  /// **'Ulashish'**
  String get editorSheetShare;

  /// No description provided for @editorSheetSides.
  ///
  /// In uz, this message translates to:
  /// **'Tomonlar'**
  String get editorSheetSides;

  /// No description provided for @editorSheetSize.
  ///
  /// In uz, this message translates to:
  /// **'O‘lcham'**
  String get editorSheetSize;

  /// No description provided for @editorSheetSnapping.
  ///
  /// In uz, this message translates to:
  /// **'Yopishish'**
  String get editorSheetSnapping;

  /// No description provided for @editorSheetSync.
  ///
  /// In uz, this message translates to:
  /// **'Sinxronlash'**
  String get editorSheetSync;

  /// No description provided for @editorSheetSyncedFrom.
  ///
  /// In uz, this message translates to:
  /// **'“{area}”dan sinxron'**
  String editorSheetSyncedFrom(String area);

  /// No description provided for @editorSheetSyncedTo.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{{count} ta tomonga sinxron} other{{count} ta tomonga sinxron}}'**
  String editorSheetSyncedTo(int count);

  /// No description provided for @editorSheetText.
  ///
  /// In uz, this message translates to:
  /// **'Matn'**
  String get editorSheetText;

  /// No description provided for @editorSheetToGallery.
  ///
  /// In uz, this message translates to:
  /// **'Galereyaga'**
  String get editorSheetToGallery;

  /// Product variant (type) picker title
  ///
  /// In uz, this message translates to:
  /// **'Tur'**
  String get editorSheetType;

  /// No description provided for @editorTemplatesEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Bu tur uchun shablon yo‘q'**
  String get editorTemplatesEmpty;

  /// No description provided for @editorTextAdd.
  ///
  /// In uz, this message translates to:
  /// **'Matn qo‘shish'**
  String get editorTextAdd;

  /// No description provided for @editorTextBestDad.
  ///
  /// In uz, this message translates to:
  /// **'Eng yaxshi dadam'**
  String get editorTextBestDad;

  /// No description provided for @editorTextBigHeading.
  ///
  /// In uz, this message translates to:
  /// **'KATTA SARLAVHA'**
  String get editorTextBigHeading;

  /// No description provided for @editorTextBirthday.
  ///
  /// In uz, this message translates to:
  /// **'Tug‘ilgan kuning bilan!'**
  String get editorTextBirthday;

  /// No description provided for @editorTextCongrats.
  ///
  /// In uz, this message translates to:
  /// **'Tabriklayman!'**
  String get editorTextCongrats;

  /// No description provided for @editorTextElegant.
  ///
  /// In uz, this message translates to:
  /// **'Nafis sarlavha'**
  String get editorTextElegant;

  /// No description provided for @editorTextFonts.
  ///
  /// In uz, this message translates to:
  /// **'Shriftlar'**
  String get editorTextFonts;

  /// No description provided for @editorTextGoodDays.
  ///
  /// In uz, this message translates to:
  /// **'Yaxshi kunlar'**
  String get editorTextGoodDays;

  /// No description provided for @editorTextHeading.
  ///
  /// In uz, this message translates to:
  /// **'Sarlavha'**
  String get editorTextHeading;

  /// Default text of a new text layer
  ///
  /// In uz, this message translates to:
  /// **'Matningiz shu yerda'**
  String get editorTextPlaceholder;

  /// No description provided for @editorTextSubheading.
  ///
  /// In uz, this message translates to:
  /// **'Kichik sarlavha'**
  String get editorTextSubheading;

  /// No description provided for @editorTextWithLove.
  ///
  /// In uz, this message translates to:
  /// **'Sevgi bilan'**
  String get editorTextWithLove;

  /// No description provided for @errorCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilindi'**
  String get errorCancelled;

  /// No description provided for @errorForbidden.
  ///
  /// In uz, this message translates to:
  /// **'Ruxsat yo‘q'**
  String get errorForbidden;

  /// No description provided for @errorGeneric.
  ///
  /// In uz, this message translates to:
  /// **'Nimadir xato ketdi'**
  String get errorGeneric;

  /// No description provided for @errorInsecure.
  ///
  /// In uz, this message translates to:
  /// **'Xavfsiz ulanib bo‘lmadi'**
  String get errorInsecure;

  /// No description provided for @errorNoInternet.
  ///
  /// In uz, this message translates to:
  /// **'Internet aloqasi yo‘q'**
  String get errorNoInternet;

  /// No description provided for @errorNotFound.
  ///
  /// In uz, this message translates to:
  /// **'Topilmadi'**
  String get errorNotFound;

  /// No description provided for @errorServer.
  ///
  /// In uz, this message translates to:
  /// **'Serverda xatolik'**
  String get errorServer;

  /// No description provided for @errorSignInAgain.
  ///
  /// In uz, this message translates to:
  /// **'Qaytadan kiring'**
  String get errorSignInAgain;

  /// No description provided for @errorTimeout.
  ///
  /// In uz, this message translates to:
  /// **'Server javob bermadi'**
  String get errorTimeout;

  /// No description provided for @homeCategories.
  ///
  /// In uz, this message translates to:
  /// **'Turkumlar'**
  String get homeCategories;

  /// No description provided for @homeChooseProduct.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot tanlang'**
  String get homeChooseProduct;

  /// No description provided for @homeCreateDesign.
  ///
  /// In uz, this message translates to:
  /// **'Dizayn yaratish'**
  String get homeCreateDesign;

  /// No description provided for @homeGallery.
  ///
  /// In uz, this message translates to:
  /// **'Galereya'**
  String get homeGallery;

  /// No description provided for @homeHeroTitle.
  ///
  /// In uz, this message translates to:
  /// **'Krujka, futbolka, soat —\no‘z dizayningiz bilan'**
  String get homeHeroTitle;

  /// No description provided for @homeNoProducts.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlar yo‘q'**
  String get homeNoProducts;

  /// No description provided for @homeSearch.
  ///
  /// In uz, this message translates to:
  /// **'Qidirish'**
  String get homeSearch;

  /// No description provided for @homeSeeAll.
  ///
  /// In uz, this message translates to:
  /// **'Barchasi'**
  String get homeSeeAll;

  /// No description provided for @languageChoose.
  ///
  /// In uz, this message translates to:
  /// **'Tilni tanlang'**
  String get languageChoose;

  /// No description provided for @languageSystemHint.
  ///
  /// In uz, this message translates to:
  /// **'Ilova tili'**
  String get languageSystemHint;

  /// No description provided for @languageTitle.
  ///
  /// In uz, this message translates to:
  /// **'Til'**
  String get languageTitle;

  /// No description provided for @materialCeramicGlossy.
  ///
  /// In uz, this message translates to:
  /// **'Keramika, yaltiroq'**
  String get materialCeramicGlossy;

  /// No description provided for @materialCeramicMatte.
  ///
  /// In uz, this message translates to:
  /// **'Keramika, matoviy'**
  String get materialCeramicMatte;

  /// No description provided for @materialFabric.
  ///
  /// In uz, this message translates to:
  /// **'Mato'**
  String get materialFabric;

  /// No description provided for @materialGlassClear.
  ///
  /// In uz, this message translates to:
  /// **'Shisha, tiniq'**
  String get materialGlassClear;

  /// No description provided for @materialGlassFrosted.
  ///
  /// In uz, this message translates to:
  /// **'Shisha, matoviy'**
  String get materialGlassFrosted;

  /// No description provided for @materialMetal.
  ///
  /// In uz, this message translates to:
  /// **'Metall'**
  String get materialMetal;

  /// No description provided for @materialPaper.
  ///
  /// In uz, this message translates to:
  /// **'Qog‘oz'**
  String get materialPaper;

  /// No description provided for @materialPlastic.
  ///
  /// In uz, this message translates to:
  /// **'Plastik'**
  String get materialPlastic;

  /// No description provided for @materialWood.
  ///
  /// In uz, this message translates to:
  /// **'Yog‘och'**
  String get materialWood;

  /// No description provided for @navCart.
  ///
  /// In uz, this message translates to:
  /// **'Savat'**
  String get navCart;

  /// No description provided for @navDesigns.
  ///
  /// In uz, this message translates to:
  /// **'Dizaynlarim'**
  String get navDesigns;

  /// No description provided for @navHome.
  ///
  /// In uz, this message translates to:
  /// **'Asosiy'**
  String get navHome;

  /// No description provided for @navProducts.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlar'**
  String get navProducts;

  /// No description provided for @navProfile.
  ///
  /// In uz, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @orderNextInProduction.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotingiz tayyorlanmoqda'**
  String get orderNextInProduction;

  /// No description provided for @orderNextNew.
  ///
  /// In uz, this message translates to:
  /// **'Operator tez orada bog‘lanadi'**
  String get orderNextNew;

  /// No description provided for @orderNextPaid.
  ///
  /// In uz, this message translates to:
  /// **'Tez orada ishlab chiqarishga beriladi'**
  String get orderNextPaid;

  /// No description provided for @orderNextPaymentPending.
  ///
  /// In uz, this message translates to:
  /// **'To‘lovingiz kutilmoqda'**
  String get orderNextPaymentPending;

  /// No description provided for @orderNextQualityCheck.
  ///
  /// In uz, this message translates to:
  /// **'Sifati tekshirilmoqda'**
  String get orderNextQualityCheck;

  /// No description provided for @orderNextReadyForDelivery.
  ///
  /// In uz, this message translates to:
  /// **'Tez orada yetkaziladi'**
  String get orderNextReadyForDelivery;

  /// No description provided for @orderNextReadyForPickup.
  ///
  /// In uz, this message translates to:
  /// **'Olib ketishingiz mumkin'**
  String get orderNextReadyForPickup;

  /// No description provided for @orderStatusCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilingan'**
  String get orderStatusCancelled;

  /// No description provided for @orderStatusCompleted.
  ///
  /// In uz, this message translates to:
  /// **'Yakunlangan'**
  String get orderStatusCompleted;

  /// No description provided for @orderStatusInProduction.
  ///
  /// In uz, this message translates to:
  /// **'Ishlab chiqarilmoqda'**
  String get orderStatusInProduction;

  /// No description provided for @orderStatusNew.
  ///
  /// In uz, this message translates to:
  /// **'Yangi'**
  String get orderStatusNew;

  /// No description provided for @orderStatusPaid.
  ///
  /// In uz, this message translates to:
  /// **'To‘langan'**
  String get orderStatusPaid;

  /// No description provided for @orderStatusPaymentPending.
  ///
  /// In uz, this message translates to:
  /// **'To‘lov kutilmoqda'**
  String get orderStatusPaymentPending;

  /// No description provided for @orderStatusQualityCheck.
  ///
  /// In uz, this message translates to:
  /// **'Sifat nazorati'**
  String get orderStatusQualityCheck;

  /// No description provided for @orderStatusReadyForDelivery.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazishga tayyor'**
  String get orderStatusReadyForDelivery;

  /// No description provided for @orderStatusReadyForPickup.
  ///
  /// In uz, this message translates to:
  /// **'Olib ketishga tayyor'**
  String get orderStatusReadyForPickup;

  /// No description provided for @orderStatusReadyForProduction.
  ///
  /// In uz, this message translates to:
  /// **'Ishlab chiqarishga tayyor'**
  String get orderStatusReadyForProduction;

  /// No description provided for @orderStepAccepted.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilindi'**
  String get orderStepAccepted;

  /// No description provided for @orderStepDone.
  ///
  /// In uz, this message translates to:
  /// **'Yakunlandi'**
  String get orderStepDone;

  /// No description provided for @orderStepPayment.
  ///
  /// In uz, this message translates to:
  /// **'To‘lov'**
  String get orderStepPayment;

  /// No description provided for @orderStepProduction.
  ///
  /// In uz, this message translates to:
  /// **'Ishlab chiqarish'**
  String get orderStepProduction;

  /// No description provided for @orderStepReady.
  ///
  /// In uz, this message translates to:
  /// **'Tayyor'**
  String get orderStepReady;

  /// No description provided for @ordersAll.
  ///
  /// In uz, this message translates to:
  /// **'Barcha buyurtmalar'**
  String get ordersAll;

  /// No description provided for @ordersCancelAction.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish'**
  String get ordersCancelAction;

  /// No description provided for @ordersCancelConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani bekor qilasizmi?'**
  String get ordersCancelConfirm;

  /// No description provided for @ordersCancelKeep.
  ///
  /// In uz, this message translates to:
  /// **'Yo‘q'**
  String get ordersCancelKeep;

  /// No description provided for @ordersCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma bekor qilindi'**
  String get ordersCancelled;

  /// No description provided for @ordersCancelledBanner.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma bekor qilingan'**
  String get ordersCancelledBanner;

  /// No description provided for @ordersChooseProduct.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot tanlash'**
  String get ordersChooseProduct;

  /// No description provided for @ordersDetailTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma №{number}'**
  String ordersDetailTitle(String number);

  /// No description provided for @ordersDiscount.
  ///
  /// In uz, this message translates to:
  /// **'Chegirma'**
  String get ordersDiscount;

  /// No description provided for @ordersEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hali buyurtma yo‘q'**
  String get ordersEmpty;

  /// No description provided for @ordersFree.
  ///
  /// In uz, this message translates to:
  /// **'Bepul'**
  String get ordersFree;

  /// No description provided for @ordersItemCount.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{{count} ta mahsulot} other{{count} ta mahsulot}}'**
  String ordersItemCount(int count);

  /// No description provided for @ordersItems.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlar'**
  String get ordersItems;

  /// No description provided for @ordersLeaveReview.
  ///
  /// In uz, this message translates to:
  /// **'Fikr qoldirish'**
  String get ordersLeaveReview;

  /// No description provided for @ordersMore.
  ///
  /// In uz, this message translates to:
  /// **'Yana'**
  String get ordersMore;

  /// No description provided for @ordersNotFound.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma topilmadi'**
  String get ordersNotFound;

  /// No description provided for @ordersNumber.
  ///
  /// In uz, this message translates to:
  /// **'№{number}'**
  String ordersNumber(String number);

  /// No description provided for @ordersOnlyNewCancellable.
  ///
  /// In uz, this message translates to:
  /// **'Faqat yangi buyurtmani'**
  String get ordersOnlyNewCancellable;

  /// No description provided for @ordersPayment.
  ///
  /// In uz, this message translates to:
  /// **'To‘lov'**
  String get ordersPayment;

  /// No description provided for @ordersPickup.
  ///
  /// In uz, this message translates to:
  /// **'Olib ketish'**
  String get ordersPickup;

  /// No description provided for @ordersPieces.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{{count} dona} other{{count} dona}}'**
  String ordersPieces(int count);

  /// No description provided for @ordersReviewSent.
  ///
  /// In uz, this message translates to:
  /// **'Fikringiz yuborildi'**
  String get ordersReviewSent;

  /// No description provided for @ordersShipping.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazish'**
  String get ordersShipping;

  /// No description provided for @ordersShippingTbd.
  ///
  /// In uz, this message translates to:
  /// **'Kelishiladi'**
  String get ordersShippingTbd;

  /// No description provided for @ordersShowMore.
  ///
  /// In uz, this message translates to:
  /// **'Yana ko‘rsatish'**
  String get ordersShowMore;

  /// No description provided for @ordersSignInPrompt.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalarni ko‘rish uchun kiring'**
  String get ordersSignInPrompt;

  /// No description provided for @ordersStatAwaitingPayment.
  ///
  /// In uz, this message translates to:
  /// **'To‘lov kutilmoqda'**
  String get ordersStatAwaitingPayment;

  /// No description provided for @ordersStatInProduction.
  ///
  /// In uz, this message translates to:
  /// **'Ishlab chiqarishda'**
  String get ordersStatInProduction;

  /// No description provided for @ordersStatSpent.
  ///
  /// In uz, this message translates to:
  /// **'Umumiy sarf'**
  String get ordersStatSpent;

  /// No description provided for @ordersStatTotal.
  ///
  /// In uz, this message translates to:
  /// **'Jami buyurtma'**
  String get ordersStatTotal;

  /// No description provided for @ordersTelegram.
  ///
  /// In uz, this message translates to:
  /// **'Telegram orqali yozish'**
  String get ordersTelegram;

  /// No description provided for @ordersTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalarim'**
  String get ordersTitle;

  /// No description provided for @ordersTotal.
  ///
  /// In uz, this message translates to:
  /// **'Jami'**
  String get ordersTotal;

  /// No description provided for @paymentUnpaid.
  ///
  /// In uz, this message translates to:
  /// **'To‘lanmagan'**
  String get paymentUnpaid;

  /// The cheapest option of a product; price already includes the currency.
  ///
  /// In uz, this message translates to:
  /// **'{price} dan'**
  String priceFrom(String price);

  /// No description provided for @printMethodEngrave.
  ///
  /// In uz, this message translates to:
  /// **'Lazer o‘yma'**
  String get printMethodEngrave;

  /// No description provided for @printMethodUv.
  ///
  /// In uz, this message translates to:
  /// **'Rangli bosma'**
  String get printMethodUv;

  /// No description provided for @product3dLoading.
  ///
  /// In uz, this message translates to:
  /// **'3D model yuklanmoqda…'**
  String get product3dLoading;

  /// No description provided for @product3dOpenFailed.
  ///
  /// In uz, this message translates to:
  /// **'3D ko‘rinishni ochib bo‘lmadi'**
  String get product3dOpenFailed;

  /// No description provided for @product3dResetView.
  ///
  /// In uz, this message translates to:
  /// **'Ko‘rinishni tiklash'**
  String get product3dResetView;

  /// No description provided for @product3dView.
  ///
  /// In uz, this message translates to:
  /// **'3D ko‘rinish'**
  String get product3dView;

  /// Hint next to the Size heading when a size is required
  ///
  /// In uz, this message translates to:
  /// **'Tanlang'**
  String get productChooseSize;

  /// No description provided for @productChooseSizeSnack.
  ///
  /// In uz, this message translates to:
  /// **'O‘lchamni tanlang'**
  String get productChooseSizeSnack;

  /// No description provided for @productColor.
  ///
  /// In uz, this message translates to:
  /// **'Rang'**
  String get productColor;

  /// No description provided for @productDescription.
  ///
  /// In uz, this message translates to:
  /// **'Tavsif'**
  String get productDescription;

  /// No description provided for @productDesign.
  ///
  /// In uz, this message translates to:
  /// **'Dizayn qilish'**
  String get productDesign;

  /// No description provided for @productPrintMethod.
  ///
  /// In uz, this message translates to:
  /// **'Bosma usuli'**
  String get productPrintMethod;

  /// No description provided for @productShare.
  ///
  /// In uz, this message translates to:
  /// **'Ulashish'**
  String get productShare;

  /// No description provided for @productShowLess.
  ///
  /// In uz, this message translates to:
  /// **'Yig‘ish'**
  String get productShowLess;

  /// No description provided for @productShowMore.
  ///
  /// In uz, this message translates to:
  /// **'Batafsil'**
  String get productShowMore;

  /// No description provided for @productSize.
  ///
  /// In uz, this message translates to:
  /// **'O‘lcham'**
  String get productSize;

  /// No description provided for @productSoldOut.
  ///
  /// In uz, this message translates to:
  /// **'Tugagan'**
  String get productSoldOut;

  /// No description provided for @productSpecMaterial.
  ///
  /// In uz, this message translates to:
  /// **'Material'**
  String get productSpecMaterial;

  /// No description provided for @productSpecs.
  ///
  /// In uz, this message translates to:
  /// **'Xususiyatlari'**
  String get productSpecs;

  /// No description provided for @productVariant.
  ///
  /// In uz, this message translates to:
  /// **'Turi'**
  String get productVariant;

  /// No description provided for @productionPacked.
  ///
  /// In uz, this message translates to:
  /// **'Qadoqlandi'**
  String get productionPacked;

  /// No description provided for @productionPrinted.
  ///
  /// In uz, this message translates to:
  /// **'Bosildi'**
  String get productionPrinted;

  /// No description provided for @productionPrinting.
  ///
  /// In uz, this message translates to:
  /// **'Bosilmoqda'**
  String get productionPrinting;

  /// No description provided for @productionQueued.
  ///
  /// In uz, this message translates to:
  /// **'Navbatda'**
  String get productionQueued;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In uz, this message translates to:
  /// **'Hisobni o‘chirish'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteAccountBody.
  ///
  /// In uz, this message translates to:
  /// **'Hisobingiz, saqlangan dizaynlaringiz va savatingiz o‘chiriladi. Yakunlangan buyurtmalar hisob-kitob uchun shaxsiy ma’lumotlaringizsiz saqlanib qoladi.\n\nBu amalni ortga qaytarib bo‘lmaydi.'**
  String get profileDeleteAccountBody;

  /// No description provided for @profileDeleteAccountDone.
  ///
  /// In uz, this message translates to:
  /// **'Hisobingiz o‘chirildi'**
  String get profileDeleteAccountDone;

  /// No description provided for @profileDeleteAccountFailed.
  ///
  /// In uz, this message translates to:
  /// **'Hisobni o‘chirib bo‘lmadi. Qayta urinib ko‘ring'**
  String get profileDeleteAccountFailed;

  /// No description provided for @profileDeleteAccountSubmit.
  ///
  /// In uz, this message translates to:
  /// **'O‘chirish'**
  String get profileDeleteAccountSubmit;

  /// No description provided for @profileDeleteAccountTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hisobni o‘chirasizmi?'**
  String get profileDeleteAccountTitle;

  /// No description provided for @profileEdit.
  ///
  /// In uz, this message translates to:
  /// **'Tahrirlash'**
  String get profileEdit;

  /// No description provided for @profileEditTitle.
  ///
  /// In uz, this message translates to:
  /// **'Profilni tahrirlash'**
  String get profileEditTitle;

  /// No description provided for @profileLastName.
  ///
  /// In uz, this message translates to:
  /// **'Familiya'**
  String get profileLastName;

  /// No description provided for @profileLinkOpenFailed.
  ///
  /// In uz, this message translates to:
  /// **'Havolani ochib bo‘lmadi'**
  String get profileLinkOpenFailed;

  /// No description provided for @profileMyOrders.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalarim'**
  String get profileMyOrders;

  /// No description provided for @profilePhone.
  ///
  /// In uz, this message translates to:
  /// **'Telefon'**
  String get profilePhone;

  /// No description provided for @profilePhoneIncomplete.
  ///
  /// In uz, this message translates to:
  /// **'Telefon raqamini to‘liq kiriting'**
  String get profilePhoneIncomplete;

  /// No description provided for @profilePrivacyPolicy.
  ///
  /// In uz, this message translates to:
  /// **'Maxfiylik siyosati'**
  String get profilePrivacyPolicy;

  /// No description provided for @profileSaved.
  ///
  /// In uz, this message translates to:
  /// **'Saqlandi'**
  String get profileSaved;

  /// No description provided for @profileSignOut.
  ///
  /// In uz, this message translates to:
  /// **'Chiqish'**
  String get profileSignOut;

  /// No description provided for @profileSignOutConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Hisobdan chiqasizmi?'**
  String get profileSignOutConfirm;

  /// No description provided for @profileTelegramConnected.
  ///
  /// In uz, this message translates to:
  /// **'Telegram ulandi'**
  String get profileTelegramConnected;

  /// No description provided for @profileTelegramLink.
  ///
  /// In uz, this message translates to:
  /// **'Ulash'**
  String get profileTelegramLink;

  /// No description provided for @profileTelegramLinked.
  ///
  /// In uz, this message translates to:
  /// **'Ulangan'**
  String get profileTelegramLinked;

  /// No description provided for @profileTelegramNotConfigured.
  ///
  /// In uz, this message translates to:
  /// **'Telegram bot sozlanmagan'**
  String get profileTelegramNotConfigured;

  /// No description provided for @profileTelegramNotConfirmed.
  ///
  /// In uz, this message translates to:
  /// **'Ulanish tasdiqlanmadi'**
  String get profileTelegramNotConfirmed;

  /// No description provided for @profileTelegramOpenFailed.
  ///
  /// In uz, this message translates to:
  /// **'Telegram ochilmadi'**
  String get profileTelegramOpenFailed;

  /// No description provided for @profileTelegramRelink.
  ///
  /// In uz, this message translates to:
  /// **'Qayta ulash'**
  String get profileTelegramRelink;

  /// No description provided for @profileTelegramTitle.
  ///
  /// In uz, this message translates to:
  /// **'Telegram xabarnomalari'**
  String get profileTelegramTitle;

  /// No description provided for @profileTelegramUnlinked.
  ///
  /// In uz, this message translates to:
  /// **'Ulanmagan'**
  String get profileTelegramUnlinked;

  /// No description provided for @profileTelegramWaiting.
  ///
  /// In uz, this message translates to:
  /// **'Kutilmoqda'**
  String get profileTelegramWaiting;

  /// No description provided for @reviewsCity.
  ///
  /// In uz, this message translates to:
  /// **'Shahar'**
  String get reviewsCity;

  /// No description provided for @reviewsEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hali fikr qoldirmagansiz'**
  String get reviewsEmpty;

  /// No description provided for @reviewsFormTitle.
  ///
  /// In uz, this message translates to:
  /// **'Fikr qoldirish'**
  String get reviewsFormTitle;

  /// No description provided for @reviewsPhotoTooLarge.
  ///
  /// In uz, this message translates to:
  /// **'Surat {size} MB dan oshmasin'**
  String reviewsPhotoTooLarge(int size);

  /// No description provided for @reviewsPhotosOpenFailed.
  ///
  /// In uz, this message translates to:
  /// **'Suratlarni ochib bo‘lmadi'**
  String get reviewsPhotosOpenFailed;

  /// Screen-reader label of the star rating.
  ///
  /// In uz, this message translates to:
  /// **'{value} / 5'**
  String reviewsRatingLabel(int value);

  /// No description provided for @reviewsSend.
  ///
  /// In uz, this message translates to:
  /// **'Yuborish'**
  String get reviewsSend;

  /// No description provided for @reviewsSignIn.
  ///
  /// In uz, this message translates to:
  /// **'Fikrlaringizni ko‘rish uchun kiring'**
  String get reviewsSignIn;

  /// No description provided for @reviewsStatusApproved.
  ///
  /// In uz, this message translates to:
  /// **'Saytda ko‘rinadi'**
  String get reviewsStatusApproved;

  /// No description provided for @reviewsStatusPending.
  ///
  /// In uz, this message translates to:
  /// **'Tekshirilmoqda'**
  String get reviewsStatusPending;

  /// No description provided for @reviewsStatusRejected.
  ///
  /// In uz, this message translates to:
  /// **'Rad etilgan'**
  String get reviewsStatusRejected;

  /// No description provided for @reviewsTextLabel.
  ///
  /// In uz, this message translates to:
  /// **'Fikringiz'**
  String get reviewsTextLabel;

  /// No description provided for @reviewsTextTooShort.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, one{Kamida {count} ta belgi} other{Kamida {count} ta belgi}}'**
  String reviewsTextTooShort(int count);

  /// No description provided for @reviewsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Fikrlarim'**
  String get reviewsTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
