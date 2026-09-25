import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/utils/json.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/review.dart';

/// An uploaded photo (`MediaOut`).
class UploadedPhoto {
  const UploadedPhoto({required this.id, required this.url});

  final String id;
  final String url;
}

/// Backend `/reviews/*` and the R2 upload flow of `/media/*`.
class ReviewsApi {
  ReviewsApi(this._dio, {Dio? storage}) : _storage = storage ?? Dio();

  final Dio _dio;

  /// Plain client for the presigned PUT (no API base URL, no token).
  final Dio _storage;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  static Json _map(Object? data) =>
      data is Map ? Map<String, dynamic>.from(data) : throw ApiException(ApiErrorKind.unknown, l10nNow.errorGeneric);

  Future<List<Review>> mine() => _guard(() async {
        final res = await _dio.get<Object?>('/reviews/mine/');
        return mapList(res.data, Review.fromJson);
      });

  Future<Review> create({
    required int orderId,
    required int rating,
    required String text,
    String city = '',
    List<String> photoIds = const [],
  }) =>
      _guard(() async {
        final res = await _dio.post<Object?>('/reviews/', data: {
          'order_id': orderId,
          'rating': rating,
          'text': text,
          'city': city,
          'photo_ids': photoIds,
        });
        return Review.fromJson(_map(res.data));
      });

  /// Uploads an image as a `design` media: ticket → PUT to R2 → complete.
  Future<UploadedPhoto> uploadPhoto(Uint8List bytes, String contentType) => _guard(() async {
        final ticketRes = await _dio.post<Object?>('/media/uploads/', data: {
          'purpose': 'design',
          'content_type': contentType,
          'size_bytes': bytes.length,
        });
        final ticket = _map(ticketRes.data);
        final headers = ticket.obj('upload_headers');
        await _storage.put<Object?>(
          ticket.str('upload_url'),
          data: Stream.fromIterable([bytes]),
          options: Options(
            headers: {...headers, Headers.contentLengthHeader: bytes.length},
            contentType: contentType,
            extra: {kSkipAuth: true},
            responseType: ResponseType.plain,
          ),
        );
        final done = await _dio.post<Object?>('/media/${ticket.str('id')}/complete/');
        final media = _map(done.data);
        return UploadedPhoto(id: media.str('id'), url: media.str('url'));
      });
}

final reviewsApiProvider = Provider<ReviewsApi>((ref) => ReviewsApi(ref.watch(dioProvider)));

/// "Fikrlarim", newest first.
final myReviewsProvider = FutureProvider<List<Review>>((ref) async {
  final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  if (userId == null) return const [];
  return ref.read(reviewsApiProvider).mine();
});
