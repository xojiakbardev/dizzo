import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../domain/editor_models.dart';

/// The web's sticker library (`public/stickers`, `app/lib/design/stickers.ts`),
/// read from the site so the app, the 3D view and the print files draw the
/// same SVGs: `index.json` + `more.json`, single SVG files, and icon packs
/// (`packs/<pk>.json`: name → SVG markup).
class StickerLibrary {
  StickerLibrary(this._dio, {String? base}) : _base = base ?? '${Env.siteUrl}/stickers';

  final Dio _dio;
  final String _base;

  Future<StickerIndex>? _index;
  final _svgs = <String, String>{};
  final _loads = <String, Future<void>>{};
  Map<String, String>? _packOf;

  /// Goes up whenever SVGs arrive, so lists showing them redraw.
  final revision = ValueNotifier(0);

  Future<Object?> _get(String url) async {
    final res = await _dio.get<Object?>(url, options: Options(responseType: ResponseType.json));
    return res.data;
  }

  StickerIndex _parse(Object? data) =>
      data is Map ? StickerIndex.fromJson(Map<String, dynamic>.from(data)) : const StickerIndex([], []);

  /// Both indexes, merged (the icons' one may fail on its own).
  Future<StickerIndex> index() {
    return _index ??= () async {
      try {
        final main = _parse(await _get('$_base/index.json'));
        StickerIndex? more;
        try {
          more = _parse(await _get('$_base/more.json'));
        } catch (_) {}
        return more == null ? main : main.merge(more);
      } catch (e) {
        _index = null;
        throw ApiException.from(e);
      }
    }();
  }

  /// The SVG markup, once loaded (see [ensure]).
  String? svg(String name) => _svgs[name];

  /// Loads the SVGs of these stickers (single files or their packs).
  Future<void> ensure(Iterable<String> names) async {
    final wanted = names.where((n) => !_svgs.containsKey(n)).toSet();
    if (wanted.isEmpty) return;
    final packed = wanted.where(isPackedSticker).toList();
    final single = wanted.where((n) => !isPackedSticker(n));
    final jobs = <Future<void>>[for (final n in single) _load('file:$n', () => _loadFile(n))];
    if (packed.isNotEmpty) {
      if (_packOf == null) {
        final idx = await index();
        _packOf = {for (final i in idx.items) if (i.pack != null) i.name: i.pack!};
      }
      final packs = {for (final n in packed) ?_packOf![n]};
      jobs.addAll(packs.map((pk) => _load('pack:$pk', () => _loadPack(pk))));
    }
    await Future.wait(jobs.map((j) => j.catchError((_) {})));
  }

  Future<void> _load(String key, Future<void> Function() run) {
    return _loads[key] ??= run().catchError((Object e) {
      _loads.remove(key);
      throw e;
    });
  }

  Future<void> _loadFile(String name) async {
    final res = await _dio.get<String>('$_base/$name.svg', options: Options(responseType: ResponseType.plain));
    final body = res.data;
    if (body != null && body.contains('<svg')) {
      _svgs[name] = body;
      revision.value++;
    }
  }

  Future<void> _loadPack(String pk) async {
    final data = await _get('$_base/packs/$pk.json');
    if (data is! Map) return;
    for (final e in data.entries) {
      if (e.value is String) _svgs['${e.key}'] = e.value as String;
    }
    revision.value++;
  }

  void dispose() => revision.dispose();
}

final stickerLibraryProvider = Provider<StickerLibrary>((ref) {
  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 60)));
  final lib = StickerLibrary(dio);
  ref.onDispose(() {
    lib.dispose();
    dio.close();
  });
  return lib;
});

final stickerIndexProvider = FutureProvider<StickerIndex>((ref) => ref.watch(stickerLibraryProvider).index());
