import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json.dart';
import '../domain/design_document.dart';
import '../domain/editor_models.dart';

/// The cart priced the item differently from what was shown (409): the
/// customer confirms [quote] and the item is sent again with its price.
class PriceChanged implements Exception {
  const PriceChanged(this.message, this.quote);

  final String message;
  final Quote quote;
}

/// The design was saved elsewhere meanwhile (409 on PUT).
class DesignConflict implements Exception {
  const DesignConflict();
}

/// The Studio endpoints the web uses (`useStudio.ts`).
class EditorApi {
  EditorApi(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PriceChanged {
      rethrow;
    } on DesignConflict {
      rethrow;
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Json _obj(Object? data) => data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

  Future<List<DesignTemplate>> templates(String slug) => _guard(() async {
        final res = await _dio.get<Object?>('/catalog/products/${Uri.encodeComponent(slug)}/templates/');
        return mapList(res.data, DesignTemplate.fromJson);
      });

  /// How often each library graphic is used (`[{library, name, count}]`).
  Future<Map<String, int>> popularGraphics() => _guard(() async {
        final res = await _dio.get<Object?>('/studio/graphics/popular/');
        return {
          for (final j in mapList(res.data, (j) => j)) '${j.str('library')}:${j.str('name')}': j.integer('count'),
        };
      });

  Future<SavedDesign> design(String id) => _guard(() async {
        final res = await _dio.get<Object?>('/studio/designs/$id/');
        return SavedDesign.fromJson(_obj(res.data));
      });

  /// Creates (no [id]) or updates a design. [previews]: media ids of the
  /// five views ("Dizaynlarim" shows them); null keeps the saved ones.
  Future<SavedDesign> saveDesign({
    String? id,
    int? version,
    required int variantId,
    required int colorId,
    required DesignDocument document,
    required Map<String, String> areasCm2,
    List<String>? previews,
  }) =>
      _guard(() async {
        final body = {
          'variant_id': variantId,
          'color_id': colorId,
          'document': document.toJson(),
          'areas_cm2': areasCm2,
          'previews': ?previews,
          if (id != null) 'version': version,
        };
        try {
          final res = id == null
              ? await _dio.post<Object?>('/studio/designs/', data: body)
              : await _dio.put<Object?>('/studio/designs/$id/', data: body);
          return SavedDesign.fromJson(_obj(res.data));
        } on DioException catch (e) {
          if (e.response?.statusCode == 409 && id != null) throw const DesignConflict();
          rethrow;
        }
      });

  Future<Quote> quote({
    required int variantId,
    required int colorId,
    String? size,
    required Map<String, String> areasCm2,
  }) =>
      _guard(() async {
        final res = await _dio.post<Object?>('/catalog/quote/', data: {
          'variant_id': variantId,
          'color_id': colorId,
          'quantity': 1,
          'size': size,
          'areas_cm2': areasCm2,
        });
        return Quote.fromJson(_obj(res.data));
      });

  /// `POST /cart/items/`; throws [PriceChanged] when the print files price
  /// differently from [expectedUnitPrice].
  Future<void> addCartItem(Json item, String expectedUnitPrice) => _guard(() async {
        try {
          await _dio.post<Object?>('/cart/items/', data: {...item, 'expected_unit_price': expectedUnitPrice});
        } on DioException catch (e) {
          final data = e.response?.data;
          if (e.response?.statusCode == 409 && data is Map && data['quote'] is Map) {
            throw PriceChanged(
              ApiException.detailMessage(data) ?? l10nNow.editorMainPriceRecalculated,
              Quote.fromJson(Map<String, dynamic>.from(data['quote'] as Map)),
            );
          }
          rethrow;
        }
      });
}

final editorApiProvider = Provider<EditorApi>((ref) => EditorApi(ref.watch(dioProvider)));

final templatesProvider = FutureProvider.autoDispose.family<List<DesignTemplate>, String>(
  (ref, slug) => ref.watch(editorApiProvider).templates(slug),
);

final popularGraphicsProvider = FutureProvider<Map<String, int>>(
  (ref) => ref.watch(editorApiProvider).popularGraphics().catchError((_) => <String, int>{}),
);
