import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/l10n/app_language.dart';
import '../../../core/utils/json.dart';
import '../domain/design_document.dart';
import '../domain/editor_models.dart';
import 'engine_protocol.dart';

/// A print file rendered by the engine (`renderPrintFiles`).
class EnginePrintFile {
  const EnginePrintFile({required this.area, required this.method, required this.dataUrl, required this.bytes});

  factory EnginePrintFile.fromJson(Json j) => EnginePrintFile(
        area: j.str('area'),
        method: j.str('method'),
        dataUrl: j.str('dataUrl'),
        bytes: j.integer('bytes'),
      );

  final String area;
  final String method;
  final String dataUrl;
  final int bytes;
}

/// The web's rendering engine: 3D preview, mockups, print files and
/// measurement (EMBED_ENGINE.md). [WebDesignEngine] hosts it in a WebView;
/// tests pass a fake.
abstract class DesignEngine {
  /// True once the page said `ready` (and no fatal error came).
  ValueListenable<EngineStatus> get status;
  Stream<EngineEvent> get events;

  /// The WebView to show (the 3D view). Keep it in the tree while editing.
  Widget buildView();

  Future<EngineProduct> load({required String productSlug, int? variantId, int? colorId});
  Future<EngineProduct> setAppearance({int? variantId, int? colorId});
  Future<Json> setDocument(DesignDocument document);
  Future<void> showArea(String key);
  Future<void> resetView();
  Future<List<String>> captureFrames({int size = 900, List<String>? areas});
  Future<String> captureView({int size = 1600});
  Future<List<EnginePrintFile>> renderPrintFiles();
  Future<Map<String, String>> measure();

  /// Reloads the page after a failure.
  Future<void> reload();
  void dispose();
}

enum EngineStatus { loading, ready, failed }

class WebDesignEngine implements DesignEngine {
  WebDesignEngine({Uri? url}) : _url = url ?? Uri.parse('${Env.siteUrl}/embed/engine?chunk=1000000&lang=${AppLanguage.current.code}') {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFE9EDF2))
      ..addJavaScriptChannel('DizzoBridge', onMessageReceived: (m) => _protocol.receive(m.message))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            // A (re)load: whatever was waiting is lost with the old page.
            if (!_disposed && _pageLoads++ > 0) _restart();
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame ?? true) _fail(EngineException(e.description));
          },
          onNavigationRequest: (r) => r.url.startsWith(_url.origin) || r.url.startsWith('about:')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      );
    _protocol = _newProtocol();
    unawaited(_controller.loadRequest(_url));
  }

  final Uri _url;
  late final WebViewController _controller;
  late EngineProtocol _protocol;
  final _status = ValueNotifier(EngineStatus.loading);
  final _events = StreamController<EngineEvent>.broadcast();
  StreamSubscription<EngineEvent>? _sub;
  var _pageLoads = 0;
  var _disposed = false;

  // The last load, replayed after a page reload.
  Json? _lastLoad;

  @override
  ValueListenable<EngineStatus> get status => _status;

  @override
  Stream<EngineEvent> get events => _events.stream;

  EngineProtocol _newProtocol() {
    final p = EngineProtocol(_controller.runJavaScript);
    unawaited(_sub?.cancel());
    _sub = p.events.listen((e) {
      if (e.name == 'error' && e.data['fatal'] == true) _status.value = EngineStatus.failed;
      if (!_events.isClosed) _events.add(e);
    });
    p.ready.then((_) {
      if (!_disposed && identical(p, _protocol)) _status.value = EngineStatus.ready;
    }, onError: (Object _) {});
    return p;
  }

  void _restart() {
    _protocol.failAll(EngineException(l10nNow.editorMainEngineReloaded));
    _protocol.dispose();
    _status.value = EngineStatus.loading;
    _protocol = _newProtocol();
    final last = _lastLoad;
    if (last != null) unawaited(_call('load', last, const Duration(seconds: 90)).then((_) {}, onError: (_) {}));
  }

  void _fail(EngineException e) {
    _protocol.failAll(e);
    _status.value = EngineStatus.failed;
  }

  Future<Object?> _call(String method, [Json? params, Duration? timeout]) async {
    if (_disposed) throw EngineException(l10nNow.editorMainEngineClosed);
    if (_status.value == EngineStatus.failed) {
      throw _protocol.fatalError ?? EngineException(l10nNow.editorMainEngineBroken);
    }
    // Calls made before `ready` are queued by the page itself, but the
    // channel only exists once the page has loaded: wait for ready.
    await _protocol.ready.timeout(const Duration(seconds: 60), onTimeout: () {
      throw EngineException(l10nNow.editorMainEngineLoadFailed, timeout: true);
    });
    return _protocol.call(method, params, timeout);
  }

  Json _obj(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  @override
  Widget buildView() => WebViewWidget(controller: _controller);

  @override
  Future<EngineProduct> load({required String productSlug, int? variantId, int? colorId}) async {
    final params = {'productSlug': productSlug, 'variantId': ?variantId, 'colorId': ?colorId};
    final result = await _call('load', params, const Duration(seconds: 90));
    final product = EngineProduct.fromJson(_obj(result));
    _lastLoad = {'productSlug': productSlug, 'variantId': product.variantId, 'colorId': product.colorId};
    return product;
  }

  @override
  Future<EngineProduct> setAppearance({int? variantId, int? colorId}) async {
    final result = await _call(
      'setAppearance',
      {'variantId': ?variantId, 'colorId': ?colorId},
      const Duration(seconds: 90),
    );
    final product = EngineProduct.fromJson(_obj(result));
    final last = _lastLoad;
    if (last != null) _lastLoad = {...last, 'variantId': product.variantId, 'colorId': product.colorId};
    return product;
  }

  @override
  Future<Json> setDocument(DesignDocument document) async =>
      _obj(await _call('setDocument', {'document': document.toJson()}, const Duration(seconds: 60)));

  @override
  Future<void> showArea(String key) => _call('showArea', {'key': key});

  @override
  Future<void> resetView() => _call('resetView');

  @override
  Future<List<String>> captureFrames({int size = 900, List<String>? areas}) async {
    final result = _obj(await _call(
      'captureFrames',
      {'size': size, if (areas != null && areas.isNotEmpty) 'areas': areas},
      const Duration(seconds: 120),
    ));
    return result.strings('frames');
  }

  @override
  Future<String> captureView({int size = 1600}) async {
    final result = _obj(await _call('captureView', {'size': size}, const Duration(seconds: 60)));
    return result.str('image');
  }

  @override
  Future<List<EnginePrintFile>> renderPrintFiles() async {
    final result = _obj(await _call('renderPrintFiles', null, const Duration(minutes: 5)));
    return result.list('files', EnginePrintFile.fromJson);
  }

  @override
  Future<Map<String, String>> measure() async {
    final result = _obj(await _call('measure', null, const Duration(seconds: 60)));
    return {for (final e in result.obj('areasCm2').entries) e.key: '${e.value}'};
  }

  @override
  Future<void> reload() async {
    _status.value = EngineStatus.loading;
    await _controller.loadRequest(_url);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_sub?.cancel());
    _protocol.dispose();
    unawaited(_events.close());
    _status.dispose();
    // Free the page (WebGL context) right away.
    unawaited(_controller.loadRequest(Uri.parse('about:blank')).catchError((_) {}));
  }
}

/// One engine per editor screen (created lazily, freed when the editor closes).
final designEngineProvider = Provider.autoDispose<DesignEngine>((ref) {
  final engine = WebDesignEngine();
  ref.onDispose(engine.dispose);
  return engine;
});
