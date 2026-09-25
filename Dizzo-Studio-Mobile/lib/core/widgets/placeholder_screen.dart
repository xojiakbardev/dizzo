import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import 'state_views.dart';

/// Stand-in for a screen another agent/feature will build. Keeps the route
/// alive and navigable. Search for `PlaceholderScreen(` to find them all.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.icon = Icons.construction_rounded,
    this.showAppBar = true,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final IconData icon;
  final bool showAppBar;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(title)) : null,
      body: SafeArea(
        child: EmptyState(
          icon: icon,
          title: showAppBar ? context.l10n.commonComingSoon : title,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
  }
}
