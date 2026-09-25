import 'dart:convert';

import 'package:dizzo/features/editor/domain/design_document.dart';
import 'package:dizzo/features/editor/domain/dial.dart';
import 'package:dizzo/features/editor/domain/history.dart';
import 'package:dizzo/features/editor/domain/print_area.dart';
import 'package:flutter_test/flutter_test.dart';

// A document as the web Studio writes it (JSON.stringify of a
// DesignDocument): whole numbers without ".0", optional keys left out.
const webSample =
    '{"version":1,"layers":['
    '{"id":"dial-m1x2","area":"front","method":"uv","kind":"dial","x_mm":100,"y_mm":100,"w_mm":180,"h_mm":180,"rotation":0,'
    '"dial":{"font":"Montserrat","size_mm":14,"color":"#111827","bold":true,"italic":false,"numerals":"roman","ticks":true,"face":"round","corner_radius_mm":0},"locked":"system"},'
    '{"id":"lmabc12345","area":"front","method":"uv","kind":"text","x_mm":100,"y_mm":45.5,"w_mm":61.24,"h_mm":20.16,"rotation":-12.5,'
    '"text":{"content":"Dizzo\\nO‘zbek","font":"Playfair Display","size_mm":14,"color":"#d24419","align":"center","bold":true,"italic":false}},'
    '{"id":"lmabc12346","area":"front","method":"uv","kind":"image","x_mm":60,"y_mm":120,"w_mm":80.5,"h_mm":60.375,"rotation":90,'
    '"image":{"media_id":"5b0c3f0e-1111-2222-3333-444455556666","url":"https://cdn.dizzo.uz/u/1/a.png","px_w":1600,"px_h":1200},"locked":"user"},'
    '{"id":"lmabc12347","area":null,"method":"uv","kind":"graphic","x_mm":10,"y_mm":10,"w_mm":20,"h_mm":20,"rotation":0,'
    '"graphic":{"library":"sticker","name":"red-heart","color":"#000000"}}'
    '],"links":[{"source":"left","target":"right"}],"strips":[]}';

const _areaJson = {
  'id': 1,
  'key': 'front',
  'name': 'Old tomoni',
  'width_mm': '200.00',
  'height_mm': '100.00',
  'anchor': <String, Object?>{},
  'sort_order': 0,
  'pair_key': null,
  'pair_mirror': false,
  'methods': [
    {
      'method': 'uv',
      'zone_x_mm': '10.00',
      'zone_y_mm': '10.00',
      'zone_w_mm': '180.00',
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
      'zone_x_mm': '10.00',
      'zone_y_mm': '10.00',
      'zone_w_mm': '180.00',
      'zone_h_mm': '80.00',
      'max_width_mm': null,
      'max_height_mm': null,
      'strip_width_mm': '60.00',
      'min_font_mm': '4.00',
      'colors_allowed': false,
      'dpi': 600,
    },
  ],
};

Layer _text(String id, {double x = 100, double y = 50, double w = 20, double h = 10, String method = 'uv'}) => Layer(
      id: id,
      area: 'front',
      method: method,
      kind: LayerKind.text,
      x: x,
      y: y,
      w: w,
      h: h,
      text: const TextSource(content: 'A', font: 'Roboto', sizeMm: 3, color: '#ff0000'),
    );

void main() {
  final area = PrintArea.fromJson(Map<String, dynamic>.from(_areaJson));

  group('DesignDocument JSON', () {
    test('round-trips the web sample byte for byte', () {
      final doc = DesignDocument.fromJson(jsonDecode(webSample) as Map<String, dynamic>);
      expect(doc.layers, hasLength(4));
      expect(doc.layers[0].dial!.numerals, 'roman');
      expect(doc.layers[0].locked, LayerLock.system);
      expect(doc.layers[1].text!.content, 'Dizzo\nO‘zbek');
      expect(doc.layers[1].rotation, -12.5);
      expect(doc.layers[2].image!.pxW, 1600);
      expect(doc.layers[3].area, isNull);
      expect(doc.links.single.target, 'right');
      expect(jsonEncode(doc.toJson()), webSample);
    });

    test('documents saved before links (or strips) existed get none', () {
      final doc = DesignDocument.fromJson({'version': 1, 'layers': <Object>[]});
      expect(jsonEncode(doc.toJson()), '{"version":1,"layers":[],"links":[],"strips":[]}');
    });

    test('whole numbers are written without a decimal point', () {
      expect(jsNum(12.0), 12);
      expect(jsNum(12.5), 12.5);
      expect(jsonEncode(_text('a').copyWith(x: 3.0).toJson()), contains('"x_mm":3,'));
    });

    test('new layer ids fit the backend pattern', () {
      final id = newLayerId();
      expect(RegExp(r'^[A-Za-z0-9_-]{1,40}$').hasMatch(id), isTrue);
      expect(newLayerId(), isNot(id));
    });
  });

  group('geometry and problems', () {
    test('parses areas from the API', () {
      expect(area.widthMm, 200);
      expect(area.method('engrave')!.stripWidth, 60);
      expect(area.method('uv')!.zone, const Box(10, 10, 190, 90));
    });

    test('rotated bounds', () {
      final b = layerBox(_text('a', w: 20, h: 10).copyWith(rotation: 90));
      expect(b.width, closeTo(10, 1e-9));
      expect(b.height, closeTo(20, 1e-9));
    });

    test('a strip follows the layers', () {
      final m = area.method('engrave')!;
      final l = _text('a', x: 150, method: 'engrave');
      final z = printZone(area, m, [l]);
      expect(z.width, 60);
      expect(z.cx, 150);
      // Kept inside the zone.
      final edge = printZone(area, m, [_text('b', x: 185, method: 'engrave')]);
      expect(edge.x1, 190);
    });

    test('placeInZone keeps the centre inside; clampInto moves the whole box', () {
      final m = area.method('uv')!;
      final out = _text('a', x: 250, y: -20);
      final placed = placeInZone(out, m);
      expect(placed.x, 190);
      expect(placed.y, 10);
      final clamped = clampInto(out, m.zone);
      expect(clamped.x, 180);
      expect(clamped.y, 15);
    });

    test('problems: colour on engraving, small text, wrong area', () {
      final l = _text('a', method: 'engrave');
      final p = layerProblems(l, [area], ['uv', 'engrave'], [l]);
      expect(p, contains('bu usulda rang bo‘lmaydi'));
      expect(p, contains('shrift kamida 4 mm bo‘lsin'));
      final lost = l.copyWith(area: 'back');
      expect(layerProblems(lost, [area], ['uv'], [lost]).single, contains('hududi bu turda yo‘q'));
      final all = designProblems([l, _text('b')], [area], ['uv', 'engrave'], 'uv');
      expect(all['a'], contains('dizayn bitta usulda bosiladi — bu element boshqa usulda'));
      expect(problemCount(all), 1);
    });

    test('sticking out is cropped, not a problem', () {
      final l = _text('a', x: 189);
      expect(sticksOut(l, [area], [l]), isTrue);
      expect(layerProblems(l, [area], ['uv'], [l]), isEmpty);
    });

    test('synced areas copy layers, mirrored for a mirrored pair', () {
      final left = PrintArea(key: 'left', name: 'Chap', widthMm: 100, heightMm: 50, pairKey: 'right', methods: area.methods);
      final right = PrintArea(
        key: 'right',
        name: 'O‘ng',
        widthMm: 100,
        heightMm: 50,
        pairKey: 'left',
        pairMirror: true,
        methods: area.methods,
      );
      final doc = DesignDocument(
        layers: [_text('a', x: 30).copyWith(area: 'left', rotation: 10)],
        links: const [AreaLink('left', 'right')],
      );
      final eff = effectiveLayers(doc, [left, right]);
      expect(eff, hasLength(2));
      expect(eff[1].id, 'a@right');
      expect(eff[1].x, 70);
      expect(eff[1].rotation, -10);
      expect(printTargets(eff).map((t) => t.area), ['left', 'right']);
      // On a shape without the pair the link goes and the layers are parked.
      final fitted = fitToShape(doc, [area]);
      expect(fitted.links, isEmpty);
      expect(fitted.layers.single.area, isNull);
    });

    test('a clock face gets numerals once', () {
      const clock = PrintArea(
        key: 'face',
        name: 'Siferblat',
        widthMm: 200,
        heightMm: 200,
        anchor: {'point': [0, 0, 0], 'normal': [0, 0, 1], 'up': [0, 1, 0], 'round': true, 'dial': true},
      );
      expect(clock.isDial, isTrue);
      final withMethods = PrintArea(
        key: clock.key,
        name: clock.name,
        widthMm: 200,
        heightMm: 200,
        anchor: clock.anchor,
        methods: area.methods,
      );
      final doc = withDials(DesignDocument.empty, [withMethods]);
      expect(doc.layers.single.dial!.face, 'round');
      expect(doc.layers.single.locked, LayerLock.system);
      expect(withDials(doc, [withMethods]).layers, hasLength(1));
      final laid = layoutDial(doc.layers.single.dial!, 180, 80, 1, (l, px) => px * 0.6 * l.length);
      expect(laid.ticks, hasLength(60));
      expect(laid.numerals, hasLength(12));
      expect(laid.numerals.first.y, lessThan(0)); // 12 at the top
    });

    test('contrast ink', () {
      expect(contrastInk('#000000'), '#ffffff');
      expect(contrastInk('#ffffff'), '#111827');
    });
  });

  group('laser strip', () {
    const zone = Box(10, 10, 190, 90);
    Layer engraved(String id, double x, {double w = 20}) => _text(id, x: x, w: w, method: 'engrave');

    test('followStrip: stays while the span fits, is pushed by its edges, stays in the zone', () {
      expect(followStrip(50, (lo: 60, hi: 100), zone, 60), 50);
      expect(followStrip(50, (lo: 50, hi: 110), zone, 60), 50);
      expect(followStrip(50, (lo: 40, hi: 80), zone, 60), 40); // pushed left
      expect(followStrip(50, (lo: 70, hi: 125), zone, 60), 65); // pushed right
      expect(followStrip(50, (lo: 0, hi: 20), zone, 60), 10); // not past the zone
      expect(followStrip(120, (lo: 170, hi: 200), zone, 60), 130);
      expect(followStrip(50, (lo: double.infinity, hi: double.negativeInfinity), zone, 60), 50); // no layers
      expect(followStrip(50, (lo: 40, hi: 120), zone, 60), 50); // wider than the strip: it stays
      expect(followStrip(120, (lo: 0, hi: 190), zone, 60), 120);
      expect(followStrip(150, (lo: 0, hi: 190), zone, 60), 130); // still inside the zone
    });

    test('a stored strip is used; without one the midpoint rule', () {
      final m = area.method('engrave')!;
      final l = engraved('a', 100);
      expect(printZone(area, m, [l]), const Box(70, 10, 130, 90));
      const stored = [PrintStrip(area: 'front', method: 'engrave', x: 85)];
      expect(printZone(area, m, [l], stored), const Box(85, 10, 145, 90));
      // Another area's strip or another method's doesn't count.
      expect(printZone(area, m, [l], const [PrintStrip(area: 'back', method: 'engrave', x: 20)]).x0, 70);
      // A stored position past the zone is kept inside.
      expect(printZone(area, m, [l], const [PrintStrip(area: 'front', method: 'engrave', x: 500)]).x1, 190);
      expect(printZone(area, area.method('uv')!, [l], stored), zone);
      // Cropping follows the stored strip.
      final edge = engraved('b', 140);
      expect(sticksOut(edge, [area], [edge], const [PrintStrip(area: 'front', method: 'engrave', x: 90)]), isFalse);
      expect(sticksOut(edge, [area], [edge], const [PrintStrip(area: 'front', method: 'engrave', x: 60)]), isTrue);
    });

    test('strips start with the first layer, follow the layers and go with the last', () {
      var doc = withStrips(DesignDocument(layers: [engraved('a', 100)]), [area]);
      expect(doc.strips, const [PrintStrip(area: 'front', method: 'engrave', x: 70)]);
      expect(identical(withStrips(doc, [area]), doc), isTrue);
      // Moved inside the strip: it stays.
      doc = withStrips(doc.patch('a', (l) => l.copyWith(x: 110)), [area]);
      expect(doc.strips.single.x, 70);
      // Pushed right past its edge.
      doc = withStrips(doc.patch('a', (l) => l.copyWith(x: 150)), [area]);
      expect(doc.strips.single.x, 100);
      // Back to the left: it stays until the layer touches its left edge.
      doc = withStrips(doc.patch('a', (l) => l.copyWith(x: 120)), [area]);
      expect(doc.strips.single.x, 100);
      doc = withStrips(doc.patch('a', (l) => l.copyWith(x: 90)), [area]);
      expect(doc.strips.single.x, 80);
      // Outside the zone altogether: the strip stays.
      doc = withStrips(doc.patch('a', (l) => l.copyWith(y: 200)), [area]);
      expect(doc.strips.single.x, 80);
      // Colour print has no strip; the last engraved layer takes it away.
      doc = withStrips(doc.copyWith(layers: [_text('u')]), [area]);
      expect(doc.strips, isEmpty);
      // Nor does a shape without the area; with no areas known nothing changes.
      final stale = DesignDocument(layers: [engraved('a', 100)], strips: const [
        PrintStrip(area: 'front', method: 'engrave', x: 20),
        PrintStrip(area: 'gone', method: 'engrave', x: 20),
      ]);
      expect(withStrips(stale, [area]).strips, const [PrintStrip(area: 'front', method: 'engrave', x: 50)]);
      expect(identical(withStrips(stale, const []), stale), isTrue);
    });

    test('a move keeps the area\'s engraved layers within one strip width', () {
      final m = area.method('engrave')!;
      final others = [engraved('a', 50)]; // 40..60
      // Right: no further than 40 + 60 = 100 for its right edge.
      expect(placeInZone(engraved('b', 150), m, others).x, 90);
      // Left: the other one's right edge 60 - 60 = 0 is past the zone: the zone limits it.
      expect(placeInZone(engraved('b', 0), m, others).x, 20);
      // Nothing else placed: the whole zone.
      expect(placeInZone(engraved('b', 150), m, const []).x, 150);
      expect(placeInZone(engraved('b', 185), m, const []).x, 180);
      // Without the area's layers only the centre is kept inside.
      expect(placeInZone(engraved('b', 185), m).x, 185);
      // One that can't fit with the others (an older design) stays.
      expect(placeInZone(engraved('b', 150, w: 80), m, [engraved('a', 20)]).x, 150);
      expect(placeInZone(engraved('b', 150), m, [engraved('b', 20)]).x, 150); // itself doesn't count
      // Colour print isn't limited.
      expect(placeInZone(_text('b', x: 150), area.method('uv')!, [_text('a', x: 50)]).x, 150);
      // Each layer of a template after the ones before it.
      final placed = fitIntoStrips([engraved('a', 30), engraved('b', 170)], [area], const []);
      // The first stays; the strip is centred on it (10..70) and the next goes into it.
      expect(placed.map((l) => l.x), [30, 60]);
    });

    test('a layer going onto the method is put inside the current strip', () {
      const strips = [PrintStrip(area: 'front', method: 'engrave', x: 50)]; // 50..110
      Layer into(Layer l, [List<Layer> others = const [], List<PrintStrip> s = strips]) =>
          placeInStrip(l, area, area.method(l.method)!, others, s);
      expect(into(engraved('a', 150)).x, 100);
      expect(into(engraved('a', 20)).x, 60);
      expect(into(engraved('a', 80)).x, 80); // already inside
      expect(into(engraved('a', 150, w: 70)).x, 150); // wider than the strip
      expect(into(engraved('a', 150), const [], const []).x, 150); // the area's first: one is centred on it
      expect(into(engraved('a', 150), [engraved('b', 40)], const []).x, 60); // else centred on the others (10..70)
      expect(into(_text('u', x: 150)).x, 150); // colour print
    });

    test('a synced area has no strip of its own: its copies are centred', () {
      final left = PrintArea(key: 'left', name: 'Chap', widthMm: 200, heightMm: 100, pairKey: 'right', methods: area.methods);
      final right = PrintArea(
        key: 'right',
        name: 'O‘ng',
        widthMm: 200,
        heightMm: 100,
        pairKey: 'left',
        pairMirror: true,
        methods: area.methods,
      );
      final doc = withStrips(
        DesignDocument(
          layers: [engraved('a', 40).copyWith(area: 'left')],
          links: const [AreaLink('left', 'right')],
          strips: const [PrintStrip(area: 'left', method: 'engrave', x: 20)],
        ),
        [left, right],
      );
      expect(doc.strips, const [PrintStrip(area: 'left', method: 'engrave', x: 20)]);
      final copy = effectiveLayers(doc, [left, right]).last;
      expect(copy.x, 160);
      expect(printZone(right, right.method('engrave')!, effectiveLayers(doc, [left, right]), doc.strips),
          const Box(130, 10, 190, 90));
    });

    test('JSON: strips round-trip', () {
      final json = webSample.replaceFirst(
        '"strips":[]}',
        '"strips":[{"area":"front","method":"engrave","x_mm":42.5},{"area":"back","method":"engrave","x_mm":10}]}',
      );
      final doc = DesignDocument.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(doc.strips, const [
        PrintStrip(area: 'front', method: 'engrave', x: 42.5),
        PrintStrip(area: 'back', method: 'engrave', x: 10),
      ]);
      expect(jsonEncode(doc.toJson()), json);
      expect(DesignDocument.fromJson(jsonDecode(webSample) as Map<String, dynamic>).strips, isEmpty);
    });
  });

  group('History', () {
    test('undo and redo walk the snapshots', () {
      final h = History<int>(limit: 3);
      expect(h.canUndo, isFalse);
      h.checkpoint(1);
      h.checkpoint(2);
      expect(h.undo(3), 2);
      expect(h.undo(2), 1);
      expect(h.undo(1), isNull);
      expect(h.redo(1), 2);
      expect(h.redo(2), 3);
      expect(h.canRedo, isFalse);
    });

    test('a new change drops the redo steps and the oldest past the limit', () {
      final h = History<int>(limit: 2);
      h.checkpoint(1);
      h.checkpoint(2);
      h.checkpoint(3);
      expect(h.undo(4), 3);
      h.checkpoint(3);
      expect(h.canRedo, isFalse);
      expect(h.undo(5), 3);
      expect(h.undo(3), 2);
      expect(h.canUndo, isFalse);
    });
  });
}
