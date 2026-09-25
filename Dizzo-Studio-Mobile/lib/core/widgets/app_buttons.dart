import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

enum AppButtonVariant { primary, secondary, outline, ghost }

/// The app's button. Full width by default (mobile forms and bottom bars),
/// with a built-in busy state that keeps its size.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = true,
    this.size = 52,
  });

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.size = 52,
  }) : variant = AppButtonVariant.outline;

  final String label;
  final VoidCallback? onPressed;

  /// A leading widget: an [Icon] or a brand logo.
  final Widget? icon;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = switch (variant) {
      AppButtonVariant.primary => Colors.white,
      AppButtonVariant.secondary => Colors.white,
      AppButtonVariant.outline => c.ink,
      AppButtonVariant.ghost => c.brandStrong,
    };
    final child = AnimatedSwitcher(
      duration: Motion.fast,
      child: loading
          ? SizedBox(
              key: const ValueKey('busy'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  IconTheme.merge(data: IconThemeData(size: 20, color: fg), child: icon!),
                  const Gap(10),
                ],
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
    final minSize = Size(expand ? double.infinity : 64, size);
    final onTap = loading ? null : onPressed;
    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(minimumSize: minSize),
          child: child,
        ),
      AppButtonVariant.secondary => FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(minimumSize: minSize, backgroundColor: c.ink),
          child: child,
        ),
      AppButtonVariant.outline => OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(minimumSize: minSize, backgroundColor: c.surface),
          child: child,
        ),
      AppButtonVariant.ghost => TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(minimumSize: minSize),
          child: child,
        ),
    };
    return Semantics(button: true, enabled: onTap != null, child: button);
  }
}

/// A round icon button on a surface (over images, in app bars).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface.withValues(alpha: 0.92),
      shape: CircleBorder(side: BorderSide(color: c.line)),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: c.ink),
        constraints: BoxConstraints.tightFor(width: size, height: size),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
