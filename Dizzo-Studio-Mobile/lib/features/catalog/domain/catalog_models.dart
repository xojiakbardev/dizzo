import 'dart:ui' show Color;

import '../../../core/l10n/app_language.dart';
import '../../../core/utils/json.dart';
import '../../../core/utils/money.dart';

// Mirrors the backend's public catalog (`app/schemas/catalog.py`,
// `Public*`) and the web's `app/types/catalog.ts`. Money and lengths arrive
// as decimal strings. Image fields are absolute URLs.

/// How a design is put on: colour print or laser engraving.
enum PrintMethod {
  uv('uv'),
  engrave('engrave');

  const PrintMethod(this.value);
  final String value;

  /// "Rangli bosma" / "Lazer o‘yma" in the current language.
  String get label => labelIn(l10nNow);

  String labelIn(AppLocalizations l) => switch (this) {
        PrintMethod.uv => l.printMethodUv,
        PrintMethod.engrave => l.printMethodEngrave,
      };

  static PrintMethod? parse(String v) {
    for (final m in values) {
      if (m.value == v) return m;
    }
    return null;
  }
}

/// A variant material's name (null for an unknown code).
String? materialName(AppLocalizations l, String material) => switch (material) {
      'ceramic_glossy' => l.materialCeramicGlossy,
      'ceramic_matte' => l.materialCeramicMatte,
      'glass_clear' => l.materialGlassClear,
      'glass_frosted' => l.materialGlassFrosted,
      'fabric' => l.materialFabric,
      'paper' => l.materialPaper,
      'plastic' => l.materialPlastic,
      'metal' => l.materialMetal,
      'wood' => l.materialWood,
      _ => null,
    };

/// A storefront shelf (`GET /catalog/categories/`).
class Category {
  const Category({required this.slug, required this.name, this.iconSvg = '', this.imageUrl});

  factory Category.fromJson(Json json) => Category(
        slug: json.str('slug'),
        name: json.str('name'),
        iconSvg: json.str('icon_svg'),
        imageUrl: json.strOrNull('image_url'),
      );

  final String slug;
  final String name;

  /// Inline SVG markup (may be empty).
  final String iconSvg;
  final String? imageUrl;
}

/// A product in lists (`GET /catalog/products/`, `PublicProductCard`).
class ProductSummary {
  const ProductSummary({
    required this.slug,
    required this.name,
    required this.coverUrl,
    required this.fromPrice,
    this.isFeatured = false,
    this.category = '',
  });

  factory ProductSummary.fromJson(Json json) => ProductSummary(
        slug: json.str('slug'),
        name: json.str('name'),
        coverUrl: json.strOrNull('cover_url'),
        fromPrice: Money.parse(json['from_price']),
        isFeatured: json.boolean('is_featured'),
        category: json.str('category'),
      );

  final String slug;
  final String name;
  final String? coverUrl;

  /// The cheapest sellable variant and colour.
  final Money fromPrice;
  final bool isFeatured;

  /// A [Category.slug].
  final String category;
}

class SpecItem {
  const SpecItem(this.label, this.value);

  factory SpecItem.fromJson(Json json) => SpecItem(json.str('label'), json.str('value'));

  final String label;
  final String value;
}

/// A clothing size. Out-of-stock sizes are listed but not selectable.
class VariantSize {
  const VariantSize({required this.label, required this.surcharge, required this.isAvailable});

  factory VariantSize.fromJson(Json json) => VariantSize(
        label: json.str('label'),
        surcharge: Money.parse(json['surcharge']),
        isAvailable: json.boolean('is_available', true),
      );

  final String label;
  final Money surcharge;
  final bool isAvailable;
}

/// A colour on sale (`PublicColor`).
class ProductColor {
  const ProductColor({
    required this.id,
    required this.name,
    required this.hex,
    required this.surcharge,
    this.images = const [],
  });

  factory ProductColor.fromJson(Json json) => ProductColor(
        id: json.integer('id'),
        name: json.str('name'),
        hex: json.str('hex', '#FFFFFF'),
        surcharge: Money.parse(json['surcharge']),
        images: json.strings('images'),
      );

  final int id;
  final String name;

  /// "#RRGGBB".
  final String hex;
  final Money surcharge;
  final List<String> images;

  Color get color => parseHexColor(hex);
}

/// A product type on sale (`PublicVariant`): e.g. "Oq krujka 330 ml".
class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.shapeId,
    required this.name,
    this.shortDescription = '',
    this.description = '',
    this.specs = const [],
    required this.basePrice,
    this.methods = const [],
    this.material = '',
    this.images = const [],
    this.colors = const [],
    this.sizes = const [],
  });

  factory ProductVariant.fromJson(Json json) => ProductVariant(
        id: json.integer('id'),
        shapeId: json.integer('shape_id'),
        name: json.str('name'),
        shortDescription: json.str('short_description'),
        description: json.str('description'),
        specs: json.list('specs', SpecItem.fromJson),
        basePrice: Money.parse(json['base_price']),
        methods: [
          for (final m in json.strings('methods')) ?PrintMethod.parse(m),
        ],
        material: json.str('material'),
        images: json.strings('images'),
        colors: json.list('colors', ProductColor.fromJson),
        sizes: json.list('sizes', VariantSize.fromJson),
      );

  final int id;
  final int shapeId;
  final String name;
  final String shortDescription;

  /// Rich text from the admin (safe HTML; older values are plain text),
  /// shown with RichDescription.
  final String description;
  final List<SpecItem> specs;
  final Money basePrice;

  /// What the customer can use on this variant.
  final List<PrintMethod> methods;
  final String material;
  final List<String> images;
  final List<ProductColor> colors;

  /// In display order; empty for products without sizes.
  final List<VariantSize> sizes;

  String get materialLabel => materialLabelIn(l10nNow);

  String materialLabelIn(AppLocalizations l) => materialName(l, material) ?? material;

  ProductColor? colorById(int? id) {
    for (final c in colors) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// 3D/print geometry of a variant. The editor feature reads [raw] for the
/// full structure (areas, anchors, model transform); the shop only needs
/// the basics.
class ProductShape {
  const ProductShape({required this.id, required this.kind, this.modelUrl, this.raw = const {}});

  factory ProductShape.fromJson(Json json) => ProductShape(
        id: json.integer('id'),
        kind: json.str('kind'),
        modelUrl: json.strOrNull('model_url'),
        raw: json,
      );

  final int id;

  /// cylinder | plane | disc | model
  final String kind;
  final String? modelUrl;
  final Json raw;
}

/// `GET /catalog/products/{slug}/` (`PublicProductDetail`).
class ProductDetail {
  const ProductDetail({
    required this.slug,
    required this.name,
    this.coverUrl,
    this.images = const [],
    required this.fromPrice,
    this.variants = const [],
    this.shapes = const [],
  });

  factory ProductDetail.fromJson(Json json) => ProductDetail(
        slug: json.str('slug'),
        name: json.str('name'),
        coverUrl: json.strOrNull('cover_url'),
        images: json.strings('images'),
        fromPrice: Money.parse(json['from_price']),
        variants: json.list('variants', ProductVariant.fromJson),
        shapes: json.list('shapes', ProductShape.fromJson),
      );

  final String slug;
  final String name;
  final String? coverUrl;
  final List<String> images;
  final Money fromPrice;
  final List<ProductVariant> variants;
  final List<ProductShape> shapes;

  ProductVariant? variantById(int? id) {
    for (final v in variants) {
      if (v.id == id) return v;
    }
    return null;
  }

  /// Pictures for the gallery: colour photos, then the variant's, then the
  /// product's, without duplicates.
  List<String> galleryFor(ProductVariant? variant, ProductColor? color) {
    final seen = <String>{};
    return [
      ...?color?.images,
      ...?variant?.images,
      ...images,
      ?coverUrl,
    ].where(seen.add).toList();
  }
}

/// "#ED5124" / "ED5124" / "#fff" → [Color]; white on garbage.
Color parseHexColor(String hex) {
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null || h.length != 8 ? const Color(0xFFFFFFFF) : Color(v);
}
