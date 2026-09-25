import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/widgets.dart';
import '../../settings/presentation/privacy_policy.dart';
import '../data/google_auth.dart';
import 'auth_controller.dart';
import 'brand_logos.dart';
import 'telegram_login_sheet.dart';

enum _Mode { options, login, register }

/// Every sign-in method in one block: Google, Telegram, then email (login /
/// register), with the privacy policy link below. Used by the welcome screen and the login sheet; the parent
/// reacts to [authControllerProvider] turning [Authenticated].
class LoginPanel extends ConsumerStatefulWidget {
  const LoginPanel({super.key});

  @override
  ConsumerState<LoginPanel> createState() => _LoginPanelState();
}

class _LoginPanelState extends ConsumerState<LoginPanel> {
  _Mode _mode = _Mode.options;
  String? _busy; // 'google' | 'telegram'

  Future<void> _google() async {
    setState(() => _busy = 'google');
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _telegram() async {
    setState(() => _busy = 'telegram');
    try {
      await showTelegramLogin(context);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _methods(),
        Gap.lg,
        const PrivacyNotice(),
      ],
    );
  }

  Widget _methods() {
    return AnimatedSize(
      duration: Motion.normal,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: Motion.normal,
        child: switch (_mode) {
          _Mode.options => _options(context),
          _Mode.login || _Mode.register => EmailAuthForm(
              key: ValueKey(_mode),
              register: _mode == _Mode.register,
              onSwitchMode: () => setState(
                () => _mode = _mode == _Mode.login ? _Mode.register : _Mode.login,
              ),
              onBack: () => setState(() => _mode = _Mode.options),
            ),
        },
      ),
    );
  }

  Widget _options(BuildContext context) {
    final disabled = _busy != null;
    return Column(
      key: const ValueKey('options'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ref.watch(googleAuthProvider).isAvailable) ...[
          AppButton.outline(
            label: context.l10n.authSignInGoogle,
            icon: const GoogleLogo(),
            loading: _busy == 'google',
            onPressed: disabled ? null : _google,
          ),
          Gap.md,
        ],
        AppButton.outline(
          label: context.l10n.authSignInTelegram,
          icon: const TelegramLogo(),
          loading: _busy == 'telegram',
          onPressed: disabled ? null : _telegram,
        ),
        Gap.lg,
        const _OrDivider(),
        Gap.lg,
        AppButton(
          label: context.l10n.authSignInEmail,
          variant: AppButtonVariant.secondary,
          icon: const Icon(Icons.mail_outline_rounded),
          onPressed: disabled ? null : () => setState(() => _mode = _Mode.login),
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Text(context.l10n.authOr, style: context.text.bodySmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// Email + password: sign in, or create an account.
class EmailAuthForm extends ConsumerStatefulWidget {
  const EmailAuthForm({
    super.key,
    required this.register,
    required this.onSwitchMode,
    this.onBack,
  });

  final bool register;
  final VoidCallback onSwitchMode;
  final VoidCallback? onBack;

  @override
  ConsumerState<EmailAuthForm> createState() => _EmailAuthFormState();
}

class _EmailAuthFormState extends ConsumerState<EmailAuthForm> {
  final _form = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  Map<String, String> _serverErrors = const {};

  @override
  void dispose() {
    _firstName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = const {});
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final auth = ref.read(authControllerProvider.notifier);
    try {
      if (widget.register) {
        await auth.register(
          firstName: _firstName.text,
          email: _email.text,
          password: _password.text,
        );
      } else {
        await auth.signInWithEmail(_email.text, _password.text);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      final fields = e.fieldErrors;
      if (fields.isNotEmpty) {
        setState(() => _serverErrors = fields);
        _form.currentState?.validate();
      } else {
        showAppSnack(context, e.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _server(String field) => _serverErrors[field];

  @override
  Widget build(BuildContext context) {
    final register = widget.register;
    final l = context.l10n;
    return Form(
      key: _form,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (widget.onBack != null)
                  IconButton(
                    tooltip: context.l10n.commonBack,
                    onPressed: _busy ? null : widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Expanded(
                  child: Text(
                    register ? l.authRegisterTitle : l.authSignInEmail,
                    style: context.text.titleMedium,
                  ),
                ),
              ],
            ),
            Gap.md,
            if (register) ...[
              TextFormField(
                controller: _firstName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
                decoration: InputDecoration(labelText: l.authFirstName),
                validator: (v) => _server('first_name') ??
                    ((v ?? '').trim().isEmpty ? l.authFirstNameRequired : null),
              ),
              Gap.md,
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: l.authEmail),
              validator: (v) {
                final server = _server('email');
                if (server != null) return server;
                final value = (v ?? '').trim();
                if (value.isEmpty) return l.authEmailRequired;
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                  return l.authEmailInvalid;
                }
                return null;
              },
            ),
            Gap.md,
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: [register ? AutofillHints.newPassword : AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l.authPassword,
                suffixIcon: IconButton(
                  tooltip: _obscure ? l.authPasswordShow : l.authPasswordHide,
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
              validator: (v) {
                final server = _server('password');
                if (server != null) return server;
                final value = v ?? '';
                if (value.isEmpty) return l.authPasswordRequired;
                if (register && value.length < 8) return l.authPasswordTooShort(8);
                return null;
              },
            ),
            Gap.lg,
            AppButton(
              label: register ? l.authRegisterSubmit : l.authSignIn,
              loading: _busy,
              onPressed: _submit,
            ),
            Gap.xs,
            AppButton(
              variant: AppButtonVariant.ghost,
              label: register ? l.authHaveAccount : l.authRegisterSwitch,
              onPressed: _busy ? null : widget.onSwitchMode,
            ),
          ],
        ),
      ),
    );
  }
}
