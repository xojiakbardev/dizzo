import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/widgets/widgets.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../catalog/presentation/widgets/category_widgets.dart';
import '../../catalog/presentation/widgets/product_grid.dart';
import '../data/gallery_api.dart';
import '../domain/gallery_item.dart';

/// "Asosiy" tab: hero, categories, popular products, customer works.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _popularLimit = 8;

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(popularProductsProvider)
      ..invalidate(categoriesProvider)
      ..invalidate(galleryProvider);
    await ref.read(popularProductsProvider.future).catchError((_) => const <Never>[]);
  }

  void _openCategory(BuildContext context, WidgetRef ref, String slug) {
    ref.read(catalogFilterProvider.notifier).setCategory(slug);
    context.go(Routes.products);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popular = ref.watch(popularProductsProvider);
    final categories = ref.watch(categoriesProvider);
    final gallery = ref.watch(galleryProvider);
    final pad = context.pagePadding;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              titleSpacing: pad,
              title: const _Wordmark(),
              actions: [
                IconButton(
                  tooltip: context.l10n.homeSearch,
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => context.go(Routes.products),
                ),
                Gap(pad - 8),
              ],
            ),
            SliverPageBody(
              padTop: Insets.sm,
              sliver: SliverToBoxAdapter(
                child: _Hero(onStart: () => context.go(Routes.products)),
              ),
            ),

            // Categories (hidden when there are none).
            ...categories.maybeWhen(
              data: (items) => items.isEmpty
                  ? const <Widget>[]
                  : [
                      SliverPageBody(
                        padTop: Insets.xl,
                        sliver: SliverToBoxAdapter(child: SectionHeader(title: context.l10n.homeCategories)),
                      ),
                      SliverToBoxAdapter(
                        child: ContentWidth(
                          child: SizedBox(
                            height: categoryTileHeight(context, 96),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(horizontal: pad),
                              itemCount: items.length,
                              separatorBuilder: (_, _) => Gap.md,
                              itemBuilder: (context, i) => CategoryTile(
                                category: items[i],
                                onTap: () => _openCategory(context, ref, items[i].slug),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
              orElse: () => const <Widget>[],
            ),

            SliverPageBody(
              padTop: Insets.xl,
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  title: context.l10n.homeChooseProduct,
                  actionLabel: context.l10n.homeSeeAll,
                  onAction: () => context.go(Routes.products),
                ),
              ),
            ),
            popular.when(
              skipLoadingOnRefresh: true,
              data: (items) => items.isEmpty
                  ? SliverToBoxAdapter(
                      child: EmptyState(compact: true, icon: Icons.inventory_2_outlined, title: context.l10n.homeNoProducts),
                    )
                  : SliverPageBody(
                      sliver: SliverProductGrid(
                        products: items.take(_popularLimit).toList(),
                        heroPrefix: 'home',
                      ),
                    ),
              loading: () => const SliverPageBody(sliver: SliverProductGridSkeleton(count: 4)),
              error: (e, _) => SliverToBoxAdapter(
                child: ErrorState(
                  compact: true,
                  error: e,
                  onRetry: () => ref.invalidate(popularProductsProvider),
                ),
              ),
            ),

            // Customer works: shown once there are at least three (as on the site).
            ...gallery.maybeWhen(
              data: (items) => items.length < 3
                  ? const <Widget>[]
                  : [
                      SliverPageBody(
                        padTop: Insets.xxl,
                        sliver: SliverToBoxAdapter(
                          child: SectionHeader(title: context.l10n.homeGallery),
                        ),
                      ),
                      SliverToBoxAdapter(child: ContentWidth(child: _GalleryStrip(items: items))),
                    ],
              orElse: () => const <Widget>[],
            ),
            const SliverToBoxAdapter(child: Gap(Insets.xxxl)),
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/brand/dizzo-mark.png', width: 30, height: 30),
        const Gap(8),
        Text(
          'Dizzo',
          style: context.text.headlineSmall?.copyWith(
            color: context.colors.brand,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final wide = !context.isCompact;
    return ClipRRect(
      borderRadius: Radii.brXl,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [BrandColors.orange, BrandColors.amber],
          ),
        ),
        child: Stack(
          children: [
            // The mark, large and faint, bleeding off the corner.
            Positioned(
              right: -36,
              bottom: -40,
              child: Opacity(
                opacity: 0.22,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  child: Image.asset('assets/brand/dizzo-mark.png', width: wide ? 260 : 190),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(wide ? Insets.xxl : Insets.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      context.l10n.homeHeroTitle,
                      style: (wide ? context.text.displaySmall : context.text.headlineMedium)
                          ?.copyWith(color: Colors.white, height: 1.15),
                    ),
                  ),
                  Gap(wide ? Insets.xl : Insets.lg),
                  FilledButton.icon(
                    onPressed: onStart,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: BrandColors.ink,
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.brush_rounded, size: 20),
                    label: Text(context.l10n.homeCreateDesign),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryStrip extends StatelessWidget {
  const _GalleryStrip({required this.items});

  final List<GalleryItem> items;

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final width = context.isCompact ? 168.0 : 210.0;
    return SizedBox(
      height: width + 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: pad),
        itemCount: items.length,
        separatorBuilder: (_, _) => Gap.md,
        itemBuilder: (context, i) {
          final item = items[i];
          return SizedBox(
            width: width,
            child: InkWell(
              borderRadius: Radii.brLg,
              onTap: item.canOpen
                  ? () => context.push(Routes.editor(
                        item.productSlug!,
                        variant: item.variantId,
                        color: item.colorId,
                        from: item.templateId,
                      ))
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppImage(item.imageUrl, width: width, height: width, borderRadius: Radii.brLg),
                  Gap.sm,
                  Text(item.heading, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
