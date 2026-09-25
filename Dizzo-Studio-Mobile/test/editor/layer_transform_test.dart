import 'package:dizzo/features/editor/domain/design_document.dart';
import 'package:dizzo/features/editor/domain/print_area.dart';
import 'package:dizzo/features/editor/presentation/canvas/layer_transform.dart';
import 'package:dizzo/features/editor/presentation/render/design_fonts.dart';
import 'package:flutter_test/flutter_test.dart';

// Gestures on a laser strip: a layer goes anywhere in the zone the strip can
// follow, but never leaves the area's other engraved layers outside it.

const _area = PrintArea(
  key: 'front',
  name: 'Old tomoni',
  widthMm: 200,
  heightMm: 100,
  methods: [
    AreaMethod(method: 'engrave', zoneX: 10, zoneY: 10, zoneW: 180, zoneH: 80, stripWidth: 60, colorsAllowed: false),
  ],
);

Layer _shape(String id, double x, {double w = 20}) => Layer(
      id: id,
      area: 'front',
      method: 'engrave',
      kind: LayerKind.graphic,
      x: x,
      y: 50,
      w: w,
      h: 20,
      graphic: const GraphicSource(library: 'shape', name: 'square', color: monoColor),
    );

void main() {
  setUpAll(() => designFontsEnabled = false);

  test('alone, a layer moves across the whole zone', () {
    final a = _shape('a', 100);
    expect(moveLayer(_area, a, 70, 0, [a], threshold: 0, snapping: false).layer.x, 170);
    expect(moveLayer(_area, a, 200, 0, [a], threshold: 0, snapping: false).layer.x, 180); // wholly inside
  });

  test('with others, it stops where one strip still takes them all', () {
    final a = _shape('a', 100);
    final b = _shape('b', 50); // 40..60
    final layers = [a, b];
    // Right: its right edge no further than 40 + 60.
    expect(moveLayer(_area, a, 60, 0, layers, threshold: 0, snapping: false).layer.x, 90);
    // Left: the zone is the only limit (60 - 60 is outside it).
    expect(moveLayer(_area, a, -95, 0, layers, threshold: 0, snapping: false).layer.x, 20);
    // Up and down stay free.
    expect(moveLayer(_area, a, 60, 20, layers, threshold: 0, snapping: false).layer.y, 70);
  });

  group('the strip moves only when the finger takes the layer past its edge', () {
    const strips = [PrintStrip(area: 'front', method: 'engrave', x: 50)]; // 50..110
    final a = _shape('a', 80); // 70..90

    test('inside it snaps to the strip and never moves it', () {
      final r = moveLayer(_area, a, 17, 0, [a], threshold: 3, strips: strips).layer;
      expect(layerBox(r).x1, closeTo(110, 1e-9));
      expect(withStrips(DesignDocument(layers: [r], strips: strips), [_area]).strips, strips);
    });

    test('past its edge the layer follows the finger, unless a snap takes it back inside', () {
      final r = moveLayer(_area, a, 30, 0, [a], threshold: 3, strips: strips).layer;
      expect(r.x, 110);
      expect(withStrips(DesignDocument(layers: [r], strips: strips), [_area]).strips.single.x, 60);
      // The area's centre is within reach and keeps it in the strip: the strip stays.
      final back = moveLayer(_area, a, 22, 0, [a], threshold: 3, strips: strips).layer;
      expect(back.x, 100);
      expect(withStrips(DesignDocument(layers: [back], strips: strips), [_area]).strips, strips);
    });

    test('a vertical move never moves it', () {
      for (final x in [60.0, 80.0, 98.0, 100.0]) {
        var l = _shape('a', x);
        for (final dy in [5.0, 12.0, -20.0, 30.0]) {
          l = moveLayer(_area, l, 0, dy, [l], threshold: 3, strips: strips).layer;
          expect(withStrips(DesignDocument(layers: [l], strips: strips), [_area]).strips, strips);
        }
      }
    });
  });

  test('turning and pinching keep to the strip too', () {
    final a = _shape('a', 85, w: 40); // 65..105
    final b = _shape('b', 30); // 20..40
    final layers = [a, b];
    // Turned 90°, it is 20 wide; the union may reach 20 + 60 = 80.
    final turned = rotateLayer(_area, a.copyWith(x: 120), 90, layers).layer;
    expect(layerBox(turned).x1, closeTo(80, 1e-9));
    final pinched = pinchLayer(_area, a, 1, 0, 30, 0, layers, threshold: 0).layer;
    expect(layerBox(pinched).x1, closeTo(80, 1e-9));
  });

  test('growing stops at the strip width with the others', () {
    final a = _shape('a', 70); // 60..80
    final b = _shape('b', 30); // 20..40
    final grown = scaleLayer(_area, a, 3, [a, b], threshold: 0, snapping: false).layer;
    expect(layerBox(grown).x1, lessThanOrEqualTo(80 + 1e-9));
  });
}
