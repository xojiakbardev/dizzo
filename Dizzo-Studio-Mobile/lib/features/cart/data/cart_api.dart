import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/cart_models.dart';

/// Backend `/cart/*` (app/api/v1/cart.py). Every call answers with the
/// whole cart.
class CartApi {
  CartApi(this._dio);

  final Dio _dio;

  /// The backend's limit per item.
  static const maxQuantity = 1000;

  Future<Cart> _run(Future<Response<Object?>> Function() call) async {
    try {
      final res = await call();
      final data = res.data;
      return data is Map ? Cart.fromJson(Map<String, dynamic>.from(data)) : Cart.empty;
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<Cart> fetch() => _run(() => _dio.get<Object?>('/cart/'));

  Future<Cart> setQuantity(String itemUuid, int quantity) =>
      _run(() => _dio.patch<Object?>('/cart/items/$itemUuid/', data: {'quantity': quantity}));

  Future<Cart> remove(String itemUuid) => _run(() => _dio.delete<Object?>('/cart/items/$itemUuid/'));

  Future<Cart> clear() => _run(() => _dio.delete<Object?>('/cart/clear/'));
}

final cartApiProvider = Provider<CartApi>((ref) => CartApi(ref.watch(dioProvider)));
