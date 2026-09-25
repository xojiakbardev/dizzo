import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../theme/app_colors.dart';

/// The Dizzo mark as the big loading animation — a port of the site's
/// `BrandLoader.vue`: the mark stays in view and breathes (a soft squash and
/// lift every 2 s), the corner flaps, the three sparks light up in turn and
/// the eye blinks every other breath — one seamless loop.
///
/// With reduced motion the mark stays still and only its sparks fade in turn.
class BrandLoader extends StatefulWidget {
  const BrandLoader({super.key, this.size = 72});

  final double size;

  @override
  State<BrandLoader> createState() => _BrandLoaderState();
}

class _BrandLoaderState extends State<BrandLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _loop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: the mark stays still and only the sparks fade up in
    // turn, so it still reads as loading.
    _calm = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_c.isAnimating) _c.repeat();
  }

  bool _calm = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.commonLoading,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(painter: _LoaderPainter(_c, calm: _calm)),
        ),
      ),
    );
  }
}

/// A full-screen brand loader on the app background.
class BrandLoaderScreen extends StatelessWidget {
  const BrandLoaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: const Center(child: BrandLoader(size: 88)),
    );
  }
}

// ── Geometry (SVG user units, viewBox 40 40 800 820) ────────────────────────

const _bodyD =
    'M129.6,154.0Q122.2,158.0 114.1,167.1Q106.0,176.2 102.5,185.6Q99.0,195.0 99.0,367.9Q99.0,540.8 103.5,566.1Q108.0,591.5 113.5,608.0Q119.0,624.5 128.0,643.5Q137.0,662.5 149.5,681.5Q162.0,700.5 169.5,709.5Q177.0,718.5 189.1,730.6Q201.2,742.8 213.8,752.8Q226.2,762.8 239.2,771.2Q252.2,779.8 266.8,787.2Q281.2,794.8 293.6,799.8Q306.0,804.8 323.0,809.8Q340.0,814.8 356.0,817.8Q372.0,820.8 383.0,821.8Q394.0,822.8 415.4,822.8Q436.8,822.8 450.8,821.2Q464.8,819.8 478.8,816.8Q492.8,813.8 508.6,808.8Q524.5,803.8 537.0,798.2Q549.5,792.8 560.5,786.8Q571.5,780.8 587.0,770.2Q602.5,759.8 613.0,750.8Q623.5,741.8 633.6,731.1Q643.8,720.5 653.2,708.5Q662.8,696.5 672.8,680.0Q682.8,663.5 690.2,647.0Q697.8,630.5 701.8,618.1Q705.8,605.8 709.8,584.8Q713.8,563.8 713.8,551.9Q713.8,540.0 710.8,531.6Q707.8,523.2 700.1,514.6Q692.5,506.0 683.1,502.0Q673.8,498.0 661.5,498.5Q649.2,499.0 642.1,502.1Q635.0,505.2 629.5,509.8Q624.0,514.2 619.0,521.2Q614.0,528.2 608.0,539.6Q602.0,551.0 592.5,564.2Q583.0,577.5 574.2,587.2Q565.5,597.0 552.5,607.6Q539.5,618.2 530.1,622.8Q520.8,627.2 514.6,627.6Q508.5,628.0 505.2,627.6Q502.0,627.2 498.9,625.5Q495.8,623.8 490.2,617.9Q484.8,612.0 482.2,603.9Q479.8,595.8 479.5,394.4Q479.2,193.0 477.5,185.2Q475.8,177.5 472.4,171.6Q469.0,165.8 465.8,162.1Q462.5,158.5 455.5,154.2Q448.5,150.0 438.6,148.4Q428.8,146.8 291.6,146.8Q154.5,146.8 145.8,148.4Q137.0,150.0 129.6,154.0Z';

const _mouthD =
    'M278.1,644.0Q276.2,635.8 278.8,628.1Q281.2,620.5 286.0,615.8Q290.8,611.0 295.8,608.9Q300.8,606.8 308.9,606.8Q317.0,606.8 321.1,608.5Q325.2,610.2 328.9,613.4Q332.5,616.5 338.4,625.0Q344.2,633.5 352.2,642.2Q360.2,651.0 375.5,662.4Q390.8,673.8 409.6,682.1Q428.5,690.5 441.1,693.5Q453.8,696.5 464.8,697.6Q475.8,698.8 494.0,697.9Q512.2,697.0 529.4,692.9Q546.5,688.8 564.2,680.4Q582.0,672.0 597.2,660.4Q612.5,648.8 614.1,648.8Q615.8,648.8 616.6,650.6Q617.5,652.5 609.8,664.4Q602.0,676.2 593.4,685.6Q584.8,695.0 576.0,702.4Q567.2,709.8 556.2,716.8Q545.2,723.8 533.0,729.4Q520.8,735.0 507.0,738.9Q493.2,742.8 478.2,744.6Q463.2,746.5 452.9,746.5Q442.5,746.5 426.1,744.4Q409.8,742.2 396.8,738.6Q383.8,735.0 371.9,729.9Q360.0,724.8 347.8,717.5Q335.5,710.2 324.8,701.6Q314.0,693.0 304.4,682.9Q294.8,672.8 287.4,662.5Q280.0,652.2 278.1,644.0Z';

const _foldD =
    'M464.5,158.0Q459.2,156.0 466.2,163.9Q473.2,171.8 476.1,180.0Q479.0,188.2 479.5,285.9Q480.0,383.5 485.9,392.2Q491.8,401.0 497.1,404.8Q502.5,408.5 508.9,410.6Q515.2,412.8 606.8,412.8Q698.2,412.8 701.8,410.6Q705.2,408.5 707.0,405.9Q708.8,403.2 708.8,399.9Q708.8,396.5 707.6,394.2Q706.5,392.0 593.5,279.5Q480.5,167.0 475.1,163.5Q469.8,160.0 464.5,158.0Z';

const _eyeCenter = Offset(311.5, 499.5);
const _eyeRadius = 37.1;

class _Spark {
  const _Spark(this.from, this.to, this.width);
  final Offset from;
  final Offset to;
  final double width;
}

const _sparks = [
  _Spark(Offset(618.5, 160.2), Offset(618.5, 93.5), 39.0),
  _Spark(Offset(681.4, 190.4), Offset(736.9, 134.9), 40.3),
  _Spark(Offset(713.2, 249.0), Offset(779.5, 249.0), 38.5),
];

/// Parses the subset of SVG path data the mark uses (M, Q, L, Z; absolute).
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(r'[MQLZmqlz]|-?\d*\.?\d+').allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var cmd = 'M';
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final t = tokens[i];
    if (RegExp(r'^[A-Za-z]$').hasMatch(t)) {
      cmd = t.toUpperCase();
      i++;
      if (cmd == 'Z') {
        path.close();
        continue;
      }
    }
    switch (cmd) {
      case 'M':
        path.moveTo(n(), n());
        cmd = 'L';
      case 'L':
        path.lineTo(n(), n());
      case 'Q':
        path.quadraticBezierTo(n(), n(), n(), n());
      default:
        i++;
    }
  }
  return path;
}

final Path _body = parseSvgPath(_bodyD);
final Path _mouth = parseSvgPath(_mouthD);
final Path _fold = parseSvgPath(_foldD);

const _ease = Cubic(.4, 0, .2, 1);

const _loop = Duration(milliseconds: 4000);
const _breathEase = Cubic(.45, 0, .55, 1);
const _sparkEase = Cubic(.42, 0, .58, 1);
const _sparkDelay = .075; // 0.15 s of a 2 s breath

// Keyframes of one breath (same as BrandLoader.vue's dl-breathe / dl-flap).
const _breathX = [(0.0, 1.0), (.20, 1.04), (.45, .98), (.70, 1.02), (1.0, 1.0)];
const _breathY = [(0.0, 1.0), (.20, .95), (.45, 1.03), (.70, .98), (1.0, 1.0)];
const _breathLift = [(0.0, 0.0), (.20, 0.0), (.45, 45.0), (.70, 0.0), (1.0, 0.0)]; // 6% of the mark's height
const _flap = [(0.0, 0.0), (.45, 1.0), (1.0, 0.0)];

/// The value of eased keyframes at [t] (0..1).
double _keys(double t, List<(double, double)> keys) {
  for (var i = 1; i < keys.length; i++) {
    final (b, vb) = keys[i];
    if (t <= b) {
      final (a, va) = keys[i - 1];
      return _lerp(va, vb, _seg(t, a, b, _breathEase));
    }
  }
  return keys.last.$2;
}

/// Progress of [t] through [a]..[b], eased, clamped to 0..1.
double _seg(double t, double a, double b, [Curve curve = _ease]) {
  if (t <= a) return 0;
  if (t >= b) return 1;
  return curve.transform((t - a) / (b - a));
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// The face (body minus eye and smile) for an eye opened by [wink] (0..1).
/// Path boolean operations are slow, so the shapes are built once per
/// eye step (the eye is fully open for 92% of the loop) instead of on
/// every frame.
final _faces = <int, Path>{};
const _winkSteps = 24;

Path _faceFor(double wink) {
  final step = (wink.clamp(0.0, 1.0) * _winkSteps).round();
  return _faces.putIfAbsent(step, () {
    final eye = Path()
      ..addOval(Rect.fromCenter(
        center: _eyeCenter,
        width: _eyeRadius * 2,
        height: _eyeRadius * 2 * step / _winkSteps,
      ));
    final holes = Path.combine(PathOperation.union, eye, _mouth);
    return Path.combine(PathOperation.difference, _body, holes);
  });
}

class _LoaderPainter extends CustomPainter {
  _LoaderPainter(this.animation, {this.calm = false}) : super(repaint: animation);

  /// Reduced motion: a still mark, the sparks' opacity alone changes.
  final bool calm;

  /// 0..1 over [_loop]: two breaths, one blink.
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final beat = (t * 2) % 1; // one breath
    const viewX = 40.0, viewY = 40.0, viewW = 800.0, viewH = 820.0;
    final scale = math.min(size.width / viewW, size.height / viewH);
    canvas.save();
    canvas.translate(
      (size.width - viewW * scale) / 2 - viewX * scale,
      (size.height - viewH * scale) / 2 - viewY * scale,
    );
    canvas.scale(scale);

    if (calm) {
      canvas.drawPath(_faceFor(1), Paint()..color = BrandColors.orange);
      canvas.drawPath(_fold, Paint()..color = BrandColors.amber);
      final phase = (t * 2) % 1; // the site's 2 s `dl-glow`, twice a loop
      for (var i = 0; i < _sparks.length; i++) {
        final s = _sparks[i];
        final u = (phase - i * .15) % 1; // .3 s apart
        // .2 → 1 at 35 % → .2 at 70 %, eased (as `dl-glow`).
        final k = u < .35 ? Curves.easeInOut.transform(u / .35) : u < .7 ? 1 - Curves.easeInOut.transform((u - .35) / .35) : 0.0;
        canvas.drawLine(
          s.from,
          s.to,
          Paint()
            ..color = BrandColors.amber.withValues(alpha: .2 + .8 * k)
            ..strokeWidth = s.width
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.restore();
      return;
    }

    // Whole mark: squashes, lifts and settles from its base.
    final sx = _keys(beat, _breathX), sy = _keys(beat, _breathY), lift = _keys(beat, _breathLift);
    const origin = Offset(439.25, 842.05); // bottom centre of the group's box
    canvas.translate(origin.dx, origin.dy - lift);
    canvas.scale(sx, sy);
    canvas.translate(-origin.dx, -origin.dy);

    // The face: body minus the (blinking) eye and the smile.
    final wink = t < .83 ? _lerp(1, .08, _seg(t, .80, .83)) : _lerp(.08, 1, _seg(t, .83, .86));
    canvas.drawPath(_faceFor(wink), Paint()..color = BrandColors.orange);

    // The folded corner flaps up with each breath.
    final flap = _keys(beat, _flap);
    const pivot = Offset(459.2, 412.8); // the fold's bottom-left corner
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(-8 * flap * math.pi / 180);
    canvas.scale(1 + .06 * flap);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawPath(_fold, Paint()..color = BrandColors.amber);
    canvas.restore();

    // Sparks draw outward, hold, then leave from the base, one after another.
    for (var i = 0; i < _sparks.length; i++) {
      final s = _sparks[i];
      final u = (beat - i * _sparkDelay) % 1;
      final double from, to, opacity;
      if (u < .15 || u >= .9) {
        continue;
      } else if (u < .40) {
        final p = _seg(u, .15, .40, _sparkEase);
        from = 0;
        to = p;
        opacity = p;
      } else if (u < .65) {
        from = 0;
        to = 1;
        opacity = 1;
      } else {
        final p = _seg(u, .65, .90, _sparkEase);
        from = p;
        to = 1;
        opacity = 1 - p;
      }
      if (to <= from || opacity <= 0) continue;
      canvas.drawLine(
        Offset.lerp(s.from, s.to, from)!,
        Offset.lerp(s.from, s.to, to)!,
        Paint()
          ..color = BrandColors.amber.withValues(alpha: opacity)
          ..strokeWidth = s.width
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LoaderPainter oldDelegate) => oldDelegate.animation != animation || oldDelegate.calm != calm;
}
