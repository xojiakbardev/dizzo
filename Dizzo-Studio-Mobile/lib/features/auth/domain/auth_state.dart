import 'app_user.dart';

/// Where the session stands. Read with `ref.watch(authControllerProvider)`.
sealed class AuthState {
  const AuthState();

  AppUser? get user => switch (this) {
        Authenticated(:final user) => user,
        _ => null,
      };

  bool get isAuthenticated => this is Authenticated;
  bool get isResolved => this is! AuthUnknown;
}

/// App start: tokens are being read from storage.
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

/// Browsing without an account (catalog, product pages, the editor preview).
class Guest extends AuthState {
  const Guest();
}

class Authenticated extends AuthState {
  const Authenticated(this.user);

  @override
  final AppUser user;
}
