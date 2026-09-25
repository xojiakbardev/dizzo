import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/widgets.dart';
import 'image_processing.dart';

/// Crops a picked picture before it is uploaded. Pops a [CropFraction]
/// (the whole picture when left as it is) or null when cancelled.
class CropScreen extends StatefulWidget {
  const CropScreen({super.key, required this.bytes, this.zoneAspect});

  final Uint8List bytes;

  /// The print zone's width / height, offered as a crop shape.
  final double? zoneAspect;

  static Future<CropFraction?> open(BuildContext context, Uint8List bytes, {double? zoneAspect}) {
    return Navigator.of(context, rootNavigator: true).push<CropFraction>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => CropScreen(bytes: bytes, zoneAspect: zoneAspect)),
    );
  }

  @override
  State<CropScreen> createState() => _CropScreenState();
}

enum _Grip { move, tl, tr, bl, br }

class _CropScreenState extends State<CropScreen> {
  Size? _imageSize;
  Rect _crop = const Rect.fromLTRB(0, 0, 1, 1); // fractions
  double? _aspect; // null: free
  _Grip? _grip;
  Rect _startCrop = Rect.zero;
  Offset _startPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    final provider = MemoryImage(widget.bytes);
    provider.resolve(ImageConfiguration.empty).addListener(
      ImageStreamListener((info, _) {
        if (mounted) {
          setState(() => _imageSize = Size(info.image.width.toDouble(), info.image.height.toDouble()));
        }
        info.dispose();
      }, onError: (_, _) {
        if (mounted) Navigator.of(context).pop();
      }),
    );
  }

  void _setAspect(double? aspect) {
    HapticFeedback.selectionClick();
    final size = _imageSize;
    setState(() {
      _aspect = aspect;
      if (aspect == null || size == null) return;
      // The largest centred crop of that shape.
      final imageAspect = size.width / size.height;
      final wf = aspect >= imageAspect ? 1.0 : aspect / imageAspect;
      final hf = aspect >= imageAspect ? imageAspect / aspect : 1.0;
      _crop = Rect.fromCenter(center: const Offset(0.5, 0.5), width: wf, height: hf);
    });
  }

  void _start(Offset p, Rect frame) {
    final r = Rect.fromLTRB(
      frame.left + _crop.left * frame.width,
      frame.top + _crop.top * frame.height,
      frame.left + _crop.right * frame.width,
      frame.top + _crop.bottom * frame.height,
    );
    const touch = 36.0;
    _grip = null;
    for (final (g, corner) in [
      (_Grip.tl, r.topLeft),
      (_Grip.tr, r.topRight),
      (_Grip.bl, r.bottomLeft),
      (_Grip.br, r.bottomRight),
    ]) {
      if ((corner - p).distance <= touch) _grip = g;
    }
    if (_grip == null && r.inflate(8).contains(p)) _grip = _Grip.move;
    _startCrop = _crop;
    _startPoint = p;
  }

  void _update(Offset p, Rect frame) {
    final grip = _grip;
    if (grip == null) return;
    final dx = (p.dx - _startPoint.dx) / frame.width;
    final dy = (p.dy - _startPoint.dy) / frame.height;
    const minF = 0.08;
    var r = _startCrop;
    if (grip == _Grip.move) {
      final x = (r.left + dx).clamp(0.0, 1 - r.width);
      final y = (r.top + dy).clamp(0.0, 1 - r.height);
      setState(() => _crop = Rect.fromLTWH(x, y, r.width, r.height));
      return;
    }
    var left = r.left;
    var top = r.top;
    var right = r.right;
    var bottom = r.bottom;
    if (grip == _Grip.tl || grip == _Grip.bl) left = (left + dx).clamp(0.0, right - minF);
    if (grip == _Grip.tr || grip == _Grip.br) right = (right + dx).clamp(left + minF, 1.0);
    if (grip == _Grip.tl || grip == _Grip.tr) top = (top + dy).clamp(0.0, bottom - minF);
    if (grip == _Grip.bl || grip == _Grip.br) bottom = (bottom + dy).clamp(top + minF, 1.0);
    final aspect = _aspect;
    final size = _imageSize;
    if (aspect != null && size != null) {
      // Keep the shape: the height follows the width (in picture pixels).
      final k = size.width / size.height / aspect;
      var w = right - left;
      var h = w * k;
      final maxH = (grip == _Grip.tl || grip == _Grip.tr) ? bottom : 1 - top;
      if (h > maxH) {
        h = maxH;
        w = h / k;
      }
      if (grip == _Grip.tl || grip == _Grip.bl) left = right - w;
      if (grip == _Grip.tr || grip == _Grip.br) right = left + w;
      if (grip == _Grip.tl || grip == _Grip.tr) top = bottom - h;
      if (grip == _Grip.bl || grip == _Grip.br) bottom = top + h;
      r = Rect.fromLTRB(left, top, right, bottom);
      if (r.left < 0 || r.right > 1 || r.top < -0.0001 || r.bottom > 1.0001) return;
    }
    setState(() => _crop = Rect.fromLTRB(left, top, right, bottom));
  }

  @override
  Widget build(BuildContext context) {
    final size = _imageSize;
    final t = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(t.editorCropTitle),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _crop = const Rect.fromLTRB(0, 0, 1, 1);
              _aspect = null;
            }),
            child: Text(t.editorCropOriginal, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: size == null
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(
                      builder: (context, box) {
                        final k = math.min((box.maxWidth - 32) / size.width, (box.maxHeight - 32) / size.height);
                        final w = size.width * k;
                        final h = size.height * k;
                        final frame = Rect.fromLTWH((box.maxWidth - w) / 2, (box.maxHeight - h) / 2, w, h);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (d) => _start(d.localPosition, frame),
                          onPanUpdate: (d) => _update(d.localPosition, frame),
                          onPanEnd: (_) => _grip = null,
                          child: Stack(
                            children: [
                              Positioned.fromRect(
                                rect: frame,
                                child: Image.memory(widget.bytes, fit: BoxFit.fill, cacheWidth: math.min(1600, size.width.round())),
                              ),
                              Positioned.fill(child: CustomPaint(painter: _CropPainter(frame, _crop))),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.sm),
              child: Row(
                children: [
                  for (final (label, aspect) in [
                    (t.editorCropFree, null),
                    if (widget.zoneAspect != null) (t.editorCropZone, widget.zoneAspect),
                    ('1:1', 1.0),
                    ('4:3', 4 / 3),
                    ('3:4', 3 / 4),
                    ('16:9', 16 / 9),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: Insets.sm),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _aspect == aspect,
                        onSelected: (_) => _setAspect(aspect),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.lg, Insets.lg),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(0, 52)),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(t.commonCancel),
                    ),
                  ),
                  Gap.md,
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                      onPressed: size == null
                          ? null
                          : () => Navigator.of(context).pop(
                                CropFraction(_crop.left, _crop.top, _crop.right, _crop.bottom),
                              ),
                      child: Text(t.commonDone),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.frame, this.crop);

  final Rect frame;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTRB(
      frame.left + crop.left * frame.width,
      frame.top + crop.top * frame.height,
      frame.left + crop.right * frame.width,
      frame.top + crop.bottom * frame.height,
    );
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(frame)
      ..addRect(r);
    canvas.drawPath(shade, Paint()..color = Colors.black.withValues(alpha: 0.55));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    canvas.drawRect(r, line);
    final thin = Paint()
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.6);
    for (var i = 1; i < 3; i++) {
      final x = r.left + r.width * i / 3;
      final y = r.top + r.height * i / 3;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), thin);
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), thin);
    }
    final grip = Paint()..color = Colors.white;
    for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      canvas.drawCircle(c, 9, grip);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.frame != frame || old.crop != crop;
}
