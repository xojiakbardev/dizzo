import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/utils/money.dart';
import '../data/catalog_api.dart';
import '../domain/catalog_models.dart';

/// Every product on sale, in the admin's order. Kept alive: the list is
/// small and used by home, catalog and search.
final productsProvider = FutureProvider<List<ProductSummary>>(
  (ref) {
    ref.watch(contentLanguageProvider);
    return ref.watch(catalogApiProvider).products();
  },
);

/// Most-ordered first (home "Mahsulot tanlang").
final popularProductsProvider = FutureProvider<List<ProductSummary>>(
  (ref) {
    ref.watch(contentLanguageProvider);
    return ref.watch(catalogApiProvider).products(popular: true);
  },
);

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) {
    ref.watch(contentLanguageProvider);
    return ref.watch(catalogApiProvider).categories();
  },
);

final productDetailProvider = FutureProvider.autoDispose.family<ProductDetail, String>(
  (ref, slug) async {
    ref.watch(contentLanguageProvider);
    final detail = await ref.watch(catalogApiProvider).product(slug);
    // Keep a visited product for a while (back-and-forth navigation).
    final link = ref.keepAlive();
    final timer = Timer(const Duration(minutes: 5), link.close);
    ref.onDispose(timer.cancel);
    return detail;
  },
);

/// The server's price for a (variant, colour, size) choice. The page shows
/// its own sum at once and this one when it arrives.
final productQuoteProvider = FutureProvider.autoDispose.family<Money, (int, int, String?)>(
  (ref, key) async {
    // Debounce quick taps through the options.
    var cancelled = false;
    ref.onDispose(() => cancelled = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (cancelled) throw StateError('cancelled');
    final price = await ref.watch(catalogApiProvider).quote(variantId: key.$1, colorId: key.$2, size: key.$3);
    final link = ref.keepAlive();
    final timer = Timer(const Duration(minutes: 5), link.close);
    ref.onDispose(timer.cancel);
    return price;
  },
  retry: (_, _) => null,
);

/// The last choice per product (slug → route query) for this app session,
/// so a product opened again shows what the customer picked before.
class ProductChoiceMemory extends Notifier<Map<String, Map<String, String>>> {
  @override
  Map<String, Map<String, String>> build() => const {};

  void remember(String slug, Map<String, String> query) {
    if (query.isEmpty || _same(state[slug], query)) return;
    state = {...state, slug: query};
  }

  static bool _same(Map<String, String>? a, Map<String, String> b) =>
      a != null && a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}

final productChoiceMemoryProvider =
    NotifierProvider<ProductChoiceMemory, Map<String, Map<String, String>>>(ProductChoiceMemory.new);

/// The catalog screen's search text and shelf.
class CatalogFilter {
  const CatalogFilter({this.query = '', this.category});

  final String query;

  /// A category slug, or null for all.
  final String? category;

  CatalogFilter copyWith({String? query, String? Function()? category}) => CatalogFilter(
        query: query ?? this.query,
        category: category != null ? category() : this.category,
      );
}

class CatalogFilterController extends Notifier<CatalogFilter> {
  @override
  CatalogFilter build() => const CatalogFilter();

  void setQuery(String query) => state = state.copyWith(query: query);
  void setCategory(String? slug) => state = state.copyWith(category: () => slug);
}

final catalogFilterProvider =
    NotifierProvider<CatalogFilterController, CatalogFilter>(CatalogFilterController.new);

/// Products matching [catalogFilterProvider] (case- and apostrophe-insensitive).
final filteredProductsProvider = Provider<AsyncValue<List<ProductSummary>>>((ref) {
  final filter = ref.watch(catalogFilterProvider);
  return ref.watch(productsProvider).whenData((items) => filterProducts(items, filter));
});

List<ProductSummary> filterProducts(List<ProductSummary> items, CatalogFilter filter) {
  final q = normalizeSearch(filter.query);
  return [
    for (final p in items)
      if ((filter.category == null || p.category == filter.category) &&
          (q.isEmpty || normalizeSearch(p.name).contains(q)))
        p,
  ];
}

/// Lower-cases and folds the many apostrophes of Uzbek Latin (o‘, g‘, ’, ')
/// so "ogil" matches "O‘g‘il" and "o'g'il".
String normalizeSearch(String s) =>
    s.toLowerCase().replaceAll(RegExp('[\'‘’ʻʼ`´]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
