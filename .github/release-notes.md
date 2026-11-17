## Install WhoTook 1.9.1

**Android:** pick the APK for your phone. Most modern phones use `WhoTook-1.9.1-arm64-v8a.apk`; older 32-bit phones use `WhoTook-1.9.1-armeabi-v7a.apk`. If you are unsure, use `WhoTook-1.9.1-universal.apk`, or the stable `WhoTook.apk` alias used by the website and Obtainium. Android asks you to allow installs from this source once.

**Automatic updates:** add `https://github.com/warreth/WhoTook` in Obtainium, or use the Add to Obtainium button on [whotook.party](https://whotook.party). The stable `WhoTook.apk` stays the universal build.

**iOS:** download `WhoTook-1.9.1-unsigned.ipa` (or the stable `WhoTook-unsigned.ipa` alias) and install it with SideStore or AltStore. TestFlight internal testers get the signed build from App Store Connect. The public App Store listing is not live yet. The source builds with Flutter 3.47 and Xcode 16 or newer.

**Play upload:** `WhoTook-1.9.1.aab`.

## What is in this release

- **Make It Meme photos stay put.** Each photo now has one cached image provider per photo id, so timer ticks and text updates cannot drop the decoded texture. The host looks up its own vault bytes too, and the creation countdown waits for every assigned photo before it starts. A short **Syncing vaults** progress bar covers a slow phone instead of opening a blank canvas.
- **Retransmits no longer break a transfer.** An identical duplicate chunk is ignored. A chunk that changes mid-photo is still rejected and the photo is verified by SHA-256 before it reaches the cache.
- **Fairer Mixed Party.** Every core mode appears in three or more rounds, counts stay within one of each other, and the same mode never runs twice in a row.
- **A real party soundtrack.** A looping lobby and gameplay track, layered button, swap, vote, timer and fanfare effects, and music that ducks to 25% during the last five seconds and reveals. Music and sound effects have separate switches in the home header, lobby and Settings.
- **iPhone 8 fits.** Compact spacing, smaller buttons, a shorter timer and a responsive meme canvas keep every action on one screen at 375 x 667. Tall phones keep the previous sizes.
- **Smaller fixes.** The QR code is smaller on compact phones, the lobby and podium keep their main action visible, and the timeline timer no longer crowds the date on small screens.

## Checks

- 345 Flutter tests, including the full three-player Make It Meme flow, 1,000 Mixed Party queues per round count, photo cache behavior, large text, 375 and 412 phone widths, and the FOSS build.
- `flutter analyze` clean.
- Normal and FOSS APKs build.
- Responsive captures checked at 375 x 667 and 412 x 915.

`SHA256SUMS.txt` contains the checksum of every attached file.
