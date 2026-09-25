import 'package:dizzo/features/cart/presentation/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/account_harness.dart';
import 'helpers/fake_api.dart';

Map<String, Object?> _item(String uuid, String name, int qty, {String price = '49000.00', bool available = true}) => {
      'uuid': uuid,
      'design_id': 'd-$uuid',
      'product_slug': 'krujka',
      'product_name': name,
      'variant_id': 1,
      'variant_name': 'Oq 330 ml',
      'color_id': 2,
      'color_name': 'Oq',
      'color_hex': '#FFFFFF',
      'size': '',
      'quantity': qty,
      'unit_price': price,
      'total_price': '${double.parse(price) * qty}',
      'quote': {
        'methods': [
          {'method': 'uv', 'area_cm2': '48.00'},
        ],
      },
      'mockups': <String>[],
      'files': <Object>[],
      'available': available,
    };

Map<String, Object?> _cart(List<Map<String, Object?>> items) {
  final total = items.fold<double>(0, (a, i) => a + double.parse(i['total_price']! as String));
  return {
    'uuid': 'c1',
    'items': items,
    'total_items': items.fold<int>(0, (a, i) => a + (i['quantity']! as int)),
    'subtotal': '$total',
    'total_amount': '$total',
    'is_empty': items.isEmpty,
    'blocked': items.any((i) => i['available'] == false),
  };
}

void main() {
  late List<Map<String, Object?>> items;
  late FakeAdapter backend;

  setUp(() {
    items = [_item('a', 'Krujka', 2), _item('b', 'Futbolka', 1, price: '129000.00')];
    backend = routedAdapter({
      'GET /auth/me': (_) => testUser,
      'GET /cart/': (_) => _cart(items),
      'PATCH /cart/items/a/': (o) {
        final q = (o.data as Map)['quantity'] as int;
        items[0] = _item('a', 'Krujka', q);
        return _cart(items);
      },
      'DELETE /cart/items/b/': (_) {
        items.removeAt(1);
        return _cart(items);
      },
      'DELETE /cart/clear/': (_) {
        items.clear();
        return _cart(items);
      },
    });
  });

  int count(String method, String path) =>
      backend.requests.where((r) => r.method == method && r.uri.path.endsWith(path)).length;

  testWidgets('shows items, options, prices and the checkout bar', (tester) async {
    final router = await pumpScreen(tester, const CartScreen(), backend: backend);
    expect(find.text('Krujka'), findsOneWidget);
    expect(find.text('Futbolka'), findsOneWidget);
    expect(find.textContaining('Oq 330 ml', findRichText: true), findsNWidgets(2));
    expect(find.text('Rangli bosma · 48 cm²'), findsNWidgets(2));
    expect(find.textContaining('98 000', findRichText: true), findsOneWidget);
    expect(find.text('3 ta mahsulot'), findsOneWidget);
    expect(find.textContaining('227 000', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Rasmiylashtirish'));
    await settle(tester);
    expect(router.state.uri.toString(), '/checkout');
  });

  testWidgets('stepper updates at once and sends one request', (tester) async {
    await pumpScreen(tester, const CartScreen(), backend: backend);
    final plus = find.byTooltip('Ko‘paytirish').first;
    await tester.tap(plus);
    await tester.pump();
    await tester.tap(plus);
    await tester.pump();
    expect(find.text('4'), findsOneWidget);
    expect(find.text('5 ta mahsulot'), findsOneWidget);
    expect(count('PATCH', '/cart/items/a/'), 0);

    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    expect(count('PATCH', '/cart/items/a/'), 1);
    expect(backend.requests.last.data, {'quantity': 4});
    expect(find.textContaining('196 000', findRichText: true), findsOneWidget);
  });

  testWidgets('removing can be undone; otherwise it is sent', (tester) async {
    await pumpScreen(tester, const CartScreen(), backend: backend);

    Future<void> removeFutbolka() async {
      await tester.tap(find.byTooltip('Amallar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('O‘chirish'));
      await tester.pumpAndSettle();
    }

    await removeFutbolka();
    expect(find.text('Futbolka'), findsNothing);
    expect(find.text('Qaytarish'), findsOneWidget);
    await tester.tap(find.text('Qaytarish'));
    await tester.pumpAndSettle();
    expect(find.text('Futbolka'), findsOneWidget);
    expect(count('DELETE', '/cart/items/b/'), 0);

    await removeFutbolka();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(count('DELETE', '/cart/items/b/'), 1);
    expect(find.text('Futbolka'), findsNothing);
    expect(find.text('2 ta mahsulot'), findsOneWidget);
  });

  testWidgets('clearing asks first and ends on the empty state', (tester) async {
    await pumpScreen(tester, const CartScreen(), backend: backend);
    await tester.tap(find.text('Tozalash'));
    await tester.pumpAndSettle();
    expect(find.text('Savatni tozalaysizmi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Tozalash'));
    await tester.pumpAndSettle();
    expect(count('DELETE', '/cart/clear/'), 1);
    expect(find.text('Savat bo‘sh'), findsOneWidget);
  });

  testWidgets('off-sale items block checkout', (tester) async {
    items = [_item('a', 'Krujka', 1, available: false)];
    await pumpScreen(tester, const CartScreen(), backend: backend);
    expect(find.text('Ba’zi mahsulotlar sotuvda yo‘q'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Rasmiylashtirish'));
    expect(button.onPressed, isNull);
  });

  testWidgets('guests are asked to sign in', (tester) async {
    await pumpScreen(tester, const CartScreen(), backend: backend, storage: sessionStorage(signedIn: false));
    expect(find.text('Savatni ko‘rish uchun kiring'), findsOneWidget);
    expect(find.text('Kirish'), findsOneWidget);
    expect(count('GET', '/cart/'), 0);
  });

  testWidgets('fits a 320 px phone and a tablet', (tester) async {
    await pumpScreen(tester, const CartScreen(), backend: backend, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    await pumpScreen(tester, const CartScreen(), backend: backend, size: const Size(1280, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('Jami'), findsOneWidget);
  });
}
