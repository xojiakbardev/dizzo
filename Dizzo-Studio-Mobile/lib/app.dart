import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_language.dart';
import 'core/l10n/locale_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class DizzoApp extends ConsumerWidget {
  const DizzoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // A language switch rebuilds the whole app in the new locale.
    final language = ref.watch(appLanguageProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Light first; switch to ThemeMode.system once dark screens are reviewed.
      themeMode: ThemeMode.light,
      routerConfig: router,
      locale: language.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      // Material/Cupertino/Widgets localizations cover uz, ru and en.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) {
        // Respect the user's font size, but keep layouts intact on the
        // largest accessibility sizes.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.35),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
