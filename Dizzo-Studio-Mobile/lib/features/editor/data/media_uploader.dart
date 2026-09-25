import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json.dart';

/// An uploaded file (`MediaOut`).
class MediaItem {
  const MediaItem({required this.id, required this.url, this.guest = false});

  factory MediaItem.fromJson(Json j) => MediaItem(id: j.str('id'), url: j.str('url'), guest: j.boolean('guest'));

  final String id;
  final String url;

  /// Uploaded without an account: claimed into the account after sign-in.
  final bool guest;
}

/// Accepted by the backend for design pictures (`app/api/v1/media.py`).
const mediaImageTypes = {'image/png', 'image/jpeg', 'image/webp'};
const designImageMaxBytes = 10 * 1024 * 1024;

/// Uploads straight to storage, as the web does (`useMediaUpload.ts`): the
/// backend hands out a presigned PUT, the bytes go there, then the backend
/// confirms the object.
class MediaUploader {
  MediaUploader(this._api, [Dio? storage]) : _storage = storage ?? Dio();

  final Dio _api;
  final Dio _storage;

  /// [purpose]: `design` (pictures, mockups, previews) or `print`.
  Future<MediaItem> upload(Uint8List bytes, String contentType, String purpose) async {
    try {
      final ticket = await _api.post<Object?>('/media/uploads/', data: {
        'purpose': purpose,
        'content_type': contentType,
        'size_bytes': bytes.length,
      });
      final t = Map<String, dynamic>.from(ticket.data! as Map);
      final headers = <String, dynamic>{...t.obj('upload_headers'), Headers.contentLengthHeader: bytes.length};
      final put = await _storage.request<Object?>(
        t.str('upload_url'),
        data: Stream<List<int>>.value(bytes),
        options: Options(
          method: t.str('upload_method', 'PUT'),
          headers: headers,
          contentType: contentType,
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 2),
          validateStatus: (_) => true,
        ),
      );
      final status = put.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw ApiException(ApiErrorKind.server, l10nNow.editorMainFileSaveFailed('$status'));
      }
      final done = await _api.post<Object?>('/media/${t.str('id')}/complete/');
      return MediaItem.fromJson(Map<String, dynamic>.from(done.data! as Map));
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// Moves guest uploads into the account; returns the new URLs by old URL.
  Future<Map<String, String>> claim(List<MediaItem> items) async {
    if (items.isEmpty) return const {};
    try {
      final res = await _api.post<Object?>('/media/claim/', data: {'ids': [for (final m in items) m.id]});
      final claimed = mapList(res.data, MediaItem.fromJson);
      return {
        for (var i = 0; i < items.length && i < claimed.length; i++) items[i].url: claimed[i].url,
      };
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}

final mediaUploaderProvider = Provider<MediaUploader>((ref) {
  final storage = Dio();
  ref.onDispose(storage.close);
  return MediaUploader(ref.watch(dioProvider), storage);
});
