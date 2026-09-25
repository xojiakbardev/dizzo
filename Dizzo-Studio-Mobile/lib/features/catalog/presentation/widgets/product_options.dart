import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/widgets.dart';
import '../../domain/catalog_models.dart';

/// Product types as a horizontal row of picture cards: thumbnail, name and
/// the price difference from the cheapest type.
class VariantCards extends StatefulWidget {
  const VariantCards({
    super.key,
    required this.variants,
    required this.selected,
    required this.thumbnailOf,
    required this.onSelected,
  });

  final List<ProductVariant> variants;
  final ProductVariant? selected;
  final String? Function(ProductVariant) thumbnailOf;
  final ValueChanged<ProductVariant> onSelected;

  static const cardWidth = 116.0;

  @override
  State<VariantCards> createState() => _VariantCardsState();
}

class _VariantCardsState extends State<VariantCards> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // A restored choice further along the row is scrolled into view.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: false));
  }

  @override
  void didUpdateWidget(VariantCards old) {
    super.didUpdateWidget(old);
    if (old.selected?.id != widget.selected?.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: true));
    }
  }

  void _reveal({required bool animate}) {
    if (!mounted || !_scroll.hasClients) return;
    final i = widget.variants.indexWhere((v) => v.id == widget.selected?.id);
    if (i < 0) return;
    final pos = _scroll.position;
    const step = VariantCards.cardWidth + Insets.sm;
    final start = i * step;
    final end = start + VariantCards.cardWidth;
    double? target;
    if (start < pos.pixels) target = start;
    if (end > pos.pixels + pos.viewportDimension) target = end - pos.viewportDimension;
    if (target == null) return;
    target = target.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(target, duration: Motion.normal, curve: Curves.easeOutCubic);
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final variants = widget.variants;
    final cheapest = variants.map((v) => v.basePrice).reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    final scaler = MediaQuery.textScalerOf(context);
    // Picture + two lines of name + a price line, at the user's text size.
    final height = VariantCards.cardWidth - 16 + 8 + scaler.scale(13) * 1.3 * 2 + 4 + scaler.scale(12) * 1.4 + 20;
    return SizedBox(
      height: height,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: variants.length,
        separatorBuilder: (_, _) => Gap.sm,
        itemBuilder: (context, i) {
          final v = variants[i];
          final diff = Money.of(v.basePrice.amount - cheapest.amount);
          return _VariantCard(
            name: v.name,
            imageUrl: widget.thumbnailOf(v),
            priceDiff: diff.amount > 0 ? diff : null,
            active: v.id == widget.selected?.id,
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onSelected(v);
            },
          );
        },
      ),
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.name,
    required this.imageUrl,
    required this.priceDiff,
    required this.active,
    required this.onTap,
  });

  final String name;
  final String? imageUrl;
  final Money? priceDiff;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: active,
      button: true,
      label: name,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: Radii.brMd,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          width: VariantCards.cardWidth,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: active ? c.brand.withValues(alpha: 0.08) : c.surface,
            borderRadius: Radii.brMd,
            border: Border.all(color: active ? c.brand : c.line, width: active ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: AppImage(imageUrl, fit: BoxFit.contain, borderRadius: Radii.brSm),
              ),
              Gap.sm,
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall?.copyWith(fontSize: 13, height: 1.3),
              ),
              const Gap(4),
              if (priceDiff != null)
                Text(
                  '+${priceDiff!.format()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(fontSize: 12, height: 1.4, color: c.inkMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Colour swatches with their names under them.
class ColorSwatches extends StatelessWidget {
  const ColorSwatches({super.key, required this.colors, required this.selected, required this.onSelected});

  final List<ProductColor> colors;
  final ProductColor? selected;
  final ValueChanged<ProductColor> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: 4,
      runSpacing: Insets.sm,
      children: [
        for (final color in colors)
          Builder(builder: (context) {
            final active = color.id == selected?.id;
            return Semantics(
              label: color.name,
              selected: active,
              button: true,
              excludeSemantics: true,
              child: InkWell(
                borderRadius: Radii.brMd,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(color);
                },
                child: SizedBox(
                  width: 64,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: Motion.fast,
                          width: 44,
                          height: 44,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: active ? c.brand : Colors.transparent, width: 2),
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: color.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.ink.withValues(alpha: 0.12)),
                            ),
                            child: active
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: color.color.computeLuminance() > 0.5 ? BrandColors.ink : Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          color.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: context.text.labelSmall?.copyWith(
                            color: active ? c.ink : c.inkMuted,
                            fontWeight: active ? FontWeight.w700 : null,
                          ),
                        ),
                      ],
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

/// A variant's rich description; long ones start folded with a
/// "Batafsil" toggle.
class CollapsibleDescription extends StatefulWidget {
  const CollapsibleDescription(this.html, {super.key});

  final String html;

  /// Plain-text length above which the text starts folded.
  static const foldAfter = 320;
  static const foldedHeight = 132.0;

  @override
  State<CollapsibleDescription> createState() => _CollapsibleDescriptionState();
}

class _CollapsibleDescriptionState extends State<CollapsibleDescription> {
  bool _open = false;

  bool get _long =>
      widget.html.replaceAll(RegExp(r'<[^>]*>'), '').trim().length > CollapsibleDescription.foldAfter;

  @override
  void didUpdateWidget(CollapsibleDescription old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html) _open = false;
  }

  @override
  Widget build(BuildContext context) {
    final text = RichDescription(widget.html);
    if (!_long) return text;
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: Motion.normal,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? text
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: CollapsibleDescription.foldedHeight),
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.6, 1],
                      colors: [Colors.black, Colors.transparent],
                    ).createShader(rect),
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        maxHeight: double.infinity,
                        child: text,
                      ),
                    ),
                  ),
                ),
        ),
        TextButton.icon(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 40),
            foregroundColor: c.brandStrong,
          ),
          onPressed: () => setState(() => _open = !_open),
          icon: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
          label: Text(_open ? context.l10n.productShowLess : context.l10n.productShowMore),
        ),
      ],
    );
  }
}
