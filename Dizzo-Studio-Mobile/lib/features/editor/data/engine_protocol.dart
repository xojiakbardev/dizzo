import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/utils/json.dart';

// The request/response protocol of the web engine hosted in a WebView
// (Dizzo-Frontend/docs/EMBED_ENGINE.md), without the WebView: requests go
// out through [send] (JavaScript source), messages come in through
// [receive]. Big messages arrive in chunks and are joined here.

/// A failed engine call (or an engine that couldn't start).
class EngineException implements Exception {
  const EngineException(this.message, {this.fatal = false, this.timeout = false});

  final String message;
  final bool fatal;
  final bool timeout;

  @override
  String toString() => 'EngineException($message)';
}

/// An unsolicited engine message: `ready`, `loaded`, `error`, `view`.
class EngineEvent {
  const EngineEvent(this.name, this.data);

  final String name;
  final Json data;
}

class EngineProtocol {
  EngineProtocol(this.send, {this.defaultTimeout = const Duration(seconds: 30)});

  /// Runs JavaScript in the page.
  final Future<void> Function(String javascript) send;
  final Duration defaultTimeout;

  final _pending = <String, Completer<Object?>>{};
  final _timers = <String, Timer>{};
  final _chunks = <Object, Map<int, String>>{};
  final _chunkCounts = <Object, int>{};
  final _events = StreamController<EngineEvent>.broadcast();
  var _nextId = 0;
  EngineException? _fatal;
  final _ready = Completer<void>();

  Stream<EngineEvent> get events => _events.stream;

  /// Completes on the `ready` event (fails on a fatal error).
  Future<void> get ready => _ready.future;
  bool get isReady => _ready.isCompleted && _fatal == null;
  EngineException? get fatalError => _fatal;

  /// Calls [method]; resolves with its `result`.
  Future<Object?> call(String method, [Json? params, Duration? timeout]) async {
    if (_fatal != null) throw _fatal!;
    final id = 'm${++_nextId}';
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _timers[id] = Timer(timeout ?? defaultTimeout, () {
      _timers.remove(id);
      _pending.remove(id)?.completeError(EngineException(l10nNow.editorMainEngineNoAnswer, timeout: true));
    });
    final request = jsonEncode({'id': id, 'method': method, 'params': ?params});
    try {
      await send('window.dizzoEngine && window.dizzoEngine.call(${jsonEncode(request)})');
    } catch (_) {
      _finish(id)?.completeError(EngineException(l10nNow.editorMainEngineConnectFailed));
    }
    return completer.future;
  }

  Completer<Object?>? _finish(String id) {
    _timers.remove(id)?.cancel();
    return _pending.remove(id);
  }

  /// A message posted by the page (one string).
  void receive(String message) {
    Object? decoded;
    try {
      decoded = jsonDecode(message);
    } catch (_) {
      return; // not ours
    }
    if (decoded is! Map) return;
    final json = Map<String, dynamic>.from(decoded);
    final chunk = json['chunk'];
    if (chunk is Map) {
      _receiveChunk(chunk, json['data']);
      return;
    }
    _dispatch(json);
  }

  void _receiveChunk(Map<dynamic, dynamic> chunk, Object? data) {
    final id = chunk['id'] as Object? ?? 0;
    final index = (chunk['index'] as num?)?.toInt() ?? 0;
    final count = (chunk['count'] as num?)?.toInt() ?? 1;
    final parts = _chunks.putIfAbsent(id, () => {});
    parts[index] = data is String ? data : '';
    _chunkCounts[id] = count;
    if (parts.length < count) return;
    _chunks.remove(id);
    _chunkCounts.remove(id);
    final buffer = StringBuffer();
    for (var i = 0; i < count; i++) {
      buffer.write(parts[i] ?? '');
    }
    receive(buffer.toString());
  }

  void _dispatch(Json json) {
    final event = json['event'];
    if (event is String) {
      _onEvent(EngineEvent(event, json));
      return;
    }
    final id = json['id'];
    if (id is! String) {
      if (kDebugMode) debugPrint('[engine] unmatched message: ${json['error']}');
      return;
    }
    final completer = _finish(id);
    if (completer == null) return;
    if (json['ok'] == true) {
      completer.complete(json['result']);
    } else {
      completer.completeError(EngineException('${json['error'] ?? l10nNow.editorMainUnknownError}'));
    }
  }

  void _onEvent(EngineEvent e) {
    if (e.name == 'ready' && !_ready.isCompleted) _ready.complete();
    if (e.name == 'error' && e.data['fatal'] == true) {
      _fatal = EngineException('${e.data['message'] ?? l10nNow.editorMainEngineStartFailed}', fatal: true);
      if (!_ready.isCompleted) _ready.completeError(_fatal!);
      failAll(_fatal!);
    }
    if (!_events.isClosed) _events.add(e);
  }

  /// Fails every waiting call (page reload, crash).
  void failAll(EngineException error) {
    for (final id in [..._pending.keys]) {
      _finish(id)?.completeError(error);
    }
    _chunks.clear();
    _chunkCounts.clear();
  }

  void dispose() {
    failAll(EngineException(l10nNow.editorMainEngineClosed));
    unawaited(_events.close());
    if (!_ready.isCompleted) {
      _ready.future.ignore();
      _ready.completeError(EngineException(l10nNow.editorMainEngineClosed));
    }
  }
}

/// A `data:<type>;base64,…` URL's bytes (decoded off the UI isolate when big).
Future<Uint8List> dataUrlBytes(String dataUrl) async {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) throw EngineException(l10nNow.editorMainBadImage);
  final payload = dataUrl.substring(comma + 1);
  if (payload.length < 200000) return base64Decode(payload);
  return compute(base64Decode, payload);
}

/// `image/png` from `data:image/png;base64,…`.
String dataUrlType(String dataUrl) {
  final end = dataUrl.indexOf(';');
  return dataUrl.startsWith('data:') && end > 5 ? dataUrl.substring(5, end) : 'image/png';
}
