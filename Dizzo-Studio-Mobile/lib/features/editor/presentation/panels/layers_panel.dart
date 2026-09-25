import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/widgets/widgets.dart';
import '../../../catalog/domain/catalog_models.dart' show parseHexColor;
import '../../data/sticker_library.dart';
import '../../domain/design_document.dart';
import '../editor_controller.dart';
import '../editor_state.dart';
import 'props_panel.dart';

/// "Qatlamlar": the open area's layers, top first. Drag to reorder; lock,
/// hide, delete. Hidden layers stay in the design but are not printed.
class LayersPanel extends StatelessWidget {
  const LayersPanel({
    super.key,
    required this.state,
    required this.controller,
    required this.stickers,
    required this.onOpen,
  });

  final EditorState state;
  final EditorController controller;
  final StickerLibrary stickers;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.l10n;
    final pad = context.pagePadding;
    final area = state.area;
    if (area == null) return const SizedBox.shrink();
    final linked = state.linkedFrom;
    final own = [for (final l in state.doc.layers) if (l.area == area.key) l];
    final topFirst = own.reversed.toList();
    final parked = [for (final l in state.doc.layers) if (l.area == null) l];
    return CustomScrollView(
      slivers: [
        if (linked != null)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, Insets.md),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Icon(Icons.sync_rounded, color: c.brand),
                  Gap.sm,
                  Expanded(child: Text(t.editorLayersSyncedWith(linked.name), style: context.text.bodyMedium)),
                  TextButton(onPressed: () => controller.selectArea(linked.key), child: Text(t.editorLayersOpen)),
                ],
              ),
            ),
          ),
        if (topFirst.isEmpty && linked == null)
          SliverToBoxAdapter(
            child: EmptyState(title: t.editorLayersEmpty, icon: Icons.layers_outlined, compact: true),
          ),
        SliverReorderableList(
          itemCount: topFirst.length,
          onReorder: (from, to) {
            final ids = [for (final l in topFirst) l.id];
            final moved = ids.removeAt(from);
            ids.insert(to > from ? to - 1 : to, moved);
            HapticFeedback.selectionClick();
            controller.reorderArea(area.key, ids.reversed.toList());
          },
          itemBuilder: (context, i) {
            final l = topFirst[i];
            return _LayerRow(
              key: ValueKey(l.id),
              index: i,
              layer: l,
              selected: state.selectedLayer == l.id,
              problem: state.problems.containsKey(l.id),
              stickers: stickers,
              onTap: () => onOpen(l.id),
              onLock: l.systemLocked ? null : () => controller.setLocked(l.id, l.locked == null),
              onHide: l.dial != null || l.isBackground ? null : () => controller.setHidden(l.id, true),
              onDelete: l.dial != null ? null : () => controller.removeLayer(l.id),
            );
          },
        ),
        if (parked.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, Insets.lg, pad, Insets.xs),
            sliver: SliverToBoxAdapter(
              child: Text(t.editorLayersHidden, style: context.text.labelLarge?.copyWith(color: c.inkMuted)),
            ),
          ),
          SliverList.builder(
            itemCount: parked.length,
            itemBuilder: (context, i) {
              final l = parked[i];
              return ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: pad),
                leading: Opacity(opacity: 0.5, child: _LayerThumb(layer: l, stickers: stickers)),
                title: Text(_title(l), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: t.editorLayersShow,
                      icon: const Icon(Icons.visibility_outlined),
                      onPressed: () => controller.setHidden(l.id, false),
                    ),
                    IconButton(
                      tooltip: context.l10n.commonDelete,
                      icon: Icon(Icons.delete_outline_rounded, color: c.danger),
                      onPressed: () => controller.removeLayer(l.id),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        const SliverToBoxAdapter(child: Gap.xl),
      ],
    );
  }
}

String _title(Layer l) => l.text != null ? layerLabel(l) : PropsPanel.titleOf(l, null);

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    super.key,
    required this.index,
    required this.layer,
    required this.selected,
    required this.problem,
    required this.stickers,
    required this.onTap,
    required this.onLock,
    required this.onHide,
    required this.onDelete,
  });

  final int index;
  final Layer layer;
  final bool selected;
  final bool problem;
  final StickerLibrary stickers;
  final VoidCallback onTap;
  final VoidCallback? onLock;
  final VoidCallback? onHide;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = layer;
    return Material(
      color: selected ? c.brand.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.pagePadding - 4, vertical: 2),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(Insets.sm),
                  child: Icon(Icons.drag_indicator_rounded, color: c.inkSubtle),
                ),
              ),
              _LayerThumb(layer: l, stickers: stickers),
              Gap.md,
              Expanded(
                child: Text(
                  _title(l),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(color: problem ? c.danger : null),
                ),
              ),
              if (problem) Icon(Icons.error_outline_rounded, size: 18, color: c.danger),
              IconButton(
                tooltip: l.isLocked ? context.l10n.editorLayersUnlock : context.l10n.editorLayersLock,
                onPressed: onLock,
                icon: Icon(l.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded, size: 20),
              ),
              IconButton(
                tooltip: context.l10n.editorLayersHide,
                onPressed: onHide,
                icon: const Icon(Icons.visibility_off_outlined, size: 20),
              ),
              IconButton(
                tooltip: context.l10n.commonDelete,
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, size: 20, color: onDelete == null ? null : c.danger),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayerThumb extends StatelessWidget {
  const _LayerThumb({required this.layer, required this.stickers});

  final Layer layer;
  final StickerLibrary stickers;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = layer;
    Widget child;
    if (l.image != null) {
      child = AppImage(l.image!.url, fit: BoxFit.contain);
    } else if (l.graphic?.library == 'sticker') {
      final svg = stickers.svg(l.graphic!.name);
      child = svg == null ? Icon(Icons.emoji_emotions_outlined, color: c.inkMuted) : SvgPicture.string(svg);
    } else if (l.text != null) {
      child = Icon(Icons.title_rounded, color: parseHexColor(l.text!.color).computeLuminance() > 0.9 ? c.ink : parseHexColor(l.text!.color));
    } else if (l.dial != null) {
      child = Icon(Icons.schedule_rounded, color: c.ink);
    } else {
      final color = parseHexColor(l.graphic!.color);
      child = Icon(Icons.category_rounded, color: color.computeLuminance() > 0.9 ? c.ink : color);
    }
    return Container(
      width: 40,
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.plate, borderRadius: Radii.brSm),
      child: child,
    );
  }
}
