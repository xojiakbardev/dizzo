import 'dart:ui' show Locale;

import 'package:flutter/widgets.dart' show BuildContext, WidgetsBinding;
import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';

export '../../l10n/gen/app_localizations.dart';

/// The app's languages. Uzbek (Latin) is the source and the fallback.
enum AppLanguage {
  uz('O‘zbekcha'),
  ru('Русский'),
  en('English');

  const AppLanguage(this.nativeName);

  /// The language's own name (the picker shows it untranslated).
  final String nativeName;

  String get code => name;
  Locale get locale => Locale(code);

  static AppLanguage? tryParse(String? code) {
    if (code == null) return null;
    final c = code.trim().toLowerCase().split(RegExp('[-_]')).first;
    for (final l in values) {
      if (l.code == c) return l;
    }
    return null;
  }

  /// The device language if it is Russian or English, otherwise Uzbek.
  static AppLanguage fromDevice([List<Locale>? locales]) {
    final list = locales ?? WidgetsBinding.instance.platformDispatcher.locales;
    final first = list.isEmpty ? null : AppLanguage.tryParse(list.first.languageCode);
    return first ?? AppLanguage.uz;
  }

  /// The language in use, for code without a [BuildContext] (API errors,
  /// money, the `Accept-Language` header). The locale controller keeps it
  /// current.
  static AppLanguage current = AppLanguage.uz;
}

/// Strings of the current language, for code without a [BuildContext].
AppLocalizations get l10nNow => lookupAppLocalizations(AppLanguage.current.locale);

extension L10nContext on BuildContext {
  /// `context.l10n.cartTitle`
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Locale-aware dates. The Uzbek forms are the app's original ones
/// ("1-sentabr 2026 yil").
abstract final class AppDates {
  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _code(String? locale) => AppLanguage.tryParse(locale)?.code ?? AppLanguage.current.code;

  static String _fmt(String pattern, DateTime d, String code) {
    try {
      return DateFormat(pattern, code).format(d);
    } catch (_) {
      // Date symbols not loaded (a bare unit test): the default locale.
      return DateFormat(pattern).format(d);
    }
  }

  /// uz "1-sentabr 2026 yil", ru "1 сентября 2026 г.", en "September 1, 2026".
  static String date(DateTime date, [String? locale]) {
    final d = date.toLocal();
    return switch (_code(locale)) {
      'ru' => _fmt("d MMMM y 'г.'", d, 'ru'),
      'en' => _fmt('MMMM d, y', d, 'en'),
      _ => _fmt("d-MMMM y 'yil'", d, 'uz'),
    };
  }

  /// [date] plus "22:00".
  static String dateTime(DateTime date, [String? locale]) {
    final d = date.toLocal();
    final sep = _code(locale) == 'en' ? ', ' : ' ';
    return '${AppDates.date(d, locale)}$sep${_two(d.hour)}:${_two(d.minute)}';
  }

  /// uz "1-sentabr 2026, 22:00", ru "1 сентября 2026, 22:00",
  /// en "September 1, 2026, 22:00".
  static String dateTimeShort(DateTime date, [String? locale]) {
    final d = date.toLocal();
    final day = switch (_code(locale)) {
      'ru' => _fmt('d MMMM y', d, 'ru'),
      'en' => _fmt('MMMM d, y', d, 'en'),
      _ => _fmt('d-MMMM y', d, 'uz'),
    };
    return '$day, ${_two(d.hour)}:${_two(d.minute)}';
  }
}
