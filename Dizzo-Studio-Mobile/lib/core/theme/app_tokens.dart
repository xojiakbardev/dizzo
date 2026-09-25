import 'package:flutter/widgets.dart';

/// Spacing scale on a 4-pt grid.
abstract final class Insets {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Corner radii.
abstract final class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  static const brSm = BorderRadius.all(Radius.circular(sm));
  static const brMd = BorderRadius.all(Radius.circular(md));
  static const brLg = BorderRadius.all(Radius.circular(lg));
  static const brXl = BorderRadius.all(Radius.circular(xl));
}

/// Motion durations.
abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
}

/// A square gap that works in both [Row] and [Column].
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});

  final double size;

  static const xs = Gap(Insets.xs);
  static const sm = Gap(Insets.sm);
  static const md = Gap(Insets.md);
  static const lg = Gap(Insets.lg);
  static const xl = Gap(Insets.xl);
  static const xxl = Gap(Insets.xxl);

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}
