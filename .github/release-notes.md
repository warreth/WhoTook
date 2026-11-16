## Install WhoTook 1.9.0

**Android:** pick the APK for your phone. Most modern phones use `WhoTook-1.9.0-arm64-v8a.apk`; older 32-bit phones use `WhoTook-1.9.0-armeabi-v7a.apk`. If you are unsure, use `WhoTook-1.9.0-universal.apk`, or the stable `WhoTook.apk` alias used by the website and Obtainium. Android asks you to allow installs from this source once.

**Automatic updates:** add `https://github.com/warreth/WhoTook` in Obtainium, or use the Add to Obtainium button on [whotook.party](https://whotook.party). The stable `WhoTook.apk` stays the universal build.

**iOS:** download `WhoTook-1.9.0-unsigned.ipa` (or the stable `WhoTook-unsigned.ipa` alias) and install it with SideStore or AltStore. TestFlight internal testers get the signed build from App Store Connect. The public App Store listing is not live yet. The source builds with Flutter 3.47 and Xcode 16 or newer.

**Play upload:** `WhoTook-1.9.0.aab`.

## What is in this release

- **Make It Meme photos arrive.** A guest now asks the host for any missing photo chunk, while the canvas shows a photo shimmer instead of a black box. Vault bytes are verified before the assignment and cached by photo id on every phone.
- **Live meme text.** Top and bottom lines, POV headers, breaking-news banners, live reactions and the Snap Bar render on the photo as you type or move them.
- **One meme, one room.** The host owns the voting pointer, so every phone sees the same meme. A live `Waiting for votes: 2/3 voted` panel marks who has voted, the room advances when everyone is in, and the host can end a stuck vote after 12 seconds. The tally burst runs for 2.5 seconds and then everyone moves together.
- **Host-paced Time Traveler.** The reveal no longer disappears on a hidden timer. The host gets a pinned **Next Round** button and guests see `Waiting for host to continue...`.
- **A readable timeline.** Player pins stagger across lanes above and below the axis, close guesses cluster, and each pin points to its exact month. The actual-date polaroid stays highlighted.
- **Podium cleanup and winning meme.** The fourth-place player appears once, the action buttons stay pinned, and the match-winning meme now has a featured card with creator, vote split, model royalty and a working save button.
- **A proper party look.** Mode-specific animated backdrops, Fredoka display type, tilted sticker counters, custom sticker avatars, one-tap selfies, an arcade round splash, animated score bars, a circular bomb timer, and a new camera-question-mark logo and app icon.
- **Website refresh.** Sticky pill navigation, larger Make It Meme mockups, a new logo and OG image, and all app screenshots regenerated at 780 x 1688.
- **iOS privacy copy.** Photo, camera and local-network permission strings now explain the peer-to-peer flow in App Store language; the encryption exemption and associated-domains entitlement are in place.

## Checks

- 333 Flutter tests, including the full three-player Make It Meme flow, the new host-paced Time Traveler reveal, large text, 390 and 412 phone widths, and the FOSS build.
- `flutter analyze` clean.
- Normal and FOSS APKs build.
- Marketing screenshots regenerated from the real widgets at 780 x 1688.

`SHA256SUMS.txt` contains the checksum of every attached file.
