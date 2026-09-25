import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/catalog_models.dart';

/// A responsive sliver grid of products (2 columns on phones, up to 5).
class SliverProductGrid extends StatelessWidget {
  const SliverProductGrid({super.key, required this.products, this.heroPrefix = 'p'});

  final List<ProductSummary> products;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = ResponsiveContext.productColumnsFor(constraints.crossAxisExtent);
        return SliverGrid(
          gridDelegate: productGridDelegate(context, columns, constraints.crossAxisExtent),
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final p = products[i];
              return ProductCard(
                name: p.name,
                imageUrl: p.coverUrl,
                price: p.fromPrice,
                badge: p.isFeatured ? context.l10n.catalogPopularBadge : null,
                heroTag: '$heroPrefix-${p.slug}',
                onTap: () => context.push(Routes.product(p.slug), extra: '$heroPrefix-${p.slug}'),
              );
            },
            childCount: products.length,
          ),
        );
      },
    );
  }
}

/// Skeleton version of [SliverProductGrid].
class SliverProductGridSkeleton extends StatelessWidget {
  const SliverProductGridSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = ResponsiveContext.productColumnsFor(constraints.crossAxisExtent);
        return SliverGrid(
          gridDelegate: productGridDelegate(context, columns, constraints.crossAxisExtent),
          delegate: SliverChildBuilderDelegate(
            (_, _) => const SkeletonScope(child: ProductCardSkeleton()),
            childCount: count,
          ),
        );
      },
    );
  }
}

/// Square picture + a two-line name + the price; the tile height follows
/// the user's text scale so large fonts never overflow.
SliverGridDelegate productGridDelegate(BuildContext context, int columns, double width) {
  const spacing = 14.0;
  final tileWidth = (width - spacing * (columns - 1)) / columns;
  final scaler = MediaQuery.textScalerOf(context);
  final name = scaler.scale(14) * 1.25 * 2;
  final price = scaler.scale(14) * 1.45;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisSpacing: 20,
    crossAxisSpacing: spacing,
    mainAxisExtent: tileWidth + 10 + name + 4 + price + 6,
  );
}
