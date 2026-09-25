import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/widgets.dart';
import '../../cart/presentation/widgets/mockup_gallery.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../checkout/presentation/widgets/location_map.dart';
import '../../reviews/data/reviews_api.dart';
import '../../reviews/presentation/review_form_sheet.dart';
import '../../reviews/presentation/widgets/review_widgets.dart';
import '../data/orders_api.dart';
import '../domain/order_models.dart';
import '../domain/order_status.dart';
import 'orders_providers.dart';
import 'widgets/status_chip.dart';

/// One order, kept short (the web's /user/orders/[id] in the same order):
/// the status with a small tracker and what can be done now, the items,
/// the money, the delivery. Route `/orders/:id` (number or id).
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _cancelling = false;

  Future<void> _refresh() async {
    ref.invalidate(orderDetailProvider(widget.orderId));
    ref.invalidate(myReviewsProvider);
    try {
      await ref.read(orderDetailProvider(widget.orderId).future);
    } catch (_) {}
  }

  Future<void> _cancel(OrderDetail order) async {
    final ok = await confirmSheet(
      context,
      title: context.l10n.ordersCancelConfirm,
      confirmLabel: context.l10n.ordersCancelAction,
      cancelLabel: context.l10n.ordersCancelKeep,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await ref.read(ordersApiProvider).cancel(order.id);
      if (!mounted) return;
      ref.invalidateOrders();
      showAppSnack(context, context.l10n.ordersCancelled);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _review(OrderDetail order) async {
    final sent = await showReviewForm(context, orderId: order.id);
    if (sent && mounted) showAppSnack(context, context.l10n.ordersReviewSent);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderDetailProvider(widget.orderId));
    final title = async.value?.orderNumber ?? widget.orderId;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.ordersDetailTitle(title))),
      body: async.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const _DetailSkeleton(),
        error: (e, _) => ApiException.from(e).kind == ApiErrorKind.notFound
            ? EmptyState(
                icon: Icons.search_off_rounded,
                title: context.l10n.ordersNotFound,
                actionLabel: context.l10n.ordersAll,
                onAction: () => context.go(Routes.orders),
              )
            : ErrorState(error: e, onRetry: _refresh),
        data: (order) {
          final main = [
            _StatusCard(
              order: order,
              cancelling: _cancelling,
              onCancel: () => _cancel(order),
              onReview: () => _review(order),
            ),
            Gap.md,
            _ItemsCard(order: order),
          ];
          final side = [
            _SummaryCard(order: order),
            Gap.md,
            _DeliveryCard(order: order),
          ];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(context.pagePadding, Insets.sm, context.pagePadding, Insets.xxl),
              children: [
                ContentWidth(
                  child: context.isExpanded
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: Column(children: main)),
                            Gap.lg,
                            Expanded(flex: 2, child: Column(children: side)),
                          ],
                        )
                      : Column(children: [...main, Gap.md, ...side]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A plain bordered card with an optional title row.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.title, this.trailing, this.icon});

  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(color: c.surface, borderRadius: Radii.brLg, border: Border.all(color: c.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[Icon(icon, size: 18, color: c.inkMuted), Gap.sm],
                Expanded(child: Text(title!, style: context.text.titleMedium)),
                ?trailing,
              ],
            ),
            Gap.md,
          ],
          child,
        ],
      ),
    );
  }
}

/// Date and status, the tracker (or "cancelled"), the next step and the
/// actions that make sense now.
class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.order, required this.cancelling, required this.onCancel, required this.onReview});

  final OrderDetail order;
  final bool cancelling;
  final VoidCallback onCancel;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final meta = orderStatusMeta(context.l10n, order.status);
    final next = orderNextStep(context.l10n, order.status, pickup: order.isPickup);
    final reviews = order.isCompleted ? ref.watch(myReviewsProvider) : null;
    final review = reviews?.value?.where((r) => r.orderId == order.id).firstOrNull;
    final canReview = order.isCompleted && reviews != null && reviews.hasValue && review == null;
    final inProgress = !order.isCompleted && !order.isCancelled;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.createdAt == null ? '' : AppDates.dateTimeShort(order.createdAt!, context.l10n.localeName),
                  style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
                ),
              ),
              Gap.sm,
              Flexible(child: StatusChip(label: meta.label, tone: meta.tone)),
            ],
          ),
          Gap.lg,
          if (order.isCancelled)
            Container(
              padding: const EdgeInsets.all(Insets.md),
              decoration: BoxDecoration(color: c.danger.withValues(alpha: 0.08), borderRadius: Radii.brMd),
              child: Row(
                children: [
                  Icon(Icons.cancel_outlined, color: c.danger, size: 22),
                  Gap.md,
                  Expanded(
                    child: Text(
                      context.l10n.ordersCancelledBanner,
                      style: context.text.titleSmall?.copyWith(color: c.danger),
                    ),
                  ),
                ],
              ),
            )
          else
            OrderTracker(status: order.status),
          if (next != null) ...[
            Gap.md,
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: c.inkMuted),
                const Gap(6),
                Expanded(child: Text(next, style: context.text.bodyMedium)),
              ],
            ),
          ],
          if (review != null) ...[
            Gap.lg,
            ReviewCard(review: review, showProduct: false),
          ],
          if (canReview) ...[
            Gap.lg,
            AppButton(
              label: context.l10n.ordersLeaveReview,
              icon: const Icon(Icons.rate_review_outlined),
              onPressed: onReview,
              size: 48,
            ),
          ],
          Gap.md,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(supportTelegramUrl), mode: LaunchMode.externalApplication),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(context.l10n.ordersTelegram),
                ),
              ),
              if (inProgress) ...[
                Gap.sm,
                _MoreMenu(canCancel: order.canCancel, cancelling: cancelling, onCancel: onCancel),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.canCancel, required this.cancelling, required this.onCancel});

  final bool canCancel;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (cancelling) {
      return SizedBox.square(
        dimension: 44,
        child: Center(
          child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.danger)),
        ),
      );
    }
    return PopupMenuButton<void>(
      tooltip: context.l10n.ordersMore,
      icon: const Icon(Icons.more_horiz_rounded),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(44),
        side: BorderSide(color: c.line),
        shape: RoundedRectangleBorder(borderRadius: Radii.brMd),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: canCancel,
          onTap: onCancel,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.close_rounded, color: canCancel ? c.danger : c.inkSubtle),
            title: Text(context.l10n.ordersCancelAction, style: TextStyle(color: canCancel ? c.danger : c.inkSubtle)),
            subtitle: canCancel ? null : Text(context.l10n.ordersOnlyNewCancellable),
          ),
        ),
      ],
    );
  }
}

/// The five steps in one row: icon and a short name, the current one
/// highlighted.
class OrderTracker extends StatelessWidget {
  const OrderTracker({super.key, required this.status});

  final String status;

  static const _icons = [
    Icons.assignment_turned_in_outlined,
    Icons.payments_outlined,
    Icons.precision_manufacturing_outlined,
    Icons.inventory_2_outlined,
    Icons.check_circle_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labels = orderStepLabels(context.l10n);
    final current = orderStep(status);
    final completed = status == OrderStatus.completed;
    bool done(int i) => i < current || completed;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              selected: i == current,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: i == 0 ? const SizedBox() : Container(height: 2, color: done(i - 1) ? c.brand : c.line),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: done(i) ? c.brand : (i == current ? c.brand.withValues(alpha: 0.14) : c.plate),
                          shape: BoxShape.circle,
                          border: i == current && !completed ? Border.all(color: c.brand, width: 1.5) : null,
                        ),
                        child: Icon(
                          done(i) ? Icons.check_rounded : _icons[i],
                          size: 16,
                          color: done(i) ? Colors.white : (i == current ? c.brand : c.inkSubtle),
                        ),
                      ),
                      Expanded(
                        child: i == labels.length - 1
                            ? const SizedBox()
                            : Container(height: 2, color: done(i) ? c.brand : c.line),
                      ),
                    ],
                  ),
                  const Gap(6),
                  Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: context.text.labelSmall?.copyWith(
                      color: done(i) || i == current ? c.ink : c.inkSubtle,
                      fontWeight: i == current && !completed ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _Card(
      title: context.l10n.ordersItems,
      trailing: Text(context.l10n.ordersPieces(order.pieces), style: context.text.labelMedium?.copyWith(color: c.inkMuted)),
      child: Column(
        children: [
          for (final (i, item) in order.items.indexed) ...[
            if (i > 0) Divider(height: Insets.xl, color: c.line),
            OrderItemRow(item: item, showProduction: orderShowsProduction(order.status)),
          ],
        ],
      ),
    );
  }
}

/// An item: swipeable pictures (tap: full screen), name, small chips,
/// "× qty" and the line price.
class OrderItemRow extends StatelessWidget {
  const OrderItemRow({super.key, required this.item, this.showProduction = false});

  final OrderItem item;
  final bool showProduction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final production = productionStatusMeta(context.l10n, item.productionStatus);
    Widget chip(String label, {Widget? lead}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: c.plate, borderRadius: BorderRadius.circular(Radii.pill)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (lead != null) ...[lead, const Gap(4)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(color: c.inkMuted),
                ),
              ),
            ],
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(dimension: 88, child: MockupGallery(images: item.mockups, borderRadius: Radii.brMd)),
        Gap.md,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.productName, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              Gap.xs,
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (item.variantName.isNotEmpty) chip(item.variantName),
                  if (item.colorName.isNotEmpty)
                    chip(
                      item.colorName,
                      lead: item.color == null
                          ? null
                          : Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: item.color,
                                shape: BoxShape.circle,
                                border: Border.all(color: c.line),
                              ),
                            ),
                    ),
                  if (item.size.isNotEmpty) chip(item.size),
                  for (final l in item.printLines)
                    chip(
                      l.method.labelIn(context.l10n),
                      lead: Icon(
                        l.method == PrintMethod.uv ? Icons.palette_outlined : Icons.bolt_rounded,
                        size: 12,
                        color: c.brand,
                      ),
                    ),
                ],
              ),
              if (showProduction) ...[
                Gap.xs,
                StatusChip(label: production.label, tone: production.tone, dense: true),
              ],
              Gap.sm,
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('× ${item.quantity}', style: context.text.bodyMedium?.copyWith(color: c.inkMuted)),
                  Gap.sm,
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: PriceText(item.totalPrice, style: context.text.titleSmall),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.strong = false});

  final String label;
  final Widget value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: strong ? context.text.titleSmall : context.text.bodyMedium?.copyWith(color: c.inkMuted),
            ),
          ),
          Gap.md,
          value,
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = context.text.bodyMedium;
    final l = context.l10n;
    final payment = orderPaymentMeta(l, order.status);
    return _Card(
      title: l.ordersPayment,
      trailing: payment == null ? null : StatusChip(label: payment.label, tone: payment.tone, dense: true),
      child: Column(
        children: [
          _Line(l.ordersItems, PriceText(order.subtotal, style: body)),
          _Line(
            l.ordersShipping,
            !order.shippingCost.isZero
                ? PriceText(order.shippingCost, style: body)
                : Text(order.isPickup ? l.ordersFree : l.ordersShippingTbd, style: body),
          ),
          if (!order.discountAmount.isZero)
            _Line(l.ordersDiscount, Text('−${order.discountAmount.format()}', style: body?.copyWith(color: c.success))),
          Divider(height: Insets.lg, color: c.line),
          _Line(l.ordersTotal, PriceText(order.totalAmount, style: context.text.titleLarge), strong: true),
        ],
      ),
    );
  }
}

/// A row with an icon; long text folds to one line and opens on tap.
class _InfoRow extends StatefulWidget {
  const _InfoRow({required this.icon, required this.text, this.onTap, this.link = false});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final bool link;

  @override
  State<_InfoRow> createState() => _InfoRowState();
}

class _InfoRowState extends State<_InfoRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: Radii.brSm,
      onTap: widget.onTap ?? () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.icon, size: 18, color: c.inkMuted),
            Gap.md,
            Expanded(
              child: Text(
                widget.text,
                maxLines: _open ? null : 1,
                overflow: _open ? null : TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  color: widget.link ? c.brandStrong : c.ink,
                  fontWeight: widget.link ? FontWeight.w600 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final address = [order.shippingAddress, if (!order.isPickup) order.shippingCity]
        .where((s) => s.trim().isNotEmpty)
        .join(', ');
    final point = order.latitude != null && order.longitude != null
        ? LatLng(order.latitude!, order.longitude!)
        : null;
    final phone = order.shippingPhone.replaceAll(' ', '');
    return _Card(
      title: order.isPickup ? context.l10n.ordersPickup : context.l10n.ordersShipping,
      icon: order.isPickup ? Icons.storefront_outlined : Icons.local_shipping_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (address.isNotEmpty) _InfoRow(icon: Icons.place_outlined, text: address),
          if (order.isPickup) _InfoRow(icon: Icons.schedule_rounded, text: context.l10n.checkoutPickupHours),
          if (order.shippingName.isNotEmpty) _InfoRow(icon: Icons.person_outline_rounded, text: order.shippingName),
          if (phone.isNotEmpty)
            _InfoRow(
              icon: Icons.call_outlined,
              text: order.shippingPhone,
              link: true,
              onTap: () => launchUrl(Uri(scheme: 'tel', path: phone)),
            ),
          if (order.trackingNumber.isNotEmpty)
            _InfoRow(
              icon: Icons.local_shipping_outlined,
              text: [order.carrier, order.trackingNumber].where((s) => s.isNotEmpty).join(' · '),
            ),
          if (order.customerNotes.isNotEmpty)
            _InfoRow(icon: Icons.chat_bubble_outline_rounded, text: order.customerNotes),
          if (point != null && !order.isPickup) ...[
            Gap.sm,
            LocationPreview(
              point: point,
              height: 120,
              onTap: () => launchUrl(
                Uri.parse('https://yandex.uz/maps/?pt=${point.longitude},${point.latitude}&z=16&l=map'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget box(Widget child) => Container(
          padding: const EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(color: c.surface, borderRadius: Radii.brLg, border: Border.all(color: c.line)),
          child: child,
        );
    return SkeletonScope(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(context.pagePadding, Insets.sm, context.pagePadding, Insets.xl),
        children: [
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                box(Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(children: [Skeleton.line(width: 150), Spacer(), Skeleton(width: 90, height: 26)]),
                    Gap.lg,
                    Row(
                      children: [
                        for (var i = 0; i < 5; i++)
                          const Expanded(
                            child: Column(children: [
                              Skeleton(width: 32, height: 32, borderRadius: BorderRadius.all(Radius.circular(16))),
                              Gap(6),
                              Skeleton.line(width: 44, height: 10),
                            ]),
                          ),
                      ],
                    ),
                    Gap.lg,
                    const Skeleton(height: 44, borderRadius: Radii.brMd),
                  ],
                )),
                Gap.md,
                box(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Skeleton.line(width: 100, height: 16),
                    Gap.md,
                    for (var i = 0; i < 2; i++)
                      const Padding(
                        padding: EdgeInsets.only(bottom: Insets.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Skeleton(width: 88, height: 88, borderRadius: Radii.brMd),
                            Gap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Skeleton.line(width: 140),
                                  Gap(8),
                                  Skeleton.line(width: 110, height: 18),
                                  Gap(18),
                                  Skeleton.line(width: 160),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
