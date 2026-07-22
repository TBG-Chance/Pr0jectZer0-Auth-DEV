# Platform enrollment and dashboard approval

Pr0jectZer0 Auth implements version 1 of the private platform's
registered-device login protocol.

## User flow

- Enroll the phone once by scanning the platform's enrollment QR code.
- On a dashboard login, open **Approvals**, scan the displayed login QR code,
  and verify the trusted server details.
- Confirm with biometrics. If biometrics are unavailable or cancelled, enter
  the app-local PIN.
- The app signs the one-time challenge with its device-bound Ed25519 key and
  submits the approval to the enrolled server.

Biometric data, the app PIN, and the private key remain on the phone. A
successful phone approval is sufficient for the originating browser; the
browser does not request a second PIN.

## Shared version 1 contract

Enrollment QR codes use
`pr0jectzer0://enroll?v=1&server_id=...&server_name=...&server_url=...&organization=...&challenge_id=...&secret=...&issued_at=...&expires_at=...`.

Login QR codes use
`pr0jectzer0://login?v=1&server_id=...&challenge_id=...&nonce=...&expires_at=...`.

For login approval, the app signs these exact UTF-8 bytes, with no final
newline:

```text
pr0jectzer0-login-v1
<challenge_id>
<nonce>
<expires_at as Unix seconds>
```

The signature, nonce, one-time challenge ID, and platform-assigned device ID
are sent to `POST /api/v1/auth/login/approve` on the URL saved during
enrollment.

## Development networking

A real phone must be able to reach the platform URL embedded in the enrollment
QR code. Configure the platform's `PROJECTZERO_PUBLIC_URL` to a reachable
private-network URL or HTTPS hostname. Android permits cleartext private-network
testing only in debug builds. Production traffic should use HTTPS.
