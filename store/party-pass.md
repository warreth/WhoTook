# WhoTook Party Pass — store setup

One non-consumable product, the same id on both stores:

| Field | Value |
| --- | --- |
| Product ID | `whotook_party_pass` |
| Type | Non-consumable / one-time product |
| Price | €2.99 (local tier equivalent in other storefronts) |
| Bundle / package | `party.whotook.app` |
| Backend | `POST https://signal.whotook.party/api/v1/turn-credentials` |

## App Store Connect

1. Open the app record → **Features → In-App Purchases**.
2. Create a **Non-Consumable** product with the id above.
3. Add the localized display name and description. Suggested name:
   *WhoTook Party Pass*; description: relay, soundboard and shared themes.
4. Set the price tier closest to €2.99.
5. Attach the product to the app version for review.
6. In review notes, state that the pass is optional, local Wi-Fi play is free,
   and **Restore Purchases** is on the pass sheet.

StoreKit 2 is the default path in `in_app_purchase_storekit` 0.4.x. The
`serverVerificationData` field carries the signed transaction JWS; the private
backend verifies it against the pinned Apple Root CA G3.

## Google Play Console

1. Open the app → **Monetize → Products → In-app products**.
2. Create a one-time product with the id above.
3. Set the price and activate it.
4. Grant the private backend service account access under **Users and
   permissions → API access** (Android Publisher API enabled).
5. Add license testers for sandbox purchases.

The purchase token is `serverVerificationData`; the private backend verifies it
with the Android Publisher API. Purchase tokens are never logged.

## Review notes

- Local P2P play is free in every mode; no pass is needed on the same Wi-Fi or
  hotspot.
- The pass unlocks the hosted relay (fair-use limited), the live soundboard and
  shared room themes.
- The FOSS build (`--dart-define=FOSS_BUILD=true`) has no billing at all and
  includes the soundboard and themes for free.
- A self-hosted TURN server can be configured from the pass sheet and Advanced
  settings; it does not require a pass.

## Refunds and fraud

Refunds are handled by the stores. The backend verifies the current receipt on
every relay request; a revoked or refunded transaction fails verification. Fair
use is keyed by the hashed original transaction id, not the device.
