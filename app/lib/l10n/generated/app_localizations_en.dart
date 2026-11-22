// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Follow the device';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageDutch => 'Nederlands';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueLabel => 'Continue';

  @override
  String get close => 'Close';

  @override
  String get remove => 'Remove';

  @override
  String get done => 'Done';

  @override
  String get retry => 'Retry';

  @override
  String get back => 'Back';

  @override
  String get leave => 'Leave';

  @override
  String get stay => 'Stay';

  @override
  String get settings => 'Settings';

  @override
  String get player => 'Player';

  @override
  String get ready => 'Ready';

  @override
  String get waitingForHost => 'Waiting for the host';

  @override
  String get nextRoundInMoment => 'Next round in a moment.';

  @override
  String get hostAGame => 'Host a game';

  @override
  String get hostAGameSubtitle => 'Pick the mode, rounds and pace';

  @override
  String get joinAGame => 'Join a game';

  @override
  String get joinAGameSubtitle => 'Scan the host\'s QR code';

  @override
  String get homeFooter =>
      'Same room, same Wi-Fi. Photos stay between players.';

  @override
  String get lastRoom => 'Last room';

  @override
  String roomLabel(String roomId) {
    return 'Room $roomId';
  }

  @override
  String get forgetRoom => 'Forget this room';

  @override
  String get howItPlays => 'How it plays';

  @override
  String get guideSetTable => 'Pick the game';

  @override
  String get guideSetTableBody => 'Mode, rounds and pace.';

  @override
  String get guideScanIn => 'Friends scan in';

  @override
  String get guideScanInBody => 'Friends join from the QR.';

  @override
  String get guidePlay => 'Play';

  @override
  String get guidePlayBody =>
      'Guess a photo, build a meme or travel through time.';

  @override
  String get heroFact => '2–12 players · Same Wi-Fi or online';

  @override
  String get heroTitle => 'Whose camera\nroll is this?';

  @override
  String get heroSubtitle =>
      'One photo at a time. Everyone guesses whose it is.';

  @override
  String get onlineRelayUsed =>
      'Online relay is used up today. Use the same Wi-Fi to keep playing.';

  @override
  String get guessWhosePhoto => 'Guess whose photo it is';

  @override
  String get onboardingTagline =>
      'One photo. One guess. Tap who you think took it.';

  @override
  String get onboardingFreeTitle => 'Same Wi-Fi is always free';

  @override
  String get onboardingFreeBody =>
      'Play Anywhere is optional, for friends on mobile data or another Wi-Fi. It comes with the Party Pass.';

  @override
  String get yourName => 'Your name';

  @override
  String get acceptTerms => 'I agree to the Terms of use and Community rules.';

  @override
  String get termsLink => 'Terms and community rules';

  @override
  String get privacy => 'Privacy';

  @override
  String get onboardingPhotoNote =>
      'Photos are only read when a match starts. You can keep private albums out of every game in Settings.';

  @override
  String get pickNameError => 'Pick a name your friends will recognise.';

  @override
  String get acceptTermsError => 'Agree to the terms before you continue.';

  @override
  String get joinAMatch => 'Join a match';

  @override
  String get connectingToHost => 'Connecting to the host';

  @override
  String get pasteInvite => 'Or paste an invite link';

  @override
  String get useThisLink => 'Use this link';

  @override
  String get cameraUnavailable =>
      'Camera unavailable. Allow access or paste a link below.';

  @override
  String get joiningAs => 'Joining as';

  @override
  String get nameShownAtTable => 'Shown to everyone at the table';

  @override
  String get joinTheRoom => 'Join the room';

  @override
  String get joining => 'Joining';

  @override
  String joinRoomTitle(String roomId) {
    return 'Join $roomId';
  }

  @override
  String get invalidInvite =>
      'That invite is not valid. Scan the QR code again.';

  @override
  String get chooseGame => 'Choose the game';

  @override
  String get chooseGameSubtitle =>
      'Classic, Zoom-Out, Make It Meme, Foto-Sabotage, Time Traveler or a bit of everything.';

  @override
  String get nextRounds => 'Next: rounds';

  @override
  String get howManyRounds => 'How many rounds?';

  @override
  String get roundsSubtitle =>
      'Short and sharp. You can always add five more at the podium.';

  @override
  String get nextPace => 'Next: pick the pace';

  @override
  String get quickGame => 'Quick game';

  @override
  String get partySize => 'Party size';

  @override
  String get longTable => 'Long table';

  @override
  String get allNighter => 'All nighter';

  @override
  String get pickPace => 'Pick the pace';

  @override
  String get openRoom => 'Open the room';

  @override
  String get couldNotOpenRoom => 'Could not open the room.';

  @override
  String stepOf(int step) {
    return 'Step $step of 3';
  }

  @override
  String get hostAGameTitle => 'Host a game';

  @override
  String roundsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rounds',
      one: '1 round',
    );
    return '$_temp0';
  }

  @override
  String get paceClassicSubtitle =>
      'How long does everyone get to guess each photo?';

  @override
  String get paceCaptionSubtitle =>
      'How long does everyone get to write a caption?';

  @override
  String get paceTimelineSubtitle =>
      'How long does everyone get to choose a date?';

  @override
  String get paceMixedSubtitle => 'Each mode keeps its own clock.';

  @override
  String get paceFastClassic => 'Snap decisions.';

  @override
  String get paceNormalClassic => 'The party standard.';

  @override
  String get paceSlowClassic => 'For the big table.';

  @override
  String get paceFastCaption => 'A quick caption.';

  @override
  String get paceNormalCaption => 'Time to be funny.';

  @override
  String get paceSlowCaption => 'No rush, make it good.';

  @override
  String get paceFastTimeline => 'A quick date.';

  @override
  String get paceNormalTimeline => 'Think it through.';

  @override
  String get paceSlowTimeline => 'For the history buffs.';

  @override
  String get paceFastMixed => 'Every mode at its fast clock.';

  @override
  String get paceNormalMixed => 'Every mode at its normal clock.';

  @override
  String get paceSlowMixed => 'Every mode at its slow clock.';

  @override
  String get paceZoomSubtitle => 'Fifteen seconds. One detail.';

  @override
  String get paceSabotageSubtitle => 'Draw, swap and submit.';

  @override
  String get paceFastZoom => 'Early eyes, big points.';

  @override
  String get paceNormalZoom => 'The detail zooms out.';

  @override
  String get paceSlowZoom => 'Every second counts.';

  @override
  String get paceFastSabotage => 'A quick doodle.';

  @override
  String get paceNormalSabotage => 'Time for one good joke.';

  @override
  String get paceSlowSabotage => 'No rush, sabotage it.';

  @override
  String get mixed => 'Mixed';

  @override
  String secondsShort(int seconds) {
    return '${seconds}s';
  }

  @override
  String paceSemantic(String pace, String detail, String blurb) {
    return '$pace, $detail. $blurb';
  }

  @override
  String get paceFast => 'Fast';

  @override
  String get paceNormal => 'Normal';

  @override
  String get paceSlow => 'Slow';

  @override
  String get rejoin => 'Rejoin';

  @override
  String get yourRoom => 'Your room';

  @override
  String get lobby => 'Lobby';

  @override
  String get leaveMatch => 'Leave match';

  @override
  String get scanToJoin => 'Scan to join';

  @override
  String get scanToJoinBody =>
      'Point any camera at the code. No app download needed to join.';

  @override
  String get showRoomQr => 'Show room QR';

  @override
  String get roomQrShareText => 'Join my WhoTook room';

  @override
  String roomCode(String roomId) {
    return 'ROOM $roomId';
  }

  @override
  String get sameWifi => 'Same Wi-Fi';

  @override
  String get online => 'Online';

  @override
  String get onlineWifiHint =>
      'If everyone joins the same Wi-Fi, it is faster and your photos stay on your network.';

  @override
  String get shareInviteLink => 'Share invite link';

  @override
  String get hostStartsPhotoCheck =>
      'The host starts the photo check when everyone is here.';

  @override
  String get waitingForHostToStart => 'Waiting for the host to start';

  @override
  String get matchInProgressTitle => 'Match in progress';

  @override
  String get matchInProgressBody =>
      'You are in the room. The current game is finishing; you join the next one and approve your photos then.';

  @override
  String get watchingLive => 'Live from the table';

  @override
  String watchingRound(int current, int total) {
    return 'Watching round $current of $total';
  }

  @override
  String playersJoined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count players joined',
      one: '1 player joined',
    );
    return '$_temp0';
  }

  @override
  String get waitingFirstFriend => 'Waiting for the first friend';

  @override
  String get waitingFirstFriendBody =>
      'The QR code above is the only thing they need.';

  @override
  String get editAction => 'Edit';

  @override
  String get editGameBody =>
      'Changes reach everyone in the room. You can edit again until the photo check starts.';

  @override
  String get tonightsGame => 'Tonight\'s game';

  @override
  String get modeLabel => 'Mode';

  @override
  String get roundsLabel => 'Rounds';

  @override
  String get paceLabel => 'Pace';

  @override
  String removePlayerTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get removePlayerLobbyBody =>
      'They leave this room. They can join again with the QR code.';

  @override
  String get inviteLink => 'Invite link';

  @override
  String get copied => 'Copied';

  @override
  String get copyLink => 'Copy link';

  @override
  String get playerOptions => 'Player options';

  @override
  String get removeFromRoom => 'Remove from room';

  @override
  String get startPhotoCheck => 'Start photo check';

  @override
  String get hostLabel => 'Host';

  @override
  String get choosing => 'Choosing';

  @override
  String get modeClassic => 'Classic';

  @override
  String get modeCaptionThis => 'Caption This';

  @override
  String get modeTimeTraveler => 'Time Traveler';

  @override
  String get modeMixedParty => 'Mixed Party';

  @override
  String get modeZoomOut => 'Zoom-Out';

  @override
  String get modePhotoSabotage => 'Foto-Sabotage';

  @override
  String get rerollAll => 'Reroll all';

  @override
  String get waitingForPlayersButton => 'Waiting for players';

  @override
  String get forceStartMatch => 'Force start match';

  @override
  String get checkYourPhotos => 'Check your photos';

  @override
  String photosAllHere(int count) {
    return 'All $count photos for this match are here. Reroll all for a different set.';
  }

  @override
  String photosPartial(int count, int needed) {
    return 'You have $count of $needed. Reroll all to fill the set.';
  }

  @override
  String get photosReading => 'Reading the photos for this match.';

  @override
  String photosTooFew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Only $count usable photos found. Add photos or allow more albums in Settings, then reroll. You can still continue with this set.',
      one: 'Only 1 usable photo found. Add photos or allow more albums in Settings, then reroll. You can still continue with this set.',
    );
    return '$_temp0';
  }

  @override
  String get noUsablePhotos => 'No usable photos found';

  @override
  String get noUsablePhotosBody =>
      'Allow photo access, or add a few photos to your gallery. Photos are only read from albums you allow.';

  @override
  String get photoSettings => 'Photo settings';

  @override
  String get secretPhotoPlanted => 'Secret photo planted';

  @override
  String get plantSecretPhoto => 'Plant one secret photo';

  @override
  String get plantSecretPhotoBody =>
      'One per match. It quietly replaces one of your approved photos.';

  @override
  String get couldNotReadAlbums => 'Could not read your albums.';

  @override
  String get couldNotReadAlbum => 'Could not read this album.';

  @override
  String get couldNotReadPhoto => 'That photo could not be read. Try another.';

  @override
  String get couldNotSharePhoto =>
      'That photo could not be shared. Try another.';

  @override
  String get pickPhotoToPlant => 'Pick the photo to plant';

  @override
  String get pickPhotoToPlantBody =>
      'Any photo from your albums. One per match, and nobody learns which one it was until the podium.';

  @override
  String get readingAlbums => 'Reading your albums';

  @override
  String get albumsUnavailable => 'Albums are not available';

  @override
  String get albumsUnavailableBody =>
      'Photo access may be off. Allow it and try again.';

  @override
  String get noPhotosToPlant => 'No photos to plant';

  @override
  String get noPhotosToPlantBody =>
      'No approved photos are available on this device yet.';

  @override
  String get fromApprovedPhotos => 'From your approved photos';

  @override
  String roundOf(int round, int total) {
    return 'Round $round of $total';
  }

  @override
  String get whoTookThis => 'Who took this';

  @override
  String screenshotBy(String name) {
    return '$name took a screenshot';
  }

  @override
  String get lockedInWaiting => 'Locked in, waiting for the others.';

  @override
  String get getReady => 'Get ready';

  @override
  String get tapWhoTook => 'Tap who took the photo as soon as it appears';

  @override
  String get tapNameToLock => 'Tap a name to lock in';

  @override
  String get noAnswer => 'No answer.';

  @override
  String yourPhotoYouGotIt(int points) {
    return 'Your photo. You got it. +$points';
  }

  @override
  String youGotIt(int points) {
    return 'You got it. +$points';
  }

  @override
  String get yourPhotoWrongGuess => 'Your photo. Wrong guess.';

  @override
  String get wrongGuess => 'Wrong guess.';

  @override
  String playersFooled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count players fooled',
      one: '1 player fooled',
    );
    return '$_temp0';
  }

  @override
  String playersDidNotAnswer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count did not answer',
      one: '1 did not answer',
    );
    return '$_temp0';
  }

  @override
  String get everyoneGotItRight => 'Everyone got it right';

  @override
  String shotBy(String name) {
    return 'Shot by $name';
  }

  @override
  String get whoTookIt => 'Who took it?';

  @override
  String fastestAward(String name, String seconds) {
    return 'Fastest: $name ${seconds}s';
  }

  @override
  String get nobodyGuessed => 'Nobody guessed it';

  @override
  String get everyoneNailedIt => 'Everyone nailed it';

  @override
  String get writeFunniestCaption => 'Write the funniest caption';

  @override
  String get captionSentWaiting => 'Caption sent. Waiting for the others.';

  @override
  String get yourCaption => 'Your caption';

  @override
  String get makeItWeird => 'Make it weird.';

  @override
  String get waitingForOthers => 'Waiting for the others';

  @override
  String get sendCaption => 'Send caption';

  @override
  String votesIn(int votes, int total) {
    return '$votes of $total votes in. The reveal starts when everyone has voted.';
  }

  @override
  String get tapOneCaption => 'Tap one caption. You cannot pick your own.';

  @override
  String get voteLockedWaiting => 'Vote locked. Waiting for the table.';

  @override
  String get revealNow => 'Reveal now';

  @override
  String get noCaptions => 'No captions';

  @override
  String get thisRoundMovesOn => 'This round will move on.';

  @override
  String get tableHasSpoken => 'The table has spoken';

  @override
  String photoBy(String name) {
    return 'Photo by $name';
  }

  @override
  String get yourCaptionZero => 'Your caption got zero votes. Brutal.';

  @override
  String yourCaptionVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your caption got $count votes.',
      one: 'Your caption got 1 vote.',
    );
    return '$_temp0';
  }

  @override
  String get zeroVotes => 'Zero votes';

  @override
  String get groupMenace => 'Group menace';

  @override
  String get topCaption => 'Top caption';

  @override
  String voteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
    );
    return '$_temp0';
  }

  @override
  String captionAuthorBadge(String author, String badge) {
    return '$author · $badge';
  }

  @override
  String get whenWasThisTaken => 'When was this taken?';

  @override
  String get guessYearMonth => 'Guess the year and month';

  @override
  String lockedDate(String date) {
    return 'Locked: $date';
  }

  @override
  String lockInDate(String date) {
    return 'Lock in $date';
  }

  @override
  String get timeLord => 'Time Lord';

  @override
  String get mostDelusional => 'Most delusional';

  @override
  String get noGuess => 'No guess';

  @override
  String get exact => 'exact';

  @override
  String offBy(String distance) {
    return 'off by $distance';
  }

  @override
  String monthCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String yearCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String get matchAwards => 'Match awards';

  @override
  String get oneMoreRound => 'One more round (5)';

  @override
  String get backToLobby => 'Back to lobby';

  @override
  String points(int score) {
    return '$score pts';
  }

  @override
  String get quickestDraw => 'Quickest draw';

  @override
  String get longestStreak => 'Longest streak';

  @override
  String get masterOfMystery => 'Unguessable Photo 🕵️';

  @override
  String awardWrongGuesses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wrong guesses',
      one: '1 wrong guess',
    );
    return '$_temp0';
  }

  @override
  String itWasPhotoOf(String name) {
    return 'It was $name\'s photo!';
  }

  @override
  String guessedWrong(String name) {
    return 'Guessed $name ❌';
  }

  @override
  String get guessedCorrectly => 'Guessed right ✓';

  @override
  String get noGuessMade => 'No guess ⏳';

  @override
  String get tapToZoom => '🔍 Tap to zoom';

  @override
  String get tapToZoomBody => 'Pinch to inspect the details';

  @override
  String get paparazzi => 'Paparazzi';

  @override
  String get smoothPlanter => 'Smooth planter';

  @override
  String awardSeconds(String seconds) {
    return '${seconds}s';
  }

  @override
  String awardStreak(int count) {
    return '${count}x';
  }

  @override
  String awardPoints(int count) {
    return '$count pts';
  }

  @override
  String awardFrames(int count) {
    return '$count screenshots';
  }

  @override
  String awardFooled(int count) {
    return 'fooled $count';
  }

  @override
  String moreRounds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more rounds',
      one: '1 more round',
    );
    return '$_temp0';
  }

  @override
  String get swapBeforeTimer => 'Swap anything you like before the timer ends.';

  @override
  String get pickingExtraPhotos => 'Picking extra photos';

  @override
  String get freshFrames =>
      'Fresh frames are coming from your albums. This stays on your device.';

  @override
  String get approve => 'Approve';

  @override
  String get reviewDemo => 'Game demo';

  @override
  String get closeDemo => 'Close demo';

  @override
  String get tryDemo => 'Try the demo';

  @override
  String get tryDemoBody =>
      'Play the real game with three bots and twelve bundled photos.';

  @override
  String get demoIntroTitle => 'A real game, without the setup';

  @override
  String get demoIntroBody =>
      'This demo runs the same host, rules and screens as a live room. Three bots join with twelve bundled photos. Your gallery, camera and network are not used.';

  @override
  String get demoIntroNotice =>
      'Everything here is simulated. Nothing leaves this phone.';

  @override
  String get demoLineup => 'Your table';

  @override
  String get demoBotRoles =>
      'You are the host. Lotte, Sam and Noor answer automatically, but you still get to play every round.';

  @override
  String get demoTryModes =>
      'Change the mode in the lobby to try Classic, Zoom-Out, Make It Meme, Foto-Sabotage, Time Traveler or Mixed Party.';

  @override
  String get startDemo => 'Start demo';

  @override
  String get demoLobbyTitle => 'Your demo table';

  @override
  String get demoLobbyBody =>
      'Three bots are ready. Start the photo check when you want to play.';

  @override
  String get demoPreparing => 'Setting up the demo table';

  @override
  String get demoFailed => 'The demo could not start. Close it and try again.';

  @override
  String get endDemoTitle => 'End demo?';

  @override
  String get endDemoBody =>
      'The bots and this room will be removed. Your real rooms are not affected.';

  @override
  String get endDemo => 'End demo';

  @override
  String get demoEndedTitle => 'Demo ended';

  @override
  String get demoEndedBody =>
      'You can close this screen and start a real room, or play the demo again.';

  @override
  String get placeFirst => '1st';

  @override
  String get placeSecond => '2nd';

  @override
  String get placeThird => '3rd';

  @override
  String placeNth(int place) {
    return '${place}th';
  }

  @override
  String get lockedIn => 'Locked in';

  @override
  String get podium => 'Podium';

  @override
  String get champion => 'Champion';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get nameLabel => 'Name';

  @override
  String get nameHelper => 'Shown to other players';

  @override
  String get avatar => 'Avatar';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'Follow the device';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get privateAlbums => 'Private albums';

  @override
  String excludedCount(int count) {
    return '$count excluded';
  }

  @override
  String get privateAlbumsBody =>
      'Optional. Excluded albums are never drawn from in any match.';

  @override
  String get albumListUnavailable => 'Album list unavailable';

  @override
  String get albumListUnavailableBody =>
      'Photo access was not granted. Allow it and try again.';

  @override
  String get noAlbums => 'No albums found';

  @override
  String get noAlbumsBody =>
      'Allow photo access to choose private albums. Photos are only read when a match starts.';

  @override
  String get allowPhotoAccess => 'Allow photo access';

  @override
  String photosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get onlineRelay => 'Online relay';

  @override
  String get onlineRelayBody =>
      'Local play never uses a server. Online play uses a small relay for friends elsewhere.';

  @override
  String get selfHostedRelay => 'Self-hosted relay';

  @override
  String get selfHostedRelayBody =>
      'Point the app at your own signaling and TURN server';

  @override
  String get signalingUrl => 'Signaling URL';

  @override
  String signalingUrlHelper(String url) {
    return 'Default: $url';
  }

  @override
  String get customTurnUrl => 'TURN URI';

  @override
  String get customTurnHelper => 'Optional, e.g. turn:turn.example.org:3478';

  @override
  String get turnUsername => 'Username';

  @override
  String get turnCredential => 'Password';

  @override
  String get resetToDefault => 'Reset to default';

  @override
  String get saveRelay => 'Save relay';

  @override
  String get helpAndLegal => 'Help and legal';

  @override
  String get reportContent => 'Report content or a player';

  @override
  String reportBody(String email) {
    return 'Send the room code and what happened to $email';
  }

  @override
  String get reportIssue => 'Report this issue';

  @override
  String reportIssueBody(String email) {
    return 'Send diagnostics and recent errors to $email';
  }

  @override
  String get reportBodyIntro =>
      'What went wrong? (Type your explanation above)';

  @override
  String get reportDiagnostics => 'Diagnostics (do not remove)';

  @override
  String get reportRecentLogs => 'Recent logs';

  @override
  String reportNoMailApp(String email) {
    return 'No mail app found. The report was copied to the clipboard. Mail it to $email.';
  }

  @override
  String get reportCopyFailed =>
      'Could not open a mail app or copy the report.';

  @override
  String get reportEmailAction => 'Email with diagnostics';

  @override
  String get reportEmailBody => 'A short report that fits in any mail app';

  @override
  String get reportShareAction => 'Share log file';

  @override
  String get reportShareBody =>
      'The full report as a text file, to send as an attachment';

  @override
  String reportShareMessage(String email) {
    return 'WhoTook diagnostics for $email. The full report is attached as a text file.';
  }

  @override
  String get reportCopyAction => 'Copy report';

  @override
  String get reportCopied => 'Report copied to the clipboard.';

  @override
  String get reportShareFailed => 'Could not share the log file.';

  @override
  String get demoTakingLong => 'This is taking longer than expected.';

  @override
  String get demoRetry => 'Try again';

  @override
  String get termsAndRules => 'Terms and community rules';

  @override
  String get openSource =>
      'Open source under the AGPLv3. Photos stay on your phone.';

  @override
  String get trademark => 'WhoTook™ is a trademark of the project owner.';

  @override
  String get relaySignalingSchemeError =>
      'Signaling URL must start with https://, http://, wss:// or ws://';

  @override
  String get relayTurnSchemeError => 'TURN URL must start with turn: or turns:';

  @override
  String get relaySaved => 'Relay saved';

  @override
  String get relayDefault => 'Back to the default relay';

  @override
  String get about => 'About';

  @override
  String get support => 'Support';

  @override
  String avatarOption(int number) {
    return 'Avatar $number';
  }

  @override
  String get yourPhotoAvatar => 'Your photo avatar';

  @override
  String get pickAnAvatar => 'Pick an avatar';

  @override
  String get photoAvatarStored =>
      'Stored on this phone and shared only in the room.';

  @override
  String get avatarChoices =>
      'A selfie, a photo from your gallery, or an icon.';

  @override
  String get takeSelfie => 'Take a selfie';

  @override
  String get choosePhoto => 'Choose a photo';

  @override
  String get useIcon => 'Use an icon';

  @override
  String get cropTitle => 'Your photo';

  @override
  String get cropHint => 'Pinch to zoom and drag to centre your face.';

  @override
  String get savingPhoto => 'Saving photo';

  @override
  String get useThisPhoto => 'Use this photo';

  @override
  String get hostControls => 'Host controls';

  @override
  String get skipRound => 'Skip round';

  @override
  String get removePlayer => 'Remove player';

  @override
  String get skipRoundTitle => 'Skip this round?';

  @override
  String get skipRoundBody =>
      'The current screen ends now and the next round starts.';

  @override
  String get skipButton => 'Skip';

  @override
  String get removeAPlayer => 'Remove a player';

  @override
  String get removePlayerMatchBody =>
      'They leave this match. Their photo rounds stay in the game.';

  @override
  String get differentVersions => 'Different app versions';

  @override
  String versionWarningBody(
    String latestVersion,
    int latestBuild,
    String ownVersion,
    int ownBuild,
  ) {
    return 'Someone is on $latestVersion. You are on $ownVersion. Update so rounds and photos stay in sync.';
  }

  @override
  String get getUpdate => 'Get the update';

  @override
  String get keepPlaying => 'Keep playing';

  @override
  String get connectionLost => 'Connection lost';

  @override
  String reconnectingIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds left.',
      one: '1 second left.',
    );
    return 'Trying to reconnect. $_temp0';
  }

  @override
  String get leaveRoom => 'Leave room';

  @override
  String get leaveRoomTitle => 'Leave this room?';

  @override
  String get leaveRoomHostBody => 'The room closes for everyone.';

  @override
  String get leaveRoomGuestBody =>
      'You leave the room and can rejoin with the QR code.';

  @override
  String streakLabel(int count) {
    return 'Streak $count';
  }

  @override
  String get modeClassicBlurb => 'Guess who took it.';

  @override
  String get modeCaptionThisBlurb => 'Write the funniest caption.';

  @override
  String get modeTimeTravelerBlurb => 'Guess the year and month.';

  @override
  String get modeMixedPartyBlurb => 'All five, shuffled.';

  @override
  String get modeZoomOutBlurb => 'Guess the photo as it zooms out.';

  @override
  String get modePhotoSabotageBlurb => 'Doodle on a friend\'s photo.';

  @override
  String get mixedModesLabel => 'Mixed Party modes';

  @override
  String get mixedModesHint =>
      'Pick at least two. Rounds stay balanced and never repeat the same mode twice in a row.';

  @override
  String get mixedModesMinimum => 'Keep at least two modes in Mixed Party.';

  @override
  String modeSemantic(String label, String blurb) {
    return '$label. $blurb';
  }

  @override
  String get errorNoDatedPhotos =>
      'No photos with a date found. Allow another album or pick a different mode.';

  @override
  String get errorNeedAnotherPlayer =>
      'One more player has to scan the QR code before the match starts';

  @override
  String get errorPlayersNotReady => 'Everyone has to tap Ready first';

  @override
  String get errorPhotoAccessHost =>
      'Photo access is off. Allow photos in Settings, then start the photo check.';

  @override
  String get errorPhotoAccessClient =>
      'Photo access is off. Allow photos in Settings, then tap Reroll all.';

  @override
  String get errorOpenRoom => 'Could not open the room. Try again.';

  @override
  String get errorInvalidInvite =>
      'That invite is not valid. Scan the QR code again.';

  @override
  String get errorRelayLimit =>
      'Online relay is used up for today. Join the same Wi-Fi or a hotspot to keep playing.';

  @override
  String get errorReachHost =>
      'Could not reach the host. Check that you are on the same Wi-Fi or hotspot.';

  @override
  String get errorHostEnded =>
      'The host ended the room. Scan a new QR or host your own game.';

  @override
  String get errorRoomStarted =>
      'That room already started. Ask the host to open the lobby again.';

  @override
  String get errorRemovedByHost => 'The host removed you from the room.';

  @override
  String get errorSomethingWentWrong => 'Something went wrong. Try again.';

  @override
  String get errorNoPhotos => 'The host did not receive your photos';

  @override
  String get countdown => 'Countdown';

  @override
  String countdownSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String get syncingVaults => 'Syncing vaults';

  @override
  String syncingVaultsProgress(int received, int total) {
    return '$received of $total photos ready';
  }

  @override
  String get loadingStartingMatch => 'Starting match';

  @override
  String get loadingReadingPhotos => 'Reading your photos';

  @override
  String get loadingJoining => 'Joining match';

  @override
  String get errorPlantUsed => 'This photo plant is once per game.';

  @override
  String get errorNotReady => 'Tap Ready before planting a photo.';

  @override
  String get errorNotPlanter =>
      'Only the chosen player can plant a photo this game.';

  @override
  String get errorWrongOwner => 'That photo is not yours.';

  @override
  String get errorNoUnplayedPhoto =>
      'Every approved photo has already been shown.';

  @override
  String get errorEmptyCaption => 'Write something first.';

  @override
  String get errorCaptionTooLong => 'Keep the caption under 80 characters.';

  @override
  String get errorAlreadyGuessed => 'Your guess is already locked.';

  @override
  String get errorAlreadyVoted => 'Your vote is already locked.';

  @override
  String get errorAlreadyCaptioned => 'Your caption is already locked.';

  @override
  String secondsLeftShort(String seconds) {
    return '$seconds s left';
  }

  @override
  String get roundsUnit => 'rounds';

  @override
  String get youreIn => 'You\'re in';

  @override
  String get swap => 'Swap';

  @override
  String get revealing => 'Revealing...';

  @override
  String get yours => 'Yours';

  @override
  String get couldNotOpenLink => 'Could not open this link.';

  @override
  String get you => 'You';

  @override
  String get advancedSettings => 'Advanced settings';

  @override
  String get advancedSettingsBody => 'Relay, TURN and self-hosting.';

  @override
  String get modeMakeItMeme => 'Make It Meme';

  @override
  String get modeMakeItMemeBlurb => 'Make a meme from a friend\'s photo.';

  @override
  String get paceMemeSubtitle => 'How long does everyone get to build a meme?';

  @override
  String get paceFastMeme => 'A quick meme.';

  @override
  String get paceNormalMeme => 'Time to build the joke.';

  @override
  String get paceSlowMeme => 'No rush, make it good.';

  @override
  String get memeVaultTitle => 'Your photos.';

  @override
  String get memeVaultBody =>
      'Reroll the whole set if something should not be in the game.';

  @override
  String get memeVaultOnly => 'Only these photos enter the game.';

  @override
  String get memeVaultReady => 'Ready';

  @override
  String get memeVaultReroll => 'Reroll all';

  @override
  String get memeWritingLabel => 'Build the meme';

  @override
  String get memeRoundSwaps => 'Round swaps';

  @override
  String get memeTemplate => 'Template';

  @override
  String get memeTemplateClassic => 'Classic';

  @override
  String get memeTemplatePov => 'POV';

  @override
  String get memeTemplateBreaking => 'Breaking';

  @override
  String get memeTemplateLive => 'Live';

  @override
  String get memeTemplatePoster => 'Poster';

  @override
  String get memeTemplateSnap => 'Snap bar';

  @override
  String get memeTemplateSplit => 'Split';

  @override
  String get memeTopLine => 'Top line';

  @override
  String get memeBottomLine => 'Bottom line';

  @override
  String get memeHeader => 'Header';

  @override
  String get memeHeadline => 'Headline';

  @override
  String get memeReaction => 'Reaction';

  @override
  String get memeTitle => 'Title';

  @override
  String get memeSubtitle => 'Subtitle';

  @override
  String get memeBarText => 'Bar text';

  @override
  String get memeTopPanel => 'Top panel';

  @override
  String get memeBottomPanel => 'Bottom label';

  @override
  String get memeWritePrompt => 'Make the joke.';

  @override
  String get memeSend => 'Send meme';

  @override
  String get memeSentWaiting => 'Meme sent. Waiting for the others.';

  @override
  String get memeSwapPhoto => 'Swap photo';

  @override
  String memeSwapsLeft(int count) {
    return '$count left';
  }

  @override
  String get memeSwapsRoundWide =>
      '5 swaps every round. Swapped photos go back into the pool.';

  @override
  String get memeVoteTitle => 'Vote on this meme.';

  @override
  String get memeVoteSubtitle =>
      'Upvote, Meh or Downvote. You cannot vote for your own meme.';

  @override
  String get memeUpvote => 'Upvote';

  @override
  String get memeMeh => 'Meh';

  @override
  String get memeDownvote => 'Downvote';

  @override
  String get memeAnonymous => 'Anonymous until the reveal';

  @override
  String get memeYourMeme => 'Your meme';

  @override
  String get memeVoteLocked => 'Vote locked.';

  @override
  String get memeTapToVote => 'Tap one to vote.';

  @override
  String get memeRoundWinner => 'Round winner';

  @override
  String get memeCreatorPoints => 'Creator points';

  @override
  String get memeTopMemes => 'Top 3 memes';

  @override
  String get memeFinalRound =>
      'Final round: everyone gets the same photo. Double points.';

  @override
  String get memeDownload => 'Save meme';

  @override
  String get memeSaved => 'Meme saved.';

  @override
  String get memeSaveFailed => 'Could not save the meme.';

  @override
  String memePhotoFrom(Object name) {
    return 'Photo from $name';
  }

  @override
  String memePoints(int score) {
    return '$score pts';
  }

  @override
  String get memeVotesUp => 'Upvotes';

  @override
  String get memeVotesMeh => 'Meh';

  @override
  String get memeVotesDown => 'Down';

  @override
  String get memeWriteSomething => 'Write something first.';

  @override
  String get music => 'Music';

  @override
  String get musicBody => 'Party loop for the lobby and rounds';

  @override
  String get soundEffects => 'Sound effects';

  @override
  String get soundEffectsBody => 'Buttons, votes and reveals';

  @override
  String get memeHaptics => 'Haptics';

  @override
  String get memeHapticsBody => 'A tap when a vote lands';

  @override
  String get photoLoading => 'Loading photo...';

  @override
  String roundBadge(int current, int total) {
    return 'ROUND $current/$total';
  }

  @override
  String waitingForVotes(int voted, int eligible) {
    return 'Waiting for votes: $voted/$eligible voted';
  }

  @override
  String get endVoting => 'End voting / Skip AFK';

  @override
  String get votesAreIn => 'Votes are in!';

  @override
  String get countingVotes => 'Counting the votes...';

  @override
  String get nextRound => 'Next Round';

  @override
  String get waitingForHostToContinue => 'Waiting for host to continue...';

  @override
  String get winningMemeTitle => 'Winning meme of the match';

  @override
  String memeVoteTally(int up, int meh, int down) {
    return '$up up · $meh meh · $down down';
  }

  @override
  String roundSplashKicker(int round) {
    return 'ROUND $round';
  }

  @override
  String get classicSplashPhotographer => 'Guess the photographer!';

  @override
  String get classicSplashGallery => 'Whose gallery is this from?';

  @override
  String get classicSplashDetails => 'Look closely at the details!';

  @override
  String get classicSplashWho => 'Who took this shot?';

  @override
  String get memeSplashRoast => 'Time to roast!';

  @override
  String get memeSplashFunniest => 'Think of the funniest meme!';

  @override
  String get memeSplashRidicule => 'Make your friends ridiculous!';

  @override
  String get memeSplashLaugh => 'Make the room laugh!';

  @override
  String get timeSplashMachine => 'Start the time machine!';

  @override
  String get timeSplashYear => 'What year was this?!';

  @override
  String get timeSplashHair => 'Check the haircuts and clothes!';

  @override
  String get timeSplashBack => 'Travel back in time!';

  @override
  String get zoomSplashFocus => 'Focus on the details!';

  @override
  String get zoomSplashWho => 'Zooming out... whose photo is this?!';

  @override
  String get zoomSplashEarly => 'Dare to guess early?';

  @override
  String get zoomSplashClose => 'The closer you look, the more you score!';

  @override
  String get sabotageSplashMarker => 'Grab your marker: sabotage time!';

  @override
  String get sabotageSplashRuin => 'Ruin your friend\'s photo!';

  @override
  String get sabotageSplashRidiculous => 'Draw something ridiculous!';

  @override
  String get sabotageSplashDraw => 'Make them laugh out loud!';

  @override
  String roundSplash(int round, String mode) {
    return 'ROUND $round: $mode!';
  }

  @override
  String get selfieStickerTitle => 'Your sticker';

  @override
  String get selfieStickerBody => 'Snap a quick selfie or pick a cartoon face.';

  @override
  String get playerVoted => 'Voted';

  @override
  String get pickDecade => 'Pick a decade';

  @override
  String get pickYear => 'Pick a year';

  @override
  String get pickMonth => 'Pick a month';

  @override
  String get actualDate => 'Actual date';

  @override
  String get yourGuess => 'Your guess';

  @override
  String averageMiss(String distance) {
    return 'Average miss: $distance';
  }

  @override
  String get ownerLabel => 'OWNER';

  @override
  String get breakingNews => 'BREAKING NEWS';

  @override
  String get liveBadge => '● LIVE';

  @override
  String get gameFeel => 'Game feel';

  @override
  String get finalTable => 'Final table';

  @override
  String get memeNoMemes => 'No memes this round.';

  @override
  String get partyPassTitle => 'WhoTook Party Pass';

  @override
  String get partyPassSubtitle => 'One payment. Every party feature, forever.';

  @override
  String get partyPassPerkRelayTitle => 'Play Anywhere';

  @override
  String get partyPassPerkRelayBody =>
      'Friends on mobile data or another Wi-Fi join through our encrypted relay. Same Wi-Fi is always free. The relay has a daily limit.';

  @override
  String get partyPassPerkSoundboardTitle => 'Live soundboard';

  @override
  String get partyPassPerkSoundboardBody =>
      'Drop Airhorn, Vine Boom and more during rounds. Everyone in the room hears it.';

  @override
  String get partyPassPerkThemesTitle => 'Shared room themes';

  @override
  String get partyPassPerkThemesBody =>
      'Pick a premium theme and every friend\'s phone switches with you for the whole match.';

  @override
  String partyPassUnlockButton(String price) {
    return 'Unlock Forever, $price';
  }

  @override
  String get partyPassRestore => 'Restore purchases';

  @override
  String get partyPassRestoreHint =>
      'Already bought it? Restore it on this device.';

  @override
  String get partyPassActiveBadge => 'Party Pass Active';

  @override
  String get partyPassActiveBody =>
      'Play Anywhere, the soundboard and shared themes are unlocked on this device.';

  @override
  String partyPassFairUse(int remaining, int limit) {
    return '$remaining of $limit relay matches left today';
  }

  @override
  String get partyPassStoreUnavailable =>
      'The store is not available in this build. Install WhoTook from the App Store or Google Play to buy or restore the Party Pass.';

  @override
  String get partyPassStoreButton => 'Get the store version';

  @override
  String get partyPassPaddleUnavailable =>
      'Online checkout is unavailable right now. You can still enter a license key.';

  @override
  String get partyPassLicenseButton => 'I have a license key';

  @override
  String get partyPassLicenseTitle => 'Enter your Party Pass license';

  @override
  String get partyPassLicenseHint =>
      'WT-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX';

  @override
  String get partyPassLicenseApply => 'Unlock Party Pass';

  @override
  String get partyPassRestoreHintPaddle =>
      'Already bought it? Restore the purchase or enter the license key.';

  @override
  String get partyPassCustomTurn => 'Use your own TURN server';

  @override
  String get partyPassPurchasePending => 'Waiting for the purchase to confirm…';

  @override
  String get partyPassErrorCanceled =>
      'Purchase canceled. Nothing was charged.';

  @override
  String get partyPassErrorUnavailable =>
      'The store is not available right now. Try again in a moment.';

  @override
  String get partyPassErrorProduct =>
      'The Party Pass product is not available in this store yet.';

  @override
  String get partyPassErrorRestoreEmpty =>
      'No previous Party Pass purchase was found on this account.';

  @override
  String get partyPassErrorRevoked =>
      'This Party Pass is no longer valid. Restore purchases, or contact support if you think this is a mistake.';

  @override
  String get partyPassErrorGeneric =>
      'Something went wrong. Try again, or restore purchases.';

  @override
  String get partyPassErrorInvalidLicense =>
      'That license key is not valid. Check the key and try again.';

  @override
  String get partyPassErrorLicenseMissing =>
      'The purchase completed, but the license was not returned. Restore the purchase or contact support.';

  @override
  String get partyPassErrorPurchaseExpired =>
      'This checkout expired. Start a new purchase.';

  @override
  String get partyPassErrorPurchaseNotFound =>
      'No pending purchase was found. Start a new purchase.';

  @override
  String get partyPassErrorRateLimited =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get partyPassErrorCheckoutUnavailable =>
      'Checkout is not available right now. Try again later.';

  @override
  String get partyPassErrorCheckoutOpenFailed =>
      'The checkout page could not open. Try again, or enter your license key.';

  @override
  String get partyPassErrorNetwork =>
      'Could not reach the purchase service. Check your connection and try again.';

  @override
  String get partyPassRelayError =>
      'The relay could not verify this purchase right now. Direct play still works.';

  @override
  String get partyPassTerms => 'Terms';

  @override
  String get partyPassPrivacy => 'Privacy';

  @override
  String partyPassLobbyButton(String price) {
    return 'Party Pass ($price)';
  }

  @override
  String get partyPassLobbyActive => 'Party Pass Active';

  @override
  String get partyPassLoading => 'Checking your pass…';

  @override
  String get roomThemePickerTitle => 'Room theme';

  @override
  String get roomThemePickerBody =>
      'The theme applies to every phone in this lobby for the whole match.';

  @override
  String get roomThemeClassicParty => 'Classic Party';

  @override
  String get roomThemeMidnightArcade => 'Midnight Arcade';

  @override
  String get roomThemeCyberNeon => 'Cyber Neon';

  @override
  String get roomThemeRetroPolaroid => 'Retro Polaroid 90s';

  @override
  String get roomThemePubKroeg => 'Pub / Kroeg Mode';

  @override
  String get roomThemePremium => 'Party Pass';

  @override
  String get roomThemeSelected => 'Selected';

  @override
  String get roomThemeLocked => 'Unlock the Party Pass to share this theme';

  @override
  String get lobbyThemeLabel => 'Theme';

  @override
  String get lobbySoundboardLabel => 'Soundboard';

  @override
  String get lobbyRelayLabel => 'Relay';

  @override
  String get lobbySoundboardOn => 'Ready';

  @override
  String get lobbySoundboardOff => 'Pass only';

  @override
  String get relayStatusLocal => 'Same Wi-Fi';

  @override
  String get relayStatusDirect => 'Direct P2P';

  @override
  String get relayStatusRelay => 'Online relay';

  @override
  String get relayStatusCustom => 'Custom TURN';

  @override
  String get relayStatusOffline => 'Not connected';

  @override
  String get soundboardTitle => 'Soundboard';

  @override
  String get soundboardHint => 'Tap a sound. Everyone hears it.';

  @override
  String get soundboardCollapse => 'Hide soundboard';

  @override
  String get soundboardExpand => 'Show soundboard';

  @override
  String soundboardCooldown(int seconds) {
    return 'Wait ${seconds}s';
  }

  @override
  String get soundboardLocked =>
      'The live soundboard is part of the Party Pass.';

  @override
  String get soundVineBoom => 'Vine Boom';

  @override
  String get soundAirhorn => 'Airhorn';

  @override
  String get soundCrickets => 'Crickets';

  @override
  String get soundSadTrombone => 'Sad Trombone';

  @override
  String get soundDrumroll => 'Drumroll';

  @override
  String get soundLaughTrack => 'Laugh Track';

  @override
  String soundPlayedToast(String name, String sound) {
    return '$name played $sound';
  }

  @override
  String get firewallTitle => 'This network blocks direct play';

  @override
  String get firewallBody =>
      'Same Wi-Fi is always free. Connect to the same Wi-Fi or hotspot to play, or unlock Play Anywhere with the Party Pass.';

  @override
  String get firewallWifiAction => 'Play on Wi-Fi/Hotspot';

  @override
  String get firewallUnlockAction => 'Unlock Party Pass';

  @override
  String get firewallRelayDownTitle => 'Relay could not connect';

  @override
  String get firewallRelayDownBody =>
      'Your Party Pass is active, but the relay did not answer. Check your connection, then try again.';

  @override
  String get firewallRetryAction => 'Try again';

  @override
  String get settingsPartyPassTitle => 'WhoTook Party Pass';

  @override
  String get settingsPartyPassActive => 'Active on this device';

  @override
  String get settingsPartyPassInactive =>
      'Play Anywhere, soundboard and shared themes';

  @override
  String get errorRelayUnavailable =>
      'The relay is unavailable right now. Direct play still works.';

  @override
  String get roomThemeFree => 'Free for everyone';

  @override
  String get roomThemePreviewHint =>
      'Tap a theme to preview it live on the lobby.';

  @override
  String roomThemePreviewing(String theme) {
    return '👀 Previewing \"$theme\"';
  }

  @override
  String get roomThemeApply => '✓ Apply Theme to Room';

  @override
  String roomThemeUnlockPass(String price) {
    return '🔓 Unlock Party Pass ($price) to use in match';
  }

  @override
  String get roomThemeRevert => 'Revert';

  @override
  String get roomThemeApplied => 'Theme applied to the room';

  @override
  String get firewallQuotaTitle => 'Daily relay limit reached';

  @override
  String get firewallQuotaBody =>
      'Your Party Pass relay allowance is used up. It resets on a rolling 24-hour window. Play on the same Wi-Fi/hotspot, or configure your own TURN server.';

  @override
  String get firewallVerificationTitle => 'Could not verify this purchase';

  @override
  String get firewallVerificationBody =>
      'Restore purchases from the Party Pass sheet, or contact support. Direct play still works.';

  @override
  String firewallQuotaReset(String time) {
    return 'Next allowance: $time';
  }

  @override
  String get firewallBusyTitle => 'Relay is busy';

  @override
  String get firewallBusyBody =>
      'Too many relay attempts from this network. Wait a moment and try again.';

  @override
  String firewallBusyReset(String time) {
    return 'Try again after $time';
  }

  @override
  String get firewallRetryNow => 'Retry now';

  @override
  String get errorHostStarting =>
      'The host is still opening the room. Try again in a moment.';

  @override
  String get errorInviteExpired =>
      'This invite has expired. Ask the host for a new QR code.';

  @override
  String get roomThemePreviewBadge => 'PREVIEW';

  @override
  String get gamePhoto => 'Game photo';

  @override
  String zoomPotential(int points) {
    return '+$points pts';
  }

  @override
  String zoomLockedIn(String scale) {
    return 'Locked in at $scale!';
  }

  @override
  String get zoomWrongLocked => 'Wrong! Locked out';

  @override
  String zoomEagleEye(String name, String scale) {
    return 'Eagle Eye: $name at $scale!';
  }

  @override
  String get zoomNoEagleEye => 'No eagle eyes this round.';

  @override
  String get zoomFullPhoto => 'The full photo';

  @override
  String get sabotageDrawTitle => 'Sabotage the photo';

  @override
  String sabotageDrawHint(String name) {
    return 'Draw on $name\'s photo.';
  }

  @override
  String get sabotageDrawFirst => 'Draw something first.';

  @override
  String get sabotagePreparing => 'Getting your photo...';

  @override
  String get sabotageUndo => 'Undo';

  @override
  String get sabotageColor1 => 'Black';

  @override
  String get sabotageColor2 => 'White';

  @override
  String get sabotageColor3 => 'Red';

  @override
  String get sabotageColor4 => 'Yellow';

  @override
  String get sabotageColor5 => 'Green';

  @override
  String get sabotageClear => 'Clear';

  @override
  String get sabotageThin => 'Thin';

  @override
  String get sabotageThick => 'Thick';

  @override
  String get sabotageSend => 'Send sabotage';

  @override
  String get sabotageSent => 'Sabotage sent. Waiting for the others.';

  @override
  String get sabotageVoteTitle => 'Which sabotage wins?';

  @override
  String get sabotageVoteSubtitle => 'React to the drawing, not the photo.';

  @override
  String sabotageWaitingVotes(int current, int total) {
    return 'Waiting for votes: $current/$total';
  }

  @override
  String get sabotageNoSubmissions => 'No sabotages this round.';

  @override
  String get sabotageRevealTitle => 'The sabotage revealed';

  @override
  String get topCreations => 'Top 3 memes & sabotages';

  @override
  String get winningSabotage => 'WINNING SABOTAGE';

  @override
  String get sabotageSave => 'Save sabotage';
}
