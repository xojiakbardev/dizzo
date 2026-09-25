import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cart_controller.dart';

/// A refresh signal for the cart. After adding to the cart elsewhere
/// (editor, product page), call `ref.invalidate(cartSummaryProvider)`:
/// [cartProvider] watches it and reloads `GET /cart/`. If you already have
/// the server's cart (`POST /cart/items/` answers with it), prefer
/// `ref.read(cartProvider.notifier).replace(Cart.fromJson(...))`.
final cartSummaryProvider = Provider<Object>((ref) => Object());

/// Pieces in the cart, for the Savat tab badge. 0 for guests and while the
/// cart is loading or offline.
final cartCountProvider = Provider<int>((ref) => ref.watch(cartProvider).value?.totalItems ?? 0);
