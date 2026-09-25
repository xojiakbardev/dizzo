import 'package:dizzo/core/l10n/app_language.dart';
import 'package:dizzo/features/orders/domain/order_status.dart';
import 'package:dizzo/features/orders/presentation/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/account_harness.dart';
import 'helpers/fake_api.dart';
import 'helpers/l10n.dart';

Map<String, Object?> _item(int id, {String production = 'PENDING'}) => {
      'id': id,
      'product_name': 'Keramik krujka',
      'product_slug': 'krujka',
      'variant_name': '330 ml',
      'color_name': 'Oq',
      'color_hex': '#ffffff',
      'size': id.isEven ? 'XL' : '',
      'unit_price': '85000.00',
      'quantity': 2,
      'total_price': '170000.00',
      'production_status': production,
      'quote': {
        'methods': [
          {'method': 'uv', 'area_cm2': '92', 'tier_min_cm2': '0', 'tier_max_cm2': null, 'surcharge': '0'},
        ],
      },
      'mockups': <String>[],
    };

Map<String, Object?> _order({
  String status = 'NEW',
  String delivery = 'DELIVERY',
  String shipping = '0.00',
  String discount = '0.00',
  List<Map<String, Object?>>? items,
}) =>
    {
      'id': 42,
      'order_number': '0000042',
      'status': status,
      'subtotal': '170000.00',
      'shipping_cost': shipping,
      'discount_amount': discount,
      'total_amount': '170000.00',
      'delivery_method': delivery,
      'latitude': null,
      'longitude': null,
      'shipping_name': 'Ali Valiyev',
      'shipping_phone': '+998 90 123 45 67',
      'shipping_address': 'Amir Temur ko‘chasi 108',
      'shipping_city': 'Toshkent',
      'customer_notes': '',
      'tracking_number': '',
      'carrier': '',
      'items': items ?? [_item(1)],
      'payments': <Object?>[],
      'created_at': DateTime(2026, 9, 1, 22).toUtc().toIso8601String(),
      'updated_at': DateTime(2026, 9, 1, 22).toUtc().toIso8601String(),
    };

const _review = {
  'id': 3,
  'name': 'Ali V.',
  'city': 'Toshkent',
  'rating': 5,
  'text': 'Juda chiroyli chiqdi, rahmat!',
  'product_name': 'Keramik krujka',
  'product_slug': 'krujka',
  'photos': <String>[],
  'created_at': '2026-09-10T10:00:00Z',
  'status': 'pending',
  'order_id': 42,
  'order_number': '0000042',
};

FakeAdapter _backend(Object? order, {List<Object?> reviews = const []}) => routedAdapter({
      'GET /auth/me': (_) => testUser,
      'GET /orders/0000042/': (_) => order,
      'POST /orders/42/cancel/': (_) => _order(status: 'CANCELLED'),
      'GET /orders/': (_) => {'results': <Object?>[]},
      'GET /reviews/mine/': (_) => reviews,
    });

Future<void> _open(WidgetTester tester, FakeAdapter backend, {Size size = const Size(390, 844)}) =>
    pumpScreen(tester, const OrderDetailScreen(orderId: '0000042'), backend: backend, size: size);

void main() {
  setUpAll(initTestDates);

  test('short date and payment state', () {
    expect(AppDates.dateTimeShort(DateTime(2026, 9, 1, 22), 'uz'), '1-sentabr 2026, 22:00');
    expect(orderPaymentMeta(uzL10n, 'NEW')?.label, 'To‘lanmagan');
    expect(orderPaymentMeta(uzL10n, 'PAYMENT_PENDING')?.label, 'To‘lov kutilmoqda');
    expect(orderPaymentMeta(uzL10n, 'IN_PRODUCTION')?.label, 'To‘langan');
    expect(orderPaymentMeta(uzL10n, 'CANCELLED'), isNull);
  });

  testWidgets('a new order: title, status, tracker, item, money, delivery', (tester) async {
    await _open(tester, _backend(_order()));

    expect(find.text('Buyurtma №0000042'), findsOneWidget);
    expect(find.text('1-sentabr 2026, 22:00'), findsOneWidget);
    expect(find.text('Yangi'), findsOneWidget);
    expect(find.byType(OrderTracker), findsOneWidget);
    for (final step in orderStepLabels(uzL10n)) {
      expect(find.text(step), findsWidgets);
    }
    expect(find.text('Operator tez orada bog‘lanadi'), findsOneWidget);

    expect(find.text('Keramik krujka'), findsOneWidget);
    expect(find.text('330 ml'), findsOneWidget);
    expect(find.text('Rangli bosma'), findsOneWidget);
    expect(find.text('× 2'), findsOneWidget);
    // Production steps only while the order is being made.
    expect(find.text('Navbatda'), findsNothing);

    await tester.scrollUntilVisible(find.text('Ali Valiyev'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('To‘lanmagan'), findsOneWidget);
    expect(find.text('Kelishiladi'), findsOneWidget);
    expect(find.text('Amir Temur ko‘chasi 108, Toshkent'), findsOneWidget);
    expect(find.text('+998 90 123 45 67'), findsOneWidget);
    // No explanatory paragraphs or repeated fields.
    expect(find.textContaining('Operatorimiz'), findsNothing);
    expect(find.text('Qabul qiluvchi'), findsNothing);
  });

  testWidgets('a new order can be cancelled from the menu', (tester) async {
    final backend = _backend(_order());
    await _open(tester, backend);
    await tester.tap(find.byTooltip('Yana'));
    await settle(tester);
    await tester.tap(find.text('Bekor qilish'));
    await settle(tester);
    expect(find.text('Buyurtmani bekor qilasizmi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Bekor qilish'));
    await settle(tester);
    expect(backend.requests.any((r) => r.method == 'POST' && r.uri.path.endsWith('/orders/42/cancel/')), isTrue);
  });

  testWidgets('in production: cancel is disabled with a hint, items show their step', (tester) async {
    await _open(tester, _backend(_order(status: 'IN_PRODUCTION', items: [_item(1, production: 'PRINTING')])));
    expect(find.text('Ishlab chiqarilmoqda'), findsOneWidget);
    expect(find.text('Bosilmoqda'), findsOneWidget);
    await tester.tap(find.byTooltip('Yana'));
    await settle(tester);
    expect(find.text('Faqat yangi buyurtmani'), findsOneWidget);
    final item = tester.widget<PopupMenuItem<void>>(find.byType(PopupMenuItem<void>));
    expect(item.enabled, isFalse);
  });

  testWidgets('pickup ready: free pickup, hours, paid', (tester) async {
    await _open(tester, _backend(_order(status: 'READY_FOR_PICKUP', delivery: 'PICKUP')));
    expect(find.text('Olib ketishingiz mumkin'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Dushanba–Shanba, 09:00–20:00'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Bepul'), findsOneWidget);
    expect(find.text('To‘langan'), findsOneWidget);
    expect(find.text('Olib ketish'), findsOneWidget);
  });

  testWidgets('completed without a review: "Fikr qoldirish", no cancel menu', (tester) async {
    await _open(tester, _backend(_order(status: 'COMPLETED')));
    expect(find.text('Fikr qoldirish'), findsOneWidget);
    expect(find.byTooltip('Yana'), findsNothing);
    expect(find.text('Telegram orqali yozish'), findsOneWidget);
  });

  testWidgets('completed with a review: shows it instead of the button', (tester) async {
    await _open(tester, _backend(_order(status: 'COMPLETED'), reviews: [_review]));
    expect(find.text('Fikr qoldirish'), findsNothing);
    expect(find.text('Juda chiroyli chiqdi, rahmat!'), findsOneWidget);
  });

  testWidgets('cancelled: a distinct state instead of the tracker', (tester) async {
    await _open(tester, _backend(_order(status: 'CANCELLED')));
    expect(find.text('Buyurtma bekor qilingan'), findsOneWidget);
    expect(find.byType(OrderTracker), findsNothing);
    expect(find.byTooltip('Yana'), findsNothing);
    expect(find.text('To‘lanmagan'), findsNothing);
  });

  testWidgets('not found', (tester) async {
    await _open(tester, routedAdapter({'GET /auth/me': (_) => testUser}));
    expect(find.text('Buyurtma topilmadi'), findsOneWidget);
    expect(find.text('Barcha buyurtmalar'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    await _open(tester, _backend(const FakeResponse(403, {'detail': 'Serverda xatolik'})));
    expect(find.text('Buyurtma topilmadi'), findsNothing);
    expect(find.text('Qayta urinish'), findsOneWidget);
  });

  testWidgets('fits a 320 px phone and a tablet', (tester) async {
    final order = _order(status: 'READY_FOR_DELIVERY', shipping: '25000.00', discount: '15000.00', items: [_item(1), _item(2)]);
    await _open(tester, _backend(order), size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    expect(find.text('Chegirma'), findsOneWidget);
    await _open(tester, _backend(order), size: const Size(1280, 800));
    expect(tester.takeException(), isNull);
  });
}
