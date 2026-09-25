import 'package:dizzo/core/network/api_client.dart';
import 'package:dizzo/core/storage/token_storage.dart';
import 'package:dizzo/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_api.dart';
import 'l10n.dart';

const testUser = {
  'id': 5,
  'email': 'ali@dizzo.uz',
  'first_name': 'Ali',
  'last_name': 'Valiyev',
  'full_name': 'Ali Valiyev',
  'phone_number': '+998901234567',
};

/// Storage holding a session (signed in) or nothing (guest).
MemoryTokenStorage sessionStorage({bool signedIn = true}) {
  final s = MemoryTokenStorage(signedIn ? const TokenPair(access: 'a', refresh: 'r') : null);
  s.flags['welcome_seen'] = '1';
  return s;
}

/// Pumps [screen] as the home route of a small router (other routes show
/// their path), with a fake backend and a phone-sized view.
Future<GoRouter> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required FakeAdapter backend,
  MemoryTokenStorage? storage,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      for (final path in ['/checkout', '/products', '/orders', '/orders/:id', '/editor/:slug', '/reviews', '/designs', '/cart', '/home'])
        GoRoute(
          path: path,
          builder: (_, state) => Scaffold(body: Text('route:${state.uri}')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(storage ?? sessionStorage()),
      dioProvider.overrideWithValue(fakeDio(backend)),
    ],
    retry: (_, _) => null,
    child: MaterialApp.router(
      locale: testLocale,
      localizationsDelegates: l10nDelegates,
      supportedLocales: l10nLocales,
      theme: AppTheme.light, routerConfig: router),
  ));
  await settle(tester);
  return router;
}

/// Lets requests finish without waiting on endless animations.
Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
