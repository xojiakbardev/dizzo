import 'dart:ui' show Color;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../catalog/domain/catalog_models.dart';

/// A saved Studio design (`DesignSummary`, app/schemas/design.py).
class DesignSummary {
  const DesignSummary({
    required this.id,
    required this.productSlug,
    required this.productName,
    this.variantName = '',
    this.colorName = '',
    this.colorHex = '',
    this.previews = const [],
    this.updatedAt,
  });

  factory DesignSummary.fromJson(Json json) {
    final previews = json.strings('previews');
    final cover = json.strOrNull('preview_url');
    return DesignSummary(
      id: json.str('id'),
      productSlug: json.str('product_slug'),
      productName: json.str('product_name'),
      variantName: json.str('variant_name'),
      colorName: json.str('color_name'),
      colorHex: json.str('color_hex'),
      previews: previews.isNotEmpty ? previews : [?cover],
      updatedAt: json.date('updated_at'),
    );
  }

  final String id;
  final String productSlug;
  final String productName;
  final String variantName;
  final String colorName;
  final String colorHex;

  /// The Studio's views; an older design has one or none.
  final List<String> previews;
  final DateTime? updatedAt;

  Color? get color => colorHex.isEmpty ? null : parseHexColor(colorHex);
}

/// Backend `/studio/designs/` (list, delete).
class DesignsApi {
  DesignsApi(this._dio);

  final Dio _dio;

  Future<List<DesignSummary>> mine() async {
    try {
      final res = await _dio.get<Object?>('/studio/designs/');
      return mapList(res.data, DesignSummary.fromJson);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<Object?>('/studio/designs/$id/');
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}

final designsApiProvider = Provider<DesignsApi>((ref) => DesignsApi(ref.watch(dioProvider)));

/// "Dizaynlarim", newest first. The editor should
/// `ref.invalidate(myDesignsProvider)` after saving a design.
class MyDesignsController extends AsyncNotifier<List<DesignSummary>> {
  @override
  Future<List<DesignSummary>> build() async {
    ref.watch(contentLanguageProvider);
    final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
    if (userId == null) return const [];
    return ref.read(designsApiProvider).mine();
  }

  /// Removes at once; puts it back and rethrows if the server refuses.
  Future<void> delete(String id) async {
    final before = state.value;
    if (before == null) return;
    state = AsyncData([for (final d in before) if (d.id != id) d]);
    try {
      await ref.read(designsApiProvider).delete(id);
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.notFound) return;
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
  }
}

final myDesignsProvider = AsyncNotifierProvider<MyDesignsController, List<DesignSummary>>(MyDesignsController.new);
