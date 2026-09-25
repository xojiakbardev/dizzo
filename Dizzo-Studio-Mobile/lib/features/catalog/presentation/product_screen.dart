import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/env.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/catalog_models.dart';
import '../domain/product_selection.dart';
import 'catalog_providers.dart';
import 'product_3d_screen.dart';
import 'widgets/image_gallery.dart';
import 'widgets/option_pickers.dart';
import 'widgets/product_options.dart';

/// Product details: pictures that follow the chosen type and colour, the
/// options, the type's description and specs, and "Dizayn qilish" → the
/// editor with the choice.
///
/// The choice is kept in the route query (`variant`, `color`, `size`), so a
/// shared or restored link shows the same thing, and remembered per product
/// for the session.
class ProductScreen extends ConsumerWidget {
  const ProductScreen({
    super.key,
    required this.slug,
    this.heroTag,
    this.variantId,
    this.colorId,
    this.size,
  });

  final String slug;
  final String? heroTag;
  final int? variantId;
  final int? colorId;
  final String? size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(productDetailProvider(slug));
    final view = _ProductView(
      // One view for loading and loaded: the hero lands on the cover while
      // the details load, and nothing jumps when they arrive.
      key: ValueKey(slug),
      slug: slug,
      product: detail.value,
      heroTag: heroTag,
      variantId: variantId,
      colorId: colorId,
      size: size,
    );
    if (detail.hasValue) return view;
    return detail.maybeWhen(
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(error: e, onRetry: () => ref.invalidate(productDetailProvider(slug))),
      ),
      orElse: () => view,
    );
  }
}

class _ProductView extends ConsumerStatefulWidget {
  const _ProductView({
    super.key,
    required this.slug,
    required this.product,
    required this.heroTag,
    required this.variantId,
    required this.colorId,
    required this.size,
  });

  final String slug;
  final ProductDetail? product;
  final String? heroTag;
  final int? variantId;
  final int? colorId;
  final String? size;

  @override
  ConsumerState<_ProductView> createState() => _ProductViewState();
}

class _ProductViewState extends ConsumerState<_ProductView> {
  ProductSelection _sel = const ProductSelection();
  final _sizeKey = GlobalKey();
  bool _sizeWanted = false;

  // What the list screens already know, shown while the details load.
  late final ProductSummary? _summary = _findSummary();

  ProductSummary? _findSummary() {
    for (final list in [ref.read(productsProvider).value, ref.read(popularProductsProvider).value]) {
      for (final p in list ?? const <ProductSummary>[]) {
        if (p.slug == widget.slug) return p;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_ProductView old) {
    super.didUpdateWidget(old);
    final loaded = old.product == null && widget.product != null;
    final refreshed = old.product != null && widget.product != null && !identical(old.product, widget.product);
    final routeChanged = old.variantId != widget.variantId ||
        old.colorId != widget.colorId ||
        old.size != widget.size;
    // Our own route updates come back here with the query we wrote.
    if (loaded || refreshed || (routeChanged && !_matchesRoute())) _resolve();
  }

  bool _matchesRoute() =>
      _sel.variant?.id == widget.variantId && _sel.color?.id == widget.colorId && _sel.size == widget.size;

  void _resolve() {
    final product = widget.product;
    if (product == null) return;
    final fromRoute = widget.variantId != null || widget.colorId != null || widget.size != null;
    if (fromRoute) {
      _sel = ProductSelection.resolve(
        product,
        variantId: widget.variantId,
        colorId: widget.colorId,
        size: widget.size,
        chosen: true,
      );
      return;
    }
    final remembered = ref.read(productChoiceMemoryProvider)[widget.slug];
    _sel = ProductSelection.resolve(
      product,
      variantId: int.tryParse(remembered?['variant'] ?? ''),
      colorId: int.tryParse(remembered?['color'] ?? ''),
      size: remembered?['size'],
      chosen: remembered != null,
    );
    if (remembered != null) _syncRoute();
  }

  void _choose(ProductSelection next) {
    if (next == _sel) return;
    setState(() {
      _sel = next;
      if (!next.needsSize) _sizeWanted = false;
    });
    ref.read(productChoiceMemoryProvider.notifier).remember(widget.slug, next.query);
    _syncRoute();
  }

  /// Writes the choice into this page's location without a transition.
  void _syncRoute() {
    final query = _sel.query;
    if (query.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      if (router == null || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
      // A newer choice may have been made meanwhile; write the latest.
      final latest = _sel.query;
      unawaited(router.replace<void>(Routes.product(widget.slug, query: latest), extra: widget.heroTag));
    });
  }

  String get _webLink => Uri.parse('${Env.siteUrl}/products/${Uri.encodeComponent(widget.slug)}')
      .replace(queryParameters: _sel.query.isEmpty ? null : _sel.query)
      .toString();

  Future<void> _share() async {
    final name = widget.product?.name ?? _summary?.name ?? '';
    await SharePlus.instance.share(ShareParams(text: _webLink, subject: name));
  }

  void _askSize() {
    HapticFeedback.mediumImpact();
    setState(() => _sizeWanted = true);
    final target = _sizeKey.currentContext;
    if (target != null) {
      unawaited(Scrollable.ensureVisible(target, duration: Motion.normal, curve: Curves.easeOutCubic, alignment: 0.3));
    }
    showAppSnack(context, context.l10n.productChooseSizeSnack);
  }

  void _design() {
    final product = widget.product;
    if (product == null) return;
    if (_sel.needsSize) return _askSize();
    HapticFeedback.lightImpact();
    final chosen = ProductSelection(variant: _sel.variant, color: _sel.color, size: _sel.size, chosen: true);
    ref.read(productChoiceMemoryProvider.notifier).remember(widget.slug, chosen.query);
    context.push(Routes.editor(
      product.slug,
      variant: _sel.variant?.id,
      color: _sel.color?.id,
      size: _sel.size,
    ));
  }

  ProductShape? get _shape {
    final id = _sel.variant?.shapeId;
    for (final s in widget.product?.shapes ?? const <ProductShape>[]) {
      if (s.id == id) return s;
    }
    return null;
  }

  bool get _can3d {
    final s = _shape;
    return s != null && (s.kind != 'model' || (s.modelUrl?.isNotEmpty ?? false));
  }

  void _open3d() {
    final product = widget.product;
    if (product == null) return;
    HapticFeedback.selectionClick();
    unawaited(Product3dScreen.open(
      context,
      slug: product.slug,
      title: product.name,
      variantId: _sel.variant?.id,
      colorId: _sel.color?.id,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final List<String> images;
    final List<List<String>> upcoming;
    if (product == null) {
      images = [?_summary?.coverUrl];
      upcoming = const [];
    } else {
      images = picturesFor(product, _sel.variant, _sel.color);
      upcoming = likelyNextPictures(product, _sel);
    }
    final gallery = Stack(
      fit: StackFit.expand,
      children: [
        ImageGallery(images: images, heroTag: widget.heroTag, upcoming: upcoming),
        if (_can3d)
          Positioned(
            right: Insets.md,
            bottom: Insets.md,
            child: CircleIconButton(
              icon: Icons.view_in_ar_outlined,
              tooltip: context.l10n.product3dView,
              size: 44,
              onPressed: _open3d,
            ),
          ),
      ],
    );
    final details = product == null
        ? _DetailsSkeleton(summary: _summary)
        : _Details(
            product: product,
            sel: _sel,
            sizeKey: _sizeKey,
            sizeWanted: _sizeWanted,
            onChanged: _choose,
          );
    final bar = _BottomBar(
      product: product,
      sel: _sel,
      fallbackPrice: _summary?.fromPrice,
      onDesign: product == null || _sel.soldOut || _sel.variant == null ? null : _design,
    );
    final share = CircleIconButton(icon: Icons.ios_share_rounded, tooltip: context.l10n.productShare, onPressed: _share);

    if (!context.isCompact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(product?.name ?? _summary?.name ?? ''),
          actions: [share, Gap.sm],
        ),
        body: ContentWidth(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.sm, Insets.lg, Insets.xl),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(borderRadius: Radii.brXl, child: gallery),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 10,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.xl, Insets.xl),
                        child: details,
                      ),
                    ),
                    bar,
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: MediaQuery.sizeOf(context).width.clamp(240, 520),
            backgroundColor: context.colors.background,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: context.l10n.commonBack,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            actions: [share, Gap.sm],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: gallery,
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(context.pagePadding, Insets.lg, context.pagePadding, Insets.xxl),
            sliver: SliverToBoxAdapter(child: details),
          ),
        ],
      ),
      bottomNavigationBar: bar,
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.product,
    required this.sel,
    required this.sizeKey,
    required this.sizeWanted,
    required this.onChanged,
  });

  final ProductDetail product;
  final ProductSelection sel;
  final Key sizeKey;
  final bool sizeWanted;
  final ValueChanged<ProductSelection> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = context.l10n;
    final v = sel.variant;
    final description = v?.description.trim() ?? '';
    final specs = [
      ...?v?.specs,
      // The admin usually lists the material already.
      if (v != null && v.material.isNotEmpty && !v.specs.any((s) => s.label.toLowerCase() == 'material' || s.label == l.productSpecMaterial))
        SpecItem(l.productSpecMaterial, v.materialLabelIn(l)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.name, style: context.text.headlineMedium),
        Gap.sm,
        _Price(product: product, sel: sel, style: context.text.headlineSmall, color: c.brand),
        if (product.variants.length > 1) ...[
          _Label(l.productVariant, trailing: v?.name),
          VariantCards(
            variants: product.variants,
            selected: v,
            thumbnailOf: (x) => variantThumbnail(product, x),
            onSelected: (x) => onChanged(sel.withVariant(x)),
          ),
        ],
        if (v != null && v.colors.length > 1) ...[
          _Label(l.productColor, trailing: sel.color?.name),
          ColorSwatches(
            colors: v.colors,
            selected: sel.color,
            onSelected: (x) => onChanged(sel.withColor(x)),
          ),
        ],
        if (v != null && v.sizes.isNotEmpty) ...[
          _Label(
            l.productSize,
            key: sizeKey,
            trailing: sel.soldOut ? l.productSoldOut : (sizeWanted && sel.needsSize ? l.productChooseSize : null),
            trailingColor: sel.soldOut || sizeWanted ? c.danger : null,
          ),
          SizePicker(sizes: v.sizes, selected: sel.size, onSelected: (x) => onChanged(sel.withSize(x))),
        ],
        if (v != null && v.methods.isNotEmpty) ...[
          _Label(l.productPrintMethod),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [for (final m in v.methods) MethodBadge(method: m)],
          ),
        ],
        if (description.isNotEmpty) ...[
          _Label(l.productDescription),
          CollapsibleDescription(description, key: ValueKey(v?.id)),
        ],
        if (specs.isNotEmpty) ...[
          _Label(l.productSpecs),
          SpecsTable(specs: specs),
        ],
      ],
    );
  }
}

/// The price of the choice: the server's quote when it has answered, the
/// page's own sum until then; the product's "from" price before a choice.
class _Price extends ConsumerWidget {
  const _Price({required this.product, required this.sel, this.style, this.color, this.fallback});

  final ProductDetail? product;
  final ProductSelection sel;
  final TextStyle? style;
  final Color? color;
  final Money? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = product;
    final Money value;
    final bool from;
    if (p == null) {
      value = fallback ?? Money.zero;
      from = true;
    } else if (!sel.chosen || sel.variant == null || sel.color == null) {
      value = p.fromPrice;
      from = true;
    } else {
      final key = (sel.variant!.id, sel.color!.id, sel.size);
      value = ref.watch(productQuoteProvider(key).select((q) => q.value)) ?? sel.priceIn(p);
      // A size can still change the price.
      from = sel.needsSize && sel.variant!.sizes.any((s) => !s.surcharge.isZero);
    }
    return AnimatedSwitcher(
      duration: Motion.fast,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, ?current],
      ),
      child: PriceText(
        value,
        key: ValueKey((value.amount, from)),
        from: from,
        style: style,
        color: color,
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {super.key, this.trailing, this.trailingColor});

  final String text;
  final String? trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Insets.xl, bottom: Insets.md),
      child: Row(
        children: [
          Text(text, style: context.text.titleMedium),
          if (trailing != null) ...[
            Gap.sm,
            Flexible(
              child: Text(
                trailing!,
                style: context.text.bodyMedium?.copyWith(color: trailingColor ?? context.colors.inkMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.product,
    required this.sel,
    required this.fallbackPrice,
    required this.onDesign,
  });

  final ProductDetail? product;
  final ProductSelection sel;
  final Money? fallbackPrice;
  final VoidCallback? onDesign;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(context.pagePadding, Insets.md, context.pagePadding, Insets.md),
          child: Row(
            children: [
              Flexible(
                child: _Price(product: product, sel: sel, fallback: fallbackPrice, style: context.text.titleLarge),
              ),
              Gap.lg,
              Expanded(
                child: AppButton(
                  label: sel.soldOut ? context.l10n.productSoldOut : context.l10n.productDesign,
                  icon: const Icon(Icons.brush_rounded),
                  onPressed: onDesign,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton({required this.summary});

  final ProductSummary? summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s != null) ...[
          Text(s.name, style: context.text.headlineMedium),
          Gap.sm,
          PriceText(s.fromPrice, from: true, style: context.text.headlineSmall, color: context.colors.brand),
        ],
        SkeletonScope(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s == null) ...const [
                Skeleton.line(width: 220, height: 24),
                Gap.md,
                Skeleton.line(width: 120, height: 20),
              ],
              Gap.xl,
              const Skeleton.line(width: 60, height: 16),
              Gap.md,
              const Row(
                children: [
                  Skeleton(width: 116, height: 150, borderRadius: Radii.brMd),
                  Gap.sm,
                  Skeleton(width: 116, height: 150, borderRadius: Radii.brMd),
                  Gap.sm,
                  Expanded(child: Skeleton(height: 150, borderRadius: Radii.brMd)),
                ],
              ),
              Gap.xl,
              const Row(
                children: [
                  Skeleton(width: 40, height: 40, borderRadius: BorderRadius.all(Radius.circular(20))),
                  Gap.md,
                  Skeleton(width: 40, height: 40, borderRadius: BorderRadius.all(Radius.circular(20))),
                  Gap.md,
                  Skeleton(width: 40, height: 40, borderRadius: BorderRadius.all(Radius.circular(20))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
