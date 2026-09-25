import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/money.dart';
import 'app_image.dart';
import 'price_text.dart';

/// A product tile for grids: square picture on the warm plate, name, price.
/// Takes plain values so any feature can use it (catalog, home, designs).
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.price,
    this.fromPrice = true,
    this.badge,
    this.onTap,
    this.heroTag,
  });

  final String name;
  final String? imageUrl;
  final Money price;
  final bool fromPrice;

  /// A small label over the picture ("Ommabop").
  final String? badge;
  final VoidCallback? onTap;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget image = AppImage(imageUrl, borderRadius: Radii.brLg, fit: BoxFit.cover);
    if (heroTag != null) {
      image = Hero(tag: heroTag!, flightShuttleBuilder: appImageFlightShuttle, child: image);
    }
    return Semantics(
      button: onTap != null,
      label: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.brLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  if (badge != null)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.surface.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          child: Text(
                            badge!,
                            style: context.text.labelSmall?.copyWith(color: c.brand),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Gap(10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall?.copyWith(height: 1.25),
              ),
            ),
            const Gap(4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: PriceText(
                price,
                from: fromPrice,
                style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
