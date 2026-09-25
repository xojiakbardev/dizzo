import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/widgets.dart';
import '../data/auth_api.dart';
import '../data/telegram_native_login.dart';
import 'auth_controller.dart';
import 'brand_logos.dart';

/// Telegram sign-in through the official "Log in with Telegram" SDK: it
/// opens Telegram (or, when Telegram isn't installed, its own browser
/// sheet), returns an id token, and the app exchanges it at
/// `POST /auth/oauth/telegram-oidc/`.
///
/// Resolves to true once signed in.
Future<bool> showTelegramLogin(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => const TelegramLoginSheet(),
  );
  return ok ?? false;
}

enum _Phase { waiting, verifying, failed }

class TelegramLoginSheet extends ConsumerStatefulWidget {
  const TelegramLoginSheet({super.key});

  @override
  ConsumerState<TelegramLoginSheet> createState() => _TelegramLoginSheetState();
}

class _TelegramLoginSheetState extends ConsumerState<TelegramLoginSheet> {
  _Phase _phase = _Phase.waiting;
  /// Null: the generic "couldn't sign in" title.
  String? _error;

  /// Bumped on every attempt, so a superseded one is ignored.
  int _attempt = 0;
  late final TelegramNativeLogin _login = ref.read(telegramNativeLoginProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    if (_phase == _Phase.waiting) unawaited(_login.cancel());
    super.dispose();
  }

  Future<void> _start() async {
    final attempt = ++_attempt;
    setState(() => _phase = _Phase.waiting);
    try {
      final idToken = await _login.signIn();
      if (!mounted || attempt != _attempt) return;
      if (idToken == null) {
        _close(false);
        return;
      }
      setState(() => _phase = _Phase.verifying);
      final result = await ref.read(authApiProvider).telegramOidc(idToken);
      if (!mounted || attempt != _attempt) return;
      await ref.read(authControllerProvider.notifier).completeSignIn(result);
      _close(true);
    } on TelegramNativeError {
      if (mounted && attempt == _attempt) _fail(null);
    } on ApiException catch (e) {
      if (mounted && attempt == _attempt) _fail(e.isNetwork ? e.message : null);
    }
  }

  void _fail(String? message) {
    setState(() {
      _phase = _Phase.failed;
      _error = message;
    });
  }

  void _close(bool signedIn) {
    // A parent login sheet may already have closed this one.
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      Navigator.of(context).pop(signedIn);
    }
  }

  void _cancel() {
    _attempt++;
    if (_phase == _Phase.waiting) unawaited(_login.cancel());
    _phase = _Phase.failed; // nothing left to cancel in dispose
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = switch (_phase) {
      _Phase.waiting => context.l10n.authTelegramConfirm,
      _Phase.verifying => context.l10n.authTelegramVerifying,
      _Phase.failed => _error ?? context.l10n.authTelegramFailed,
    };
    final busy = _phase != _Phase.failed;
    return AppSheet(
      showClose: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Gap.sm,
          Center(
            child: SizedBox.square(
              dimension: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (busy)
                    SizedBox.square(
                      dimension: 88,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: TelegramLogo.brandColor,
                        backgroundColor: c.plate,
                      ),
                    ),
                  const TelegramLogo(size: 56),
                ],
              ),
            ),
          ),
          Gap.xl,
          Text(title, textAlign: TextAlign.center, style: context.text.titleLarge),
          Gap.xl,
          if (_phase == _Phase.waiting)
            AppButton(
              label: context.l10n.authTelegramReopen,
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: _start,
            )
          else if (_phase == _Phase.failed)
            AppButton(
              label: context.l10n.commonRetry,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _start,
            ),
          Gap.sm,
          AppButton(
            label: context.l10n.commonCancel,
            variant: AppButtonVariant.ghost,
            onPressed: _phase == _Phase.verifying ? null : _cancel,
          ),
        ],
      ),
    );
  }
}
