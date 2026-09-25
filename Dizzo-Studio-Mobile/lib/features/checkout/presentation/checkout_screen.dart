import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cart/domain/cart_models.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../cart/presentation/widgets/mockup_gallery.dart';
import '../../orders/data/orders_api.dart';
import '../../orders/domain/order_models.dart';
import '../../orders/domain/order_status.dart';
import '../../orders/presentation/orders_providers.dart';
import '../../orders/presentation/widgets/status_chip.dart';
import '../../profile/presentation/widgets/sign_in_prompt.dart';
import '../data/geocoder.dart';
import '../domain/uz_phone.dart';
import 'address_picker_screen.dart';
import 'widgets/location_map.dart';

/// Where "Kelib olib ketish" orders are collected (the web's utils/pickup.ts).
abstract final class PickupPoint {
  static String name(AppLocalizations l) => l.checkoutPickupName;
  static String address(AppLocalizations l) => l.checkoutPickupAddress;
  static String hours(AppLocalizations l) => l.checkoutPickupHours;

  /// What the order stores: always Uzbek, for the operators.
  static String get serverAddress {
    final uz = lookupAppLocalizations(AppLanguage.uz.locale);
    return '${name(uz)}, ${address(uz)}';
  }
}

/// "Rasmiylashtirish": contact, delivery or pickup, a note and the order's
/// contents. No payment: the operator calls to confirm.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController(text: UzPhone.prefix);
  final _address = TextEditingController();
  final _note = TextEditingController();
  String _method = DeliveryMethod.delivery;
  PickedAddress? _point;
  bool _prefilled = false;
  bool _submitting = false;

  /// The current checkout attempt's Idempotency-Key: kept for retries after
  /// a network or server error, new after a success or a refusal (4xx).
  String? _checkoutKey;
  String? _error;
  Map<String, String> _fieldErrors = const {};
  CheckoutResult? _result;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  void _prefill() {
    final user = ref.read(currentUserProvider);
    if (_prefilled || user == null || user.id == 0) return;
    _prefilled = true;
    if (_name.text.isEmpty) _name.text = user.displayName == user.email ? '' : user.displayName;
    if (UzPhone.localDigits(_phone.text).isEmpty && user.phoneNumber.isNotEmpty) {
      _phone.text = UzPhone.format(user.phoneNumber);
    }
  }

  Future<void> _pickAddress() async {
    final p = _point;
    final picked = await pickDeliveryAddress(context, initial: p == null ? null : LatLng(p.latitude, p.longitude));
    if (picked == null || !mounted) return;
    setState(() {
      _point = picked;
      _address.text = picked.address;
      _fieldErrors = {..._fieldErrors}..remove('shipping_address');
    });
  }

  double _round(double v) => double.parse(v.toStringAsFixed(6));

  Future<void> _submit(Cart cart) async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    final pickup = _method == DeliveryMethod.pickup;
    final body = <String, Object?>{
      'contact_name': _name.text.trim(),
      'contact_email': user?.email ?? '',
      'contact_phone': UzPhone.format(_phone.text),
      'delivery_method': _method,
      'latitude': pickup || _point == null ? null : _round(_point!.latitude),
      'longitude': pickup || _point == null ? null : _round(_point!.longitude),
      'shipping_address': pickup ? PickupPoint.serverAddress : _address.text.trim(),
      'shipping_city': pickup ? 'Toshkent' : (_point?.city ?? 'Toshkent'),
      'shipping_state': pickup ? 'Toshkent' : (_point?.state ?? 'Toshkent'),
      'customer_notes': _note.text.trim(),
    };
    setState(() => _submitting = true);
    try {
      final key = _checkoutKey ??= newIdempotencyKey();
      final result = await ref.read(ordersApiProvider).checkout(body, idempotencyKey: key);
      _checkoutKey = null;
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      ref.read(cartProvider.notifier).replace(Cart.empty);
      ref.invalidateOrders();
      setState(() => _result = result);
    } on ApiException catch (e) {
      final retryable = e.isNetwork || e.kind == ApiErrorKind.server || e.kind == ApiErrorKind.unknown;
      if (!retryable) _checkoutKey = null;
      if (!mounted) return;
      setState(() {
        _fieldErrors = e.fieldErrors;
        _error = e.message;
      });
      // Prices changed or something went off sale: show the fresh cart.
      if (e.kind == ApiErrorKind.conflict) ref.invalidate(cartProvider);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authControllerProvider.select((s) => s.isAuthenticated));
    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.checkoutTitle)),
        body: SignInPrompt(icon: Icons.local_shipping_outlined, title: context.l10n.checkoutSignInPrompt),
      );
    }
    if (_result != null) return _SuccessView(result: _result!);
    ref.listen(currentUserProvider, (_, _) => _prefill());
    _prefill();

    final cartAsync = ref.watch(cartProvider);
    final cart = cartAsync.value;
    final ready = cart != null && !cart.isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.checkoutTitle)),
      body: cartAsync.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const _CheckoutSkeleton(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(cartProvider)),
        data: (cart) {
          if (cart.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: context.l10n.checkoutCartEmpty,
              actionLabel: context.l10n.checkoutChooseProduct,
              onAction: () => context.go(Routes.products),
            );
          }
          final form = _buildForm(context);
          final summary = _Summary(cart: cart, pickup: _method == DeliveryMethod.pickup);
          return Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.fromLTRB(context.pagePadding, Insets.sm, context.pagePadding, Insets.xxl),
              children: [
                ContentWidth(
                  child: context.isExpanded
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: form),
                            Gap.lg,
                            Expanded(flex: 2, child: summary),
                          ],
                        )
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: Column(children: [form, Gap.md, summary]),
                        ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: ready
          ? _SubmitBar(
              total: cart.totalAmount,
              blocked: cart.blocked,
              busy: _submitting,
              onSubmit: () => _submit(cart),
            )
          : null,
    );
  }

  Widget _buildForm(BuildContext context) {
    final c = context.colors;
    final l = context.l10n;
    final cart = ref.watch(cartProvider).value;
    final delivery = _method == DeliveryMethod.delivery;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          _InlineAlert(text: _error!, color: c.danger, icon: Icons.error_outline_rounded),
          Gap.md,
        ],
        if (cart?.blocked ?? false) ...[
          _InlineAlert(text: l.checkoutSomeUnavailable, color: c.warning, icon: Icons.warning_amber_rounded),
          Gap.md,
        ],
        _Card(
          step: 1,
          title: l.checkoutContactTitle,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: l.checkoutNameLabel,
                  counterText: '',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  errorText: _fieldErrors['contact_name'],
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? l.checkoutNameRequired : null,
              ),
              Gap.md,
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: const [UzPhoneFormatter()],
                decoration: InputDecoration(
                  labelText: l.checkoutPhoneLabel,
                  prefixIcon: const Icon(Icons.phone_outlined),
                  errorText: _fieldErrors['contact_phone'],
                ),
                validator: (v) => UzPhone.isComplete(v ?? '') ? null : l.checkoutPhoneIncomplete,
              ),
            ],
          ),
        ),
        Gap.md,
        _Card(
          step: 2,
          title: l.checkoutMethodTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MethodOption(
                      icon: Icons.local_shipping_outlined,
                      label: l.checkoutDelivery,
                      selected: delivery,
                      onTap: () => setState(() => _method = DeliveryMethod.delivery),
                    ),
                  ),
                  Gap.sm,
                  Expanded(
                    child: _MethodOption(
                      icon: Icons.storefront_outlined,
                      label: l.checkoutPickup,
                      selected: !delivery,
                      onTap: () => setState(() => _method = DeliveryMethod.pickup),
                    ),
                  ),
                ],
              ),
              Gap.lg,
              AnimatedSize(
                duration: Motion.normal,
                alignment: Alignment.topCenter,
                child: delivery ? _deliveryFields(context) : const _PickupInfo(),
              ),
            ],
          ),
        ),
        Gap.md,
        _Card(
          step: 3,
          title: l.checkoutNoteTitle,
          child: TextFormField(
            controller: _note,
            minLines: 2,
            maxLines: 5,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.checkoutNoteLabel, alignLabelWithHint: true, counterText: ''),
          ),
        ),
      ],
    );
  }

  Widget _deliveryFields(BuildContext context) {
    final c = context.colors;
    final l = context.l10n;
    final p = _point;
    return Column(
      key: const ValueKey('delivery'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p != null)
          Stack(
            children: [
              LocationPreview(point: LatLng(p.latitude, p.longitude), height: 150, onTap: _pickAddress),
              Positioned(
                right: 8,
                bottom: 8,
                child: FilledButton.tonalIcon(
                  onPressed: _pickAddress,
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                  label: Text(l.checkoutChangeLocation),
                ),
              ),
            ],
          )
        else
          OutlinedButton.icon(
            onPressed: _pickAddress,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(64),
              foregroundColor: c.brandStrong,
            ),
            icon: const Icon(Icons.map_outlined),
            label: Text(l.checkoutPickOnMap),
          ),
        Gap.md,
        TextFormField(
          controller: _address,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          autofillHints: const [AutofillHints.fullStreetAddress],
          decoration: InputDecoration(
            labelText: l.checkoutAddressLabel,
            hintText: l.checkoutAddressHint,
            counterText: '',
            prefixIcon: const Icon(Icons.place_outlined),
            errorText: _fieldErrors['shipping_address'],
          ),
          validator: (v) =>
              _method == DeliveryMethod.delivery && (v ?? '').trim().isEmpty && _point == null ? l.checkoutAddressRequired : null,
        ),
      ],
    );
  }
}

class _InlineAlert extends StatelessWidget {
  const _InlineAlert({required this.text, required this.color, required this.icon});

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: Radii.brMd),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          Gap.sm,
          Expanded(child: Text(text, style: context.text.bodyMedium?.copyWith(color: color))),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.step, required this.title, required this.child});

  final int step;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(color: c.surface, borderRadius: Radii.brLg, border: Border.all(color: c.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.brandStrong, shape: BoxShape.circle),
                child: Text('$step', style: context.text.labelMedium?.copyWith(color: Colors.white)),
              ),
              Gap.sm,
              Expanded(child: Text(title, style: context.text.titleMedium)),
            ],
          ),
          Gap.lg,
          child,
        ],
      ),
    );
  }
}

class _MethodOption extends StatelessWidget {
  const _MethodOption({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: Radii.brMd,
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.md),
          decoration: BoxDecoration(
            color: selected ? c.brand.withValues(alpha: 0.08) : c.surface,
            borderRadius: Radii.brMd,
            border: Border.all(color: selected ? c.brand : c.line, width: selected ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? c.brand : c.inkMuted),
              const Gap(6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: context.text.labelLarge?.copyWith(color: selected ? c.ink : c.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickupInfo extends StatelessWidget {
  const _PickupInfo();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final muted = context.text.bodySmall?.copyWith(color: c.inkMuted);
    return Container(
      key: const ValueKey('pickup'),
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(color: c.plate, borderRadius: Radii.brMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.place_outlined, color: c.brand),
          Gap.md,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(PickupPoint.name(context.l10n), style: context.text.titleSmall),
                const Gap(2),
                Text(PickupPoint.address(context.l10n), style: muted),
                Text(PickupPoint.hours(context.l10n), style: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.cart, required this.pickup});

  final Cart cart;
  final bool pickup;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = context.text.bodyMedium;
    final muted = context.text.bodySmall?.copyWith(color: c.inkMuted);
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(color: c.surface, borderRadius: Radii.brLg, border: Border.all(color: c.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(l.checkoutSummaryTitle, style: context.text.titleMedium)),
              Text(l.checkoutItemsCount(cart.totalItems), style: context.text.labelLarge?.copyWith(color: c.inkMuted)),
            ],
          ),
          Gap.md,
          for (final item in cart.items)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox.square(
                    dimension: 56,
                    child: MockupGallery(images: item.mockups, borderRadius: Radii.brSm),
                  ),
                  Gap.md,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.productName, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          [item.optionsLine, l.checkoutQuantity(item.quantity)].where((s) => s.isNotEmpty).join(' · '),
                          style: muted,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Gap.sm,
                  PriceText(item.totalPrice, style: context.text.titleSmall),
                ],
              ),
            ),
          Divider(height: 1, color: c.line),
          Gap.md,
          Row(
            children: [
              Expanded(child: Text(l.checkoutProducts, style: body?.copyWith(color: c.inkMuted))),
              PriceText(cart.subtotal, style: body),
            ],
          ),
          Gap.sm,
          Row(
            children: [
              Expanded(child: Text(pickup ? l.checkoutPickup : l.checkoutDelivery, style: body?.copyWith(color: c.inkMuted))),
              Text(pickup ? l.checkoutFree : l.checkoutOperatorQuotes, style: body),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.total, required this.blocked, required this.busy, required this.onSubmit});

  final Money total;
  final bool blocked;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
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
                        Text(context.l10n.checkoutTotal, style: context.text.labelMedium?.copyWith(color: c.inkMuted)),
                        PriceText(total, style: context.text.titleLarge),
                      ],
                    ),
                  ),
                  Gap.md,
                  Flexible(
                    child: AppButton(
                      label: context.l10n.checkoutPlaceOrder,
                      expand: false,
                      loading: busy,
                      onPressed: blocked || busy ? null : onSubmit,
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

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.result});

  final CheckoutResult result;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = context.l10n;
    final meta = orderStatusMeta(l, result.status);
    final pictures = [
      for (final item in result.order?.items ?? const <OrderItem>[])
        if (item.mockups.isNotEmpty) item.mockups.first,
    ];
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.pagePadding + Insets.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Breakpoints.formMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.6, end: 1),
                    duration: Motion.slow,
                    curve: Curves.easeOutBack,
                    builder: (_, v, child) => Transform.scale(scale: v, child: child),
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(color: c.success.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(Icons.check_rounded, size: 48, color: c.success),
                    ),
                  ),
                ),
                Gap.xl,
                Text(l.checkoutSuccessTitle, textAlign: TextAlign.center, style: context.text.headlineSmall),
                Gap.lg,
                if (pictures.isNotEmpty) ...[
                  Center(child: MockupStrip(images: pictures, size: 56)),
                  Gap.lg,
                ],
                Container(
                  padding: const EdgeInsets.all(Insets.lg),
                  decoration: BoxDecoration(color: c.surface, borderRadius: Radii.brLg, border: Border.all(color: c.line)),
                  child: Column(
                    children: [
                      _kv(context, l.checkoutOrderNumber, Text(l.ordersNumber(result.orderNumber), style: context.text.titleMedium)),
                      Gap.md,
                      _kv(context, l.checkoutTotal, PriceText(result.totalAmount, style: context.text.titleMedium)),
                      Gap.md,
                      _kv(context, l.checkoutStatus, StatusChip(label: meta.label, tone: meta.tone, dense: true)),
                    ],
                  ),
                ),
                Gap.xl,
                AppButton(
                  label: l.checkoutViewOrder,
                  onPressed: () => context.pushReplacement(Routes.order(result.orderNumber)),
                ),
                Gap.sm,
                AppButton(
                  label: l.checkoutHome,
                  variant: AppButtonVariant.ghost,
                  onPressed: () => context.go(Routes.home),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, Widget v) => Row(
        children: [
          Expanded(child: Text(k, style: context.text.bodyMedium?.copyWith(color: context.colors.inkMuted))),
          Flexible(child: Align(alignment: Alignment.centerRight, child: v)),
        ],
      );
}

class _CheckoutSkeleton extends StatelessWidget {
  const _CheckoutSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget card(List<Widget> children) => Container(
          padding: const EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(color: c.surface, borderRadius: Radii.brLg, border: Border.all(color: c.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        );
    const title = Row(children: [
      Skeleton(width: 24, height: 24, borderRadius: BorderRadius.all(Radius.circular(12))),
      Gap(8),
      Skeleton.line(width: 120, height: 16),
    ]);
    const field = Skeleton(height: 52, borderRadius: Radii.brMd);
    return SkeletonScope(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(context.pagePadding, Insets.sm, context.pagePadding, Insets.xl),
        children: [
          card(const [title, Gap(16), field, Gap(12), field]),
          Gap.md,
          card(const [
            title,
            Gap(16),
            Row(children: [
              Expanded(child: Skeleton(height: 72, borderRadius: Radii.brMd)),
              Gap(8),
              Expanded(child: Skeleton(height: 72, borderRadius: Radii.brMd)),
            ]),
            Gap(16),
            Skeleton(height: 64, borderRadius: Radii.brMd),
            Gap(12),
            field,
          ]),
          Gap.md,
          card(const [title, Gap(16), Skeleton(height: 72, borderRadius: Radii.brMd)]),
        ],
      ),
    );
  }
}
