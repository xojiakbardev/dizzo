import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/responsive.dart';

/// Opens a rounded, drag-dismissible bottom sheet sized to its content,
/// with an optional [title] row and a close button. On tablets it stays
/// form-width instead of stretching edge to edge.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  bool isDismissible = true,
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    useRootNavigator: useRootNavigator,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => AppSheet(title: title, showClose: isDismissible, child: builder(context)),
  );
}

/// The body of a sheet: title row + content, padded above the keyboard.
class AppSheet extends StatelessWidget {
  const AppSheet({super.key, required this.child, this.title, this.showClose = true});

  final Widget child;
  final String? title;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final pad = context.pagePadding + 4;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, 0, pad, Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.lg),
                child: Row(
                  children: [
                    Expanded(child: Text(title!, style: context.text.titleLarge)),
                    if (showClose)
                      IconButton(
                        tooltip: context.l10n.commonClose,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// A yes/no question as a sheet. Title and buttons only.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final result = await showAppBottomSheet<bool>(
    context,
    title: title,
    builder: (context) => Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel ?? context.l10n.commonCancel),
          ),
        ),
        Gap.md,
        Expanded(
          child: FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: context.colors.danger)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
