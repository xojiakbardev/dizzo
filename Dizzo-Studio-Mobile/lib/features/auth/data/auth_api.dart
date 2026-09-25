import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/json.dart';
import '../domain/app_user.dart';

/// Tokens + user, as every sign-in endpoint returns them.
class AuthResult {
  const AuthResult(this.tokens, this.user);

  final TokenPair tokens;
  final AppUser user;

  static AuthResult parse(Object? data) {
    if (data is! Map) throw ApiException(ApiErrorKind.unknown, l10nNow.authSignInFailed);
    final json = Map<String, dynamic>.from(data);
    final pair = TokenPair.fromJson(json);
    if (pair == null) throw ApiException(ApiErrorKind.unknown, l10nNow.authSignInFailed);
    return AuthResult(pair, AppUser.fromJson(json.obj('user')));
  }
}

/// Backend `/auth/*` endpoints (see `Dizzo-Backend/app/api/v1/auth.py`).
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  static final _public = Options(extra: {kSkipAuth: true});

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<AuthResult> login({required String email, required String password}) => _guard(() async {
        final res = await _dio.post<Object?>(
          '/auth/login/',
          data: {'email': email, 'password': password},
          options: _public,
        );
        return AuthResult.parse(res.data);
      });

  Future<AuthResult> register({
    required String firstName,
    String lastName = '',
    String phoneNumber = '',
    required String email,
    required String password,
  }) =>
      _guard(() async {
        final res = await _dio.post<Object?>(
          '/auth/register/',
          data: {
            'first_name': firstName,
            'last_name': lastName,
            'phone_number': phoneNumber,
            'email': email,
            'password': password,
          },
          options: _public,
        );
        return AuthResult.parse(res.data);
      });

  Future<AuthResult> google(String idToken) => _guard(() async {
        final res = await _dio.post<Object?>(
          '/auth/oauth/google/',
          data: {'id_token': idToken},
          options: _public,
        );
        return AuthResult.parse(res.data);
      });

  /// The id token from the native Telegram login SDK.
  Future<AuthResult> telegramOidc(String idToken) => _guard(() async {
        final res = await _dio.post<Object?>(
          '/auth/oauth/telegram-oidc/',
          data: {'id_token': idToken},
          options: _public,
        );
        return AuthResult.parse(res.data);
      });

  Future<AppUser> me() => _guard(() async {
        final res = await _dio.get<Object?>('/auth/me');
        return AppUser.fromJson(Map<String, dynamic>.from(res.data! as Map));
      });

  /// Saves the profile language (`PATCH /users/profile/me/`).
  Future<AppUser> setLanguage(String code) => _guard(() async {
        final res = await _dio.patch<Object?>('/users/profile/me/', data: {'language': code});
        return AppUser.fromJson(Map<String, dynamic>.from(res.data! as Map));
      });

  /// Deletes the account (`DELETE /users/profile/me/`, 204). The server
  /// anonymizes it and revokes every token. 409: an order is still in
  /// progress; 403: staff accounts. Both come with a localized `detail`.
  Future<void> deleteAccount() => _guard(() async {
        await _dio.delete<Object?>('/users/profile/me/');
      });

  /// Server-side logout (clears cookies on the web). Failures are ignored:
  /// the tokens are dropped locally either way.
  Future<void> logout({String? refreshToken}) async {
    try {
      await _dio.post<Object?>(
        '/auth/logout/',
        data: {'refresh_token': ?refreshToken},
        options: Options(sendTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)),
      );
    } catch (_) {}
  }
}

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(dioProvider)));
