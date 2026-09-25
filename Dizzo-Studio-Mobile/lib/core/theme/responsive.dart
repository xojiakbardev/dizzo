import 'package:flutter/widgets.dart';

import 'app_tokens.dart';

/// Material 3 window size classes.
enum WindowSize {
  /// Phones in portrait (< 600).
  compact,

  /// Large phones in landscape, small tablets, foldables (600–839).
  medium,

  /// Tablets and up (>= 840).
  expanded;

  static WindowSize of(double width) {
    if (width >= Breakpoints.expanded) return WindowSize.expanded;
    if (width >= Breakpoints.medium) return WindowSize.medium;
    return WindowSize.compact;
  }
}

abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;

  /// Page content never grows wider than this (tablets, landscape).
  static const double contentMaxWidth = 1100;

  /// Forms and single-column reading content.
  static const double formMaxWidth = 480;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  WindowSize get windowSize => WindowSize.of(screenWidth);
  bool get isCompact => windowSize == WindowSize.compact;
  bool get isExpanded => windowSize == WindowSize.expanded;

  /// Horizontal page padding: 16 on phones, 24 on tablets. Screens under
  /// 360 px (small Androids) get 12.
  double get pagePadding {
    final w = screenWidth;
    if (w < 360) return Insets.md;
    if (w < Breakpoints.medium) return Insets.lg;
    return Insets.xl;
  }

  /// Columns for a product grid at [width] (the space actually available).
  static int productColumnsFor(double width) {
    if (width >= 1000) return 5;
    if (width >= 760) return 4;
    if (width >= 520) return 3;
    return 2;
  }
}

/// Centers [child] and caps its width at [maxWidth]; on phones it is a no-op.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Sliver version of [ContentWidth] plus the page's horizontal padding.
class SliverPageBody extends StatelessWidget {
  const SliverPageBody({super.key, required this.sliver, this.padTop = 0, this.padBottom = 0});

  final Widget sliver;
  final double padTop;
  final double padBottom;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final side = width > Breakpoints.contentMaxWidth
            ? (width - Breakpoints.contentMaxWidth) / 2
            : context.pagePadding;
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(side, padTop, side, padBottom),
          sliver: sliver,
        );
      },
    );
  }
}
