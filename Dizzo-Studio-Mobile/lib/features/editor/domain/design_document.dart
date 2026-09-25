import 'dart:math' as math;

import '../../../core/l10n/app_language.dart';
import '../../../core/utils/json.dart';
import 'print_area.dart';

// The Studio's design document: a port of the web's
// `app/lib/design/document.ts` (the backend's `app/schemas/design.py`).
// The JSON is the web's exactly (same keys, same order, absent optionals
// left out, whole numbers without ".0"), so a design opens on both.
//
// Millimetres in the print area: origin at the area's top-left corner,
// x right, y down. A layer is its centre, its unrotated size and a
// clockwise rotation in degrees. `area: null` = the current shape has no
// area with the layer's key; the layer is kept but never printed.

const designFonts = <String>[
  'Montserrat', 'Roboto', 'Open Sans', 'Rubik', 'Oswald', 'Lora', 'Playfair Display', 'PT Serif', 'Comfortaa',
  'Caveat', 'Lobster', 'Pacifico',
];

const monoColor = '#000000';
const backgroundPrefix = 'bg-';
const dialPrefix = 'dial-';
const maxLayers = 40;

/// A number as JavaScript's JSON writes it: whole numbers without ".0".
Object jsNum(double v) {
  if (!v.isFinite) return 0;
  if (v == v.roundToDouble() && v.abs() < 9007199254740992) return v.toInt();
  return v;
}

double _d(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? fallback;

enum LayerKind { image, text, graphic, dial }

enum LayerLock { user, system }

class ImageSource {
  const ImageSource({required this.mediaId, required this.url, required this.pxW, required this.pxH});

  factory ImageSource.fromJson(Json j) =>
      ImageSource(mediaId: j.str('media_id'), url: j.str('url'), pxW: j.integer('px_w', 1), pxH: j.integer('px_h', 1));

  final String mediaId;
  final String url;
  final int pxW;
  final int pxH;

  Json toJson() => {'media_id': mediaId, 'url': url, 'px_w': pxW, 'px_h': pxH};

  @override
  bool operator ==(Object other) =>
      other is ImageSource && other.mediaId == mediaId && other.url == url && other.pxW == pxW && other.pxH == pxH;

  @override
  int get hashCode => Object.hash(mediaId, url, pxW, pxH);
}

enum LineAlign { left, center, right }

class TextSource {
  const TextSource({
    required this.content,
    required this.font,
    required this.sizeMm,
    required this.color,
    this.align = LineAlign.center,
    this.bold = false,
    this.italic = false,
  });

  factory TextSource.fromJson(Json j) => TextSource(
        content: j.str('content'),
        font: j.str('font', 'Montserrat'),
        sizeMm: _d(j['size_mm'], 10),
        color: j.str('color', '#111827'),
        align: LineAlign.values.firstWhere((a) => a.name == j['align'], orElse: () => LineAlign.center),
        bold: j.boolean('bold'),
        italic: j.boolean('italic'),
      );

  final String content;
  final String font;
  final double sizeMm;
  final String color;
  final LineAlign align;
  final bool bold;
  final bool italic;

  TextSource copyWith({
    String? content,
    String? font,
    double? sizeMm,
    String? color,
    LineAlign? align,
    bool? bold,
    bool? italic,
  }) =>
      TextSource(
        content: content ?? this.content,
        font: font ?? this.font,
        sizeMm: sizeMm ?? this.sizeMm,
        color: color ?? this.color,
        align: align ?? this.align,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
      );

  Json toJson() => {
        'content': content,
        'font': font,
        'size_mm': jsNum(sizeMm),
        'color': color,
        'align': align.name,
        'bold': bold,
        'italic': italic,
      };

  @override
  bool operator ==(Object other) =>
      other is TextSource &&
      other.content == content &&
      other.font == font &&
      other.sizeMm == sizeMm &&
      other.color == color &&
      other.align == align &&
      other.bold == bold &&
      other.italic == italic;

  @override
  int get hashCode => Object.hash(content, font, sizeMm, color, align, bold, italic);
}

/// A vector from the bundled library (`shape`, `icon`) or a sticker.
class GraphicSource {
  const GraphicSource({required this.library, required this.name, required this.color});

  factory GraphicSource.fromJson(Json j) =>
      GraphicSource(library: j.str('library', 'shape'), name: j.str('name'), color: j.str('color', monoColor));

  /// `shape` | `icon` | `sticker`.
  final String library;
  final String name;
  final String color;

  GraphicSource copyWith({String? color}) => GraphicSource(library: library, name: name, color: color ?? this.color);

  Json toJson() => {'library': library, 'name': name, 'color': color};

  @override
  bool operator ==(Object other) =>
      other is GraphicSource && other.library == library && other.name == name && other.color == color;

  @override
  int get hashCode => Object.hash(library, name, color);
}

/// A clock face's numerals and minute marks.
class DialSource {
  const DialSource({
    required this.font,
    required this.sizeMm,
    required this.color,
    this.bold = true,
    this.italic = false,
    this.numerals = 'arabic',
    this.ticks = true,
    this.face = 'round',
    this.cornerRadiusMm = 0,
  });

  factory DialSource.fromJson(Json j) => DialSource(
        font: j.str('font', 'Montserrat'),
        sizeMm: _d(j['size_mm'], 8),
        color: j.str('color', monoColor),
        bold: j.boolean('bold'),
        italic: j.boolean('italic'),
        numerals: j.str('numerals', 'arabic'),
        ticks: j.boolean('ticks', true),
        face: j.str('face', 'round'),
        cornerRadiusMm: _d(j['corner_radius_mm']),
      );

  final String font;
  final double sizeMm;
  final String color;
  final bool bold;
  final bool italic;

  /// `arabic` | `roman` | `none`.
  final String numerals;
  final bool ticks;

  /// `round` | `rect`.
  final String face;
  final double cornerRadiusMm;

  DialSource copyWith({
    String? font,
    double? sizeMm,
    String? color,
    bool? bold,
    bool? italic,
    String? numerals,
    bool? ticks,
    String? face,
    double? cornerRadiusMm,
  }) =>
      DialSource(
        font: font ?? this.font,
        sizeMm: sizeMm ?? this.sizeMm,
        color: color ?? this.color,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        numerals: numerals ?? this.numerals,
        ticks: ticks ?? this.ticks,
        face: face ?? this.face,
        cornerRadiusMm: cornerRadiusMm ?? this.cornerRadiusMm,
      );

  Json toJson() => {
        'font': font,
        'size_mm': jsNum(sizeMm),
        'color': color,
        'bold': bold,
        'italic': italic,
        'numerals': numerals,
        'ticks': ticks,
        'face': face,
        'corner_radius_mm': jsNum(cornerRadiusMm),
      };

  @override
  bool operator ==(Object other) =>
      other is DialSource &&
      other.font == font &&
      other.sizeMm == sizeMm &&
      other.color == color &&
      other.bold == bold &&
      other.italic == italic &&
      other.numerals == numerals &&
      other.ticks == ticks &&
      other.face == face &&
      other.cornerRadiusMm == cornerRadiusMm;

  @override
  int get hashCode => Object.hash(font, sizeMm, color, bold, italic, numerals, ticks, face, cornerRadiusMm);
}

const _unset = Object();

class Layer {
  const Layer({
    required this.id,
    required this.area,
    required this.method,
    required this.kind,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.rotation = 0,
    this.image,
    this.text,
    this.graphic,
    this.dial,
    this.locked,
  });

  factory Layer.fromJson(Json j) => Layer(
        id: j.str('id'),
        area: j['area'] as String?,
        method: j.str('method', 'uv'),
        kind: LayerKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => LayerKind.image),
        x: _d(j['x_mm']),
        y: _d(j['y_mm']),
        w: _d(j['w_mm'], 1),
        h: _d(j['h_mm'], 1),
        rotation: _d(j['rotation']),
        image: j.objOrNull('image')?.let(ImageSource.fromJson),
        text: j.objOrNull('text')?.let(TextSource.fromJson),
        graphic: j.objOrNull('graphic')?.let(GraphicSource.fromJson),
        dial: j.objOrNull('dial')?.let(DialSource.fromJson),
        locked: switch (j['locked']) {
          'user' => LayerLock.user,
          'system' => LayerLock.system,
          _ => null,
        },
      );

  final String id;
  final String? area;

  /// `uv` | `engrave`.
  final String method;
  final LayerKind kind;
  final double x;
  final double y;
  final double w;
  final double h;
  final double rotation;
  final ImageSource? image;
  final TextSource? text;
  final GraphicSource? graphic;
  final DialSource? dial;
  final LayerLock? locked;

  Layer copyWith({
    String? id,
    Object? area = _unset,
    String? method,
    double? x,
    double? y,
    double? w,
    double? h,
    double? rotation,
    ImageSource? image,
    TextSource? text,
    GraphicSource? graphic,
    DialSource? dial,
    Object? locked = _unset,
  }) =>
      Layer(
        id: id ?? this.id,
        area: identical(area, _unset) ? this.area : area as String?,
        method: method ?? this.method,
        kind: kind,
        x: x ?? this.x,
        y: y ?? this.y,
        w: w ?? this.w,
        h: h ?? this.h,
        rotation: rotation ?? this.rotation,
        image: image ?? this.image,
        text: text ?? this.text,
        graphic: graphic ?? this.graphic,
        dial: dial ?? this.dial,
        locked: identical(locked, _unset) ? this.locked : locked as LayerLock?,
      );

  Json toJson() => {
        'id': id,
        'area': area,
        'method': method,
        'kind': kind.name,
        'x_mm': jsNum(x),
        'y_mm': jsNum(y),
        'w_mm': jsNum(w),
        'h_mm': jsNum(h),
        'rotation': jsNum(rotation),
        if (image != null) 'image': image!.toJson(),
        if (text != null) 'text': text!.toJson(),
        if (graphic != null) 'graphic': graphic!.toJson(),
        if (dial != null) 'dial': dial!.toJson(),
        if (locked != null) 'locked': locked!.name,
      };

  bool get isBackground => id.startsWith(backgroundPrefix);

  /// Doesn't move, resize or turn (the customer's lock or the Studio's).
  bool get isLocked => locked != null || isBackground;

  /// The customer can't unlock it.
  bool get systemLocked => locked == LayerLock.system || isBackground;

  /// The single ink colour of a text, graphic or dial (images have none).
  String? get color => text?.color ?? graphic?.color ?? dial?.color;

  /// Anything may stick out of the zone (cropped); clock numerals can't.
  bool get crops => kind != LayerKind.dial;

  Box get box => layerBox(this);

  @override
  bool operator ==(Object other) =>
      other is Layer &&
      other.id == id &&
      other.area == area &&
      other.method == method &&
      other.kind == kind &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h &&
      other.rotation == rotation &&
      other.image == image &&
      other.text == text &&
      other.graphic == graphic &&
      other.dial == dial &&
      other.locked == locked;

  @override
  int get hashCode => Object.hash(id, area, method, kind, x, y, w, h, rotation, image, text, graphic, dial, locked);
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

/// Synced areas: the target shows the source's layers.
class AreaLink {
  const AreaLink(this.source, this.target);

  factory AreaLink.fromJson(Json j) => AreaLink(j.str('source'), j.str('target'));

  final String source;
  final String target;

  Json toJson() => {'source': source, 'target': target};

  @override
  bool operator ==(Object other) => other is AreaLink && other.source == source && other.target == target;

  @override
  int get hashCode => Object.hash(source, target);
}

/// Where an area's laser strip stands (`x_mm`: its left edge in area mm).
/// It moves only when the layers push it (followStrip), so it is stored.
class PrintStrip {
  const PrintStrip({required this.area, required this.method, required this.x});

  factory PrintStrip.fromJson(Json j) =>
      PrintStrip(area: j.str('area'), method: j.str('method', 'engrave'), x: _d(j['x_mm']));

  final String area;
  final String method;
  final double x;

  PrintStrip at(double x) => PrintStrip(area: area, method: method, x: x);

  Json toJson() => {'area': area, 'method': method, 'x_mm': jsNum(x)};

  @override
  bool operator ==(Object other) =>
      other is PrintStrip && other.area == area && other.method == method && other.x == x;

  @override
  int get hashCode => Object.hash(area, method, x);

  @override
  String toString() => 'PrintStrip($area, $method, $x)';
}

PrintStrip? stripOf(List<PrintStrip> strips, String? area, String method) {
  for (final s in strips) {
    if (s.area == area && s.method == method) return s;
  }
  return null;
}

class DesignDocument {
  const DesignDocument({this.layers = const [], this.links = const [], this.strips = const []});

  /// Documents saved before links (or strips) existed have none (normaliseDocument).
  factory DesignDocument.fromJson(Json j) => DesignDocument(
        layers: j.list('layers', Layer.fromJson),
        links: j.list('links', AreaLink.fromJson),
        strips: j.list('strips', PrintStrip.fromJson),
      );

  static const empty = DesignDocument();

  final List<Layer> layers;
  final List<AreaLink> links;

  /// Laser strip positions; an area without one uses the midpoint rule.
  final List<PrintStrip> strips;

  DesignDocument copyWith({List<Layer>? layers, List<AreaLink>? links, List<PrintStrip>? strips}) =>
      DesignDocument(layers: layers ?? this.layers, links: links ?? this.links, strips: strips ?? this.strips);

  Json toJson() => {
        'version': 1,
        'layers': [for (final l in layers) l.toJson()],
        'links': [for (final l in links) l.toJson()],
        'strips': [for (final s in strips) s.toJson()],
      };

  Layer? byId(String? id) {
    if (id == null) return null;
    for (final l in layers) {
      if (l.id == id) return l;
    }
    return null;
  }

  DesignDocument patch(String id, Layer Function(Layer l) change) =>
      copyWith(layers: [for (final l in layers) l.id == id ? change(l) : l]);

  bool get hasBackground => layers.any((l) => l.isBackground);

  /// The area this one is synced from, if it is a target.
  String? syncedFrom(String key) {
    for (final l in links) {
      if (l.target == key) return l.source;
    }
    return null;
  }

  /// The areas that show this one's design.
  List<String> syncTargets(String key) => [for (final l in links) if (l.source == key) l.target];
}

final _rand = math.Random();

String newLayerId() {
  final t = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final r = List.generate(5, (_) => '0123456789abcdefghijklmnopqrstuvwxyz'[_rand.nextInt(36)]).join();
  return 'l$t$r';
}

// ── Geometry ─────────────────────────────────────────────────────────────

/// Axis-aligned bounds of the rotated layer (same as the backend).
Box layerBox(Layer l) => rotatedBox(l.x, l.y, l.w, l.h, l.rotation);

Box rotatedBox(double x, double y, double w, double h, double rotation) {
  final a = rotation * math.pi / 180;
  final hw = (w / 2 * math.cos(a)).abs() + (h / 2 * math.sin(a)).abs();
  final hh = (w / 2 * math.sin(a)).abs() + (h / 2 * math.cos(a)).abs();
  return Box(x - hw, y - hh, x + hw, y + hh);
}

double? _stripWidth(AreaMethod m, Box zone) => m.stripWidth != null && m.stripWidth! > 0
    ? math.min(m.stripWidth!, zone.width)
    : null;

({double lo, double hi}) _spanInZone(String? area, AreaMethod m, Box zone, List<Layer> layers, [String? skip]) {
  var lo = double.infinity;
  var hi = double.negativeInfinity;
  for (final l in layers) {
    if (l.area != area || l.method != m.method || l.id == skip) continue;
    final b = layerBox(l);
    if (b.x1 <= zone.x0 || b.x0 >= zone.x1 || b.y1 <= zone.y0 || b.y0 >= zone.y1) continue;
    lo = math.min(lo, math.max(b.x0, zone.x0));
    hi = math.max(hi, math.min(b.x1, zone.x1));
  }
  return (lo: lo, hi: hi);
}

/// The strip's left edge once the design covers [span]: it stays while the
/// design is inside it and is pushed by the design's edge otherwise, always
/// inside the zone. A design wider than the strip (only older designs, or
/// one that can't shrink further) doesn't move it. The web's followStrip,
/// the backend's follow_strip.
double followStrip(double x, ({double lo, double hi}) span, Box zone, double width) {
  var next = x;
  if (span.lo <= span.hi && span.hi - span.lo <= width + 1e-6) {
    if (span.lo < next) {
      next = span.lo;
    } else if (span.hi > next + width) {
      next = span.hi - width;
    }
  }
  return _clampStrip(next, zone, width);
}

double _clampStrip(double x, Box zone, double width) => math.min(math.max(x, zone.x0), zone.x1 - width);

/// The strip's width for a method (null: it prints the whole zone).
double? stripWidthOf(AreaMethod m) => _stripWidth(m, m.zone);

/// The left edge of a strip centred on the span (the rule before strips were stored).
double _centredStrip(({double lo, double hi}) span, Box zone, double width) =>
    _clampStrip((span.lo <= span.hi ? (span.lo + span.hi) / 2 : zone.cx) - width / 2, zone, width);

/// Where a method's layers are printed: its zone, or a strip where the
/// document stored it, else centred on the layers.
Box printZone(PrintArea area, AreaMethod m, List<Layer> layers, [List<PrintStrip> strips = const []]) {
  final zone = m.zone;
  final width = _stripWidth(m, zone);
  if (width == null) return zone;
  final stored = stripOf(strips, area.key, m.method);
  final x0 = stored != null
      ? _clampStrip(stored.x, zone, width)
      : _centredStrip(_spanInZone(area.key, m, zone, layers), zone, width);
  return Box(x0, zone.y0, x0 + width, zone.y1);
}

/// The document with its strips brought up to date with its layers (the
/// web's settleStrips): an area's strip method that got layers gets a strip
/// (centred on them), one whose layers moved past its edge follows them, one
/// with no layers left (or no strip on this shape) is dropped. The same
/// document when nothing changes. Only the document's own layers count: a
/// synced area has none, and its copies keep the centred strip.
DesignDocument withStrips(DesignDocument doc, List<PrintArea> areas) {
  if (areas.isEmpty) return doc;
  final strips = <PrintStrip>[];
  for (final area in areas) {
    for (final m in area.methods) {
      final zone = m.zone;
      final width = _stripWidth(m, zone);
      if (width == null || !doc.layers.any((l) => l.area == area.key && l.method == m.method)) continue;
      final span = _spanInZone(area.key, m, zone, doc.layers);
      final stored = stripOf(doc.strips, area.key, m.method);
      final x = stored == null ? _centredStrip(span, zone, width) : followStrip(stored.x, span, zone, width);
      strips.add(PrintStrip(area: area.key, method: m.method, x: x));
    }
  }
  return _sameList(strips, doc.strips) ? doc : doc.copyWith(strips: strips);
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

const _eps = 0.05;

bool inside(Box box, Box zone) =>
    box.x0 >= zone.x0 - _eps && box.y0 >= zone.y0 - _eps && box.x1 <= zone.x1 + _eps && box.y1 <= zone.y1 + _eps;

double _roomScale(Layer l, AreaMethod m) {
  final box = layerBox(l);
  final zone = m.zone;
  final maxW = math.min(_stripWidth(m, zone) ?? zone.width, m.maxWidth ?? double.infinity);
  final maxH = math.min(zone.height, m.maxHeight ?? double.infinity);
  return math.min(maxW / box.width, maxH / box.height);
}

/// Largest uniform scale (≤ 1) that makes the layer fit the zone and max size.
double fitScale(Layer l, AreaMethod m) => math.min(1, _roomScale(l, m));

double _stripScale(Layer l, AreaMethod m, List<Layer> layers) {
  final zone = m.zone;
  final width = _stripWidth(m, zone);
  if (width == null) return double.infinity;
  final box = layerBox(l);
  final half = box.width / 2;
  final cx = box.cx;
  final others = _spanInZone(l.area, m, zone, layers, l.id);
  final lo = math.min(others.lo, cx);
  final hi = math.max(others.hi, cx);
  final f = [(width - (cx - lo)) / half, (width - (hi - cx)) / half, width / (2 * half)].reduce(math.min);
  return math.max(f, 1);
}

/// Moves the layer (never resizes it) so its bounds lie inside the box.
Layer clampInto(Layer l, Box zone) {
  final box = layerBox(l);
  var dx = 0.0;
  var dy = 0.0;
  if (box.width <= zone.width) {
    if (box.x0 < zone.x0) {
      dx = zone.x0 - box.x0;
    } else if (box.x1 > zone.x1) {
      dx = zone.x1 - box.x1;
    }
  } else {
    dx = zone.cx - l.x;
  }
  if (box.height <= zone.height) {
    if (box.y0 < zone.y0) {
      dy = zone.y0 - box.y0;
    } else if (box.y1 > zone.y1) {
      dy = zone.y1 - box.y1;
    }
  } else {
    dy = zone.cy - l.y;
  }
  return l.copyWith(x: l.x + dx, y: l.y + dy);
}

Layer clampIntoZone(Layer l, AreaMethod m) => clampInto(l, m.zone);

/// Across the zone, where a layer may go so that it and the area's other
/// [layers] on its method still fit one strip; null without a strip.
({double lo, double hi, double width})? _stripRoom(Layer l, AreaMethod m, List<Layer> layers) {
  final zone = m.zone;
  final width = _stripWidth(m, zone);
  if (width == null) return null;
  final others = _spanInZone(l.area, m, zone, layers, l.id);
  return (lo: math.max(zone.x0, others.hi - width), hi: math.min(zone.x1, others.lo + width), width: width);
}

double _intoSpan(Box box, double lo, double hi) => box.x0 < lo
    ? lo - box.x0
    : box.x1 > hi
        ? hi - box.x1
        : 0.0;

/// Moves the layer across (never resizes it) into its strip room. A layer
/// that can't fit there (wider than the strip, or an older design) is left
/// where it is.
Layer keepInStrip(Layer l, AreaMethod m, List<Layer> layers) {
  final room = _stripRoom(l, m, layers);
  if (room == null) return l;
  final box = layerBox(l);
  if (box.width > room.width + 1e-9 || box.width > room.hi - room.lo + 1e-9) return l;
  final dx = _intoSpan(box, room.lo, room.hi);
  return dx != 0 ? l.copyWith(x: l.x + dx) : l;
}

/// Keeps a layer printable: dials wholly inside, the rest with the centre
/// inside. With [layers] (the area's) and a strip, also across so that it
/// and the others fit one strip, which then follows it (withStrips).
Layer placeInZone(Layer l, AreaMethod m, [List<Layer>? layers]) {
  final z = m.zone;
  final placed = l.crops
      ? l.copyWith(x: math.min(z.x1, math.max(z.x0, l.x)), y: math.min(z.y1, math.max(z.y0, l.y)))
      : clampIntoZone(l, m);
  return layers != null ? keepInStrip(placed, m, layers) : placed;
}

/// A layer arriving on a method with a strip (added, duplicated, placed,
/// converted): placeInZone, then moved across into the strip where it is
/// now, so the strip doesn't move for it. Where the area has no strip yet
/// (no stored one, no other layers) it stays and the strip is centred on
/// it; a layer wider than the strip only keeps to keepInStrip. [layers]:
/// the area's. The web's placeInStrip.
Layer placeInStrip(Layer l, PrintArea area, AreaMethod m, List<Layer> layers, List<PrintStrip> strips) {
  final placed = placeInZone(l, m, layers);
  final others = [for (final o in layers) if (o.id != l.id && o.area == area.key && o.method == m.method) o];
  if (stripWidthOf(m) == null || (stripOf(strips, area.key, m.method) == null && others.isEmpty)) return placed;
  final strip = printZone(area, m, others, strips);
  final box = layerBox(placed);
  if (box.width > strip.width + 1e-9) return placed;
  final dx = _intoSpan(box, strip.x0, strip.x1);
  return dx != 0 ? placed.copyWith(x: placed.x + dx) : placed;
}

/// The layers placed one by one into their strips (placeInStrip), each
/// next to the ones before it (after a method change or a template).
List<Layer> fitIntoStrips(List<Layer> layers, List<PrintArea> areas, List<PrintStrip> strips) {
  final out = <Layer>[];
  for (final l in layers) {
    final area = areaByKey(areas, l.area);
    final m = area?.method(l.method);
    out.add(area != null && m != null ? placeInStrip(l, area, m, out, strips) : l);
  }
  return out;
}

/// The largest scale a layer may take.
double growLimit(Layer l, AreaMethod m, [List<Layer> layers = const []]) {
  final strip = _stripScale(l, m, layers);
  if (!l.crops) return math.min(_roomScale(l, m), strip);
  final zone = m.zone;
  return math.min(strip, 3 * math.max(zone.width, zone.height) / math.max(l.w, l.h));
}

/// Pixels for a length at a DPI (the backend's expected_pixels).
int pixelsAt(double mm, int dpi) => (mm * dpi / 25.4 + 0.5).floor();

PrintArea? areaByKey(List<PrintArea> areas, String? key) {
  if (key == null) return null;
  for (final a in areas) {
    if (a.key == key) return a;
  }
  return null;
}

/// Part of it lies outside the zone (or strip) and won't be printed.
bool sticksOut(Layer l, List<PrintArea> areas, List<Layer> layers, [List<PrintStrip> strips = const []]) {
  final area = areaByKey(areas, l.area);
  final m = area?.method(l.method);
  return area != null && m != null && l.crops && !inside(layerBox(l), printZone(area, m, layers, strips));
}

// ── Problems (the backend's design_rules) ────────────────────────────────

String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

List<String> layerProblems(
  Layer l,
  List<PrintArea> areas,
  List<String> methods,
  List<Layer> layers, [
  List<PrintStrip> strips = const [],
]) {
  if (l.area == null) return const [];
  final t = l10nNow;
  final area = areaByKey(areas, l.area);
  if (area == null) return [t.editorDomainNoArea(l.area!)];
  final m = area.method(l.method);
  if (m == null || !methods.contains(l.method)) return [t.editorDomainNoMethod(area.name)];
  final problems = <String>[];
  final zone = printZone(area, m, layers, strips);
  var box = layerBox(l);
  if (l.crops) {
    box = Box(math.max(box.x0, zone.x0), math.max(box.y0, zone.y0), math.min(box.x1, zone.x1), math.min(box.y1, zone.y1));
  } else if (!inside(box, zone)) {
    problems.add(t.editorDomainOutOfZone);
  }
  if (m.maxWidth != null && box.width > m.maxWidth! + _eps) problems.add(t.editorDomainMaxWidth(_fmt(m.maxWidth!)));
  if (m.maxHeight != null && box.height > m.maxHeight! + _eps) {
    problems.add(t.editorDomainMaxHeight(_fmt(m.maxHeight!)));
  }
  final color = l.color;
  if (color != null && !m.colorsAllowed && color.toLowerCase() != monoColor) problems.add(t.editorDomainNoColor);
  final size = l.text?.sizeMm ?? l.dial?.sizeMm;
  if (size != null && m.minFont != null && size < m.minFont! - 1e-6) {
    problems.add(t.editorDomainMinFont(_fmt(m.minFont!)));
  }
  return problems;
}

/// The whole design is printed one way.
String? designMethodOf(List<Layer> layers, List<String> methods, String? preferred) {
  for (final l in layers) {
    if (methods.contains(l.method)) return l.method;
  }
  if (preferred != null && methods.contains(preferred)) return preferred;
  return methods.isEmpty ? null : methods.first;
}

const _copyMark = '@';
bool isCopy(String id) => id.contains(_copyMark);
String sourceId(String id) => id.split(_copyMark).first;

Map<String, List<String>> designProblems(
  List<Layer> layers,
  List<PrintArea> areas,
  List<String> methods,
  String? designMethod, [
  List<PrintStrip> strips = const [],
]) {
  final t = l10nNow;
  final out = <String, List<String>>{};
  for (final l in layers) {
    final list = [...layerProblems(l, areas, methods, layers, strips)];
    if (designMethod != null && l.method != designMethod) {
      list.add(t.editorDomainOneMethod);
    }
    if (list.isEmpty) continue;
    out[l.id] = list;
    if (isCopy(l.id)) {
      final where = areaByKey(areas, l.area)?.name ?? l.area!;
      (out[sourceId(l.id)] ??= []).addAll(list.map((p) => t.editorDomainProblemAt(where, p)));
    }
  }
  return out;
}

int problemCount(Map<String, List<String>> problems) => problems.keys.where((id) => !isCopy(id)).length;

// ── Area pairs ───────────────────────────────────────────────────────────

bool isPair(PrintArea s, PrintArea t) => s.pairKey == t.key && t.pairKey == s.key;

bool linkable(PrintArea s, PrintArea t) =>
    s.key != t.key && (isPair(s, t) || (s.widthMm == t.widthMm && s.heightMm == t.heightMm));

bool mirrored(PrintArea s, PrintArea t) => isPair(s, t) && t.pairMirror;

Layer copyToPartner(Layer l, PrintArea source, PrintArea target) {
  final base = l.copyWith(id: '${l.id}$_copyMark${target.key}', area: target.key);
  return mirrored(source, target) ? base.copyWith(x: target.widthMm - l.x, rotation: -l.rotation) : base;
}

List<(PrintArea, PrintArea)> validLinks(DesignDocument doc, List<PrintArea> areas) => [
      for (final link in doc.links)
        if (areaByKey(areas, link.source) case final s?)
          if (areaByKey(areas, link.target) case final t?)
            if (linkable(s, t)) (s, t),
    ];

/// Placed layers plus the copies synced areas add: what gets printed.
List<Layer> effectiveLayers(DesignDocument doc, List<PrintArea> areas) {
  final layers = doc.layers.where((l) => l.area != null).toList();
  for (final (source, target) in validLinks(doc, areas)) {
    layers.addAll(doc.layers.where((l) => l.area == source.key).map((l) => copyToPartner(l, source, target)));
  }
  return layers;
}

/// The (area, method) pairs that need a print file.
List<({String area, String method})> printTargets(List<Layer> layers) {
  final seen = <String, ({String area, String method})>{};
  for (final l in layers) {
    if (l.area != null) seen['${l.area}:${l.method}'] = (area: l.area!, method: l.method);
  }
  return seen.values.toList();
}

List<String> usedAreas(List<Layer> layers) => {for (final t in printTargets(layers)) t.area}.toList();

/// The document on another shape: layers of missing areas are parked and
/// links that are no longer linkable are dropped (the web's fitToShape).
DesignDocument fitToShape(DesignDocument doc, List<PrintArea> areas) {
  final keys = {for (final a in areas) a.key};
  return DesignDocument(
    layers: [for (final l in doc.layers) l.area != null && !keys.contains(l.area) ? l.copyWith(area: null) : l],
    links: [
      for (final link in doc.links)
        if (areaByKey(areas, link.source) case final s?)
          if (areaByKey(areas, link.target) case final t?)
            if (linkable(s, t)) link,
    ],
    strips: [for (final s in doc.strips) if (keys.contains(s.area)) s],
  );
}

String layerLabel(Layer l) {
  final text = l.text;
  if (text != null) {
    final c = text.content.replaceAll('\n', ' ');
    return c.length > 24 ? '${c.substring(0, 24)}…' : c;
  }
  final t = l10nNow;
  final g = l.graphic;
  if (g != null) {
    return switch (g.library) {
      'shape' => t.editorDomainLayerShape,
      'icon' => t.editorDomainLayerIcon,
      'sticker' => t.editorPropsSticker,
      _ => t.editorDomainLayerElement,
    };
  }
  if (l.dial != null) return t.editorPropsDialNumerals;
  return t.editorPropsImage;
}

/// Ink that shows on the product: white on dark bodies, near-black otherwise.
String contrastInk(String hex) {
  final h = hex.replaceFirst('#', '');
  if (h.length < 6) return '#111827';
  double c(int i) => (int.tryParse(h.substring(i, i + 2), radix: 16) ?? 255) / 255;
  return 0.2126 * c(0) + 0.7152 * c(2) + 0.0722 * c(4) < 0.45 ? '#ffffff' : '#111827';
}
