import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../network/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_buttons.dart';

/// Empty state: an icon, a title and (optionally) one action. By design
/// there is no description line.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Inline use inside a scroll view (smaller, no vertical centring).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = Padding(
      padding: const EdgeInsets.all(Insets.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 64 : 88,
            height: compact ? 64 : 88,
            decoration: BoxDecoration(color: c.plate, shape: BoxShape.circle),
            child: Icon(icon, size: compact ? 28 : 38, color: c.brand),
          ),
          Gap.lg,
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleMedium,
          ),
          if (actionLabel != null && onAction != null) ...[
            Gap.lg,
            AppButton(label: actionLabel!, onPressed: onAction, expand: false),
          ],
        ],
      ),
    );
    return compact ? content : Center(child: SingleChildScrollView(child: content));
  }
}

/// Error state: the error's message as the title and a retry action.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final e = ApiException.from(error);
    return EmptyState(
      compact: compact,
      icon: e.isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: e.message,
      actionLabel: onRetry == null ? null : context.l10n.commonRetry,
      onAction: onRetry,
    );
  }
}

/// A short message at the bottom of the screen.
void showAppSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? context.colors.danger : null,
      ),
    );
}
