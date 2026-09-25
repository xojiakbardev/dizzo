import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/sticker_library.dart';
import '../../domain/design_document.dart';

/// Pictures the canvas draws, decoded once: uploaded images (scaled to at
/// most [maxPx] on screen), their single-colour versions for engraving, and
/// sticker SVGs as pictures. Notifies when something arrives.
class AssetStore extends ChangeNotifier {
  AssetStore(this._stickers, {this.maxPx = 2048}) {
    _stickers.revision.addListener(_onStickers);
  }

  final StickerLibrary _stickers;
  final int maxPx;

  final _images = <String, ui.Image>{};
  final _mono = <String, ui.Image>{};
  final _pending = <String>{};
  final _failed = <String>{};
  final _pictures = <String, PictureInfo>{};
  final _pictureLoads = <String>{};
  final _stickerAsked = <String>{};
  var _disposed = false;

  ui.Image? image(String url) {
    final hit = _images[url];
    if (hit == null && !_pending.contains(url) && !_failed.contains(url)) unawaited(_loadImage(url));
    return hit;
  }

  bool failed(String url) => _failed.contains(url);

  /// Black-ink version (the web's `monoImage`): with transparency every
  /// opaque pixel is ink; without, every dark pixel is.
  ui.Image? monoImage(String url) {
    final hit = _mono[url];
    if (hit != null) return hit;
    final src = _images[url];
    if (src == null) {
      image(url);
      return null;
    }
    final key = 'mono:$url';
    if (!_pending.contains(key)) unawaited(_makeMono(url, src, key));
    return null;
  }

  /// Puts a picture the phone already has (a fresh upload) under its URL.
  Future<void> putBytes(String url, Uint8List bytes) async {
    try {
      _images[url] = await _decode(bytes);
      _failed.remove(url);
      _notify();
    } catch (_) {}
  }

  Future<ui.Image> _decode(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final w = descriptor.width;
    final h = descriptor.height;
    final k = w > h ? maxPx / w : maxPx / h;
    final codec = k < 1
        ? await descriptor.instantiateCodec(targetWidth: (w * k).round(), targetHeight: (h * k).round())
        : await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    return frame.image;
  }

  Future<void> _loadImage(String url) async {
    _pending.add(url);
    final provider = ResizeImage(
      CachedNetworkImageProvider(url),
      width: maxPx,
      height: maxPx,
      policy: ResizeImagePolicy.fit,
      allowUpscaling: false,
    );
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image.clone());
        info.dispose();
        stream.removeListener(listener);
      },
      onError: (e, _) {
        if (!completer.isCompleted) completer.completeError(e);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    try {
      _images[url] = await completer.future;
    } catch (e) {
      debugPrint('[editor] image not loaded: $url $e');
      _failed.add(url);
    } finally {
      _pending.remove(url);
      _notify();
    }
  }

  Future<void> _makeMono(String url, ui.Image src, String key) async {
    _pending.add(key);
    try {
      final data = await src.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      if (data == null) return;
      final px = await compute(_monoPixels, data.buffer.asUint8List());
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(px, src.width, src.height, ui.PixelFormat.rgba8888, completer.complete);
      _mono[url] = await completer.future;
    } catch (e) {
      debugPrint('[editor] mono image failed: $e');
    } finally {
      _pending.remove(key);
      _notify();
    }
  }

  /// A sticker as a picture (null until its SVG has arrived).
  PictureInfo? sticker(String name) {
    final hit = _pictures[name];
    if (hit != null) return hit;
    final svg = _stickers.svg(name);
    if (svg == null) {
      if (_stickerAsked.add(name)) unawaited(_stickers.ensure([name]));
      return null;
    }
    if (_pictureLoads.add(name)) unawaited(_loadPicture(name, svg));
    return null;
  }

  Future<void> _loadPicture(String name, String svg) async {
    try {
      _pictures[name] = await vg.loadPicture(SvgStringLoader(svg), null);
    } catch (e) {
      debugPrint('[editor] sticker $name unreadable: $e');
    } finally {
      _notify();
    }
  }

  /// Everything the layers need, loaded (for pictures of the design).
  Future<void> prepare(List<Layer> layers) async {
    final names = [for (final l in layers) if (l.graphic?.library == 'sticker') l.graphic!.name];
    await _stickers.ensure(names);
    for (final n in names) {
      sticker(n);
    }
    for (final l in layers) {
      if (l.image != null) image(l.image!.url);
    }
  }

  void _onStickers() => _notify();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stickers.revision.removeListener(_onStickers);
    for (final i in _images.values) {
      i.dispose();
    }
    for (final i in _mono.values) {
      i.dispose();
    }
    for (final p in _pictures.values) {
      p.picture.dispose();
    }
    super.dispose();
  }
}

Uint8List _monoPixels(Uint8List px) {
  var transparent = false;
  for (var i = 3; i < px.length; i += 4) {
    if (px[i] < 250) {
      transparent = true;
      break;
    }
  }
  final out = Uint8List(px.length);
  for (var i = 0; i < px.length; i += 4) {
    final lum = (0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2]) / 255;
    final ink = transparent ? px[i + 3] > 127 : lum < 0.5;
    out[i + 3] = ink ? 255 : 0;
  }
  return out;
}
