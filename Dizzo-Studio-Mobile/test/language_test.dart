import 'dart:convert';

import 'package:dizzo/core/l10n/app_language.dart';
import 'package:dizzo/core/l10n/locale_controller.dart';
import 'package:dizzo/core/network/api_client.dart';
import 'package:dizzo/core/storage/token_storage.dart';
import 'package:dizzo/core/theme/app_theme.dart';
import 'package:dizzo/features/auth/presentation/auth_controller.dart';
import 'package:dizzo/features/settings/presentation/language_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/account_harness.dart';
import 'helpers/fake_api.dart';

FakeAdapter _backend({String? language}) => routedAdapter({
      'GET /auth/me': (_) => {...testUser, 'language': ?language},
      'PATCH /users/profile/me/': (o) => {...testUser, ...Map<String, Object?>.from(o.data as Map)},
    });

List<Object?> _languagePatches(FakeAdapter backend) => [
      for (final r in backend.requests)
        if (r.method == 'PATCH' && r.path.contains('/users/profile/me/')) (r.data as Map)['language'],
    ];

ProviderContainer _container(MemoryTokenStorage storage, FakeAdapter backend) {
  final container = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      dioProvider.overrideWithValue(fakeDio(backend)),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  tearDown(() => AppLanguage.current = AppLanguage.uz);

  test('signed in, never picked here: the profile language is adopted', () async {
    final storage = sessionStorage();
    final backend = _backend(language: 'en');
    final container = _container(storage, backend);
    container.read(authControllerProvider);
    await _flush();
    expect(container.read(appLanguageProvider), AppLanguage.en);
    expect(AppLanguage.current, AppLanguage.en);
    expect(storage.flags['language'], 'en');
    expect(_languagePatches(backend), isEmpty);
  });

  test('a language picked on the device wins and is sent to the profile', () async {
    final storage = sessionStorage()
      ..flags['language'] = 'ru'
      ..flags['language_source'] = 'user';
    final backend = _backend(language: 'en');
    final container = _container(storage, backend);
    container.read(authControllerProvider);
    await _flush();
    expect(container.read(appLanguageProvider), AppLanguage.ru);
    expect(_languagePatches(backend), ['ru']);
  });

  test('picking a language saves it and PATCHes the profile', () async {
    final storage = sessionStorage();
    final backend = _backend(language: 'uz');
    final container = _container(storage, backend);
    container.read(authControllerProvider);
    await _flush();
    expect(container.read(appLanguageProvider), AppLanguage.uz);

    await container.read(appLanguageProvider.notifier).select(AppLanguage.ru);
    await _flush();
    expect(AppLanguage.current, AppLanguage.ru);
    expect(storage.flags['language'], 'ru');
    expect(storage.flags['language_source'], 'user');
    expect(_languagePatches(backend), ['ru']);
    expect(container.read(currentUserProvider)?.language, 'ru');
    expect(jsonDecode(storage.user!)['language'], 'ru');
  });

  test('a guest picks a language: saved, nothing sent', () async {
    final storage = MemoryTokenStorage();
    final backend = _backend();
    final container = _container(storage, backend);
    container.read(authControllerProvider);
    await _flush();
    await container.read(appLanguageProvider.notifier).select(AppLanguage.en);
    await _flush();
    expect(storage.flags['language'], 'en');
    expect(backend.requests.where((r) => r.method == 'PATCH'), isEmpty);
  });

  testWidgets('the picker switches the app language at once', (tester) async {
    final storage = sessionStorage();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        dioProvider.overrideWithValue(fakeDio(_backend(language: 'uz'))),
      ],
      retry: (_, _) => null,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          locale: ref.watch(appLanguageProvider).locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: const Scaffold(body: LanguageTile()),
        ),
      ),
    ));
    await settle(tester);
    expect(find.text('Til'), findsOneWidget);
    expect(find.text('O‘zbekcha'), findsOneWidget);

    await tester.tap(find.byType(LanguageTile));
    await settle(tester);
    expect(find.text('Tilni tanlang'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('language-ru')));
    await settle(tester, 20);

    expect(find.text('Язык'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('Выберите язык'), findsNothing);
    expect(storage.flags['language'], 'ru');

    await tester.tap(find.byType(LanguageTile));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('language-en')));
    await settle(tester, 20);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });
}
