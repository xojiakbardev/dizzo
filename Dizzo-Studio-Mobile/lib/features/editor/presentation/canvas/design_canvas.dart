import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../catalog/domain/catalog_models.dart' show parseHexColor;
import '../../domain/design_document.dart';
import '../../domain/print_area.dart';
import '../../domain/snap.dart';
import '../editor_controller.dart';
import '../editor_state.dart';
import '../render/asset_store.dart';
import 'design_painter.dart';
import 'layer_transform.dart';

enum _Mode { none, move, scale, rotate, pinch, view }

/// The open print area at real proportions with its layers. One finger
/// moves a layer or drags a handle, two fingers pinch and turn it (or zoom
/// the view on empty space); a tap selects, a double tap edits text, a long
/// press opens the layer's menu.
class DesignCanvas extends StatefulWidget {
  const DesignCanvas({
    super.key,
    required this.state,
    required this.controller,
    required this.assets,
    required this.onEditLayer,
    required this.onLayerMenu,
    this.showGrid = false,
    this.snapping = true,
  });

  final EditorState state;
  final EditorController controller;
  final AssetStore assets;
  final ValueChanged<String> onEditLayer;
  final void Function(String id, Offset globalPosition) onLayerMenu;
  final bool showGrid;
  final bool snapping;

  @override
  State<DesignCanvas> createState() => DesignCanvasState();
}

class DesignCanvasState extends State<DesignCanvas> {
  static const _pad = 20.0;
  static const _handleTouch = 24.0; // px a finger may miss a handle by
  static const _knobGap = 30.0;

  final _texts = TextPainterCache();
  double _zoom = 1;
  Offset _pan = Offset.zero;

  // The gesture in progress.
  var _mode = _Mode.none;
  Offset? _down;
  int _pointers = 0;
  Layer? _start;
  Layer? _live;
  ({double x, double y})? _startMm;

  // The finger's move since [_startMm], before any clamp: the layer's centre
  // stays that far from where it started, so it comes back under the finger.
  double _dx = 0;
  double _dy = 0;
  double _startDist = 1;
  double _startAngle = 0;
  double _startZoom = 1;
  Offset _startPan = Offset.zero;
  Offset _startFocal = Offset.zero;
  var _recorded = false;
  List<Guide> _guides = const [];
  List<GapMark> _gaps = const [];
  String? _badge;
  var _wasSnapped = false;
  Size _size = Size.zero;

  // The document as the finger leaves it: its strips and everything placed.
  List<PrintStrip>? _liveStrips;
  List<Layer>? _liveAll;
  var _stripMoving = false;
  var _stripAtEdge = false;

  EditorState get _s => widget.state;

  @override
  void didUpdateWidget(DesignCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.selectedArea != widget.state.selectedArea) resetView();
  }

  @override
  void dispose() {
    _texts.clear();
    super.dispose();
  }

  void resetView() {
    setState(() {
      _zoom = 1;
      _pan = Offset.zero;
    });
  }

  CanvasView _view(PrintArea area) {
    final avail = Size(math.max(1, _size.width - 2 * _pad), math.max(1, _size.height - 2 * _pad));
    final base = math.min(avail.width / area.widthMm, avail.height / area.heightMm);
    final s = base * _zoom;
    final origin = Offset(
      _size.width / 2 - area.widthMm * s / 2 + _pan.dx,
      _size.height / 2 - area.heightMm * s / 2 + _pan.dy,
    );
    return CanvasView(origin, s);
  }

  /// What can be touched: the area's own layers (a synced area has none).
  List<Layer> _own(PrintArea area) => [
        for (final l in _s.doc.layers)
          if (l.area == area.key) l.id == _live?.id ? _live! : l,
      ];

  List<Layer> _drawn(PrintArea area) => [
        for (final l in _s.effective)
          if (l.area == area.key) l.id == _live?.id ? _live! : l,
      ];

  bool get _readOnly => _s.linkedFrom != null;

  Layer? get _selected {
    final l = _s.layer;
    if (l == null) return null;
    return _live?.id == l.id ? _live : l;
  }

  Point _mm(CanvasView view, Offset p) {
    final m = view.toMm(p);
    return Point(m.x, m.y);
  }

  Layer? _hit(PrintArea area, CanvasView view, Offset p) {
    final pt = _mm(view, p);
    final slack = 12 / view.scale;
    final sel = _selected;
    // The selected layer keeps the touch where it overlaps others.
    if (sel != null && sel.area == area.key && hitLayer([sel], pt, slack: slack) != null) return sel;
    return hitLayer(_own(area), pt, slack: slack);
  }

  void _onStart(ScaleStartDetails d) {
    final area = _s.area;
    if (area == null) return;
    final view = _view(area);
    final at = _down ?? d.localFocalPoint;
    _pointers = d.pointerCount;
    _mode = _Mode.none;
    _recorded = false;
    _live = null;
    _clearLiveStrips();
    _dx = 0;
    _dy = 0;
    _startFocal = d.localFocalPoint;
    _startZoom = _zoom;
    _startPan = _pan;
    final sel = _selected;
    final p = _mm(view, at);
    if (_pointers == 1 && sel != null && sel.area == area.key && !sel.isLocked && !_readOnly) {
      final h = handleAt(sel, p, _handleTouch / view.scale, _knobGap / view.scale);
      if (h != null) {
        _start = sel;
        _mode = h == HandleKind.scale ? _Mode.scale : _Mode.rotate;
        _startDist = math.max(0.01, math.sqrt(math.pow(p.x - sel.x, 2) + math.pow(p.y - sel.y, 2)));
        _startAngle = math.atan2(p.y - sel.y, p.x - sel.x);
        return;
      }
    }
    final hit = _hit(area, view, at);
    if (hit != null) {
      if (hit.id != _s.selectedLayer) widget.controller.select(hit.id);
      if (!hit.isLocked && !_readOnly) {
        _start = hit;
        // One finger: from where it went down, so the layer stays under it.
        _startMm = view.toMm(_pointers >= 2 ? d.localFocalPoint : at);
        _mode = _pointers >= 2 ? _Mode.pinch : _Mode.move;
        return;
      }
    }
    // Two fingers on a selected layer anywhere: pinch it.
    if (_pointers >= 2 && sel != null && sel.area == area.key && !sel.isLocked && !_readOnly) {
      _start = sel;
      _startMm = view.toMm(d.localFocalPoint);
      _mode = _Mode.pinch;
      return;
    }
    _mode = _Mode.view;
  }

  void _clearLiveStrips() {
    _liveStrips = null;
    _liveAll = null;
    _stripMoving = false;
    _stripAtEdge = false;
  }

  /// The strip is at the end of its travel with the layer pressing on it.
  bool _atEdge(PrintArea area, Layer l, PrintStrip? strip) {
    final m = area.method(l.method);
    final width = m == null ? null : stripWidthOf(m);
    if (m == null || width == null || strip == null) return false;
    const eps = 0.01;
    final z = m.zone;
    final b = layerBox(l);
    return (strip.x <= z.x0 + eps && b.x0 <= z.x0 + eps) || (strip.x >= z.x1 - width - eps && b.x1 >= z.x1 - eps);
  }

  /// The committed document with the live layer: its strips follow the
  /// finger from where they were last frame, in lock-step once pushed.
  void _followLive(PrintArea area, Layer live) {
    final areas = _s.areas;
    final before = _liveStrips ?? _s.doc.strips;
    final doc = withStrips(
      DesignDocument(
        layers: [for (final l in _s.doc.layers) l.id == live.id ? live : l],
        links: _s.doc.links,
        strips: before,
      ),
      areas,
    );
    final strips = doc.strips;
    final prev = stripOf(before, live.area, live.method);
    final next = stripOf(strips, live.area, live.method);
    final moving = prev != null && next != null && prev.x != next.x;
    final atEdge = _atEdge(area, live, next);
    if ((moving && !_stripMoving) || (atEdge && !_stripAtEdge)) HapticFeedback.lightImpact();
    _stripMoving = moving;
    _stripAtEdge = atEdge;
    _liveStrips = strips;
    _liveAll = effectiveLayers(doc, areas);
  }

  void _rebaseline(ScaleUpdateDetails d, CanvasView view) {
    _pointers = d.pointerCount;
    _startFocal = d.localFocalPoint;
    _startZoom = _zoom;
    _startPan = _pan;
    final start = _start;
    if (start != null) {
      final live = _live ?? start;
      final moves = _mode == _Mode.move || _mode == _Mode.pinch;
      _start = moves ? live.copyWith(x: start.x + _dx, y: start.y + _dy) : live;
      _dx = 0;
      _dy = 0;
      _startMm = view.toMm(d.localFocalPoint);
      if (_mode == _Mode.move && _pointers >= 2) _mode = _Mode.pinch;
      if (_mode == _Mode.pinch && _pointers < 2) _mode = _Mode.move;
    }
  }

  void _onUpdate(ScaleUpdateDetails d) {
    final area = _s.area;
    if (area == null || _mode == _Mode.none) return;
    final view = _view(area);
    if (d.pointerCount != _pointers) {
      _rebaseline(d, view);
      return;
    }
    if (_mode == _Mode.view) {
      _updateView(d);
      return;
    }
    final start = _start;
    if (start == null) return;
    final layers = _own(area);
    final threshold = 8 / view.scale;
    final p = _mm(view, d.localFocalPoint);
    final strips = _liveStrips ?? _s.doc.strips;
    TransformResult r;
    switch (_mode) {
      case _Mode.move:
        final s0 = _startMm!;
        _dx = p.x - s0.x;
        _dy = p.y - s0.y;
        r = moveLayer(
          area,
          start,
          _dx,
          _dy,
          layers,
          threshold: threshold,
          snapping: widget.snapping,
          strips: strips,
        );
      case _Mode.scale:
        final dist = math.sqrt(math.pow(p.x - start.x, 2) + math.pow(p.y - start.y, 2));
        r = scaleLayer(
          area,
          start,
          dist / _startDist,
          layers,
          threshold: threshold,
          snapping: widget.snapping,
          strips: strips,
        );
      case _Mode.rotate:
        final angle = math.atan2(p.y - start.y, p.x - start.x);
        r = rotateLayer(area, start, (angle - _startAngle) * 180 / math.pi, layers);
      case _Mode.pinch:
        final s0 = _startMm!;
        _dx = p.x - s0.x;
        _dy = p.y - s0.y;
        r = pinchLayer(
          area,
          start,
          d.scale,
          d.rotation * 180 / math.pi,
          _dx,
          _dy,
          layers,
          threshold: threshold,
          strips: strips,
        );
      case _Mode.none:
      case _Mode.view:
        return;
    }
    if (r.layer == (_live ?? start)) return;
    if (!_recorded) {
      _recorded = true;
      widget.controller.checkpoint();
    }
    final snapped = r.guides.isNotEmpty;
    if (snapped && !_wasSnapped) HapticFeedback.selectionClick();
    _wasSnapped = snapped;
    if (_liveAll == null) _atStart(area, start);
    _followLive(area, r.layer);
    setState(() {
      _live = r.layer;
      _guides = r.guides;
      _gaps = r.gaps;
      _badge = r.badge;
    });
  }

  /// Whether the strip already rests at an edge (no haptic for that).
  void _atStart(PrintArea area, Layer start) =>
      _stripAtEdge = _atEdge(area, start, stripOf(_s.doc.strips, start.area, start.method));

  void _updateView(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      final zoom = (_startZoom * d.scale).clamp(1.0, 8.0);
      // Keep the point under the fingers where it is.
      final centre = Offset(_size.width / 2, _size.height / 2);
      final k = zoom / _startZoom;
      final pan = (_startPan - (_startFocal - centre)) * k + (d.localFocalPoint - centre);
      setState(() {
        _zoom = zoom;
        _pan = zoom == 1 ? Offset.zero : pan;
      });
    } else if (_zoom > 1) {
      setState(() => _pan = _startPan + (d.localFocalPoint - _startFocal));
    }
  }

  void _onEnd(ScaleEndDetails d) {
    final live = _live;
    if (live != null && _recorded) widget.controller.patchLayer(live, strips: _liveStrips);
    _down = null;
    setState(() {
      _mode = _Mode.none;
      _live = null;
      _clearLiveStrips();
      _start = null;
      _guides = const [];
      _gaps = const [];
      _badge = null;
      _wasSnapped = false;
    });
  }

  void _onTapUp(TapUpDetails d) {
    final area = _s.area;
    if (area == null) return;
    final hit = _hit(area, _view(area), d.localPosition);
    widget.controller.select(hit?.id);
  }

  void _onDoubleTap(TapDownDetails d) {
    final area = _s.area;
    if (area == null) return;
    final hit = _hit(area, _view(area), d.localPosition);
    if (hit == null) {
      if (_zoom != 1) resetView();
      return;
    }
    widget.controller.select(hit.id);
    if (!_readOnly) widget.onEditLayer(hit.id);
  }

  void _onLongPress(LongPressStartDetails d) {
    final area = _s.area;
    if (area == null || _readOnly) return;
    final hit = _hit(area, _view(area), d.localPosition);
    if (hit == null) return;
    HapticFeedback.mediumImpact();
    widget.controller.select(hit.id);
    widget.onLayerMenu(hit.id, d.globalPosition);
  }

  @override
  Widget build(BuildContext context) {
    final area = _s.area;
    final c = context.colors;
    if (area == null) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, box) {
        _size = box.biggest;
        final view = _view(area);
        final selected = _selected;
        return Listener(
          onPointerDown: (e) {
            if (_mode == _Mode.none) _down = e.localPosition;
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onStart,
            onScaleUpdate: _onUpdate,
            onScaleEnd: _onEnd,
            onTapUp: _onTapUp,
            onDoubleTapDown: _onDoubleTap,
            onDoubleTap: () {},
            onLongPressStart: _onLongPress,
            child: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: DesignPainter(
                        area: area,
                        layers: _drawn(area),
                        allLayers: _liveAll ?? _s.effective,
                        strips: _liveStrips ?? _s.strips,
                        view: view,
                        surface: parseHexColor(_s.surfaceHex),
                        engraveTint: parseHexColor(_s.engraveColor),
                        assets: widget.assets,
                        texts: _texts,
                        designMethod: _s.designMethod,
                        selected: selected,
                        problemIds: _s.problems.keys.toSet(),
                        guides: _guides,
                        gaps: _gaps,
                        knobGap: _knobGap,
                        showGrid: widget.showGrid,
                        readOnly: _readOnly,
                        colors: EditorColors(
                          selection: c.brand,
                          guide: const Color(0xFFEC4899),
                          problem: c.danger,
                          zone: c.inkMuted,
                          handleFill: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_badge != null)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.ink.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Text(
                            _badge!,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
