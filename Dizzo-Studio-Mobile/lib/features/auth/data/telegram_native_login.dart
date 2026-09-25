import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';

/// Why the native Telegram login could not give a token.
class TelegramNativeError implements Exception {
  const TelegramNativeError(this.code, [this.message]);

  /// `not_configured` (no client id / redirect uri), `unavailable` (no
  /// plugin or activity) or `failed` (Telegram or the network refused).
  final String code;
  final String? message;

  @override
  String toString() => 'TelegramNativeError($code, $message)';
}

/// "Log in with Telegram" through the official SDKs (Android
/// `org.telegram:login-sdk`, iOS `TelegramLogin` package), wrapped by the
/// in-app plugins `TelegramLoginPlugin` (android/app/src/main/kotlin,
/// ios/Runner). The SDK opens the Telegram app, or a browser sheet when it
/// isn't installed, and returns an OIDC **id token** that
/// `POST /auth/oauth/telegram-oidc/` verifies.
///
/// Configuration: [Env.telegramClientId] and [Env.telegramRedirectUri].
class TelegramNativeLogin {
  TelegramNativeLogin({
    MethodChannel? channel,
    this.clientId = Env.telegramClientId,
    String? redirectUri,
    bool? platformSupported,
  })  : redirectUri = redirectUri ?? Env.telegramRedirectUriForPlatform,
        _channel = channel ?? const MethodChannel(channelName),
        _platformSupported = platformSupported ?? (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  static const channelName = 'uz.dizzo/telegram_login';

  /// `openid` is added by the Android SDK itself, but not by the iOS one.
  static const scopes = ['openid', 'profile', 'phone'];

  final MethodChannel _channel;
  final String clientId;
  final String redirectUri;
  final bool _platformSupported;
  bool _initialized = false;

  /// False when the build has no Telegram config (or runs off Android/iOS).
  bool get isAvailable => _platformSupported && clientId.isNotEmpty && redirectUri.isNotEmpty;

  /// Opens Telegram and waits for the user. Returns the id token, or null
  /// when the user cancelled (or [cancel] was called). Throws
  /// [TelegramNativeError].
  Future<String?> signIn() async {
    if (!isAvailable) throw const TelegramNativeError('not_configured');
    try {
      if (!_initialized) {
        await _channel.invokeMethod<void>('init', {
          'clientId': clientId,
          'redirectUri': redirectUri,
          'scopes': scopes,
        });
        _initialized = true;
      }
      final token = await _channel.invokeMethod<String>('login');
      return (token == null || token.isEmpty) ? null : token;
    } on MissingPluginException {
      throw const TelegramNativeError('unavailable');
    } on PlatformException catch (e) {
      debugPrint('Telegram native login: ${e.code} ${e.message}');
      throw TelegramNativeError(e.code, e.message);
    }
  }

  /// Stops waiting: a pending [signIn] completes with null.
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (_) {}
  }
}

final telegramNativeLoginProvider = Provider<TelegramNativeLogin>((ref) => TelegramNativeLogin());
