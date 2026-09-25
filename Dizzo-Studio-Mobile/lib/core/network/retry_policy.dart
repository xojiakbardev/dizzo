import 'api_exception.dart';

/// Riverpod's automatic provider retry (`ProviderScope(retry: ...)`):
/// only transient failures (offline, timeout, 5xx) are retried, up to three
/// times with 1 s, 2 s, 4 s pauses. A 404 or 422 fails at once.
Duration? providerRetry(int retryCount, Object error) {
  if (retryCount >= 3) return null;
  final e = ApiException.from(error);
  final transient = e.isNetwork || e.kind == ApiErrorKind.server;
  if (!transient) return null;
  return Duration(seconds: 1 << retryCount);
}
