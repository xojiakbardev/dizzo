import 'package:dio/dio.dart';
import 'package:dizzo/core/network/api_exception.dart';
import 'package:dizzo/core/network/auth_interceptor.dart';
import 'package:dizzo/core/storage/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_api.dart';

void main() {
  late MemoryTokenStorage storage;
  late int expiredCalls;

  /// A client whose server accepts only access token "fresh" and refreshes
  /// "r1" → ("fresh", "r2"); [refreshStatus] overrides the refresh result.
  ({Dio dio, FakeAdapter api, FakeAdapter refresh}) build({int refreshStatus = 200}) {
    final api = FakeAdapter((o) async {
      final auth = o.headers['Authorization'];
      if (o.path == '/public') return const FakeResponse(200, {'ok': true});
      return auth == 'Bearer fresh'
          ? const FakeResponse(200, {'ok': true})
          : const FakeResponse(401, {'detail': 'Token yaroqsiz'});
    });
    final refresh = FakeAdapter((o) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (refreshStatus != 200) {
        return FakeResponse(refreshStatus, const {'detail': 'Refresh token yaroqsiz'});
      }
      expect((o.data as Map)['refresh_token'], 'r1');
      return const FakeResponse(200, {'access_token': 'fresh', 'refresh_token': 'r2', 'token_type': 'bearer'});
    });
    final dio = fakeDio(api);
    dio.interceptors.add(AuthInterceptor(
      storage: storage,
      refreshDio: fakeDio(refresh),
      retryDio: dio,
      onSessionExpired: () => expiredCalls++,
    ));
    return (dio: dio, api: api, refresh: refresh);
  }

  setUp(() {
    storage = MemoryTokenStorage(const TokenPair(access: 'stale', refresh: 'r1'));
    expiredCalls = 0;
  });

  test('adds the bearer token', () async {
    storage.pair = const TokenPair(access: 'fresh', refresh: 'r1');
    final c = build();
    await c.dio.get<Object?>('/me');
    expect(c.api.requests.single.headers['Authorization'], 'Bearer fresh');
  });

  test('skipAuth requests carry no token', () async {
    final c = build();
    await c.dio.get<Object?>('/public', options: Options(extra: {kSkipAuth: true}));
    expect(c.api.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('refreshes once on 401 and replays the request', () async {
    final c = build();
    final res = await c.dio.get<Object?>('/me');
    expect(res.statusCode, 200);
    expect(storage.pair?.access, 'fresh');
    expect(storage.pair?.refresh, 'r2');
    expect(c.refresh.requests, hasLength(1));
    expect(c.api.requests, hasLength(2));
  });

  test('concurrent 401s share a single refresh', () async {
    final c = build();
    final results = await Future.wait([
      c.dio.get<Object?>('/a'),
      c.dio.get<Object?>('/b'),
      c.dio.get<Object?>('/c'),
    ]);
    expect(results.every((r) => r.statusCode == 200), isTrue);
    expect(c.refresh.requests, hasLength(1));
  });

  test('a rejected refresh clears the tokens and signals expiry', () async {
    final c = build(refreshStatus: 401);
    await expectLater(
      c.dio.get<Object?>('/me'),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 401)),
    );
    expect(storage.pair, isNull);
    expect(expiredCalls, 1);
  });

  test('a failing refresh server keeps the session', () async {
    final c = build(refreshStatus: 503);
    await expectLater(c.dio.get<Object?>('/me'), throwsA(isA<DioException>()));
    expect(storage.pair?.refresh, 'r1');
    expect(expiredCalls, 0);
  });

  test('ApiException reads FastAPI detail messages', () {
    final validation = ApiException.from(DioException(
      requestOptions: RequestOptions(),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(),
        statusCode: 422,
        data: {
          'detail': [
            {'loc': ['body', 'email'], 'msg': 'Email noto‘g‘ri', 'type': 'value_error'},
          ],
        },
      ),
    ));
    expect(validation.kind, ApiErrorKind.validation);
    expect(validation.message, 'Email noto‘g‘ri');
    expect(validation.fieldErrors, {'email': 'Email noto‘g‘ri'});

    final offline = ApiException.from(DioException(
      requestOptions: RequestOptions(),
      type: DioExceptionType.connectionError,
    ));
    expect(offline.isNetwork, isTrue);
  });
}
