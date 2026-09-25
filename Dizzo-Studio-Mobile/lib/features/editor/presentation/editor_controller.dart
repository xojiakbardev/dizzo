import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cart/presentation/cart_badge.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../designs/data/designs_api.dart' show myDesignsProvider;
import '../data/draft_store.dart';
import '../data/editor_api.dart';
import '../data/engine_bridge.dart';
import '../data/engine_protocol.dart';
import '../data/media_uploader.dart';
import '../domain/design_document.dart';
import '../domain/dial.dart';
import '../domain/editor_models.dart';
import '../domain/graphics.dart';
import '../domain/history.dart';
import '../domain/print_area.dart';
import 'canvas/layer_transform.dart';
import 'editor_state.dart';
import 'render/design_fonts.dart';

// The editor's state and behaviour: a port of the web's `useStudio.ts`
// (document, variant/colour/size, undo, autosave with the backend's price,
// templates, synced areas, the colour fill, the cart) plus the engine: the
// document is pushed to the 3D view a moment after each change.

const _saveDelay = Duration(milliseconds: 1500);
const _draftDelay = Duration(milliseconds: 300);
const _engineDelay = Duration(milliseconds: 350);
const textSizeMm = 24.0;

class _Snapshot {
  const _Snapshot(this.variantId, this.colorId, this.doc);
  final int? variantId;
  final int? colorId;
  final DesignDocument doc;
}

class EditorController extends Notifier<EditorState> {
  EditorController(this.args);

  final EditorArgs args;

  final _history = History<_Snapshot>();
  late DesignEngine _engine;
  Timer? _saveTimer;
  Timer? _draftTimer;
  Timer? _engineTimer;
  Future<void>? _saving;
  var _saveAgain = false;
  Future<void>? _adopting;
  var _disposed = false;
  var _savedToAccount = false;

  /// Guest uploads (claimed into the account after sign-in).
  final _guestMedia = <String, String>{};

  /// Views uploaded to go with the next save ("Dizaynlarim" shows them).
  List<String>? _pendingPreviews;
  Json? _pendingItem;

  // What the engine has, to skip pushing the same thing twice.
  DesignDocument? _engineDoc;
  int? _engineVariant;
  int? _engineColor;
  var _engineLoaded = false;
  Future<void>? _engineSync;

  EditorApi get _api => ref.read(editorApiProvider);
  DraftStore get _drafts => ref.read(draftStoreProvider);
  bool get _authed => ref.read(authControllerProvider).isAuthenticated;

  /// The engine hosting the 3D view.
  DesignEngine get engine => _engine;

  @override
  EditorState build() {
    _engine = ref.watch(designEngineProvider);
    ref.listen(authControllerProvider, (prev, next) {
      if (next.isAuthenticated && !(prev?.isAuthenticated ?? false)) {
        final s = _stateOrNull;
        if (s != null && s.phase == EditorPhase.ready && s.designId == null) unawaited(adoptLocal());
      }
    });
    ref.onDispose(() {
      _disposed = true;
      _saveTimer?.cancel();
      _engineTimer?.cancel();
      _draftTimer?.cancel();
      final s = _stateOrNull;
      if (s != null && s.phase == EditorPhase.ready) unawaited(_writeDraft(s));
    });
    Future.microtask(load);
    return EditorState();
  }

  EditorState? get _stateOrNull {
    try {
      return state;
    } catch (_) {
      return null;
    }
  }

  void _set(EditorState next, {bool changed = true}) {
    if (_disposed) return;
    // The laser strips follow the layers in the same step (and undo step).
    if (!identical(next.doc, _stateOrNull?.doc)) {
      final doc = withStrips(next.doc, next.areas);
      if (!identical(doc, next.doc)) next = next.copyWith(doc: doc);
    }
    state = next;
    if (changed && next.phase == EditorPhase.ready) {
      _scheduleSave();
      _scheduleDraft();
      _scheduleEngine();
    }
  }

  // ── Loading ────────────────────────────────────────────────────────────

  Future<void> load() async {
    try {
      // Kept alive while the editor is open.
      final keep = ref.listen(productDetailProvider(args.slug), (_, _) {});
      ref.onDispose(keep.close);
      final product = await ref.read(productDetailProvider(args.slug).future);
      var s = EditorState(product: product);
      final local = await _drafts.read(args.slug);
      var resumedLocal = false;
      if (args.designId != null && _authed) {
        final d = await _api.design(args.designId!);
        s = s.copyWith(
          designId: d.id,
          version: d.version,
          quote: d.quote,
          variantId: d.variantId,
          colorId: d.colorId,
          doc: d.document,
        );
        // Unsaved changes of this very version (the app was closed before the save).
        if (local != null && local.designId == d.id && local.designVersion == d.version) {
          s = s.copyWith(doc: local.document, size: local.size);
          _guestMedia.addAll(local.guestMedia);
          resumedLocal = true;
        }
      } else if (local != null && local.designId == args.designId && args.templateId == null) {
        s = s.copyWith(
          variantId: local.variantId,
          colorId: local.colorId,
          size: local.size,
          doc: local.document,
          designId: local.designId,
          version: local.designVersion ?? 0,
        );
        _guestMedia.addAll(local.guestMedia);
        resumedLocal = true;
      } else {
        final first = product.variants.isEmpty ? null : product.variants.first;
        s = s.copyWith(variantId: first?.id, colorId: first?.colors.firstOrNull?.id);
      }
      // The product page's choice wins over a draft's.
      if (args.variantId != null && product.variantById(args.variantId) != null && args.variantId != s.variantId) {
        final nextAreas = areasOf(product, product.variantById(args.variantId));
        s = s.copyWith(
          variantId: args.variantId,
          colorId: product.variantById(args.variantId)!.colors.firstOrNull?.id,
          doc: withDials(refitDials(fitToShape(s.doc, nextAreas), nextAreas), nextAreas),
        );
      }
      if (args.colorId != null && s.variant?.colorById(args.colorId) != null) s = s.copyWith(colorId: args.colorId);
      if (args.size != null) s = s.copyWith(size: args.size);
      s = _ensureOnSale(s.copyWith(doc: withDials(s.doc, s.areas)));
      // A design picked in the gallery starts the editor.
      if (args.templateId != null && args.designId == null) {
        final picked = (await _api.templates(args.slug)).where((t) => t.id == args.templateId).firstOrNull;
        if (picked != null) {
          final copied = [for (final l in picked.document.layers) l.copyWith(id: newLayerId())];
          var doc = fitToShape(
            DesignDocument(layers: copied, links: picked.document.links, strips: picked.document.strips),
            s.areas,
          );
          doc = doc.copyWith(layers: fitIntoStrips(doc.layers, s.areas, doc.strips));
          s = s.copyWith(doc: withDials(doc, s.areas));
        }
      }
      s = s.copyWith(phase: EditorPhase.ready, selectedArea: s.areas.firstOrNull?.key);
      _history.clear();
      _set(s, changed: false);
      _preloadFonts(s.doc);
      if (resumedLocal && s.designId == null && _authed) {
        unawaited(adoptLocal());
      } else if (resumedLocal) {
        _scheduleSave();
      }
      unawaited(_loadEngine());
      _scheduleEngine();
      if (!_authed || s.needsSize) unawaited(_quoteOnly());
    } catch (e, st) {
      debugPrint('[editor] load failed: $e $st');
      if (_disposed) return;
      state = EditorState(phase: EditorPhase.failed, error: ApiException.from(e));
    }
  }

  void _preloadFonts(DesignDocument doc) {
    for (final l in doc.layers) {
      // Saved boxes are kept as they are (measured where they were made).
      if (l.text case final t?) unawaited(ensureFont(t.font, bold: t.bold, italic: t.italic));
      if (l.dial case final d?) unawaited(ensureFont(d.font, bold: d.bold, italic: d.italic));
    }
  }

  /// A variant or colour that went off sale falls back to the first on sale.
  EditorState _ensureOnSale(EditorState s) {
    var next = s;
    if (next.variant == null) {
      final first = next.product!.variants.firstOrNull;
      next = next.copyWith(
        variantId: first?.id,
        colorId: first?.colors.firstOrNull?.id,
        notice: s.variantId != null ? l10nNow.editorMainVariantReplaced : null,
      );
      next = next.copyWith(doc: fitToShape(next.doc, next.areas));
    } else if (next.color == null) {
      next = next.copyWith(colorId: next.variant!.colors.firstOrNull?.id);
    }
    return _ensureSize(next);
  }

  EditorState _ensureSize(EditorState s) {
    if (s.sizesInStock.any((x) => x.label == s.size)) return s;
    return s.copyWith(size: s.sizesInStock.firstOrNull?.label);
  }

  Future<void> retry() async {
    state = EditorState();
    await load();
  }

  // ── Engine ─────────────────────────────────────────────────────────────

  /// The product's model has been drawn in the engine (the 3D view's loader
  /// stays until then; the engine answers `load` after its first frame).
  final modelShown = ValueNotifier(false);

  void _setModelShown(bool on) {
    if (!_disposed) modelShown.value = on;
  }

  Future<void> _loadEngine() async {
    final s = state;
    try {
      _setModelShown(false);
      final p = await _engine.load(productSlug: args.slug, variantId: s.variantId, colorId: s.colorId);
      _setModelShown(true);
      _engineLoaded = true;
      _engineVariant = p.variantId;
      _engineColor = p.colorId;
      _applyEngineProduct(p);
      _engineDoc = null;
      _scheduleEngine(immediate: true);
    } catch (e) {
      _setModelShown(true); // no endless loader: the view shows what it has
      debugPrint('[editor] engine load failed: $e');
    }
  }

  void _applyEngineProduct(EngineProduct p) {
    if (_disposed) return;
    state = state.copyWith(
      surfaceColors: p.surfaceColors,
      engraveTint: p.engraveTint,
    );
  }

  void _scheduleEngine({bool immediate = false}) {
    _engineTimer?.cancel();
    _engineTimer = Timer(immediate ? Duration.zero : _engineDelay, () => unawaited(syncEngine()));
  }

  /// Pushes the current variant, colour and document to the engine.
  Future<void> syncEngine() {
    _engineTimer?.cancel();
    final running = _engineSync;
    if (running != null) {
      return running.then((_) => _engineDirty ? syncEngine() : null);
    }
    return _engineSync = _syncEngineOnce().whenComplete(() => _engineSync = null);
  }

  bool get _engineDirty =>
      !_disposed &&
      _engineLoaded &&
      (_engineDoc != state.doc || _engineVariant != state.variantId || _engineColor != state.colorId);

  Future<void> _syncEngineOnce() async {
    if (!_engineLoaded || _disposed) return;
    try {
      final s = state;
      if (s.variantId != _engineVariant || s.colorId != _engineColor) {
        final p = await _engine.setAppearance(variantId: s.variantId, colorId: s.colorId);
        _engineVariant = p.variantId;
        _engineColor = p.colorId;
        _applyEngineProduct(p);
        if (s.selectedArea != null) unawaited(_engine.showArea(s.selectedArea!).catchError((_) {}));
      }
      final doc = state.doc;
      if (doc != _engineDoc) {
        await _engine.setDocument(doc);
        _engineDoc = doc;
      }
    } catch (e) {
      debugPrint('[editor] engine sync failed: $e');
    }
  }

  bool get engineReady => _engineLoaded && _engine.status.value == EngineStatus.ready;

  /// The engine has the latest design (before pictures, measuring, files).
  Future<void> flushEngine() async {
    if (!_engineLoaded) await _loadEngine();
    if (!_engineLoaded) throw EngineException(l10nNow.editorMainEngineNotReady);
    await syncEngine();
    if (_engineDirty) await syncEngine();
  }

  void showAreaIn3d(String key) => unawaited(_engine.showArea(key).catchError((_) {}));

  Future<Map<String, String>> _measure() async {
    try {
      await flushEngine();
      return await _engine.measure();
    } catch (_) {
      return const {};
    }
  }

  /// Five views of the product (the cart's mockups) or larger for the gallery.
  Future<List<String>> captureFrames({int size = 900}) async {
    await flushEngine();
    final used = usedAreas(state.effective);
    return _engine.captureFrames(
      size: size,
      areas: used.isNotEmpty ? used : [?state.selectedArea],
    );
  }

  Future<String> captureView({int size = 1600}) async {
    await flushEngine();
    return _engine.captureView(size: size);
  }

  // ── History ────────────────────────────────────────────────────────────

  _Snapshot get _snapshot => _Snapshot(state.variantId, state.colorId, state.doc);

  /// Records the state before a change (one undo step).
  void checkpoint() {
    _history.checkpoint(_snapshot);
    state = state.copyWith(canUndo: true, canRedo: false);
  }

  void _restore(_Snapshot s) {
    final keep = s.doc.byId(state.selectedLayer) != null;
    _set(state.copyWith(
      variantId: s.variantId,
      colorId: s.colorId,
      doc: s.doc,
      selectedLayer: keep ? state.selectedLayer : null,
      canUndo: _history.canUndo,
      canRedo: _history.canRedo,
    ));
    final fixed = _ensureSize(state);
    if (fixed.size != state.size) _set(fixed);
  }

  void undo() {
    final prev = _history.undo(_snapshot);
    if (prev != null) _restore(prev);
  }

  void redo() {
    final next = _history.redo(_snapshot);
    if (next != null) _restore(next);
  }

  // ── Selection ──────────────────────────────────────────────────────────

  void select(String? id) {
    final l = state.doc.byId(id);
    _set(
      state.copyWith(selectedLayer: l?.id, selectedArea: l?.area ?? state.selectedArea),
      changed: false,
    );
    if (l?.area != null && l!.area != state.selectedArea) showAreaIn3d(l.area!);
  }

  void selectArea(String key) {
    if (areaByKey(state.areas, key) == null) return;
    final l = state.layer;
    _set(
      state.copyWith(selectedArea: key, selectedLayer: l != null && l.area == key ? l.id : null),
      changed: false,
    );
    showAreaIn3d(key);
  }

  void clearNotice() => state = state.copyWith(notice: null);

  // ── Editing ────────────────────────────────────────────────────────────

  /// Replaces a layer as one undo step ([strips]: where a live gesture left them).
  void updateLayer(Layer next, {bool record = true, List<PrintStrip>? strips}) {
    if (state.doc.byId(next.id) == null) return;
    if (record) checkpoint();
    _set(state.copyWith(doc: state.doc.patch(next.id, (_) => next).copyWith(strips: strips)));
  }

  /// Replaces a layer without a history step (live changes; call
  /// [checkpoint] once first).
  void patchLayer(Layer next, {List<PrintStrip>? strips}) => updateLayer(next, record: false, strips: strips);

  /// The layer inside its area's current strip, where the strip still takes
  /// it with the area's others.
  Layer _placed(Layer l) {
    final m = areaByKey(state.areas, l.area)?.method(l.method);
    if (m == null) return l;
    final area = areaByKey(state.areas, l.area)!;
    return placeInStrip(l, area, m, [for (final x in state.doc.layers) if (x.id != l.id && x.area == l.area) x], state.doc.strips);
  }

  String? _addLayer(Layer l) {
    if (state.doc.layers.length >= maxLayers) {
      state = state.copyWith(notice: l10nNow.editorMainTooManyLayers(maxLayers));
      return null;
    }
    checkpoint();
    final placed = l.isBackground ? l : _placed(l);
    _set(state.copyWith(doc: state.doc.copyWith(layers: [...state.doc.layers, placed]), selectedLayer: l.id));
    return l.id;
  }

  void removeLayer(String id) {
    if (state.doc.byId(id) == null) return;
    checkpoint();
    _set(state.copyWith(
      doc: state.doc.copyWith(layers: [for (final l in state.doc.layers) if (l.id != id) l]),
      selectedLayer: state.selectedLayer == id ? null : state.selectedLayer,
    ));
  }

  void duplicate(String id) {
    final src = state.doc.byId(id);
    if (src == null || src.dial != null || src.isBackground) return;
    _addLayer(src.copyWith(id: newLayerId(), x: src.x + 5, y: src.y + 5, locked: null));
  }

  /// The next layer up (1) or down (-1) in the same area.
  int _neighbour(String id, int step) {
    final list = state.doc.layers;
    final i = list.indexWhere((l) => l.id == id);
    if (i < 0) return -1;
    var j = i + step;
    while (j >= 0 && j < list.length && list[j].area != list[i].area) {
      j += step;
    }
    return j >= 0 && j < list.length ? j : -1;
  }

  bool canMove(String id, int step) => _neighbour(id, step) >= 0;

  void moveLayer(String id, int step) {
    final list = [...state.doc.layers];
    final i = list.indexWhere((l) => l.id == id);
    final j = _neighbour(id, step);
    if (i < 0 || j < 0) return;
    checkpoint();
    final t = list[i];
    list[i] = list[j];
    list[j] = t;
    _set(state.copyWith(doc: state.doc.copyWith(layers: list)));
  }

  /// "Qatlamlar" drag and drop: the area's layers in a new order (bottom first).
  void reorderArea(String areaKey, List<String> idsBottomFirst) {
    final layers = state.doc.layers;
    final inArea = [for (final l in layers) if (l.area == areaKey) l];
    if (inArea.length != idsBottomFirst.length) return;
    final byId = {for (final l in inArea) l.id: l};
    final ordered = [for (final id in idsBottomFirst) ?byId[id]];
    if (ordered.length != inArea.length) return;
    var k = 0;
    final next = [for (final l in layers) l.area == areaKey ? ordered[k++] : l];
    if (listEquals(next, layers)) return;
    checkpoint();
    _set(state.copyWith(doc: state.doc.copyWith(layers: next)));
  }

  void setLocked(String id, bool on) {
    final l = state.doc.byId(id);
    if (l == null || l.systemLocked) return;
    updateLayer(l.copyWith(locked: on ? LayerLock.user : null));
  }

  /// "Yashirish": the layer is parked (kept, not printed) and remembers its area.
  void setHidden(String id, bool hidden) {
    final l = state.doc.byId(id);
    if (l == null || l.dial != null || l.isBackground) return;
    if (hidden) {
      if (l.area == null) return;
      checkpoint();
      _set(state.copyWith(
        doc: state.doc.patch(id, (x) => x.copyWith(area: null)),
        hiddenAreas: {...state.hiddenAreas, id: l.area!},
        selectedLayer: state.selectedLayer == id ? null : state.selectedLayer,
      ));
    } else {
      place(id, areaKey: state.hiddenAreas[id]);
    }
  }

  /// Puts a parked layer into an area (the open one by default), shrinking it to fit.
  void place(String id, {String? areaKey}) {
    final l = state.doc.byId(id);
    final key = areaKey != null && areaByKey(state.areas, areaKey) != null ? areaKey : state.selectedArea;
    final area = areaByKey(state.areas, key);
    if (l == null || area == null) return;
    if (state.doc.syncedFrom(area.key) != null) {
      state = state.copyWith(notice: l10nNow.editorMainAreaSynced);
      return;
    }
    final method = state.defaultMethod(area.key);
    final m = method == null ? null : area.method(method);
    if (m == null) {
      state = state.copyWith(notice: l10nNow.editorMainAreaNoMethod(area.name));
      return;
    }
    var next = l.copyWith(area: area.key, method: m.method);
    next = _monoInk(next, m);
    final f = next.crops ? 1.0 : fitScale(next, m);
    if (f < 1 && next.text == null) next = next.copyWith(w: next.w * f, h: next.h * f);
    checkpoint();
    _set(state.copyWith(
      doc: state.doc.patch(id, (_) => _placed(placeInZone(next, m))),
      hiddenAreas: {...state.hiddenAreas}..remove(id),
      selectedArea: area.key,
    ));
  }

  Layer _monoInk(Layer l, AreaMethod m) {
    if (m.colorsAllowed) return l;
    if (l.text != null) return l.copyWith(text: l.text!.copyWith(color: monoColor));
    if (l.graphic != null) return l.copyWith(graphic: l.graphic!.copyWith(color: monoColor));
    return l;
  }

  /// The selected layer to the middle of its zone, across (x) or down (y).
  void centerLayer(String id, {bool horizontal = true, bool vertical = false}) {
    final l = state.doc.byId(id);
    final a = areaByKey(state.areas, l?.area);
    final m = a?.method(l?.method ?? '');
    if (l == null || a == null || m == null || l.isLocked) return;
    final z = printZone(a, m, [for (final x in state.doc.layers) if (x.id != id) x], state.doc.strips);
    updateLayer(_placed(l.copyWith(x: horizontal ? z.cx : null, y: vertical ? z.cy : null)));
  }

  void setTextSource(String id, TextSource t, {bool record = true}) {
    final l = state.doc.byId(id);
    if (l == null || l.text == null) return;
    final area = areaByKey(state.areas, l.area);
    updateLayer(withText(area, l, t.content.isEmpty ? t.copyWith(content: ' ') : t, state.doc.layers), record: record);
    unawaited(ensureFont(t.font, bold: t.bold, italic: t.italic).then((_) => _remeasure(id)));
  }

  /// After a font arrives, the box is measured again with the real glyphs.
  void _remeasure(String id) {
    if (_disposed) return;
    final l = state.doc.byId(id);
    if (l?.text == null) return;
    final next = withText(areaByKey(state.areas, l!.area), l, l.text!, state.doc.layers);
    if (next != l) updateLayer(next, record: false);
  }

  void setDial(String id, DialSource d) {
    final l = state.doc.byId(id);
    if (l == null || l.dial == null) return;
    updateLayer(l.copyWith(dial: d));
    unawaited(ensureFont(d.font, bold: d.bold, italic: d.italic));
  }

  void setColor(String id, String hex) {
    final l = state.doc.byId(id);
    if (l == null) return;
    if (l.text != null) {
      setTextSource(id, l.text!.copyWith(color: hex));
    } else if (l.dial != null) {
      setDial(id, l.dial!.copyWith(color: hex));
    } else if (l.graphic != null) {
      updateLayer(l.copyWith(graphic: l.graphic!.copyWith(color: hex)));
    }
  }

  // ── Adding ─────────────────────────────────────────────────────────────

  /// Where a new layer goes: the open area and its method (or why not).
  ({PrintArea area, AreaMethod m, Box zone, String ink})? _target() {
    final s = state;
    final area = s.area;
    final linked = s.linkedFrom;
    final method = area != null && linked == null ? s.defaultMethod(area.key) : null;
    if (area == null || method == null) {
      state = s.copyWith(
        notice: linked != null
            ? l10nNow.editorMainAreaSyncedWith(linked.name)
            : area != null
                ? l10nNow.editorMainAreaNoMethod(area.name)
                : l10nNow.editorMainCannotAddHere,
      );
      return null;
    }
    final m = area.method(method)!;
    return (area: area, m: m, zone: printZone(area, m, s.doc.layers, s.doc.strips), ink: m.colorsAllowed ? s.inkColor : monoColor);
  }

  /// Whether something can be added to the open area (a notice says why not).
  bool ensureCanAdd() => _target() != null;

  /// The zone's centre, stepped down-right past layers already there.
  ({double x, double y}) _freeSpot(({PrintArea area, AreaMethod m, Box zone, String ink}) t, double w, double h) {
    var spot = Layer(
      id: '_',
      area: t.area.key,
      method: t.m.method,
      kind: LayerKind.image,
      x: t.zone.cx,
      y: t.zone.cy,
      w: w,
      h: h,
    );
    bool taken(double x, double y) =>
        state.doc.layers.any((l) => l.area == t.area.key && math.sqrt(math.pow(l.x - x, 2) + math.pow(l.y - y, 2)) < 1);
    for (var i = 0; i < 6 && taken(spot.x, spot.y); i++) {
      spot = clampInto(spot.copyWith(x: spot.x + 6, y: spot.y + 6), t.zone);
    }
    return (x: spot.x, y: spot.y);
  }

  Future<String?> addText({
    String? content,
    String font = 'Open Sans',
    bool bold = false,
    bool italic = false,
  }) async {
    final t = _target();
    if (t == null) return null;
    final minFont = (t.m.minFont ?? 3).ceilToDouble();
    var text = TextSource(
      content: content ?? l10nNow.editorMainTextPlaceholder,
      font: font,
      sizeMm: math.max(minFont, textSizeMm),
      color: t.ink,
      bold: bold,
      italic: italic,
    );
    await ensureFont(font, bold: bold, italic: italic);
    var layout = layoutText(text);
    final room = t.zone.width * 0.9;
    if (layout.w > room) {
      text = text.copyWith(sizeMm: math.max(minFont, (text.sizeMm * room / layout.w).floorToDouble()));
      layout = layoutText(text);
    }
    final spot = _freeSpot(t, layout.w, layout.h);
    return _addLayer(Layer(
      id: newLayerId(),
      area: t.area.key,
      method: t.m.method,
      kind: LayerKind.text,
      x: spot.x,
      y: spot.y,
      w: layout.w,
      h: layout.h,
      text: text,
    ));
  }

  String? addImage(ImageSource image) {
    final t = _target();
    if (t == null) return null;
    final maxW = math.min(t.zone.width * 0.7, t.m.maxWidth ?? double.infinity);
    final maxH = math.min(t.zone.height * 0.7, t.m.maxHeight ?? double.infinity);
    final k = math.min(maxW / image.pxW, maxH / image.pxH);
    final w = image.pxW * k;
    final h = image.pxH * k;
    final spot = _freeSpot(t, w, h);
    return _addLayer(Layer(
      id: newLayerId(),
      area: t.area.key,
      method: t.m.method,
      kind: LayerKind.image,
      x: spot.x,
      y: spot.y,
      w: w,
      h: h,
      image: image,
    ));
  }

  String? addGraphic(String library, String name) {
    final t = _target();
    final def = resolveGraphic(library, name);
    if (t == null || def == null) return null;
    final long = def.width / def.height > 5;
    final k = long
        ? t.zone.width * 0.6 / def.width
        : math.min(t.zone.width, t.zone.height) * 0.35 / math.max(def.width, def.height);
    final w = def.width * k;
    final h = def.height * k;
    final spot = _freeSpot(t, w, h);
    return _addLayer(Layer(
      id: newLayerId(),
      area: t.area.key,
      method: t.m.method,
      kind: LayerKind.graphic,
      x: spot.x,
      y: spot.y,
      w: w,
      h: h,
      graphic: GraphicSource(library: library, name: name, color: t.ink),
    ));
  }

  String? addSticker(StickerItem item) {
    final t = _target();
    if (t == null) return null;
    final k = math.min(t.zone.width, t.zone.height) * 0.4 / math.max(item.w, item.h);
    final w = item.w * k;
    final h = item.h * k;
    final spot = _freeSpot(t, w, h);
    return _addLayer(Layer(
      id: newLayerId(),
      area: t.area.key,
      method: t.m.method,
      kind: LayerKind.graphic,
      x: spot.x,
      y: spot.y,
      w: w,
      h: h,
      graphic: GraphicSource(library: 'sticker', name: item.name, color: isMonoSticker(item.name) ? t.ink : monoColor),
    ));
  }

  /// A picture uploaded by the customer: offered again in "Rasm".
  void rememberUpload(ImageSource image, {required bool guest}) {
    if (guest) _guestMedia[image.mediaId] = image.url;
    state = state.copyWith(uploads: [image, ...state.uploads.where((u) => u.mediaId != image.mediaId)]);
  }

  // ── Templates ──────────────────────────────────────────────────────────

  void applyTemplate(DesignTemplate t) {
    checkpoint();
    final copied = [for (final l in t.document.layers) l.copyWith(id: newLayerId())];
    var doc = fitToShape(
      DesignDocument(layers: copied, links: t.document.links, strips: t.document.strips),
      state.areas,
    );
    doc = doc.copyWith(layers: fitIntoStrips(doc.layers, state.areas, doc.strips));
    _set(state.copyWith(
      doc: doc,
      selectedLayer: null,
      selectedArea: copied.where((l) => l.area != null).firstOrNull?.area ?? state.selectedArea,
    ));
    _preloadFonts(doc);
  }

  // ── Variant, colour, size, method ──────────────────────────────────────

  /// How many placed layers switching to [variantId] would park.
  int layersLostBy(int variantId) {
    final v = state.product?.variantById(variantId);
    if (v == null || v.shapeId == state.variant?.shapeId) return 0;
    final keys = {for (final a in areasOf(state.product, v)) a.key};
    return state.doc.layers.where((l) => l.area != null && !keys.contains(l.area)).length;
  }

  void pickVariant(int id, {int? colorId}) {
    final s = state;
    final next = s.product?.variantById(id);
    if (next == null) return;
    if (id == s.variantId) {
      if (colorId != null) pickColor(colorId);
      return;
    }
    checkpoint();
    final areas = areasOf(s.product, next);
    final color = colorId != null && next.colorById(colorId) != null
        ? colorId
        : next.colorById(s.colorId) != null
            ? s.colorId
            : next.colors.firstOrNull?.id;
    final keys = {for (final a in areas) a.key};
    var ns = s.copyWith(
      variantId: id,
      colorId: color,
      doc: withDials(refitDials(fitToShape(s.doc, areas), areas), areas),
      selectedArea: s.selectedArea != null && keys.contains(s.selectedArea) ? s.selectedArea : areas.firstOrNull?.key,
    );
    ns = _ensureSize(ns);
    ns = _fitMethodToVariant(ns);
    _set(_recolourBackground(ns));
  }

  void pickColor(int id) {
    if (id == state.colorId || state.variant?.colorById(id) == null) return;
    checkpoint();
    _set(_recolourBackground(state.copyWith(colorId: id)));
  }

  void pickSize(String label) {
    if (!state.sizesInStock.any((s) => s.label == label) || label == state.size) return;
    _set(state.copyWith(size: label));
    unawaited(_quoteOnly());
  }

  /// The fill follows the product's colour.
  EditorState _recolourBackground(EditorState s) {
    final hex = s.color?.hex;
    if (hex == null || !s.doc.hasBackground) return s;
    return s.copyWith(
      doc: s.doc.copyWith(layers: [
        for (final l in s.doc.layers)
          l.isBackground && l.graphic != null ? l.copyWith(graphic: l.graphic!.copyWith(color: hex)) : l,
      ]),
    );
  }

  Layer _convertLayer(Layer l, String method, List<PrintArea> areas) {
    var next = l.copyWith(method: method);
    final area = areaByKey(areas, l.area);
    final target = area?.method(method);
    if (target == null) return next;
    next = _monoInk(next, target);
    final f = fitScale(next, target);
    if (next.text != null) {
      final min = target.minFont ?? 0;
      final t = next.text!.copyWith(
        sizeMm: double.parse(math.max(min, next.text!.sizeMm * f).toStringAsFixed(2)),
      );
      final layout = layoutText(t);
      next = next.copyWith(text: t, w: layout.w, h: layout.h);
    } else if (f < 1 && (!next.crops || stripWidthOf(target) != null)) {
      next = next.copyWith(w: next.w * f, h: next.h * f);
    }
    return placeInZone(next, target);
  }

  /// After a type change: a method the new type lacks becomes one it has.
  EditorState _fitMethodToVariant(EditorState s) {
    final m = s.preferredMethod != null && s.methods.contains(s.preferredMethod)
        ? s.preferredMethod!
        : s.methods.firstOrNull;
    if (m == null || s.doc.layers.every((l) => l.method == m)) return s;
    final layers = [
      for (final l in s.doc.layers)
        if (areaByKey(s.areas, l.area) case final a? when a.method(m) == null)
          l.copyWith(method: m, area: null)
        else
          _convertLayer(l, m, s.areas),
    ];
    final label = m == 'engrave' ? l10nNow.printMethodEngrave : l10nNow.printMethodUv;
    return s.copyWith(
      doc: s.doc.copyWith(layers: fitIntoStrips(layers, s.areas, s.doc.strips)),
      notice: l10nNow.editorMainMethodSwitched(label),
    );
  }

  /// Puts the whole design on one method; returns why not, if refused.
  String? setDesignMethod(String m) {
    final s = state;
    if (!s.methods.contains(m)) return l10nNow.editorMainVariantNoMethod;
    for (final a in s.areas) {
      if (a.method(m) == null && s.doc.layers.any((l) => l.area == a.key)) {
        return l10nNow.editorMainAreaNoMethodClear(a.name);
      }
    }
    state = s.copyWith(preferredMethod: m);
    if (s.doc.layers.every((l) => l.method == m)) {
      _scheduleSave();
      return null;
    }
    checkpoint();
    final layers = fitIntoStrips([for (final l in s.doc.layers) _convertLayer(l, m, s.areas)], s.areas, s.doc.strips);
    _set(state.copyWith(doc: s.doc.copyWith(layers: layers)));
    return null;
  }

  // ── Colour fill ("Fon") ────────────────────────────────────────────────

  void setBackground(bool on) {
    checkpoint();
    final s = state;
    final rest = [for (final l in s.doc.layers) if (!l.isBackground) l];
    final hex = s.color?.hex;
    final fills = <Layer>[];
    if (on && hex != null) {
      for (final a in s.areas) {
        final m = a.method('uv');
        if (m == null || s.doc.syncedFrom(a.key) != null) continue;
        final z = m.zone;
        fills.add(Layer(
          id: '$backgroundPrefix${newLayerId()}',
          area: a.key,
          method: 'uv',
          kind: LayerKind.graphic,
          x: z.cx,
          y: z.cy,
          w: z.width,
          h: z.height,
          graphic: GraphicSource(library: 'shape', name: a.round ? 'circle' : 'square', color: hex),
        ));
      }
    }
    _set(s.copyWith(doc: s.doc.copyWith(layers: [...fills, ...rest])));
  }

  // ── Synced areas and clearing ──────────────────────────────────────────

  void setSync(String sourceKey, List<String> targets) {
    final s = state;
    final source = areaByKey(s.areas, sourceKey);
    if (source == null) return;
    final current = s.doc.syncTargets(sourceKey);
    final removed = current.where((t) => !targets.contains(t)).toList();
    final added = targets.where((t) => !current.contains(t)).toList();
    if (removed.isEmpty && added.isEmpty) return;
    checkpoint();
    final own = s.doc.layers.where((l) => l.area == sourceKey).toList();
    final copies = [
      for (final key in removed)
        if (areaByKey(s.areas, key) case final target?)
          for (final l in own) copyToPartner(l, source, target).copyWith(id: newLayerId()),
    ];
    _set(s.copyWith(
      doc: DesignDocument(
        layers: [
          for (final l in s.doc.layers) l.area != null && added.contains(l.area) ? l.copyWith(area: null) : l,
          ...copies,
        ],
        links: [
          for (final l in s.doc.links)
            if (!(l.source == sourceKey && removed.contains(l.target))) l,
          for (final t in added) AreaLink(sourceKey, t),
        ],
        strips: s.doc.strips,
      ),
    ));
  }

  static bool _clearable(Layer l) => l.dial == null && !l.isBackground;

  int clearCount(String key) => state.doc.layers.where((l) => l.area == key && _clearable(l)).length;

  void clearArea(String key) {
    final gone = {for (final l in state.doc.layers) if (l.area == key && _clearable(l)) l.id};
    if (gone.isEmpty) return;
    checkpoint();
    _set(state.copyWith(
      doc: state.doc.copyWith(layers: [for (final l in state.doc.layers) if (!gone.contains(l.id)) l]),
      selectedLayer: gone.contains(state.selectedLayer) ? null : state.selectedLayer,
    ));
  }

  // ── Saving ─────────────────────────────────────────────────────────────

  void _scheduleDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(_draftDelay, () => unawaited(_writeDraft(state)));
  }

  Future<void> _writeDraft(EditorState s) async {
    final v = s.variantId;
    final c = s.colorId;
    if (v == null || c == null) return;
    await _drafts.write(
      args.slug,
      LocalDraft(
        variantId: v,
        colorId: c,
        size: s.size,
        designId: s.designId,
        designVersion: s.designId == null ? null : s.version,
        document: s.doc,
        guestMedia: Map.of(_guestMedia),
      ),
    );
  }

  void _scheduleSave() {
    if (state.phase != EditorPhase.ready) return;
    _saveTimer?.cancel();
    if (state.saveStatus != SaveStatus.saving) state = state.copyWith(saveStatus: SaveStatus.pending);
    _saveTimer = Timer(_saveDelay, () => unawaited(save()));
  }

  /// Saves now (in the account when signed in; a guest keeps the draft on the phone).
  Future<void> save() {
    _saveTimer?.cancel();
    final running = _saving;
    if (running != null) {
      _saveAgain = true;
      return running;
    }
    if (_disposed) return Future.value();
    state = state.copyWith(saveStatus: SaveStatus.saving);
    return _saving = () async {
      try {
        do {
          _saveAgain = false;
          await _saveOnce();
        } while (_saveAgain && !_disposed);
        if (!_disposed) state = state.copyWith(saveStatus: SaveStatus.saved, saveError: null);
      } on DesignConflict {
        // Saved elsewhere meanwhile: take that version.
        final id = state.designId;
        if (id != null) {
          try {
            final d = await _api.design(id);
            _history.clear();
            state = state.copyWith(
              designId: d.id,
              version: d.version,
              quote: d.quote,
              variantId: d.variantId,
              colorId: d.colorId,
              doc: d.document,
              saveStatus: SaveStatus.saved,
              canUndo: false,
              canRedo: false,
              notice: l10nNow.editorMainReloadedNewer,
            );
            _scheduleEngine();
          } catch (e) {
            state = state.copyWith(saveStatus: SaveStatus.error, saveError: ApiException.from(e).message);
          }
        }
      } catch (e) {
        if (!_disposed) {
          state = state.copyWith(
            saveStatus: SaveStatus.error,
            saveError: e is ApiException ? e.message : l10nNow.editorMainSaveFailedOffline,
          );
        }
      } finally {
        _saving = null;
      }
    }();
  }

  Future<void> _saveOnce() async {
    final s = state;
    final v = s.variantId;
    final c = s.colorId;
    if (v == null || c == null) return;
    await _writeDraft(s);
    final areasCm2 = await _measure();
    if (!_authed) {
      final q = await _api.quote(variantId: v, colorId: c, size: s.size, areasCm2: areasCm2);
      if (!_disposed) state = state.copyWith(quote: q);
      return;
    }
    final previews = _pendingPreviews;
    final saved = await _api.saveDesign(
      id: s.designId,
      version: s.version,
      variantId: v,
      colorId: c,
      document: s.doc,
      areasCm2: areasCm2,
      previews: previews,
    );
    if (identical(_pendingPreviews, previews)) _pendingPreviews = null;
    _savedToAccount = true;
    if (s.designId == null || previews != null) _invalidateDesigns();
    if (_disposed) return;
    state = state.copyWith(designId: saved.id, version: saved.version, quote: saved.quote);
    // A saved design doesn't keep the size: price it again with the one chosen.
    if (s.needsSize) {
      final q = await _api.quote(variantId: v, colorId: c, size: s.size, areasCm2: areasCm2);
      if (!_disposed) state = state.copyWith(quote: q);
    }
    await _writeDraft(state);
  }

  /// Leaving the editor: pending changes are saved and "Dizaynlarim" refreshed.
  Future<void> onLeave() async {
    if (_saveTimer?.isActive ?? false) {
      _saveTimer?.cancel();
      unawaited(save().then((_) => _invalidateDesigns()));
    } else if (_savedToAccount) {
      _invalidateDesigns();
    }
  }

  void _invalidateDesigns() {
    try {
      ref.invalidate(myDesignsProvider);
    } catch (_) {}
  }

  Future<void> _quoteOnly() async {
    final s = state;
    if (s.variantId == null || s.colorId == null) return;
    try {
      final q = await _api.quote(variantId: s.variantId!, colorId: s.colorId!, size: s.size, areasCm2: await _measure());
      if (!_disposed) state = state.copyWith(quote: q);
    } catch (_) {}
  }

  /// After sign-in: guest uploads move into the account and the design is saved there.
  Future<void> adoptLocal() {
    return _adopting ??= () async {
      try {
        if (_guestMedia.isNotEmpty) {
          final items = [for (final e in _guestMedia.entries) MediaItem(id: e.key, url: e.value, guest: true)];
          final moves = await ref.read(mediaUploaderProvider).claim(items);
          _guestMedia.clear();
          if (moves.isNotEmpty && !_disposed) {
            ImageSource moved(ImageSource i) =>
                ImageSource(mediaId: i.mediaId, url: moves[i.url] ?? i.url, pxW: i.pxW, pxH: i.pxH);
            state = state.copyWith(
              doc: state.doc.copyWith(layers: [
                for (final l in state.doc.layers)
                  l.image == null ? l : l.copyWith(image: moved(l.image!)),
              ]),
              uploads: [for (final u in state.uploads) moved(u)],
            );
          }
        }
        await save();
      } catch (e) {
        debugPrint('[editor] adopting the draft failed: $e');
      } finally {
        _adopting = null;
      }
    }();
  }

  /// "Saqlash": with the five views "Dizaynlarim" shows.
  Future<bool> saveWithPreviews(Future<MediaItem> Function(Uint8List bytes, String type) upload) async {
    if (_authed) {
      try {
        final frames = await captureFrames();
        if (frames.isNotEmpty) {
          _pendingPreviews = await Future.wait(frames.map((f) async {
            return (await upload(await dataUrlBytes(f), dataUrlType(f))).id;
          }));
        }
      } catch (e) {
        debugPrint('[editor] the design’s views could not be saved: $e');
      }
    }
    await save();
    return state.saveStatus == SaveStatus.saved;
  }

  // ── Cart ───────────────────────────────────────────────────────────────

  void _cart(CartFlow flow) {
    if (!_disposed) state = state.copyWith(cart: flow);
  }

  void resetCart() {
    _pendingItem = null;
    _cart(const CartIdle());
  }

  /// Mirrors the web: save, print files, mockups, then `POST /cart/items/`.
  Future<void> addToCart({int quantity = 1}) async {
    final s = state;
    if (s.blocked) {
      _cart(CartFailed(s.placedCount == 0 ? l10nNow.editorMainAddSomethingFirst : l10nNow.editorMainFixRedItems));
      return;
    }
    if (s.needsSize && s.size == null) {
      _cart(CartFailed(l10nNow.editorMainPickSizeFirst));
      return;
    }
    final uploader = ref.read(mediaUploaderProvider);
    // Steps (the loader's bar): saving, the print files, each upload, the
    // views, the cart request. Five views until they are taken.
    var done = 0;
    var total = 0;
    void step(String text, [int finished = 0]) {
      done += finished;
      _cart(CartWorking(text, total == 0 ? null : done / total));
    }

    final l10n = l10nNow;
    try {
      step(l10n.editorMainStepSaving);
      await save();
      step(l10n.editorMainStepPrintFiles);
      await flushEngine();
      final prints = await _engine.renderPrintFiles();
      if (prints.isEmpty) throw EngineException(l10n.editorMainNoPrintFile);
      var views = 5;
      total = 2 + prints.length + 1 + views + 1;
      step(l10n.editorMainStepPrintFiles, 2);
      var uploaded = 0;
      String uploading() => l10n.editorMainStepUploading(math.min(uploaded + 1, prints.length + views), prints.length + views);
      final files = <Json>[];
      for (final f in prints) {
        step(uploading());
        final media = await uploader.upload(await dataUrlBytes(f.dataUrl), 'image/png', 'print');
        uploaded++;
        files.add({'area': f.area, 'method': f.method, 'media_id': media.id});
        step(uploading(), 1);
      }
      step(l10n.editorMainStepViews);
      final frames = await captureFrames();
      total += frames.length - views;
      views = frames.length;
      step(uploading(), 1);
      final mockups = await Future.wait(frames.map((f) async {
        final id = (await uploader.upload(await dataUrlBytes(f), dataUrlType(f), 'design')).id;
        uploaded++;
        step(uploading(), 1);
        return id;
      }));
      if (mockups.isEmpty) throw EngineException(l10n.editorMainNoViews);
      _pendingPreviews = mockups;
      unawaited(save());
      final now = state;
      _pendingItem = {
        'design_id': now.designId,
        'variant_id': now.variantId,
        'color_id': now.colorId,
        'size': now.size,
        'quantity': quantity,
        'document': now.doc.toJson(),
        'files': files,
        'mockups': mockups,
      };
      step(l10n.editorMainStepAddingToCart);
      await _postItem(now.liveQuote?.unitPrice.raw ?? _priceString(now.provisionalPrice?.amount ?? 0));
    } on PriceChanged catch (e) {
      _cart(CartConfirm(e.quote, e.message));
    } on ApiException catch (e) {
      _cart(CartFailed(e.message));
    } on EngineException catch (e) {
      _cart(CartFailed(e.message));
    } catch (e) {
      debugPrint('[editor] cart failed: $e');
      _cart(CartFailed(l10n.editorMainAddToCartFailed));
    }
  }

  String _priceString(double v) => v.toStringAsFixed(2);

  Future<void> _postItem(String expected) async {
    final item = _pendingItem;
    if (item == null) return;
    await _api.addCartItem(item, expected);
    _pendingItem = null;
    ref.invalidate(cartSummaryProvider);
    _cart(const CartDone());
  }

  /// The customer accepted the price computed from the print files.
  Future<void> confirmPrice() async {
    final flow = state.cart;
    if (flow is! CartConfirm || _pendingItem == null) return;
    _cart(CartWorking(l10nNow.editorMainStepAddingToCart));
    try {
      await _postItem(flow.quote.unitPrice.raw);
      state = state.copyWith(quote: flow.quote);
    } on PriceChanged catch (e) {
      _cart(CartConfirm(e.quote, e.message));
    } on ApiException catch (e) {
      _cart(CartFailed(e.message));
    }
  }
}

final editorControllerProvider =
    NotifierProvider.autoDispose.family<EditorController, EditorState, EditorArgs>(EditorController.new);
