import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/widgets.dart';
import '../domain/auth_state.dart';
import 'auth_controller.dart';
import 'login_panel.dart';

/// Gate for account-only actions (add to cart, save a design, orders).
///
/// Returns true right away when signed in; otherwise opens the login sheet
/// and returns true once the user has signed in there, so the caller simply
/// continues:
///
/// ```dart
/// if (!await ensureSignedIn(context, ref)) return;
/// await cart.add(...);
/// ```
Future<bool> ensureSignedIn(BuildContext context, WidgetRef ref) async {
  if (ref.read(authControllerProvider).isAuthenticated) return true;
  final ok = await showLoginSheet(context);
  return ok && ref.read(authControllerProvider).isAuthenticated;
}

/// The sign-in sheet; resolves to true after a successful sign-in.
Future<bool> showLoginSheet(BuildContext context) async {
  final ok = await showAppBottomSheet<bool>(
    context,
    title: context.l10n.authSignInTitle,
    builder: (_) => const _LoginSheetBody(),
  );
  return ok ?? false;
}

class _LoginSheetBody extends ConsumerWidget {
  const _LoginSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next is Authenticated && prev is! Authenticated) {
        // Close this sheet (and the Telegram sheet above it, if open).
        final route = ModalRoute.of(context);
        final nav = Navigator.of(context);
        nav.popUntil((r) => r == route || r.isFirst);
        if (route != null && route.isCurrent) nav.pop(true);
      }
    });
    return const LoginPanel();
  }
}
