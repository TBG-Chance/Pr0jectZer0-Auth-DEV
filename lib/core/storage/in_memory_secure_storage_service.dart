import 'secure_storage_service.dart';

class InMemorySecureStorageService implements SecureStorageService {
  final Map<String, String> _values = <String, String>{};
  bool _initialized = false;
  bool _disposed = false;

  Map<String, String> get debugValues => Map.unmodifiable(_values);

  @override
  Future<void> initialize() async {
    _ensureActive();
    _initialized = true;
  }

  @override
  Future<bool> containsKey(String key) async {
    _ensureReady();
    return _values.containsKey(key);
  }

  @override
  Future<String?> read(String key) async {
    _ensureReady();
    return _values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _ensureReady();
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _ensureReady();
    _values.remove(key);
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
    _values.clear();
  }
}
