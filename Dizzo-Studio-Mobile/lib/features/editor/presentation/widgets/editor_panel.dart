import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/widgets.dart';

/// A tool panel under the stage: the design stays visible above it. Drag
/// the handle to make it taller or shorter; drag it down to close.
class EditorPanel extends StatefulWidget {
  const EditorPanel({
    super.key,
    required this.title,
    required this.child,
    required this.onClose,
    this.actions = const [],
    this.initialFraction = 0.42,
    this.maxHeight,
  });

  final String title;
  final Widget child;
  final VoidCallback onClose;
  final List<Widget> actions;

  /// Of the space the editor has.
  final double initialFraction;
  final double? maxHeight;

  @override
  State<EditorPanel> createState() => _EditorPanelState();
}

class _EditorPanelState extends State<EditorPanel> {
  double? _height;
  double _dragStart = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, box) {
        final screen = MediaQuery.sizeOf(context).height;
        final maxH = widget.maxHeight ?? screen * 0.72;
        final minH = screen * 0.2;
        final h = (_height ?? screen * widget.initialFraction).clamp(minH, maxH);
        return AnimatedContainer(
          duration: _height == null ? Motion.normal : Duration.zero,
          height: h,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
          ),
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (d) => _dragStart = h,
                onVerticalDragUpdate: (d) => setState(() => _height = (_height ?? h) - d.delta.dy),
                onVerticalDragEnd: (d) {
                  final current = _height ?? h;
                  if (current < minH * 1.05 && (d.primaryVelocity ?? 0) > 0 || (d.primaryVelocity ?? 0) > 1200) {
                    HapticFeedback.lightImpact();
                    widget.onClose();
                    return;
                  }
                  setState(() => _height = current.clamp(minH, maxH));
                  if ((current - _dragStart).abs() > 40) HapticFeedback.selectionClick();
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.xs, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2)),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              style: context.text.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ...widget.actions,
                          IconButton(
                            tooltip: context.l10n.commonClose,
                            onPressed: widget.onClose,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: widget.child),
            ],
          ),
        );
      },
    );
  }
}

/// A round colour choice.
class ColorDot extends StatelessWidget {
  const ColorDot({super.key, required this.color, required this.selected, required this.onTap, this.size = 36});

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        radius: size / 2 + 4,
        child: AnimatedContainer(
          duration: Motion.fast,
          width: size,
          height: size,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? c.brand : Colors.transparent, width: 2),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled round action for bars (icon over a short label).
class BarAction extends StatelessWidget {
  const BarAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = onTap == null
        ? c.inkSubtle
        : danger
            ? c.danger
            : selected
                ? c.brand
                : c.ink;
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      borderRadius: Radii.brMd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 60, minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.xs, vertical: Insets.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: Motion.fast,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                decoration: BoxDecoration(
                  color: selected ? c.brand.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A slider row: label, value, slider.
class ValueSlider extends StatelessWidget {
  const ValueSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.format,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final String Function(double)? format;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(min, max).toDouble();
    return Row(
      children: [
        SizedBox(width: 84, child: Text(label, style: context.text.bodyMedium)),
        Expanded(
          child: Slider(
            value: v,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            onChangeStart: onChangeStart,
            onChangeEnd: onChangeEnd,
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            format?.call(v) ?? v.toStringAsFixed(0),
            textAlign: TextAlign.end,
            style: context.text.labelLarge,
          ),
        ),
      ],
    );
  }
}
