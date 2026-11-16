# Self-hosting WhoTook

WhoTook plays over a direct local socket when every phone is on the same
Wi-Fi or hotspot, and over WebRTC when that is not possible. The public
repository ships the app only. The hosted signaling and relay deployment lives
in a separate private repository and is not required to play locally.

This document describes the public protocol so you can run your own signaling
server and TURN relay.

## 1. Local play (no server)

The host opens a WebSocket on the LAN and puts its address in the invite QR
code. Players connect directly to that socket. Nothing leaves the network and
no account, telemetry or relay is involved. This path is always free, in every
build.

## 2. Online play: signaling protocol

The app connects to a WebSocket endpoint:

```
wss://your-signal.example/room/<roomId>?role=host|client&token=<roomSecret>
```

`roomId` is 4-32 characters from `[A-Za-z0-9_-]`. The first host connection
registers `<roomSecret>` in that room; every later connection (host or client)
must present the same secret. Hosts and clients exchange these JSON frames:

| Frame | Direction | Meaning |
| --- | --- | --- |
| `{"type":"welcome","peerId":"host","role":"host"}` | server → client | Connection accepted. |
| `{"type":"peer_joined","peerId":"c_ab12cd34","role":"client"}` | server → host | A player joined; the host creates an offer for that peer. |
| `{"type":"offer","from":"host","to":"c_ab12cd34","payload":{"sdp":"...","type":"offer"}}` | host → server → client | WebRTC offer. |
| `{"type":"answer","from":"c_ab12cd34","to":"host","payload":{"sdp":"...","type":"answer"}}` | client → server → host | WebRTC answer. |
| `{"type":"ice","from":"...","to":"...","payload":{"candidate":"...","sdpMid":"0","sdpMLineIndex":0}}` | either | ICE candidate. |
| `{"type":"peer_left","peerId":"c_ab12cd34"}` | server → host | A player disconnected. |
| `{"type":"room_closed","reason":"..."}` | server → clients | The host closed the room. |

The server only relays `offer`, `answer` and `ice`; it must not inspect the
photo or game payloads. A reference implementation limits messages to 64 KB,
rooms to 12 players, and closes idle rooms after two hours.

After the data channel opens, the app sends its own envelope inside it:

```json
{"type": "round_show", "seq": 12, "payload": {"roundNumber": 3}}
```

Messages are host-authoritative. Clients send intents (`submit_guess`,
`caption_submit`, `sound_effect`, ...) and the host broadcasts the resulting
state. The complete list of application message names is in
`app/lib/core/protocol/wire_message.dart`.

## 3. Online play: your own TURN relay

A strict mobile carrier NAT (for example 5G without IPv6) can block direct
WebRTC. A TURN server relays the encrypted media and data channel. WhoTook does
not bundle relay credentials; use a standard `coturn` deployment:

```conf
# /etc/turnserver.conf
listening-port=3478
tls-listening-port=5349
fingerprint
lt-cred-mech
use-auth-secret
static-auth-secret=REPLACE_WITH_A_LONG_RANDOM_SECRET
realm=turn.example.com
cert=/etc/letsencrypt/live/turn.example.com/fullchain.pem
pkey=/etc/letsencrypt/live/turn.example.com/privkey.pem
no-multicast-peers
no-cli
```

Open UDP/TCP 3478 and TCP 5349, and the relay port range you configure
(`min-port`/`max-port`). Then install a FOSS build of WhoTook and open
**Settings → Online relay → Self-hosted relay**:

- **TURN URI**: `turn:turn.example.com:3478?transport=udp` (add a
  `turns:turn.example.com:5349?transport=tcp` entry for TLS if you have it)
- **Username** and **Password**: static credentials from your `coturn`
  configuration, or time-limited credentials produced by your own issuer.

The app appends this server to the ICE configuration for every match. It never
contacts the official WhoTook relay from a FOSS build.

Build the FOSS variant with:

```bash
cd app
flutter run --dart-define=FOSS_BUILD=true
```

FOSS builds contain no store billing code paths and no official relay client.
They include the local soundboard and all room themes for free.

## 4. What the official build does differently

The App Store and Play Store builds optionally sell the **WhoTook Party Pass**,
a one-time non-consumable in-app purchase. It unlocks the hosted TURN relay
(fair-use limited per verified store transaction), the live soundboard and
shared room themes. Receipt verification and relay credential issuance happen
on the private server; they are deliberately absent from this repository.

The app still plays local P2P matches for free without a Party Pass, and the
FOSS build never includes the purchase flow.
