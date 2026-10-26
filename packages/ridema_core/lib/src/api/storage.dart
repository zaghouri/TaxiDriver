import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/user.dart';

/// Where tokens live. Production uses [SecureTokenStore]; tests use [MemoryTokenStore].
abstract class TokenStore {
  /// Loads tokens from storage into memory (call once at start).
  Future<void> load();

  /// In-memory access token (null when logged out).
  String? get accessToken;
  String? get refreshToken;

  Future<void> save(Tokens tokens);
  Future<void> clear();

  bool get hasSession => (accessToken?.isNotEmpty ?? false) && (refreshToken?.isNotEmpty ?? false);
}

/// Tokens in the Android Keystore / iOS Keychain via flutter_secure_storage.
class SecureTokenStore extends TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'ridema.access_token';
  static const _refreshKey = 'ridema.refresh_token';

  final FlutterSecureStorage _storage;
  String? _access;
  String? _refresh;

  @override
  String? get accessToken => _access;
  @override
  String? get refreshToken => _refresh;

  @override
  Future<void> load() async {
    try {
      _access = await _storage.read(key: _accessKey);
      _refresh = await _storage.read(key: _refreshKey);
    } catch (_) {
      // Keystore can fail after a backup restore: start logged out.
      _access = _refresh = null;
      await clear();
    }
  }

  @override
  Future<void> save(Tokens tokens) async {
    _access = tokens.accessToken;
    _refresh = tokens.refreshToken;
    try {
      await _storage.write(key: _accessKey, value: tokens.accessToken);
      await _storage.write(key: _refreshKey, value: tokens.refreshToken);
    } catch (_) {
      // Keep the in-memory session for this run.
    }
  }

  @override
  Future<void> clear() async {
    _access = _refresh = null;
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (_) {}
  }
}

/// Tokens kept in memory only (tests, previews).
class MemoryTokenStore extends TokenStore {
  MemoryTokenStore({String? access, String? refresh}) {
    _access = access;
    _refresh = refresh;
  }

  String? _access;
  String? _refresh;
  int saveCount = 0;

  @override
  String? get accessToken => _access;
  @override
  String? get refreshToken => _refresh;
  @override
  Future<void> load() async {}
  @override
  Future<void> save(Tokens tokens) async {
    saveCount++;
    _access = tokens.accessToken;
    _refresh = tokens.refreshToken;
  }

  @override
  Future<void> clear() async {
    _access = _refresh = null;
  }
}

/// Stable per-install id sent as `X-Device-Id` (UUID v4 stored in shared_preferences).
class DeviceIdStore {
  DeviceIdStore._(this.deviceId);

  static const _key = 'ridema.device_id';
  final String deviceId;

  static Future<DeviceIdStore> load(SharedPreferences prefs) async {
    var id = prefs.getString(_key);
    if (id == null || id.length < 8) {
      id = const Uuid().v4();
      await prefs.setString(_key, id);
    }
    return DeviceIdStore._(id);
  }

  /// For tests.
  factory DeviceIdStore.fixed(String id) => DeviceIdStore._(id);
}
