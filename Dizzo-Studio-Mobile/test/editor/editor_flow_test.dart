import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:dizzo/core/network/api_client.dart';
import 'package:dizzo/core/storage/token_storage.dart';
import 'package:dizzo/core/theme/app_theme.dart';
import 'package:dizzo/core/utils/json.dart';
import 'package:dizzo/features/editor/data/draft_store.dart';
import 'package:dizzo/features/editor/data/engine_bridge.dart';
import 'package:dizzo/features/editor/data/engine_protocol.dart';
import 'package:dizzo/features/editor/data/media_uploader.dart';
import 'package:dizzo/features/editor/data/sticker_library.dart';
import 'package:dizzo/features/editor/domain/design_document.dart';
import 'package:dizzo/features/editor/domain/editor_models.dart';
import 'package:dizzo/features/editor/domain/print_area.dart';
import 'package:dizzo/features/editor/presentation/canvas/design_canvas.dart';
import 'package:dizzo/features/editor/presentation/canvas/design_painter.dart';
import 'package:dizzo/features/editor/presentation/editor_controller.dart';
import 'package:dizzo/features/editor/presentation/editor_screen.dart';
import 'package:dizzo/features/editor/presentation/editor_state.dart';
import 'package:dizzo/features/editor/presentation/render/asset_store.dart';
import 'package:dizzo/features/editor/presentation/render/design_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';
import '../helpers/l10n.dart';

final _area = {
  'id': 1,
  'key': 'front',
  'name': 'Old tomoni',
  'width_mm': '200.00',
  'height_mm': '90.00',
  'anchor': <String, Object?>{},
  'camera': null,
  'placement_note': '',
  'sort_order': 0,
  'pair_key': null,
  'pair_mirror': false,
  'methods': [
    {
      'method': 'uv',
      'zone_x_mm': '5.00',
      'zone_y_mm': '5.00',
      'zone_w_mm': '190.00',
      'zone_h_mm': '80.00',
      'max_width_mm': null,
      'max_height_mm': null,
      'strip_width_mm': null,
      'min_font_mm': null,
      'colors_allowed': true,
      'dpi': 300,
    },
    {
      'method': 'engrave',
      'zone_x_mm': '5.00',
      'zone_y_mm': '5.00',
      'zone_w_mm': '190.00',
      'zone_h_mm': '80.00',
      'max_width_mm': null,
      'max_height_mm': null,
      'strip_width_mm': '60.00',
      'min_font_mm': null,
      'colors_allowed': false,
      'dpi': 600,
    },
  ],
};

final _product = {
  'slug': 'krujka',
  'name': 'Krujka',
  'description': '',
  'cover_url': null,
  'images': <String>[],
  'from_price': '49000.00',
  'variants': [
    {
      'id': 12,
      'shape_id': 5,
      'name': 'Oq krujka',
      'base_price': '49000.00',
      'methods': ['uv'],
      'material': 'ceramic_glossy',
      'images': <String>[],
      'sizes': <Object>[],
      'colors': [
        {'id': 40, 'name': 'Oq', 'hex': '#ffffff', 'surcharge': '0.00', 'images': <String>[]},
      ],
    },
    {
      'id': 13,
      'shape_id': 5,
      'name': 'Metall krujka',
      'base_price': '59000.00',
      'methods': ['engrave'],
      'material': 'steel',
      'images': <String>[],
      'sizes': <Object>[],
      'colors': [
        {'id': 41, 'name': 'Kumush', 'hex': '#c0c0c0', 'surcharge': '0.00', 'images': <String>[]},
      ],
    },
  ],
  'shapes': [
    {'id': 5, 'kind': 'cylinder', 'model_url': null, 'areas': [_area]},
  ],
};

Json _quote(String price) => {
      'variant_id': 12,
      'color_id': 40,
      'base_price': '49000.00',
      'color_surcharge': '0.00',
      'size': null,
      'size_surcharge': '0.00',
      'methods': <Object>[],
      'unit_price': price,
      'quantity': 1,
      'total': price,
    };

class FakeEngine implements DesignEngine {
  final calls = <String>[];
  final _status = ValueNotifier(EngineStatus.ready);

  @override
  ValueListenable<EngineStatus> get status => _status;
  @override
  Stream<EngineEvent> get events => const Stream.empty();
  @override
  Widget buildView() => const SizedBox.expand();

  EngineProduct get _product => EngineProduct.fromJson({
        'variantId': 12,
        'colorId': 40,
        'colorHex': '#ffffff',
        'material': 'ceramic_glossy',
        'methods': ['uv'],
        'engraveTint': '#6f6a66',
        'areas': [
          {'key': 'front', 'surfaceColor': '#fafafa', 'raw': _area},
        ],
      });

  @override
  Future<EngineProduct> load({required String productSlug, int? variantId, int? colorId}) async {
    calls.add('load');
    return _product;
  }

  @override
  Future<EngineProduct> setAppearance({int? variantId, int? colorId}) async {
    calls.add('setAppearance');
    return _product;
  }

  @override
  Future<Json> setDocument(DesignDocument document) async {
    calls.add('setDocument');
    return {};
  }

  @override
  Future<void> showArea(String key) async => calls.add('showArea');
  @override
  Future<void> resetView() async {}
  @override
  Future<List<String>> captureFrames({int size = 900, List<String>? areas}) async {
    calls.add('captureFrames');
    return ['data:image/jpeg;base64,${base64Encode([1, 2, 3])}'];
  }

  @override
  Future<String> captureView({int size = 1600}) async => 'data:image/png;base64,AA==';
  @override
  Future<List<EnginePrintFile>> renderPrintFiles() async {
    calls.add('renderPrintFiles');
    return [
      EnginePrintFile(area: 'front', method: 'uv', dataUrl: 'data:image/png;base64,${base64Encode([9, 9])}', bytes: 2),
    ];
  }

  @override
  Future<Map<String, String>> measure() async => {'uv': '12.50'};
  @override
  Future<void> reload() async {}
  @override
  void dispose() {}
}

class Backend {
  final requests = <String>[];
  final bodies = <String, Object?>{};
  var cartConflicts = 1;

  FakeAdapter adapter() => FakeAdapter((o) async {
        final key = '${o.method} ${o.uri.path.replaceFirst('/api', '')}';
        requests.add(key);
        bodies[key] = o.data;
        switch (key) {
          case 'GET /catalog/products/krujka/':
            return FakeResponse(200, _product);
          case 'GET /catalog/products/krujka/templates/':
            return const FakeResponse(200, <Object>[]);
          case 'POST /catalog/quote/':
            return FakeResponse(200, _quote('61000.00'));
          case 'GET /auth/me':
            return const FakeResponse(200, {'id': 5, 'email': 'ali@dizzo.uz', 'first_name': 'Ali', 'full_name': 'Ali'});
          case 'POST /studio/designs/':
            return FakeResponse(201, {
              'id': 'd1',
              'version': 1,
              'product_slug': 'krujka',
              'variant_id': 12,
              'color_id': 40,
              'document': (o.data as Map)['document'],
              'quote': _quote('61000.00'),
            });
          case 'POST /media/uploads/':
            final n = requests.where((r) => r == key).length;
            return FakeResponse(201, {
              'id': 'm$n',
              'upload_url': 'https://storage.test/put/m$n',
              'upload_method': 'PUT',
              'upload_headers': {'Content-Type': (o.data as Map)['content_type']},
              'url': 'https://cdn.test/m$n',
              'expires_in': 600,
            });
          case 'PUT /put/m1' || 'PUT /put/m2' || 'PUT /put/m3':
            return const FakeResponse(200);
          case 'POST /cart/items/':
            if (cartConflicts-- > 0) {
              return FakeResponse(409, {'detail': 'Narx qayta hisoblandi', 'quote': _quote('65000.00')});
            }
            return const FakeResponse(201, {'items': <Object>[], 'total_items': 1});
        }
        if (key.startsWith('POST /media/') && key.endsWith('/complete/')) {
          final id = o.uri.pathSegments[o.uri.pathSegments.length - 3];
          return FakeResponse(200, {'id': id, 'url': 'https://cdn.test/$id', 'guest': false});
        }
        return const FakeResponse(404, {'detail': 'Topilmadi'});
      });
}

Future<ProviderContainer> _container(Backend backend, {bool signedIn = false}) async {
  final dir = await Directory.systemTemp.createTemp('editor_test');
  addTearDown(() => dir.delete(recursive: true).then((_) {}, onError: (_) {}));
  final dio = fakeDio(backend.adapter());
  final engine = FakeEngine();
  final container = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        MemoryTokenStorage(signedIn ? const TokenPair(access: 'a', refresh: 'r') : null),
      ),
      dioProvider.overrideWithValue(dio),
      designEngineProvider.overrideWithValue(engine),
      draftStoreProvider.overrideWithValue(DraftStore(dir)),
      mediaUploaderProvider.overrideWithValue(MediaUploader(dio, dio)),
      stickerLibraryProvider.overrideWithValue(StickerLibrary(Dio()..httpClientAdapter = backend.adapter())),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  return container;
}

const _args = EditorArgs(slug: 'krujka');
const _engraved = EditorArgs(slug: 'krujka', variantId: 13);

Future<EditorState> _ready(ProviderContainer c, [EditorArgs args = _args]) async {
  final sub = c.listen(editorControllerProvider(args), (_, _) {});
  addTearDown(sub.close);
  for (var i = 0; i < 50 && c.read(editorControllerProvider(args)).phase == EditorPhase.loading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return c.read(editorControllerProvider(args));
}

DesignPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<DesignPainter>()
    .single;

/// The canvas alone on the engraved variant, with one text in the middle.
Future<({ProviderContainer container, EditorController ctrl, String id})> _pumpCanvas(
  WidgetTester tester, {
  bool snapping = true,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final backend = Backend();
  final dir = Directory.systemTemp.createTempSync('editor_strip');
  addTearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });
  final dio = fakeDio(backend.adapter());
  final container = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
      dioProvider.overrideWithValue(dio),
      designEngineProvider.overrideWithValue(FakeEngine()),
      draftStoreProvider.overrideWithValue(DraftStore(dir)),
      stickerLibraryProvider.overrideWithValue(StickerLibrary(dio)),
    ],
    retry: (_, _) => null,
  );
  final assets = AssetStore(container.read(stickerLibraryProvider));
  addTearDown(assets.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: testLocale,
      localizationsDelegates: l10nDelegates,
      supportedLocales: l10nLocales,
      theme: AppTheme.light,
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) {
            final s = ref.watch(editorControllerProvider(_engraved));
            if (s.phase != EditorPhase.ready) return const SizedBox.expand();
            return DesignCanvas(
              state: s,
              controller: ref.read(editorControllerProvider(_engraved).notifier),
              assets: assets,
              snapping: snapping,
              onEditLayer: (_) {},
              onLayerMenu: (_, _) {},
            );
          },
        ),
      ),
    ),
  ));
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  final ctrl = container.read(editorControllerProvider(_engraved).notifier);
  final id = (await tester.runAsync(() => ctrl.addText(content: 'Salom')))!;
  await tester.pump();
  return (container: container, ctrl: ctrl, id: id);
}

Future<void> _disposeCanvas(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox());
  container.dispose();
  await tester.pump(const Duration(seconds: 2));
}

/// The strip the canvas draws and clips with right now.
Box _drawnStrip(WidgetTester tester) {
  final p = _painter(tester);
  return printZone(p.area, p.area.method('engrave')!, p.allLayers, p.strips);
}

void main() {
  setUpAll(() => designFontsEnabled = false);

  test('loads the product, adds text, undoes and redoes', () async {
    final c = await _container(Backend());
    final s = await _ready(c);
    expect(s.phase, EditorPhase.ready);
    expect(s.selectedArea, 'front');
    expect(s.areas.single.widthMm, 200);
    final ctrl = c.read(editorControllerProvider(_args).notifier);
    final id = await ctrl.addText(content: 'Salom');
    expect(id, isNotNull);
    var now = c.read(editorControllerProvider(_args));
    final layer = now.doc.byId(id)!;
    expect(layer.text!.sizeMm, textSizeMm);
    expect(layer.x, 100); // the zone's centre
    expect(now.canUndo, isTrue);
    ctrl.undo();
    expect(c.read(editorControllerProvider(_args)).doc.layers, isEmpty);
    ctrl.redo();
    now = c.read(editorControllerProvider(_args));
    expect(now.doc.layers.single.id, id);
    // Problems and the engine's surface colour are known.
    expect(now.problemTotal, 0);
    expect(now.surfaceHex, '#fafafa');
  });

  test('a guest save keeps a draft and prices the design', () async {
    final backend = Backend();
    final c = await _container(backend);
    await _ready(c);
    final ctrl = c.read(editorControllerProvider(_args).notifier);
    ctrl.addGraphic('shape', 'heart');
    await ctrl.save();
    expect(backend.requests, contains('POST /catalog/quote/'));
    expect((backend.bodies['POST /catalog/quote/']! as Map)['areas_cm2'], {'uv': '12.50'});
    final s = c.read(editorControllerProvider(_args));
    expect(s.price!.amount, 61000);
    final draft = await c.read(draftStoreProvider).read('krujka');
    expect(draft!.document.layers.single.graphic!.name, 'heart');
  });

  test('add to cart: print files, mockups, confirmed new price', () async {
    final backend = Backend();
    final c = await _container(backend, signedIn: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await _ready(c);
    final ctrl = c.read(editorControllerProvider(_args).notifier);
    // Nothing placed yet: refused.
    await ctrl.addToCart();
    expect(c.read(editorControllerProvider(_args)).cart, isA<CartFailed>());
    ctrl.resetCart();

    ctrl.addGraphic('shape', 'star');
    await ctrl.addToCart();
    final flow = c.read(editorControllerProvider(_args)).cart;
    expect(flow, isA<CartConfirm>());
    expect((flow as CartConfirm).quote.unitPrice.raw, '65000.00');
    final item = backend.bodies['POST /cart/items/']! as Map;
    expect(item['files'], [
      {'area': 'front', 'method': 'uv', 'media_id': 'm1'},
    ]);
    expect(item['mockups'], ['m2']);
    expect(item['design_id'], 'd1');
    expect(item['expected_unit_price'], '61000.00');
    await ctrl.confirmPrice();
    expect(c.read(editorControllerProvider(_args)).cart, isA<CartDone>());
    expect((backend.bodies['POST /cart/items/']! as Map)['expected_unit_price'], '65000.00');
  });

  test('the laser strip follows moves in the same undo step', () async {
    final c = await _container(Backend());
    final s = await _ready(c, _engraved);
    expect(s.designMethod, 'engrave');
    final ctrl = c.read(editorControllerProvider(_engraved).notifier);
    EditorState now() => c.read(editorControllerProvider(_engraved));
    final id = (await ctrl.addText(content: 'Salom'))!;
    final l = now().doc.byId(id)!;
    final half = l.w / 2;
    expect(l.x, 100);
    // The first engraved layer starts a strip centred on it.
    expect(now().doc.strips, const [PrintStrip(area: 'front', method: 'engrave', x: 70)]);
    expect(now().doc.toJson()['strips'], [
      {'area': 'front', 'method': 'engrave', 'x_mm': 70},
    ]);
    // Inside the strip: it stays.
    ctrl.updateLayer(l.copyWith(x: 130 - half));
    expect(now().doc.strips.single.x, 70);
    // Past its edge: pushed.
    ctrl.updateLayer(now().doc.byId(id)!.copyWith(x: 160));
    final pushed = now().doc.strips.single.x;
    expect(pushed, closeTo(160 + half - 60, 1e-9));
    // Centring goes to the middle of the strip, which stays.
    ctrl.centerLayer(id);
    expect(now().doc.byId(id)!.x, closeTo(pushed + 30, 1e-9));
    expect(now().doc.strips.single.x, pushed);
    // Undo brings back the layer and the strip together.
    ctrl.undo();
    ctrl.undo();
    expect(now().doc.byId(id)!.x, 130 - half);
    expect(now().doc.strips.single.x, 70);
    ctrl.redo();
    expect(now().doc.strips.single.x, closeTo(pushed, 1e-9));
    // A copy goes inside the current strip, which stays.
    ctrl.duplicate(id);
    final both = now().doc.layers;
    expect(both, hasLength(2));
    expect(now().doc.strips.single.x, closeTo(pushed, 1e-9));
    for (final x in both) {
      expect(layerBox(x).x0, greaterThanOrEqualTo(pushed - 1e-9));
      expect(layerBox(x).x1, lessThanOrEqualTo(pushed + 60 + 1e-9));
    }
    // The last engraved layer takes the strip away.
    for (final x in [...both]) {
      ctrl.removeLayer(x.id);
    }
    expect(now().doc.strips, isEmpty);
    expect(now().doc.toJson()['strips'], isEmpty);
  });

  testWidgets('the drawn strip follows a live drag and stays where it was pushed', (tester) async {
    final (:container, :ctrl, :id) = await _pumpCanvas(tester);
    EditorState now() => container.read(editorControllerProvider(_engraved));
    expect(_drawnStrip(tester), const Box(70, 5, 130, 85));

    final view = _painter(tester).view;
    final l = now().doc.byId(id)!;
    final origin = tester.getTopLeft(find.byType(DesignCanvas));
    final gesture = await tester.startGesture(origin + view.toPx(l.x, l.y));
    await tester.pump(const Duration(milliseconds: 20));
    Layer live() => _painter(tester).layers.single;
    // Step right, 5 mm a time, past the strip's right edge.
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(Offset(5 * view.scale, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final box = layerBox(live());
      final strip = _drawnStrip(tester);
      // In lock-step once touching, still otherwise; never outside the zone.
      expect(strip.x1, closeTo(math.min(195, math.max(130, box.x1)), 1e-6));
      // Nothing is committed until the finger lifts.
      expect(now().doc.strips.single.x, 70);
    }
    final pushed = _drawnStrip(tester);
    expect(pushed.x0, greaterThan(70));
    // Back left a little: the strip stays where it was pushed.
    await gesture.moveBy(Offset(-3 * view.scale, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(_drawnStrip(tester), pushed);
    await gesture.up();
    await tester.pump();
    // Committed as drawn, in one undo step.
    expect(now().doc.strips.single.x, closeTo(pushed.x0, 1e-9));
    expect(_drawnStrip(tester), pushed);
    ctrl.undo();
    await tester.pump();
    expect(now().doc.strips.single.x, 70);
    expect(now().doc.byId(id)!.x, l.x);
    expect(_drawnStrip(tester), const Box(70, 5, 130, 85));

    // A purely vertical drag (snapping on) never moves the strip.
    final vertical = await tester.startGesture(origin + view.toPx(l.x, l.y));
    await tester.pump(const Duration(milliseconds: 20));
    for (var i = 0; i < 8; i++) {
      await vertical.moveBy(Offset(0, (i < 4 ? 6 : -9) * view.scale));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_drawnStrip(tester), const Box(70, 5, 130, 85));
    }
    await vertical.up();
    await tester.pump();
    expect(now().doc.strips.single.x, 70);

    await _disposeCanvas(tester, container);
  });

  testWidgets('a clamped drag stays anchored to the finger', (tester) async {
    final (:container, ctrl: _, :id) = await _pumpCanvas(tester, snapping: false);
    EditorState now() => container.read(editorControllerProvider(_engraved));
    final view = _painter(tester).view;
    final l = now().doc.byId(id)!;
    final half = l.w / 2;
    // Grabbed off-centre: the offset to the finger is kept.
    final grab = view.toPx(l.x + half / 2, l.y);
    final origin = tester.getTopLeft(find.byType(DesignCanvas));
    final gesture = await tester.startGesture(origin + grab);
    await tester.pump(const Duration(milliseconds: 20));
    Layer live() => _painter(tester).layers.single;
    // Far past the zone's right edge: held at it, the strip at the end of its travel.
    for (var i = 0; i < 16; i++) {
      await gesture.moveBy(Offset(10 * view.scale, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(layerBox(live()).x1, closeTo(195, 1e-6));
    expect(_drawnStrip(tester).x1, closeTo(195, 1e-6));
    // Back: nothing moves until the finger is over the layer's grab point again, then it follows exactly.
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(Offset(-10 * view.scale, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // The finger is 160 - 120 = 40 mm right of where it went down.
    expect(live().x, closeTo(l.x + 40, 1e-6));
    // The strip was pushed back only as far as the layer's left edge took it.
    expect(_drawnStrip(tester).x0, closeTo(math.min(135, l.x + 40 - half), 1e-6));
    await gesture.up();
    await tester.pump();
    expect(now().doc.byId(id)!.x, closeTo(l.x + 40, 1e-6));
    await _disposeCanvas(tester, container);
  });

  testWidgets('the screen shows the tools and adds a heading', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final backend = Backend();
    final dir = Directory.systemTemp.createTempSync('editor_widget');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    final dio = fakeDio(backend.adapter());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
        dioProvider.overrideWithValue(dio),
        designEngineProvider.overrideWithValue(FakeEngine()),
        draftStoreProvider.overrideWithValue(DraftStore(dir)),
        stickerLibraryProvider.overrideWithValue(StickerLibrary(dio)),
      ],
      retry: (_, _) => null,
      child: MaterialApp(
        locale: testLocale,
        localizationsDelegates: l10nDelegates,
        supportedLocales: l10nLocales,
        theme: AppTheme.light, home: const EditorScreen(slug: 'krujka')),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Krujka'), findsOneWidget);
    expect(find.text('Savatga'), findsOneWidget);
    await tester.tap(find.text('Matn'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Sarlavha'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // The heading is on the design and selected: its actions show.
    expect(find.text('Sozlash'), findsWidgets);
    expect(find.text('O‘chirish'), findsOneWidget);
    await tester.ensureVisible(find.text('O‘chirish'));
    await tester.pump();
    await tester.tap(find.text('O‘chirish'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Elementlar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
