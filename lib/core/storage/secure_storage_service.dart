abstract interface class SecureStorageService {
  Future<void> initialize();

  Future<bool> containsKey(String key);

  Future<String?> read(String key);

  Future<void> write({required String key, required String value});

  Future<void> delete(String key);

  Future<void> dispose();
}
