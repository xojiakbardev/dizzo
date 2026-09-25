import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/widgets.dart';
import '../../../catalog/domain/catalog_models.dart' show parseHexColor;
import '../../domain/design_document.dart';
import '../../domain/editor_models.dart';
import '../../domain/graphics.dart';
import '../canvas/layer_transform.dart';
import '../editor_controller.dart';
import '../editor_state.dart';
import '../render/design_fonts.dart';
import '../widgets/editor_panel.dart';

const swatches = [
  '#111827', '#ffffff', '#6b7280', '#b91c1c', '#ef4444', '#ea580c', '#f59e0b', '#ca8a04', '#84cc16', '#15803d',
  '#0d9488', '#0ea5e9', '#0369a1', '#4338ca', '#6d28d9', '#a855f7', '#be185d', '#ec4899', '#8d4b00', '#d6b58b',
];

const lowDpi = 150;

/// Colour choice for text, graphics and clock numerals.
class SwatchRow extends StatelessWidget {
  const SwatchRow({super.key, required this.value, required this.onPick});

  final String value;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final current = value.toLowerCase();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final hex in {current, ...swatches})
            ColorDot(color: parseHexColor(hex), selected: hex == current, onTap: () => onPick(hex)),
        ],
      ),
    );
  }
}

/// Every design font, each written in itself.
class FontPicker extends StatelessWidget {
  const FontPicker({super.key, required this.value, required this.onPick, this.sample});

  final String value;
  final ValueChanged<String> onPick;
  final String? sample;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ValueListenableBuilder(
      valueListenable: fontsRevision,
      builder: (context, _, _) => SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: designFonts.length,
          separatorBuilder: (_, _) => Gap.sm,
          itemBuilder: (context, i) {
            final f = designFonts[i];
            final selected = f == value;
            return InkWell(
              borderRadius: Radii.brMd,
              onTap: () {
                HapticFeedback.selectionClick();
                onPick(f);
              },
              child: AnimatedContainer(
                duration: Motion.fast,
                width: 104,
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: Insets.xs),
                decoration: BoxDecoration(
                  borderRadius: Radii.brMd,
                  border: Border.all(color: selected ? c.brand : c.line, width: selected ? 2 : 1),
                  color: selected ? c.brand.withValues(alpha: 0.06) : c.surface,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      sample ?? context.l10n.editorFontSample,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: designTextStyle(f, bold: false, italic: false, px: 20, color: c.ink),
                    ),
                    Text(
                      f,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Small red/amber notes: what stops the cart, what gets cropped.
class ProblemNotes extends StatelessWidget {
  const ProblemNotes({super.key, required this.problems, this.cropped = false, this.lowQuality = false});

  final List<String> problems;
  final bool cropped;
  final bool lowQuality;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget chip(String text, Color color, IconData icon) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: Radii.brSm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(child: Text(text, style: context.text.labelMedium?.copyWith(color: color))),
            ],
          ),
        );
    final items = [
      for (final p in problems) chip(p, c.danger, Icons.error_outline_rounded),
      if (cropped) chip(context.l10n.editorPropsCropped, c.warning, Icons.crop_rounded),
      if (lowQuality) chip(context.l10n.editorPropsLowQuality, c.warning, Icons.blur_on_rounded),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Wrap(spacing: Insets.sm, runSpacing: Insets.sm, children: items),
    );
  }
}

/// "Sozlash": properties of the selected layer.
class PropsPanel extends StatelessWidget {
  const PropsPanel({
    super.key,
    required this.state,
    required this.controller,
    required this.layer,
    required this.onEditText,
    required this.stickerLabel,
  });

  final EditorState state;
  final EditorController controller;
  final Layer layer;
  final VoidCallback onEditText;
  final String? stickerLabel;

  static String titleOf(Layer l, String? stickerLabel) {
    final t = l10nNow;
    if (l.text != null) return t.editorSheetText;
    if (l.dial != null) return t.editorPropsDialNumerals;
    if (l.image != null) return t.editorPropsImage;
    final g = l.graphic!;
    if (l.isBackground) return t.editorPropsBackground;
    if (g.library == 'sticker') return stickerLabel ?? t.editorPropsSticker;
    final def = resolveGraphic(g.library, g.name);
    return def != null ? graphicLabel(def, t) : layerLabel(l);
  }

  @override
  Widget build(BuildContext context) {
    final l = layer;
    final area = areaByKey(state.areas, l.area);
    final m = area?.method(l.method);
    final mono = m != null && !m.colorsAllowed;
    final problems = state.problems[l.id] ?? const [];
    final cropped = sticksOut(l, state.areas, state.effective, state.strips);
    final img = l.image;
    final dpi = img == null ? null : math.min(img.pxW / (l.w / 25.4), img.pxH / (l.h / 25.4));
    final pad = context.pagePadding;
    final t = context.l10n;
    final color = l.text?.color ??
        l.dial?.color ??
        (l.graphic != null && (l.graphic!.library != 'sticker' || isMonoSticker(l.graphic!.name)) ? l.graphic!.color : null);

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 0, pad, Insets.lg),
      children: [
        ProblemNotes(problems: problems, cropped: cropped, lowQuality: dpi != null && dpi < lowDpi),
        if (l.text != null) ..._text(context, l, l.text!, m?.minFont),
        if (l.dial != null) ..._dial(context, l, l.dial!, m?.minFont),
        if (color != null && !mono && !l.isBackground) ...[
          _label(context, t.editorPropsColor),
          SwatchRow(value: color, onPick: (hex) => controller.setColor(l.id, hex)),
          Gap.md,
        ],
        if (!l.isLocked && l.dial == null) ...[
          ValueSlider(
            label: t.editorPropsRotation,
            value: l.rotation,
            min: -180,
            max: 180,
            format: (v) => '${v.round()}°',
            onChangeStart: (_) => controller.checkpoint(),
            onChanged: (v) {
              final a = area;
              if (a == null) return;
              final r = rotateLayer(a, l, v - l.rotation);
              controller.patchLayer(r.layer.copyWith(rotation: v.roundToDouble()));
            },
          ),
          if (l.text == null)
            ValueSlider(
              label: t.editorPropsSize,
              value: math.max(l.w, l.h),
              min: 2,
              max: math.max(math.max(l.w, l.h), area == null ? 100 : math.max(area.widthMm, area.heightMm) * 1.5),
              format: (v) => context.l10n.editorPropsMm('${v.round()}'),
              onChangeStart: (_) => controller.checkpoint(),
              onChanged: (v) {
                if (area == null) return;
                controller.patchLayer(scaledLayer(area, l, v / math.max(l.w, l.h), state.effective));
              },
            ),
          Gap.sm,
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              ActionChip(
                avatar: const Icon(Icons.align_horizontal_center_rounded, size: 18),
                label: Text(t.editorPropsCenterX),
                onPressed: () => controller.centerLayer(l.id, horizontal: true),
              ),
              ActionChip(
                avatar: const Icon(Icons.align_vertical_center_rounded, size: 18),
                label: Text(t.editorPropsCenterY),
                onPressed: () => controller.centerLayer(l.id, horizontal: false, vertical: true),
              ),
              if (l.rotation != 0)
                ActionChip(
                  avatar: const Icon(Icons.rotate_left_rounded, size: 18),
                  label: Text(t.editorPropsStraighten),
                  onPressed: () => controller.updateLayer(l.copyWith(rotation: 0)),
                ),
            ],
          ),
        ],
        if (l.isBackground) ...[
          Gap.md,
          OutlinedButton.icon(
            onPressed: () => controller.setBackground(false),
            icon: const Icon(Icons.format_color_reset_rounded),
            label: Text(t.editorPropsRemoveBackground),
          ),
        ],
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.xs),
        child: Text(text, style: context.text.labelLarge?.copyWith(color: context.colors.inkMuted)),
      );

  List<Widget> _text(BuildContext context, Layer l, TextSource t, double? minFont) {
    final c = context.colors;
    final min = (minFont ?? 1).ceilToDouble();
    return [
      InkWell(
        onTap: onEditText,
        borderRadius: Radii.brMd,
        child: InputDecorator(
          decoration: const InputDecoration(suffixIcon: Icon(Icons.edit_rounded)),
          child: Text(t.content, maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
      ),
      Gap.md,
      FontPicker(
        value: t.font,
        sample: t.content.trim().isEmpty ? null : t.content.split('\n').first,
        onPick: (f) => controller.setTextSource(l.id, t.copyWith(font: f)),
      ),
      Gap.sm,
      ValueSlider(
        label: context.l10n.editorPropsFontSize,
        value: t.sizeMm,
        min: min,
        max: math.max(min + 1, math.max(t.sizeMm, 150)),
        divisions: null,
        format: (v) => context.l10n.editorPropsMm('${v.round()}'),
        onChangeStart: (_) => controller.checkpoint(),
        onChanged: (v) {
          final size = v.roundToDouble();
          if (size != t.sizeMm) controller.setTextSource(l.id, t.copyWith(sizeMm: size), record: false);
        },
      ),
      Row(
        children: [
          SegmentedButton<LineAlign>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: LineAlign.left, icon: const Icon(Icons.format_align_left_rounded), tooltip: context.l10n.editorPropsAlignLeft),
              ButtonSegment(value: LineAlign.center, icon: const Icon(Icons.format_align_center_rounded), tooltip: context.l10n.editorPropsAlignCenter),
              ButtonSegment(value: LineAlign.right, icon: const Icon(Icons.format_align_right_rounded), tooltip: context.l10n.editorPropsAlignRight),
            ],
            selected: {t.align},
            onSelectionChanged: (v) => controller.setTextSource(l.id, t.copyWith(align: v.first)),
          ),
          const Spacer(),
          IconButton.outlined(
            tooltip: context.l10n.editorPropsBold,
            isSelected: t.bold,
            selectedIcon: Icon(Icons.format_bold_rounded, color: c.brand),
            icon: const Icon(Icons.format_bold_rounded),
            onPressed: () => controller.setTextSource(l.id, t.copyWith(bold: !t.bold)),
          ),
          Gap.xs,
          IconButton.outlined(
            tooltip: context.l10n.editorPropsItalic,
            isSelected: t.italic,
            selectedIcon: Icon(Icons.format_italic_rounded, color: c.brand),
            icon: const Icon(Icons.format_italic_rounded),
            onPressed: () => controller.setTextSource(l.id, t.copyWith(italic: !t.italic)),
          ),
        ],
      ),
      Gap.md,
    ];
  }

  List<Widget> _dial(BuildContext context, Layer l, DialSource d, double? minFont) {
    final min = (minFont ?? 1).ceilToDouble();
    final max = math.max(min + 1, (math.min(l.w, l.h) * 0.16).roundToDouble());
    return [
      SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [
          const ButtonSegment(value: 'arabic', label: Text('12')),
          const ButtonSegment(value: 'roman', label: Text('XII')),
          ButtonSegment(value: 'none', label: Text(context.l10n.editorPropsNumeralsNone)),
        ],
        selected: {d.numerals},
        onSelectionChanged: (v) => controller.setDial(l.id, d.copyWith(numerals: v.first)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.l10n.editorPropsMinuteTicks),
        value: d.ticks,
        onChanged: (v) => controller.setDial(l.id, d.copyWith(ticks: v)),
      ),
      if (d.numerals != 'none') ...[
        FontPicker(value: d.font, sample: d.numerals == 'roman' ? 'XII' : '12', onPick: (f) => controller.setDial(l.id, d.copyWith(font: f))),
        ValueSlider(
          label: context.l10n.editorPropsFontSize,
          value: d.sizeMm,
          min: min,
          max: max,
          format: (v) => context.l10n.editorPropsMm('${v.round()}'),
          onChangeStart: (_) => controller.checkpoint(),
          onChanged: (v) => controller.patchLayer(l.copyWith(dial: d.copyWith(sizeMm: v.roundToDouble()))),
        ),
        Row(
          children: [
            FilterChip(
              label: Text(context.l10n.editorPropsBold),
              selected: d.bold,
              onSelected: (v) => controller.setDial(l.id, d.copyWith(bold: v)),
            ),
            Gap.sm,
            FilterChip(
              label: Text(context.l10n.editorPropsItalic),
              selected: d.italic,
              onSelected: (v) => controller.setDial(l.id, d.copyWith(italic: v)),
            ),
          ],
        ),
      ],
      Gap.md,
    ];
  }
}
