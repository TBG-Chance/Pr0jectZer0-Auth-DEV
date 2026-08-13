# PZ Auth push and beta readiness

## Repository roles

- `Pr0jectZer0-Auth-DEV` is the active working repository.
- `Pr0jectZer0-Auth` is the public showcase repository and should receive only curated, reviewed changes.

## Confirmed integration contract

- Release Pr0jectZer0 servers listen on HTTPS port `8443` by default.
- PZ Auth uses the exact canonical `server_url` in the signed enrollment payload, including any explicitly configured port; it does not substitute a hard-coded port.
- Enrollment completes at `POST /api/v1/auth/enrollment/complete`.
- Dashboard approval posts to `POST /api/v1/auth/login/approve`.
- Cleartext port `8080` is development-only and is not accepted by a release PZ Auth build.

## Before open beta

- Create and back up the Android upload key, then configure the four `ANDROID_UPLOAD_*` repository secrets described in `ANDROID_BETA_RELEASE.md`.
- Run the signed beta workflow without Play upload and verify the resulting App Bundle certificate fingerprint.
- Complete a physical Android 14-16 test against a release Pr0jectZer0 server using its real installation CA.
- Configure the Play listing, privacy policy, data-safety form, content rating, tester group, support route, and rollback procedure.
- Exercise device loss/recovery, key rotation, replay rejection, PIN lockout, biometric fallback, expired challenges, and server certificate rotation.
- Keep the public showcase repository curated; do not mirror development secrets, signing material, private deployment details, or unfinished release artifacts.
