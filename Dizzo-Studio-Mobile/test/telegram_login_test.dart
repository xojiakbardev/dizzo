import 'package:dio/dio.dart';
import 'package:dizzo/core/network/api_client.dart';
import 'package:dizzo/core/storage/token_storage.dart';
import 'package:dizzo/core/theme/app_theme.dart';
import 'package:dizzo/features/auth/data/google_auth.dart';
import 'package:dizzo/features/auth/data/telegram_native_login.dart';
import 'package:dizzo/features/auth/presentation/auth_controller.dart';
import 'package:dizzo/features/auth/presentation/login_panel.dart';
import 'package:dizzo/features/auth/presentation/telegram_login_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'helpers/account_harness.dart';
import 'helpers/fake_api.dart';
import 'helpers/l10n.dart';

const _channel = MethodChannel('test/telegram_login');
const _redirect = 'https://app42-login.tg.dev/tglogin';
const _idToken = 'eyJhbGciOiJSUzI1NiJ9.telegram.token';

final _authBody = {
  'access_token': 'a1',
  'refresh_token': 'r1',
  'token_type': 'bearer',
  'user': testUser,
};

/// Answers the native plugin's calls; [login] decides what `login` does.
List<MethodCall> _fakeNative(Future<Object?> Function() login) {
  final calls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
    calls.add(call);
    return switch (call.method) {
      'login' => login(),
      _ => null,
    };
  });
  addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, null));
  return calls;
}

TelegramNativeLogin _native({String redirectUri = _redirect, bool platformSupported = true}) => TelegramNativeLogin(
      channel: _channel,
      clientId: '8249953132',
      redirectUri: redirectUri,
      platformSupported: platformSupported,
    );

class _FakeGoogle extends GoogleAuth {
  _FakeGoogle(this.available);
  final bool available;
  @override
  bool get isAvailable => available;
}

class _Harness {
  _Harness(this.container, this.backend, this.storage);
  final ProviderContainer container;
  final FakeAdapter backend;
  final MemoryTokenStorage storage;
  bool? result;

  List<String> get paths => [for (final r in backend.requests) '${r.method} ${r.uri.path}'];
}

Future<_Harness> _pumpSheet(
  WidgetTester tester, {
  required TelegramNativeLogin native,
  required FakeAdapter backend,
}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final storage = MemoryTokenStorage();
  final container = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      dioProvider.overrideWithValue(fakeDio(backend)),
      telegramNativeLoginProvider.overrideWithValue(native),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  final h = _Harness(container, backend, storage);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: testLocale,
      localizationsDelegates: l10nDelegates,
      supportedLocales: l10nLocales,
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => h.result = await showTelegramLogin(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await settle(tester);
  return h;
}

FakeAdapter _backend({FakeResponse? oidc}) => routedAdapter({
      'POST /auth/oauth/telegram-oidc/': (_) => oidc ?? _authBody,
      'GET /auth/me': (_) => testUser,
    });

void main() {
  group('TelegramNativeLogin', () {
    test('is unavailable without a redirect uri or off Android/iOS', () {
      expect(_native().isAvailable, isTrue);
      expect(_native(redirectUri: '').isAvailable, isFalse);
      expect(_native(platformSupported: false).isAvailable, isFalse);
      expect(
        () => _native(redirectUri: '').signIn(),
        throwsA(isA<TelegramNativeError>().having((e) => e.code, 'code', 'not_configured')),
      );
    });

    test('initialises once, then returns the id token', () async {
      final calls = _fakeNative(() async => _idToken);
      final native = _native();
      expect(await native.signIn(), _idToken);
      expect(await native.signIn(), _idToken);
      expect(calls.map((c) => c.method), ['init', 'login', 'login']);
      expect(calls.first.arguments, {
        'clientId': '8249953132',
        'redirectUri': _redirect,
        'scopes': ['openid', 'profile', 'phone'],
      });
    });

    test('null or empty token means cancelled', () async {
      _fakeNative(() async => '');
      expect(await _native().signIn(), isNull);
    });

    test('platform errors become TelegramNativeError', () async {
      _fakeNative(() async => throw PlatformException(code: 'failed', message: 'HTTP 400'));
      await expectLater(
        _native().signIn(),
        throwsA(isA<TelegramNativeError>()
            .having((e) => e.code, 'code', 'failed')
            .having((e) => e.message, 'message', 'HTTP 400')),
      );
    });

    test('a missing plugin is "unavailable"', () async {
      final native = TelegramNativeLogin(
        channel: const MethodChannel('test/not_registered'),
        clientId: '1',
        redirectUri: _redirect,
        platformSupported: true,
      );
      await expectLater(
        native.signIn(),
        throwsA(isA<TelegramNativeError>().having((e) => e.code, 'code', 'unavailable')),
      );
    });
  });

  group('Telegram login sheet', () {
    testWidgets('native: the id token is exchanged at /auth/oauth/telegram-oidc/', (tester) async {
      _fakeNative(() async => _idToken);
      final backend = _backend();
      final h = await _pumpSheet(tester, native: _native(), backend: backend);

      expect(h.result, isTrue);
      expect(find.byType(TelegramLoginSheet), findsNothing);
      final oidc = backend.requests.singleWhere((r) => r.uri.path.endsWith('/auth/oauth/telegram-oidc/'));
      expect(oidc.data, {'id_token': _idToken});
      expect(h.paths.any((p) => p.contains('app-login')), isFalse);
      expect(h.storage.pair?.access, 'a1');
      expect(h.container.read(currentUserProvider)?.firstName, 'Ali');
    });

    testWidgets('native: waits for Telegram, cancel closes the sheet', (tester) async {
      final calls = _fakeNative(() => Future<Object?>.delayed(const Duration(days: 1)));
      final h = await _pumpSheet(tester, native: _native(), backend: _backend());

      expect(find.text('Telegramda tasdiqlang'), findsOneWidget);
      expect(find.text('Qayta ochish'), findsOneWidget);
      await tester.tap(find.text('Bekor qilish'));
      await settle(tester);

      expect(h.result, isFalse);
      expect(calls.map((c) => c.method), contains('cancel'));
      expect(h.backend.requests, isEmpty);
      await tester.pump(const Duration(days: 1));
    });

    testWidgets('native: the user cancelling in Telegram closes the sheet', (tester) async {
      _fakeNative(() async => null);
      final h = await _pumpSheet(tester, native: _native(), backend: _backend());
      expect(h.result, isFalse);
      expect(h.backend.requests, isEmpty);
    });

    testWidgets('a native failure shows the error and a retry that works', (tester) async {
      var attempts = 0;
      _fakeNative(() async {
        attempts++;
        if (attempts == 1) throw PlatformException(code: 'failed', message: 'HTTP 400');
        return _idToken;
      });
      final h = await _pumpSheet(tester, native: _native(), backend: _backend());

      expect(find.text('Telegram orqali kirib bo‘lmadi'), findsOneWidget);
      expect(find.text('Qayta urinish'), findsOneWidget);
      expect(h.backend.requests, isEmpty);

      await tester.tap(find.text('Qayta urinish'));
      await settle(tester);
      expect(attempts, 2);
      expect(h.result, isTrue);
      expect(h.paths, ['POST /api/auth/oauth/telegram-oidc/']);
    });

    testWidgets('the backend rejecting the token is a failure', (tester) async {
      _fakeNative(() async => _idToken);
      final backend = _backend(
        oidc: const FakeResponse(401, {'detail': 'Telegram token yaroqsiz yoki bot sozlanmagan'}),
      );
      final h = await _pumpSheet(tester, native: _native(), backend: backend);

      expect(find.text('Telegram orqali kirib bo‘lmadi'), findsOneWidget);
      expect(find.text('Qayta urinish'), findsOneWidget);
      expect(h.result, isNull);
      expect(h.storage.pair, isNull);
    });

    testWidgets('offline while verifying says so', (tester) async {
      _fakeNative(() async => _idToken);
      final backend = FakeAdapter((o) async => throw DioException.connectionError(
            requestOptions: o,
            reason: 'offline',
          ));
      await _pumpSheet(tester, native: _native(), backend: backend);
      expect(find.text('Internet aloqasi yo‘q'), findsOneWidget);
    });

    testWidgets('not configured: an error, no plugin call and no bot login', (tester) async {
      final calls = _fakeNative(() async => _idToken);
      final h = await _pumpSheet(tester, native: _native(redirectUri: ''), backend: _backend());

      expect(calls, isEmpty);
      expect(h.backend.requests, isEmpty);
      expect(find.text('Telegram orqali kirib bo‘lmadi'), findsOneWidget);
      await tester.tap(find.text('Bekor qilish'));
      await settle(tester);
      expect(h.result, isFalse);
    });
  });

  group('Google', () {
    test('errors map to Uzbek messages; cancel is null', () {
      GoogleSignInException e(GoogleSignInExceptionCode code, [String? d]) =>
          GoogleSignInException(code: code, description: d);
      expect(googleSignInError(e(GoogleSignInExceptionCode.canceled)), isNull);
      expect(googleSignInError(e(GoogleSignInExceptionCode.interrupted)), isNull);
      expect(googleSignInError(e(GoogleSignInExceptionCode.clientConfigurationError))?.message,
          'Google orqali kirish hali sozlanmagan');
      expect(googleSignInError(e(GoogleSignInExceptionCode.unknownError, '[28444] Developer console is not set up'))
          ?.message, 'Google orqali kirish hali sozlanmagan');
      expect(googleSignInError(e(GoogleSignInExceptionCode.unknownError, 'A network error occurred'))?.message,
          'Internet aloqasi yo‘q');
      expect(googleSignInError(e(GoogleSignInExceptionCode.unknownError, 'No credential available: x'))?.message,
          'Qurilmada Google hisobi topilmadi');
      expect(googleSignInError(e(GoogleSignInExceptionCode.uiUnavailable))?.message, 'Google oynasini ochib bo‘lmadi');
      expect(googleSignInError(e(GoogleSignInExceptionCode.unknownError, 'boom'))?.message,
          'Google orqali kirib bo‘lmadi');
    });

    for (final available in [true, false]) {
      testWidgets('the Google button is ${available ? 'shown' : 'hidden'} when ${available ? '' : 'not '}configured',
          (tester) async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
            dioProvider.overrideWithValue(fakeDio(_backend())),
            googleAuthProvider.overrideWithValue(_FakeGoogle(available)),
          ],
          retry: (_, _) => null,
          child: MaterialApp(
            locale: testLocale,
            localizationsDelegates: l10nDelegates,
            supportedLocales: l10nLocales,
            theme: AppTheme.light, home: const Scaffold(body: LoginPanel())),
        ));
        await settle(tester);
        expect(find.text('Google orqali kirish'), available ? findsOneWidget : findsNothing);
        expect(find.text('Telegram orqali kirish'), findsOneWidget);
      });
    }
  });
}
