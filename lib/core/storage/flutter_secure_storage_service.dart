import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage_keys.dart';
import 'secure_storage_service.dart';

class FlutterSecureStorageService implements SecureStorageService {
  FlutterSecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;
  bool _initialized = false;
  bool _disposed = false;

  @override
  Future<void> initialize() async {
    _ensureActive();
    if (_initialized) return;

    // Forces the platform channel and backing store to initialize early so
    // startup failures are detected before authentication is attempted.
    await _storage.containsKey(key: SecureStorageKeys.healthCheck);
    _initialized = true;
  }

  @override
  Future<bool> containsKey(String key) async {
    _ensureReady();
    return _storage.containsKey(key: key);
  }

  @override
  Future<String?> read(String key) async {
    _ensureReady();
    return _storage.read(key: key);
  }

  @override
  Future<void> write({
    required String key,
    required String value,
  }) async {
    _ensureReady();
    await _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) async {
    _ensureReady();
    await _storage.delete(key: key);
  }

  void _ensureReady() {
    _ensureActive();
    if (!_initialized) {
      throw StateError('SecureStorageService has not been initialized.');
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('SecureStorageService has been disposed.');
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
  }
}
