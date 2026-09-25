import '../../../core/l10n/app_language.dart';
import '../../../core/utils/json.dart';

/// The signed-in customer (backend `UserOut`, `app/schemas/auth.py`).
class AppUser {
  const AppUser({
    required this.id,
    this.email,
    this.firstName = '',
    this.lastName = '',
    this.fullName = '',
    this.phoneNumber = '',
    this.avatar,
    this.role = 'customer',
    this.telegramLinked = false,
    this.language,
  });

  factory AppUser.fromJson(Json json) => AppUser(
        id: json.integer('id'),
        email: json.strOrNull('email'),
        firstName: json.str('first_name'),
        lastName: json.str('last_name'),
        fullName: json.str('full_name'),
        phoneNumber: json.str('phone_number'),
        avatar: json.strOrNull('avatar') ?? json.strOrNull('avatar_url'),
        role: json.str('role', 'customer'),
        telegramLinked: json.boolean('telegram_linked'),
        language: json.strOrNull('language'),
      );

  /// Used when tokens exist but the profile could not be loaded yet (offline
  /// first start); replaced by the real user on the next `/auth/me`.
  static const pending = AppUser(id: 0);

  final int id;
  final String? email;
  final String firstName;
  final String lastName;
  final String fullName;
  final String phoneNumber;

  /// Absolute URL (Google/Telegram photo) or null.
  final String? avatar;
  final String role;
  final bool telegramLinked;

  /// The profile's language ("uz" | "ru" | "en"); null if never set.
  final String? language;

  String get displayName {
    if (fullName.trim().isNotEmpty) return fullName.trim();
    final joined = '$firstName $lastName'.trim();
    if (joined.isNotEmpty) return joined;
    return email ?? l10nNow.commonCustomer;
  }

  String get initials {
    final parts = displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'D';
    String head(String s) => String.fromCharCode(s.runes.first);
    final second = parts.length > 1 ? head(parts[1]) : '';
    return (head(parts.first) + second).toUpperCase();
  }

  Json toJson() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'avatar': avatar,
        'role': role,
        'telegram_linked': telegramLinked,
        'language': language,
      };
}
