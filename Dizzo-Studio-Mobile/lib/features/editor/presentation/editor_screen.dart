import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/require_auth.dart';
import '../../catalog/domain/catalog_models.dart' show parseHexColor;
import '../../catalog/presentation/widgets/option_pickers.dart';
import '../data/engine_bridge.dart';
import '../data/media_uploader.dart';
import '../data/sticker_library.dart';
import '../domain/design_document.dart';
import 'canvas/design_canvas.dart';
import 'editor_controller.dart';
import 'editor_state.dart';
import 'panels/editor_sheets.dart';
import 'panels/elements_panel.dart';
import 'panels/image_panel.dart';
import 'panels/layers_panel.dart';
import 'panels/props_panel.dart';
import 'panels/templates_panel.dart';
import 'panels/text_panel.dart';
import 'render/asset_store.dart';
import 'widgets/editor_panel.dart';

enum _Tool { text, image, elements, templates, layers, background, props }

/// The design editor (Studio): the print area edited natively, the 3D
/// view, pictures and print files from the web engine.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({
    super.key,
    required this.slug,
    this.variantId,
    this.colorId,
    this.size,
    this.designId,
    this.templateId,
  });

  final String slug;
  final int? variantId;
  final int? colorId;
  final String? size;
  final String? designId;
  final int? templateId;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late final EditorArgs _args = EditorArgs(
    slug: widget.slug,
    variantId: widget.variantId,
    colorId: widget.colorId,
    size: widget.size,
    designId: widget.designId,
    templateId: widget.templateId,
  );
  // Made up front: the screen can close without the flat editor ever built.
  late final AssetStore _assets;
  final _canvasKey = GlobalKey<DesignCanvasState>();

  _Tool? _tool;
  // The product in 3D first; the flat editor on request.
  bool _show3d = true;
  bool _grid = false;
  bool _snapping = true;
  bool _imageBusy = false;
  bool _saving = false;

  EditorController get _c => ref.read(editorControllerProvider(_args).notifier);

  @override
  void initState() {
    super.initState();
    _assets = AssetStore(ref.read(stickerLibraryProvider));
  }

  @override
  void dispose() {
    _assets.dispose();
    super.dispose();
  }

  void _open(_Tool? tool) {
    HapticFeedback.selectionClick();
    setState(() => _tool = _tool == tool ? null : tool);
  }

  // ── Actions ──

  Future<void> _addText(TextPreset p) async {
    final id = await _c.addText(content: p.content, font: p.font, bold: p.bold, italic: p.italic);
    if (id == null || !mounted) return;
    setState(() => _tool = _Tool.props);
    if (identical(p, plainText)) await _editText(id);
  }

  Future<void> _editText(String id) async {
    final s = ref.read(editorControllerProvider(_args));
    final l = s.doc.byId(id);
    if (l == null) return;
    if (l.text != null) {
      await showTextEditSheet(context, _c, s, id);
    } else {
      setState(() => _tool = _Tool.props);
    }
  }

  Future<void> _pickImage(ImageSource2 source) async {
    final ok = await pickAndPlaceImage(
      context,
      ref,
      source: source,
      state: ref.read(editorControllerProvider(_args)),
      controller: _c,
      assets: _assets,
      onBusy: (v) {
        if (mounted) setState(() => _imageBusy = v);
      },
    );
    if (ok && mounted && context.isCompact) setState(() => _tool = null);
  }

  Future<void> _layerMenu(String id, Offset at) async {
    final s = ref.read(editorControllerProvider(_args));
    final l = s.doc.byId(id);
    if (l == null) return;
    final size = MediaQuery.sizeOf(context);
    final l10n = context.l10n;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, size.width - at.dx, size.height - at.dy),
      items: [
        if (l.text != null) PopupMenuItem(value: 'edit', child: Text(l10n.editorMainMenuEditText)),
        PopupMenuItem(value: 'props', child: Text(l10n.editorMainSettings)),
        if (l.dial == null && !l.isBackground) PopupMenuItem(value: 'dup', child: Text(l10n.editorMainDuplicate)),
        if (_c.canMove(id, 1)) PopupMenuItem(value: 'up', child: Text(l10n.editorMainBringForward)),
        if (_c.canMove(id, -1)) PopupMenuItem(value: 'down', child: Text(l10n.editorMainSendBackward)),
        if (!l.systemLocked)
          PopupMenuItem(value: 'lock', child: Text(l.isLocked ? l10n.editorMainUnlock : l10n.editorMainLock)),
        if (l.dial == null && !l.isBackground) PopupMenuItem(value: 'hide', child: Text(l10n.editorMainHide)),
        if (l.dial == null) PopupMenuItem(value: 'del', child: Text(l10n.commonDelete)),
      ],
    );
    switch (choice) {
      case 'edit':
        await _editText(id);
      case 'props':
        setState(() => _tool = _Tool.props);
      case 'dup':
        _c.duplicate(id);
      case 'up':
        _c.moveLayer(id, 1);
      case 'down':
        _c.moveLayer(id, -1);
      case 'lock':
        _c.setLocked(id, !l.isLocked);
      case 'hide':
        _c.setHidden(id, true);
      case 'del':
        _c.removeLayer(id);
    }
  }

  Future<bool> _signIn() async {
    if (ref.read(authControllerProvider).isAuthenticated) return true;
    unawaited(_c.save()); // kept on the phone meanwhile
    if (!await ensureSignedIn(context, ref)) return false;
    await _c.adoptLocal();
    return true;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!await _signIn() || !mounted) return;
    setState(() => _saving = true);
    final uploader = ref.read(mediaUploaderProvider);
    final ok = await _c.saveWithPreviews((bytes, type) => uploader.upload(bytes, type, 'design'));
    if (!mounted) return;
    setState(() => _saving = false);
    await _c.onLeave(); // refreshes "Dizaynlarim"
    if (!mounted) return;
    showAppSnack(
      context,
      ok ? context.l10n.editorMainSaved : ref.read(editorControllerProvider(_args)).saveError ?? context.l10n.editorMainSaveFailed,
      error: !ok,
    );
  }

  Future<void> _addToCart() async {
    if (!await _signIn() || !mounted) return;
    unawaited(_c.addToCart());
    final result = await showCartProgress(context, _args);
    if (!mounted) return;
    if (result == 'cart') context.go(Routes.cart);
  }

  void _showProblems(EditorState s) {
    final id = s.problems.keys.where((k) => !k.contains('@')).firstOrNull;
    if (id == null) return;
    _c.select(id);
    setState(() {
      _show3d = false;
      _tool = _Tool.props;
    });
  }

  void _toggle3d(bool on) {
    HapticFeedback.selectionClick();
    setState(() => _show3d = on);
    if (on) {
      unawaited(_c.syncEngine());
      final area = ref.read(editorControllerProvider(_args)).selectedArea;
      if (area != null) _c.showAreaIn3d(area);
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(editorControllerProvider(_args));
    ref.listen(editorControllerProvider(_args).select((s) => s.notice), (_, notice) {
      if (notice == null) return;
      showAppSnack(context, notice);
      _c.clearNotice();
    });
    ref.listen(editorControllerProvider(_args).select((s) => s.selectedLayer), (prev, next) {
      if (next == null && _tool == _Tool.props) setState(() => _tool = null);
    });

    return switch (s.phase) {
      EditorPhase.loading => const Scaffold(body: BrandLoaderScreen()),
      EditorPhase.failed => Scaffold(
          appBar: AppBar(title: Text(context.l10n.editorMainTitle)),
          body: ErrorState(error: s.error ?? context.l10n.editorMainError, onRetry: _c.retry),
        ),
      EditorPhase.ready => PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) unawaited(_c.onLeave());
          },
          child: Scaffold(
            backgroundColor: context.colors.background,
            body: SafeArea(child: context.windowSize == WindowSize.expanded ? _wide(s) : _narrow(s)),
          ),
        ),
    };
  }

  Widget _narrow(EditorState s) {
    return Column(
      children: [
        _topBar(s),
        Expanded(child: _stage(s)),
        if (_tool != null) _panel(s, context.isCompact ? null : 0.45),
        _orderRow(s),
        _bottomBar(s),
      ],
    );
  }

  Widget _wide(EditorState s) {
    final c = context.colors;
    return Column(
      children: [
        _topBar(s),
        Expanded(
          child: Row(
            children: [
              Container(
                width: 88,
                color: c.surface,
                child: SingleChildScrollView(
                  child: Column(children: _toolActions(s)),
                ),
              ),
              Expanded(child: _stage(s)),
              SizedBox(
                width: 400,
                child: Column(
                  children: [
                    Expanded(
                      child: _tool == null
                          ? Center(child: EmptyState(title: context.l10n.editorMainPickTool, icon: Icons.touch_app_outlined, compact: true))
                          : _panel(s, null, fill: true),
                    ),
                    if (s.layer != null)
                      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _selectionActions(s))),
                    _orderRow(s),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _topBar(EditorState s) {
    final area = s.area;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            tooltip: context.l10n.commonBack,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home),
          ),
          Expanded(
            child: InkWell(
              borderRadius: Radii.brMd,
              onTap: s.areas.length > 1 ? () => _areaMenu() : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.xs, horizontal: Insets.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.product?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    if (area != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              area.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelMedium?.copyWith(color: context.colors.inkMuted),
                            ),
                          ),
                          if (s.areas.length > 1)
                            Icon(Icons.expand_more_rounded, size: 18, color: context.colors.inkMuted),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          _saveIndicator(s),
          IconButton(tooltip: context.l10n.editorMainUndo, onPressed: s.canUndo ? _c.undo : null, icon: const Icon(Icons.undo_rounded)),
          IconButton(tooltip: context.l10n.editorMainRedo, onPressed: s.canRedo ? _c.redo : null, icon: const Icon(Icons.redo_rounded)),
          IconButton(tooltip: context.l10n.editorMainActions, onPressed: _areaMenu, icon: const Icon(Icons.more_vert_rounded)),
        ],
      ),
    );
  }

  Widget _saveIndicator(EditorState s) {
    final c = context.colors;
    return switch (s.saveStatus) {
      SaveStatus.saving || SaveStatus.pending => Padding(
          padding: const EdgeInsets.all(Insets.sm),
          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.inkSubtle)),
        ),
      SaveStatus.error => IconButton(
          tooltip: context.l10n.editorMainNotSaved,
          onPressed: () {
            showAppSnack(context, s.saveError ?? context.l10n.editorMainSaveFailed, error: true);
            unawaited(_c.save());
          },
          icon: Icon(Icons.cloud_off_rounded, color: c.danger),
        ),
      SaveStatus.saved => Padding(
          padding: const EdgeInsets.all(Insets.sm),
          child: Icon(Icons.cloud_done_outlined, size: 20, color: c.inkSubtle),
        ),
      SaveStatus.idle => const SizedBox.shrink(),
    };
  }

  void _areaMenu() {
    unawaited(showAreaMenu(
      context,
      ref,
      _args,
      grid: _grid,
      snapping: _snapping,
      onGrid: (v) => setState(() => _grid = v),
      onSnapping: (v) => setState(() => _snapping = v),
    ));
  }

  Widget _stage(EditorState s) {
    final c = context.colors;
    final engine = _c.engine;
    return Stack(
      children: [
        // The engine stays loaded all the time; the flat editor covers it.
        Positioned.fill(child: engine.buildView()),
        if (!_show3d)
          Positioned.fill(
            child: ColoredBox(
              color: c.plate,
              child: DesignCanvas(
                key: _canvasKey,
                state: s,
                controller: _c,
                assets: _assets,
                showGrid: _grid,
                snapping: _snapping,
                onEditLayer: (id) => unawaited(_editText(id)),
                onLayerMenu: (id, at) => unawaited(_layerMenu(id, at)),
              ),
            ),
          ),
        if (_show3d)
          Positioned.fill(
            child: ValueListenableBuilder(
              valueListenable: engine.status,
              builder: (context, status, _) => switch (status) {
                EngineStatus.ready || EngineStatus.loading => ValueListenableBuilder(
                    valueListenable: _c.modelShown,
                    builder: (context, shown, _) => StageLoader(
                      show: status == EngineStatus.loading || !shown,
                      text: context.l10n.editorMain3dLoading,
                      immediate: true,
                    ),
                  ),
                EngineStatus.failed => ColoredBox(
                    color: c.plate,
                    child: Center(
                      child: EmptyState(
                        title: context.l10n.editorMain3dFailed,
                        icon: Icons.view_in_ar_outlined,
                        actionLabel: context.l10n.commonRetry,
                        onAction: () => unawaited(engine.reload()),
                        compact: true,
                      ),
                    ),
                  ),
              },
            ),
          ),
        Positioned(
          left: Insets.sm,
          top: Insets.sm,
          right: 120,
          child: Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: [
              if (s.problemTotal > 0)
                _Badge(
                  icon: Icons.error_outline_rounded,
                  label: context.l10n.editorMainErrorsBadge(s.problemTotal),
                  color: c.danger,
                  onTap: () => _showProblems(s),
                ),
              if (s.croppedCount > 0)
                _Badge(icon: Icons.crop_rounded, label: context.l10n.editorMainCroppedBadge(s.croppedCount), color: c.warning),
              if (s.linkedFrom != null)
                _Badge(
                  icon: Icons.sync_rounded,
                  label: context.l10n.editorMainSyncedFrom(s.linkedFrom!.name),
                  color: c.brand,
                  onTap: () => _c.selectArea(s.linkedFrom!.key),
                ),
            ],
          ),
        ),
        Positioned(
          right: Insets.sm,
          top: Insets.sm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _RoundButton(
                icon: _show3d ? Icons.crop_square_rounded : Icons.view_in_ar_outlined,
                tooltip: _show3d ? context.l10n.editorMainFlatView : context.l10n.editorMain3dView,
                onTap: () => _toggle3d(!_show3d),
              ),
              Gap.sm,
              _RoundButton(
                icon: Icons.photo_camera_outlined,
                tooltip: context.l10n.editorMainCapture,
                onTap: () => unawaited(showCaptureSheet(context, _c, widget.slug)),
              ),
              if (_show3d) ...[
                Gap.sm,
                _RoundButton(
                  icon: Icons.center_focus_strong_outlined,
                  tooltip: context.l10n.editorMainResetView,
                  onTap: () => unawaited(engine.resetView().catchError((_) {})),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _panelTitle(EditorState s) => switch (_tool) {
        _Tool.text => context.l10n.editorMainToolText,
        _Tool.image => context.l10n.editorMainToolImage,
        _Tool.elements => context.l10n.editorMainToolElements,
        _Tool.templates => context.l10n.editorMainToolGallery,
        _Tool.layers => context.l10n.editorMainToolLayers,
        _Tool.background => context.l10n.editorMainToolBackground,
        _Tool.props => s.layer == null ? context.l10n.editorMainSettings : PropsPanel.titleOf(s.layer!, _stickerLabel(s.layer!)),
        null => '',
      };

  String? _stickerLabel(Layer l) {
    final g = l.graphic;
    if (g == null || g.library != 'sticker') return null;
    final items = ref.read(stickerIndexProvider).value?.items ?? const [];
    for (final i in items) {
      if (i.name == g.name) return i.label;
    }
    return null;
  }

  void _closeOnPhone() {
    if (context.isCompact) setState(() => _tool = null);
  }

  Widget _panelBody(EditorState s) {
    final tool = _tool!;
    switch (tool) {
      case _Tool.text:
        return TextPanel(enabled: s.canAdd, onAdd: (p) => unawaited(_addText(p)));
      case _Tool.image:
        return ImagePanel(
          state: s,
          busy: _imageBusy,
          onPick: (src) => unawaited(_pickImage(src)),
          onReuse: (img) {
            if (_c.addImage(img) != null) _closeOnPhone();
          },
        );
      case _Tool.elements:
        return ElementsPanel(
          enabled: s.canAdd,
          ink: parseHexColor(s.inkColor),
          onPick: (item) {
            final id = item.sticker != null ? _c.addSticker(item.sticker!) : _c.addGraphic(item.library, item.name);
            if (id != null) _closeOnPhone();
          },
        );
      case _Tool.templates:
        return TemplatesPanel(
          slug: widget.slug,
          variantId: s.variantId,
          onPick: (t) {
            _c.applyTemplate(t);
            _closeOnPhone();
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(context.l10n.editorMainTemplateApplied(t.name)),
                action: SnackBarAction(label: context.l10n.editorMainUndoAction, onPressed: _c.undo),
              ));
          },
        );
      case _Tool.layers:
        return LayersPanel(
          state: s,
          controller: _c,
          stickers: ref.read(stickerLibraryProvider),
          onOpen: (id) {
            _c.select(id);
            setState(() => _tool = _Tool.props);
          },
        );
      case _Tool.background:
        return _backgroundPanel(s);
      case _Tool.props:
        final l = s.layer;
        if (l == null) return const SizedBox.shrink();
        return PropsPanel(
          state: s,
          controller: _c,
          layer: l,
          stickerLabel: _stickerLabel(l),
          onEditText: () => unawaited(_editText(l.id)),
        );
    }
  }

  Widget _panel(EditorState s, double? fraction, {bool fill = false}) {
    final body = _panelBody(s);
    if (fill) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.lg, Insets.sm),
            child: Text(_panelTitle(s), style: context.text.titleMedium),
          ),
          Expanded(child: body),
        ],
      );
    }
    return EditorPanel(
      key: ValueKey(_tool),
      title: _panelTitle(s),
      initialFraction: fraction ?? (_tool == _Tool.props ? 0.34 : 0.42),
      onClose: () => setState(() => _tool = null),
      child: body,
    );
  }

  Widget _backgroundPanel(EditorState s) {
    final pad = context.pagePadding;
    final variant = s.variant;
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 0, pad, Insets.xl),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.editorMainProductColorBackground),
          value: s.doc.hasBackground,
          onChanged: s.canBackground || s.doc.hasBackground ? _c.setBackground : null,
        ),
        if (variant != null && variant.colors.length > 1) ...[
          Gap.md,
          Text(context.l10n.editorMainProductColor, style: context.text.labelLarge?.copyWith(color: context.colors.inkMuted)),
          Gap.sm,
          ColorPicker(colors: variant.colors, selected: s.color, onSelected: (c) => _c.pickColor(c.id)),
        ],
      ],
    );
  }

  Widget _orderRow(EditorState s) {
    final c = context.colors;
    final price = s.price;
    return Container(
      padding: EdgeInsets.fromLTRB(context.pagePadding, Insets.sm, context.pagePadding, Insets.sm),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: Radii.brMd,
              onTap: () => unawaited(showVariantSheet(context, _args)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                child: Row(
                  children: [
                    if (s.color != null)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: s.color!.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.line),
                        ),
                      ),
                    Gap.sm,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            [s.variant?.name, if (s.size != null) s.size].whereType<String>().join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelMedium?.copyWith(color: c.inkMuted),
                          ),
                          if (price != null) PriceText(price, style: context.text.titleMedium),
                        ],
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, color: c.inkMuted),
                  ],
                ),
              ),
            ),
          ),
          Gap.sm,
          IconButton.outlined(
            tooltip: context.l10n.commonSave,
            onPressed: _saving ? null : () => unawaited(_save()),
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.bookmark_add_outlined),
          ),
          Gap.sm,
          FilledButton.icon(
            onPressed: s.cart is CartWorking ? null : () => unawaited(_addToCart()),
            icon: const Icon(Icons.shopping_bag_outlined, size: 20),
            label: Text(context.l10n.editorMainAddToCart),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
        ],
      ),
    );
  }

  List<Widget> _toolActions(EditorState s) => [
        BarAction(icon: Icons.title_rounded, label: context.l10n.editorMainToolText, selected: _tool == _Tool.text, onTap: () => _open(_Tool.text)),
        BarAction(icon: Icons.image_outlined, label: context.l10n.editorMainToolImage, selected: _tool == _Tool.image, onTap: () => _open(_Tool.image)),
        BarAction(
          icon: Icons.interests_outlined,
          label: context.l10n.editorMainToolElements,
          selected: _tool == _Tool.elements,
          onTap: () => _open(_Tool.elements),
        ),
        BarAction(
          icon: Icons.dashboard_outlined,
          label: context.l10n.editorMainToolGallery,
          selected: _tool == _Tool.templates,
          onTap: () => _open(_Tool.templates),
        ),
        BarAction(
          icon: Icons.layers_outlined,
          label: context.l10n.editorMainToolLayers,
          selected: _tool == _Tool.layers,
          onTap: () => _open(_Tool.layers),
        ),
        if (s.canBackground || s.doc.hasBackground)
          BarAction(
            icon: Icons.format_color_fill_rounded,
            label: context.l10n.editorMainToolBackground,
            selected: _tool == _Tool.background,
            onTap: () => _open(_Tool.background),
          ),
      ];

  List<Widget> _selectionActions(EditorState s) {
    final l = s.layer!;
    final editable = !l.isLocked && s.linkedFrom == null;
    return [
      if (l.text != null)
        BarAction(icon: Icons.edit_rounded, label: context.l10n.editorMainEditTextShort, onTap: () => unawaited(_editText(l.id))),
      BarAction(
        icon: Icons.tune_rounded,
        label: context.l10n.editorMainSettings,
        selected: _tool == _Tool.props,
        onTap: () => _open(_Tool.props),
      ),
      if (l.dial == null && !l.isBackground)
        BarAction(icon: Icons.copy_rounded, label: context.l10n.editorMainCopy, onTap: () => _c.duplicate(l.id)),
      BarAction(
        icon: Icons.filter_center_focus_rounded,
        label: context.l10n.editorMainCenter,
        onTap: editable
            ? () => _c.centerLayer(l.id, vertical: true)
            : null,
      ),
      BarAction(icon: Icons.flip_to_front_rounded, label: context.l10n.editorMainBringForward, onTap: _c.canMove(l.id, 1) ? () => _c.moveLayer(l.id, 1) : null),
      BarAction(icon: Icons.flip_to_back_rounded, label: context.l10n.editorMainSendBackward, onTap: _c.canMove(l.id, -1) ? () => _c.moveLayer(l.id, -1) : null),
      BarAction(
        icon: l.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
        label: l.isLocked ? context.l10n.editorMainLocked : context.l10n.editorMainLock,
        selected: l.isLocked,
        onTap: l.systemLocked ? null : () => _c.setLocked(l.id, !l.isLocked),
      ),
      BarAction(
        icon: Icons.delete_outline_rounded,
        label: context.l10n.commonDelete,
        danger: true,
        onTap: l.dial == null ? () => _c.removeLayer(l.id) : null,
      ),
    ];
  }

  Widget _bottomBar(EditorState s) {
    final c = context.colors;
    final selected = s.layer != null;
    return Container(
      color: c.surface,
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: AnimatedSwitcher(
        duration: Motion.fast,
        child: selected
            ? Row(
                key: const ValueKey('selection'),
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: _selectionActions(s)),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.commonDone,
                    onPressed: () => _c.select(null),
                    icon: Icon(Icons.check_circle_rounded, color: c.brand, size: 30),
                  ),
                ],
              )
            : SingleChildScrollView(
                key: const ValueKey('tools'),
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _toolActions(s),
                  ),
                ),
              ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color, this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      shape: StadiumBorder(side: BorderSide(color: color.withValues(alpha: 0.4))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      shape: const CircleBorder(),
      elevation: 1,
      child: IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icon)),
    );
  }
}
