import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../../catalog/domain/catalog_models.dart' show parseHexColor;
import '../../domain/design_document.dart';
import '../../domain/dial.dart';
import '../../domain/editor_models.dart' show isMonoSticker;
import '../../domain/graphics.dart';
import '../../domain/print_area.dart';
import '../../domain/snap.dart';
import '../render/asset_store.dart';
import '../render/design_fonts.dart';

/// How millimetres map to the canvas: `px = origin + mm * scale`.
class CanvasView {
  const CanvasView(this.origin, this.scale);

  final Offset origin;
  final double scale;

  Offset toPx(double x, double y) => Offset(origin.dx + x * scale, origin.dy + y * scale);
  ({double x, double y}) toMm(Offset p) => (x: (p.dx - origin.dx) / scale, y: (p.dy - origin.dy) / scale);
}

/// Text lines laid out once per text and size.
class TextPainterCache {
  final _cache = <String, List<TextPainter>>{};
  int _fonts = -1;

  List<TextPainter> lines(TextSource t, double px, Color color) {
    if (_fonts != fontsRevision.value) {
      clear();
      _fonts = fontsRevision.value;
    }
    final key = '${t.font}|${t.bold}|${t.italic}|${t.content}|${px.toStringAsFixed(2)}|${color.toARGB32()}';
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    final style = designTextStyle(t.font, bold: t.bold, italic: t.italic, px: px, color: color);
    final list = [
      for (final line in t.content.split('\n'))
        TextPainter(text: TextSpan(text: line, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout(),
    ];
    _cache[key] = list;
    while (_cache.length > 120) {
      final first = _cache.keys.first;
      for (final p in _cache.remove(first)!) {
        p.dispose();
      }
    }
    return list;
  }

  TextPainter label(String text, String font, bool bold, bool italic, double px, Color color) {
    final t = TextSource(content: text, font: font, sizeMm: 0, color: '', bold: bold, italic: italic);
    return lines(t, px, color).first;
  }

  void clear() {
    for (final list in _cache.values) {
      for (final p in list) {
        p.dispose();
      }
    }
    _cache.clear();
  }
}

class EditorColors {
  const EditorColors({
    required this.selection,
    required this.guide,
    required this.problem,
    required this.zone,
    required this.handleFill,
  });

  final Color selection;
  final Color guide;
  final Color problem;
  final Color zone;
  final Color handleFill;
}

class DesignPainter extends CustomPainter {
  DesignPainter({
    required this.area,
    required this.layers,
    required this.allLayers,
    this.strips = const [],
    required this.view,
    required this.surface,
    required this.engraveTint,
    required this.assets,
    required this.texts,
    required this.colors,
    required this.designMethod,
    this.selected,
    this.problemIds = const {},
    this.guides = const [],
    this.gaps = const [],
    this.handleRadius = 11,
    this.knobGap = 30,
    this.showGrid = false,
    this.readOnly = false,
  }) : super(repaint: Listenable.merge([assets, fontsRevision]));

  final PrintArea area;

  /// The area's layers in drawing order (synced copies included).
  final List<Layer> layers;

  /// Everything placed (where a strip is), live while a finger moves a layer.
  final List<Layer> allLayers;

  /// Where the laser strips stand (live too).
  final List<PrintStrip> strips;
  final CanvasView view;
  final Color surface;
  final Color engraveTint;
  final AssetStore assets;
  final TextPainterCache texts;
  final EditorColors colors;
  final String? designMethod;
  final Layer? selected;
  final Set<String> problemIds;
  final List<Guide> guides;
  final List<GapMark> gaps;

  /// Handle radius and the rotate knob's distance, in logical pixels.
  final double handleRadius;
  final double knobGap;
  final bool showGrid;
  final bool readOnly;

  double get s => view.scale;

  Rect get _areaRect => Rect.fromLTWH(view.origin.dx, view.origin.dy, area.widthMm * s, area.heightMm * s);

  Path _facePath() {
    final r = _areaRect;
    if (area.round) return Path()..addOval(r);
    final corner = math.min(area.cornerRadiusMm * s, math.min(r.width, r.height) / 2);
    return Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(corner)));
  }

  Rect _boxRect(Box b) => Rect.fromLTRB(
        view.origin.dx + b.x0 * s,
        view.origin.dy + b.y0 * s,
        view.origin.dx + b.x1 * s,
        view.origin.dy + b.y1 * s,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final face = _facePath();
    // The product's surface under the area.
    canvas.drawShadow(face, Colors.black, 6, false);
    canvas.drawPath(face, Paint()..color = surface);
    canvas.drawPath(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.08),
    );
    if (showGrid) _grid(canvas, face);

    // Zones of the design's method: a strip strong, where it can travel faint.
    final zoneMethod = area.method(designMethod ?? '') ?? (area.methods.isEmpty ? null : area.methods.first);
    if (zoneMethod != null) {
      final zone = printZone(area, zoneMethod, allLayers, strips);
      if (zone == zoneMethod.zone) {
        _dashedRect(canvas, _boxRect(zone), colors.zone.withValues(alpha: 0.55), 1);
      } else {
        final travel = _boxRect(zoneMethod.zone);
        canvas.drawRect(travel, Paint()..color = colors.zone.withValues(alpha: 0.04));
        _dashedRect(canvas, travel, colors.zone.withValues(alpha: 0.3), 1);
        final strip = _boxRect(zone);
        canvas.drawRect(strip, Paint()..color = colors.zone.withValues(alpha: 0.07));
        canvas.drawRect(
          strip,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = colors.zone,
        );
      }
    }

    for (final l in layers) {
      final m = area.method(l.method);
      if (m == null) continue;
      final mono = !m.colorsAllowed;
      final zone = printZone(area, m, allLayers, strips);
      if (l.crops && !inside(layerBox(l), zone)) {
        // What the zone crops away, faintly.
        canvas.saveLayer(null, Paint()..color = const Color(0x38000000));
        _layer(canvas, l, mono);
        canvas.restore();
      }
      canvas.save();
      if (l.crops) canvas.clipRect(_boxRect(zone));
      _layer(canvas, l, mono);
      canvas.restore();
    }

    for (final l in layers) {
      if (problemIds.contains(l.id) || problemIds.contains(sourceId(l.id))) {
        _outline(canvas, l, colors.problem, dashed: true, width: 1.6);
      }
    }
    _guides(canvas);
    final sel = selected;
    if (sel != null && sel.area == area.key) _selection(canvas, sel);
  }

  void _grid(Canvas canvas, Path face) {
    canvas.save();
    canvas.clipPath(face);
    final p = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    final step = 10 * s;
    if (step >= 6) {
      final r = _areaRect;
      for (var x = r.left + step; x < r.right; x += step) {
        canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), p);
      }
      for (var y = r.top + step; y < r.bottom; y += step) {
        canvas.drawLine(Offset(r.left, y), Offset(r.right, y), p);
      }
    }
    canvas.restore();
  }

  Color _ink(String hex, bool mono) => mono ? engraveTint : parseHexColor(hex);

  void _layer(Canvas canvas, Layer l, bool mono) {
    canvas.save();
    canvas.translate(view.origin.dx + l.x * s, view.origin.dy + l.y * s);
    canvas.rotate(l.rotation * math.pi / 180);
    final w = l.w * s;
    final h = l.h * s;
    final dst = Rect.fromLTWH(-w / 2, -h / 2, w, h);
    switch (l.kind) {
      case LayerKind.image:
        _image(canvas, l, dst, mono);
      case LayerKind.text:
        _text(canvas, l, w, h, mono);
      case LayerKind.dial:
        _dial(canvas, l, w, h, mono);
      case LayerKind.graphic:
        _graphic(canvas, l, dst, mono);
    }
    canvas.restore();
  }

  void _image(Canvas canvas, Layer l, Rect dst, bool mono) {
    final url = l.image?.url ?? '';
    final img = mono ? assets.monoImage(url) : assets.image(url);
    if (img == null) {
      canvas.drawRect(dst, Paint()..color = Colors.black.withValues(alpha: assets.failed(url) ? 0.18 : 0.06));
      return;
    }
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true;
    if (mono) paint.colorFilter = ColorFilter.mode(engraveTint, BlendMode.srcIn);
    canvas.drawImageRect(img, src, dst, paint);
  }

  void _text(Canvas canvas, Layer l, double w, double h, bool mono) {
    final t = l.text!;
    final layout = layoutText(t);
    final painters = texts.lines(t, t.sizeMm * s, _ink(t.color, mono));
    for (var i = 0; i < painters.length && i < layout.baselines.length; i++) {
      final p = painters[i];
      final ax = -w / 2 + layout.anchor * s;
      final dx = switch (t.align) {
        LineAlign.left => ax,
        LineAlign.center => ax - p.width / 2,
        LineAlign.right => ax - p.width,
      };
      final baseline = -h / 2 + layout.baselines[i] * s;
      p.paint(canvas, Offset(dx, baseline - p.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
    }
  }

  void _dial(Canvas canvas, Layer l, double w, double h, bool mono) {
    final d = l.dial!;
    final color = _ink(d.color, mono);
    final px = d.sizeMm * s;
    final laid = layoutDial(d, w, h, s, (label, size) => texts.label(label, d.font, d.bold, d.italic, size, color).width);
    final stroke = Paint()
      ..color = color
      ..strokeCap = StrokeCap.butt;
    for (final t in laid.ticks) {
      canvas.drawLine(Offset(t.x0, t.y0), Offset(t.x1, t.y1), stroke..strokeWidth = t.width);
    }
    for (final n in laid.numerals) {
      final p = texts.label(n.label, d.font, d.bold, d.italic, px, color);
      // The canvas's "middle" baseline: centred on the em box.
      final middle = p.computeDistanceToActualBaseline(TextBaseline.alphabetic) - px * 0.35;
      p.paint(canvas, Offset(n.x - p.width / 2, n.y - middle));
    }
  }

  void _graphic(Canvas canvas, Layer l, Rect dst, bool mono) {
    final g = l.graphic!;
    if (g.library == 'sticker') {
      final pic = assets.sticker(g.name);
      if (pic == null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(dst, Radius.circular(dst.shortestSide * 0.2)),
          Paint()..color = Colors.black.withValues(alpha: 0.05),
        );
        return;
      }
      final tint = mono ? engraveTint : (isMonoSticker(g.name) ? parseHexColor(g.color) : null);
      canvas.save();
      canvas.clipRect(dst);
      if (tint != null) canvas.saveLayer(dst, Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.srcIn));
      canvas.translate(dst.left, dst.top);
      canvas.scale(dst.width / math.max(1, pic.size.width), dst.height / math.max(1, pic.size.height));
      canvas.drawPicture(pic.picture);
      if (tint != null) canvas.restore();
      canvas.restore();
      return;
    }
    final def = resolveGraphic(g.library, g.name);
    if (def == null) return;
    canvas.save();
    canvas.translate(dst.left, dst.top);
    canvas.scale(dst.width / def.width, dst.height / def.height);
    final paint = Paint()
      ..color = _ink(g.color, mono)
      ..isAntiAlias = true;
    for (final path in graphicPaths(def)) {
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  List<Offset> _corners(Layer l, {double grow = 0}) {
    final a = l.rotation * math.pi / 180;
    final c = view.toPx(l.x, l.y);
    final hw = l.w * s / 2 + grow;
    final hh = l.h * s / 2 + grow;
    Offset at(double x, double y) => c + Offset(x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a));
    return [at(-hw, -hh), at(hw, -hh), at(hw, hh), at(-hw, hh)];
  }

  void _outline(Canvas canvas, Layer l, Color color, {bool dashed = false, double width = 1.5}) {
    final pts = _corners(l, grow: 2);
    final path = Path()..addPolygon(pts, true);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    if (dashed) {
      _dashedPath(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void _selection(Canvas canvas, Layer l) {
    final locked = l.isLocked || readOnly;
    _outline(canvas, l, colors.selection, width: 2);
    if (locked) return;
    final pts = _corners(l, grow: 2);
    final a = l.rotation * math.pi / 180;
    final c = view.toPx(l.x, l.y);
    final up = Offset(math.sin(a), -math.cos(a));
    final top = c + up * (l.h * s / 2 + 2);
    final knob = c + up * (l.h * s / 2 + knobGap);
    final line = Paint()
      ..color = colors.selection
      ..strokeWidth = 1.5;
    canvas.drawLine(top, knob, line);
    final fill = Paint()..color = colors.handleFill;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = colors.selection;
    for (final p in pts) {
      canvas.drawCircle(p, handleRadius * 0.62, fill);
      canvas.drawCircle(p, handleRadius * 0.62, ring);
    }
    canvas.drawCircle(knob, handleRadius * 0.8, Paint()..color = colors.selection);
    // A turning arrow on the knob.
    final arrow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = colors.handleFill;
    final r = handleRadius * 0.42;
    canvas.drawArc(Rect.fromCircle(center: knob, radius: r), -math.pi * 0.9, math.pi * 1.5, false, arrow);
  }

  void _guides(Canvas canvas) {
    final paint = Paint()
      ..color = colors.guide
      ..strokeWidth = 1;
    for (final g in guides) {
      if (g.axis == Axis2.x) {
        canvas.drawLine(view.toPx(g.at, g.from), view.toPx(g.at, g.to), paint);
      } else {
        canvas.drawLine(view.toPx(g.from, g.at), view.toPx(g.to, g.at), paint);
      }
    }
    for (final gap in gaps) {
      final (a, b) = gap.axis == Axis2.x
          ? (view.toPx(gap.from, gap.at), view.toPx(gap.to, gap.at))
          : (view.toPx(gap.at, gap.from), view.toPx(gap.at, gap.to));
      canvas.drawLine(a, b, paint..strokeWidth = 1.5);
      final label = TextPainter(
        text: TextSpan(
          text: _mm(gap.mm),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: colors.handleFill),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final mid = (a + b) / 2;
      final box = Rect.fromCenter(center: mid, width: label.width + 8, height: label.height + 4);
      canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(4)), Paint()..color = colors.guide);
      label.paint(canvas, box.topLeft + const Offset(4, 2));
      label.dispose();
    }
  }

  String _mm(double v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? '${r.toInt()}' : '$r';
  }

  void _dashedRect(Canvas canvas, Rect r, Color color, double width) {
    _dashedPath(
      canvas,
      Path()..addRect(r),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  void _dashedPath(Canvas canvas, Path path, Paint paint, {double dash = 6, double gap = 4}) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dash, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DesignPainter old) =>
      old.area != area ||
      !identical(old.layers, layers) ||
      !identical(old.allLayers, allLayers) ||
      !listEquals(old.strips, strips) ||
      old.view.origin != view.origin ||
      old.view.scale != view.scale ||
      old.surface != surface ||
      old.engraveTint != engraveTint ||
      old.selected != selected ||
      old.guides != guides ||
      old.gaps != gaps ||
      old.problemIds != problemIds ||
      old.showGrid != showGrid ||
      old.designMethod != designMethod ||
      old.readOnly != readOnly;
}
