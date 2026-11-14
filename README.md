# WhoTook

An open-source party photo-guessing game. One player hosts on their phone,
friends scan a QR code, and each round shows a photo from someone in the room
while everybody races the timer to guess who took it.

- **Website:** [whotook.party](https://whotook.party)
- **Signaling endpoint:** `https://signal.whotook.party`
- **License:** [GNU AGPLv3](LICENSE)

[![CI](https://github.com/warreth/WhoTook/actions/workflows/ci.yml/badge.svg)](https://github.com/warreth/WhoTook/actions/workflows/ci.yml)

Continuous integration runs the Worker typecheck and Miniflare suite, Flutter
`analyze` and widget/integration tests, a debug Android APK build, and an
unsigned iOS build on every push.

## How a match works

1. **Host & invite:** The host picks rounds (`5`, `10`, `15`, `20`, or custom in
   the lobby) and timer (`6s`, `8s`, `12s`) and opens a room. The QR code carries
   an invite URL (`https://whotook.party/j#<base64url>`) with the LAN endpoints,
   room ID, secret token, and signaling URL inside the URL fragment (`#`).
   Browsers never send the `#` fragment to the server.
2. **Contact sheet & secret plant:** Each player gets a private grid of random
   photos from their allowed albums, swaps anything they prefer to keep out, and
   taps **Ready**. Once Ready, while at least one other player is still picking,
   each player has one chance per match to pick any photo from their albums to
   plant quietly in place of an approved frame.
3. **Guessing & reveal:** A 3-2-1 countdown leads into each photo. Every player
   sees the same name buttons, including their own, so glancing at a neighbour's
   screen gives nothing away. Faster correct guesses score more points, streaks
   add a bonus, fooling opponents awards mystery points, and screenshots trigger
   a live room alert.
4. **Podium & extension:** Final scores and match awards appear on the podium.
   The host can start a 10-second **5 more rounds** extension window where
   everyone approves or swaps 3 extra frames before continuing.

## Privacy and networking

- **No accounts, no photo server:** Only a local nickname and photo permission
  are requested. Photos are resized to 1080 px JPEG (`keepExif: false`) so EXIF
  and GPS tags are stripped before any frame leaves the phone, and bytes live
  only in memory for the match.
- **Local first:** The host opens a WebSocket server on the phone and advertises
  over mDNS (`_whotook._tcp`). Joiners race all local endpoints for 800 ms and
  stay on Wi-Fi or a hotspot whenever reachable.
- **Online fallback:** When LAN fails, players fall back to WebRTC DataChannels
  signaled through the Cloudflare Worker. STUN is always available; Cloudflare
  TURN relay is protected by a per-IP daily quota (`5` rooms/day) and a global
  daily cap (`250` rooms/day) so the free Realtime tier stays bounded.
- **Self-hosted overrides:** Players can point the app to their own signaling
  server and custom TURN server under **Settings -> Self-hosted relay**.

## Repository layout

| Path | Contents |
| --- | --- |
| `app/` | Flutter app for Android 7.0+ (API 24+, including GrapheneOS) and iOS 15+ |
| `cloudflare-signaling/` | Cloudflare Worker, SQLite Durable Objects (`RoomCoordinator`, `TurnQuotaCoordinator`), static site (`public/`), `/j` invite page, and `.well-known` handlers |
| `prototypes/` | Early static HTML visual prototypes (`Warm Contact Sheet` and `Darkroom Ink`) |
| `.github/workflows/ci.yml` | Automated Worker, Android, and iOS verification |

## Running and building the app

Requirements: Flutter `3.47.x` (Dart `3.13+`), Java 17 and Android SDK for
Android, Xcode on macOS for iOS.

```bash
cd app
flutter pub get
flutter run
```

Useful verification commands:

```bash
cd app
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

### OS support and permissions

- **Android (API 24+ / Android 7.0+, GrapheneOS compatible):**
  - Photo access uses `READ_MEDIA_IMAGES` + `READ_MEDIA_VISUAL_USER_SELECTED`
    (Android 13/14+ partial selection supported) and `READ_EXTERNAL_STORAGE` up
    to API 32.
  - Screenshot detection uses Android 14+ `registerScreenCaptureCallback`
    (`DETECT_SCREEN_CAPTURE`) and a scoped `MediaStore` observer on API 24 to 33.
  - Cleartext traffic in `network_security_config.xml` is solely for local
    RFC1918 WebSocket connections; remote signaling uses `https://` and `wss://`.
- **iOS (iOS 15.0+):**
  - `Info.plist` declares camera, photo library, local network, and Bonjour
    (`_whotook._tcp`), plus the `whotook://` URL scheme.
  - `Runner/Runner.entitlements` declares `applinks:whotook.party` for
    Universal Links.
  - Screenshot detection bridges `UIApplication.userDidTakeScreenshotNotification`.

Android release builds need a signing key. Copy
`app/android/key.properties.example` to `app/android/key.properties` and point it
at your keystore; the file is git-ignored. Without it, release builds fall back
to the debug key so `flutter run --release` still works, but store builds must use
a real upload key.

One keystore file can sign several of your own apps: Android identifies an app by
its package name, and the certificate only proves that updates for that package
come from the same signer. A distinct `keyAlias` per app keeps the file readable.
The caveats are blast radius (a leaked key affects every app signed with it) and
App Links: `assetlinks.json` must list the SHA-256 of the certificate that is
actually installed on the phone. With Play App Signing that is Google's app
signing certificate from the Play Console, not your local upload key, so list
both if you also distribute the APK directly.

iOS device and TestFlight builds require your Apple Developer Team ID in Xcode.

## Running and deploying the Worker & website

`cloudflare-signaling/` runs on the Cloudflare Workers Free plan using SQLite
Durable Objects and Workers Static Assets.

```bash
cd cloudflare-signaling
npm install
npm test            # Miniflare integration tests (no Cloudflare account needed)
npm run typecheck   # Generates wrangler types and runs tsc --noEmit
npx wrangler dev    # Local Worker + static site
```

### Production deploy

1. Set the required HMAC salt secret (used to hash client IPs per UTC day for
   TURN rate limiting; never stored in git):

   ```bash
   cd cloudflare-signaling
   npx wrangler deploy --secrets-file /path/to/secrets.env
   # or after the Worker exists:
   npx wrangler secret put IP_HASH_SALT
   ```

2. Optional Cloudflare Realtime TURN secrets (without these, the Worker serves
   STUN-only, which still works for LAN and direct P2P and costs nothing):

   ```bash
   npx wrangler secret put TURN_TOKEN_ID
   npx wrangler secret put TURN_API_TOKEN
   ```

   Realtime TURN gives 1,000 GB of egress per month free (shared with SFU) and
   charges $0.05/GB after that. Cloudflare has no hard spending cap for Realtime,
   so the Worker itself is the cap: `MAX_GLOBAL_TURN_ROOMS_PER_DAY` (`250`) is
   sized so that even a worst-case 12-player, 25-round room of about 100 MB
   stays near 760 GB/month. Per-IP allowance is
   `MAX_TURN_GAMES_PER_IP_PER_DAY` (`5`). Raising either number raises the
   possible bill; lower them, or remove the two TURN secrets, to stop relay
   spending entirely. A $1 budget alert under **Billing > Billable Usage** emails
   you before the free tier runs out, but it does not block usage.

3. Optional deep-link verification vars in `cloudflare-signaling/wrangler.jsonc`
   (or dashboard vars) once you have your Apple Team ID and Android release
   signing certificate SHA-256 fingerprint:
   - `APPLE_TEAM_ID`: enables `/.well-known/apple-app-site-association` for
     `<TEAM_ID>.app.whotook.whotook`
   - `ANDROID_SHA256_CERT_FINGERPRINTS`: comma-separated SHA-256 fingerprints
     for `/.well-known/assetlinks.json` (`app.whotook.whotook`)

4. Deploy the Worker, website (`public/`), `/j` invite handler, and custom
   domains (`whotook.party`, `www.whotook.party`, `signal.whotook.party`):

   ```bash
   npx wrangler deploy
   ```

## License

WhoTook is licensed under the [GNU Affero General Public License v3.0](LICENSE).
