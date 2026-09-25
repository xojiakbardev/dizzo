import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/widgets/widgets.dart';
import '../../../catalog/domain/catalog_models.dart';
import '../../../catalog/presentation/widgets/option_pickers.dart';
import '../../data/engine_protocol.dart';
import '../../domain/design_document.dart';
import '../editor_controller.dart';
import '../editor_state.dart';

/// Edits a text layer's words with the keyboard; the canvas follows live.
Future<void> showTextEditSheet(BuildContext context, EditorController controller, EditorState state, String id) async {
  final l = state.doc.byId(id);
  final t = l?.text;
  if (l == null || t == null) return;
  controller.checkpoint();
  final text = TextEditingController(text: t.content.trim().isEmpty ? '' : t.content);
  text.selection = TextSelection(baseOffset: 0, extentOffset: text.text.length);
  await showAppBottomSheet<void>(
    context,
    title: context.l10n.editorSheetText,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: text,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          maxLength: 500,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) => controller.setTextSource(id, t.copyWith(content: v), record: false),
        ),
        Gap.sm,
        AppButton(label: context.l10n.commonDone, onPressed: () => Navigator.of(context).pop()),
      ],
    ),
  );
  text.dispose();
}

/// Type (with its description), colour, size and print method, with the
/// live price.
Future<void> showVariantSheet(BuildContext context, EditorArgs args) {
  return showAppBottomSheet<void>(
    context,
    title: context.l10n.editorSheetProduct,
    builder: (_) => _VariantSheet(args: args),
  );
}

class _VariantSheet extends ConsumerWidget {
  const _VariantSheet({required this.args});

  final EditorArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(editorControllerProvider(args));
    final controller = ref.read(editorControllerProvider(args).notifier);
    final product = s.product;
    final variant = s.variant;
    final c = context.colors;
    final t = context.l10n;
    if (product == null || variant == null) return const SizedBox.shrink();
    Widget title(String text) => Padding(
          padding: const EdgeInsets.only(top: Insets.lg, bottom: Insets.sm),
          child: Text(text, style: context.text.titleSmall),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (product.variants.length > 1) ...[
          title(t.editorSheetType),
          VariantPicker(
            variants: product.variants,
            selected: variant,
            onSelected: (v) async {
              final lost = controller.layersLostBy(v.id);
              if (lost > 0) {
                final ok = await confirmSheet(
                  context,
                  title: t.editorSheetLostElements(lost),
                  confirmLabel: t.editorSheetReplace,
                );
                if (!ok) return;
              }
              controller.pickVariant(v.id);
            },
          ),
        ],
        if (variant.description.trim().isNotEmpty) ...[
          Gap.md,
          RichDescription(variant.description),
        ],
        if (variant.colors.isNotEmpty) ...[
          title(s.color != null ? t.editorSheetColorNamed(s.color!.name) : t.editorPropsColor),
          ColorPicker(colors: variant.colors, selected: s.color, onSelected: (col) => controller.pickColor(col.id)),
        ],
        if (variant.sizes.isNotEmpty) ...[
          title(t.editorSheetSize),
          SizePicker(sizes: variant.sizes, selected: s.size, onSelected: controller.pickSize),
        ],
        if (s.methods.length > 1) ...[
          title(t.editorSheetPrintMethod),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final m in variant.methods) ButtonSegment(value: m.value, label: Text(m.label)),
            ],
            selected: {?s.designMethod},
            onSelectionChanged: (v) {
              HapticFeedback.selectionClick();
              final why = controller.setDesignMethod(v.first);
              if (why != null) showAppSnack(context, why, error: true);
            },
          ),
        ],
        Gap.xl,
        Row(
          children: [
            Text(t.editorSheetPrice, style: context.text.bodyLarge?.copyWith(color: c.inkMuted)),
            const Spacer(),
            if (s.price != null) PriceText(s.price!, style: context.text.titleLarge),
          ],
        ),
        Gap.lg,
        AppButton(label: context.l10n.commonDone, onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

/// The ⋮ menu: switch side, sync sides, clear the side, view options.
Future<void> showAreaMenu(
  BuildContext context,
  WidgetRef ref,
  EditorArgs args, {
  required bool grid,
  required bool snapping,
  required ValueChanged<bool> onGrid,
  required ValueChanged<bool> onSnapping,
}) {
  final outer = context;
  return showAppBottomSheet<void>(
    context,
    title: context.l10n.editorSheetSides,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final s = ref.watch(editorControllerProvider(args));
        final controller = ref.read(editorControllerProvider(args).notifier);
        final c = context.colors;
        final t = context.l10n;
        final area = s.area;
        final clear = area == null ? 0 : controller.clearCount(area.key);
        final canSync = area != null && s.areas.any((a) => linkable(area, a));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final a in s.areas)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  a.key == s.selectedArea ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: a.key == s.selectedArea ? c.brand : c.inkSubtle,
                ),
                title: Text(a.name),
                subtitle: _areaNote(t, s, a.key),
                trailing: Text('${s.doc.layers.where((l) => l.area == a.key && !l.isBackground).length}'),
                onTap: () {
                  controller.selectArea(a.key);
                  Navigator.of(context).pop();
                },
              ),
            const Divider(),
            if (canSync)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sync_rounded),
                title: Text(t.editorSheetSync),
                onTap: () {
                  Navigator.of(context).pop();
                  showSyncSheet(outer, args);
                },
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: clear > 0,
              leading: Icon(Icons.cleaning_services_outlined, color: clear > 0 ? c.danger : null),
              title: Text(clear > 0 ? t.editorSheetClearSideCount(clear) : t.editorSheetClearSide),
              onTap: () async {
                final nav = Navigator.of(context);
                final ok = await confirmSheet(
                  context,
                  title: t.editorSheetClearConfirm(clear, area!.name),
                  confirmLabel: t.editorSheetClear,
                  destructive: true,
                );
                if (ok) {
                  controller.clearArea(area.key);
                  nav.pop();
                }
              },
            ),
            _Toggle(label: t.editorSheetGrid, icon: Icons.grid_4x4_rounded, value: grid, onChanged: onGrid),
            _Toggle(label: t.editorSheetSnapping, icon: Icons.straighten_rounded, value: snapping, onChanged: onSnapping),
          ],
        );
      },
    ),
  );
}

Widget? _areaNote(AppLocalizations t, EditorState s, String key) {
  final from = s.doc.syncedFrom(key);
  if (from != null) return Text(t.editorSheetSyncedFrom(areaByKey(s.areas, from)?.name ?? from));
  final to = s.doc.syncTargets(key);
  if (to.isNotEmpty) return Text(t.editorSheetSyncedTo(to.length));
  return null;
}

class _Toggle extends StatefulWidget {
  const _Toggle({required this.label, required this.icon, required this.value, required this.onChanged});

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<_Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<_Toggle> {
  late bool _value = widget.value;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(widget.icon),
        title: Text(widget.label),
        value: _value,
        onChanged: (v) {
          setState(() => _value = v);
          widget.onChanged(v);
        },
      );
}

/// Which sides show the open side's design.
Future<void> showSyncSheet(BuildContext context, EditorArgs args) {
  return showAppBottomSheet<void>(
    context,
    title: context.l10n.editorSheetSync,
    builder: (context) => _SyncSheet(args: args),
  );
}

class _SyncSheet extends ConsumerStatefulWidget {
  const _SyncSheet({required this.args});
  final EditorArgs args;

  @override
  ConsumerState<_SyncSheet> createState() => _SyncSheetState();
}

class _SyncSheetState extends ConsumerState<_SyncSheet> {
  Set<String>? _picked;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(editorControllerProvider(widget.args));
    final source = s.area;
    if (source == null) return const SizedBox.shrink();
    final picked = _picked ??= s.doc.syncTargets(source.key).toSet();
    final options = [for (final a in s.areas) if (linkable(source, a)) a];
    final isTarget = s.doc.syncedFrom(source.key) != null;
    final t = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isTarget)
          EmptyState(title: t.editorSheetSelfSynced, icon: Icons.sync_disabled_rounded, compact: true)
        else
          for (final a in options)
            Builder(
              builder: (context) {
                final from = s.doc.syncedFrom(a.key);
                final blocked = s.doc.syncTargets(a.key).isNotEmpty
                    ? t.editorSheetLinkedElsewhere
                    : from != null && from != source.key
                        ? t.editorSheetSyncedFrom(areaByKey(s.areas, from)?.name ?? from)
                        : null;
                final own = s.doc.layers.where((l) => l.area == a.key).length;
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: picked.contains(a.key),
                  onChanged: blocked != null
                      ? null
                      : (v) => setState(() => v == true ? picked.add(a.key) : picked.remove(a.key)),
                  title: Text(mirrored(source, a) ? t.editorSheetMirrored(a.name) : a.name),
                  subtitle: blocked != null
                      ? Text(blocked)
                      : own > 0 && !s.doc.syncTargets(source.key).contains(a.key)
                          ? Text(t.editorSheetOwnHidden(own))
                          : null,
                );
              },
            ),
        Gap.lg,
        AppButton(
          label: t.commonSave,
          onPressed: isTarget
              ? null
              : () {
                  ref.read(editorControllerProvider(widget.args).notifier).setSync(source.key, picked.toList());
                  Navigator.of(context).pop();
                },
        ),
      ],
    );
  }
}

/// "Rasmga olish": the five views, or the product as it is seen now.
Future<void> showCaptureSheet(BuildContext context, EditorController controller, String slug) {
  return showAppBottomSheet<void>(
    context,
    title: context.l10n.editorSheetCapture,
    builder: (_) => _CaptureSheet(controller: controller, slug: slug),
  );
}

class _CaptureSheet extends StatefulWidget {
  const _CaptureSheet({required this.controller, required this.slug});

  final EditorController controller;
  final String slug;

  @override
  State<_CaptureSheet> createState() => _CaptureSheetState();
}

enum _Shot { set, view }

class _CaptureSheetState extends State<_CaptureSheet> {
  (_Shot, bool)? _busy; // (what, to gallery)

  Future<List<Uint8List>> _take(_Shot shot) async {
    if (shot == _Shot.set) {
      final frames = await widget.controller.captureFrames(size: 1600);
      return [for (final f in frames) await dataUrlBytes(f)];
    }
    return [await dataUrlBytes(await widget.controller.captureView())];
  }

  Future<void> _run(_Shot shot, {required bool gallery}) async {
    if (_busy != null) return;
    setState(() => _busy = (shot, gallery));
    final ext = shot == _Shot.set ? 'jpg' : 'png';
    final t = context.l10n;
    try {
      final images = await _take(shot);
      if (images.isEmpty) throw EngineException(t.editorSheet3dNotReady);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      if (gallery) {
        if (!await Gal.hasAccess(toAlbum: true) && !await Gal.requestAccess(toAlbum: true)) {
          throw EngineException(t.editorSheetGalleryDenied);
        }
        for (final (i, bytes) in images.indexed) {
          await Gal.putImageBytes(bytes, album: 'Dizzo', name: '${widget.slug}-$stamp-${i + 1}');
        }
        if (mounted) {
          Navigator.of(context).pop();
          showAppSnack(context, images.length > 1 ? t.editorSheetImagesSaved(images.length) : t.editorSheetImageSaved);
        }
      } else {
        final dir = await getTemporaryDirectory();
        final files = <XFile>[];
        for (final (i, bytes) in images.indexed) {
          final f = File('${dir.path}${Platform.pathSeparator}${widget.slug}-$stamp-${i + 1}.$ext');
          await f.writeAsBytes(bytes);
          files.add(XFile(f.path, mimeType: ext == 'png' ? 'image/png' : 'image/jpeg'));
        }
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(ShareParams(
          files: files,
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ));
      }
    } on EngineException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } on GalException {
      if (mounted) showAppSnack(context, t.editorSheetGallerySaveFailed, error: true);
    } catch (_) {
      if (mounted) showAppSnack(context, t.editorSheetCaptureFailed, error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Widget _option(BuildContext context, _Shot shot, IconData icon, String title) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: Radii.brLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: c.brand),
              Gap.sm,
              Expanded(child: Text(title, style: context.text.titleSmall)),
            ],
          ),
          Gap.md,
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: context.l10n.editorSheetToGallery,
                  size: 44,
                  icon: const Icon(Icons.download_rounded, size: 20),
                  loading: _busy == (shot, true),
                  onPressed: _busy == null ? () => _run(shot, gallery: true) : null,
                ),
              ),
              Gap.sm,
              Expanded(
                child: AppButton(
                  label: context.l10n.editorSheetShare,
                  size: 44,
                  variant: AppButtonVariant.outline,
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                  loading: _busy == (shot, false),
                  onPressed: _busy == null ? () => _run(shot, gallery: false) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _option(context, _Shot.set, Icons.collections_rounded, context.l10n.editorSheetImagesCount(5)),
        Gap.md,
        _option(context, _Shot.view, Icons.crop_free_rounded, context.l10n.editorSheetCurrentView),
      ],
    );
  }
}

/// Adding to the cart: the steps, a changed price, the result.
Future<String?> showCartProgress(BuildContext context, EditorArgs args) {
  return showAppBottomSheet<String>(
    context,
    isDismissible: false,
    builder: (_) => _CartProgress(args: args),
  );
}

class _CartProgress extends ConsumerWidget {
  const _CartProgress({required this.args});

  final EditorArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(editorControllerProvider(args).select((s) => s.cart));
    final controller = ref.read(editorControllerProvider(args).notifier);
    final c = context.colors;
    final t = context.l10n;
    void close() {
      controller.resetCart();
      Navigator.of(context).pop();
    }

    return switch (flow) {
      CartWorking(:final step, :final progress) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Insets.xl),
          child: Center(child: StageLoaderContent(text: step, progress: progress, size: 64)),
        ),
      CartConfirm(:final quote) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.editorSheetPriceRecalculated, style: context.text.titleMedium),
            Gap.lg,
            Center(child: PriceText(quote.unitPrice, style: context.text.headlineSmall?.copyWith(color: c.brand))),
            Gap.xl,
            AppButton(label: t.editorSheetAddAtPrice, onPressed: controller.confirmPrice),
            Gap.sm,
            AppButton(label: t.commonCancel, variant: AppButtonVariant.ghost, onPressed: close),
          ],
        ),
      CartDone() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.check_circle_rounded, size: 56, color: c.success),
            Gap.md,
            Text(t.editorSheetAddedToCart, style: context.text.titleLarge, textAlign: TextAlign.center),
            Gap.xl,
            AppButton(
              label: t.editorSheetGoToCart,
              onPressed: () {
                controller.resetCart();
                Navigator.of(context).pop('cart');
              },
            ),
            Gap.sm,
            AppButton(label: t.editorSheetContinue, variant: AppButtonVariant.outline, onPressed: close),
          ],
        ),
      CartFailed(:final message) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: c.danger),
            Gap.md,
            Text(message, style: context.text.titleMedium, textAlign: TextAlign.center),
            Gap.xl,
            AppButton(label: t.commonClose, variant: AppButtonVariant.outline, onPressed: close),
          ],
        ),
      CartIdle() => const SizedBox(height: 120),
    };
  }
}

/// A product colour row for "Fon".
class ProductColorRow extends StatelessWidget {
  const ProductColorRow({super.key, required this.colors, required this.selected, required this.onPick});

  final List<ProductColor> colors;
  final ProductColor? selected;
  final ValueChanged<ProductColor> onPick;

  @override
  Widget build(BuildContext context) =>
      ColorPicker(colors: colors, selected: selected, onSelected: onPick);
}
