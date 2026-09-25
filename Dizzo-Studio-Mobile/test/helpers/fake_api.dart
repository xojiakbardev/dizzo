import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A canned HTTP response.
class FakeResponse {
  const FakeResponse(this.status, [this.body]);

  final int status;
  final Object? body;
}

/// A Dio adapter that answers from [handler] and records every request.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final Future<FakeResponse> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final r = await handler(options);
    return ResponseBody.fromString(
      r.body == null ? '' : jsonEncode(r.body),
      r.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Routes by "METHOD path" (path without the base URL and query).
FakeAdapter routedAdapter(Map<String, Object? Function(RequestOptions o)> routes) {
  return FakeAdapter((o) async {
    final key = '${o.method} ${o.uri.path.replaceFirst('/api', '')}';
    final route = routes[key];
    if (route == null) return const FakeResponse(404, {'detail': 'Topilmadi'});
    final result = route(o);
    return result is FakeResponse ? result : FakeResponse(200, result);
  });
}

Dio fakeDio(HttpClientAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://api.test/api'))..httpClientAdapter = adapter;
