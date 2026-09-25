import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../../l10n/gen/app_localizations.dart';

/// A picture ready to upload: the right way up, cropped, not larger than
/// the backend takes (the web scales very large photos down the same way).
class PreparedImage {
  const PreparedImage(this.bytes, this.contentType, this.width, this.height);

  final Uint8List bytes;
  final String contentType;
  final int width;
  final int height;
}

/// A crop as fractions of the (upright) picture.
class CropFraction {
  const CropFraction(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  static const whole = CropFraction(0, 0, 1, 1);

  bool get isWhole => left <= 0.001 && top <= 0.001 && right >= 0.999 && bottom >= 0.999;
}

const _maxSide = 6000;
const _maxBytes = 10 * 1024 * 1024;

enum ImageProblem { unsupported, unreadable }

class ImageProcessingException implements Exception {
  const ImageProcessingException(this.problem);
  final ImageProblem problem;

  /// Thrown off the UI isolate, so the words are picked where it is shown.
  String messageIn(AppLocalizations l) => switch (problem) {
        ImageProblem.unsupported => l.editorImageUnsupported,
        ImageProblem.unreadable => l.editorImageOpenFailed,
      };
}

/// Runs off the UI isolate.
Future<PreparedImage> prepareImage(Uint8List bytes, CropFraction crop) =>
    Isolate.run(() => _prepare(bytes, crop));

PreparedImage _prepare(Uint8List bytes, CropFraction crop) {
  final decoder = img.findDecoderForData(bytes);
  if (decoder == null) throw const ImageProcessingException(ImageProblem.unsupported);
  final isPng = decoder is img.PngDecoder;
  final isJpeg = decoder is img.JpegDecoder;
  final isWebp = decoder is img.WebPDecoder;
  if (!isPng && !isJpeg && !isWebp) {
    throw const ImageProcessingException(ImageProblem.unsupported);
  }
  final decoded = decoder.decode(bytes);
  if (decoded == null) throw const ImageProcessingException(ImageProblem.unreadable);
  final orientation = decoded.exif.imageIfd.orientation ?? 1;
  var image = orientation != 1 ? img.bakeOrientation(decoded) : decoded;
  var changed = orientation != 1;

  if (!crop.isWhole) {
    final x = (crop.left * image.width).round().clamp(0, image.width - 1);
    final y = (crop.top * image.height).round().clamp(0, image.height - 1);
    final w = ((crop.right - crop.left) * image.width).round().clamp(1, image.width - x);
    final h = ((crop.bottom - crop.top) * image.height).round().clamp(1, image.height - y);
    image = img.copyCrop(image, x: x, y: y, width: w, height: h);
    changed = true;
  }
  final longest = math.max(image.width, image.height);
  if (longest > _maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: _maxSide, interpolation: img.Interpolation.cubic)
        : img.copyResize(image, height: _maxSide, interpolation: img.Interpolation.cubic);
    changed = true;
  }

  // The original file when nothing had to change.
  if (!changed && bytes.length <= _maxBytes && !isWebp) {
    return PreparedImage(bytes, isPng ? 'image/png' : 'image/jpeg', image.width, image.height);
  }
  final keepAlpha = image.hasAlpha && (isPng || isWebp);
  if (keepAlpha) {
    var png = img.encodePng(image, level: 6);
    // Too big for the backend: smaller until it fits.
    while (png.length > _maxBytes && math.max(image.width, image.height) > 1200) {
      image = img.copyResize(image, width: (image.width * 0.8).round());
      png = img.encodePng(image, level: 6);
    }
    return PreparedImage(png, 'image/png', image.width, image.height);
  }
  final flat = image.hasAlpha ? image.convert(numChannels: 3) : image;
  var quality = 92;
  var jpg = img.encodeJpg(flat, quality: quality);
  while (jpg.length > _maxBytes && quality > 60) {
    quality -= 10;
    jpg = img.encodeJpg(flat, quality: quality);
  }
  return PreparedImage(jpg, 'image/jpeg', flat.width, flat.height);
}
