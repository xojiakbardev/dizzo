import 'package:dio/dio.dart';

import '../l10n/app_language.dart';

enum ApiErrorKind { network, timeout, unauthorized, forbidden, notFound, gone, conflict, validation, server, cancelled, unknown }

/// Every failed request reaches the UI as an [ApiException] with a message
/// that can be shown as is: app-made messages are in the current language,
/// and the backend writes `detail` in the `Accept-Language` it was sent.
class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.statusCode, this.data});

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;
  final Object? data;

  bool get isNetwork => kind == ApiErrorKind.network || kind == ApiErrorKind.timeout;

  static ApiException from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final inner = error.error;
      if (inner is ApiException) return inner;
      return _fromDio(error);
    }
    return ApiException(ApiErrorKind.unknown, l10nNow.errorGeneric);
  }

  static ApiException _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(ApiErrorKind.timeout, l10nNow.errorTimeout);
      case DioExceptionType.connectionError:
        return ApiException(ApiErrorKind.network, l10nNow.errorNoInternet);
      case DioExceptionType.cancel:
        return ApiException(ApiErrorKind.cancelled, l10nNow.errorCancelled);
      case DioExceptionType.badCertificate:
        return ApiException(ApiErrorKind.network, l10nNow.errorInsecure);
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }
    final response = e.response;
    final code = response?.statusCode;
    if (response == null || code == null) {
      return ApiException(ApiErrorKind.network, l10nNow.errorNoInternet);
    }
    final detail = detailMessage(response.data);
    final kind = switch (code) {
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      410 => ApiErrorKind.gone,
      400 || 422 => ApiErrorKind.validation,
      >= 500 => ApiErrorKind.server,
      _ => ApiErrorKind.unknown,
    };
    final l = l10nNow;
    final fallback = switch (kind) {
      ApiErrorKind.unauthorized => l.errorSignInAgain,
      ApiErrorKind.forbidden => l.errorForbidden,
      ApiErrorKind.notFound => l.errorNotFound,
      ApiErrorKind.server => l.errorServer,
      _ => l.errorGeneric,
    };
    return ApiException(kind, detail ?? fallback, statusCode: code, data: response.data);
  }

  /// FastAPI errors: `{"detail": "text"}` or, for validation,
  /// `{"detail": [{"loc": [...], "msg": "text"}]}`.
  static String? detailMessage(Object? data) {
    if (data is! Map) return null;
    final detail = data['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] is String) return first['msg'] as String;
    }
    if (detail is Map && detail['message'] is String) return detail['message'] as String;
    return null;
  }

  /// Field errors of a 422, keyed by the last `loc` element.
  Map<String, String> get fieldErrors {
    final d = data;
    if (d is! Map || d['detail'] is! List) return const {};
    final out = <String, String>{};
    for (final e in d['detail'] as List) {
      if (e is Map && e['loc'] is List && (e['loc'] as List).isNotEmpty) {
        out[(e['loc'] as List).last.toString()] = (e['msg'] ?? '').toString();
      }
    }
    return out;
  }

  @override
  String toString() => 'ApiException($kind, $statusCode): $message';
}
