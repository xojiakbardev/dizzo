import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/widgets/widgets.dart';
import '../../domain/catalog_models.dart';

/// The admin's inline SVG icon of a category, tinted; a fallback glyph when
/// it is empty or unparsable.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, required this.svg, this.size = 22, this.color});

  final String svg;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.colors.ink;
    final fallback = Icon(Icons.category_outlined, size: size, color: tint);
    if (svg.trim().isEmpty) return fallback;
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// Horizontal, scrollable category filter: "Barchasi" + each shelf.
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
    this.padding,
  });

  final List<Category> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget chip({required String label, required bool active, required VoidCallback onTap, Widget? icon}) {
      return Padding(
        padding: const EdgeInsets.only(right: Insets.sm),
        child: ChoiceChip(
          selected: active,
          onSelected: (_) => onTap(),
          avatar: icon,
          label: Text(label),
          labelStyle: context.text.labelLarge?.copyWith(color: active ? c.surface : c.ink),
          selectedColor: c.ink,
          backgroundColor: c.surface,
          side: BorderSide(color: active ? c.ink : c.line),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        children: [
          chip(label: context.l10n.catalogAllCategories, active: selected == null, onTap: () => onSelected(null)),
          for (final cat in categories)
            chip(
              label: cat.name,
              active: selected == cat.slug,
              onTap: () => onSelected(selected == cat.slug ? null : cat.slug),
              icon: cat.iconSvg.isEmpty
                  ? null
                  : CategoryIcon(
                      svg: cat.iconSvg,
                      size: 18,
                      color: selected == cat.slug ? c.surface : c.ink,
                    ),
            ),
        ],
      ),
    );
  }
}

/// Height of a row of [CategoryTile]s of [width] at the current text scale.
double categoryTileHeight(BuildContext context, double width) =>
    width + Insets.sm + MediaQuery.textScalerOf(context).scale(12.5) * 1.4 + 4;

/// A category tile for the home screen: picture (or icon) and name.
class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.category, required this.onTap, this.width = 96});

  final Category category;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.brLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: category.imageUrl != null
                  ? AppImage(category.imageUrl, borderRadius: Radii.brLg)
                  : DecoratedBox(
                      decoration: BoxDecoration(color: c.plate, borderRadius: Radii.brLg),
                      child: Center(child: CategoryIcon(svg: category.iconSvg, size: 34, color: c.brand)),
                    ),
            ),
            Gap.sm,
            Text(
              category.name,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
