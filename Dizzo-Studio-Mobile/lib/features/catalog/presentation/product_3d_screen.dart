import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
// The web engine (WebView) the editor uses; the product page opens its own
// instance only when the customer asks for 3D, and frees it on close.
import '../../editor/data/engine_bridge.dart';

/// The product in 3D (read-only: orbit and zoom), in the chosen type and
/// colour.
class Product3dScreen extends StatefulWidget {
  const Product3dScreen({
    super.key,
    required this.slug,
    required this.title,
    this.variantId,
    this.colorId,
    this.engineFactory,
  });

  final String slug;
  final String title;
  final int? variantId;
  final int? colorId;

  /// Tests pass a fake engine.
  final DesignEngine Function()? engineFactory;

  static Future<void> open(
    BuildContext context, {
    required String slug,
    required String title,
    int? variantId,
    int? colorId,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => Product3dScreen(slug: slug, title: title, variantId: variantId, colorId: colorId),
      ),
    );
  }

  @override
  State<Product3dScreen> createState() => _Product3dScreenState();
}

class _Product3dScreenState extends State<Product3dScreen> {
  late final DesignEngine _engine = (widget.engineFactory ?? WebDesignEngine.new)();
  bool _loaded = false;
  bool _failed = false;
  // The WebView is attached after the page transition: a platform view
  // during the slide costs frames.
  bool _showView = false;
  bool _waitingForRoute = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (_showView || _waitingForRoute) return;
    if (animation == null || animation.isCompleted) {
      _showView = true;
    } else {
      _waitingForRoute = true;
      void listener(AnimationStatus s) {
        if (s != AnimationStatus.completed) return;
        animation.removeStatusListener(listener);
        if (mounted) setState(() => _showView = true);
      }

      animation.addStatusListener(listener);
    }
  }

  Future<void> _load() async {
    try {
      await _engine.load(productSlug: widget.slug, variantId: widget.variantId, colorId: widget.colorId);
      if (mounted) setState(() => _loaded = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _retry() async {
    setState(() {
      _failed = false;
      _loaded = false;
    });
    if (_engine.status.value == EngineStatus.failed) {
      await _engine.reload().catchError((_) {});
    }
    await _load();
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_loaded)
            IconButton(
              tooltip: context.l10n.product3dResetView,
              icon: const Icon(Icons.center_focus_strong_outlined),
              onPressed: () => unawaited(_engine.resetView().catchError((_) {})),
            ),
        ],
      ),
      body: ColoredBox(
        color: c.plate,
        child: Stack(
          children: [
            if (_showView) Positioned.fill(child: _engine.buildView()),
            Positioned.fill(
              child: ValueListenableBuilder<EngineStatus>(
                valueListenable: _engine.status,
                builder: (context, status, _) {
                  if (_failed || status == EngineStatus.failed) {
                    return ColoredBox(
                      color: c.plate,
                      child: EmptyState(
                        title: context.l10n.product3dOpenFailed,
                        icon: Icons.view_in_ar_outlined,
                        actionLabel: context.l10n.commonRetry,
                        onAction: () => unawaited(_retry()),
                      ),
                    );
                  }
                  // Covers the blank WebView until the model is drawn
                  // (the engine answers `load` after its first frame).
                  return StageLoader(
                    show: !(_loaded && status == EngineStatus.ready),
                    text: context.l10n.product3dLoading,
                    background: c.plate,
                    immediate: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
