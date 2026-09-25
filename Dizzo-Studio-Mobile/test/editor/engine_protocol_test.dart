import 'dart:convert';

import 'package:dizzo/features/editor/data/engine_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> sent;
  late EngineProtocol p;

  Map<String, dynamic> lastRequest() {
    // window.dizzoEngine && window.dizzoEngine.call("<json>")
    final js = sent.last;
    final arg = js.substring(js.indexOf('call(') + 5, js.length - 1);
    return jsonDecode(jsonDecode(arg) as String) as Map<String, dynamic>;
  }

  setUp(() {
    sent = [];
    p = EngineProtocol((js) async => sent.add(js), defaultTimeout: const Duration(milliseconds: 200));
  });

  tearDown(() => p.dispose());

  test('matches responses to requests by id', () async {
    final a = p.call('ping');
    final b = p.call('showArea', {'key': 'back'});
    await Future<void>.delayed(Duration.zero);
    expect(lastRequest(), {'id': 'm2', 'method': 'showArea', 'params': {'key': 'back'}});
    p.receive(jsonEncode({'id': 'm2', 'ok': true, 'result': {'area': 'back'}}));
    p.receive(jsonEncode({'id': 'm1', 'ok': false, 'error': 'no product loaded: call load first'}));
    expect(await b, {'area': 'back'});
    await expectLater(a, throwsA(isA<EngineException>().having((e) => e.message, 'message', contains('no product'))));
  });

  test('joins chunked messages in index order', () async {
    final call = p.call('renderPrintFiles');
    final full = jsonEncode({'id': 'm1', 'ok': true, 'result': {'files': [{'area': 'front', 'dataUrl': 'data:image/png;base64,QUJD'}]}});
    final parts = [full.substring(0, 10), full.substring(10, 30), full.substring(30)];
    p.receive(jsonEncode({'chunk': {'id': 1, 'index': 2, 'count': 3}, 'data': parts[2]}));
    p.receive(jsonEncode({'chunk': {'id': 1, 'index': 0, 'count': 3}, 'data': parts[0]}));
    p.receive(jsonEncode({'chunk': {'id': 1, 'index': 1, 'count': 3}, 'data': parts[1]}));
    final result = await call as Map;
    expect((result['files'] as List).single['area'], 'front');
    expect(await dataUrlBytes('data:image/png;base64,QUJD'), utf8.encode('ABC'));
    expect(dataUrlType('data:image/jpeg;base64,xx'), 'image/jpeg');
  });

  test('times out and ignores the late answer', () async {
    final call = p.call('captureFrames');
    await expectLater(call, throwsA(isA<EngineException>().having((e) => e.timeout, 'timeout', isTrue)));
    p.receive(jsonEncode({'id': 'm1', 'ok': true, 'result': {}}));
  });

  test('ready and fatal events', () async {
    final events = <String>[];
    p.events.listen((e) => events.add(e.name));
    p.receive(jsonEncode({'event': 'ready', 'version': 1, 'chunkChars': 8000000}));
    await p.ready;
    expect(p.isReady, isTrue);
    final pending = p.call('load', {'productSlug': 'x'});
    p.receive(jsonEncode({'event': 'error', 'message': 'WebGL yo‘q', 'fatal': true}));
    await expectLater(pending, throwsA(isA<EngineException>().having((e) => e.fatal, 'fatal', isTrue)));
    await expectLater(p.call('ping'), throwsA(isA<EngineException>()));
    await Future<void>.delayed(Duration.zero);
    expect(events, ['ready', 'error']);
    p.receive('not json');
  });
}
