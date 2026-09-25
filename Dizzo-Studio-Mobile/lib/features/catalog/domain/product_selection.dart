import '../../../core/utils/money.dart';
import 'catalog_models.dart';

/// What the customer picked on a product page: a type, a colour and (on
/// clothing) a size. Mirrors the web page (`pages/products/[slug].vue`):
/// the type and colour default to the first ones, a size is never
/// pre-selected, and the choice lives in the route query.
class ProductSelection {
  const ProductSelection({this.variant, this.color, this.size, this.chosen = false});

  /// The choice for [product] from ids (route query or memory). Unknown ids
  /// fall back to the first type / colour; an unknown or sold-out size is
  /// dropped.
  factory ProductSelection.resolve(
    ProductDetail product, {
    int? variantId,
    int? colorId,
    String? size,
    bool chosen = false,
  }) {
    final variant = product.variantById(variantId) ?? product.variants.firstOrNull;
    final color = variant?.colorById(colorId) ?? variant?.colors.firstOrNull;
    return ProductSelection(
      variant: variant,
      color: color,
      size: _availableSize(variant, size),
      chosen: chosen,
    );
  }

  final ProductVariant? variant;
  final ProductColor? color;

  /// A [VariantSize.label]; null until the customer picks one.
  final String? size;

  /// The customer (or a shared link) made a choice: the page shows the
  /// exact price instead of the product's "from" price.
  final bool chosen;

  static String? _availableSize(ProductVariant? variant, String? label) {
    if (label == null || variant == null) return null;
    return variant.sizes.any((s) => s.label == label && s.isAvailable) ? label : null;
  }

  /// Another type: the colour (by name) and the size carry over when the
  /// new type has them.
  ProductSelection withVariant(ProductVariant next) {
    final sameColor = next.colors.where((c) => c.name == color?.name).firstOrNull;
    return ProductSelection(
      variant: next,
      color: sameColor ?? next.colors.firstOrNull,
      size: _availableSize(next, size),
      chosen: true,
    );
  }

  ProductSelection withColor(ProductColor next) =>
      ProductSelection(variant: variant, color: next, size: size, chosen: true);

  ProductSelection withSize(String next) =>
      ProductSelection(variant: variant, color: color, size: _availableSize(variant, next), chosen: true);

  VariantSize? get sizeOption => variant?.sizes.where((s) => s.label == size).firstOrNull;

  /// The type has sizes and none is picked yet.
  bool get needsSize => (variant?.sizes.isNotEmpty ?? false) && size == null;

  /// Every size of the type is sold out.
  bool get soldOut {
    final sizes = variant?.sizes ?? const <VariantSize>[];
    return sizes.isNotEmpty && !sizes.any((s) => s.isAvailable);
  }

  /// Ready for the editor.
  bool get complete => variant != null && color != null && !needsSize && !soldOut;

  /// The price of this choice before any print surcharge (what the server
  /// quotes without areas): type + colour + size.
  Money priceIn(ProductDetail product) {
    final v = variant;
    if (v == null) return product.fromPrice;
    return v.basePrice + (color?.surcharge ?? Money.zero) + (sizeOption?.surcharge ?? Money.zero);
  }

  /// Route query (`variant`, `color`, `size`); empty until a choice is made
  /// so a bare link stays bare.
  Map<String, String> get query => !chosen
      ? const {}
      : {
          if (variant != null) 'variant': '${variant!.id}',
          if (color != null) 'color': '${color!.id}',
          'size': ?size,
        };

  @override
  bool operator ==(Object other) =>
      other is ProductSelection &&
      other.variant?.id == variant?.id &&
      other.color?.id == color?.id &&
      other.size == size &&
      other.chosen == chosen;

  @override
  int get hashCode => Object.hash(variant?.id, color?.id, size, chosen);
}

/// The product's own pictures (cover first), without duplicates.
List<String> productPictures(ProductDetail product) {
  final seen = <String>{};
  return [?product.coverUrl, ...product.images].where((u) => u.isNotEmpty && seen.add(u)).toList();
}

/// The gallery for a type and colour: the colour's pictures when it has
/// any, else the type's, else the product's. Never mixed, so choosing a
/// colour really shows that colour.
List<String> picturesFor(ProductDetail product, ProductVariant? variant, ProductColor? color) {
  if (color != null && color.images.isNotEmpty) return color.images;
  if (variant != null && variant.images.isNotEmpty) return variant.images;
  return productPictures(product);
}

/// A thumbnail for a type card: its own first picture, else its first
/// colour's, else the product cover.
String? variantThumbnail(ProductDetail product, ProductVariant variant) =>
    picturesFor(product, variant, variant.colors.firstOrNull).firstOrNull;

/// The picture sets the customer is likely to open next from [selection]:
/// every colour of the current type and every other type (with its
/// default colour). The current set is excluded.
List<List<String>> likelyNextPictures(ProductDetail product, ProductSelection selection) {
  final current = picturesFor(product, selection.variant, selection.color);
  final sets = <List<String>>[
    for (final c in selection.variant?.colors ?? const <ProductColor>[])
      picturesFor(product, selection.variant, c),
    for (final v in product.variants)
      if (v.id != selection.variant?.id) picturesFor(product, v, selection.withVariant(v).color),
  ];
  final seen = <String>{current.join('|')};
  return [
    for (final s in sets)
      if (s.isNotEmpty && seen.add(s.join('|'))) s,
  ];
}
