import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' as picker;

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/media_uploader.dart';
import '../../domain/design_document.dart';
import '../editor_controller.dart';
import '../editor_state.dart';
import '../render/asset_store.dart';
import 'crop_screen.dart';
import 'image_processing.dart';

/// Picks a picture, lets the customer crop it, uploads it (as the web does)
/// and places it on the open area. Returns false when nothing was added.
Future<bool> pickAndPlaceImage(
  BuildContext context,
  WidgetRef ref, {
  required ImageSource2 source,
  required EditorState state,
  required EditorController controller,
  required AssetStore assets,
  required ValueChanged<bool> onBusy,
}) async {
  if (!controller.ensureCanAdd()) return false;
  final picker.XFile? file;
  try {
    file = await picker.ImagePicker().pickImage(
      source: source == ImageSource2.camera ? picker.ImageSource.camera : picker.ImageSource.gallery,
      requestFullMetadata: false,
    );
  } catch (_) {
    if (context.mounted) showAppSnack(context, context.l10n.editorImageOpenFailed, error: true);
    return false;
  }
  if (file == null || !context.mounted) return false;
  final raw = await file.readAsBytes();
  if (!context.mounted) return false;
  final zone = state.area?.method(state.designMethod ?? '')?.zone;
  final crop = await CropScreen.open(context, raw, zoneAspect: zone == null ? null : zone.width / zone.height);
  if (crop == null || !context.mounted) return false;
  onBusy(true);
  try {
    final prepared = await prepareImage(raw, crop);
    final media = await ref.read(mediaUploaderProvider).upload(prepared.bytes, prepared.contentType, 'design');
    await assets.putBytes(media.url, prepared.bytes);
    final image = ImageSource(mediaId: media.id, url: media.url, pxW: prepared.width, pxH: prepared.height);
    controller.rememberUpload(image, guest: media.guest || !ref.read(authControllerProvider).isAuthenticated);
    return controller.addImage(image) != null;
  } on ImageProcessingException catch (e) {
    if (context.mounted) showAppSnack(context, e.messageIn(context.l10n), error: true);
  } on ApiException catch (e) {
    if (context.mounted) showAppSnack(context, e.message, error: true);
  } catch (_) {
    if (context.mounted) showAppSnack(context, context.l10n.editorImageUploadFailed, error: true);
  } finally {
    onBusy(false);
  }
  return false;
}

enum ImageSource2 { gallery, camera }

/// "Rasm": from the gallery or the camera, and pictures used before.
class ImagePanel extends StatelessWidget {
  const ImagePanel({
    super.key,
    required this.state,
    required this.busy,
    required this.onPick,
    required this.onReuse,
  });

  final EditorState state;
  final bool busy;
  final ValueChanged<ImageSource2> onPick;
  final ValueChanged<ImageSource> onReuse;

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final seen = <String, ImageSource>{};
    for (final i in [...state.uploads, for (final l in state.doc.layers) ?l.image]) {
      seen.putIfAbsent(i.mediaId, () => i);
    }
    final images = seen.values.toList();
    final enabled = state.canAdd && !busy;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, Insets.lg),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: context.l10n.editorImageGallery,
                    icon: const Icon(Icons.photo_library_rounded),
                    loading: busy,
                    onPressed: enabled ? () => onPick(ImageSource2.gallery) : null,
                  ),
                ),
                Gap.md,
                Expanded(
                  child: AppButton(
                    label: context.l10n.editorImageCamera,
                    variant: AppButtonVariant.outline,
                    icon: const Icon(Icons.photo_camera_rounded),
                    onPressed: enabled ? () => onPick(ImageSource2.camera) : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (images.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, Insets.xl),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 110,
                crossAxisSpacing: Insets.sm,
                mainAxisSpacing: Insets.sm,
              ),
              itemCount: images.length,
              itemBuilder: (context, i) => InkWell(
                borderRadius: Radii.brMd,
                onTap: enabled ? () => onReuse(images[i]) : null,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: context.colors.plate, borderRadius: Radii.brMd),
                  child: AppImage(images[i].url, fit: BoxFit.contain, borderRadius: Radii.brMd),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
