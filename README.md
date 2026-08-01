# pr0jectzer0_auth

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Secure storage foundation

Sensitive authentication values are stored through `SecureStorageService`.
The production implementation uses `flutter_secure_storage`, backed by Android
KeyStore and Apple Keychain. PINs are never stored directly: the app stores a
randomly salted PBKDF2-HMAC-SHA256 verifier and compares derived values in
constant time.

Android auto-backup is disabled because KeyStore keys are device-bound and
restoring encrypted preferences to another device can make them unreadable.
The open-beta minimum is Android 14 (API 34), and release builds target Android
16 (API 36). See `docs/ANDROID_SUPPORT_MATRIX.md` for the tested device policy.
