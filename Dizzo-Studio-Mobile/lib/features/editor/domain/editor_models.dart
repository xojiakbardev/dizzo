import '../../../core/utils/json.dart';
import '../../../core/utils/money.dart';
import 'design_document.dart';

/// `POST /catalog/quote/` and a design's price (`QuoteOut`).
class Quote {
  const Quote({
    required this.variantId,
    required this.colorId,
    required this.unitPrice,
    this.size,
    this.raw = const {},
  });

  factory Quote.fromJson(Json j) => Quote(
        variantId: j.integer('variant_id'),
        colorId: j.integer('color_id'),
        size: j.strOrNull('size'),
        unitPrice: Money.parse(j['unit_price']),
        raw: j,
      );

  final int variantId;
  final int colorId;
  final String? size;
  final Money unitPrice;
  final Json raw;

  /// The methods' surcharges (the provisional price keeps them).
  double get methodsSurcharge {
    var sum = 0.0;
    for (final m in raw.list('methods', (j) => j)) {
      sum += Money.parse(m['surcharge']).amount;
    }
    return sum;
  }

  bool matches(int? variant, int? color, String? sizeLabel) =>
      variant == variantId && color == colorId && (size ?? '') == (sizeLabel ?? '');
}

/// A gallery design (`GET /catalog/products/{slug}/templates/`).
class DesignTemplate {
  const DesignTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.previewUrl,
    required this.variantIds,
    required this.document,
  });

  factory DesignTemplate.fromJson(Json j) => DesignTemplate(
        id: j.integer('id'),
        name: j.str('name'),
        category: j.str('category'),
        previewUrl: j.str('preview_url'),
        variantIds: [
          for (final v in (j['variant_ids'] as List?) ?? const []) if (v is num) v.toInt(),
        ],
        document: DesignDocument.fromJson(j.obj('document')),
      );

  final int id;
  final String name;
  final String category;
  final String previewUrl;
  final List<int> variantIds;
  final DesignDocument document;
}

/// `GET/POST/PUT /studio/designs/…` (`DesignOut`).
class SavedDesign {
  const SavedDesign({
    required this.id,
    required this.version,
    required this.productSlug,
    required this.variantId,
    required this.colorId,
    required this.document,
    this.quote,
  });

  factory SavedDesign.fromJson(Json j) => SavedDesign(
        id: j.str('id'),
        version: j.integer('version', 1),
        productSlug: j.str('product_slug'),
        variantId: j.integer('variant_id'),
        colorId: j.integer('color_id'),
        document: DesignDocument.fromJson(j.obj('document')),
        quote: j.objOrNull('quote') == null ? null : Quote.fromJson(j.obj('quote')),
      );

  final String id;
  final int version;
  final String productSlug;
  final int variantId;
  final int colorId;
  final DesignDocument document;
  final Quote? quote;
}

/// A sticker in the web's `public/stickers/index.json` / `more.json`.
class StickerItem {
  const StickerItem({
    required this.name,
    required this.group,
    required this.label,
    required this.keywords,
    required this.w,
    required this.h,
    this.rank,
    this.pack,
    this.mono = false,
  });

  factory StickerItem.fromJson(Json j) => StickerItem(
        name: j.str('n'),
        group: j.str('g'),
        label: j.str('l'),
        keywords: j.str('k'),
        w: j.dbl('w', 32),
        h: j.dbl('h', 32),
        rank: j.intOrNull('p'),
        pack: j.strOrNull('pk'),
        mono: j['m'] == 1,
      );

  final String name;
  final String group;
  final String label;
  final String keywords;
  final double w;
  final double h;
  final int? rank;
  final String? pack;
  final bool mono;
}

class StickerGroup {
  const StickerGroup(this.key, this.label);
  final String key;
  final String label;
}

class StickerIndex {
  const StickerIndex(this.groups, this.items);

  factory StickerIndex.fromJson(Json j) => StickerIndex(
        j.list('groups', (g) => StickerGroup(g.str('key'), g.str('label'))),
        j.list('items', StickerItem.fromJson),
      );

  final List<StickerGroup> groups;
  final List<StickerItem> items;

  StickerIndex merge(StickerIndex other) =>
      StickerIndex([...groups, ...other.groups], [...items, ...other.items]);
}

// Icons live in packs; their names carry the set's prefix.
final _packed = RegExp('^(mdi|tb|ph|fc)-');
final _mono = RegExp('^(mdi|tb|ph)-');
bool isPackedSticker(String name) => _packed.hasMatch(name);

/// A single-colour sticker: recoloured like an icon.
bool isMonoSticker(String name) => _mono.hasMatch(name);

/// What the engine's `load` / `setAppearance` returns (only what the app uses).
class EngineProduct {
  const EngineProduct({
    required this.variantId,
    required this.colorId,
    required this.colorHex,
    required this.material,
    required this.methods,
    required this.engraveTint,
    required this.shapeChanged,
    required this.areas,
    required this.surfaceColors,
  });

  factory EngineProduct.fromJson(Json j) {
    final areas = j.list('areas', (a) => a);
    return EngineProduct(
      variantId: j.integer('variantId'),
      colorId: j.integer('colorId'),
      colorHex: j.str('colorHex', '#ffffff'),
      material: j.str('material'),
      methods: j.strings('methods'),
      engraveTint: j.str('engraveTint', '#3f3f46'),
      shapeChanged: j.boolean('shapeChanged'),
      areas: [for (final a in areas) a.obj('raw')],
      surfaceColors: {for (final a in areas) a.str('key'): a.str('surfaceColor', '#ffffff')},
    );
  }

  final int variantId;
  final int colorId;
  final String colorHex;
  final String material;
  final List<String> methods;
  final String engraveTint;
  final bool shapeChanged;

  /// Each area's `raw` PrintArea JSON.
  final List<Json> areas;
  final Map<String, String> surfaceColors;
}

/// The engraving colour of each material when the engine hasn't said
/// (the web's ENGRAVE_TINT).
const engraveTints = <String, String>{
  'ceramic_glossy': '#6f6a66',
  'ceramic_matte': '#f1ede6',
  'glass_clear': '#f2f2f2',
  'glass_frosted': '#f7f7f7',
  'fabric': '#3f3f46',
  'paper': '#3f3f46',
  'plastic': '#e4e4e7',
  'metal': '#d4d4d8',
  'wood': '#4a2c17',
};
