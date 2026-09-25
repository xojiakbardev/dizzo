import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cart/presentation/cart_badge.dart';
import '../../checkout/domain/uz_phone.dart';
import '../../settings/presentation/language_picker.dart';
import '../../settings/presentation/privacy_policy.dart';
import '../data/profile_api.dart';
import 'widgets/sign_in_prompt.dart';
import 'widgets/telegram_link_tile.dart';

/// "Profil" tab: the account, Telegram notifications, the account's
/// sections, the language, the privacy policy, sign-out, account deletion
/// and the app version.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final version = ref.watch(appVersionProvider).value;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.navProfile), actions: const [LanguageButton(), Gap.sm]),
        body: Column(
          children: [
            Expanded(
              child: SignInPrompt(icon: Icons.person_outline_rounded, title: context.l10n.authSignInTitle),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(context.pagePadding, 0, context.pagePadding, Insets.lg),
              child: const ContentWidth(
                maxWidth: Breakpoints.formMaxWidth + 120,
                child: _Group(children: [PrivacyPolicyTile()]),
              ),
            ),
          ],
        ),
      );
    }
    final cartCount = ref.watch(cartCountProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navProfile)),
      body: RefreshIndicator(
        onRefresh: () => ref.read(authControllerProvider.notifier).refreshUser(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(context.pagePadding, Insets.sm, context.pagePadding, Insets.xxl),
          children: [
            ContentWidth(
              maxWidth: Breakpoints.formMaxWidth + 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AccountCard(user: user, onEdit: () => showEditProfile(context, user)),
                  Gap.lg,
                  const _Group(children: [TelegramLinkTile()]),
                  Gap.lg,
                  _Group(
                    children: [
                      _Tile(
                        icon: Icons.receipt_long_outlined,
                        title: context.l10n.profileMyOrders,
                        onTap: () => context.push(Routes.orders),
                      ),
                      _Tile(
                        icon: Icons.brush_outlined,
                        title: context.l10n.navDesigns,
                        onTap: () => context.go(Routes.designs),
                      ),
                      _Tile(
                        icon: Icons.shopping_bag_outlined,
                        title: context.l10n.navCart,
                        badge: cartCount,
                        onTap: () => context.go(Routes.cart),
                      ),
                      _Tile(
                        icon: Icons.rate_review_outlined,
                        title: context.l10n.reviewsTitle,
                        onTap: () => context.push(Routes.reviews),
                      ),
                    ],
                  ),
                  Gap.lg,
                  const _Group(children: [LanguageTile(), PrivacyPolicyTile()]),
                  Gap.lg,
                  _Group(
                    children: [
                      _Tile(
                        icon: Icons.logout_rounded,
                        title: context.l10n.profileSignOut,
                        danger: true,
                        onTap: () async {
                          final ok = await confirmSheet(
                            context,
                            title: context.l10n.profileSignOutConfirm,
                            confirmLabel: context.l10n.profileSignOut,
                            destructive: true,
                          );
                          if (ok) await ref.read(authControllerProvider.notifier).logout();
                        },
                      ),
                    ],
                  ),
                  Gap.md,
                  Center(
                    child: TextButton(
                      key: const ValueKey('delete-account'),
                      style: TextButton.styleFrom(foregroundColor: context.colors.danger),
                      onPressed: () => confirmDeleteAccount(context),
                      child: Text(context.l10n.profileDeleteAccount),
                    ),
                  ),
                  if (version != null) ...[
                    Gap.xl,
                    Text(
                      'Dizzo $version',
                      textAlign: TextAlign.center,
                      style: context.text.labelMedium?.copyWith(color: context.colors.inkSubtle),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountCard extends StatelessWidget {
  const AccountCard({super.key, required this.user, required this.onEdit});

  final AppUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final contact = user.email ?? (user.phoneNumber.isEmpty ? null : UzPhone.format(user.phoneNumber));
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(color: c.surface, borderRadius: Radii.brXl, border: Border.all(color: c.line)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: c.brand.withValues(alpha: 0.14),
            foregroundColor: c.brand,
            child: user.avatar != null
                ? ClipOval(child: AppImage(user.avatar, width: 60, height: 60, fallbackIcon: Icons.person_rounded))
                : Text(user.initials, style: context.text.titleLarge?.copyWith(color: c.brand)),
          ),
          Gap.lg,
          Expanded(
            child: user.id == 0
                ? const SkeletonScope(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Skeleton.line(width: 140, height: 16), Gap(8), Skeleton.line(width: 110)],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName, style: context.text.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (contact != null)
                        Text(
                          contact,
                          style: context.text.bodySmall?.copyWith(color: c.inkMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (user.email != null && user.phoneNumber.isNotEmpty)
                        Text(
                          UzPhone.format(user.phoneNumber),
                          style: context.text.bodySmall?.copyWith(color: c.inkMuted),
                          maxLines: 1,
                        ),
                    ],
                  ),
          ),
          IconButton(
            tooltip: context.l10n.profileEdit,
            onPressed: user.id == 0 ? null : onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: Radii.brLg, border: Border.all(color: c.line)),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 56, color: c.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.onTap, this.danger = false, this.badge = 0});

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.colors.danger : context.colors.ink;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: context.text.titleSmall?.copyWith(color: color)),
      trailing: danger
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badge > 0) Badge.count(count: badge),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
      shape: const RoundedRectangleBorder(borderRadius: Radii.brLg),
      onTap: onTap,
    );
  }
}

/// Asks before deleting the account; the sheet runs the request. On success
/// the session is already gone: go home and say so.
Future<void> confirmDeleteAccount(BuildContext context) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final done = context.l10n.profileDeleteAccountDone;
  final deleted = await showAppBottomSheet<bool>(
    context,
    title: context.l10n.profileDeleteAccountTitle,
    builder: (_) => const DeleteAccountSheet(),
  );
  if (deleted != true) return;
  router.go(Routes.home);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(done)));
}

/// What deletion removes and keeps, then Cancel / Delete. Stays open (with
/// the error) if the server refuses.
class DeleteAccountSheet extends ConsumerStatefulWidget {
  const DeleteAccountSheet({super.key});

  @override
  ConsumerState<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<DeleteAccountSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _delete() async {
    final fallback = context.l10n.profileDeleteAccountFailed;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final detail = ApiException.detailMessage(e.data);
      setState(() {
        _busy = false;
        _error = detail ?? (e.isNetwork ? e.message : fallback);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = fallback;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    return PopScope(
      canPop: !_busy,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.profileDeleteAccountBody, style: context.text.bodyMedium?.copyWith(color: c.inkMuted)),
          if (_error != null) ...[
            Gap.md,
            Text(_error!, style: context.text.bodySmall?.copyWith(color: c.danger)),
          ],
          Gap.xl,
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                  child: Text(l.commonCancel),
                ),
              ),
              Gap.md,
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.danger,
                    disabledBackgroundColor: c.danger.withValues(alpha: 0.6),
                  ),
                  onPressed: _busy ? null : _delete,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(l.profileDeleteAccountSubmit),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Name and phone editor.
Future<void> showEditProfile(BuildContext context, AppUser user) async {
  final saved = await showAppBottomSheet<bool>(
    context,
    title: context.l10n.profileEditTitle,
    builder: (_) => EditProfileForm(user: user),
  );
  if (saved == true && context.mounted) showAppSnack(context, context.l10n.profileSaved);
}

class EditProfileForm extends ConsumerStatefulWidget {
  const EditProfileForm({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<EditProfileForm> {
  final _form = GlobalKey<FormState>();
  late final _first = TextEditingController(text: widget.user.firstName);
  late final _last = TextEditingController(text: widget.user.lastName);
  late final _phone = TextEditingController(
    text: widget.user.phoneNumber.isEmpty ? UzPhone.prefix : UzPhone.format(widget.user.phoneNumber),
  );
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final hasPhone = UzPhone.localDigits(_phone.text).isNotEmpty;
      final profile = await ref.read(profileApiProvider).update(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            phoneNumber: hasPhone ? UzPhone.format(_phone.text) : '',
          );
      await ref.read(authControllerProvider.notifier).updateUser(profile.user);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _fieldErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? e.message : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _first,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            maxLength: 150,
            decoration: InputDecoration(labelText: l.authFirstName, counterText: '', errorText: _fieldErrors['first_name']),
            validator: (v) => (v ?? '').trim().isEmpty ? l.authFirstNameRequired : null,
          ),
          Gap.md,
          TextFormField(
            controller: _last,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            maxLength: 150,
            decoration: InputDecoration(labelText: l.profileLastName, counterText: '', errorText: _fieldErrors['last_name']),
          ),
          Gap.md,
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: const [UzPhoneFormatter()],
            decoration: InputDecoration(labelText: l.profilePhone, errorText: _fieldErrors['phone_number']),
            validator: (v) {
              final d = UzPhone.localDigits(v ?? '');
              return d.isEmpty || d.length == 9 ? null : l.profilePhoneIncomplete;
            },
          ),
          if (_error != null) ...[
            Gap.md,
            Text(_error!, style: context.text.bodySmall?.copyWith(color: context.colors.danger)),
          ],
          Gap.xl,
          AppButton(label: l.commonSave, loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
