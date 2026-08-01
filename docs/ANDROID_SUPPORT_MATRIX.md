# PZ Auth Android open-beta support matrix

Legal publisher: The Bostrom Group, LLC
Policy date: 2026-07-31

PZ Auth supports physical, Google-certified arm64 phones running Android 14,
15, 16, or 17. Each Android version must pass enrollment, login approval,
biometric/PIN fallback, credential rotation, revocation, lost-phone recovery,
Google Play update, and uninstall/reinstall tests before a release is promoted
to open beta.

| Android version | API level | Release policy |
| --- | ---: | --- |
| Android 14 | 34 | Minimum supported version |
| Android 15 | 35 | Supported |
| Android 16 | 36 | Primary target |
| Android 17 | 37 | Supported runtime after physical-device qualification |

Release builds set `minSdk` to 34 and `targetSdk` to 36. Before targeting API
37, implement and test Android 17's local-network permission declaration,
runtime request, denial handling, and user explanation.

Eligible phones must have a secure screen lock, an Android security patch no
more than 90 days old, Android Keystore support, and a locked bootloader.
Rooted devices, custom ROMs, emulators, tablets, foldables, Chromebooks,
Android Go devices, and 32-bit-only devices are outside the initial beta.

References:

- [Flutter supported platforms](https://docs.flutter.dev/reference/supported-platforms)
- [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Android platform version/API numbers](https://source.android.com/docs/setup/reference/build-numbers)
- [Android 17 behavior changes](https://developer.android.com/about/versions/17/behavior-changes-17)
