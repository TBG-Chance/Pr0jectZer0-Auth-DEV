import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../storage/secure_storage_keys.dart';
import '../storage/secure_storage_service.dart';
import 'crypto_models.dart';
import 'crypto_service.dart';

class SecureEd25519CryptoService implements CryptoService {
  SecureEd25519CryptoService(this._storage, {Ed25519? algorithm})
    : _algorithm = algorithm ?? Ed25519();

  static const _algorithmName = 'Ed25519';
  static const _recordVersion = 1;

  final SecureStorageService _storage;
  final Ed25519 _algorithm;

  bool _initialized = false;
  bool _disposed = false;

  @override
  Future<void> initialize() async {
    _ensureActive();
    if (_initialized) return;
    _initialized = true;
  }

  @override
  Future<bool> hasDeviceIdentity() async {
    _ensureReady();
    return _storage.containsKey(SecureStorageKeys.deviceIdentity);
  }

  @override
  Future<DevicePublicKey> ensureDeviceIdentity() async {
    _ensureReady();
    final existing = await _readIdentity();
    if (existing != null) return existing.publicKey;
    return _createAndStoreIdentity();
  }

  @override
  Future<DevicePublicKey?> getDevicePublicKey() async {
    _ensureReady();
    return (await _readIdentity())?.publicKey;
  }

  @override
  Future<SignatureEnvelope> sign(List<int> payload) async {
    _ensureReady();
    final identity = await _readIdentity();
    if (identity == null) {
      throw StateError('Device identity has not been created.');
    }

    final keyPair = await _algorithm.newKeyPairFromSeed(identity.seed);
    final signature = await _algorithm.sign(payload, keyPair: keyPair);
    return SignatureEnvelope(
      algorithm: _algorithmName,
      keyId: identity.publicKey.keyId,
      signatureBase64Url: _encode(signature.bytes),
      signedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<bool> verify({
    required List<int> payload,
    required SignatureEnvelope signature,
    DevicePublicKey? publicKey,
  }) async {
    _ensureReady();
    if (signature.algorithm != _algorithmName) return false;

    final candidate = publicKey ?? await getDevicePublicKey();
    if (candidate == null || candidate.keyId != signature.keyId) return false;

    try {
      final simplePublicKey = SimplePublicKey(
        _decode(candidate.publicKeyBase64Url),
        type: KeyPairType.ed25519,
      );
      return _algorithm.verify(
        payload,
        signature: Signature(
          _decode(signature.signatureBase64Url),
          publicKey: simplePublicKey,
        ),
      );
    } on FormatException {
      return false;
    }
  }

  @override
  Future<DevicePublicKey> rotateDeviceIdentity() async {
    _ensureReady();
    await _storage.delete(SecureStorageKeys.deviceIdentity);
    return _createAndStoreIdentity();
  }

  @override
  Future<void> deleteDeviceIdentity() async {
    _ensureReady();
    await _storage.delete(SecureStorageKeys.deviceIdentity);
  }

  Future<DevicePublicKey> _createAndStoreIdentity() async {
    final keyPair = await _algorithm.newKeyPair();
    final seed = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    final createdAt = DateTime.now().toUtc();
    final fingerprint = await _fingerprint(publicKey.bytes);
    final keyId = 'pz-${fingerprint.substring(0, 24).toLowerCase()}';

    final record = <String, Object>{
      'version': _recordVersion,
      'algorithm': _algorithmName,
      'keyId': keyId,
      'seed': _encode(seed),
      'publicKey': _encode(publicKey.bytes),
      'fingerprint': fingerprint,
      'createdAt': createdAt.toIso8601String(),
    };
    await _storage.write(
      key: SecureStorageKeys.deviceIdentity,
      value: jsonEncode(record),
    );

    return DevicePublicKey(
      algorithm: _algorithmName,
      keyId: keyId,
      publicKeyBase64Url: _encode(publicKey.bytes),
      fingerprint: fingerprint,
      createdAt: createdAt,
    );
  }

  Future<_StoredIdentity?> _readIdentity() async {
    final encoded = await _storage.read(SecureStorageKeys.deviceIdentity);
    if (encoded == null) return null;

    try {
      final json = jsonDecode(encoded);
      if (json is! Map<String, dynamic> ||
          json['version'] != _recordVersion ||
          json['algorithm'] != _algorithmName) {
        throw const FormatException('Unsupported device identity record.');
      }

      final seed = _decode(json['seed'] as String);
      final publicKeyBytes = _decode(json['publicKey'] as String);
      if (seed.length != 32 || publicKeyBytes.length != 32) {
        throw const FormatException('Invalid Ed25519 key material.');
      }

      return _StoredIdentity(
        seed: seed,
        publicKey: DevicePublicKey(
          algorithm: _algorithmName,
          keyId: json['keyId'] as String,
          publicKeyBase64Url: json['publicKey'] as String,
          fingerprint: json['fingerprint'] as String,
          createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        ),
      );
    } on Object catch (error) {
      throw StateError('Stored device identity is invalid: $error');
    }
  }

  Future<String> _fingerprint(List<int> publicKey) async {
    final digest = await Sha256().hash(publicKey);
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  String _encode(List<int> bytes) => base64UrlEncode(bytes).replaceAll('=', '');

  Uint8List _decode(String value) {
    final padding = '=' * ((4 - value.length % 4) % 4);
    return Uint8List.fromList(base64Url.decode('$value$padding'));
  }

  void _ensureReady() {
    _ensureActive();
    if (!_initialized) {
      throw StateError('CryptoService has not been initialized.');
    }
  }

  void _ensureActive() {
    if (_disposed) throw StateError('CryptoService has been disposed.');
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
  }
}

class _StoredIdentity {
  const _StoredIdentity({required this.seed, required this.publicKey});

  final List<int> seed;
  final DevicePublicKey publicKey;
}
