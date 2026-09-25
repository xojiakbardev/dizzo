import 'package:dizzo/core/l10n/app_language.dart';
import 'package:dizzo/features/checkout/domain/uz_phone.dart';
import 'package:dizzo/features/checkout/presentation/checkout_screen.dart';
import 'package:dizzo/features/designs/presentation/designs_screen.dart';
import 'package:dizzo/features/orders/data/orders_api.dart';
import 'package:dizzo/features/profile/presentation/profile_screen.dart';
import 'package:dizzo/features/reviews/presentation/my_reviews_screen.dart';
import 'package:dizzo/features/settings/presentation/privacy_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/account_harness.dart';
import 'helpers/fake_api.dart';
import 'helpers/l10n.dart';

final _cart = {
  'uuid': 'c1',
  'items': [
    {
      'uuid': 'a',
      'product_slug': 'krujka',
      'product_name': 'Krujka',
      'variant_name': 'Oq',
      'color_name': 'Oq',
      'quantity': 2,
      'unit_price': '49000.00',
      'total_price': '98000.00',
      'mockups': <String>[],
      'available': true,
    },
  ],
  'total_items': 2,
  'subtotal': '98000.00',
  'total_amount': '98000.00',
  'blocked': false,
};

void main() {
  group('UzPhone', () {
    test('formats and completes', () {
      expect(UzPhone.format('+998901234567'), '+998 90 123 45 67');
      expect(UzPhone.format('90 12'), '+998 90 12');
      expect(UzPhone.isComplete('+998 90 123 45 67'), isTrue);
      expect(UzPhone.isComplete('+998 90 123'), isFalse);
    });

    test('formatter keeps the prefix while typing and deleting', () {
      const f = UzPhoneFormatter();
      var v = f.formatEditUpdate(
        const TextEditingValue(text: '+998 '),
        const TextEditingValue(text: '+998 901'),
      );
      expect(v.text, '+998 90 1');
      v = f.formatEditUpdate(const TextEditingValue(text: '+998 9'), const TextEditingValue(text: '+998'));
      expect(v.text, '+998 ');
    });
  });

  testWidgets('checkout: prefilled contact, pickup order, success screen', (tester) async {
    Map<Object?, Object?>? sent;
    final backend = routedAdapter({
      'GET /auth/me': (_) => testUser,
      'GET /cart/': (_) => _cart,
      'POST /checkout/': (o) {
        sent = o.data as Map;
        return {'order_number': '0000042', 'order_id': 42, 'total_amount': '98000.00', 'status': 'NEW'};
      },
    });
    final router = await pumpScreen(tester, const CheckoutScreen(), backend: backend);
    expect(find.text('Ali Valiyev'), findsOneWidget);
    expect(find.text('+998 90 123 45 67'), findsOneWidget);
    expect(find.text('Krujka'), findsOneWidget);

    // Delivery needs an address.
    await tester.tap(find.text('Buyurtma berish'));
    await settle(tester);
    expect(find.text('Manzilni kiriting'), findsOneWidget);
    expect(sent, isNull);

    await tester.tap(find.text('Olib ketish').first);
    await tester.pumpAndSettle();
    expect(find.text(PickupPoint.name(uzL10n)), findsOneWidget);
    await tester.tap(find.text('Buyurtma berish'));
    await settle(tester);

    expect(sent?['delivery_method'], 'PICKUP');
    expect(sent?['contact_phone'], '+998 90 123 45 67');
    expect(sent?['contact_name'], 'Ali Valiyev');
    expect(sent?['latitude'], isNull);
    await tester.pumpAndSettle();
    expect(find.text('Buyurtma qabul qilindi'), findsOneWidget);
    expect(find.text('№0000042'), findsOneWidget);

    await tester.tap(find.text('Buyurtmani ko‘rish'));
    await settle(tester);
    expect(router.state.uri.toString(), '/orders/0000042');
  });

  testWidgets('checkout sends an Idempotency-Key: kept on a retry after 5xx, new after 4xx', (tester) async {
    final keys = <String?>[];
    final answers = <Object?>[
      const FakeResponse(503, {'detail': 'Serverda xatolik'}),
      {'order_number': '0000042', 'order_id': 42, 'total_amount': '98000.00', 'status': 'NEW'},
    ];
    final backend = routedAdapter({
      'GET /auth/me': (_) => testUser,
      'GET /cart/': (_) => _cart,
      'POST /checkout/': (o) {
        keys.add(o.headers['Idempotency-Key'] as String?);
        return answers.removeAt(0);
      },
    });
    await pumpScreen(tester, const CheckoutScreen(), backend: backend);
    await tester.tap(find.text('Olib ketish').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buyurtma berish'));
    await settle(tester);
    await tester.tap(find.text('Buyurtma berish'));
    await settle(tester);

    expect(keys, hasLength(2));
    expect(keys.first, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(keys.last, keys.first);
    expect(newIdempotencyKey(), isNot(newIdempotencyKey()));
  });

  testWidgets('checkout: a refused attempt gets a new key next time', (tester) async {
    final keys = <String?>[];
    final backend = routedAdapter({
      'GET /auth/me': (_) => testUser,
      'GET /cart/': (_) => _cart,
      'POST /checkout/': (o) {
        keys.add(o.headers['Idempotency-Key'] as String?);
        return const FakeResponse(422, {'detail': 'Telefon noto‘g‘ri'});
      },
    });
    await pumpScreen(tester, const CheckoutScreen(), backend: backend);
    await tester.tap(find.text('Olib ketish').first);
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Buyurtma berish'));
      await settle(tester);
    }
    expect(keys, hasLength(2));
    expect(keys.first, isNotNull);
    expect(keys.last, isNot(keys.first));
  });

  testWidgets('checkout shows server errors inline', (tester) async {
    final backend = routedAdapter({
      'GET /auth/me': (_) => testUser,
      'GET /cart/': (_) => _cart,
      'POST /checkout/': (_) => const FakeResponse(409, {'detail': 'Savatdagi narxlar yangilandi'}),
    });
    await pumpScreen(tester, const CheckoutScreen(), backend: backend, size: const Size(320, 640));
    await tester.tap(find.text('Olib ketish').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buyurtma berish'));
    await settle(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text('Savatdagi narxlar yangilandi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile: account card, edit name, sections, logout', (tester) async {
    Object? patched;
    var loggedOut = false;
    final backend = routedAdapter({
      'GET /auth/me': (_) => testUser,
      'GET /cart/': (_) => _cart,
      'PATCH /users/profile/me/': (o) {
        patched = o.data;
        return {...testUser, 'first_name': 'Vali', 'full_name': 'Vali Valiyev'};
      },
      'POST /auth/logout/': (_) {
        loggedOut = true;
        return {'ok': true};
      },
    });
    final storage = sessionStorage();
    await pumpScreen(tester, const ProfileScreen(), backend: backend, storage: storage);
    expect(find.text('Ali Valiyev'), findsOneWidget);
    expect(find.text('ali@dizzo.uz'), findsOneWidget);
    expect(find.text('Telegram xabarnomalari'), findsOneWidget);
    for (final t in ['Buyurtmalarim', 'Dizaynlarim', 'Savat', 'Fikrlarim', 'Chiqish']) {
      expect(find.text(t), findsOneWidget);
    }

    await tester.tap(find.byTooltip('Tahrirlash'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Ism'), 'Vali');
    await tester.tap(find.text('Saqlash'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect((patched! as Map)['first_name'], 'Vali');
    expect((patched! as Map)['phone_number'], '+998 90 123 45 67');
    expect(find.text('Vali Valiyev'), findsOneWidget);

    await tester.tap(find.text('Chiqish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Chiqish'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(loggedOut, isTrue);
    expect(storage.pair, isNull);
    expect(find.text('Hisobingizga kiring'), findsOneWidget);
  });

  testWidgets('profile: delete account after confirming signs out without logout', (tester) async {
    var deleted = 0;
    var loggedOut = false;
    final backend = routedAdapter({
      'GET /auth/me': (_) => testUser,
      'GET /cart/': (_) => _cart,
      'DELETE /users/profile/me/': (_) {
        deleted++;
        return const FakeResponse(204);
      },
      'POST /auth/logout/': (_) {
        loggedOut = true;
        return {'ok': true};
      },
    });
    final storage = sessionStorage();
    await pumpScreen(tester, const ProfileScreen(), backend: backend, storage: storage);
    expect(find.text('Maxfiylik siyosati'), findsOneWidget);
    final button = find.byKey(const ValueKey('delete-account'));
    await tester.scrollUntilVisible(button, 200);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Hisobni o‘chirasizmi?'), findsOneWidget);
    expect(find.textContaining('ortga qaytarib bo‘lmaydi'), findsOneWidget);

    // Cancel: nothing happens.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Bekor qilish'));
    await tester.pumpAndSettle();
    expect(deleted, 0);

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'O‘chirish'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(deleted, 1);
    expect(loggedOut, isFalse);
    expect(storage.pair, isNull);
    expect(storage.user, isNull);
    expect(find.text('Hisobingiz o‘chirildi'), findsOneWidget);
    expect(find.text('Hisobingizga kiring'), findsOneWidget);
    // Guests still see the privacy policy.
    expect(find.text('Maxfiylik siyosati'), findsOneWidget);
  });

  testWidgets('profile: a refused deletion shows the server message and keeps the session', (tester) async {
    final backend = routedAdapter({
      'GET /auth/me': (_) => testUser,
      'GET /cart/': (_) => _cart,
      'DELETE /users/profile/me/': (_) =>
          const FakeResponse(409, {'detail': 'Sizda yakunlanmagan buyurtma bor'}),
    });
    final storage = sessionStorage();
    await pumpScreen(tester, const ProfileScreen(), backend: backend, storage: storage);
    final button = find.byKey(const ValueKey('delete-account'));
    await tester.scrollUntilVisible(button, 200);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'O‘chirish'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Sizda yakunlanmagan buyurtma bor'), findsOneWidget);
    expect(storage.pair, isNotNull);
    expect(find.text('Ali Valiyev'), findsOneWidget);
  });

  test('privacy policy URL follows the language', () {
    expect(privacyPolicyUri(AppLanguage.uz).toString(), 'https://dizzo.uz/privacy');
    expect(privacyPolicyUri(AppLanguage.ru).toString(), 'https://dizzo.uz/ru/privacy');
    expect(privacyPolicyUri(AppLanguage.en).toString(), 'https://dizzo.uz/en/privacy');
  });

  testWidgets('designs: grid, open in editor, delete after confirming', (tester) async {
    var deleted = 0;
    final backend = routedAdapter({
      'GET /auth/me': (_) => testUser,
      'GET /studio/designs/': (_) => [
            {'id': 'd1', 'product_slug': 'krujka', 'product_name': 'Krujka', 'variant_name': 'Oq', 'color_name': 'Oq',
              'preview_url': null, 'previews': <String>[], 'updated_at': '2026-09-01T10:00:00Z'},
            {'id': 'd2', 'product_slug': 'futbolka', 'product_name': 'Futbolka', 'previews': <String>[]},
          ],
      'DELETE /studio/designs/d2/': (_) {
        deleted++;
        return const FakeResponse(204);
      },
    });
    final router = await pumpScreen(tester, const DesignsScreen(), backend: backend);
    expect(find.text('Krujka'), findsOneWidget);
    expect(find.text('Futbolka'), findsOneWidget);

    await tester.tap(find.byTooltip('Amallar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('O‘chirish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'O‘chirish'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(deleted, 1);
    expect(find.text('Futbolka'), findsNothing);

    await tester.tap(find.text('Krujka'));
    await settle(tester);
    expect(router.state.uri.toString(), '/editor/krujka?design=d1');
  });

  testWidgets('Fikrlarim lists reviews with status', (tester) async {
    final backend = routedAdapter({
      'GET /auth/me': (_) => testUser,
      'GET /reviews/mine/': (_) => [
            {'id': 1, 'rating': 4, 'text': 'Juda yaxshi chiqdi', 'product_name': 'Krujka', 'photos': <String>[],
              'status': 'approved', 'order_id': 42, 'order_number': '0000042', 'created_at': '2026-09-01T10:00:00Z'},
          ],
    });
    final router = await pumpScreen(tester, const MyReviewsScreen(), backend: backend);
    expect(find.text('Juda yaxshi chiqdi'), findsOneWidget);
    expect(find.text('Saytda ko‘rinadi'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    await tester.tap(find.text('№0000042'));
    await settle(tester);
    expect(router.state.uri.toString(), '/orders/0000042');
  });
}
