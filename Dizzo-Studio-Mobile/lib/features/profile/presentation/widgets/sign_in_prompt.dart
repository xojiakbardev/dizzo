import 'package:flutter/material.dart';

import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/require_auth.dart';

/// What guests see on account pages: a title and "Kirish" (the login sheet).
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: icon,
      title: title,
      actionLabel: context.l10n.authSignIn,
      onAction: () => showLoginSheet(context),
    );
  }
}
