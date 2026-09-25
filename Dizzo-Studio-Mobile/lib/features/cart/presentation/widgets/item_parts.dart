import 'package:flutter/material.dart';

import '../../../../core/widgets/widgets.dart';
import '../../../catalog/domain/catalog_models.dart';
import '../../domain/cart_models.dart';
import 'mockup_gallery.dart';

/// A card with an item's pictures on the left and [child] beside them
/// (cart and order items).
class PackageItemCard extends StatelessWidget {
  const PackageItemCard({super.key, required this.images, required this.child, this.dimmed = false});

  final List<String> images;
  final Widget child;

  /// Items no longer on sale.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.brLg,
        border: Border.all(color: dimmed ? c.danger.withValues(alpha: 0.4) : c.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = (constraints.maxWidth * 0.36).clamp(96.0, 200.0);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: side,
                  height: side,
                  child: Opacity(
                    opacity: dimmed ? 0.5 : 1,
                    child: MockupGallery(images: images, borderRadius: Radii.brMd),
                  ),
                ),
                Gap.md,
                Expanded(child: child),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "Oq krujka · ● Qizil · XL"
class OptionsLine extends StatelessWidget {
  const OptionsLine({super.key, required this.variant, required this.colorName, this.color, this.size = ''});

  final String variant;
  final String colorName;
  final Color? color;
  final String size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.text.bodySmall?.copyWith(color: c.inkMuted);
    final parts = <InlineSpan>[
      if (variant.isNotEmpty) TextSpan(text: variant),
      if (colorName.isNotEmpty) ...[
        if (variant.isNotEmpty) const TextSpan(text: ' · '),
        if (color != null)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: c.line),
              ),
            ),
          ),
        TextSpan(text: colorName),
      ],
      if (size.isNotEmpty) TextSpan(text: ' · $size'),
    ];
    return Text.rich(
      TextSpan(children: parts),
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Small tags for the print methods ("Rangli bosma 48 cm²").
class PrintMethodTags extends StatelessWidget {
  const PrintMethodTags({super.key, required this.lines});

  final List<PrintLine> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final l in lines)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: c.plate, borderRadius: BorderRadius.circular(Radii.pill)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  l.method == PrintMethod.uv ? Icons.palette_outlined : Icons.bolt_rounded,
                  size: 13,
                  color: c.brand,
                ),
                const Gap(4),
                Flexible(
                  child: Text(
                    l.areaCm2 > 0
                        ? context.l10n.cartPrintArea(l.method.labelIn(context.l10n), _area(l.areaCm2))
                        : l.method.labelIn(context.l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(color: c.inkMuted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _area(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// Placeholder shaped like [PackageItemCard].
class PackageItemCardSkeleton extends StatelessWidget {
  const PackageItemCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.brLg,
        border: Border.all(color: c.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = (constraints.maxWidth * 0.36).clamp(96.0, 200.0);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: side, height: side, borderRadius: Radii.brMd),
                Gap.md,
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton.line(width: 140, height: 14),
                      Gap(8),
                      Skeleton.line(width: 110),
                      Gap(10),
                      Skeleton.line(width: 90, height: 18),
                      Gap(14),
                      Skeleton.line(width: 80, height: 16),
                      Gap(10),
                      Skeleton(width: 116, height: 40, borderRadius: Radii.brMd),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
