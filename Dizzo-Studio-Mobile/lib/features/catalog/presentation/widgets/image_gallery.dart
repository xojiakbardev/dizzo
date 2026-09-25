import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/widgets.dart';

/// Swipeable product pictures with page dots; a tap opens a zoomable
/// full-screen viewer (hero transition).
///
/// When [images] changes (another type or colour) the new set cross-fades
/// over the old one and opens at the same position when it has that many
/// pictures (sets are usually shot in the same order: front, side, back).
/// [upcoming] are the sets the customer is likely to pick next; their first
/// pictures are decoded ahead so switching is instant.
class ImageGallery extends StatefulWidget {
  const ImageGallery({
    super.key,
    required this.images,
    this.heroTag,
    this.upcoming = const [],
  });

  final List<String> images;

  /// Hero tag of the grid card that opened the page (see [ImageGalleryState]).
  final String? heroTag;
  final List<List<String>> upcoming;

  /// At most this many pictures are decoded ahead (a gallery picture is a
  /// few MB in memory).
  static const maxPrecached = 6;

  @override
  State<ImageGallery> createState() => ImageGalleryState();
}

class _Layer {
  _Layer(this.id, this.images, int page) : controller = PageController(initialPage: page);

  final int id;
  final List<String> images;
  final PageController controller;
}

@visibleForTesting
class ImageGalleryState extends State<ImageGallery> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(vsync: this, duration: Motion.normal, value: 1)
    ..addStatusListener(_onFade);
  final _index = ValueNotifier(0);
  late final List<_Layer> _layers = [_Layer(0, widget.images, 0)];
  var _nextId = 1;
  double? _width;
  final _precached = <String>{};

  /// The picture index on screen.
  int get index => _index.value;

  _Layer get _top => _layers.last;

  static String _keyOf(List<String> images) => images.join('\n');

  @override
  void didUpdateWidget(ImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_keyOf(widget.images) != _keyOf(_top.images)) {
      final page = widget.images.isEmpty ? 0 : math.min(_index.value, widget.images.length - 1);
      // A switch during a fade: the half-shown set goes, the new one fades
      // in over the set that was fully shown.
      while (_layers.length > 1) {
        _layers.removeLast().controller.dispose();
      }
      _layers.add(_Layer(_nextId++, widget.images, page));
      _index.value = page;
      _fade.forward(from: 0);
    }
    _schedulePrecache();
  }

  void _onFade(AnimationStatus status) {
    if (status != AnimationStatus.completed || _layers.length < 2) return;
    setState(() {
      while (_layers.length > 1) {
        _layers.removeAt(0).controller.dispose();
      }
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    _index.dispose();
    for (final l in _layers) {
      l.controller.dispose();
    }
    super.dispose();
  }

  void _schedulePrecache() {
    final width = _width;
    if (width == null) return;
    // The first and current picture of every likely next set, the likeliest
    // first, and the neighbours of the current picture.
    final wanted = <String>[
      for (final set in widget.upcoming) ...[
        if (set.isNotEmpty) set.first,
        if (set.length > _index.value && _index.value > 0) set[_index.value],
      ],
    ].where((u) => !_precached.contains(u)).take(ImageGallery.maxPrecached - _precached.length).toList();
    if (wanted.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final url in wanted) {
        if (_precached.add(url)) AppImage.precache(context, url, width);
      }
    });
  }

  /// The grid card's tag sits on the first picture while it is the one on
  /// screen (so going back flies from what the customer sees); every other
  /// picture has a tag of its own for the full-screen viewer.
  Object _tagFor(_Layer layer, int i, {required int current}) {
    final gridTag = widget.heroTag;
    if (gridTag != null && i == 0 && current == 0) return gridTag;
    return 'gallery-${identityHashCode(this)}-${layer.id}-$i';
  }

  void _open(_Layer layer, int i) {
    HapticFeedback.selectionClick();
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: Motion.slow,
        reverseTransitionDuration: Motion.normal,
        pageBuilder: (_, _, _) => ImageViewer(
          images: layer.images,
          initial: i,
          heroTags: [for (var k = 0; k < layer.images.length; k++) _tagFor(layer, k, current: k)],
          // Keep the gallery on the same picture so the hero flies back
          // to it.
          onPageChanged: (k) {
            if (layer.controller.hasClients) layer.controller.jumpToPage(k);
          },
        ),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  Widget _buildLayer(_Layer layer, {required bool top}) {
    final c = context.colors;
    Widget pages = layer.images.isEmpty
        ? const AppImage(null)
        : PageView.builder(
            controller: layer.controller,
            itemCount: layer.images.length,
            // Build the neighbours too, so a swipe shows a decoded picture.
            allowImplicitScrolling: true,
            onPageChanged: (i) {
              if (identical(layer, _top)) {
                _index.value = i;
                _schedulePrecache();
              }
            },
            itemBuilder: (context, i) {
              final image = AppImage(layer.images[i], fit: BoxFit.contain);
              Widget hero(int current) => Hero(
                    tag: _tagFor(layer, i, current: current),
                    flightShuttleBuilder: appImageFlightShuttle,
                    child: image,
                  );
              return GestureDetector(
                onTap: () => _open(layer, i),
                child: i == 0 && widget.heroTag != null
                    ? ValueListenableBuilder<int>(
                        valueListenable: _index,
                        builder: (_, current, _) => hero(current),
                      )
                    : hero(i),
              );
            },
          );
    pages = ColoredBox(color: c.plate, child: pages);
    return FadeTransition(
      key: ValueKey(layer.id),
      opacity: top ? _fade : kAlwaysCompleteAnimation,
      // Only the set on top takes part in hero flights and touches.
      child: HeroMode(
        enabled: top,
        child: IgnorePointer(ignoring: !top, child: pages),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_width != constraints.maxWidth && constraints.maxWidth.isFinite) {
          _width = constraints.maxWidth;
          _schedulePrecache();
        }
        return RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (final l in _layers) _buildLayer(l, top: identical(l, _top)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: RepaintBoundary(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _index,
                    builder: (context, index, _) => _Dots(
                      count: _top.images.length,
                      index: index,
                      color: c.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, required this.color});

  final int count;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
    return Semantics(
      label: '${index + 1} / $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: Motion.fast,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index ? color : color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen pictures: swipe between them, pinch or double-tap to zoom.
class ImageViewer extends StatefulWidget {
  const ImageViewer({
    super.key,
    required this.images,
    required this.initial,
    this.heroTags,
    this.onPageChanged,
  });

  final List<String> images;
  final int initial;
  final List<Object>? heroTags;
  final ValueChanged<int>? onPageChanged;

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late final _page = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  bool _zoomed = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.images.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            itemCount: count,
            // A zoomed picture pans instead of turning the page.
            physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
            onPageChanged: (i) {
              setState(() => _index = i);
              widget.onPageChanged?.call(i);
            },
            itemBuilder: (_, i) => _ZoomablePicture(
              url: widget.images[i],
              heroTag: widget.heroTags?[i],
              onZoomed: (z) {
                if (z != _zoomed) setState(() => _zoomed = z);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.close_rounded,
                    tooltip: context.l10n.commonClose,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  if (count > 1)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text(
                          '${_index + 1} / $count',
                          style: context.text.labelLarge?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomablePicture extends StatefulWidget {
  const _ZoomablePicture({required this.url, required this.heroTag, required this.onZoomed});

  final String url;
  final Object? heroTag;
  final ValueChanged<bool> onZoomed;

  @override
  State<_ZoomablePicture> createState() => _ZoomablePictureState();
}

class _ZoomablePictureState extends State<_ZoomablePicture> with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _zoomAnim;
  Animation<Matrix4>? _animation;
  Offset _tapAt = Offset.zero;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _zoomAnim = AnimationController(vsync: this, duration: Motion.normal)
      ..addListener(() {
        final a = _animation;
        if (a != null) _transform.value = a.value;
      });
    _transform.addListener(_onTransform);
  }

  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) {
      _zoomed = zoomed;
      widget.onZoomed(zoomed);
    }
  }

  @override
  void dispose() {
    _zoomAnim.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final Matrix4 target;
    if (_zoomed) {
      target = Matrix4.identity();
    } else {
      const scale = 2.5;
      target = Matrix4.identity()
        ..translateByDouble(-_tapAt.dx * (scale - 1), -_tapAt.dy * (scale - 1), 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
    }
    _animation = Matrix4Tween(begin: _transform.value, end: target)
        .animate(CurvedAnimation(parent: _zoomAnim, curve: Curves.easeOutCubic));
    _zoomAnim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // The gallery's decode (already in memory) first, a sharper one for
    // zooming over it once it is ready.
    final base = AppImage.decodeWidth(size.width * dpr);
    final sharp = AppImage.decodeWidth(size.width * dpr * 2);
    Widget picture = AppImage(widget.url, fit: BoxFit.contain, background: Colors.black, cacheWidth: base);
    if (sharp > base) {
      picture = Stack(
        fit: StackFit.expand,
        children: [
          picture,
          CachedNetworkImage(
            imageUrl: widget.url,
            fit: BoxFit.contain,
            memCacheWidth: sharp,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (_, _) => const SizedBox.shrink(),
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      );
    }
    final tag = widget.heroTag;
    if (tag != null) {
      picture = Hero(tag: tag, flightShuttleBuilder: appImageFlightShuttle, child: picture);
    }
    return GestureDetector(
      onDoubleTapDown: (d) => _tapAt = d.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        maxScale: 4,
        child: SizedBox.expand(child: picture),
      ),
    );
  }
}
