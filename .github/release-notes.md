## Install WhoTook 1.9.2

**Android:** pick the APK for your phone. Most modern phones use `WhoTook-1.9.2-arm64-v8a.apk`; older 32-bit phones use `WhoTook-1.9.2-armeabi-v7a.apk`. If you are unsure, use `WhoTook-1.9.2-universal.apk`, or the stable `WhoTook.apk` alias used by the website and Obtainium. Android asks you to allow installs from this source once.

**Automatic updates:** add `https://github.com/warreth/WhoTook` in Obtainium, or use the Add to Obtainium button on [whotook.party](https://whotook.party). The stable `WhoTook.apk` stays the universal build.

**iOS:** download `WhoTook-1.9.2-unsigned.ipa` (or the stable `WhoTook-unsigned.ipa` alias) and install it with SideStore or AltStore. TestFlight internal testers get the signed build from App Store Connect. The public App Store listing is not live yet. The source builds with Flutter 3.47 and Xcode 16 or newer.

**Play upload:** `WhoTook-1.9.2.aab`.

**Party Pass:** GitHub and SideStore builds buy the Party Pass through the secure Paddle checkout and can restore it with a license key. Google Play and App Store builds keep using their store purchase.

## What is in this release

- **The vault can no longer freeze.** Clients repeat their ready signal every 1.5 seconds until the round starts. The host checks readiness every 500 ms, and after 10 seconds a **Force start match** button appears so a lobby cannot stay stuck.
- **Meme photos stop flickering.** Every approved vault photo is transferred and cached once before Round 1. Meme messages now carry only the photo id and text, never another copy of the image. Retransmitted chunks for a finished photo are ignored safely.
- **Android audio no longer steals focus.** Music keeps game audio focus while every click, vote, timer and soundboard effect mixes without requesting focus. Turning sound effects off and on does not stop the soundtrack.
- **A longer party soundtrack.** The 60 second loop has a funk bassline, marimba lead, clap and hi-hat groove, and a louder climax. A faster percussion layer takes over in the final five seconds.
- **Music is synchronized across phones.** The host shares the track start time and each phone measures its clock offset, then seeks to the same beat when it joins or unmutes.
- **No photo is reused in a match.** Classic, Make It Meme, photo swaps and Time Traveler all draw from one match-wide used-photo set. The vault grows from 6 to 12 photos per player based on the match length and player count.
- **Fair Mixed Party rounds.** The 10 round schedule is 4 Classic, 3 Make It Meme and 3 Time Traveler, and the same mode never runs twice in a row. The round splash now shows the mode that is about to start, and single-mode games get varied prompts instead of repeating the mode name.
- **Meme reveals wait for the host.** The winning meme stays on screen until the host taps **Next Round**, while guests see that the host is still looking.
- **Every screen fits.** Classic, Make It Meme creation and voting, Time Traveler, the photo vault, lobby and podium keep their main actions, End Voting and Next Round visible on small phones and iPads. Tablets use a narrower content column.
- **A real offline demo.** Settings now opens a demo with three bots playing the actual game, including the vault, all three Mixed Party modes and the podium. No gallery, camera or network is used.

## Checks

- 356 Flutter tests, including the three-player Make It Meme flow, the 10-round Mixed Party schedule, unique photo assignments and swaps, the vault force-start fallback, meme payloads, the offline demo and six responsive viewport profiles.
- `flutter analyze` clean.
- The full test suite passes.
- Marketing screenshots and store captures regenerated from the real widgets.

`SHA256SUMS.txt` contains the checksum of every attached file.
