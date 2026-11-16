# Store submission package

This folder holds the copy, screenshots and graphics for Google Play and the
App Store. The accounts, certificates and final store forms still have to be
completed in Play Console and App Store Connect.

## Permanent IDs

- Android application ID: `party.whotook.app`.
- iOS bundle ID: `party.whotook.app`. This is the reverse-DNS form of
  `whotook.party`. Create the App ID, App Store provisioning profile and
  App Store Connect record with this value. No new Apple ID is needed.

## What is ready (1.8.0)

- `listing.md`: listing copy, content declarations, age rating notes, review
  notes and Data safety / App Privacy drafts.
- `assets/play-icon-512.png`: Google Play store icon, generated from the app
  icon.
- `assets/play-feature-graphic-1024x500.png`: Google Play feature graphic with
  the four current modes.
- `assets/screenshots/play/`: six phone screenshots at 1170 x 2340. They show
  home, the four modes, the meme editor, the anonymous vote, the evidence
  timeline and the podium.
- `assets/screenshots/iphone69/`: six iPhone 6.9-inch screenshots at
  1320 x 2868.
- `assets/screenshots/ipad13/`: six iPad 13-inch screenshots at 2064 x 2752.
  They show home, the six-photo vault, the meme editor, a private lobby, the
  evidence timeline and the podium.
- `cloudflare-signaling/public/og.jpg` and `apple-touch-icon.png`: refreshed
  social and home-screen graphics.

The screenshots are generated from the real Flutter screens, not mocked in a
design tool:

```bash
cd app
flutter test test/ui/screens_golden_test.dart \
  --dart-define=STORE_SCREENSHOTS=true --plain-name "store"
cd ..
python3 tool/store_assets.py
```

The raw captures are written to `app/test/ui/store_raw/` (git-ignored). The
script writes the store assets, the feature graphic, `og.jpg` and the web icons.

## What only you can do

1. Create the Google Play developer account and the Apple Developer Program
   membership.
2. Create the app records with the final package and bundle IDs.
3. Create the Apple Distribution certificate, App Store provisioning profile and
   App Store Connect API key, then add the GitHub secrets listed in the release
   workflow.
4. Add the Play service account JSON as `PLAY_SERVICE_ACCOUNT_JSON`.
5. Run `tool/prepare_app_links.py` with the release Android SHA-256 and the Apple
   Team ID. It writes both values into `cloudflare-signaling/wrangler.jsonc`;
   the Worker serves the two `.well-known` files. Deploy the Worker after it.
   Without this, Android App Links and iOS Universal Links will not open the app.
6. Complete the store forms in the consoles and submit for review. Use the
   current screenshots and feature graphic in this folder.
7. Create `hello@whotook.party` in Zoho Mail, or change the address in
   `app/lib/core/constants.dart`, the website pages and the store copy.
8. The release workflow updates `cloudflare-signaling/public/altstore.json`
   from the published IPA and commits it to `main`. Add
   `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` as GitHub secrets if you
   also want the workflow to deploy the site automatically. Without them, run
   `cd cloudflare-signaling && npx wrangler deploy` once after the release.

## Release assets

For future GitHub releases, keep the stable download names:

- `WhoTook.apk` for the website and Obtainium, as the universal APK.
- `WhoTook-<version>-universal.apk` for a versioned universal APK.
- `WhoTook-<version>-arm64-v8a.apk`, `WhoTook-<version>-armeabi-v7a.apk` and
  `WhoTook-<version>-x86_64.apk` for smaller per-architecture downloads.
- `WhoTook-unsigned.ipa` for SideStore and AltStore, plus a versioned
  `WhoTook-<version>-unsigned.ipa` copy.
- `WhoTook-<version>.aab` for the Play upload.

The signed App Store IPA is uploaded to App Store Connect and kept as a private
CI artifact. Do not publish it as a public release asset. It is an App Store
distribution build, not a build that SideStore can install.
