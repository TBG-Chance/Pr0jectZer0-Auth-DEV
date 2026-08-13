# Device enrollment and dashboard approval

Pr0jectZer0 Auth implements the signed registered-device protocol shared with the Pr0jectZer0 server.

## Enrollment

Current enrollment QR codes use `pr0jectzer0://enroll` version 3. They carry the canonical HTTPS `server_url`, server Ed25519 identity, short-lived enrollment secret, and installation CA. The app verifies the server signature, identity fingerprint, CA fingerprint, device type, origin, and timestamps before sending the device public key to:

```text
POST /api/v1/auth/enrollment/complete
```

Version 2 signed enrollment remains supported for servers with a publicly trusted TLS certificate. Unsigned version 1 payloads are available only when the application is explicitly constructed in legacy-development mode.

Administrator invitation and lost-device recovery use signed `pr0jectzer0://activate` payloads and their dedicated activation endpoints.

## Dashboard login

Current dashboard QR codes use `pr0jectzer0://login` version 3. The signed payload includes the enrolled server identity and origin, one-time challenge and nonce, request and expiry timestamps, browser, operating system, network address, and six-digit comparison code.

The user must compare the code shown on the phone with the browser and authenticate with biometrics or the app PIN. The app signs the canonical version 3 challenge and submits only this body to:

```text
POST /api/v1/auth/login/approve

{
  "challenge_id": "...",
  "nonce": "...",
  "device_id": "...",
  "signature": "..."
}
```

Selecting **Deny** is a local dismissal. The browser polls the server and the unused challenge expires.

## Network boundary

Production Pr0jectZer0 defaults to HTTPS port `8443`, but the signed `server_url` is authoritative and its explicit port is preserved. PZ Auth does not discover or replace ports. Cleartext port `8080` is limited to explicitly enabled legacy development and must not be used for beta distribution.
