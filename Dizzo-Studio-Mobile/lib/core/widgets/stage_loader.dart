import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'brand_loader.dart';

/// The loading overlay of a 3D stage (the model coming in, "Savatga
/// qo‘shish") — the twin of the site's `StageLoader.vue`: the Dizzo loader
/// in the middle, no box, a short step text under it that crossfades as the
/// real work moves on, and a thin bar when the share done is known.
///
/// Short waits never show it ([delay]); once shown it stays at least
/// [minShow] so it doesn't flash. Hidden, it lets touches through.
class StageLoader extends StatefulWidget {
  const StageLoader({
    super.key,
    required this.show,
    this.text,
    this.progress,
    this.background,
    this.immediate = false,
    this.delay = const Duration(milliseconds: 250),
    this.minShow = const Duration(milliseconds: 600),
  });

  final bool show;
  final String? text;

  /// 0..1, null when unknown.
  final double? progress;

  /// The stage's colour (default: the product plate).
  final Color? background;

  /// Shown at once (a loader was already on screen).
  final bool immediate;
  final Duration delay;
  final Duration minShow;

  @override
  State<StageLoader> createState() => _StageLoaderState();
}

class _StageLoaderState extends State<StageLoader> {
  bool _visible = false;
  bool _painting = false; // the content stays until the fade-out ends
  DateTime _shownAt = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.show) {
      if (widget.immediate) {
        _visible = _painting = true;
      } else {
        _timer = Timer(widget.delay, _reveal);
      }
    }
  }

  @override
  void didUpdateWidget(StageLoader old) {
    super.didUpdateWidget(old);
    if (old.show == widget.show) return;
    _timer?.cancel();
    if (widget.show) {
      if (_visible) return;
      if (widget.immediate) {
        _reveal();
      } else {
        _timer = Timer(widget.delay, _reveal);
      }
      return;
    }
    final left = widget.minShow - DateTime.now().difference(_shownAt);
    if (_visible && left > Duration.zero) {
      _timer = Timer(left, () => _setVisible(false));
    } else {
      _setVisible(false);
    }
  }

  void _reveal() {
    _shownAt = DateTime.now();
    _setVisible(true);
  }

  void _setVisible(bool on) {
    if (!mounted || _visible == on) return;
    setState(() {
      _visible = on;
      if (on) _painting = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_visible,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        onEnd: () {
          if (!_visible && mounted) setState(() => _painting = false);
        },
        child: ColoredBox(
          color: widget.background ?? context.colors.plate,
          child: Center(
            child: _painting
                ? StageLoaderContent(text: widget.text, progress: widget.progress)
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// The loader, the step text and the bar, without the stage (a sheet uses it too).
class StageLoaderContent extends StatelessWidget {
  const StageLoaderContent({super.key, this.text, this.progress, this.size = 72});

  final String? text;
  final double? progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = this.text;
    final progress = this.progress?.clamp(0.0, 1.0);
    return SizedBox(
      width: 224,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandLoader(size: size),
          if (text != null && text.isNotEmpty) ...[
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.center,
                children: [...previous, ?current],
              ),
              child: Text(
                text,
                // Only a new step crossfades; a counter ("3/11") changes in place.
                key: ValueKey(text.replaceAll(RegExp(r'\d+\s*/\s*\d+'), '#')),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.inkMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                width: 96,
                height: 3,
                child: ColoredBox(
                  color: c.ink.withValues(alpha: .1),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progress),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    builder: (context, value, _) => Transform.scale(
                      scaleX: value,
                      alignment: Alignment.centerLeft,
                      child: ColoredBox(color: c.brand),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
