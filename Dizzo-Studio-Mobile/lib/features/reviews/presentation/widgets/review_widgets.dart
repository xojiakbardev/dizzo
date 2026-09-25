import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/widgets.dart';
import '../../../cart/presentation/widgets/mockup_gallery.dart';
import '../../../orders/presentation/widgets/status_chip.dart';
import '../../domain/review.dart';

/// Five stars; tappable when [onChanged] is set.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, this.size = 18, this.onChanged});

  final int value;
  final double size;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: context.l10n.reviewsRatingLabel(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            onChanged == null
                ? Icon(i <= value ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: c.accent)
                : IconButton(
                    tooltip: '$i',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onChanged!(i);
                    },
                    icon: Icon(
                      i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: size,
                      color: c.accent,
                    ),
                  ),
        ],
      ),
    );
  }
}

/// A review: product, stars, status, text and photos.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review, this.showProduct = true, this.onOpenOrder});

  final Review review;
  final bool showProduct;

  /// Opens the review's order ("Buyurtma №…").
  final VoidCallback? onOpenOrder;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = review.statusMeta(context.l10n);
    final muted = context.text.bodySmall?.copyWith(color: c.inkMuted);
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(color: c.surface, borderRadius: Radii.brLg, border: Border.all(color: c.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showProduct && review.productName.isNotEmpty)
                      Text(review.productName, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    StarRating(value: review.rating),
                  ],
                ),
              ),
              Gap.sm,
              Flexible(child: StatusChip(label: meta.label, tone: meta.tone, dense: true)),
            ],
          ),
          if (review.text.isNotEmpty) ...[
            Gap.sm,
            Text(review.text, style: context.text.bodyMedium),
          ],
          if (review.photos.isNotEmpty) ...[
            Gap.md,
            MockupStrip(images: review.photos, size: 64),
          ],
          Gap.md,
          Row(
            children: [
              if (review.createdAt != null)
                Expanded(child: Text(AppDates.date(review.createdAt!, context.l10n.localeName), style: muted, maxLines: 1)),
              if (review.createdAt == null) const Spacer(),
              if (onOpenOrder != null && review.orderNumber != null)
                TextButton(
                  onPressed: onOpenOrder,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                  ),
                  child: Text('№${review.orderNumber}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Placeholder shaped like [ReviewCard].
class ReviewCardSkeleton extends StatelessWidget {
  const ReviewCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(color: c.surface, borderRadius: Radii.brLg, border: Border.all(color: c.line)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Skeleton.line(width: 140, height: 14), Spacer(), Skeleton.line(width: 80, height: 18)]),
          Gap(8),
          Skeleton.line(width: 90, height: 16),
          Gap(12),
          Skeleton.line(),
          Gap(6),
          Skeleton.line(width: 200),
          Gap(12),
          Row(children: [
            Skeleton(width: 64, height: 64),
            Gap(8),
            Skeleton(width: 64, height: 64),
          ]),
          Gap(12),
          Skeleton.line(width: 110),
        ],
      ),
    );
  }
}
