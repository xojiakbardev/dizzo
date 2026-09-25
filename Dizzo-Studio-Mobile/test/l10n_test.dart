import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dizzo/core/l10n/app_language.dart';
import 'package:dizzo/core/network/api_client.dart';
import 'package:dizzo/core/utils/money.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

/// Placeholder names used in a message (`{name}`, `{count, plural, ...}`).
/// A `{` right after a word is a plural/select case body (`robot{Robot}`).
Set<String> _placeholders(String message) =>
    RegExp(r'(?<![\w=])\{\s*(\w+)\s*[,}]').allMatches(message).map((m) => m.group(1)!).toSet();

Set<String> _keys(Map<String, dynamic> arb) => arb.keys.where((k) => !k.startsWith('@')).toSet();

void main() {
  final uz = _arb('uz');
  final others = {'ru': _arb('ru'), 'en': _arb('en')};

  test('ru and en have exactly the Uzbek keys', () {
    for (final MapEntry(key: lang, value: arb) in others.entries) {
      expect(_keys(arb).difference(_keys(uz)), isEmpty, reason: '$lang has extra keys');
      expect(_keys(uz).difference(_keys(arb)), isEmpty, reason: '$lang is missing keys');
    }
  });

  test('every translation uses the same placeholders', () {
    for (final key in _keys(uz)) {
      final expected = _placeholders(uz[key] as String);
      final declared = ((uz['@$key'] as Map?)?['placeholders'] as Map?)?.keys.toSet() ?? <String>{};
      expect(expected, declared, reason: 'uz "$key": placeholders used vs declared');
      for (final MapEntry(key: lang, value: arb) in others.entries) {
        expect(_placeholders(arb[key] as String), expected, reason: '$lang "$key"');
      }
    }
  });

  test('no translation is empty', () {
    for (final MapEntry(key: lang, value: arb) in {'uz': uz, ...others}.entries) {
      for (final key in _keys(arb)) {
        expect((arb[key] as String).trim(), isNotEmpty, reason: '$lang "$key"');
      }
    }
  });

  group('language', () {
    tearDown(() => AppLanguage.current = AppLanguage.uz);

    test('device default: ru and en are kept, anything else is Uzbek', () {
      expect(AppLanguage.fromDevice(const [Locale('ru', 'RU')]), AppLanguage.ru);
      expect(AppLanguage.fromDevice(const [Locale('en', 'US')]), AppLanguage.en);
      expect(AppLanguage.fromDevice(const [Locale('uz')]), AppLanguage.uz);
      expect(AppLanguage.fromDevice(const [Locale('de')]), AppLanguage.uz);
      expect(AppLanguage.fromDevice(const []), AppLanguage.uz);
    });

    test('the currency word follows the language', () {
      expect(formatSum(149000), '149 000 so‘m');
      AppLanguage.current = AppLanguage.ru;
      expect(formatSum(149000), '149 000 сум');
      AppLanguage.current = AppLanguage.en;
      expect(formatSum(149000), '149 000 UZS');
    });

    test('dates in each language', () {
      final d = DateTime(2026, 9, 1, 22);
      expect(AppDates.date(d, 'uz'), '1-sentabr 2026 yil');
      expect(AppDates.date(d, 'ru'), '1 сентября 2026 г.');
      expect(AppDates.date(d, 'en'), 'September 1, 2026');
      expect(AppDates.dateTimeShort(d, 'ru'), '1 сентября 2026, 22:00');
    });

    test('requests carry Accept-Language of the current language', () async {
      final seen = <String?>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api'))
        ..interceptors.add(const LanguageInterceptor())
        ..interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
          seen.add(o.headers['Accept-Language'] as String?);
          h.reject(DioException(requestOptions: o, type: DioExceptionType.cancel));
        }));
      for (final lang in AppLanguage.values) {
        AppLanguage.current = lang;
        await dio.get<Object?>('/x').catchError((Object _) => Response<Object?>(requestOptions: RequestOptions()));
      }
      expect(seen, ['uz', 'ru', 'en']);
    });
  });
}
