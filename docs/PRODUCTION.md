# Production checklist

This is the maintainer checklist for shipping WhoTook. The product and store
copy are ready; the items below need accounts, certificates or a physical
device.

## Already in the repository

- Version `1.8.0+12` in `app/pubspec.yaml` and `app/lib/core/constants.dart`.
- Release workflow for a signed AAB, universal/split APKs, an unsigned IPA and
  an optional App Store upload. The Google Play and App Store jobs enable
  themselves when their secrets exist.
- iOS privacy manifest (`app/ios/Runner/PrivacyInfo.xcprivacy`), photo-library
  add permission, Bonjour service, encryption declaration and the warm launch
  background.
- Android adaptive icon, Android 13 monochrome themed icon, Android 12 splash
  screen, round icon and the screen-capture permission.
- Six-photo vault, Make It Meme, Time Traveler, Podium B, sound, haptics and
  dark-mode contrast fixes.
- Tablet max-width guards for the meme editor, timeline, round and caption
  screens.
- Refreshed store copy, release notes, feature graphic, app icon, store
  screenshots, `og.jpg` and website screenshots.
- Website SEO/PWA files (`sitemap.xml`, `manifest.webmanifest`,
  `apple-touch-icon.png`), security headers and the current mode copy.

## Blocking items only you can do

1. **Android signing is already set up.** The upload keystore lives at
   `private/upload-keystore.jks` in the main checkout (alias `upload`), and the
   four GitHub secrets (`ANDROID_KEYSTORE_BASE64`,
   `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`)
   are already present. Its SHA-256 matches both the fingerprint in
   `wrangler.jsonc` and the published 1.7.0 APK, so in-place updates keep
   working. Do not create a new key for 1.8.0. For a local signed
   build, copy the keystore and `key.properties` into this worktree; both are
   git-ignored.
2. **Google Play.** Create the developer account and app record for
   `party.whotook.app`. Add `PLAY_SERVICE_ACCOUNT_JSON` for the optional upload
   job. Upload the first AAB manually or let the workflow upload a draft.
3. **App Store and TestFlight.** Create the App ID, distribution certificate,
   provisioning profile and App Store Connect API key, then add
   `IOS_DIST_CERT_P12_BASE64`, `IOS_DIST_CERT_PASSWORD`,
   `IOS_PROVISIONING_PROFILE_BASE64`, `APPSTORE_API_PRIVATE_KEY`,
   `APPSTORE_API_KEY_ID`, `APPSTORE_API_ISSUER_ID` and `IOS_TEAM_ID`.
   `store/app-store-connect.md` has the exact portal steps and a field-by-field
   listing sheet. Run the manual **TestFlight** workflow for easy updates; test
   there before submitting the App Store build.
4. **Deep links.** Put the release Android SHA-256 and the Apple Team ID into
   the Worker, then deploy:
   ```bash
   python3 tool/prepare_app_links.py \
     --android-sha256 "AA:BB:...:99" \
     --apple-team "ABCDE12345"
   cd cloudflare-signaling && npx wrangler deploy
   ```
   The Worker serves `/.well-known/assetlinks.json` and
   `/.well-known/apple-app-site-association`. The Android SHA-256 in
   `wrangler.jsonc` matches the verified upload key, so only the Apple Team ID
   is still empty. Set it when the Apple account exists.
5. **Support inbox.** Create `hello@whotook.party` (the app, store copy and site
   use it) or change the address everywhere.
6. **Website deployment.** Deploy `cloudflare-signaling` with Wrangler after the
   store links exist. The Play/App Store buttons are still marked “soon”.
7. **Store forms.** Complete the Data safety, App Privacy, age rating, content
   declarations and review notes in Play Console and App Store Connect. The
   drafts are in `store/listing.md`.
8. **Upload the assets.** Use `store/assets/screenshots/play/`,
   `iphone69/`, `ipad13/`, `play-feature-graphic-1024x500.png` and
   `play-icon-512.png`.

## Release sequence

```bash
# 1. Verify the code
cd app && flutter analyze && flutter test
cd ../cloudflare-signaling && npm ci && npm run typecheck && npm test

# 2. Refresh screenshots if the UI changed
cd ../app
flutter test test/ui/screens_golden_test.dart \
  --dart-define=STORE_SCREENSHOTS=true --plain-name "store"
cd .. && python3 tool/store_assets.py

# 3. Tag the release (the workflow builds and attaches the artifacts)
git tag v1.8.0 && git push origin v1.8.0

# 4. The release workflow updates altstore.json from the IPA and commits it.
#    If it has no Cloudflare secrets, deploy the site once more:
cd cloudflare-signaling && npx wrangler deploy
cd ..

# 5. Check the deep-link files
curl https://whotook.party/.well-known/assetlinks.json
curl https://whotook.party/.well-known/apple-app-site-association
```

`tool/update_altstore.py` reads the real IPA size from the GitHub release. Do
not hand-edit the size.

## Device QA before submitting

Run the release builds, not the debug builds.

- Android 7, 10, 13, 14 and the current target: install, scan a QR, join, six
  photos, all four modes, save a meme, rotate and large text.
- iOS 15 and the current iOS: same flow, plus the limited photo library picker,
  Local Network prompt, Bonjour discovery and saving to the gallery.
- iPad: home, vault, meme editor, timeline and podium should stay centred; the
  store screenshots show the intended layout.
- Two-player and twelve-player rooms. Network loss during a round, host close,
  client rejoin after a restart, and a player removed from the lobby.
- Local Wi-Fi with no internet, then online through the TURN relay. The local
  WebSocket is not encrypted; the UI and privacy page say so.
- Light and dark mode on every screen. Large text at 200%. Reduced motion.
- Deny camera, photo and local-network permissions once, then grant them from
  Settings.
- Make It Meme: five swaps, voting for yourself is blocked, anonymous vote,
  royalty, top-three save, and a reconnect during voting.

## Remaining risks

- **UGC review.** Rooms are private and invite-only, the host can remove a
  player, and Settings opens a report email. Apple may still require an in-app
  block/report control. Add it if review asks.
- **Encryption wording.** The local LAN path is a plain WebSocket. Data safety
  and the privacy page say that. Do not change the copy to “encrypted” unless
  the LAN path is upgraded.
- **No crash reporting.** This is deliberate for privacy. If you add analytics
  or crash reporting, update both store privacy forms and the website privacy
  page.
- **AltStore size.** The release workflow updates the source from the real IPA.
  If that job cannot push to `main`, run `python3 tool/update_altstore.py
  --tag v1.8.0` and deploy manually.
- **App icon.** The viewfinder mark is the brand. A new icon needs a new store
  icon, feature graphic and screenshots, so do not swap it casually.

## Graphics status

Fixed in this pass:

- Old Caption This store screenshots and feature graphic replaced with current
  Make It Meme, Classic, Time Traveler and Podium captures.
- Screenshots regenerated from the real Flutter UI at Play, iPhone 6.9-inch and
  iPad 13-inch sizes.
- Dark-mode vote button contrast and the gold Time Traveler award card fixed.
- Android 12 splash, Android 13 themed icon and iOS launch background.
- Website hero, mode sections, mobile layout, dark theme and social image
  refreshed; broken screenshot links removed.

Optional next: Dutch store screenshots, a dedicated “top memes” store frame, and
photo avatars instead of icon avatars in the store demo.
