import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/widgets.dart';
import 'catalog_providers.dart';
import 'widgets/category_widgets.dart';
import 'widgets/product_grid.dart';

/// "Mahsulotlar" tab: search, category chips, product grid.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  late final TextEditingController _search =
      TextEditingController(text: ref.read(catalogFilterProvider).query);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      ref.read(catalogFilterProvider.notifier).setQuery(value);
    });
  }

  void _clearAll() {
    _search.clear();
    ref.read(catalogFilterProvider.notifier)
      ..setQuery('')
      ..setCategory(null);
  }

  Future<void> _refresh() async {
    ref.invalidate(productsProvider);
    ref.invalidate(categoriesProvider);
    await ref.read(productsProvider.future).catchError((_) => const <Never>[]);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(catalogFilterProvider);
    final products = ref.watch(filteredProductsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final pad = context.pagePadding;
    final hasFilter = filter.query.isNotEmpty || filter.category != null;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: 120,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverAppBar(title: Text(context.l10n.catalogTitle), floating: true, snap: true),
            SliverPersistentHeader(
              pinned: true,
              delegate: _FilterHeader(
                background: context.colors.background,
                child: Column(
                  children: [
                    ContentWidth(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        child: SizedBox(
                          height: 48,
                          child: TextField(
                            controller: _search,
                            onChanged: _onQuery,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: context.l10n.catalogSearchHint,
                              contentPadding: EdgeInsets.zero,
                              prefixIcon: const Icon(Icons.search_rounded),
                              // Only the clear button follows the typing,
                              // not the whole screen.
                              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _search,
                                builder: (_, value, _) => value.text.isEmpty
                                    ? const SizedBox.shrink()
                                    : IconButton(
                                        tooltip: context.l10n.catalogSearchClear,
                                        icon: const Icon(Icons.close_rounded),
                                        onPressed: () {
                                          _search.clear();
                                          _onQuery('');
                                        },
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Gap(10),
                    ContentWidth(
                      child: CategoryChips(
                        categories: categories,
                        selected: filter.category,
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        onSelected: ref.read(catalogFilterProvider.notifier).setCategory,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...products.when(
              skipLoadingOnRefresh: true,
              data: (items) => items.isEmpty
                  ? [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.search_off_rounded,
                          title: context.l10n.catalogNothingFound,
                          actionLabel: hasFilter ? context.l10n.catalogClearFilter : null,
                          onAction: hasFilter ? _clearAll : null,
                        ),
                      ),
                    ]
                  : [
                      SliverPageBody(
                        padTop: Insets.md,
                        padBottom: Insets.xxl,
                        sliver: SliverProductGrid(products: items, heroPrefix: 'catalog'),
                      ),
                    ],
              loading: () => const [
                SliverPageBody(
                  padTop: Insets.md,
                  sliver: SliverProductGridSkeleton(),
                ),
              ],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(error: e, onRetry: () => ref.invalidate(productsProvider)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterHeader extends SliverPersistentHeaderDelegate {
  _FilterHeader({required this.child, required this.background});

  final Widget child;
  final Color background;

  static const _height = 112.0;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: background,
      elevation: overlapsContent || shrinkOffset > 0 ? 0.5 : 0,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterHeader oldDelegate) =>
      oldDelegate.child != child || oldDelegate.background != background;
}
