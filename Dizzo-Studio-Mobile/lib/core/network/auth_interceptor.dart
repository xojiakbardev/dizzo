import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Request option: `Options(extra: {kSkipAuth: true})` sends no token and
/// never triggers a refresh (login, register, the refresh call itself).
const kSkipAuth = 'dizzo.skipAuth';
const _kRetried = 'dizzo.retried';

/// Adds `Authorization: Bearer <access>` and, on a 401, refreshes the pair
/// once (concurrent 401s share one refresh) and replays the request.
///
/// If the refresh is rejected by the server, tokens are cleared and
/// [onSessionExpired] runs (the auth controller turns the app into guest
/// mode). A network failure during refresh keeps the tokens.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.storage,
    required this.refreshDio,
    required this.retryDio,
    required this.onSessionExpired,
  });

  final TokenStorage storage;

  /// A bare Dio (no interceptors) with the same base URL.
  final Dio refreshDio;

  /// The Dio used to replay requests: normally the main client.
  final Dio retryDio;
  final void Function() onSessionExpired;

  Future<TokenPair?>? _refreshing;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[kSkipAuth] != true) {
      final pair = await storage.read();
      if (pair != null) {
        options.headers['Authorization'] = 'Bearer ${pair.access}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final sentHeader = options.headers['Authorization'];
    final shouldRefresh = err.response?.statusCode == 401 &&
        options.extra[kSkipAuth] != true &&
        options.extra[_kRetried] != true &&
        sentHeader is String;
    if (!shouldRefresh) return handler.next(err);

    final sentToken = sentHeader.substring('Bearer '.length);
    final TokenPair? pair;
    try {
      pair = await _freshPair(sentToken);
    } catch (_) {
      return handler.next(err);
    }
    if (pair == null) return handler.next(err);

    options.headers['Authorization'] = 'Bearer ${pair.access}';
    options.extra[_kRetried] = true;
    try {
      handler.resolve(await retryDio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// A pair newer than [sentToken]: one another request already obtained,
  /// the result of a refresh in flight, or a new refresh.
  Future<TokenPair?> _freshPair(String sentToken) async {
    final current = await storage.read();
    if (current == null) return null;
    if (current.access != sentToken) return current;
    return _refreshing ??= _refresh(current.refresh).whenComplete(() => _refreshing = null);
  }

  Future<TokenPair?> _refresh(String refreshToken) async {
    try {
      final res = await refreshDio.post<Map<String, dynamic>>(
        '/auth/token/refresh/',
        data: {'refresh_token': refreshToken},
        options: Options(extra: {kSkipAuth: true}),
      );
      final pair = res.data == null ? null : TokenPair.fromJson(res.data!);
      if (pair == null) throw StateError('Bad refresh response');
      await storage.write(pair);
      return pair;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code != null && code >= 400 && code < 500) {
        await storage.clear();
        onSessionExpired();
        return null;
      }
      rethrow; // offline or 5xx: keep the session
    }
  }
}
