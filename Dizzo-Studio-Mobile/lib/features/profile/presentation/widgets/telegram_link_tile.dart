import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/profile_api.dart';

/// Telegram order notifications: opens the bot's one-time link, then polls
/// the profile until the account is linked (as the web's ProfileSettings).
class TelegramLinkTile extends ConsumerStatefulWidget {
  const TelegramLinkTile({super.key});

  @override
  ConsumerState<TelegramLinkTile> createState() => _TelegramLinkTileState();
}

class _TelegramLinkTileState extends ConsumerState<TelegramLinkTile> with WidgetsBindingObserver {
  static const _pollEvery = Duration(seconds: 3);
  static const _waitAtMost = Duration(seconds: 90);

  Timer? _timer;
  DateTime? _startedAt;
  String? _before;
  String? _link;
  bool _starting = false;
  bool _polling = false;

  bool get _waiting => _timer != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waiting) unawaited(_poll());
  }

  Future<void> _start() async {
    if (_waiting) {
      if (_link != null) await _open(_link!);
      return;
    }
    setState(() => _starting = true);
    try {
      final api = ref.read(profileApiProvider);
      final before = await api.me();
      final ticket = await api.telegramLinkToken();
      if (!mounted) return;
      if (ticket.deepLink == null) {
        showAppSnack(context, context.l10n.profileTelegramNotConfigured, error: true);
        return;
      }
      _before = before.telegramLinkedAt;
      _link = ticket.deepLink;
      _startedAt = DateTime.now();
      _timer = Timer.periodic(_pollEvery, (_) => _poll());
      await _open(ticket.deepLink!);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _open(String link) async {
    final ok = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showAppSnack(context, context.l10n.profileTelegramOpenFailed, error: true);
  }

  void _stop() {
    _timer?.cancel();
    if (mounted) setState(() => _timer = null);
  }

  Future<void> _poll() async {
    if (_polling || !_waiting) return;
    _polling = true;
    try {
      final profile = await ref.read(profileApiProvider).me();
      if (!mounted) return;
      if (profile.user.telegramLinked && profile.telegramLinkedAt != _before) {
        _stop();
        await ref.read(authControllerProvider.notifier).updateUser(profile.user);
        if (mounted) showAppSnack(context, context.l10n.profileTelegramConnected);
      } else if (DateTime.now().difference(_startedAt!) > _waitAtMost) {
        _stop();
        showAppSnack(context, context.l10n.profileTelegramNotConfirmed, error: true);
      }
    } on ApiException {
      // Try again on the next tick.
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final linked = ref.watch(currentUserProvider.select((u) => u?.telegramLinked ?? false));
    final l = context.l10n;
    final subtitle = _waiting ? l.profileTelegramWaiting : (linked ? l.profileTelegramLinked : l.profileTelegramUnlinked);
    return ListTile(
      leading: Icon(Icons.send_rounded, color: linked ? c.success : c.ink),
      title: Text(l.profileTelegramTitle, style: context.text.titleSmall),
      subtitle: Text(subtitle, style: context.text.bodySmall?.copyWith(color: linked && !_waiting ? c.success : c.inkMuted)),
      shape: const RoundedRectangleBorder(borderRadius: Radii.brLg),
      onTap: _starting ? null : _start,
      trailing: _starting || _waiting
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                if (_waiting)
                  IconButton(tooltip: l.commonCancel, onPressed: _stop, icon: const Icon(Icons.close_rounded)),
              ],
            )
          : Text(
              linked ? l.profileTelegramRelink : l.profileTelegramLink,
              style: context.text.labelLarge?.copyWith(color: c.brandStrong),
            ),
    );
  }
}
