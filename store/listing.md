# WhoTook store listing

Copy for Google Play and the App Store. Keep the public copy short. The store
forms decide the final rating and data labels.

## Permanent IDs

- Android application ID: **app.whotook.whotook**. Keep this for update
  continuity with the APK builds that are already installed.
- iOS bundle ID: **party.whotook.app**. Create the App ID, provisioning profile
  and App Store Connect app record with this exact value.
- No separate Apple ID is needed for a bundle ID.

## Shared

- App name: **WhoTook**
- Support email: **hello@whotook.party**
- Support URL: https://whotook.party/support
- Privacy policy: https://whotook.party/privacy
- Marketing URL: https://whotook.party
- Category: Games / Party
- Price: Free
- Ads: No
- In-app purchases: No
- Accounts: No

## Google Play

### Title

WhoTook

### Short description, 80 characters

Guess whose camera roll it is. A party game for friends.

### Full description, 4000 characters

WhoTook is a party game for friends at one table or spread across the internet.

Everyone picks a few photos from their own phone. A photo appears, and the table races to guess whose camera roll it came from. Faster correct guesses score more.

Ways to play:

- Classic: guess who took the photo.
- Caption This: write the funniest caption, then vote anonymously.
- Time Traveler: guess the year and month on a timeline.
- Mixed Party: all three, shuffled.

Play on the same Wi-Fi or online. No accounts, no ads and no photo server. Photos are resized and stripped of location data before they leave the phone, and they stay in that match.

Start a room, pick the rounds, pace and mode, choose your photos and show the QR code. Friends join from any camera app and the game begins.

### Promotional text, 170 characters

New: a four-step host setup, a whole-set photo check and a cleaner lobby.

### Assets

- Icon: `store/assets/play-icon-512.png` (512 x 512 RGBA)
- Feature graphic: `store/assets/play-feature-graphic-1024x500.png` (1024 x 500)
- Phone screenshots: `store/assets/screenshots/play/` (1170 x 2340 each)

### Content declarations

- Ads: No
- In-app purchases: No
- Target audience: 13 and older. The game contains user-created photos and
  captions, and private online interaction.
- Content rating: complete the questionnaire as a social party game with
  user-generated content and online interaction. The expected rating is Teen,
  but the rating authority decides.
- News app: No
- Government app: No
- Financial features: No
- Health features: No
- App access: no login. Review notes below explain the two-device flow.

### Data safety draft

The app has no accounts, analytics, ads or developer-run photo server. Photos
are sent directly between the players in a room.

- Photos: collected and shared for app functionality, required, ephemeral.
- Encryption in transit: answer **No** for all collected data. The internet
  path uses WebRTC and an encrypted relay, but the same-Wi-Fi path uses a local
  WebSocket without TLS. Do not claim encryption for all data until that path is
  upgraded.
- Deletion: no server-side account or photo storage. Users can uninstall the
  app to remove local settings.

If you add analytics or crash reporting later, update this form.

## App Store

### Name

WhoTook

### Subtitle, 30 characters

The camera roll party game

### Keywords, 100 characters

party game,photo game,guess who,camera roll,family,friends,quiz,caption,timeline,offline

### Description, 4000 characters

WhoTook is a party game for friends at one table or spread across the internet.

Everyone picks a few photos from their own phone. A photo appears, and the table races to guess whose camera roll it came from. Faster correct guesses score more.

Ways to play:

- Classic: guess who took the photo.
- Caption This: write the funniest caption, then vote anonymously.
- Time Traveler: guess the year and month on a timeline.
- Mixed Party: all three, shuffled.

Play on the same Wi-Fi or online. No accounts, no ads and no photo server. Photos are resized and stripped of location data before they leave the phone, and they stay in that match.

Start a room, pick the rounds, pace and mode, choose your photos and show the QR code. Friends join from any camera app and the game begins.

### Promotional text, 170 characters

New: a four-step host setup, a whole-set photo check and a cleaner lobby.

### Review notes

WhoTook is a local party game. No account is needed.

To test the full flow, install the build on two iPhones or iPads on the same Wi-Fi:

1. On device A, tap Host a game.
2. Pick rounds, pace and a mode, then approve photos.
3. Tap Open the room, then Start photo check on the lobby.
4. On device B, tap Join a game and scan the QR code.
5. Approve photos on both devices, then tap Ready on both.

A hidden review demo with fake players and bundled photos is available at
Settings > About. Tap the small WhoTook trademark line seven times. It runs
offline and shows the photo check, a Classic round, the reveal and the podium.

User-generated content: rooms are private and invite-only. The host can remove
a player from the lobby. Users can report content or a player from Settings >
Report content or a player, or by emailing hello@whotook.party. Terms and
community rules are accepted during onboarding.

### App privacy draft

No data is accessible to the developer. There are no accounts, analytics, ads
or developer-run photo storage. Photos are shared only with the players in the
room. Recommended answer: **Data Not Collected**. Confirm this against Apple's
definitions before submitting.

### Export compliance

The app uses standard encryption through WebRTC and HTTPS. Complete the export
compliance questionnaire in App Store Connect and provide documentation if
Apple asks for it.

### Assets

- App icon: already in `app/ios/Runner/Assets.xcassets/AppIcon.appiconset/`
  (`Icon-App-1024x1024@1x.png`).
- iPhone 6.9-inch screenshots: `store/assets/screenshots/iphone69/`
  (1320 x 2868 each).
- iPad 13-inch screenshots: `store/assets/screenshots/ipad13/`
  (2064 x 2752 each).

## Age rating notes

The game contains user-created photos and captions, private online interaction
and no public feed. Apple's expected rating is 12+ for user-generated content.
Google Play's expected rating is Teen. The stores decide the final rating from
the questionnaires.
