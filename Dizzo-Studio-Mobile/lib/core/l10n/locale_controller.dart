import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_storage.dart';
import 'app_language.dart';

/// The app language. Starts from the device language (ru/en, else uz), then
/// the saved choice once storage has answered.
///
/// ```dart
/// final lang = ref.watch(appLanguageProvider);
/// await ref.read(appLanguageProvider.notifier).select(AppLanguage.ru);
/// ```
class AppLanguageController extends Notifier<AppLanguage> {
  static const _key = 'language';

  /// 'user' (picked in the app) or 'server' (taken from the profile).
  static const _sourceKey = 'language_source';

  bool _userChosen = false;
  final _ready = Completer<void>();

  /// Completes once the saved language was read.
  Future<void> get ready => _ready.future;

  /// Whether the user picked a language on this device.
  bool get userChosen => _userChosen;

  @override
  AppLanguage build() {
    unawaited(_load());
    return _apply(AppLanguage.fromDevice());
  }

  AppLanguage _apply(AppLanguage lang) {
    AppLanguage.current = lang;
    return lang;
  }

  Future<void> _load() async {
    final storage = ref.read(tokenStorageProvider);
    try {
      final saved = AppLanguage.tryParse(await storage.readFlag(_key));
      _userChosen = saved != null && await storage.readFlag(_sourceKey) != 'server';
      if (saved != null && saved != state) state = _apply(saved);
    } catch (_) {
      // Keep the device language.
    } finally {
      if (!_ready.isCompleted) _ready.complete();
      ref.read(appLanguageLoadedProvider.notifier).set();
    }
  }

  /// The user's choice: applied at once and saved.
  Future<void> select(AppLanguage lang) async {
    _userChosen = true;
    if (lang != state) state = _apply(lang);
    await _save(lang, 'user');
  }

  /// The profile's language after a sign-in, unless the user already chose
  /// one here. Returns true when it was adopted.
  Future<bool> adoptFromServer(String? code) async {
    final lang = AppLanguage.tryParse(code);
    if (lang == null || _userChosen) return false;
    if (lang != state) state = _apply(lang);
    await _save(lang, 'server');
    return true;
  }

  Future<void> _save(AppLanguage lang, String source) async {
    final storage = ref.read(tokenStorageProvider);
    try {
      await storage.writeFlag(_key, lang.code);
      await storage.writeFlag(_sourceKey, source);
    } catch (_) {}
  }
}

final appLanguageProvider =
    NotifierProvider<AppLanguageController, AppLanguage>(AppLanguageController.new);

class _Loaded extends Notifier<bool> {
  @override
  bool build() => false;

  void set() => state = true;
}

/// True once the saved language was read (the splash waits for it).
final appLanguageLoadedProvider = NotifierProvider<_Loaded, bool>(_Loaded.new);

/// The language code content is fetched in. Providers that load translated
/// content (product names, orders, gallery) watch it, so a language switch
/// refetches them.
final contentLanguageProvider = Provider<String>((ref) => ref.watch(appLanguageProvider).code);
