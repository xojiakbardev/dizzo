import 'package:dizzo/core/network/api_client.dart';
import 'package:dizzo/core/router/routes.dart';
import 'package:dizzo/core/theme/app_theme.dart';
import 'package:dizzo/core/widgets/widgets.dart';
import 'package:dizzo/features/catalog/domain/catalog_models.dart';
import 'package:dizzo/features/catalog/domain/product_selection.dart';
import 'package:dizzo/features/catalog/presentation/product_3d_screen.dart';
import 'package:dizzo/features/catalog/presentation/product_screen.dart';
import 'package:dizzo/features/catalog/presentation/widgets/image_gallery.dart';
import 'package:dizzo/features/editor/data/engine_bridge.dart';
import 'package:dizzo/features/editor/domain/editor_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/fake_api.dart';
import 'helpers/l10n.dart';

Map<String, dynamic> _color(int id, String name, String hex, [List<String> images = const []]) =>
    {'id': id, 'name': name, 'hex': hex, 'surcharge': id == 2 ? '5000.00' : '0.00', 'images': images};

final _productJson = <String, dynamic>{
  'slug': 'futbolka',
  'name': 'Futbolka',
  'cover_url': 'https://cdn.test/cover.png',
  'images': <String>[],
  'from_price': '100000.00',
  'variants': [
    {
      'id': 1,
      'shape_id': 10,
      'name': 'Oq',
      'short_description': '',
      'description': '<p>Paxta futbolka</p>',
      'specs': [
        {'label': 'Material', 'value': 'Paxta'},
      ],
      'base_price': '100000.00',
      'methods': ['uv'],
      'material': 'fabric',
      'images': ['https://cdn.test/v1a.png', 'https://cdn.test/v1b.png'],
      'colors': [
        _color(1, 'Oq', '#ffffff', ['https://cdn.test/c1a.png', 'https://cdn.test/c1b.png']),
        _color(2, 'Qizil', '#d7262b'),
      ],
      'sizes': [
        {'label': 'S', 'surcharge': '0.00', 'is_available': true},
        {'label': 'M', 'surcharge': '0.00', 'is_available': false},
        {'label': 'XL', 'surcharge': '10000.00', 'is_available': true},
      ],
    },
    {
      'id': 2,
      'shape_id': 11,
      'name': 'Qora',
      'short_description': '',
      'description': '',
      'specs': <Object>[],
      'base_price': '120000.00',
      'methods': ['uv', 'engrave'],
      'material': '',
      'images': <String>[],
      'colors': [_color(3, 'Qora', '#111111')],
      'sizes': <Object>[],
    },
  ],
  'shapes': [
    {'id': 10, 'kind': 'plane', 'model_url': null},
    {'id': 11, 'kind': 'model', 'model_url': null},
  ],
};

ProductDetail get _product => ProductDetail.fromJson(_productJson);

FakeAdapter _backend() => routedAdapter({
      'GET /catalog/products/futbolka/': (_) => _productJson,
      'GET /catalog/products/': (_) => <Object>[],
      'POST /catalog/quote/': (o) {
        final body = o.data as Map;
        final price = body['size'] == 'XL' ? '777000.00' : '555000.00';
        return {'unit_price': price};
      },
    });

/// The pictures the gallery is showing (its newest set).
List<String> _shown(WidgetTester tester) => tester.widget<ImageGallery>(find.byType(ImageGallery)).images;

Future<GoRouter> _pump(WidgetTester tester, {String location = '/product/futbolka'}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
      // As in app_router.dart.
      GoRoute(
        path: Routes.productPattern,
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return ProductScreen(
            slug: state.pathParameters['slug']!,
            variantId: int.tryParse(q['variant'] ?? ''),
            colorId: int.tryParse(q['color'] ?? ''),
            size: q['size'],
          );
        },
      ),
      GoRoute(
        path: Routes.editorPattern,
        builder: (_, state) => Scaffold(body: Text('editor:${state.uri}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [dioProvider.overrideWithValue(fakeDio(_backend()))],
    retry: (_, _) => null,
    child: MaterialApp.router(
      locale: testLocale,
      localizationsDelegates: l10nDelegates,
      supportedLocales: l10nLocales,
      theme: AppTheme.light, routerConfig: router),
  ));
  await _settle(tester);
  return router;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tapText(WidgetTester tester, String text, {Finder? within}) async {
  final finder = within == null ? find.text(text) : find.descendant(of: within, matching: find.text(text));
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await _settle(tester);
}

class _Engine extends Fake implements DesignEngine {
  final loads = <String>[];
  final _status = ValueNotifier(EngineStatus.ready);
  bool disposed = false;

  @override
  ValueListenable<EngineStatus> get status => _status;

  @override
  Widget buildView() => const ColoredBox(color: Color(0xFF00FF00), child: Text('webview'));

  @override
  Future<EngineProduct> load({required String productSlug, int? variantId, int? colorId}) async {
    loads.add('$productSlug/$variantId/$colorId');
    return EngineProduct.fromJson({'variantId': variantId, 'colorId': colorId});
  }

  @override
  void dispose() => disposed = true;
}

void main() {
  group('picture logic', () {
    test('colour pictures, else the type\'s, else the product\'s, never mixed', () {
      final p = _product;
      final white = p.variants[0];
      expect(picturesFor(p, white, white.colors[0]), ['https://cdn.test/c1a.png', 'https://cdn.test/c1b.png']);
      expect(picturesFor(p, white, white.colors[1]), ['https://cdn.test/v1a.png', 'https://cdn.test/v1b.png']);
      final black = p.variants[1];
      expect(picturesFor(p, black, black.colors[0]), ['https://cdn.test/cover.png']);
      expect(variantThumbnail(p, black), 'https://cdn.test/cover.png');
      expect(variantThumbnail(p, white), 'https://cdn.test/c1a.png');
    });

    test('likely next sets skip the current one and duplicates', () {
      final p = _product;
      final sel = ProductSelection.resolve(p);
      expect(likelyNextPictures(p, sel), [
        ['https://cdn.test/v1a.png', 'https://cdn.test/v1b.png'],
        ['https://cdn.test/cover.png'],
      ]);
    });
  });

  group('selection', () {
    test('defaults to the first type and colour and never picks a size', () {
      final sel = ProductSelection.resolve(_product);
      expect(sel.variant?.id, 1);
      expect(sel.color?.id, 1);
      expect(sel.size, isNull);
      expect(sel.needsSize, isTrue);
      expect(sel.complete, isFalse);
      expect(sel.query, isEmpty);
    });

    test('route ids are honoured; unknown ids and sold-out sizes fall back', () {
      final p = _product;
      final sel = ProductSelection.resolve(p, variantId: 1, colorId: 2, size: 'XL', chosen: true);
      expect(sel.color?.name, 'Qizil');
      expect(sel.priceIn(p).amount, 100000 + 5000 + 10000);
      expect(sel.query, {'variant': '1', 'color': '2', 'size': 'XL'});
      final bad = ProductSelection.resolve(p, variantId: 99, colorId: 99, size: 'M');
      expect(bad.variant?.id, 1);
      expect(bad.color?.id, 1);
      expect(bad.size, isNull);
    });

    test('changing the type keeps the colour by name and drops a missing size', () {
      final p = _product;
      final sel = ProductSelection.resolve(p, size: 'S').withVariant(p.variants[1]);
      expect(sel.color?.id, 3);
      expect(sel.size, isNull);
      expect(sel.needsSize, isFalse);
      expect(sel.complete, isTrue);
    });

    test('Routes.product carries the choice', () {
      expect(Routes.product('futbolka'), '/product/futbolka');
      expect(
        Routes.product('futbolka', query: {'variant': '1', 'color': '2', 'size': 'XL'}),
        '/product/futbolka?variant=1&color=2&size=XL',
      );
    });
  });

  testWidgets('pictures follow the chosen colour and type', (tester) async {
    await _pump(tester);
    expect(find.text('Futbolka'), findsWidgets);
    expect(_shown(tester), ['https://cdn.test/c1a.png', 'https://cdn.test/c1b.png']);

    // A colour without pictures shows the type's.
    await _tapText(tester, 'Qizil');
    expect(_shown(tester), ['https://cdn.test/v1a.png', 'https://cdn.test/v1b.png']);

    // A type without pictures shows the product's.
    await _tapText(tester, 'Qora', within: find.byType(ListView));
    expect(_shown(tester), ['https://cdn.test/cover.png']);

    // Back to the white type: "Qora" isn't one of its colours, so its first
    // colour (with photos) is chosen.
    await _tapText(tester, 'Oq', within: find.byType(ListView));
    expect(_shown(tester), ['https://cdn.test/c1a.png', 'https://cdn.test/c1b.png']);
  });

  testWidgets('switching pictures cross-fades and keeps the position', (tester) async {
    await _pump(tester);
    final state = tester.state<ImageGalleryState>(find.byType(ImageGallery));
    await tester.drag(find.byType(PageView).first, const Offset(-500, 0));
    await _settle(tester);
    expect(state.index, 1);

    await _tapText(tester, 'Qizil');
    // Both sets are on screen mid-fade, the new one opens on picture 2.
    expect(state.index, 1);
    await tester.pump(Motion.normal);
    await tester.pump();
    expect(find.byType(PageView), findsOneWidget);
    expect(state.index, 1);

    // A set with fewer pictures clamps.
    await _tapText(tester, 'Qora', within: find.byType(ListView));
    expect(state.index, 0);
  });

  testWidgets('the choice goes to the route, the price and the editor', (tester) async {
    final router = await _pump(tester);
    // Bare link: the product's "from" price.
    expect(find.textContaining('dan'), findsWidgets);

    await _tapText(tester, 'Qizil');
    expect(router.state.uri.toString(), '/product/futbolka?variant=1&color=2');
    // The server's quote replaces the page's own sum.
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(find.textContaining('555 000'), findsWidgets);

    // Without a size the editor doesn't open.
    await _tapText(tester, 'Dizayn qilish');
    expect(find.text('O‘lchamni tanlang'), findsOneWidget);
    expect(find.textContaining('editor:'), findsNothing);

    // A sold-out size can't be picked.
    await _tapText(tester, 'M');
    expect(router.state.uri.queryParameters['size'], isNull);

    await _tapText(tester, 'XL');
    expect(router.state.uri.toString(), '/product/futbolka?variant=1&color=2&size=XL');

    await _tapText(tester, 'Dizayn qilish');
    await _settle(tester);
    expect(find.text('editor:/editor/futbolka?variant=1&color=2&size=XL'), findsOneWidget);

    // Coming back: the same choice.
    router.pop();
    await _settle(tester);
    expect(router.state.uri.toString(), '/product/futbolka?variant=1&color=2&size=XL');
    expect(_shown(tester), ['https://cdn.test/v1a.png', 'https://cdn.test/v1b.png']);
  });

  testWidgets('a shared link opens with its choice; a later visit remembers the last one', (tester) async {
    final router = await _pump(tester, location: '/product/futbolka?variant=2&color=3');
    expect(_shown(tester), ['https://cdn.test/cover.png']);
    expect(find.text('Qora'), findsWidgets);

    await _tapText(tester, 'Oq', within: find.byType(ListView));
    expect(router.state.uri.toString(), '/product/futbolka?variant=1&color=1');

    // Leave and open the bare product again.
    router.go('/');
    await tester.pumpAndSettle();
    router.go(Routes.product('futbolka'));
    await _settle(tester);
    expect(_shown(tester), ['https://cdn.test/c1a.png', 'https://cdn.test/c1b.png']);
    expect(router.state.uri.toString(), '/product/futbolka?variant=1&color=1');
  });

  testWidgets('3D button only where the type has a model', (tester) async {
    await _pump(tester);
    expect(find.byTooltip('3D ko‘rinish'), findsOneWidget); // plane shape
    await _tapText(tester, 'Qora', within: find.byType(ListView));
    expect(find.byTooltip('3D ko‘rinish'), findsNothing); // model without a file
  });

  testWidgets('tablet: gallery and details side by side', (tester) async {
    tester.view.physicalSize = const Size(1200, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/product/futbolka',
      routes: [
        GoRoute(
          path: Routes.productPattern,
          builder: (_, state) => ProductScreen(slug: state.pathParameters['slug']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [dioProvider.overrideWithValue(fakeDio(_backend()))],
      retry: (_, _) => null,
      child: MaterialApp.router(
        locale: testLocale,
        localizationsDelegates: l10nDelegates,
        supportedLocales: l10nLocales,
        theme: AppTheme.light, routerConfig: router),
    ));
    await _settle(tester);
    final gallery = tester.getRect(find.byType(ImageGallery));
    final title = tester.getRect(find.text('Dizayn qilish'));
    expect(title.left, greaterThan(gallery.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a picture opens full screen and closes', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(ImageGallery));
    await _settle(tester);
    expect(find.byType(ImageViewer), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Yopish'));
    await _settle(tester);
    expect(find.byType(ImageViewer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('3D view loads the chosen type and colour and frees the engine', (tester) async {
    final engine = _Engine();
    await tester.pumpWidget(MaterialApp(
      locale: testLocale,
      localizationsDelegates: l10nDelegates,
      supportedLocales: l10nLocales,
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => Product3dScreen(
              slug: 'futbolka',
              title: 'Futbolka',
              variantId: 1,
              colorId: 2,
              engineFactory: () => engine,
            ),
          )),
          child: const Text('open'),
        ),
      ),
    ));
    expect(engine.loads, isEmpty);
    await tester.tap(find.text('open'));
    await _settle(tester);
    expect(engine.loads, ['futbolka/1/2']);
    expect(find.text('webview'), findsOneWidget);
    // The loader stays its minimum time, then fades out.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(BrandLoader), findsNothing);
    await tester.tap(find.byType(BackButton));
    await _settle(tester);
    expect(engine.disposed, isTrue);
  });
}
