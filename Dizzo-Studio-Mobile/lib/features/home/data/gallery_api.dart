import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json.dart';
import '../domain/gallery_item.dart';

/// Customer works for the home screen (`GET /gallery/?limit=`).
final galleryProvider = FutureProvider<List<GalleryItem>>((ref) async {
  ref.watch(contentLanguageProvider);
  try {
    final res = await ref.watch(dioProvider).get<Object?>(
      '/gallery/',
      queryParameters: {'limit': 12},
    );
    return mapList(res.data, GalleryItem.fromJson);
  } catch (e) {
    throw ApiException.from(e);
  }
});
