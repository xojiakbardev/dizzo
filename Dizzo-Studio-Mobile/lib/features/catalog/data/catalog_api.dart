import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json.dart';
import '../../../core/utils/money.dart';
import '../domain/catalog_models.dart';

/// Public catalog endpoints (`Dizzo-Backend/app/api/v1/catalog.py`).
/// The list endpoint has no server-side search or filter: it returns every
/// product on sale, and the app filters locally.
class CatalogApi {
  CatalogApi(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<List<ProductSummary>> products({bool popular = false}) => _guard(() async {
        final res = await _dio.get<Object?>(
          '/catalog/products/',
          queryParameters: {if (popular) 'sort': 'popular'},
        );
        return mapList(res.data, ProductSummary.fromJson);
      });

  Future<List<Category>> categories() => _guard(() async {
        final res = await _dio.get<Object?>('/catalog/categories/');
        return mapList(res.data, Category.fromJson);
      });

  Future<ProductDetail> product(String slug) => _guard(() async {
        final res = await _dio.get<Object?>('/catalog/products/${Uri.encodeComponent(slug)}/');
        return ProductDetail.fromJson(Map<String, dynamic>.from(res.data! as Map));
      });

  /// The price of one piece of a type / colour / size before any print
  /// surcharge (`POST /catalog/quote/` without areas).
  Future<Money> quote({required int variantId, required int colorId, String? size}) => _guard(() async {
        final res = await _dio.post<Object?>('/catalog/quote/', data: {
          'variant_id': variantId,
          'color_id': colorId,
          'quantity': 1,
          'size': ?size,
        });
        final data = res.data;
        return Money.parse(data is Map ? data['unit_price'] : null);
      });
}

final catalogApiProvider = Provider<CatalogApi>((ref) => CatalogApi(ref.watch(dioProvider)));
