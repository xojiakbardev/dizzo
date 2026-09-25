import 'dart:ui' show Color;

import '../../../core/utils/json.dart';
import '../../../core/utils/money.dart';
import '../../catalog/domain/catalog_models.dart';

// Mirrors the backend's `CartOut` / `CartItemOut` (app/schemas/design.py)
// and the web's `app/types/commerce.ts`.

/// One print method on an item, with the painted area it is priced by.
class PrintLine {
  const PrintLine({required this.method, required this.areaCm2});

  factory PrintLine.fromJson(Json json) =>
      PrintLine(method: PrintMethod.parse(json.str('method')) ?? PrintMethod.uv, areaCm2: json.dbl('area_cm2'));

  final PrintMethod method;
  final double areaCm2;
}

/// A frozen package built in the Studio.
class CartItem {
  const CartItem({
    required this.uuid,
    required this.productSlug,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.designId,
    this.variantId,
    this.variantName = '',
    this.colorId,
    this.colorName = '',
    this.colorHex = '',
    this.size = '',
    this.printLines = const [],
    this.mockups = const [],
    this.available = true,
  });

  factory CartItem.fromJson(Json json) {
    final quote = json.obj('quote');
    var lines = quote.list('methods', PrintLine.fromJson);
    if (lines.isEmpty) {
      // Older packages: fall back to the print files' methods.
      final seen = <PrintMethod>{};
      lines = [
        for (final f in json.list('files', (f) => f))
          if (PrintMethod.parse(f.str('method')) case final m? when seen.add(m))
            PrintLine(method: m, areaCm2: f.dbl('painted_cm2')),
      ];
    }
    return CartItem(
      uuid: json.str('uuid'),
      designId: json.strOrNull('design_id'),
      productSlug: json.str('product_slug'),
      productName: json.str('product_name'),
      variantId: json.intOrNull('variant_id'),
      variantName: json.str('variant_name'),
      colorId: json.intOrNull('color_id'),
      colorName: json.str('color_name'),
      colorHex: json.str('color_hex'),
      size: json.str('size'),
      quantity: json.integer('quantity', 1),
      unitPrice: Money.parse(json['unit_price']),
      totalPrice: Money.parse(json['total_price']),
      printLines: lines,
      mockups: json.strings('mockups'),
      available: json.boolean('available', true),
    );
  }

  final String uuid;
  final String? designId;
  final String productSlug;
  final String productName;
  final int? variantId;
  final String variantName;
  final int? colorId;
  final String colorName;
  final String colorHex;

  /// Empty on products without sizes.
  final String size;
  final int quantity;
  final Money unitPrice;
  final Money totalPrice;
  final List<PrintLine> printLines;
  final List<String> mockups;

  /// Still on sale; checkout is blocked otherwise.
  final bool available;

  Color? get color => colorHex.isEmpty ? null : parseHexColor(colorHex);

  /// "Oq krujka · Qizil · XL"
  String get optionsLine => [variantName, colorName, size].where((s) => s.isNotEmpty).join(' · ');

  /// For an optimistic quantity change (the server's answer replaces it).
  CartItem withQuantity(int value) => CartItem(
    uuid: uuid,
    designId: designId,
    productSlug: productSlug,
    productName: productName,
    variantId: variantId,
    variantName: variantName,
    colorId: colorId,
    colorName: colorName,
    colorHex: colorHex,
    size: size,
    quantity: value,
    unitPrice: unitPrice,
    totalPrice: unitPrice * value,
    printLines: printLines,
    mockups: mockups,
    available: available,
  );
}

class Cart {
  const Cart({
    this.uuid = '',
    this.items = const [],
    this.totalItems = 0,
    this.subtotal = Money.zero,
    this.totalAmount = Money.zero,
    this.blocked = false,
  });

  factory Cart.fromJson(Json json) => Cart(
    uuid: json.str('uuid'),
    items: json.list('items', CartItem.fromJson),
    totalItems: json.integer('total_items'),
    subtotal: Money.parse(json['subtotal']),
    totalAmount: Money.parse(json['total_amount']),
    blocked: json.boolean('blocked'),
  );

  static const empty = Cart();

  final String uuid;
  final List<CartItem> items;

  /// Pieces (sum of quantities), for the tab badge.
  final int totalItems;
  final Money subtotal;
  final Money totalAmount;

  /// Some item went off sale: checkout is blocked until it is removed.
  final bool blocked;

  bool get isEmpty => items.isEmpty;

  /// The same cart with [next] items and totals recomputed on the device
  /// (optimistic updates only; the server's cart replaces it).
  Cart withItems(List<CartItem> next) {
    final sum = next.fold<Money>(Money.zero, (a, i) => a + i.totalPrice);
    return Cart(
      uuid: uuid,
      items: next,
      totalItems: next.fold(0, (a, i) => a + i.quantity),
      subtotal: sum,
      totalAmount: sum,
      blocked: next.any((i) => !i.available),
    );
  }
}
