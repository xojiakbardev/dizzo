import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/design_document.dart';

// The Studio's fonts (the same Google Fonts families the web self-hosts)
// and the text box layout of the web's `layoutText` (render.ts): each line
// is measured at 200 px and the box is padded so no glyph paints outside.

const _lineHeight = 1.2;
const _textPad = 0.06;
const _referencePx = 200.0;

/// Bumped whenever a design font finishes loading: text is measured and
/// painted again.
final fontsRevision = ValueNotifier(0);

/// Off in tests: the platform font is used and nothing is downloaded.
@visibleForTesting
bool designFontsEnabled = true;
final _loaded = <String>{};
final _loading = <String, Future<void>>{};
final _failedAt = <String, DateTime>{};

TextStyle designTextStyle(String font, {required bool bold, required bool italic, required double px, Color? color}) {
  TextStyle style;
  try {
    if (!designFontsEnabled) throw UnsupportedError('fonts off');
    style = GoogleFonts.getFont(
      designFonts.contains(font) ? font : 'Montserrat',
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      fontSize: px,
      color: color,
    );
  } catch (_) {
    // Tests and offline first runs: the platform font.
    style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      fontSize: px,
      color: color,
    );
  }
  unawaited(ensureFont(font, bold: bold, italic: italic));
  return style;
}

/// Waits for a font variant (downloaded once, then cached by google_fonts).
Future<void> ensureFont(String font, {required bool bold, required bool italic}) {
  final key = '$font|$bold|$italic';
  if (!designFontsEnabled || _loaded.contains(key)) return Future.value();
  final failed = _failedAt[key];
  if (failed != null && DateTime.now().difference(failed) < const Duration(seconds: 30)) return Future.value();
  return _loading[key] ??= () async {
    try {
      GoogleFonts.getFont(
        designFonts.contains(font) ? font : 'Montserrat',
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );
      await GoogleFonts.pendingFonts();
      _loaded.add(key);
      _layouts.clear();
      fontsRevision.value++;
    } catch (e) {
      _failedAt[key] = DateTime.now();
      debugPrint('[editor] font $font not loaded: $e');
    } finally {
      unawaited(_loading.remove(key));
    }
  }();
}

class TextLayout {
  const TextLayout({
    required this.w,
    required this.h,
    required this.anchor,
    required this.baselines,
    required this.lines,
  });

  /// The box in mm.
  final double w;
  final double h;

  /// From the box's left edge (mm): the alignment point of every line.
  final double anchor;

  /// From the box's top (mm): each line's baseline.
  final List<double> baselines;
  final List<String> lines;
}

class _Ref {
  const _Ref(this.left, this.right, this.ascent, this.descent, this.lines);
  final double left;
  final double right;
  final double ascent;
  final double descent;
  final List<String> lines;
}

final _layouts = <String, _Ref>{};

_Ref _measure(TextSource t) {
  final key = '${t.font}|${t.bold}|${t.italic}|${t.align.name}|${t.content}';
  final hit = _layouts.remove(key);
  if (hit != null) return _layouts[key] = hit;
  final style = designTextStyle(t.font, bold: t.bold, italic: t.italic, px: _referencePx);
  final lines = t.content.split('\n');
  var left = 0.0;
  var right = 0.0;
  var ascent = 0.0;
  var descent = 0.0;
  for (final line in lines) {
    final p = TextPainter(
      text: TextSpan(text: line.isEmpty ? ' ' : line, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    // The canvas measures ink; italics lean past the advance on the right.
    final width = p.width + (t.italic ? _referencePx * 0.08 : 0);
    final (l, r) = switch (t.align) {
      LineAlign.left => (0.0, width),
      LineAlign.center => (width / 2, width / 2),
      LineAlign.right => (width, 0.0),
    };
    if (l > left) left = l;
    if (r > right) right = r;
    final metrics = p.computeLineMetrics();
    if (metrics.isNotEmpty) {
      if (metrics.first.ascent > ascent) ascent = metrics.first.ascent;
      if (metrics.first.descent > descent) descent = metrics.first.descent;
    } else {
      ascent = ascent < _referencePx * 0.9 ? _referencePx * 0.9 : ascent;
      descent = descent < _referencePx * 0.25 ? _referencePx * 0.25 : descent;
    }
    p.dispose();
  }
  final ref = _Ref(left, right, ascent, descent, lines);
  _layouts[key] = ref;
  if (_layouts.length > 300) _layouts.remove(_layouts.keys.first);
  return ref;
}

/// The box a text needs (the web's `layoutText`), in mm.
TextLayout layoutText(TextSource t) {
  final m = _measure(t);
  final k = t.sizeMm / _referencePx;
  const pad = _textPad * _referencePx;
  final lineHeight = [_lineHeight * _referencePx, m.ascent + m.descent].reduce((a, b) => a > b ? a : b);
  final extra = (lineHeight - m.ascent - m.descent) / 2;
  return TextLayout(
    w: (m.left + m.right + 2 * pad) * k,
    h: (m.lines.length * lineHeight + 2 * pad) * k,
    anchor: (pad + m.left) * k,
    baselines: [for (var i = 0; i < m.lines.length; i++) (pad + i * lineHeight + extra + m.ascent) * k],
    lines: m.lines,
  );
}

/// A label's advance width at [px] (clock numerals).
double measureLabel(String label, double px, {required String font, required bool bold, required bool italic}) {
  final p = TextPainter(
    text: TextSpan(text: label, style: designTextStyle(font, bold: bold, italic: italic, px: px)),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final w = p.width;
  p.dispose();
  return w;
}
