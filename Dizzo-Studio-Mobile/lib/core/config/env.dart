import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Build-time configuration, passed with `--dart-define` (or
/// `--dart-define-from-file=config/dev.json`). Nothing secret lives here:
/// OAuth client ids are public by design.
abstract final class Env {
  /// The API root, with the `/api` suffix and no trailing slash.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.dizzo.uz/api',
  );

  /// The public web site (share links, "open on the site").
  static const siteUrl = String.fromEnvironment(
    'SITE_URL',
    defaultValue: 'https://dizzo.uz',
  );

  /// Google OAuth **Web** client id: the same one the backend verifies
  /// (`GOOGLE_CLIENT_ID`). With it as `serverClientId`, the id token Google
  /// returns on Android/iOS is issued for this audience. The backend also
  /// accepts the mobile client ids listed in its `GOOGLE_MOBILE_CLIENT_IDS`.
  ///
  /// Android needs no id of its own in code, only the Android OAuth client
  /// for `uz.dizzo.studio` in Google Cloud Console with the SHA-1 of every
  /// signing key (debug, upload, Play App Signing).
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '859762564989-9clcipm8jl4j2siv76og5brii5soimat.apps.googleusercontent.com',
  );

  /// Google OAuth **iOS** client id
  /// (`1234-abcd.apps.googleusercontent.com`).
  ///
  /// The iOS client of bundle id `uz.dizzo.studio`. The iOS build also needs
  /// its reversed form as a URL scheme: `GOOGLE_REVERSED_CLIENT_ID` in
  /// `ios/Flutter/*.xcconfig` (regenerated from this define by
  /// `ios/scripts/dart_defines_to_xcconfig.sh`) — keep them in sync.
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '859762564989-g7knvm4031i5deop6dn8u19hhlksme7k.apps.googleusercontent.com',
  );

  /// Google sign-in needs the web client id on both platforms, and the iOS
  /// client id on iOS. Without them the Google button is hidden.
  static bool googleConfiguredFor({required bool isIOS}) =>
      googleServerClientId.isNotEmpty && (!isIOS || googleIosClientId.isNotEmpty);

  /// Telegram "Log in with Telegram" **Client ID** from @BotFather
  /// (Bot Settings > Login Widget). The backend checks the id token's `aud`
  /// against its `TELEGRAM_OIDC_CLIENT_ID`, so both must be the same value.
  static const telegramClientId = String.fromEnvironment(
    'TELEGRAM_CLIENT_ID',
    defaultValue: '8249953132',
  );

  /// The Android redirect URI of the app registered in @BotFather: the
  /// generated `https://app{id}-login.tg.dev` host plus `/tglogin` (Telegram's
  /// Android README). The Android build makes its App Link intent filter
  /// from it (android/app/build.gradle.kts).
  static const telegramRedirectUri = String.fromEnvironment(
    'TELEGRAM_REDIRECT_URI',
    defaultValue: 'https://app2398820989-login.tg.dev/tglogin',
  );

  /// The iOS redirect URI. Telegram's iOS README uses the bare generated
  /// host (`https://app{id}-login.tg.dev`); by default it is the Android
  /// URI's origin. If @BotFather gives the iOS app its own host, pass it
  /// here; the iOS build makes its Associated Domain from it.
  static const telegramIosRedirectUri = String.fromEnvironment('TELEGRAM_IOS_REDIRECT_URI');

  static String get telegramRedirectUriForPlatform {
    if (kIsWeb || !Platform.isIOS) return telegramRedirectUri;
    if (telegramIosRedirectUri.isNotEmpty) return telegramIosRedirectUri;
    final uri = Uri.tryParse(telegramRedirectUri);
    return uri == null || uri.host.isEmpty ? '' : uri.origin;
  }
}
