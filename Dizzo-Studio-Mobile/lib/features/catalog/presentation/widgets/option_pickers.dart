import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/widgets.dart';
import '../../domain/catalog_models.dart';

/// Product types as selectable cards (name + price).
class VariantPicker extends StatelessWidget {
  const VariantPicker({super.key, required this.variants, required this.selected, required this.onSelected});

  final List<ProductVariant> variants;
  final ProductVariant? selected;
  final ValueChanged<ProductVariant> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: [
        for (final v in variants)
          Builder(builder: (context) {
            final active = v.id == selected?.id;
            return Semantics(
              selected: active,
              button: true,
              child: InkWell(
                borderRadius: Radii.brMd,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(v);
                },
                child: AnimatedContainer(
                  duration: Motion.fast,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? c.brand.withValues(alpha: 0.08) : c.surface,
                    borderRadius: Radii.brMd,
                    border: Border.all(color: active ? c.brand : c.line, width: active ? 1.6 : 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.name, style: context.text.titleSmall),
                      const Gap(2),
                      PriceText(v.basePrice, style: context.text.labelMedium, color: c.inkMuted),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// Round colour swatches with a ring on the chosen one.
class ColorPicker extends StatelessWidget {
  const ColorPicker({super.key, required this.colors, required this.selected, required this.onSelected});

  final List<ProductColor> colors;
  final ProductColor? selected;
  final ValueChanged<ProductColor> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final color in colors)
          Tooltip(
            message: color.name,
            child: Semantics(
              label: color.name,
              selected: color.id == selected?.id,
              button: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(color);
                },
                child: AnimatedContainer(
                  duration: Motion.fast,
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.id == selected?.id ? c.brand : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.ink.withValues(alpha: 0.12)),
                    ),
                    child: color.id == selected?.id
                        ? Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: color.color.computeLuminance() > 0.5 ? BrandColors.ink : Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Size chips; sold-out sizes are shown crossed out and disabled.
class SizePicker extends StatelessWidget {
  const SizePicker({super.key, required this.sizes, required this.selected, required this.onSelected});

  final List<VariantSize> sizes;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: [
        for (final s in sizes)
          Builder(builder: (context) {
            final active = s.label == selected;
            return Semantics(
              selected: active,
              enabled: s.isAvailable,
              button: true,
              child: InkWell(
                borderRadius: Radii.brMd,
                onTap: s.isAvailable
                    ? () {
                        HapticFeedback.selectionClick();
                        onSelected(s.label);
                      }
                    : null,
                child: AnimatedContainer(
                  duration: Motion.fast,
                  constraints: const BoxConstraints(minWidth: 52, minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? c.ink : c.surface,
                    borderRadius: Radii.brMd,
                    border: Border.all(color: active ? c.ink : c.line),
                  ),
                  child: Text(
                    s.label,
                    style: context.text.labelLarge?.copyWith(
                      color: active ? c.surface : (s.isAvailable ? c.ink : c.inkSubtle),
                      decoration: s.isAvailable ? null : TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class MethodBadge extends StatelessWidget {
  const MethodBadge({super.key, required this.method});

  final PrintMethod method;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final icon = switch (method) {
      PrintMethod.uv => Icons.palette_outlined,
      PrintMethod.engrave => Icons.bolt_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: c.plate, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: c.brand),
          const Gap(6),
          Text(method.labelIn(context.l10n), style: context.text.labelLarge),
        ],
      ),
    );
  }
}

class SpecsTable extends StatelessWidget {
  const SpecsTable({super.key, required this.specs});

  final List<SpecItem> specs;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.brLg,
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < specs.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(specs[i].label, style: context.text.bodyMedium?.copyWith(color: c.inkMuted)),
                  ),
                  Gap.md,
                  Expanded(
                    child: Text(specs[i].value, textAlign: TextAlign.end, style: context.text.titleSmall),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
