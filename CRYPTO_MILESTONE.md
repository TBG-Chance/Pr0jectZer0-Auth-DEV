# Crypto Service Milestone

Implemented:

- Reusable `CryptoService` contract
- Ed25519 device identity generation
- Secure persistence through `SecureStorageService`
- Public-key export with stable key ID and SHA-256 fingerprint
- Payload signing and signature verification
- Identity rotation and deletion
- Versioned identity record
- Unit tests for persistence, signing, tamper detection, and rotation

Security boundary:

The current provider stores the 32-byte Ed25519 seed inside the platform secure-storage service. This provides Keychain/Keystore-backed encrypted storage, but it is not yet a truly non-exportable hardware key. The `CryptoService` abstraction is designed so a native StrongBox/Secure Enclave provider can replace this implementation during production hardening.
