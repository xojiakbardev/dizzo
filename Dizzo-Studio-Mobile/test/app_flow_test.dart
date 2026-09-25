import 'package:dizzo/app.dart';
import 'package:dizzo/core/network/api_client.dart';
import 'package:dizzo/core/storage/token_storage.dart';
import 'package:dizzo/features/auth/presentation/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_api.dart';

final _products = [
  {'slug': 'krujka', 'name': 'Krujka', 'cover_url': null, 'from_price': '49000.00', 'is_featured': true, 'category': 'idish'},
  {'slug': 'futbolka', 'name': 'Futbolka', 'cover_url': null, 'from_price': '129000.00', 'is_featured': false, 'category': 'kiyim'},
];

FakeAdapter _backend() => routedAdapter({
      'GET /catalog/products/': (_) => _products,
      'GET /catalog/categories/': (_) => [
            {'slug': 'idish', 'name': 'Idishlar', 'icon_svg': '', 'image_url': null},
          ],
      'GET /gallery/': (_) => <Object>[],
      'POST /auth/login/': (o) => {
            'access_token': 'a1',
            'refresh_token': 'r1',
            'token_type': 'bearer',
            'user': {'id': 5, 'email': 'ali@dizzo.uz', 'first_name': 'Ali', 'full_name': 'Ali Valiyev'},
          },
      'GET /auth/me': (_) => {'id': 5, 'email': 'ali@dizzo.uz', 'first_name': 'Ali', 'full_name': 'Ali Valiyev'},
      'GET /cart/': (_) => {'total_items': 3},
    });

Future<void> pumpApp(WidgetTester tester, {required MemoryTokenStorage storage, required FakeAdapter backend}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      dioProvider.overrideWithValue(fakeDio(backend)),
    ],
    retry: (_, _) => null,
    child: const DizzoApp(),
  ));
  // Let the session restore and the first requests settle (the brand loader
  // animates forever, so pump a fixed time instead of pumpAndSettle).
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('first launch shows the welcome screen with every sign-in method', (tester) async {
    await pumpApp(tester, storage: MemoryTokenStorage(), backend: _backend());
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Google orqali kirish'), findsOneWidget);
    expect(find.text('Telegram orqali kirish'), findsOneWidget);
    expect(find.text('Email orqali kirish'), findsOneWidget);

    await tester.tap(find.text('Keyinroq'));
    await tester.pumpAndSettle();
    expect(find.text('Mahsulot tanlang'), findsOneWidget);
  });

  testWidgets('a returning guest lands on home with products and tabs', (tester) async {
    final storage = MemoryTokenStorage()..flags['welcome_seen'] = '1';
    await pumpApp(tester, storage: storage, backend: _backend());
    expect(find.text('Mahsulot tanlang'), findsOneWidget);
    expect(find.text('Krujka'), findsOneWidget);
    for (final tab in ['Asosiy', 'Mahsulotlar', 'Dizaynlarim', 'Savat', 'Profil']) {
      expect(find.text(tab), findsWidgets);
    }
  });

  testWidgets('email sign-in from the welcome screen opens the app signed in', (tester) async {
    final storage = MemoryTokenStorage();
    await pumpApp(tester, storage: storage, backend: _backend());

    await tester.tap(find.text('Email orqali kirish'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'ali@dizzo.uz');
    await tester.enterText(find.widgetWithText(TextFormField, 'Parol'), 'secret123');
    final submit = find.widgetWithText(FilledButton, 'Kirish');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(storage.pair?.access, 'a1');
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.text('Mahsulot tanlang'), findsOneWidget);
    // The cart badge shows the server's count.
    expect(find.text('3'), findsOneWidget);
  });
}
