import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json.dart';
import '../domain/order_models.dart';

/// A page of orders. The backend returns every order at once today
/// (`next` is null); the list still follows `next` if it ever pages.
class OrdersPage {
  const OrdersPage(this.results, {this.next});

  final List<OrderSummary> results;
  final String? next;
}

/// Backend `/orders/*` and `/checkout/` (app/api/v1/orders.py, checkout.py).
class OrdersApi {
  OrdersApi(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  static Json _map(Object? data) =>
      data is Map ? Map<String, dynamic>.from(data) : throw ApiException(ApiErrorKind.unknown, l10nNow.errorGeneric);

  Future<OrdersPage> list({String? next}) => _guard(() async {
        final res = await _dio.get<Object?>(next ?? '/orders/');
        final data = res.data;
        if (data is List) return OrdersPage(mapList(data, OrderSummary.fromJson));
        final json = _map(data);
        return OrdersPage(json.list('results', OrderSummary.fromJson), next: json.strOrNull('next'));
      });

  Future<OrderStats> stats() => _guard(() async {
        final res = await _dio.get<Object?>('/orders/stats/');
        return OrderStats.fromJson(_map(res.data));
      });

  /// By order number or id.
  Future<OrderDetail> detail(String lookup) => _guard(() async {
        final res = await _dio.get<Object?>('/orders/${Uri.encodeComponent(lookup)}/');
        return OrderDetail.fromJson(_map(res.data));
      });

  Future<OrderDetail> cancel(int orderId) => _guard(() async {
        final res = await _dio.post<Object?>('/orders/$orderId/cancel/');
        return OrderDetail.fromJson(_map(res.data));
      });

  /// Places the order from the cart. [body] matches the backend's
  /// `CheckoutRequest` (unknown fields are rejected). The same
  /// [idempotencyKey] from the same customer returns the same order, so a
  /// retry after a lost answer doesn't place a second one.
  Future<CheckoutResult> checkout(Json body, {String? idempotencyKey}) => _guard(() async {
        final res = await _dio.post<Object?>(
          '/checkout/',
          data: body,
          options: idempotencyKey == null ? null : Options(headers: {'Idempotency-Key': idempotencyKey}),
        );
        return CheckoutResult.fromJson(_map(res.data));
      });
}

final ordersApiProvider = Provider<OrdersApi>((ref) => OrdersApi(ref.watch(dioProvider)));

final _random = Random.secure();

/// A random UUID (v4) for the `Idempotency-Key` header: one per checkout
/// attempt.
String newIdempotencyKey() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
