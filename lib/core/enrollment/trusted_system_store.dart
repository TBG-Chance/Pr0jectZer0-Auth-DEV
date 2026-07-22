import 'dart:convert';

import '../models/trusted_system.dart';
import '../storage/secure_storage_keys.dart';
import '../storage/secure_storage_service.dart';

class TrustedSystemStore {
  const TrustedSystemStore(this._storage);

  final SecureStorageService _storage;

  Future<List<TrustedSystem>> readAll() async {
    final value = await _storage.read(SecureStorageKeys.trustedSystems);
    if (value == null) return const <TrustedSystem>[];

    try {
      final decoded = jsonDecode(value);
      if (decoded is! List<dynamic>) {
        throw const FormatException('Trusted systems record is not a list.');
      }
      return decoded
          .map((item) => TrustedSystem.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } on Object catch (error) {
      throw StateError('Stored trusted systems are invalid: $error');
    }
  }

  Future<void> writeAll(List<TrustedSystem> systems) async {
    await _storage.write(
      key: SecureStorageKeys.trustedSystems,
      value: jsonEncode(
        systems.map((system) => system.toJson()).toList(growable: false),
      ),
    );
  }
}
