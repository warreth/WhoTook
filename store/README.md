# Store submission package

This folder holds the copy, screenshots and graphics for Google Play and the
App Store. The accounts, certificates and final store forms still have to be
completed in Play Console and App Store Connect.

## Permanent IDs

- Android application ID: `party.whotook.app`.
- iOS bundle ID: `party.whotook.app`. This is the reverse-DNS form of
  `whotook.party`. Create the App ID, App Store provisioning profile and App
  Store Connect record with this value. No new Apple ID is needed.

## What is ready

- `listing.md`: all listing copy, content declarations, age rating notes,
  review notes and Data safety / App Privacy drafts.
- `assets/play-icon-512.png`: Google Play store icon.
- `assets/play-feature-graphic-1024x500.png`: Google Play feature graphic.
- `assets/screenshots/play/`: 7 phone screenshots at 1170 x 2340.
- `assets/screenshots/iphone69/`: 7 iPhone 6.9-inch screenshots at 1320 x 2868.
- `assets/screenshots/ipad13/`: 7 iPad 13-inch screenshots at 2064 x 2752.

## What only you can do

1. Create the Google Play developer account and the Apple Developer Program
   membership.
2. Create the app records with the final package and bundle IDs.
3. Create the Apple Distribution certificate, App Store provisioning profile and
   App Store Connect API key, then add the GitHub secrets listed in the release
   workflow.
4. Add the Play service account JSON as `PLAY_SERVICE_ACCOUNT_JSON`.
5. Complete the store forms in the consoles and submit for review.
6. Create `hello@whotook.party` in Zoho Mail, or change the address in
   `app/lib/core/constants.dart`, the website pages and the store copy.

## Release assets

For future GitHub releases, keep the stable download names:

- `WhoTook.apk` for the website and Obtainium.
- `WhoTook-unsigned.ipa` for SideStore and AltStore.
- `WhoTook-<version>.aab` for the Play upload.

The versioned APK and IPA duplicates are not needed; the release tag identifies
the version. The signed App Store IPA is uploaded to App Store Connect and kept
as a private CI artifact. Do not publish it as a public release asset. It is an
App Store distribution build, not a build that SideStore can install.
