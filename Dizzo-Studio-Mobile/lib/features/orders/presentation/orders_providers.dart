import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/orders_api.dart';
import '../domain/order_models.dart';

/// The customer's orders, shown [pageSize] at a time.
class OrdersList {
  const OrdersList({required this.all, required this.shown, this.next, this.loadingMore = false});

  final List<OrderSummary> all;
  final int shown;

  /// The backend's next page, if it pages.
  final String? next;
  final bool loadingMore;

  List<OrderSummary> get visible => all.take(shown).toList();
  bool get hasMore => shown < all.length || next != null;

  OrdersList copyWith({List<OrderSummary>? all, int? shown, String? next, bool clearNext = false, bool? loadingMore}) =>
      OrdersList(
        all: all ?? this.all,
        shown: shown ?? this.shown,
        next: clearNext ? null : (next ?? this.next),
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class OrdersController extends AsyncNotifier<OrdersList> {
  static const pageSize = 20;

  @override
  Future<OrdersList> build() async {
    ref.watch(contentLanguageProvider);
    final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
    if (userId == null) return const OrdersList(all: [], shown: 0);
    final page = await ref.read(ordersApiProvider).list();
    return OrdersList(all: page.results, shown: pageSize, next: page.next);
  }

  Future<void> loadMore() async {
    final list = state.value;
    if (list == null || list.loadingMore || !list.hasMore) return;
    if (list.shown < list.all.length) {
      state = AsyncData(list.copyWith(shown: list.shown + pageSize));
      return;
    }
    state = AsyncData(list.copyWith(loadingMore: true));
    try {
      final page = await ref.read(ordersApiProvider).list(next: list.next);
      if (!ref.mounted) return;
      state = AsyncData(OrdersList(
        all: [...list.all, ...page.results],
        shown: list.shown + pageSize,
        next: page.next,
      ));
    } catch (_) {
      if (ref.mounted) state = AsyncData(list.copyWith(loadingMore: false));
    }
  }
}

final ordersProvider = AsyncNotifierProvider<OrdersController, OrdersList>(OrdersController.new);

final orderStatsProvider = FutureProvider<OrderStats>((ref) async {
  final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  if (userId == null) return const OrderStats();
  return ref.read(ordersApiProvider).stats();
});

/// One order by number or id.
final orderDetailProvider = FutureProvider.autoDispose.family<OrderDetail, String>((ref, lookup) {
  ref.watch(contentLanguageProvider);
  return ref.read(ordersApiProvider).detail(lookup);
});

extension InvalidateOrders on WidgetRef {
  /// After an order changes (placed, cancelled): reload lists and stats.
  void invalidateOrders() {
    invalidate(ordersProvider);
    invalidate(orderStatsProvider);
    invalidate(orderDetailProvider);
  }
}
