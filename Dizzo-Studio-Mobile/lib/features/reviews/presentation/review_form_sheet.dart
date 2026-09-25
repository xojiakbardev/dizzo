import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/widgets.dart';
import '../data/reviews_api.dart';
import '../domain/review.dart';
import 'widgets/review_widgets.dart';

/// "Fikr qoldirish" for a completed order: stars, text, city and up to six
/// photos (mirrors the web's OrderReview.vue). Resolves to true once sent.
Future<bool> showReviewForm(BuildContext context, {required int orderId}) async {
  final sent = await showAppBottomSheet<bool>(
    context,
    title: context.l10n.reviewsFormTitle,
    builder: (_) => ReviewForm(orderId: orderId),
  );
  return sent ?? false;
}

class _Photo {
  _Photo(this.bytes);

  final Uint8List bytes;
  UploadedPhoto? uploaded;
  bool failed = false;
}

class ReviewForm extends ConsumerStatefulWidget {
  const ReviewForm({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<ReviewForm> {
  final _text = TextEditingController();
  final _city = TextEditingController();
  final _photos = <_Photo>[];
  int _rating = 5;
  bool _sending = false;
  String? _textError;
  String? _error;

  bool get _uploading => _photos.any((p) => p.uploaded == null && !p.failed);

  @override
  void dispose() {
    _text.dispose();
    _city.dispose();
    super.dispose();
  }

  static String _contentType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _addPhotos() async {
    final left = ReviewRules.maxPhotos - _photos.length;
    if (left <= 0) return;
    List<XFile> files;
    try {
      files = await ImagePicker().pickMultiImage(maxWidth: 2000, maxHeight: 2000, imageQuality: 85, limit: left);
    } on PlatformException {
      if (mounted) setState(() => _error = context.l10n.reviewsPhotosOpenFailed);
      return;
    }
    for (final file in files.take(left)) {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > ReviewRules.maxPhotoBytes) {
        setState(() => _error = context.l10n.reviewsPhotoTooLarge(ReviewRules.maxPhotoBytes ~/ (1024 * 1024)));
        continue;
      }
      final photo = _Photo(bytes);
      setState(() {
        _error = null;
        _photos.add(photo);
      });
      await _upload(photo, _contentType(file.name));
    }
  }

  Future<void> _upload(_Photo photo, String type) async {
    try {
      final up = await ref.read(reviewsApiProvider).uploadPhoto(photo.bytes, type);
      if (mounted) setState(() => photo.uploaded = up);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          photo.failed = true;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _submit() async {
    final text = _text.text.trim();
    setState(() {
      _error = null;
      _textError = text.length < ReviewRules.minText ? context.l10n.reviewsTextTooShort(ReviewRules.minText) : null;
    });
    if (_textError != null || _uploading) return;
    setState(() => _sending = true);
    try {
      await ref.read(reviewsApiProvider).create(
            orderId: widget.orderId,
            rating: _rating,
            text: text,
            city: _city.text.trim(),
            photoIds: [for (final p in _photos) if (p.uploaded != null) p.uploaded!.id],
          );
      ref.invalidate(myReviewsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _textError = e.fieldErrors['text'];
        _error = _textError == null ? e.message : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: StarRating(value: _rating, size: 36, onChanged: (v) => setState(() => _rating = v)),
        ),
        Gap.lg,
        TextField(
          controller: _text,
          minLines: 3,
          maxLines: 6,
          maxLength: ReviewRules.maxText,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: context.l10n.reviewsTextLabel, alignLabelWithHint: true, errorText: _textError),
        ),
        Gap.sm,
        TextField(
          controller: _city,
          maxLength: ReviewRules.maxCity,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: context.l10n.reviewsCity, counterText: ''),
        ),
        Gap.lg,
        SizedBox(
          height: 76,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final p in _photos) ...[
                _PhotoTile(
                  photo: p,
                  onRemove: _sending ? null : () => setState(() => _photos.remove(p)),
                ),
                Gap.sm,
              ],
              if (_photos.length < ReviewRules.maxPhotos)
                InkWell(
                  onTap: _sending ? null : _addPhotos,
                  borderRadius: Radii.brMd,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: c.plate,
                      borderRadius: Radii.brMd,
                      border: Border.all(color: c.line),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: c.brand),
                        const Gap(2),
                        Text('${_photos.length}/${ReviewRules.maxPhotos}', style: context.text.labelSmall),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_error != null) ...[
          Gap.md,
          Text(_error!, style: context.text.bodySmall?.copyWith(color: c.danger)),
        ],
        Gap.xl,
        AppButton(
          label: context.l10n.reviewsSend,
          icon: const Icon(Icons.send_rounded),
          loading: _sending,
          onPressed: _uploading ? null : _submit,
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.onRemove});

  final _Photo photo;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: Radii.brMd,
            child: Image.memory(photo.bytes, fit: BoxFit.cover, cacheWidth: 228),
          ),
          if (photo.uploaded == null)
            DecoratedBox(
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: Radii.brMd),
              child: Center(
                child: photo.failed
                    ? const Icon(Icons.error_outline_rounded, color: Colors.white)
                    : const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      ),
              ),
            ),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: c.surface,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.close_rounded, size: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
