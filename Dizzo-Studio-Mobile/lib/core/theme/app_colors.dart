import 'package:flutter/material.dart';

/// Brand palette. Features read colours through [DizzoColors]
/// (`context.colors`) or the Material [ColorScheme], never raw hex values.
abstract final class BrandColors {
  static const orange = Color(0xFFED5124);
  static const amber = Color(0xFFF99517);

  /// The orange that carries white text with AA contrast (the site's CTA).
  static const orangeDeep = Color(0xFFD24419);
  static const ink = Color(0xFF111827);
}

/// Design tokens beyond the Material [ColorScheme]: the warm plate products
/// sit on, hairlines, muted text, statuses, skeleton colours.
@immutable
class DizzoColors extends ThemeExtension<DizzoColors> {
  const DizzoColors({
    required this.brand,
    required this.brandStrong,
    required this.accent,
    required this.ink,
    required this.inkMuted,
    required this.inkSubtle,
    required this.background,
    required this.surface,
    required this.plate,
    required this.line,
    required this.success,
    required this.warning,
    required this.danger,
    required this.skeletonBase,
    required this.skeletonHighlight,
  });

  /// The logo orange: accents, icons, badges, prices.
  final Color brand;

  /// Filled buttons with white text.
  final Color brandStrong;
  final Color accent;
  final Color ink;
  final Color inkMuted;
  final Color inkSubtle;
  final Color background;
  final Color surface;
  final Color plate;
  final Color line;
  final Color success;
  final Color warning;
  final Color danger;
  final Color skeletonBase;
  final Color skeletonHighlight;

  static const light = DizzoColors(
    brand: BrandColors.orange,
    brandStrong: BrandColors.orangeDeep,
    accent: BrandColors.amber,
    ink: BrandColors.ink,
    inkMuted: Color(0xFF4B5563),
    inkSubtle: Color(0xFF9CA3AF),
    background: Color(0xFFFBF9F8),
    surface: Color(0xFFFFFFFF),
    plate: Color(0xFFF3EEE9),
    line: Color(0xFFEBE3DC),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    skeletonBase: Color(0xFFEFEAE6),
    skeletonHighlight: Color(0xFFFAF7F5),
  );

  static const dark = DizzoColors(
    brand: Color(0xFFFF6A3D),
    brandStrong: BrandColors.orange,
    accent: Color(0xFFFBA83A),
    ink: Color(0xFFF3F4F6),
    inkMuted: Color(0xFFB6BCC6),
    inkSubtle: Color(0xFF6B7280),
    background: Color(0xFF0E1116),
    surface: Color(0xFF171B22),
    plate: Color(0xFF20252E),
    line: Color(0xFF2A303A),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFF87171),
    skeletonBase: Color(0xFF1F242C),
    skeletonHighlight: Color(0xFF2B313B),
  );

  @override
  DizzoColors copyWith({
    Color? brand,
    Color? brandStrong,
    Color? accent,
    Color? ink,
    Color? inkMuted,
    Color? inkSubtle,
    Color? background,
    Color? surface,
    Color? plate,
    Color? line,
    Color? success,
    Color? warning,
    Color? danger,
    Color? skeletonBase,
    Color? skeletonHighlight,
  }) {
    return DizzoColors(
      brand: brand ?? this.brand,
      brandStrong: brandStrong ?? this.brandStrong,
      accent: accent ?? this.accent,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkSubtle: inkSubtle ?? this.inkSubtle,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      plate: plate ?? this.plate,
      line: line ?? this.line,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
    );
  }

  @override
  DizzoColors lerp(DizzoColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return DizzoColors(
      brand: l(brand, other.brand),
      brandStrong: l(brandStrong, other.brandStrong),
      accent: l(accent, other.accent),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      inkSubtle: l(inkSubtle, other.inkSubtle),
      background: l(background, other.background),
      surface: l(surface, other.surface),
      plate: l(plate, other.plate),
      line: l(line, other.line),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      skeletonBase: l(skeletonBase, other.skeletonBase),
      skeletonHighlight: l(skeletonHighlight, other.skeletonHighlight),
    );
  }
}

extension DizzoThemeContext on BuildContext {
  DizzoColors get colors =>
      Theme.of(this).extension<DizzoColors>() ?? DizzoColors.light;
  TextTheme get text => Theme.of(this).textTheme;
}
