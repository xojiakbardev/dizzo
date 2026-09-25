import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/presentation/widgets/sign_in_prompt.dart';
import '../data/cart_api.dart';
import '../domain/cart_models.dart';
import 'cart_controller.dart';
import 'widgets/item_parts.dart';
import 'widgets/quantity_stepper.dart';

/// "Savat" tab: the Studio packages in the cart, quantities, and the way to
/// checkout.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  StreamSubscription<ApiException>? _errors;

  @override
  void initState() {
    super.initState();
    _errors = ref.read(cartProvider.notifier).errors.listen((e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    });
  }

  @override
  void dispose() {
    _errors?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(cartProvider);
    try {
      await ref.read(cartProvider.future);
    } catch (_) {}
  }

  Future<void> _clear() async {
    final ok = await confirmSheet(context, title: context.l10n.cartClearConfirm, confirmLabel: context.l10n.cartClear, destructive: true);
    if (!ok || !mounted) return;
    try {
      await ref.read(cartProvider.notifier).clear();
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    }
  }

  void _remove(CartItem item) {
    final cart = ref.read(cartProvider.notifier);
    if (cart.hide(item.uuid) == null) return;
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final snack = messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.cartItemRemoved(item.productName), maxLines: 1, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(label: context.l10n.cartUndo, onPressed: () {}),
      ),
    );
    unawaited(
      snack.closed.then((reason) {
        if (reason == SnackBarClosedReason.action) {
          cart.undoRemove(item.uuid);
        } else {
          unawaited(cart.commitRemove(item.uuid));
        }
      }),
    );
  }

  void _edit(CartItem item) {
    context.push(
      Routes.editor(
        item.productSlug,
        variant: item.variantId,
        color: item.colorId,
        size: item.size,
        design: item.designId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authControllerProvider.select((s) => s.isAuthenticated));
    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.cartTitle)),
        body: SignInPrompt(icon: Icons.shopping_bag_outlined, title: context.l10n.cartSignInPrompt),
      );
    }
    final async = ref.watch(cartProvider);
    final cart = async.value;
    final hasItems = cart != null && !cart.isEmpty;
    final wide = context.isExpanded;

    final body = async.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const CartSkeleton(),
      error: (e, _) => ErrorState(error: e, onRetry: _refresh),
      data: (cart) => cart.isEmpty
          ? RefreshIndicator(
              onRefresh: _refresh,
              child: LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: c.maxHeight,
                    child: EmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: context.l10n.cartEmpty,
                      actionLabel: context.l10n.cartBrowseProducts,
                      onAction: () => context.go(Routes.products),
                    ),
                  ),
                ),
              ),
            )
          : _CartList(
              cart: cart,
              onRefresh: _refresh,
              onRemove: _remove,
              onEdit: _edit,
              side: wide ? _SummaryPanel(cart: cart) : null,
            ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.cartTitle),
        actions: [
          if (hasItems)
            TextButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.delete_sweep_outlined, size: 20),
              label: Text(context.l10n.cartClear),
            ),
          const Gap(Insets.xs),
        ],
      ),
      body: body,
      bottomNavigationBar: hasItems && !wide ? _SummaryBar(cart: cart) : null,
    );
  }
}

class _CartList extends ConsumerWidget {
  const _CartList({
    required this.cart,
    required this.onRefresh,
    required this.onRemove,
    required this.onEdit,
    this.side,
  });

  final Cart cart;
  final Future<void> Function() onRefresh;
  final ValueChanged<CartItem> onRemove;
  final ValueChanged<CartItem> onEdit;
  final Widget? side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final list = RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (cart.blocked)
            SliverPageBody(
              padTop: Insets.sm,
              sliver: SliverToBoxAdapter(
                child: _Banner(
                  icon: Icons.warning_amber_rounded,
                  color: c.warning,
                  text: context.l10n.cartSomeUnavailable,
                ),
              ),
            ),
          SliverPageBody(
            padTop: Insets.sm,
            padBottom: Insets.xl,
            sliver: SliverList.separated(
              itemCount: cart.items.length,
              separatorBuilder: (_, _) => Gap.md,
              itemBuilder: (context, i) {
                final item = cart.items[i];
                return Dismissible(
                  key: ValueKey(item.uuid),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => onRemove(item),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: Insets.xl),
                    decoration: BoxDecoration(color: c.danger, borderRadius: Radii.brLg),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  ),
                  child: CartItemCard(
                    item: item,
                    onQuantity: (q) => ref.read(cartProvider.notifier).setQuantity(item.uuid, q),
                    onRemove: () => onRemove(item),
                    onEdit: item.designId == null ? null : () => onEdit(item),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
    if (side == null) return list;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: list),
        SizedBox(
          width: 360,
          child: Padding(padding: const EdgeInsets.fromLTRB(0, Insets.sm, Insets.xl, Insets.xl), child: side),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.md),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: Radii.brMd),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          Gap.sm,
          Expanded(
            child: Text(text, style: context.text.labelLarge?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

/// One cart item.
class CartItemCard extends StatelessWidget {
  const CartItemCard({super.key, required this.item, required this.onQuantity, required this.onRemove, this.onEdit});

  final CartItem item;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PackageItemCard(
      images: item.mockups,
      dimmed: !item.available,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    item.productName,
                    style: context.text.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              SizedBox(
                width: 32,
                height: 32,
                child: PopupMenuButton<String>(
                  tooltip: context.l10n.cartItemActions,
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  icon: Icon(Icons.more_vert_rounded, color: c.inkMuted),
                  onSelected: (v) => v == 'edit' ? onEdit?.call() : onRemove(),
                  itemBuilder: (_) => [
                    if (onEdit != null)
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.edit_outlined),
                          title: Text(context.l10n.cartEditItem),
                        ),
                      ),
                    PopupMenuItem(
                      value: 'remove',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded, color: c.danger),
                        title: Text(context.l10n.commonDelete, style: TextStyle(color: c.danger)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(2),
          OptionsLine(variant: item.variantName, colorName: item.colorName, color: item.color, size: item.size),
          if (item.printLines.isNotEmpty) ...[Gap.sm, PrintMethodTags(lines: item.printLines)],
          if (!item.available) ...[
            Gap.sm,
            Text(context.l10n.cartItemUnavailable, style: context.text.labelMedium?.copyWith(color: c.danger)),
          ],
          Gap.sm,
          PriceText(item.totalPrice, style: context.text.titleMedium),
          if (item.quantity > 1)
            Text(context.l10n.cartUnitPrice(item.unitPrice.format()), style: context.text.labelSmall?.copyWith(color: c.inkSubtle)),
          Gap.sm,
          QuantityStepper(
            value: item.quantity,
            max: CartApi.maxQuantity,
            onChanged: item.available ? onQuantity : null,
          ),
        ],
      ),
    );
  }
}

String _pieces(BuildContext context, int n) => context.l10n.cartItemsCount(n);

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.cart});

  final Cart cart;

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
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Breakpoints.contentMaxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.pagePadding, Insets.md, context.pagePadding, Insets.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_pieces(context, cart.totalItems), style: context.text.labelMedium?.copyWith(color: c.inkMuted)),
                        PriceText(cart.totalAmount, style: context.text.titleLarge),
                      ],
                    ),
                  ),
                  Gap.md,
                  Flexible(
                    child: AppButton(
                      label: context.l10n.cartCheckout,
                      expand: false,
                      onPressed: cart.blocked ? null : () => context.push(Routes.checkout),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.brLg,
        border: Border.all(color: c.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.cartTotal, style: context.text.titleMedium),
            Gap.md,
            Row(
              children: [
                Expanded(child: Text(_pieces(context, cart.totalItems), style: context.text.bodyMedium)),
                PriceText(cart.subtotal, style: context.text.bodyMedium),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.md),
              child: Divider(height: 1, color: c.line),
            ),
            PriceText(cart.totalAmount, style: context.text.headlineSmall),
            Gap.lg,
            AppButton(label: context.l10n.cartCheckout, onPressed: cart.blocked ? null : () => context.push(Routes.checkout)),
          ],
        ),
      ),
    );
  }
}

/// Loading placeholder shaped like the cart cards.
class CartSkeleton extends StatelessWidget {
  const CartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonScope(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(context.pagePadding, Insets.sm, context.pagePadding, Insets.xl),
        itemCount: 3,
        separatorBuilder: (_, _) => Gap.md,
        itemBuilder: (context, _) => ContentWidth(child: PackageItemCardSkeleton()),
      ),
    );
  }
}
