import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/widgets/widgets.dart';

/// Opens the language sheet (O‘zbekcha / Русский / English). The choice
/// applies at once, is saved on the device and, when signed in, on the
/// profile.
Future<void> showLanguageSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context,
    title: context.l10n.languageChoose,
    builder: (_) => const LanguageOptions(),
  );
}

/// The three languages as a radio list.
class LanguageOptions extends ConsumerWidget {
  const LanguageOptions({super.key, this.popOnSelect = true});

  /// Closes the sheet after a choice.
  final bool popOnSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appLanguageProvider);
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final lang in AppLanguage.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: Material(
              color: lang == current ? c.brand.withValues(alpha: 0.08) : c.surface,
              shape: RoundedRectangleBorder(
                borderRadius: Radii.brLg,
                side: BorderSide(color: lang == current ? c.brand : c.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: ValueKey('language-${lang.code}'),
                title: Text(lang.nativeName, style: context.text.titleSmall),
                trailing: lang == current
                    ? Icon(Icons.check_circle_rounded, color: c.brand)
                    : Icon(Icons.circle_outlined, color: c.inkSubtle),
                selected: lang == current,
                onTap: () async {
                  unawaited(HapticFeedback.selectionClick());
                  final navigator = Navigator.of(context);
                  await ref.read(appLanguageProvider.notifier).select(lang);
                  if (popOnSelect && navigator.canPop()) navigator.pop();
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// A list row: "Til · O‘zbekcha", opens [showLanguageSheet].
class LanguageTile extends ConsumerWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appLanguageProvider);
    final c = context.colors;
    return ListTile(
      key: const ValueKey('language-tile'),
      leading: Icon(Icons.language_rounded, color: c.ink),
      title: Text(context.l10n.languageTitle, style: context.text.titleSmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(current.nativeName, style: context.text.bodyMedium?.copyWith(color: c.inkMuted)),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      shape: const RoundedRectangleBorder(borderRadius: Radii.brLg),
      onTap: () => showLanguageSheet(context),
    );
  }
}

/// A compact button for app bars and the welcome screen: globe + the
/// current language's name.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appLanguageProvider);
    return TextButton.icon(
      key: const ValueKey('language-button'),
      onPressed: () => showLanguageSheet(context),
      icon: const Icon(Icons.language_rounded, size: 20),
      label: Text(current.nativeName),
    );
  }
}
