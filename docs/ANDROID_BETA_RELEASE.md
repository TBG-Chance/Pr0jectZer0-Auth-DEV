# Android closed-beta release process

Pr0jectZer0 Auth is distributed as a signed Android App Bundle through Google
Play's Internal Testing track. Testers receive a private opt-in link and future
beta updates through Google Play.

## One-time upload-key setup

Create and protect a dedicated Android upload key. Do this once, outside the
repository:

```powershell
keytool -genkeypair -v `
  -keystore "C:\Secure\Pr0jectZer0-upload-keystore.jks" `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload
```

Keep an offline backup of the keystore and its passwords. Losing the upload key
interrupts the ability to deliver updates. Never commit the keystore or
`android/key.properties`.

Encode the keystore for GitHub Actions:

```powershell
[Convert]::ToBase64String(
  [IO.File]::ReadAllBytes("C:\Secure\Pr0jectZer0-upload-keystore.jks")
) | Set-Clipboard
```

Create these Actions secrets in `Pr0jectZer0-Auth-DEV`:

- `ANDROID_UPLOAD_KEYSTORE_BASE64`
- `ANDROID_UPLOAD_STORE_PASSWORD`
- `ANDROID_UPLOAD_KEY_PASSWORD`
- `ANDROID_UPLOAD_KEY_ALIAS` (normally `upload`)

## One-time Google Play setup

1. Create the application in Google Play Console with package name
   `com.pr0jectzer0.pr0jectzer0_auth`.
2. Enable Play App Signing.
3. Complete the required app listing, privacy, data-safety, content-rating, and
   testing declarations.
4. Run **Android Beta Release** once with **Upload to Play** disabled.
5. Download the signed `.aab` workflow artifact and upload that first bundle
   manually in Play Console's Internal Testing track.
6. Create a Google Play Developer API service account, grant it permission to
   manage testing releases for this app, and store its JSON as the Actions
   secret `PLAY_SERVICE_ACCOUNT_JSON`.

Google Play requires the package to exist before an automated API upload can
work. Keep the first automated uploads in `draft` status until the Play listing
and review state permit completed internal releases.

## Produce an Android beta

1. Open **Actions > Android Beta Release > Run workflow**.
2. Enter the same product version used for the Windows beta.
3. Enter a new build number. It must be higher than every version code already
   uploaded to Google Play.
4. Enable **Upload to Play** after the one-time setup is complete.
5. Choose `completed` only when the build should immediately reach internal
   testers; otherwise choose `draft` and review it in Play Console.
6. Share the Internal Testing opt-in URL with the approved tester email list.

## Local signed build

Create `android/key.properties` as described by Flutter's Android signing guide,
then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\scripts\build-android-release.ps1 `
  -VersionName "0.6.0-beta.1" `
  -BuildNumber 1
```

The script analyzes, tests, signs, and places the release bundle and checksum in
`release\android`.

## Beta network requirement

Release builds reject cleartext HTTP. The phone must reach the enrolled
Pr0jectZer0 server over HTTPS, and the tester must verify the installation
server fingerprint shown during enrollment. Public Wi-Fi, direct port
forwarding, and internet exposure without the approved HTTPS and firewall
deployment remain outside the beta boundary.

Builds are released only for the Android versions and physical-device
conditions in `docs/ANDROID_SUPPORT_MATRIX.md`.
