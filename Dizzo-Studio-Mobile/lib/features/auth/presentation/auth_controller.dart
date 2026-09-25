import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_api.dart';
import '../data/google_auth.dart';
import '../domain/app_user.dart';
import '../domain/auth_state.dart';

/// The session. Everything that depends on "who is signed in" watches this.
///
/// ```dart
/// final auth = ref.watch(authControllerProvider);
/// if (auth case Authenticated(:final user)) ...
/// await ref.read(authControllerProvider.notifier).logout();
/// ```
class AuthController extends Notifier<AuthState> {
  TokenStorage get _storage => ref.read(tokenStorageProvider);
  AuthApi get _api => ref.read(authApiProvider);

  @override
  AuthState build() {
    final sub = ref.read(sessionEventsProvider).stream.listen((event) {
      if (event == SessionEvent.expired) state = const Guest();
    });
    ref.onDispose(sub.cancel);
    // A language picked in the app is saved to the profile.
    ref.listen(appLanguageProvider, (prev, next) {
      if (prev != next) unawaited(_pushLanguage(next));
    });
    unawaited(_restore());
    return const AuthUnknown();
  }

  Future<void> _restore() async {
    final tokens = await _storage.read();
    if (tokens == null) {
      state = const Guest();
      return;
    }
    final cached = await _readCachedUser();
    state = Authenticated(cached ?? AppUser.pending);
    await refreshUser();
  }

  /// Reloads the profile (`GET /auth/me`). Offline: keeps what we have.
  Future<void> refreshUser() async {
    try {
      final user = await _api.me();
      if (state is! Authenticated) return; // signed out meanwhile
      await _setUser(user);
      await _reconcileLanguage(user);
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.unauthorized) {
        await _storage.clear();
        state = const Guest();
      }
    }
  }

  /// Replaces the user after a profile edit.
  Future<void> updateUser(AppUser user) => _setUser(user);

  Future<void> signInWithEmail(String email, String password) async {
    await completeSignIn(await _api.login(email: email.trim(), password: password));
  }

  Future<void> register({
    required String firstName,
    String lastName = '',
    String phoneNumber = '',
    required String email,
    required String password,
  }) async {
    await completeSignIn(await _api.register(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      phoneNumber: phoneNumber.trim(),
      email: email.trim(),
      password: password,
    ));
  }

  /// Returns false when the user closed Google's account picker.
  Future<bool> signInWithGoogle() async {
    final idToken = await ref.read(googleAuthProvider).signIn();
    if (idToken == null) return false;
    await completeSignIn(await _api.google(idToken));
    return true;
  }

  /// Stores a finished sign-in (email, Google, Telegram).
  Future<void> completeSignIn(AuthResult result) async {
    await _storage.write(result.tokens);
    await _setUser(result.user);
    await ref.read(welcomeSeenProvider.notifier).markSeen();
    await _reconcileLanguage(result.user);
  }

  Future<void> logout() async {
    final tokens = await _storage.read();
    await _api.logout(refreshToken: tokens?.refresh);
    await _signOutLocally();
  }

  /// Deletes the account on the server, then signs out on this device.
  /// No logout call: the server has already revoked the tokens. Throws
  /// [ApiException] (with the server's localized message) on failure.
  Future<void> deleteAccount() async {
    await _api.deleteAccount();
    await _signOutLocally();
  }

  /// Drops the tokens, the cached user and the Google session. Per-user
  /// data (cart, designs, orders) is keyed by the user id and resets when
  /// the state turns [Guest].
  Future<void> _signOutLocally() async {
    await ref.read(googleAuthProvider).signOut();
    await _storage.clear();
    state = const Guest();
  }

  /// After a sign-in: adopt the profile's language unless one was picked
  /// on this device; otherwise tell the server the device's choice.
  Future<void> _reconcileLanguage(AppUser user) async {
    final language = ref.read(appLanguageProvider.notifier);
    await language.ready;
    if (await language.adoptFromServer(user.language)) return;
    final current = ref.read(appLanguageProvider);
    if (user.language != null && user.language != current.code) await _pushLanguage(current);
  }

  Future<void> _pushLanguage(AppLanguage lang) async {
    final current = state;
    if (current is! Authenticated || current.user.language == lang.code) return;
    try {
      final user = await _api.setLanguage(lang.code);
      if (state is Authenticated) await _setUser(user);
    } catch (_) {
      // Offline or refused: the local choice still applies; the next
      // sign-in tries again.
    }
  }

  Future<void> _setUser(AppUser user) async {
    state = Authenticated(user);
    try {
      await _storage.writeUser(jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<AppUser?> _readCachedUser() async {
    try {
      final raw = await _storage.readUser();
      if (raw == null) return null;
      return AppUser.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// The signed-in user or null.
final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authControllerProvider).user);

/// Whether the welcome screen was already shown (null while loading).
class WelcomeSeenController extends Notifier<bool?> {
  static const _key = 'welcome_seen';

  @override
  bool? build() {
    unawaited(_load());
    return null;
  }

  Future<void> _load() async {
    final v = await ref.read(tokenStorageProvider).readFlag(_key);
    state = v == '1';
  }

  Future<void> markSeen() async {
    state = true;
    await ref.read(tokenStorageProvider).writeFlag(_key, '1');
  }
}

final welcomeSeenProvider = NotifierProvider<WelcomeSeenController, bool?>(WelcomeSeenController.new);
