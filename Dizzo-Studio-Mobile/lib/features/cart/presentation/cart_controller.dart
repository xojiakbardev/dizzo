import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/cart_api.dart';
import '../domain/cart_models.dart';
import 'cart_badge.dart';

/// The signed-in customer's cart. Empty for guests.
///
/// Quantity changes and removals show at once; the server's cart replaces
/// the local one when it answers. Failures are reported on [errors] and
/// the cart is reloaded.
class CartController extends AsyncNotifier<Cart> {
  CartApi get _api => ref.read(cartApiProvider);

  final _quantityTimers = <String, Timer>{};
  final _hidden = <String, ({CartItem item, int index})>{};
  final _errors = StreamController<ApiException>.broadcast();
  int _requests = 0;

  /// Failed background changes (quantity, removal), for a snackbar.
  Stream<ApiException> get errors => _errors.stream;

  @override
  Future<Cart> build() async {
    // Other features invalidate cartSummaryProvider after adding to the cart.
    ref.watch(cartSummaryProvider);
    // Item names come in the app language.
    ref.watch(contentLanguageProvider);
    final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
    if (userId == null) {
      for (final t in _quantityTimers.values) {
        t.cancel();
      }
      _quantityTimers.clear();
      _hidden.clear();
      return Cart.empty;
    }
    return _withoutHidden(await _api.fetch());
  }

  Cart _withoutHidden(Cart cart) {
    if (_hidden.isEmpty) return cart;
    return cart.withItems([
      for (final i in cart.items)
        if (!_hidden.containsKey(i.uuid)) i,
    ]);
  }

  void _apply(Cart cart) {
    if (ref.mounted) state = AsyncData(_withoutHidden(cart));
  }

  Future<void> _fail(Object error) async {
    if (!ref.mounted) return;
    _errors.add(ApiException.from(error));
    try {
      _apply(await _api.fetch());
    } catch (_) {}
  }

  /// A cart the server returned elsewhere (e.g. `POST /cart/items/`).
  void replace(Cart cart) => _apply(cart);

  /// Changes an item's quantity now and sends it after a short pause, so
  /// fast stepper taps become one request.
  void setQuantity(String itemUuid, int quantity) {
    final cart = state.value;
    if (cart == null) return;
    final q = quantity.clamp(1, CartApi.maxQuantity);
    state = AsyncData(cart.withItems([for (final i in cart.items) i.uuid == itemUuid ? i.withQuantity(q) : i]));
    _quantityTimers[itemUuid]?.cancel();
    _quantityTimers[itemUuid] = Timer(const Duration(milliseconds: 450), () => _sendQuantity(itemUuid, q));
  }

  Future<void> _sendQuantity(String itemUuid, int quantity) async {
    _quantityTimers.remove(itemUuid);
    if (!ref.mounted) return;
    final request = ++_requests;
    try {
      final cart = await _api.setQuantity(itemUuid, quantity);
      // Newer local changes win; their own answer will follow.
      if (request == _requests && _quantityTimers.isEmpty) _apply(cart);
    } catch (e) {
      await _fail(e);
    }
  }

  /// Hides an item at once; call [commitRemove] or [undoRemove] next.
  CartItem? hide(String itemUuid) {
    final cart = state.value;
    if (cart == null) return null;
    final index = cart.items.indexWhere((i) => i.uuid == itemUuid);
    if (index < 0) return null;
    _quantityTimers.remove(itemUuid)?.cancel();
    _hidden[itemUuid] = (item: cart.items[index], index: index);
    state = AsyncData(_withoutHidden(cart));
    return cart.items[index];
  }

  void undoRemove(String itemUuid) {
    final entry = _hidden.remove(itemUuid);
    final cart = state.value;
    if (entry == null || cart == null || !ref.mounted) return;
    final items = [...cart.items];
    items.insert(entry.index.clamp(0, items.length), entry.item);
    state = AsyncData(cart.withItems(items));
  }

  Future<void> commitRemove(String itemUuid) async {
    if (!_hidden.containsKey(itemUuid)) return;
    try {
      final cart = await _api.remove(itemUuid);
      _hidden.remove(itemUuid);
      _apply(cart);
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.notFound) {
        _hidden.remove(itemUuid); // already gone
        return;
      }
      undoRemove(itemUuid);
      await _fail(e);
    }
  }

  /// Empties the cart. Throws [ApiException].
  Future<void> clear() async {
    final cart = await _api.clear();
    _hidden.clear();
    _apply(cart);
  }
}

final cartProvider = AsyncNotifierProvider<CartController, Cart>(CartController.new);
