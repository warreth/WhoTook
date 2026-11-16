# App Store Connect and TestFlight pack

Everything below is ready to paste into App Store Connect. The full English and
Dutch store copy lives in `store/listing.md`; this file is the field-by-field
submission sheet.

## 1. Create the app record

- Platform: **iOS**
- Name: **WhoTook**
- Primary language: **English (U.S.)** (add Dutch as a second localization)
- Bundle ID: **party.whotook.app**
- SKU: **whotook-1**
- User access: full access for your Apple ID
- Category: **Games > Party**
- Price: **Free**
- Availability: all countries, or your test markets
- Age rating: complete the questionnaire as a social party game with
  user-generated content and online interaction. The expected rating is **12+**.

Before the first upload, accept the Free Apps agreement in App Store Connect >
Business. Tax and banking are not required for a free app.

## 2. Apple Developer setup

1. **App ID.** Certificates, Identifiers & Profiles > Identifiers > **+** >
   App IDs > App. Use `party.whotook.app` and enable **Associated Domains**.
2. **Distribution certificate.** Create an **Apple Distribution** certificate.
   Install it in Keychain, export a `.p12` with a password, and keep it safe.
   Apple asks for a Certificate Signing Request (CSR). On a Mac use Keychain
   Access > Certificate Assistant > Request a Certificate from a Certificate
   Authority, save it to disk and upload it. Without a Mac, use the OpenSSL
   route below.
3. **Provisioning profile.** Create an **App Store** distribution profile for
   the App ID and that certificate. Download the `.mobileprovision`.

### Geen Mac: CSR en .p12 met OpenSSL

Run this on Linux, WSL or any machine with OpenSSL. The private key stays on
that machine; keep a backup.

```bash
mkdir -p ~/whotook-signing && cd ~/whotook-signing
openssl genrsa -out distribution.key 2048
openssl req -new -key distribution.key \
  -out distribution.certSigningRequest \
  -subj "/CN=WhoTook Distribution/C=NL"
```

Upload `distribution.certSigningRequest` in the Apple Developer portal when it
asks for a CSR. Download the generated `.cer` into the same folder. Then build
the `.p12` with the current Apple intermediate certificates:

```bash
curl -fsSLO https://www.apple.com/certificateauthority/AppleWWDRCAG4.cer
curl -fsSLO https://www.apple.com/certificateauthority/AppleWWDRCAG5.cer
openssl x509 -inform DER -in distribution.cer -out distribution.pem
openssl x509 -inform DER -in AppleWWDRCAG4.cer -out AppleWWDRCAG4.pem
openssl x509 -inform DER -in AppleWWDRCAG5.cer -out AppleWWDRCAG5.pem
cat AppleWWDRCAG4.pem AppleWWDRCAG5.pem > AppleWWDR.pem
openssl pkcs12 -export -inkey distribution.key -in distribution.pem \
  -certfile AppleWWDR.pem -out distribution.p12 -name "WhoTook Distribution"
```

Choose a strong export password and save it for `IOS_DIST_CERT_PASSWORD`.
Back up `distribution.key`, `distribution.p12` and the password somewhere safe.
If you lose the key you must revoke the certificate and create a new one.
4. **API key.** App Store Connect > Users and Access > Integrations > App Store
   Connect API > Team Keys > **+**. Give it App Manager access. Download the
   `.p8` once, and note the **Key ID** and **Issuer ID**.
5. **Team ID.** Membership details in the Apple Developer portal.

## 3. GitHub secrets for TestFlight

> **Use exactly these names.** Other guides mention
> `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`,
> `BUILD_PROVISION_PROFILE_BASE64` or `KEYCHAIN_PASSWORD`; those belong to a
> different workflow. This repository's TestFlight workflow generates its own
> temporary keychain password and reads the seven names below.

Add these in GitHub > Settings > Secrets and variables > Actions:

| Secret | Value |
| --- | --- |
| `IOS_DIST_CERT_P12_BASE64` | `base64 -i distribution.p12 \| pbcopy` |
| `IOS_DIST_CERT_PASSWORD` | the `.p12` export password |
| `IOS_PROVISIONING_PROFILE_BASE64` | `base64 -i profile.mobileprovision \| pbcopy` |
| `APPSTORE_API_PRIVATE_KEY` | the full contents of `AuthKey_XXXXXXXXXX.p8` |
| `APPSTORE_API_KEY_ID` | the Key ID from App Store Connect |
| `APPSTORE_API_ISSUER_ID` | the Issuer ID |
| `IOS_TEAM_ID` | your 10-character Apple Team ID |

The existing release workflow uses the same seven secrets. Once they exist, the
optional signed App Store upload step also activates automatically.

## 4. TestFlight

The **TestFlight** workflow is manual. Run it from GitHub Actions > TestFlight >
Run workflow, or:

```bash
gh workflow run testflight.yml
```

Leave the build number empty and it uses `1000 + run number`, always increasing
and unique for version 1.8.0. To force a number, pass `-f build_number=1005`.

The workflow:

1. Imports the distribution certificate and provisioning profile.
2. Builds a signed IPA for `party.whotook.app`.
3. Uploads it to App Store Connect with the API key.
4. Stops there; App Store Connect processes the build.

Then:

1. Open App Store Connect > TestFlight > iOS builds.
2. Wait for **Ready to submit** / processing to finish (usually 10–30 minutes).
3. Add yourself under **Internal Testing** (an App Store Connect user account
   is required). Internal testers do not need App Review.
4. Install **TestFlight** from the App Store, accept the invite, and install
   WhoTook.
5. For a new build, run the workflow again. TestFlight updates the app in place;
   no cable, no weekly re-sign, no reinstall.

TestFlight builds expire after 90 days. External testers require a beta review;
internal testers do not. Android/AltStore users can keep using the separate
release APK and `altstore.json`.

## 5. App Store listing fields

### English (U.S.)

- Name: **WhoTook**
- Subtitle: **The camera roll party game**
- Promotional text: **New: Make It Meme, a six-photo vault, an evidence-board timeline, top memes and a tactile new look.**
- Keywords: **party game,photo game,guess who,camera roll,memes,friends,quiz,timeline,offline**
- Support URL: `https://whotook.party/support`
- Marketing URL: `https://whotook.party`
- Privacy policy URL: `https://whotook.party/privacy`
- Description: copy the App Store description from `store/listing.md`.
- Review notes: copy the review notes from `store/listing.md`.

### Nederlands

- Naam: **WhoTook**
- Ondertitel: **Foto's raden, memes maken**
- Promotietekst: **Nieuw: Make It Meme, een zes-foto vault, een bewijstijdlijn en de top 3 memes. Nu ook met geluid en trilfeedback.**
- Trefwoorden: **feestspel,fotospel,raad wie,camera rol,memes,vrienden,quiz,tijdlijn,offline**
- Beschrijving:

  WhoTook is een feestspel voor vrienden aan één tafel of verspreid over het
  internet.

  Iedereen brengt foto's van de eigen telefoon mee. Raad wiens camera rol een
  foto is, maak een meme van elkaars foto of pin een datum op het
  bewijsbord. De app is beschikbaar in het Engels en Nederlands.

  Speelwijzen:

  - Klassiek: raad wie de foto nam. Snelle juiste gokken scoren meer.
  - Make It Meme: krijg een foto van een vriend, kies uit zeven templates en
    laat de kamer anoniem up, meh of down stemmen. De eigenaar van de foto
    krijgt royalty's als de meme wint.
  - Tijdreiziger: kies een decennium, jaar en maand en lees daarna de
    bewijstijdlijn.
  - Gemengde party: alle drie, door elkaar.

  Kies een naam en een selfie-, galerij- of icoonavatar. Je laatste room staat
  klaar om opnieuw binnen te komen. Een weggevallen verbinding herstelt dezelfde
  ronde. Geen accounts, geen advertenties en geen fotoserver. Foto's worden
  verkleind en van locatie ontdaan voordat ze je telefoon verlaten, en blijven
  in die match. Een foto-avatar staat alleen op je telefoon en gaat alleen naar
  de spelers in de actieve room.

## 6. Screenshots: exact upload order

iPhone 6.9-inch (`store/assets/screenshots/iphone69/`):

1. `01-home.png`
2. `02-modes.png`
3. `03-meme-editor.png`
4. `04-meme-vote.png`
5. `05-timeline.png`
6. `06-podium.png`

iPad 13-inch (`store/assets/screenshots/ipad13/`):

1. `01-home.png`
2. `02-vault.png`
3. `03-meme-editor.png`
4. `04-lobby.png`
5. `05-timeline.png`
6. `06-podium.png`

Google Play uses `store/assets/screenshots/play/` in the same order as the
iPhone set. The app icon is already in the asset catalog; the 1024 px version
is `app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`.

## 7. Privacy and compliance

- **App Privacy:** recommended **Data Not Collected**. The developer receives
  no account data, analytics or photo storage. Photos and avatars move directly
  between players in the room; they are not stored by the developer. Confirm
  this against Apple's current definitions before submitting.
- **Export compliance:** `ITSAppUsesNonExemptEncryption` is already `false` in
  `Info.plist`; the app uses standard WebRTC/HTTPS encryption.
- **Content rights:** the app and visual assets are the project's. Players own
  their own photos and memes.
- **UGC:** rooms are private and invite-only, the host can remove a player, and
  Settings opens a report email. Apple may ask for an in-app block/report
  control; add it only if review requests it.

## 8. Test first, submit later

Do not submit for App Store review yet. Run at least one TestFlight cycle:

- Upgrade a phone with 1.7.0 installed to the TestFlight build.
- Local Wi-Fi with no internet, then online through the relay.
- Classic, Make It Meme, Time Traveler and Mixed Party.
- Six-photo vault, five swaps, own-vote block, anonymous vote, royalty, top 3
  meme download.
- Two players and twelve players; reconnect; host closes the room.
- Light/dark, 200% text, iPad, Android 14 screenshot detection.
- Deny and re-grant camera, photo and local-network permissions.
- Save a meme to the gallery on iOS and Android.

When that is clean, fill the listing, privacy, age rating and review notes, then
submit the same build (or a fresh increment) for App Store review.
