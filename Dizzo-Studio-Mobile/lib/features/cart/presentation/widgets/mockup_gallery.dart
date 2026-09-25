import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/widgets.dart';

/// A cart, order or design item's pictures (the Studio's five views):
/// swipeable, with page dots; a tap opens them full screen.
///
/// Used by the cart, checkout, orders and designs screens.
class MockupGallery extends StatefulWidget {
  const MockupGallery({
    super.key,
    required this.images,
    this.borderRadius = Radii.brLg,
    this.fallbackIcon = Icons.image_outlined,
  });

  final List<String> images;
  final BorderRadius borderRadius;
  final IconData fallbackIcon;

  @override
  State<MockupGallery> createState() => _MockupGalleryState();
}

class _MockupGalleryState extends State<MockupGallery> {
  final _page = PageController();
  int _index = 0;

  @override
  void didUpdateWidget(MockupGallery old) {
    super.didUpdateWidget(old);
    if (old.images.length != widget.images.length && _index >= widget.images.length) {
      _index = 0;
      if (_page.hasClients) _page.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final c = context.colors;
    if (images.isEmpty) {
      return AppImage(null, borderRadius: widget.borderRadius, fallbackIcon: widget.fallbackIcon);
    }
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: ColoredBox(
        color: c.plate,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _page,
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => showMockupViewer(context, images, initial: i),
                child: Semantics(
                  image: true,
                  label: context.l10n.cartImageLabel(i + 1, images.length),
                  child: AppImage(images[i], fit: BoxFit.contain),
                ),
              ),
            ),
            if (images.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < images.length; i++)
                        AnimatedContainer(
                          duration: Motion.fast,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: i == _index ? 14 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: i == _index ? c.ink : c.ink.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small square tiles in a row (checkout summary, review photos).
class MockupStrip extends StatelessWidget {
  const MockupStrip({super.key, required this.images, this.size = 48});

  final List<String> images;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => Gap.sm,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => showMockupViewer(context, images, initial: i),
          child: AppImage(images[i], width: size, height: size, borderRadius: Radii.brSm),
        ),
      ),
    );
  }
}

/// Full-screen, zoomable pictures.
Future<void> showMockupViewer(BuildContext context, List<String> images, {int initial = 0}) {
  HapticFeedback.selectionClick();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => MockupViewer(images: images, initial: initial),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

class MockupViewer extends StatefulWidget {
  const MockupViewer({super.key, required this.images, this.initial = 0});

  final List<String> images;
  final int initial;

  @override
  State<MockupViewer> createState() => _MockupViewerState();
}

class _MockupViewerState extends State<MockupViewer> {
  late final _page = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.images.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            itemCount: n,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: AppImage(widget.images[i], fit: BoxFit.contain, background: Colors.black),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Insets.sm),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.close_rounded,
                    tooltip: context.l10n.commonClose,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  if (n > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Text('${_index + 1} / $n', style: context.text.labelLarge?.copyWith(color: Colors.white)),
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
