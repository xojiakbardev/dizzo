import 'dart:math' as math;

import '../../../../core/l10n/app_language.dart';
import '../../domain/design_document.dart';
import '../../domain/dial.dart';
import '../../domain/print_area.dart';
import '../../domain/snap.dart';
import '../render/design_fonts.dart';

// Moving, resizing and rotating a layer in area millimetres (the web's
// `app/lib/design/gestures.ts`), for fingers: one finger moves or drags a
// handle, two fingers pinch and turn.

class Point {
  const Point(this.x, this.y);
  final double x;
  final double y;
}

/// A point in the layer's own (unrotated, centred) frame.
Point localPoint(Layer l, Point p) {
  final a = -l.rotation * math.pi / 180;
  final dx = p.x - l.x;
  final dy = p.y - l.y;
  return Point(dx * math.cos(a) - dy * math.sin(a), dx * math.sin(a) + dy * math.cos(a));
}

/// A layer-frame point in area millimetres.
Point layerToArea(Layer l, double lx, double ly) {
  final a = l.rotation * math.pi / 180;
  return Point(l.x + lx * math.cos(a) - ly * math.sin(a), l.y + lx * math.sin(a) + ly * math.cos(a));
}

double _dialMeasure(DialSource d, String label, double px) =>
    measureLabel(label, px, font: d.font, bold: d.bold, italic: d.italic);

/// The topmost layer under the point (background fills never; a dial only
/// on its numerals and marks). [slack] widens small layers for a finger.
Layer? hitLayer(List<Layer> layers, Point p, {double slack = 2}) {
  for (final l in layers.reversed) {
    if (l.isBackground) continue;
    final q = localPoint(l, p);
    final pad = math.max(0, slack - math.min(l.w, l.h) / 2);
    if (q.x.abs() > l.w / 2 + pad || q.y.abs() > l.h / 2 + pad) continue;
    final dial = l.dial;
    if (dial != null &&
        !dialHit(dial, l.w, l.h, q.x, q.y, (label, px) => _dialMeasure(dial, label, px), slack: slack)) {
      continue;
    }
    return l;
  }
  return null;
}

/// Corners (clockwise from top-left) and the rotate knob above the top edge.
({List<Point> corners, Point knob, Point top}) handlesOf(Layer l, double knobGap) {
  final hw = l.w / 2;
  final hh = l.h / 2;
  return (
    corners: [layerToArea(l, -hw, -hh), layerToArea(l, hw, -hh), layerToArea(l, hw, hh), layerToArea(l, -hw, hh)],
    knob: layerToArea(l, 0, -hh - knobGap),
    top: layerToArea(l, 0, -hh),
  );
}

enum HandleKind { scale, rotate }

/// What a finger at [p] grabs on the selected layer ([radius], [knobGap] in mm).
HandleKind? handleAt(Layer l, Point p, double radius, double knobGap) {
  bool near(Point q) => math.sqrt(math.pow(q.x - p.x, 2) + math.pow(q.y - p.y, 2)) <= radius;
  final h = handlesOf(l, knobGap);
  if (near(h.knob)) return HandleKind.rotate;
  if (h.corners.any(near)) return HandleKind.scale;
  return null;
}

SnapFrame frameOf(PrintArea area, Layer l) =>
    SnapFrame(zone: area.method(l.method)?.zone ?? area.box, area: area.box);

List<Box> othersOf(List<Layer> layers, Layer l) =>
    [for (final o in layers) if (o.id != l.id && o.area == l.area && !o.isBackground) layerBox(o)];

/// A layer scaled by [factor] about its centre: text by whole-mm font
/// sizes and never past the zone; anything else at least 2 mm.
Layer scaledLayer(PrintArea area, Layer l, double factor, [List<Layer> layers = const []]) {
  final m = area.method(l.method);
  var f = factor;
  if (m != null) f = math.min(f, growLimit(l, m, layers));
  final text = l.text;
  if (text != null) {
    final minSize = (m?.minFont ?? 1).ceilToDouble();
    final raw = text.sizeMm * f;
    final size = math.max(minSize, f < factor ? raw.floorToDouble() : raw.roundToDouble());
    final t = text.copyWith(sizeMm: size);
    final layout = layoutText(t);
    final next = l.copyWith(text: t, w: layout.w, h: layout.h);
    return m != null ? placeInZone(next, m, layers) : next;
  }
  f = math.max(f, 2 / math.min(l.w, l.h));
  final next = l.copyWith(w: l.w * f, h: l.h * f);
  return m != null ? placeInZone(next, m, layers) : next;
}

/// A text layer re-measured around the same centre (content, font, size…).
/// With a strip the text never gets wider than it (the size steps down, not
/// below the minimum) and stays in it with the area's other [layers].
Layer withText(PrintArea? area, Layer l, TextSource t, [List<Layer> layers = const []]) {
  var text = t;
  var layout = layoutText(text);
  final m = area?.method(l.method);
  final width = m == null ? null : stripWidthOf(m);
  final minFont = (m?.minFont ?? 1).ceilToDouble();
  double boxWidth() => rotatedBox(l.x, l.y, layout.w, layout.h, l.rotation).width;
  for (var i = 0; width != null && i < 4 && boxWidth() > width && text.sizeMm > minFont; i++) {
    text = text.copyWith(sizeMm: math.max(minFont, (text.sizeMm * width / boxWidth() * 10).floorToDouble() / 10));
    layout = layoutText(text);
  }
  final next = l.copyWith(text: text, w: layout.w, h: layout.h);
  if (m == null) return next;
  return width == null ? clampIntoZone(next, m) : placeInZone(next, m, [for (final o in layers) if (o.area == l.area) o]);
}

class TransformResult {
  const TransformResult(this.layer, {this.guides = const [], this.gaps = const [], this.badge});

  final Layer layer;
  final List<Guide> guides;
  final List<GapMark> gaps;

  /// "12.5 × 30 mm" while resizing, "45°" while turning.
  final String? badge;
}

String _fmt(double mm) {
  final r = (mm * 10).round() / 10;
  return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
}

/// [start] moved by (dx, dy) mm, snapped: always where the finger is
/// relative to where it took the layer, kept in place by placeInZone. A snap
/// never pushes the strip ([strips]) where the finger alone wouldn't.
TransformResult moveLayer(
  PrintArea area,
  Layer start,
  double dx,
  double dy,
  List<Layer> layers, {
  required double threshold,
  bool snapping = true,
  List<PrintStrip> strips = const [],
}) {
  final raw = start.copyWith(x: start.x + dx, y: start.y + dy);
  var moved = raw;
  var guides = const <Guide>[];
  var gaps = const <GapMark>[];
  if (snapping) {
    final snap = snapMove(layerBox(moved), othersOf(layers, start), frameOf(area, start), threshold);
    moved = moved.copyWith(x: moved.x + snap.dx, y: moved.y + snap.dy);
    guides = snap.guides;
    gaps = snap.gaps;
  }
  final m = area.method(start.method);
  if (m == null) return TransformResult(moved, guides: guides, gaps: gaps);
  var placed = placeInZone(moved, m, layers);
  if (stripWidthOf(m) != null && placed.x != raw.x) {
    final strip = printZone(area, m, layers, strips);
    bool inStrip(Layer l) {
      final b = layerBox(l);
      return b.x0 >= strip.x0 - 1e-6 && b.x1 <= strip.x1 + 1e-6;
    }

    final unsnapped = placeInZone(raw, m, layers);
    if (!inStrip(placed) && inStrip(unsnapped)) placed = placed.copyWith(x: unsnapped.x);
  }
  return TransformResult(placed, guides: guides, gaps: gaps);
}

/// [start] scaled by [factor] (a corner handle or a pinch), snapped.
TransformResult scaleLayer(
  PrintArea area,
  Layer start,
  double factor,
  List<Layer> layers, {
  required double threshold,
  bool snapping = true,
  List<PrintStrip> strips = const [],
}) {
  var f = factor;
  final others = othersOf(layers, start);
  final frame = frameOf(area, start);
  if (snapping) {
    final box = rotatedBox(start.x, start.y, start.w * f, start.h * f, start.rotation);
    final k = snapScale(box, others, frame, threshold);
    if (k != null) f *= k;
  }
  final next = scaledLayer(area, start, f, layers);
  return TransformResult(
    next,
    guides: snapping ? guidesFor(layerBox(next), others, frame) : const [],
    badge: l10nNow.editorCanvasSizeBadge(_fmt(next.w), _fmt(next.h)),
  );
}

/// [start] turned by [degrees] (clockwise), sticking to 45° steps.
TransformResult rotateLayer(PrintArea area, Layer start, double degrees, [List<Layer> layers = const []]) {
  var angle = start.rotation + degrees;
  angle = ((angle % 360) + 540) % 360 - 180;
  angle = snapAngle(angle);
  final turned = start.copyWith(rotation: double.parse(angle.toStringAsFixed(1)));
  final m = area.method(start.method);
  final placed = m != null ? placeInZone(turned, m, layers) : turned;
  return TransformResult(placed, badge: '${placed.rotation.round()}°');
}

/// Pinch: scale, turn and move together (two fingers on a layer).
TransformResult pinchLayer(
  PrintArea area,
  Layer start,
  double scale,
  double degrees,
  double dx,
  double dy,
  List<Layer> layers, {
  required double threshold,
  List<PrintStrip> strips = const [],
}) {
  final scaled = scaleLayer(area, start, scale, layers, threshold: threshold, snapping: false).layer;
  final turned = rotateLayer(area, scaled.copyWith(x: start.x, y: start.y), degrees, layers).layer;
  final moved = moveLayer(
    area,
    turned.copyWith(x: start.x, y: start.y),
    dx,
    dy,
    layers,
    threshold: threshold,
    strips: strips,
  );
  final angle = moved.layer.rotation.round();
  return TransformResult(
    moved.layer,
    guides: moved.guides,
    gaps: moved.gaps,
    badge: angle != 0
        ? l10nNow.editorCanvasSizeAngleBadge(_fmt(moved.layer.w), _fmt(moved.layer.h), '$angle')
        : l10nNow.editorCanvasSizeBadge(_fmt(moved.layer.w), _fmt(moved.layer.h)),
  );
}
