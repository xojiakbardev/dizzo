import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// The bundled brand font (assets/fonts, weights 400–800).
const kFontFamily = 'PlusJakartaSans';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light, DizzoColors.light);
  static ThemeData get dark => _build(Brightness.dark, DizzoColors.dark);

  static ThemeData _build(Brightness brightness, DizzoColors c) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: BrandColors.orange,
      brightness: brightness,
    ).copyWith(
      primary: c.brandStrong,
      onPrimary: Colors.white,
      secondary: c.accent,
      onSecondary: BrandColors.ink,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkMuted,
      outline: c.line,
      outlineVariant: c.line,
      error: c.danger,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.background,
      surfaceContainer: c.plate,
      surfaceContainerHigh: c.plate,
      surfaceContainerHighest: c.plate,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: kFontFamily,
      scaffoldBackgroundColor: c.background,
      extensions: [c],
    );
    final text = _textTheme(base.textTheme, c);

    const buttonShape = RoundedRectangleBorder(borderRadius: Radii.brMd);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    const buttonText = TextStyle(
      fontFamily: kFontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    );

    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle:
            isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.brand.withValues(alpha: 0.14),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: kFontFamily,
            fontSize: 11.5,
            fontWeight:
                s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? c.ink : c.inkMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? c.brand : c.inkMuted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.brand.withValues(alpha: 0.14),
        selectedIconTheme: IconThemeData(color: c.brand),
        unselectedIconTheme: IconThemeData(color: c.inkMuted),
        selectedLabelTextStyle: text.labelMedium?.copyWith(color: c.ink),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(color: c.inkMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brandStrong,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.line,
          shape: buttonShape,
          padding: buttonPadding,
          minimumSize: const Size(64, 50),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: BorderSide(color: c.line, width: 1.2),
          shape: buttonShape,
          padding: buttonPadding,
          minimumSize: const Size(64, 50),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brandStrong,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: c.inkSubtle),
        border: OutlineInputBorder(
          borderRadius: Radii.brMd,
          borderSide: BorderSide(color: c.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.brMd,
          borderSide: BorderSide(color: c.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.brMd,
          borderSide: BorderSide(color: c.brand, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.brMd,
          borderSide: BorderSide(color: c.danger),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.ink,
        side: BorderSide(color: c.line),
        shape: const StadiumBorder(),
        labelStyle: text.labelLarge?.copyWith(color: c.ink),
        secondaryLabelStyle: text.labelLarge?.copyWith(color: c.surface),
        checkmarkColor: c.surface,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.brLg,
          side: BorderSide(color: c.line),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.line,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.brXl),
        titleTextStyle: text.titleLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.surface),
        shape: const RoundedRectangleBorder(borderRadius: Radii.brMd),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      badgeTheme: BadgeThemeData(
        backgroundColor: c.brand,
        textColor: Colors.white,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brand),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, DizzoColors c) {
    TextStyle s(double size, FontWeight w, {double? height, double ls = 0, Color? color}) =>
        TextStyle(
          fontFamily: kFontFamily,
          fontSize: size,
          fontWeight: w,
          height: height,
          letterSpacing: ls,
          color: color ?? c.ink,
        );
    return base.copyWith(
      displayLarge: s(44, FontWeight.w800, height: 1.08, ls: -1.2),
      displayMedium: s(36, FontWeight.w800, height: 1.1, ls: -1),
      displaySmall: s(30, FontWeight.w800, height: 1.12, ls: -0.8),
      headlineLarge: s(28, FontWeight.w800, height: 1.15, ls: -0.6),
      headlineMedium: s(24, FontWeight.w800, height: 1.2, ls: -0.4),
      headlineSmall: s(21, FontWeight.w700, height: 1.25, ls: -0.3),
      titleLarge: s(19, FontWeight.w700, height: 1.3, ls: -0.2),
      titleMedium: s(16, FontWeight.w700, height: 1.35),
      titleSmall: s(14, FontWeight.w700, height: 1.35),
      bodyLarge: s(16, FontWeight.w500, height: 1.5),
      bodyMedium: s(14, FontWeight.w500, height: 1.45),
      bodySmall: s(12.5, FontWeight.w500, height: 1.4, color: c.inkMuted),
      labelLarge: s(14, FontWeight.w600),
      labelMedium: s(12.5, FontWeight.w600),
      labelSmall: s(11, FontWeight.w600, ls: 0.2),
    );
  }
}
