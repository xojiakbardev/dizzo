import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// An access + refresh token pair.
class TokenPair {
  const TokenPair({required this.access, required this.refresh});

  final String access;
  final String refresh;

  /// Reads the backend's `{access_token, refresh_token}` body.
  static TokenPair? fromJson(Map<String, dynamic> json) {
    final access = json['access_token'] ?? json['access'];
    final refresh = json['refresh_token'] ?? json['refresh'];
    if (access is! String || refresh is! String) return null;
    return TokenPair(access: access, refresh: refresh);
  }
}

/// Where tokens (and the cached signed-in user) live. Backed by the
/// Keychain / EncryptedSharedPreferences; tests use [MemoryTokenStorage].
abstract class TokenStorage {
  Future<TokenPair?> read();
  Future<void> write(TokenPair pair);
  Future<void> clear();

  /// A JSON copy of the last `/auth/me`, so the app opens signed in offline.
  Future<String?> readUser();
  Future<void> writeUser(String json);

  /// Small app flags (e.g. the welcome screen was seen).
  Future<String?> readFlag(String key);
  Future<void> writeFlag(String key, String value);
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  static const _access = 'auth.access';
  static const _refresh = 'auth.refresh';
  static const _user = 'auth.user';

  // Tokens are cached in memory: the interceptor reads them on every request.
  TokenPair? _cache;
  bool _loaded = false;

  @override
  Future<TokenPair?> read() async {
    if (_loaded) return _cache;
    try {
      final access = await _s.read(key: _access);
      final refresh = await _s.read(key: _refresh);
      _cache = access != null && refresh != null
          ? TokenPair(access: access, refresh: refresh)
          : null;
    } catch (_) {
      // A keystore reset after a backup restore: start signed out.
      _cache = null;
      await _safeDeleteAll();
    }
    _loaded = true;
    return _cache;
  }

  @override
  Future<void> write(TokenPair pair) async {
    _cache = pair;
    _loaded = true;
    await _s.write(key: _access, value: pair.access);
    await _s.write(key: _refresh, value: pair.refresh);
  }

  @override
  Future<void> clear() async {
    _cache = null;
    _loaded = true;
    await _s.delete(key: _access);
    await _s.delete(key: _refresh);
    await _s.delete(key: _user);
  }

  @override
  Future<String?> readUser() async {
    try {
      return await _s.read(key: _user);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeUser(String json) => _s.write(key: _user, value: json);

  @override
  Future<String?> readFlag(String key) async {
    try {
      return await _s.read(key: 'flag.$key');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeFlag(String key, String value) =>
      _s.write(key: 'flag.$key', value: value);

  Future<void> _safeDeleteAll() async {
    try {
      await _s.deleteAll();
    } catch (_) {}
  }
}

class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage([this.pair]);

  TokenPair? pair;
  String? user;
  final flags = <String, String>{};

  @override
  Future<TokenPair?> read() async => pair;
  @override
  Future<void> write(TokenPair pair) async => this.pair = pair;
  @override
  Future<void> clear() async {
    pair = null;
    user = null;
  }

  @override
  Future<String?> readUser() async => user;
  @override
  Future<void> writeUser(String json) async => user = json;
  @override
  Future<String?> readFlag(String key) async => flags[key];
  @override
  Future<void> writeFlag(String key, String value) async => flags[key] = value;
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());
