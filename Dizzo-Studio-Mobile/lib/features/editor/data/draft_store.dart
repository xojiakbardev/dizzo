import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/json.dart';
import '../domain/design_document.dart';

/// The design as it stands on this phone, written after every change so a
/// crash never loses work (the web's local draft, per product).
class LocalDraft {
  const LocalDraft({
    required this.variantId,
    required this.colorId,
    required this.document,
    this.size,
    this.designId,
    this.designVersion,
    this.guestMedia = const {},
  });

  factory LocalDraft.fromJson(Json j) => LocalDraft(
        variantId: j.integer('variantId'),
        colorId: j.integer('colorId'),
        size: j.strOrNull('size'),
        designId: j.strOrNull('designId'),
        designVersion: j.intOrNull('designVersion'),
        document: DesignDocument.fromJson(j.obj('document')),
        guestMedia: {for (final e in j.obj('guestMedia').entries) e.key: '${e.value}'},
      );

  final int variantId;
  final int colorId;
  final String? size;

  /// The saved design this draft edits (null: not saved in an account yet).
  final String? designId;
  final int? designVersion;
  final DesignDocument document;

  /// Guest uploads (media id → URL), claimed after sign-in.
  final Map<String, String> guestMedia;

  Json toJson() => {
        'variantId': variantId,
        'colorId': colorId,
        'size': size,
        'designId': designId,
        'designVersion': designVersion,
        'document': document.toJson(),
        'guestMedia': guestMedia,
      };
}

class DraftStore {
  DraftStore([this._dir]);

  Directory? _dir;

  Future<Directory> _root() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}editor_drafts');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return _dir = dir;
  }

  String _name(String slug) => '${Uri.encodeComponent(slug)}.json';

  Future<LocalDraft?> read(String slug) async {
    try {
      final file = File('${(await _root()).path}${Platform.pathSeparator}${_name(slug)}');
      if (!file.existsSync()) return null;
      final json = jsonDecode(await file.readAsString());
      return json is Map ? LocalDraft.fromJson(Map<String, dynamic>.from(json)) : null;
    } catch (e) {
      debugPrint('[editor] draft unreadable: $e');
      return null;
    }
  }

  /// Written to a temporary file first, so a crash mid-write keeps the old draft.
  Future<void> write(String slug, LocalDraft draft) {
    // One write at a time: they share the temporary file.
    return _writing = _writing.then((_) => _write(slug, draft));
  }

  Future<void> _writing = Future.value();

  Future<void> _write(String slug, LocalDraft draft) async {
    try {
      final root = await _root();
      final path = '${root.path}${Platform.pathSeparator}${_name(slug)}';
      final tmp = File('$path.tmp');
      await tmp.writeAsString(jsonEncode(draft.toJson()), flush: true);
      await tmp.rename(path);
    } catch (e) {
      debugPrint('[editor] draft not written: $e');
    }
  }

  Future<void> delete(String slug) async {
    try {
      final file = File('${(await _root()).path}${Platform.pathSeparator}${_name(slug)}');
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }
}

final draftStoreProvider = Provider<DraftStore>((ref) => DraftStore());
