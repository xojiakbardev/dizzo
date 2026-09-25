import 'dart:math' as math;

import 'print_area.dart';

// Figma-like snapping in area millimetres: a port of the web's
// `app/lib/design/snap.ts`. A moving box sticks to the zone's edges and
// centre, the area's centre, the other layers' edges and centres, the middle
// between two neighbours, and to gaps equal to one already there.

enum Axis2 { x, y }

class Guide {
  const Guide(this.axis, this.at, this.from, this.to);

  final Axis2 axis;
  final double at;
  final double from;
  final double to;

  @override
  bool operator ==(Object other) =>
      other is Guide && other.axis == axis && other.at == at && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(axis, at, from, to);
}

class GapMark {
  const GapMark(this.axis, this.from, this.to, this.at);

  final Axis2 axis;
  final double from;
  final double to;
  final double at;

  double get mm => to - from;
}

class SnapFrame {
  const SnapFrame({required this.zone, required this.area});

  final Box zone;
  final Box area;
}

class SnapResult {
  const SnapResult(this.dx, this.dy, this.guides, this.gaps);

  final double dx;
  final double dy;
  final List<Guide> guides;
  final List<GapMark> gaps;

  bool get snapped => dx != 0 || dy != 0;
}

double _lo(Box b, Axis2 a) => a == Axis2.x ? b.x0 : b.y0;
double _hi(Box b, Axis2 a) => a == Axis2.x ? b.x1 : b.y1;
double _mid(Box b, Axis2 a) => (_lo(b, a) + _hi(b, a)) / 2;
Axis2 _other(Axis2 a) => a == Axis2.x ? Axis2.y : Axis2.x;
bool _overlaps(Box a, Box b, Axis2 axis) => _lo(a, axis) < _hi(b, axis) && _lo(b, axis) < _hi(a, axis);
Box _shift(Box b, Axis2 axis, double d) => axis == Axis2.x ? b.shift(d, 0) : b.shift(0, d);
const _eps = 0.01;

class _Candidate {
  const _Candidate(this.delta, [this.gap]);
  final double delta;
  final List<GapMark>? gap;
}

_Candidate? _snapAxis(Box box, List<Box> boxes, SnapFrame frame, Axis2 axis, double threshold) {
  final edges = [_lo(box, axis), _mid(box, axis), _hi(box, axis)];
  final lines = [_lo(frame.zone, axis), _mid(frame.zone, axis), _hi(frame.zone, axis), _mid(frame.area, axis)];
  for (final b in boxes) {
    lines.addAll([_lo(b, axis), _mid(b, axis), _hi(b, axis)]);
  }
  _Candidate? best;
  void consider(_Candidate c) {
    if (c.delta.abs() <= threshold && (best == null || c.delta.abs() < best!.delta.abs() - _eps)) best = c;
  }

  for (final line in lines) {
    for (final edge in edges) {
      consider(_Candidate(line - edge));
    }
  }

  final cross = _other(axis);
  final row = boxes.where((b) => _overlaps(b, box, cross)).toList();
  final beforeList = row.where((b) => _hi(b, axis) <= _lo(box, axis) + _eps).toList()
    ..sort((a, b) => _hi(b, axis).compareTo(_hi(a, axis)));
  final afterList = row.where((b) => _lo(b, axis) >= _hi(box, axis) - _eps).toList()
    ..sort((a, b) => _lo(a, axis).compareTo(_lo(b, axis)));
  final before = beforeList.isEmpty ? null : beforeList.first;
  final after = afterList.isEmpty ? null : afterList.first;
  double at(Box a, Box b) =>
      (math.max(_lo(a, cross), _lo(b, cross)) + math.min(_hi(a, cross), _hi(b, cross))) / 2;
  GapMark mark(double from, double to, Box a, Box b) => GapMark(axis, from, to, at(a, b));
  if (before != null && after != null) {
    final delta = (_hi(before, axis) + _lo(after, axis) - _lo(box, axis) - _hi(box, axis)) / 2;
    final moved = _shift(box, axis, delta);
    consider(_Candidate(delta, [
      mark(_hi(before, axis), _lo(moved, axis), before, moved),
      mark(_hi(moved, axis), _lo(after, axis), moved, after),
    ]));
  }
  for (final a in boxes) {
    for (final b in boxes) {
      if (identical(a, b) || !_overlaps(a, b, cross) || _hi(a, axis) > _lo(b, axis)) continue;
      final g = _lo(b, axis) - _hi(a, axis);
      if (g <= _eps) continue;
      final existing = mark(_hi(a, axis), _lo(b, axis), a, b);
      if (before != null) {
        final delta = _hi(before, axis) + g - _lo(box, axis);
        final moved = _shift(box, axis, delta);
        consider(_Candidate(delta, [existing, mark(_hi(before, axis), _lo(moved, axis), before, moved)]));
      }
      if (after != null) {
        final delta = _lo(after, axis) - g - _hi(box, axis);
        final moved = _shift(box, axis, delta);
        consider(_Candidate(delta, [existing, mark(_hi(moved, axis), _lo(after, axis), moved, after)]));
      }
    }
  }
  return best;
}

/// Guide lines through every edge or centre of [box] that lines up with a target.
List<Guide> guidesFor(Box box, List<Box> boxes, SnapFrame frame) {
  final guides = <Guide>[];
  for (final axis in Axis2.values) {
    final cross = _other(axis);
    final edges = [_lo(box, axis), _mid(box, axis), _hi(box, axis)];
    void add(double at, double from, double to) {
      if (!edges.any((e) => (e - at).abs() < _eps)) return;
      guides.add(Guide(axis, at, math.min(from, _lo(box, cross)), math.max(to, _hi(box, cross))));
    }

    for (final at in [_lo(frame.zone, axis), _mid(frame.zone, axis), _hi(frame.zone, axis)]) {
      add(at, _lo(frame.zone, cross), _hi(frame.zone, cross));
    }
    add(_mid(frame.area, axis), _lo(frame.area, cross), _hi(frame.area, cross));
    for (final b in boxes) {
      for (final at in [_lo(b, axis), _mid(b, axis), _hi(b, axis)]) {
        add(at, _lo(b, cross), _hi(b, cross));
      }
    }
  }
  return guides;
}

/// Where a box being moved sticks.
SnapResult snapMove(Box box, List<Box> boxes, SnapFrame frame, double threshold) {
  final x = _snapAxis(box, boxes, frame, Axis2.x, threshold);
  final y = _snapAxis(box, boxes, frame, Axis2.y, threshold);
  final dx = x?.delta ?? 0;
  final dy = y?.delta ?? 0;
  final moved = box.shift(dx, dy);
  return SnapResult(dx, dy, guidesFor(moved, boxes, frame), [...?x?.gap, ...?y?.gap]);
}

/// Uniform scale about the centre that lands an edge on a target line.
double? snapScale(Box box, List<Box> boxes, SnapFrame frame, double threshold) {
  double? bestF;
  double? bestD;
  for (final axis in Axis2.values) {
    final c = _mid(box, axis);
    final half = (_hi(box, axis) - _lo(box, axis)) / 2;
    if (half <= _eps) continue;
    final lines = [_lo(frame.zone, axis), _hi(frame.zone, axis)];
    for (final b in boxes) {
      lines.addAll([_lo(b, axis), _hi(b, axis)]);
    }
    for (final line in lines) {
      final edge = line < c ? _lo(box, axis) : _hi(box, axis);
      final d = (line - edge).abs();
      if (d <= threshold && (bestD == null || d < bestD)) {
        bestD = d;
        bestF = (line - c).abs() / half;
      }
    }
  }
  return bestF;
}

/// Rotation that sticks to every 45° (15° steps when [fine]).
double snapAngle(double angle, {bool fine = false}) {
  final step = fine ? 15.0 : 45.0;
  final snapped = (angle / step).round() * step;
  if (fine || (angle - snapped).abs() < 5) return snapped == -180 ? 180 : snapped;
  return angle;
}
