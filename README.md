# Pr0jectZer0 Auth

Pr0jectZer0 Auth is the Android companion authenticator for a self-hosted Pr0jectZer0 server. It enrolls a device from a signed dashboard QR code and uses that device's Ed25519 key to approve dashboard sign-in requests.

This is the active development repository. It is not yet approved for production use or public distribution.

## Security model

- Enrollment accepts signed `pr0jectzer0://enroll` payloads and administrator activation payloads.
- Login approval accepts signed `pr0jectzer0://login` payloads from an enrolled server.
- The app connects to the canonical HTTPS origin carried by signed enrollment data; the service port is not hard-coded in the app.
- Version 3 enrollment pins the installation CA for local HTTPS deployments.
- The device private key and salted PIN verifier stay in platform-protected storage.
- Approval requires biometrics or the app PIN, which has persistent retry lockout.
- Android backup, cleartext release traffic, and screenshots are disabled.
- Release builds fail unless the protected Android upload key is configured.

The open-beta installation floor is Android 14 (API 34), and release builds target Android 16 (API 36). See [the Android support matrix](docs/ANDROID_SUPPORT_MATRIX.md).

## Server contract

- Complete enrollment: `POST /api/v1/auth/enrollment/complete`
- Approve dashboard sign-in: `POST /api/v1/auth/login/approve`

The browser polls for challenge completion. Selecting **Deny** on the phone dismisses the request locally and lets the server challenge expire.

## Validate locally

```text
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

CI runs these checks for pull requests and pushes to `main`. Signed beta bundles are produced separately by the protected Android beta release workflow.

## Release preparation

Follow [the Android beta release guide](docs/ANDROID_BETA_RELEASE.md) to configure the upload certificate and Google Play Internal Testing. See [push readiness](docs/PUSH_READINESS.md) for the remaining beta gates and [the security policy](SECURITY.md) for private vulnerability reporting.
