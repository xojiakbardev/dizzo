import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'skeleton.dart';

/// A network image (absolute URL from the API) with a shimmer placeholder,
/// a quiet fallback icon on error or a null URL, disk caching and memory
/// downscaling to the displayed size.
///
/// The decode width is rounded up to a few fixed steps ([decodeWidth]), so
/// a picture shown at slightly different sizes (a hero flight, a
/// collapsing header, a rotated tablet) reuses one decoded image instead
/// of decoding it again for every size.
class AppImage extends StatelessWidget {
  const AppImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.background,
    this.fallbackIcon = Icons.image_outlined,
    this.cacheWidth,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  /// Shown behind transparent product shots; defaults to the warm plate.
  final Color? background;
  final IconData fallbackIcon;

  /// Decode width in pixels; by default [decodeWidth] of the laid-out size.
  final int? cacheWidth;

  static const _steps = [256, 384, 512, 768, 1024, 1280, 1536, 2048];

  /// [pixels] rounded up to the next decode step (at most 2048).
  static int decodeWidth(double pixels) {
    for (final s in _steps) {
      if (pixels <= s) return s;
    }
    return _steps.last;
  }

  /// The image provider [AppImage] uses for [url] at [cacheWidth], for
  /// [precacheImage].
  static ImageProvider provider(String url, int cacheWidth) =>
      ResizeImage.resizeIfNeeded(cacheWidth, null, CachedNetworkImageProvider(url));

  /// Decodes [url] for a box [logicalWidth] wide ahead of time, so showing
  /// it later is instant. Errors are ignored.
  static Future<void> precache(BuildContext context, String url, double logicalWidth) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return precacheImage(
      provider(url, decodeWidth(logicalWidth * dpr)),
      context,
      onError: (_, _) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = background ?? context.colors.plate;
    final src = url;
    Widget child;
    if (src == null || src.isEmpty) {
      child = _Fallback(icon: fallbackIcon);
    } else if (cacheWidth != null) {
      child = _image(src, cacheWidth!);
    } else {
      child = LayoutBuilder(
        builder: (context, constraints) {
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final w = constraints.maxWidth.isFinite ? constraints.maxWidth : width;
          final h = constraints.maxHeight.isFinite ? constraints.maxHeight : height;
          // A cover-fitted picture in a tall box is scaled by its height:
          // decode wide enough for that too (assume up to a 4:3 landscape).
          final logical = fit == BoxFit.cover && w != null && h != null && h > w ? h * 4 / 3 : w;
          return _image(src, logical == null ? null : decodeWidth(logical * dpr));
        },
      );
    }
    child = ColoredBox(color: bg, child: child);
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return SizedBox(width: width, height: height, child: child);
  }

  Widget _image(String src, int? cacheWidth) => CachedNetworkImage(
        imageUrl: src,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: cacheWidth,
        fadeInDuration: const Duration(milliseconds: 180),
        // The package default (1 s) keeps the shimmer running over the
        // loaded picture.
        fadeOutDuration: const Duration(milliseconds: 120),
        placeholder: (_, _) => const Skeleton(),
        errorWidget: (_, _, _) => _Fallback(icon: fallbackIcon),
      );
}

/// A hero flight between two [AppImage]s: each end is drawn with the decode
/// width it already has on its own page (no new decode, no shimmer flash
/// mid-flight) and the two cross-fade, so a flight between different
/// pictures (a product cover → the chosen colour's photo) stays smooth.
Widget appImageFlightShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final fromHero = fromHeroContext.widget as Hero;
  final toHero = toHeroContext.widget as Hero;
  final dpr = MediaQuery.devicePixelRatioOf(flightContext);

  Widget frozen(BuildContext heroContext, Widget child) {
    if (child is! AppImage) return child;
    final box = heroContext.findRenderObject();
    final width = box is RenderBox && box.hasSize ? box.size.width : null;
    if (width == null || child.cacheWidth != null) return child;
    return AppImage(
      child.url,
      fit: child.fit,
      borderRadius: child.borderRadius,
      background: child.background,
      fallbackIcon: child.fallbackIcon,
      cacheWidth: AppImage.decodeWidth(width * dpr),
    );
  }

  // `animation` runs 0 → 1 on push and 1 → 0 on pop; the "to" side of a
  // push is the page being opened.
  final pushed = direction == HeroFlightDirection.push;
  final bottom = frozen(pushed ? fromHeroContext : toHeroContext, pushed ? fromHero.child : toHero.child);
  final top = frozen(pushed ? toHeroContext : fromHeroContext, pushed ? toHero.child : fromHero.child);
  return Stack(
    fit: StackFit.expand,
    children: [
      bottom,
      FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.6)),
        child: top,
      ),
    ],
  );
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(child: Icon(icon, color: context.colors.inkSubtle, size: 28));
  }
}
