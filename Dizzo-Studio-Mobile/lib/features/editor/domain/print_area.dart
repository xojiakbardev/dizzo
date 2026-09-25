import '../../../core/utils/json.dart';

// A shape's print area as the API sends it (`PrintArea` in the web's
// `app/types/catalog.ts`). Lengths arrive as decimal strings.

double _mm(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
double? _mmOrNull(Object? v) {
  if (v == null) return null;
  final d = _mm(v);
  return d == 0 && '$v'.trim().isEmpty ? null : d;
}

/// An axis-aligned box in area millimetres.
class Box {
  const Box(this.x0, this.y0, this.x1, this.y1);

  final double x0;
  final double y0;
  final double x1;
  final double y1;

  double get width => x1 - x0;
  double get height => y1 - y0;
  double get cx => (x0 + x1) / 2;
  double get cy => (y0 + y1) / 2;

  Box shift(double dx, double dy) => Box(x0 + dx, y0 + dy, x1 + dx, y1 + dy);

  @override
  bool operator ==(Object other) =>
      other is Box && other.x0 == x0 && other.y0 == y0 && other.x1 == x1 && other.y1 == y1;

  @override
  int get hashCode => Object.hash(x0, y0, x1, y1);

  @override
  String toString() => 'Box($x0, $y0, $x1, $y1)';
}

/// How one method prints on an area (`AreaMethod`).
class AreaMethod {
  const AreaMethod({
    required this.method,
    required this.zoneX,
    required this.zoneY,
    required this.zoneW,
    required this.zoneH,
    this.maxWidth,
    this.maxHeight,
    this.stripWidth,
    this.minFont,
    this.colorsAllowed = true,
    this.dpi = 300,
  });

  factory AreaMethod.fromJson(Json json) => AreaMethod(
        method: json.str('method'),
        zoneX: _mm(json['zone_x_mm']),
        zoneY: _mm(json['zone_y_mm']),
        zoneW: _mm(json['zone_w_mm']),
        zoneH: _mm(json['zone_h_mm']),
        maxWidth: _mmOrNull(json['max_width_mm']),
        maxHeight: _mmOrNull(json['max_height_mm']),
        stripWidth: _mmOrNull(json['strip_width_mm']),
        minFont: _mmOrNull(json['min_font_mm']),
        colorsAllowed: json.boolean('colors_allowed', true),
        dpi: json.integer('dpi', 300),
      );

  /// `uv` | `engrave`.
  final String method;
  final double zoneX;
  final double zoneY;
  final double zoneW;
  final double zoneH;
  final double? maxWidth;
  final double? maxHeight;

  /// A laser strip this wide that slides across the zone (null: whole zone).
  final double? stripWidth;
  final double? minFont;
  final bool colorsAllowed;
  final int dpi;

  Box get zone => Box(zoneX, zoneY, zoneX + zoneW, zoneY + zoneH);
}

class PrintArea {
  const PrintArea({
    required this.key,
    required this.name,
    required this.widthMm,
    required this.heightMm,
    this.id = 0,
    this.anchor = const {},
    this.sortOrder = 0,
    this.pairKey,
    this.pairMirror = false,
    this.methods = const [],
  });

  factory PrintArea.fromJson(Json json) => PrintArea(
        id: json.integer('id'),
        key: json.str('key'),
        name: json.str('name'),
        widthMm: _mm(json['width_mm']),
        heightMm: _mm(json['height_mm']),
        anchor: json.obj('anchor'),
        sortOrder: json.integer('sort_order'),
        pairKey: json.strOrNull('pair_key'),
        pairMirror: json.boolean('pair_mirror'),
        methods: json.list('methods', AreaMethod.fromJson),
      );

  final int id;
  final String key;
  final String name;
  final double widthMm;
  final double heightMm;
  final Json anchor;
  final int sortOrder;
  final String? pairKey;
  final bool pairMirror;
  final List<AreaMethod> methods;

  Box get box => Box(0, 0, widthMm, heightMm);

  AreaMethod? method(String method) {
    for (final m in methods) {
      if (m.method == method) return m;
    }
    return null;
  }

  bool get _placedModelAnchor =>
      anchor.containsKey('point') && anchor.containsKey('normal') && anchor.containsKey('up');

  /// Only the circle inside the area is printed (a clock's dial).
  bool get round => _placedModelAnchor && anchor['round'] == true;

  /// Rounded corners of a rectangular face.
  double get cornerRadiusMm => _placedModelAnchor ? _mm(anchor['corner_radius_mm']) : 0;

  /// A clock face: new designs start with numerals and minute marks.
  bool get isDial => _placedModelAnchor && anchor['dial'] == true;
}
