import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../l10n/app_language.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

/// Session events raised by the network layer. The auth feature listens and
/// switches to guest mode; core never imports features.
enum SessionEvent { expired }

final sessionEventsProvider = Provider<StreamController<SessionEvent>>((ref) {
  final controller = StreamController<SessionEvent>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});

BaseOptions _options() => BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
      contentType: Headers.jsonContentType,
    );

/// The app's HTTP client. Paths are relative to `.../api` and keep the
/// backend's trailing slash: `dio.get('/catalog/products/')`.
///
/// Throws `DioException`; convert with `ApiException.from(e)` (repositories
/// do this, so screens only see `ApiException`).
/// Sends `Accept-Language: <current app language>` on every request (read
/// per request, so a language switch needs no new client).
class LanguageInterceptor extends Interceptor {
  const LanguageInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Accept-Language'] = AppLanguage.current.code;
    handler.next(options);
  }
}

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  final events = ref.watch(sessionEventsProvider);
  final dio = Dio(_options());
  final refreshDio = Dio(_options());
  // Content and error messages come back in the app's language.
  for (final d in [dio, refreshDio]) {
    d.interceptors.add(const LanguageInterceptor());
  }
  dio.interceptors.add(
    AuthInterceptor(
      storage: storage,
      refreshDio: refreshDio,
      retryDio: dio,
      onSessionExpired: () => events.add(SessionEvent.expired),
    ),
  );
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        responseHeader: false,
        responseBody: false,
        logPrint: (o) => debugPrint(o.toString()),
      ),
    );
  }
  ref.onDispose(() {
    dio.close();
    refreshDio.close();
  });
  return dio;
});
