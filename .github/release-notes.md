## Install WhoTook 1.9.3

**Android:** pick the APK for your phone. Most modern phones use `WhoTook-1.9.3-arm64-v8a.apk`; older 32-bit phones use `WhoTook-1.9.3-armeabi-v7a.apk`. If you are unsure, use `WhoTook-1.9.3-universal.apk`, or the stable `WhoTook.apk` alias used by the website and Obtainium. Android asks you to allow installs from this source once.

**Automatic updates:** add `https://github.com/warreth/WhoTook` in Obtainium, or use the Add to Obtainium button on [whotook.party](https://whotook.party). The stable `WhoTook.apk` stays the universal build.

**iOS:** download `WhoTook-1.9.3-unsigned.ipa` (or the stable `WhoTook-unsigned.ipa` alias) and install it with SideStore or AltStore. TestFlight internal testers get the signed build from App Store Connect. The public App Store listing is not live yet. The source builds with Flutter 3.47 and Xcode 16 or newer.

**Play upload:** `WhoTook-1.9.3.aab`.

**Party Pass:** GitHub and SideStore builds add a license-key path for the Party Pass. The secure online checkout is built in and switches on once the live Paddle catalogue and Worker secrets are configured. Google Play and App Store builds keep their store purchase when the listings go live.

## What is in this release

- **Party Pass outside the stores.** GitHub and SideStore builds can restore a Party Pass with a license key instead of pointing people back to a store they did not install from.
- **A safer saved pass.** The receipt or license is stored in the device keychain or keystore. The app checks it on startup and locks the pass again when the server says it was revoked.
- **Same Wi-Fi stays free.** The Party Pass sheet, the firewall prompt and the onboarding card now say it plainly: local play is free, the pass is for Play Anywhere, the soundboard and shared themes.
- **The offline demo starts cleanly.** The demo no longer waits on screenshot or screen-awake platform services that are not needed for a solo match.
- **Fresh captures.** The site and store screenshots are regenerated from the current widgets, including the Party Pass sheet.

## Checks

- `flutter analyze` clean.
- Party Pass, Paddle checkout, credential storage and localization tests pass.
- The release workflow builds the signed APK, AAB and unsigned IPA.
- The site is checked at phone, tablet and desktop widths with no horizontal overflow.

`SHA256SUMS.txt` contains the checksum of every attached file.
