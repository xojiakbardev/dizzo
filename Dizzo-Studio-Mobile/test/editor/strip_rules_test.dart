import 'dart:convert';

import 'package:dizzo/features/editor/domain/design_document.dart';
import 'package:dizzo/features/editor/domain/print_area.dart';
import 'package:dizzo/features/editor/presentation/canvas/layer_transform.dart';
import 'package:dizzo/features/editor/presentation/render/design_fonts.dart';
import 'package:flutter_test/flutter_test.dart';

// The laser strip's rules: the same cases as the web's
// scripts/strip-rules.test.mjs (and the backend's tests/test_laser_strip.py).

// The mug's engraving zone: 75,15 100×50 mm, a 40 mm strip.
final _method = AreaMethod.fromJson({
  'method': 'engrave', 'zone_x_mm': '75', 'zone_y_mm': '15', 'zone_w_mm': '100', 'zone_h_mm': '50',
  'max_width_mm': null, 'max_height_mm': null, 'strip_width_mm': '40', 'min_font_mm': '2', 'colors_allowed': false,
  'dpi': 600,
});
final _area = PrintArea(key: 'wrap', name: 'O‘rab olish', widthMm: 226, heightMm: 79, methods: [_method]);
const _zone = Box(75, 15, 175, 65);

Layer _text(String id, double x, double w) =>
    Layer(id: id, area: 'wrap', method: 'engrave', kind: LayerKind.text, x: x, y: 40, w: w, h: 10);

({double lo, double hi}) _span(double lo, double hi) => (lo: lo, hi: hi);
const _nothing = (lo: double.infinity, hi: double.negativeInfinity);
const _at100 = [PrintStrip(area: 'wrap', method: 'engrave', x: 100)];

void main() {
  setUpAll(() => designFontsEnabled = false);

  test('the strip stays until the design reaches its edge', () {
    expect(followStrip(100, _span(110, 130), _zone, 40), 100);
    expect(followStrip(100, _span(100, 140), _zone, 40), 100);
    expect(followStrip(100, _span(95, 120), _zone, 40), 95);
    expect(followStrip(100, _span(120, 150), _zone, 40), 110);
    expect(followStrip(100, _span(60, 70), _zone, 40), 75);
    expect(followStrip(100, _span(170, 190), _zone, 40), 135);
    expect(followStrip(100, _nothing, _zone, 40), 100);
    expect(followStrip(300, _nothing, _zone, 40), 135);
    expect(followStrip(100, _span(100, 160), _zone, 40), 100); // wider than the strip: it stays
    expect(followStrip(160, _span(100, 160), _zone, 40), 135);
  });

  test('a stored strip is where it was left, else centred', () {
    final layers = [_text('a', 110, 10), _text('b', 130, 10)];
    expect(printZone(_area, _method, layers, const []).x0, 100);
    expect(printZone(_area, _method, layers, const [PrintStrip(area: 'wrap', method: 'engrave', x: 95)]).x0, 95);
    expect(printZone(_area, _method, layers, const [PrintStrip(area: 'wrap', method: 'engrave', x: 60)]).x0, 75);
    expect(printZone(_area, _method, layers, const [PrintStrip(area: 'wrap', method: 'engrave', x: 170)]).x0, 135);
  });

  test('settling adds, follows and drops strips', () {
    final doc = DesignDocument(layers: [_text('a', 110, 10), _text('b', 130, 10)]);
    final added = withStrips(doc, [_area]);
    expect(added.strips, _at100);
    expect(identical(withStrips(added, [_area]), added), isTrue);

    final inside = added.copyWith(layers: [_text('a', 106, 10), _text('b', 130, 10)]);
    expect(withStrips(inside, [_area]).strips.single.x, 100);
    final past = added.copyWith(layers: [_text('a', 110, 10), _text('b', 140, 10)]);
    expect(withStrips(past, [_area]).strips.single.x, 105);

    expect(withStrips(added.copyWith(layers: const []), [_area]).strips, isEmpty);
    expect(identical(withStrips(added, const []), added), isTrue);
    // Written like the web's JSON.stringify.
    expect(jsonEncode(added.toJson()['strips']), '[{"area":"wrap","method":"engrave","x_mm":100}]');
  });

  test('a moved layer keeps the design in one strip and in the zone', () {
    final others = [_text('a', 110, 10)];
    expect(placeInZone(_text('b', 160, 10), _method, others).x, 140);
    expect(placeInZone(_text('b', 130, 10), _method, others).x, 130);
    expect(placeInZone(_text('b', 70, 10), _method, others).x, 80);
    expect(placeInZone(_text('b', 200, 10), _method, const []).x, 170);
    expect(placeInZone(_text('b', 160, 50), _method, others).x, 160);
  });

  test('an arriving layer goes into the strip where it is now', () {
    final others = [_text('a', 110, 10)];
    expect(placeInStrip(_text('b', 150, 10), _area, _method, others, _at100).x, 135);
    expect(placeInStrip(_text('b', 90, 10), _area, _method, others, _at100).x, 105);
    expect(placeInStrip(_text('b', 120, 10), _area, _method, others, _at100).x, 120);
    expect(placeInStrip(_text('b', 160, 10), _area, _method, const [], const []).x, 160);
    final fitted = fitIntoStrips([_text('a', 80, 10), _text('b', 170, 10)], [_area], const []);
    expect(fitted.map((l) => l.x), [80, 110]);
  });

  test('a snap never pushes the strip where the finger alone would not', () {
    // Strip 100..140; the layer 125..135 moved 4 mm right: 129..139 (inside).
    // The zone's edge isn't near, but another layer's edge at 141 is.
    final a = _text('a', 130, 10);
    final b = Layer(id: 'b', area: 'wrap', method: 'engrave', kind: LayerKind.text, x: 136, y: 58, w: 10, h: 4);
    final r = moveLayer(_area, a, 4, 0, [a, b], threshold: 3, strips: _at100).layer;
    expect(r.x, 134);
    // Without the strip rule it would have snapped to 131..141.
    expect(moveLayer(_area, a, 4, 0, [a, b], threshold: 3).layer.x, 136);
  });

  test('an edited text steps its size down rather than grow wider than the strip', () {
    final start = Layer(
      id: 't',
      area: 'wrap',
      method: 'engrave',
      kind: LayerKind.text,
      x: 125,
      y: 40,
      w: 10,
      h: 10,
      text: const TextSource(content: 'A', font: 'Roboto', sizeMm: 10, color: monoColor),
    );
    final long = const TextSource(content: 'Salom dunyo', font: 'Roboto', sizeMm: 10, color: monoColor);
    final next = withText(_area, start, long, [start]);
    expect(layoutText(long).w, greaterThan(40));
    expect(layerBox(next).width, lessThanOrEqualTo(40 + 1e-9));
    expect(next.text!.sizeMm, lessThan(10));
    expect(next.text!.sizeMm, greaterThanOrEqualTo(2));
    expect(next.text!.sizeMm * 10, closeTo((next.text!.sizeMm * 10).roundToDouble(), 1e-9)); // tenths of a mm
    // Never below the minimum: a very long text stops at it.
    final huge = long.copyWith(content: 'x' * 400);
    expect(withText(_area, start, huge, [start]).text!.sizeMm, 2);
  });
}
