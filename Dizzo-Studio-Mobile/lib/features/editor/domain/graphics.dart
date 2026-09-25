import 'dart:ui' as ui;

import 'package:path_parsing/path_parsing.dart';

import '../../../core/l10n/app_language.dart';
import 'icon_set.dart';

// The vector library behind graphic layers (the web's
// `app/lib/design/graphics.ts`): basic shapes and the bundled icons.

class GraphicDef {
  const GraphicDef(this.name, this.label, this.width, this.height, this.paths, {this.keywords = ''});

  final String name;
  final String label;
  final double width;
  final double height;

  /// (d, evenOdd) pairs in the view box.
  final List<(String, bool)> paths;
  final String keywords;
}

const shapes = <GraphicDef>[
  GraphicDef('square', 'Kvadrat', 100, 100, [('M0 0H100V100H0Z', false)]),
  GraphicDef('rounded', 'Yumaloq burchakli', 100, 100, [
    ('M20 0H80A20 20 0 0 1 100 20V80A20 20 0 0 1 80 100H20A20 20 0 0 1 0 80V20A20 20 0 0 1 20 0Z', false),
  ]),
  GraphicDef('circle', 'Doira', 100, 100, [('M50 0A50 50 0 1 1 50 100A50 50 0 1 1 50 0Z', false)]),
  GraphicDef('triangle', 'Uchburchak', 100, 87, [('M50 0L100 87H0Z', false)]),
  GraphicDef('star', 'Yulduz', 100, 95.11, [
    ('M50 0L62.36 35.56L100 36.33L70 59.07L80.9 95.11L50 73.6L19.1 95.11L30 59.07L0 36.33L37.64 35.56Z', false),
  ]),
  GraphicDef('heart', 'Yurak', 100, 92, [
    ('M50 92C30 76 0 58 0 32C0 14 13 4 27 4C38 4 46 10 50 18C54 10 62 4 73 4C87 4 100 14 100 32C100 58 70 76 50 92Z', false),
  ]),
  GraphicDef('hexagon', 'Oltiburchak', 100, 86.6, [('M25 0H75L100 43.3L75 86.6H25L0 43.3Z', false)]),
  GraphicDef('diamond', 'Romb', 100, 100, [('M50 0L100 50L50 100L0 50Z', false)]),
  GraphicDef('burst', 'Nishon', 100, 100, [
    (
      'M50 0L59.84 13.29L75 6.7L76.87 23.13L93.3 25L86.71 40.16L100 50L86.71 59.84L93.3 75L76.87 76.87L75 93.3'
          'L59.84 86.71L50 100L40.16 86.71L25 93.3L23.13 76.87L6.7 75L13.29 59.84L0 50L13.29 40.16L6.7 25L23.13 23.13'
          'L25 6.7L40.16 13.29Z',
      false
    ),
  ]),
  GraphicDef('semicircle', 'Yarim doira', 100, 50, [('M0 50A50 50 0 0 1 100 50Z', false)]),
  GraphicDef('bubble', 'Nutq pufagi', 100, 90, [
    ('M14 0H86A14 14 0 0 1 100 14V56A14 14 0 0 1 86 70H44L24 90V70H14A14 14 0 0 1 0 56V14A14 14 0 0 1 14 0Z', false),
  ]),
  GraphicDef('arrow', 'Strelka', 100, 60, [('M0 20H60V0L100 30L60 60V40H0Z', false)]),
  GraphicDef('plus', 'Plyus', 100, 100, [('M35 0H65V35H100V65H65V100H35V65H0V35H35Z', false)]),
  GraphicDef('ring', 'Halqa', 100, 100, [
    ('M50 0A50 50 0 1 1 50 100A50 50 0 1 1 50 0ZM50 10A40 40 0 1 0 50 90A40 40 0 1 0 50 10Z', true),
  ]),
  GraphicDef('frame', 'Ramka', 100, 100, [('M0 0H100V100H0ZM8 8V92H92V8Z', true)]),
  GraphicDef('frame-round', 'Yumaloq ramka', 100, 100, [
    (
      'M20 0H80A20 20 0 0 1 100 20V80A20 20 0 0 1 80 100H20A20 20 0 0 1 0 80V20A20 20 0 0 1 20 0Z'
          'M20 8A12 12 0 0 0 8 20V80A12 12 0 0 0 20 92H80A12 12 0 0 0 92 80V20A12 12 0 0 0 80 8Z',
      true
    ),
  ]),
  GraphicDef('line', 'Chiziq', 100, 4, [('M0 0H100V4H0Z', false)]),
  GraphicDef('line-double', 'Qo‘sh chiziq', 100, 10, [('M0 0H100V3H0ZM0 7H100V10H0Z', false)]),
];

final Map<String, GraphicDef> _icons = {
  for (final i in icons) i.name: GraphicDef(i.name, i.label, iconViewBox, iconViewBox, i.paths, keywords: i.keywords),
};

List<GraphicDef> get iconDefs => _icons.values.toList(growable: false);

/// [d]'s name in the app language (the built-in [GraphicDef.label] is Uzbek).
String graphicLabel(GraphicDef d, [AppLocalizations? l]) {
  l ??= l10nNow;
  final key = d.name.replaceAll('-', '_');
  final s = shapes.contains(d) ? l.editorDomainShapeLabel(key) : l.editorDomainIconLabel(key);
  return s == '-' ? d.label : s;
}

/// A shape or icon by library and name (stickers are pictures, not here).
GraphicDef? resolveGraphic(String library, String name) {
  if (library == 'shape') {
    for (final s in shapes) {
      if (s.name == name) return s;
    }
    return null;
  }
  if (library == 'icon') return _icons[name];
  return null;
}

final _pathCache = <String, List<ui.Path>>{};

/// The graphic's paths in view-box units (cached).
List<ui.Path> graphicPaths(GraphicDef def) => _pathCache.putIfAbsent('${def.name}:${def.width}', () {
      return [
        for (final (d, evenOdd) in def.paths)
          (_PathBuilder()..parse(d)).path..fillType = evenOdd ? ui.PathFillType.evenOdd : ui.PathFillType.nonZero,
      ];
    });

class _PathBuilder extends PathProxy {
  final path = ui.Path();

  void parse(String d) => writeSvgPathDataToPath(d, this);

  @override
  void close() => path.close();

  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
}
