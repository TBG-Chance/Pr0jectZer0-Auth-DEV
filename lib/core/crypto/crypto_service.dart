import 'crypto_models.dart';

abstract interface class CryptoService {
  Future<void> initialize();

  Future<bool> hasDeviceIdentity();

  Future<DevicePublicKey> ensureDeviceIdentity();

  Future<DevicePublicKey?> getDevicePublicKey();

  Future<SignatureEnvelope> sign(List<int> payload);

  Future<bool> verify({
    required List<int> payload,
    required SignatureEnvelope signature,
    DevicePublicKey? publicKey,
  });

  Future<DevicePublicKey> rotateDeviceIdentity();

  Future<void> deleteDeviceIdentity();

  Future<void> dispose();
}
