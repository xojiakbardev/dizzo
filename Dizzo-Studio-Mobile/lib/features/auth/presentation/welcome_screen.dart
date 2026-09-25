import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/widgets/widgets.dart';
import '../../settings/presentation/language_picker.dart';
import 'auth_controller.dart';
import 'login_panel.dart';

/// First launch and `/login`: the logo, a headline, every sign-in method and
/// "Keyinroq" to browse as a guest. The router leaves this screen on its own
/// once the user is signed in.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key, this.from});

  /// Where to go after signing in (the router passes `?from=`).
  final String? from;

  Future<void> _skip(BuildContext context, WidgetRef ref) async {
    await ref.read(welcomeSeenProvider.notifier).markSeen();
    if (!context.mounted) return;
    final target = from;
    if (context.canPop()) {
      context.pop();
    } else if (target != null && !Routes.requiresAuth(Uri.parse(target).path)) {
      context.go(target);
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final pad = context.pagePadding + 4;
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final short = constraints.maxHeight < 640;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: Breakpoints.formMaxWidth),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // First launch: the language can be picked here.
                            const LanguageButton(),
                            TextButton(
                              onPressed: () => _skip(context, ref),
                              child: Text(context.l10n.authLater),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Image.asset(
                              'assets/brand/dizzo-mark.png',
                              width: short ? 88 : 120,
                              height: short ? 88 : 120,
                            ),
                            Gap(short ? Insets.lg : Insets.xl),
                            Text(
                              context.l10n.authWelcomeHeadline,
                              textAlign: TextAlign.center,
                              style: (short ? context.text.headlineMedium : context.text.headlineLarge)
                                  ?.copyWith(height: 1.15),
                            ),
                          ],
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: short ? Insets.lg : Insets.xxl),
                          child: const LoginPanel(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
