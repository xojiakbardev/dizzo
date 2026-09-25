import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/presentation/widgets/sign_in_prompt.dart';
import '../domain/order_models.dart';
import '../domain/order_status.dart';
import 'orders_providers.dart';
import 'widgets/status_chip.dart';

/// "Buyurtmalarim": figures and the customer's orders, newest first.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(ordersProvider);
    ref.invalidate(orderStatsProvider);
    try {
      await Future.wait([ref.read(ordersProvider.future), ref.read(orderStatsProvider.future)]);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authControllerProvider).isAuthenticated;
    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.ordersTitle)),
        body: SignInPrompt(icon: Icons.receipt_long_outlined, title: context.l10n.ordersSignInPrompt),
      );
    }
    final orders = ref.watch(ordersProvider);
    final stats = ref.watch(orderStatsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.ordersTitle)),
      body: orders.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const OrdersSkeleton(),
        error: (e, _) => ErrorState(error: e, onRetry: () => _refresh(ref)),
        data: (list) => RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 400 && list.hasMore) {
                ref.read(ordersProvider.notifier).loadMore();
              }
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (list.all.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: context.l10n.ordersEmpty,
                      actionLabel: context.l10n.ordersChooseProduct,
                      onAction: () => context.go(Routes.products),
                    ),
                  )
                else ...[
                  if (stats.value case final s?)
                    SliverPageBody(
                      padTop: Insets.sm,
                      sliver: SliverToBoxAdapter(child: OrderStatsRow(stats: s)),
                    ),
                  SliverPageBody(
                    padTop: Insets.lg,
                    padBottom: Insets.xl,
                    sliver: SliverList.separated(
                      itemCount: list.visible.length,
                      separatorBuilder: (_, _) => Gap.sm,
                      itemBuilder: (context, i) {
                        final order = list.visible[i];
                        return OrderTile(
                          order: order,
                          onTap: () => context.push(Routes.order(order.orderNumber)),
                        );
                      },
                    ),
                  ),
                  if (list.hasMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Insets.xl),
                        child: Center(
                          child: list.loadingMore
                              ? const SizedBox.square(
                                  dimension: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.4),
                                )
                              : TextButton(
                                  onPressed: () => ref.read(ordersProvider.notifier).loadMore(),
                                  child: Text(context.l10n.ordersShowMore),
                                ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Four figures: all orders, awaiting payment, in production, spent.
class OrderStatsRow extends StatelessWidget {
  const OrderStatsRow({super.key, required this.stats});

  final OrderStats stats;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tiles = [
      _StatTile(icon: Icons.inventory_2_outlined, label: l.ordersStatTotal, value: '${stats.totalOrders}'),
      _StatTile(icon: Icons.hourglass_bottom_rounded, label: l.ordersStatAwaitingPayment, value: '${stats.paymentPending}'),
      _StatTile(icon: Icons.precision_manufacturing_outlined, label: l.ordersStatInProduction, value: '${stats.inProduction}'),
      _StatTile(icon: Icons.account_balance_wallet_outlined, label: l.ordersStatSpent, money: stats.totalSpent),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth < 520 ? 2 : 4;
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += columns) {
          if (i > 0) rows.add(Gap.sm);
          rows.add(IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = i; j < i + columns; j++) ...[
                  if (j > i) Gap.sm,
                  Expanded(child: tiles[j]),
                ],
              ],
            ),
          ));
        }
        return Column(children: rows);
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, this.value, this.money});

  final IconData icon;
  final String label;
  final String? value;
  final Money? money;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final big = context.text.titleLarge;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(color: c.surface, borderRadius: Radii.brLg, border: Border.all(color: c.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: c.brand),
          Gap.sm,
          if (money != null)
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: PriceText(money!, style: big))
          else
            Text(value ?? '', style: big),
          const Gap(2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// One row of the order list.
class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order, required this.onTap});

  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = orderStatusMeta(context.l10n, order.status);
    final muted = context.text.bodySmall?.copyWith(color: c.inkMuted);
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: Radii.brLg, side: BorderSide(color: c.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.plate, borderRadius: Radii.brMd),
                child: Icon(
                  order.deliveryMethod == DeliveryMethod.pickup
                      ? Icons.storefront_outlined
                      : Icons.local_shipping_outlined,
                  color: c.brand,
                  size: 22,
                ),
              ),
              Gap.md,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            context.l10n.ordersNumber(order.orderNumber),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall?.copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        Gap.sm,
                        Flexible(child: StatusChip(label: meta.label, tone: meta.tone, dense: true)),
                      ],
                    ),
                    const Gap(3),
                    if (order.createdAt != null)
                      Text(AppDates.dateTime(order.createdAt!, context.l10n.localeName), style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const Gap(3),
                    Row(
                      children: [
                        Expanded(child: Text(context.l10n.ordersItemCount(order.itemCount), style: muted, maxLines: 1)),
                        Gap.sm,
                        Flexible(child: PriceText(order.totalAmount, style: context.text.titleSmall)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder shaped like the figures and the list.
class OrdersSkeleton extends StatelessWidget {
  const OrdersSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget tile() => Container(
          height: 100,
          decoration: BoxDecoration(color: c.surface, borderRadius: Radii.brLg, border: Border.all(color: c.line)),
          padding: const EdgeInsets.all(Insets.md),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 20, height: 20),
              Spacer(),
              Skeleton.line(width: 40, height: 18),
              Gap(6),
              Skeleton.line(width: 80),
            ],
          ),
        );
    Widget row() => Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(color: c.surface, borderRadius: Radii.brLg, border: Border.all(color: c.line)),
          child: const Row(
            children: [
              Skeleton(width: 44, height: 44, borderRadius: Radii.brMd),
              Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Skeleton.line(width: 90, height: 14), Spacer(), Skeleton.line(width: 70, height: 18)]),
                    Gap(8),
                    Skeleton.line(width: 150),
                    Gap(8),
                    Row(children: [Skeleton.line(width: 80), Spacer(), Skeleton.line(width: 90, height: 14)]),
                  ],
                ),
              ),
            ],
          ),
        );
    return SkeletonScope(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(context.pagePadding, Insets.sm, context.pagePadding, Insets.xl),
        children: [
          ContentWidth(
            child: Column(
              children: [
                Row(children: [Expanded(child: tile()), Gap.sm, Expanded(child: tile())]),
                Gap.sm,
                Row(children: [Expanded(child: tile()), Gap.sm, Expanded(child: tile())]),
                Gap.lg,
                for (var i = 0; i < 5; i++) ...[row(), Gap.sm],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
