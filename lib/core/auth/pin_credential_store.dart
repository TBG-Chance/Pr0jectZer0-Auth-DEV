import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../storage/secure_storage_keys.dart';
import '../storage/secure_storage_service.dart';

class PinCredentialStore {
  PinCredentialStore(
    this._storage, {
    int iterations = 210000,
  })  : _algorithm = Pbkdf2.hmacSha256(
          iterations: iterations,
          bits: 256,
        ),
        _iterations = iterations;

  static const int _recordVersion = 1;
  static const int _saltLength = 32;

  final SecureStorageService _storage;
  final Pbkdf2 _algorithm;
  final int _iterations;

  Future<bool> exists() {
    return _storage.containsKey(SecureStorageKeys.pinCredential);
  }

  Future<void> create(String pin) async {
    if (await exists()) {
      throw StateError('A PIN credential already exists.');
    }
    await _save(pin);
  }

  Future<void> replace(String pin) => _save(pin);

  Future<bool> verify(String pin) async {
    final encoded = await _storage.read(SecureStorageKeys.pinCredential);
    if (encoded == null) return false;

    final record = _PinCredentialRecord.decode(encoded);
    final candidate = await _derive(
      pin,
      record.salt,
      iterations: record.iterations,
    );
    return _constantTimeEquals(candidate, record.hash);
  }

  Future<void> delete() {
    return _storage.delete(SecureStorageKeys.pinCredential);
  }

  Future<void> _save(String pin) async {
    final salt = _randomBytes(_saltLength);
    final hash = await _derive(pin, salt);
    final record = _PinCredentialRecord(
      version: _recordVersion,
      algorithm: 'PBKDF2-HMAC-SHA256',
      iterations: _iterations,
      salt: salt,
      hash: hash,
    );

    await _storage.write(
      key: SecureStorageKeys.pinCredential,
      value: record.encode(),
    );
  }

  Future<List<int>> _derive(
    String pin,
    List<int> salt, {
    int? iterations,
  }) async {
    final algorithm = iterations == null || iterations == _iterations
        ? _algorithm
        : Pbkdf2.hmacSha256(iterations: iterations, bits: 256);
    final key = await algorithm.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );
    return key.extractBytes();
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}

class _PinCredentialRecord {
  const _PinCredentialRecord({
    required this.version,
    required this.algorithm,
    required this.iterations,
    required this.salt,
    required this.hash,
  });

  final int version;
  final String algorithm;
  final int iterations;
  final List<int> salt;
  final List<int> hash;

  String encode() {
    return jsonEncode(<String, Object>{
      'version': version,
      'algorithm': algorithm,
      'iterations': iterations,
      'salt': base64UrlEncode(salt),
      'hash': base64UrlEncode(hash),
    });
  }

  static _PinCredentialRecord decode(String value) {
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      final version = json['version'] as int;
      final algorithm = json['algorithm'] as String;
      final iterations = json['iterations'] as int;

      if (version != PinCredentialStore._recordVersion ||
          algorithm != 'PBKDF2-HMAC-SHA256' ||
          iterations <= 0) {
        throw const FormatException('Unsupported PIN credential format.');
      }

      return _PinCredentialRecord(
        version: version,
        algorithm: algorithm,
        iterations: iterations,
        salt: base64Url.decode(json['salt'] as String),
        hash: base64Url.decode(json['hash'] as String),
      );
    } on Object catch (error) {
      if (error is FormatException) rethrow;
      throw FormatException('PIN credential is invalid.', error);
    }
  }
}
