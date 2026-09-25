import 'package:dizzo/core/utils/money.dart';
import 'package:dizzo/features/catalog/domain/catalog_models.dart';
import 'package:dizzo/features/catalog/presentation/catalog_providers.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

final productJson = <String, dynamic>{
  'slug': 'krujka',
  'name': 'Krujka',
  'description': '<p>Keramik <b>krujka</b></p>',
  'cover_url': 'https://cdn.test/cover.png',
  'images': ['https://cdn.test/p1.png', 'https://cdn.test/cover.png'],
  'from_price': '49000.00',
  'variants': [
    {
      'id': 7,
      'shape_id': 3,
      'name': 'Oq krujka 330 ml',
      'short_description': '',
      'description': '',
      'specs': [
        {'label': 'Hajmi', 'value': '330 ml'},
      ],
      'base_price': '49000.00',
      'methods': ['uv', 'engrave', 'unknown'],
      'material': 'ceramic_glossy',
      'images': ['https://cdn.test/v7.png'],
      'colors': [
        {
          'id': 11,
          'name': 'Oq',
          'hex': '#ffffff',
          'surcharge': '0.00',
          'images': ['https://cdn.test/c11.png'],
        },
        {'id': 12, 'name': 'Qora', 'hex': '#111827', 'surcharge': '5000.00', 'images': []},
      ],
      'sizes': [
        {'label': 'M', 'surcharge': '0.00', 'is_available': true},
        {'label': 'XXL', 'surcharge': '10000.00', 'is_available': false},
      ],
    },
  ],
  'shapes': [
    {
      'id': 3,
      'kind': 'cylinder',
      'dims': {'diameter_mm': '82.00', 'height_mm': '95.00', 'handle': true, 'handle_gap_mm': '40.00'},
      'model_url': null,
      'model_transform': null,
      'mm_per_unit': null,
      'areas': [],
    },
  ],
};

void main() {
  test('ProductDetail parses the public product payload', () {
    final p = ProductDetail.fromJson(productJson);
    expect(p.slug, 'krujka');
    expect(p.fromPrice.amount, 49000);
    final v = p.variants.single;
    expect(v.methods, [PrintMethod.uv, PrintMethod.engrave]);
    expect(v.materialLabel, 'Keramika, yaltiroq');
    expect(v.colors.last.surcharge.amount, 5000);
    expect(v.colors.last.color, const Color(0xFF111827));
    expect(v.sizes.last.isAvailable, isFalse);
    expect(v.specs.single.value, '330 ml');
    expect(p.shapes.single.kind, 'cylinder');
    expect(p.shapes.single.raw['dims'], isA<Map<String, dynamic>>());
  });

  test('gallery puts colour photos first and removes duplicates', () {
    final p = ProductDetail.fromJson(productJson);
    final v = p.variants.single;
    expect(p.galleryFor(v, v.colors.first), [
      'https://cdn.test/c11.png',
      'https://cdn.test/v7.png',
      'https://cdn.test/p1.png',
      'https://cdn.test/cover.png',
    ]);
  });

  test('ProductSummary tolerates missing optional fields', () {
    final s = ProductSummary.fromJson({'slug': 'x', 'name': 'X', 'from_price': 1000});
    expect(s.coverUrl, isNull);
    expect(s.fromPrice.amount, 1000);
    expect(s.isFeatured, isFalse);
  });

  test('parseHexColor handles short and invalid values', () {
    expect(parseHexColor('#fff'), const Color(0xFFFFFFFF));
    expect(parseHexColor('ED5124'), const Color(0xFFED5124));
    expect(parseHexColor('nope'), const Color(0xFFFFFFFF));
  });

  group('catalog filter', () {
    const items = [
      ProductSummary(slug: 'a', name: 'O‘g‘il bola futbolkasi', coverUrl: null, fromPrice: Money.zero, category: 'kiyim'),
      ProductSummary(slug: 'b', name: 'Krujka', coverUrl: null, fromPrice: Money.zero, category: 'idish'),
    ];

    test('search ignores case and Uzbek apostrophes', () {
      expect(filterProducts(items, const CatalogFilter(query: "og'il")).map((p) => p.slug), ['a']);
      expect(filterProducts(items, const CatalogFilter(query: 'KRUJ')).map((p) => p.slug), ['b']);
    });

    test('category narrows the list', () {
      expect(filterProducts(items, const CatalogFilter(category: 'idish')).map((p) => p.slug), ['b']);
      expect(filterProducts(items, const CatalogFilter()).length, 2);
    });
  });
}
