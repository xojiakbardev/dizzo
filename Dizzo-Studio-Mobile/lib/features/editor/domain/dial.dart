import 'dart:math' as math;

import 'design_document.dart';
import 'print_area.dart';

// A clock face's numerals and minute marks (the web's `app/lib/design/dial.ts`).
// Everything sits on rays from the centre, 6° apart, 12 at the top.

const romanNumerals = ['XII', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI'];

String dialLabel(DialSource dial, int hour) =>
    dial.numerals == 'roman' ? romanNumerals[hour] : '${hour == 0 ? 12 : hour}';

/// The face edge along the ray at [angle] (radians, 0 = up, clockwise).
double dialEdgeDistance(String face, double w, double h, double angle, double corner) {
  final dx = math.sin(angle);
  final dy = -math.cos(angle);
  final hw = w / 2;
  final hh = h / 2;
  if (face == 'round') return 1 / math.sqrt(math.pow(dx / hw, 2) + math.pow(dy / hh, 2));
  final r = math.min(corner, math.min(hw, hh));
  bool within(double t) {
    final qx = (dx * t).abs() - (hw - r);
    final qy = (dy * t).abs() - (hh - r);
    final outside = math.sqrt(math.pow(math.max(qx, 0), 2) + math.pow(math.max(qy, 0), 2));
    return outside + math.min(math.max(qx, qy), 0) - r <= 0;
  }

  var lo = 0.0;
  var hi = math.sqrt(hw * hw + hh * hh);
  for (var i = 0; i < 32; i++) {
    final mid = (lo + hi) / 2;
    if (within(mid)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

class DialTick {
  const DialTick(this.x0, this.y0, this.x1, this.y1, this.width);
  final double x0;
  final double y0;
  final double x1;
  final double y1;
  final double width;
}

class DialNumeral {
  const DialNumeral(this.label, this.x, this.y);
  final String label;

  /// Centre of the numeral (its middle baseline, as the web draws it).
  final double x;
  final double y;
}

/// The dial's marks and numeral centres for a box of w × h, `s` units per mm
/// (px or mm alike). [measure] gives a label's width at font size `px`.
({List<DialTick> ticks, List<DialNumeral> numerals}) layoutDial(
  DialSource dial,
  double w,
  double h,
  double s,
  double Function(String label, double px) measure,
) {
  final d = math.min(w, h);
  final margin = d * 0.022;
  final hourTick = dial.ticks ? d * 0.055 : 0.0;
  final minuteTick = d * 0.026;
  final corner = dial.cornerRadiusMm * s;
  final ticks = <DialTick>[];
  if (dial.ticks) {
    for (var i = 0; i < 60; i++) {
      final angle = i * math.pi / 30;
      final hour = i % 5 == 0;
      final edge = dialEdgeDistance(dial.face, w, h, angle, corner) - margin;
      final len = hour ? hourTick : minuteTick;
      final dx = math.sin(angle);
      final dy = -math.cos(angle);
      ticks.add(DialTick(dx * edge, dy * edge, dx * (edge - len), dy * (edge - len), hour ? d * 0.011 : d * 0.0045));
    }
  }
  final numerals = <DialNumeral>[];
  if (dial.numerals != 'none') {
    final px = dial.sizeMm * s;
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final label = dialLabel(dial, i);
      final width = measure(label, px);
      final dx = math.sin(angle);
      final dy = -math.cos(angle);
      final half = dx.abs() * (width / 2) + dy.abs() * (px * 0.42);
      final r = dialEdgeDistance(dial.face, w, h, angle, corner) - margin - hourTick - d * 0.02 - half;
      numerals.add(DialNumeral(label, dx * r, dy * r + px * 0.04));
    }
  }
  return (ticks: ticks, numerals: numerals);
}

/// Whether a press (in the layer's own frame, mm) lands on a numeral or a mark.
bool dialHit(
  DialSource dial,
  double w,
  double h,
  double px,
  double py,
  double Function(String label, double px) measure, {
  double slack = 2,
}) {
  final d = math.min(w, h);
  final margin = d * 0.022;
  final hourTick = dial.ticks ? d * 0.055 : 0.0;
  final minuteTick = d * 0.026;
  final corner = dial.cornerRadiusMm;
  final r = math.sqrt(px * px + py * py);
  if (dial.ticks) {
    final angle = math.atan2(px, -py);
    final minute = (angle * 30 / math.pi).round();
    final ray = minute * math.pi / 30;
    final across = (r * math.sin(angle - ray)).abs();
    final edge = dialEdgeDistance(dial.face, w, h, ray, corner) - margin;
    final len = minute % 5 == 0 ? hourTick : minuteTick;
    if (across <= slack && r <= edge + slack && r >= edge - len - slack) return true;
  }
  if (dial.numerals != 'none') {
    final size = dial.sizeMm;
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final label = dialLabel(dial, i);
      final width = measure(label, size);
      final dx = math.sin(angle);
      final dy = -math.cos(angle);
      final half = dx.abs() * (width / 2) + dy.abs() * (size * 0.42);
      final at = dialEdgeDistance(dial.face, w, h, angle, corner) - margin - hourTick - d * 0.02 - half;
      if ((px - dx * at).abs() <= width / 2 + slack && (py - (dy * at + size * 0.04)).abs() <= size * 0.6 + slack) {
        return true;
      }
    }
  }
  return false;
}

/// The face an area's numerals follow.
({String face, double corner}) faceOf(PrintArea area) =>
    (face: area.round ? 'round' : 'rect', corner: area.cornerRadiusMm);

/// A new clock face's numerals, covering the colour-print zone, locked by the Studio.
Layer? newDialLayer(PrintArea area, String color) {
  final m = area.method('uv') ?? (area.methods.isEmpty ? null : area.methods.first);
  if (m == null) return null;
  final z = m.zone;
  final f = faceOf(area);
  return Layer(
    id: '$dialPrefix${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
    area: area.key,
    method: m.method,
    kind: LayerKind.dial,
    locked: LayerLock.system,
    x: z.cx,
    y: z.cy,
    w: z.width,
    h: z.height,
    dial: DialSource(
      font: 'Montserrat',
      sizeMm: math.max(6, (math.min(z.width, z.height) * 0.075).roundToDouble()),
      color: m.colorsAllowed ? color : monoColor,
      bold: true,
      face: f.face,
      cornerRadiusMm: f.corner,
    ),
  );
}

/// Clock numerals follow their face on any type.
DesignDocument refitDials(DesignDocument doc, List<PrintArea> areas) => doc.copyWith(
      layers: [
        for (final l in doc.layers)
          if (l.dial != null && areaByKey(areas, l.area) != null)
            _refit(l, areaByKey(areas, l.area)!)
          else
            l,
      ],
    );

Layer _refit(Layer l, PrintArea area) {
  final fresh = newDialLayer(area, l.dial!.color);
  if (fresh == null) return l;
  final f = faceOf(area);
  return l.copyWith(
    x: fresh.x,
    y: fresh.y,
    w: fresh.w,
    h: fresh.h,
    rotation: 0,
    dial: l.dial!.copyWith(face: f.face, cornerRadiusMm: f.corner),
  );
}

/// A design without clock numerals gets them on every clock face.
DesignDocument withDials(DesignDocument doc, List<PrintArea> areas) {
  if (doc.layers.any((l) => l.dial != null)) return doc;
  final dials = [
    for (final a in areas)
      if (a.isDial) ?newDialLayer(a, contrastInk('#ffffff')),
  ];
  return dials.isEmpty ? doc : doc.copyWith(layers: [...dials, ...doc.layers]);
}
