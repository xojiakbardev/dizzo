import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/widgets/widgets.dart';

/// The site's privacy policy in [lang]: `/privacy` (Uzbek), `/ru/privacy`,
/// `/en/privacy`.
Uri privacyPolicyUri(AppLanguage lang) =>
    Uri.parse('${Env.siteUrl}${lang == AppLanguage.uz ? '' : '/${lang.code}'}/privacy');

/// Opens the privacy policy in the current language in the browser.
Future<void> openPrivacyPolicy(BuildContext context, WidgetRef ref) async {
  final uri = privacyPolicyUri(ref.read(appLanguageProvider));
  final failed = context.l10n.profileLinkOpenFailed;
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) showAppSnack(context, failed, error: true);
}

/// "Maxfiylik siyosati" row for the profile screen.
class PrivacyPolicyTile extends ConsumerWidget {
  const PrivacyPolicyTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return ListTile(
      key: const ValueKey('privacy-tile'),
      leading: Icon(Icons.privacy_tip_outlined, color: c.ink),
      title: Text(context.l10n.profilePrivacyPolicy, style: context.text.titleSmall),
      trailing: const Icon(Icons.open_in_new_rounded, size: 20),
      shape: const RoundedRectangleBorder(borderRadius: Radii.brLg),
      onTap: () => openPrivacyPolicy(context, ref),
    );
  }
}

/// "By continuing you accept the privacy policy", under sign-in forms.
class PrivacyNotice extends ConsumerStatefulWidget {
  const PrivacyNotice({super.key});

  @override
  ConsumerState<PrivacyNotice> createState() => _PrivacyNoticeState();
}

class _PrivacyNoticeState extends ConsumerState<PrivacyNotice> {
  late final _tap = TapGestureRecognizer()..onTap = () => openPrivacyPolicy(context, ref);

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      link: true,
      child: Text.rich(
        TextSpan(
          text: context.l10n.authPrivacyNotice,
          recognizer: _tap,
          style: context.text.bodySmall?.copyWith(
            color: c.inkMuted,
            decoration: TextDecoration.underline,
            decorationColor: c.inkMuted,
          ),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
