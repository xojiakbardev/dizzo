import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// A shimmering grey block. Wrap a whole skeleton layout in one
/// [SkeletonScope] when possible (one shimmer for the group looks calmer);
/// a bare [Skeleton] shimmers by itself.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, this.height, this.borderRadius = Radii.brSm});

  /// A text line placeholder.
  const Skeleton.line({super.key, this.width, this.height = 12})
      : borderRadius = const BorderRadius.all(Radius.circular(6));

  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final block = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: c.skeletonBase, borderRadius: borderRadius),
    );
    if (SkeletonScope.maybeOf(context)) return block;
    return Shimmer.fromColors(
      baseColor: c.skeletonBase,
      highlightColor: c.skeletonHighlight,
      child: block,
    );
  }
}

class SkeletonScope extends StatelessWidget {
  const SkeletonScope({super.key, required this.child});

  final Widget child;

  static bool maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SkeletonMarker>() != null;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Shimmer.fromColors(
      baseColor: c.skeletonBase,
      highlightColor: c.skeletonHighlight,
      child: _SkeletonMarker(child: child),
    );
  }
}

class _SkeletonMarker extends InheritedWidget {
  const _SkeletonMarker({required super.child});

  @override
  bool updateShouldNotify(_SkeletonMarker oldWidget) => false;
}

/// Placeholder matching [ProductCard].
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(aspectRatio: 1, child: Skeleton(borderRadius: Radii.brLg)),
        Gap(10),
        Skeleton.line(width: 110, height: 13),
        Gap(8),
        Skeleton.line(width: 72, height: 13),
      ],
    );
  }
}
