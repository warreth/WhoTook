## Install WhoTook 1.8.0

**Android:** pick the APK for your phone. Most modern phones use `WhoTook-1.8.0-arm64-v8a.apk`; older 32-bit phones use `WhoTook-1.8.0-armeabi-v7a.apk`. If you are unsure, use `WhoTook-1.8.0-universal.apk`, or the stable `WhoTook.apk` alias used by the website and Obtainium. Android asks you to allow installs from this source once.

**Automatic updates:** add `https://github.com/warreth/WhoTook` in Obtainium, or use the Add to Obtainium button on [whotook.party](https://whotook.party). The stable `WhoTook.apk` stays the universal build.

**iOS:** download `WhoTook-1.8.0-unsigned.ipa` (or the stable `WhoTook-unsigned.ipa` alias) and install it with SideStore or AltStore. The App Store build is not live yet. The source builds with Flutter 3.47 and Xcode 16 or newer.

**Play upload:** `WhoTook-1.8.0.aab`.

## What is in this release

- **Make It Meme.** Every player fills a six-photo vault. You get one photo from another player, pick one of seven templates, add text and send it to the anonymous vote. The room votes up, meh or down.
- **Five swaps per match.** Reroll the whole six-photo vault before Ready, or swap the assigned meme photo from the editor. The five swaps cover the whole match.
- **Royalties and top memes.** The creator of the winning meme scores, and the photo owner gets a model royalty. The podium keeps the top three memes and can save them to your gallery.
- **A new Time Traveler reveal.** The evidence board keeps the photo, adds the year line and pins every guess with red string. The closest and furthest guesses get their own awards.
- **A tactile game feel.** Hard shadows, chunky buttons, a panic timer, confetti, seven generated sound cues and haptics. Sound and haptics have their own switches in Settings.
- **A refreshed lobby and home.** The chosen mode now sits in its own card, the photo check matches the chosen mode, and the setup flow matches the game.
- **Both themes, both languages.** The new screens are checked in light and dark mode, in English and Nederlands.

## Checks

- 267 Flutter tests, including the full three-player Make It Meme flow and large-text checks. The three store-capture tests are opt-in.
- `dart analyze` clean.
- Store screenshots regenerated at 1170 x 2340, 1320 x 2868 and 2064 x 2752.

`SHA256SUMS.txt` contains the checksum of every attached file.
