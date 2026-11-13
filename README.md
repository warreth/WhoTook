# WhoTook

An open-source party photo-guessing game. One player hosts on their phone,
everyone else scans a QR code, and each round shows a photo from someone in the
room while everybody races to guess whose it was.

- **No accounts.** A nickname and a photo permission are all it asks for.
- **No photo server.** Photos are compressed on device, stripped of EXIF and GPS,
  and shared only with the players in the match, in memory.
- **Local first.** On the same Wi-Fi or a hotspot the host phone is the server, so
  nothing leaves the network. Remote players fall back to WebRTC automatically.
- **Cost safe.** Online play uses a small Cloudflare Worker for signaling and a
  daily per-network relay quota, so the free tiers hold.
- **License:** [GNU AGPLv3](LICENSE).

[![CI](https://github.com/warreth/WhoTook/actions/workflows/ci.yml/badge.svg)](https://github.com/warreth/WhoTook/actions/workflows/ci.yml)

Continuous integration builds the worker and its tests, runs the app tests and an
Android APK, and compiles iOS without codesigning on every push.

## Layout

| Path | What it is |
| --- | --- |
| `app/` | Flutter app for Android (API 24+), iOS 15+ and GrapheneOS |
| `cloudflare-signaling/` | Worker + Durable Objects: WebRTC signaling and the TURN quota broker |
| `prototypes/` | Static HTML explorations of the visual direction |

## Running the app

```bash
cd app
flutter pub get
flutter run
```

Android release builds need a signing config of your own. The app asks for photo
access, camera access and, on Android 14+, the screen capture detection
permission used for the screenshot callout.

## Running the signaling Worker

```bash
cd cloudflare-signaling
npm install
npx wrangler types
npm test            # Miniflare integration tests, no account needed
npx wrangler dev    # local
npx wrangler deploy # your account
```

Secrets are never stored in the repository:

```bash
npx wrangler secret put IP_HASH_SALT        # required, any long random string
npx wrangler secret put TURN_TOKEN_ID       # optional, enables TURN relay
npx wrangler secret put TURN_API_TOKEN      # optional
```

Without the two TURN secrets the Worker still serves STUN only, which is enough
for most home networks and every LAN match. With them, each client IP gets
`MAX_TURN_GAMES_PER_IP_PER_DAY` relayed matches per day (default 5) and the whole
account stops at `MAX_GLOBAL_TURN_ROOMS_PER_DAY` (default 1500), which keeps usage
inside Cloudflare's free 1,000 GB TURN allowance. When the quota is gone the app
says so and points the player at local Wi-Fi or a hotspot.

## Design

The visual direction, palette, spacing and the game rules live in the project's
private notes. The short version: warm contact sheet in light mode, darkroom in
dark mode, one accent, monospace only for counters and timers, no decoration.
