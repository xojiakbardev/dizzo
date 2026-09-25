import 'package:dizzo/core/l10n/app_language.dart';
import 'package:dizzo/features/orders/presentation/orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/account_harness.dart';
import 'helpers/fake_api.dart';
import 'helpers/l10n.dart';

Map<String, Object?> _order(int id, {String status = 'NEW', int items = 2, String total = '98000.00'}) => {
      'id': id,
      'order_number': id.toString().padLeft(7, '0'),
      'status': status,
      'delivery_method': id.isEven ? 'PICKUP' : 'DELIVERY',
      'total_amount': total,
      'item_count': items,
      // 1 September 2026, 22:00 local time, minus a day per order.
      'created_at': DateTime(2026, 9, 1, 22).subtract(Duration(days: id - 1)).toUtc().toIso8601String(),
      'updated_at': DateTime(2026, 9, 1, 22).toUtc().toIso8601String(),
    };

const _stats = {
  'total_orders': 25,
  'new_orders': 3,
  'payment_pending_orders': 2,
  'paid_orders': 1,
  'in_production_orders': 4,
  'done_orders': 10,
  'total_spent': '1250000.00',
};

void main() {
  setUpAll(initTestDates);

  test('dates read like "1-sentabr 2026 yil 22:00"', () {
    expect(AppDates.dateTime(DateTime(2026, 9, 1, 22), 'uz'), '1-sentabr 2026 yil 22:00');
    expect(AppDates.date(DateTime(2026, 1, 15, 8, 5), 'uz'), '15-yanvar 2026 yil');
    expect(AppDates.dateTime(DateTime(2025, 12, 31, 9, 5), 'uz'), '31-dekabr 2025 yil 09:05');
    expect(AppDates.date(DateTime(2026, 9, 1), 'ru'), '1 сентября 2026 г.');
    expect(AppDates.dateTime(DateTime(2026, 9, 1, 22), 'en'), 'September 1, 2026, 22:00');
  });

  FakeAdapter backend(List<Map<String, Object?>> orders) => routedAdapter({
        'GET /auth/me': (_) => testUser,
        'GET /orders/': (_) => {'count': orders.length, 'next': null, 'previous': null, 'results': orders},
        'GET /orders/stats/': (_) => _stats,
      });

  testWidgets('shows figures and a compact order list', (tester) async {
    final orders = [
      _order(1, status: 'IN_PRODUCTION', items: 3, total: '147000.00'),
      _order(2, status: 'COMPLETED'),
      _order(3, status: 'CANCELLED'),
    ];
    final router = await pumpScreen(tester, const OrdersScreen(), backend: backend(orders));

    expect(find.text('Jami buyurtma'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('To‘lov kutilmoqda'), findsOneWidget);
    expect(find.text('Ishlab chiqarishda'), findsOneWidget);
    expect(find.textContaining('1 250 000', findRichText: true), findsOneWidget);

    expect(find.text('№0000001'), findsOneWidget);
    expect(find.text('1-sentabr 2026 yil 22:00'), findsOneWidget);
    expect(find.text('3 ta mahsulot'), findsOneWidget);
    expect(find.text('Ishlab chiqarilmoqda'), findsOneWidget);
    expect(find.text('Yakunlangan'), findsOneWidget);
    expect(find.text('Bekor qilingan'), findsOneWidget);
    expect(find.textContaining('147 000', findRichText: true), findsOneWidget);

    await tester.tap(find.text('№0000002'));
    await settle(tester);
    expect(router.state.uri.toString(), '/orders/0000002');
  });

  testWidgets('pages through long lists', (tester) async {
    final orders = [for (var i = 1; i <= 45; i++) _order(i)];
    await pumpScreen(tester, const OrdersScreen(), backend: backend(orders));
    expect(find.text('№0000001'), findsOneWidget);

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('№0000020'), 400, scrollable: list);
    await settle(tester);
    await tester.scrollUntilVisible(find.text('№0000040'), 400, scrollable: list);
    await settle(tester);
    await tester.scrollUntilVisible(find.text('№0000045'), 400, scrollable: list);
    await settle(tester);
    expect(find.text('№0000045'), findsOneWidget);
    expect(find.text('Yana ko‘rsatish'), findsNothing);
  });

  testWidgets('no orders: an empty state with a way to the catalog', (tester) async {
    final router = await pumpScreen(tester, const OrdersScreen(), backend: backend(const []));
    expect(find.text('Hali buyurtma yo‘q'), findsOneWidget);
    await tester.tap(find.text('Mahsulot tanlash'));
    await settle(tester);
    expect(router.state.uri.toString(), '/products');
  });

  testWidgets('a failed load offers a retry', (tester) async {
    var fail = true;
    final adapter = routedAdapter({
      'GET /auth/me': (_) => testUser,
      'GET /orders/': (_) => fail ? const FakeResponse(500, {'detail': 'Serverda xatolik'}) : {'results': [_order(7)]},
      'GET /orders/stats/': (_) => _stats,
    });
    await pumpScreen(tester, const OrdersScreen(), backend: adapter);
    expect(find.text('Serverda xatolik'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Qayta urinish'));
    await settle(tester);
    expect(find.text('№0000007'), findsOneWidget);
  });

  testWidgets('fits a 320 px phone and a tablet', (tester) async {
    final orders = [for (var i = 1; i <= 5; i++) _order(i, status: 'READY_FOR_PRODUCTION', total: '12345678.00')];
    await pumpScreen(tester, const OrdersScreen(), backend: backend(orders), size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    await pumpScreen(tester, const OrdersScreen(), backend: backend(orders), size: const Size(1280, 800));
    expect(tester.takeException(), isNull);
  });
}
