/// Small, forgiving readers for hand-written `fromJson` factories. The API is
/// ours and typed, but a missing optional field should never crash a screen.
typedef Json = Map<String, dynamic>;

extension JsonRead on Json {
  String str(String key, [String fallback = '']) {
    final v = this[key];
    return v == null ? fallback : v.toString();
  }

  String? strOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  int integer(String key, [int fallback = 0]) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  int? intOrNull(String key) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double dbl(String key, [double fallback = 0]) {
    final v = this[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  bool boolean(String key, [bool fallback = false]) {
    final v = this[key];
    return v is bool ? v : fallback;
  }

  DateTime? date(String key) {
    final v = this[key];
    return v is String ? DateTime.tryParse(v) : null;
  }

  Json obj(String key) {
    final v = this[key];
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }

  Json? objOrNull(String key) {
    final v = this[key];
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  /// A list of objects mapped with [fromJson]; non-object entries are skipped.
  List<T> list<T>(String key, T Function(Json json) fromJson) {
    final v = this[key];
    if (v is! List) return const [];
    return [
      for (final e in v)
        if (e is Map) fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  List<String> strings(String key) {
    final v = this[key];
    if (v is! List) return const [];
    return [for (final e in v) if (e != null) e.toString()];
  }
}

/// Maps a decoded JSON array (a `List<dynamic>` response body).
List<T> mapList<T>(Object? data, T Function(Json json) fromJson) {
  if (data is! List) return const [];
  return [
    for (final e in data)
      if (e is Map) fromJson(Map<String, dynamic>.from(e)),
  ];
}
