import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/env.dart';
import '../../../core/l10n/app_language.dart';
import '../../../core/network/api_exception.dart';

bool get _isIOS => !kIsWeb && Platform.isIOS;

/// Native Google sign-in (Credential Manager on Android, the Google SDK on
/// iOS). Returns the **id token** that the backend verifies.
///
/// Configuration: see [Env.googleServerClientId] / [Env.googleIosClientId].
class GoogleAuth {
  bool _initialized = false;

  /// False when the build has no Google client ids: the button is hidden.
  bool get isAvailable => Env.googleConfiguredFor(isIOS: _isIOS);

  Future<void> _init() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: _isIOS ? Env.googleIosClientId : null,
      serverClientId: Env.googleServerClientId,
    );
    _initialized = true;
  }

  /// The id token, or null when the user closed the account picker.
  Future<String?> signIn() async {
    if (!isAvailable) throw googleNotConfigured;
    try {
      await _init();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw ApiException(ApiErrorKind.unknown, l10nNow.authGoogleUnsupported);
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw ApiException(ApiErrorKind.unknown, l10nNow.authGoogleNoResponse);
      }
      return idToken;
    } on GoogleSignInException catch (e) {
      debugPrint('Google sign-in failed: ${e.code} ${e.description}');
      final error = googleSignInError(e);
      if (error == null) return null;
      throw error;
    } on PlatformException catch (e) {
      debugPrint('Google sign-in failed: ${e.code} ${e.message}');
      throw googleSignInError(
            GoogleSignInException(code: GoogleSignInExceptionCode.unknownError, description: '${e.code} ${e.message}'),
          ) ??
          ApiException(ApiErrorKind.unknown, l10nNow.authGoogleFailed);
    }
  }

  Future<void> signOut() async {
    if (!_initialized) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}

ApiException get googleNotConfigured => ApiException(ApiErrorKind.unknown, l10nNow.authGoogleNotConfigured);

/// What the user sees for a Google failure; null means they cancelled.
@visibleForTesting
ApiException? googleSignInError(GoogleSignInException e) {
  final text = '${e.description ?? ''} ${e.details ?? ''}'.toLowerCase();
  switch (e.code) {
    case GoogleSignInExceptionCode.canceled:
    case GoogleSignInExceptionCode.interrupted:
      return null;
    case GoogleSignInExceptionCode.clientConfigurationError:
    case GoogleSignInExceptionCode.providerConfigurationError:
      if (text.contains('not supported')) {
        return ApiException(ApiErrorKind.unknown, l10nNow.authGoogleUnsupported);
      }
      return googleNotConfigured;
    case GoogleSignInExceptionCode.uiUnavailable:
      return ApiException(ApiErrorKind.unknown, l10nNow.authGoogleWindowFailed);
    case GoogleSignInExceptionCode.userMismatch:
    case GoogleSignInExceptionCode.unknownError:
      break;
  }
  if (text.contains('network') || text.contains('internet') || text.contains('offline') || text.contains('timed out')) {
    return ApiException(ApiErrorKind.network, l10nNow.errorNoInternet);
  }
  // 28444 / 10 (DEVELOPER_ERROR): the app's SHA-1 isn't registered in the
  // Google Cloud Android OAuth client.
  if (text.contains('28444') || text.contains('developer console') || text.contains('developer_error')) {
    return googleNotConfigured;
  }
  if (text.contains('no credential')) {
    return ApiException(ApiErrorKind.unknown, l10nNow.authGoogleNoAccount);
  }
  return ApiException(ApiErrorKind.unknown, l10nNow.authGoogleFailed);
}

final googleAuthProvider = Provider<GoogleAuth>((ref) => GoogleAuth());
