import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json.dart';
import '../../auth/domain/app_user.dart';

/// The profile as `/users/profile/me/` returns it.
class ProfileData {
  const ProfileData(this.user, {this.telegramLinkedAt});

  factory ProfileData.fromJson(Json json) =>
      ProfileData(AppUser.fromJson(json), telegramLinkedAt: json.strOrNull('telegram_linked_at'));

  final AppUser user;
  final String? telegramLinkedAt;
}

/// A one-time Telegram link (`POST /auth/telegram/link-token/`).
class TelegramLinkTicket {
  const TelegramLinkTicket({required this.deepLink, required this.expiresIn});

  /// `https://t.me/<bot>?start=link_<token>`; null when the bot isn't set up.
  final String? deepLink;
  final Duration expiresIn;
}

class ProfileApi {
  ProfileApi(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  static Json _map(Object? data) =>
      data is Map ? Map<String, dynamic>.from(data) : throw ApiException(ApiErrorKind.unknown, l10nNow.errorGeneric);

  Future<ProfileData> me() => _guard(() async {
        final res = await _dio.get<Object?>('/users/profile/me/');
        return ProfileData.fromJson(_map(res.data));
      });

  Future<ProfileData> update({required String firstName, required String lastName, required String phoneNumber}) =>
      _guard(() async {
        final res = await _dio.patch<Object?>('/users/profile/me/', data: {
          'first_name': firstName,
          'last_name': lastName,
          'phone_number': phoneNumber,
        });
        return ProfileData.fromJson(_map(res.data));
      });

  Future<TelegramLinkTicket> telegramLinkToken() => _guard(() async {
        final res = await _dio.post<Object?>('/auth/telegram/link-token/');
        final json = _map(res.data);
        return TelegramLinkTicket(
          deepLink: json.strOrNull('deep_link'),
          expiresIn: Duration(seconds: json.integer('expires_in_seconds', 60)),
        );
      });
}

final profileApiProvider = Provider<ProfileApi>((ref) => ProfileApi(ref.watch(dioProvider)));

/// "1.2.0 (5)"; null if the platform can't tell (tests).
final appVersionProvider = FutureProvider<String?>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.buildNumber.isEmpty ? info.version : '${info.version} (${info.buildNumber})';
  } catch (_) {
    return null;
  }
});
