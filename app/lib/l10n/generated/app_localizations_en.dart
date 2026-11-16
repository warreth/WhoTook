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
      'Classic, Make It Meme, Time Traveler or a bit of everything.';

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
  String get paceMixedSubtitle =>
      'Each of the three modes keeps its own clock.';

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
  String roomCode(String roomId) {
    return 'ROOM $roomId';
  }

  @override
  String get sameWifi => 'Same Wi-Fi';

  @override
  String get online => 'Online';

  @override
  String get shareInviteLink => 'Share invite link';

  @override
  String get hostStartsPhotoCheck =>
      'The host starts the photo check when everyone is here.';

  @override
  String get waitingForHostToStart => 'Waiting for the host to start';

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
  String get rerollAll => 'Reroll all';

  @override
  String get waitingForPlayersButton => 'Waiting for players';

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
  String get masterOfMystery => 'Master of mystery';

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
  String get reviewDemo => 'Review demo';

  @override
  String get closeDemo => 'Close demo';

  @override
  String get demoFake =>
      'Demo with fake players. No network and no real photos.';

  @override
  String get allDemoPhotos =>
      'All 4 demo photos are here. Reroll all for a different set.';

  @override
  String get startDemoRound => 'Start demo round';

  @override
  String get timerRanOut => 'The timer ran out.';

  @override
  String youGuessed(String name) {
    return 'You guessed $name. Next time.';
  }

  @override
  String get seePodium => 'See the podium';

  @override
  String get restartDemo => 'Restart demo';

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
    return 'Someone is on $latestVersion (build $latestBuild). You are on $ownVersion (build $ownBuild). Update so rounds and photos stay in sync.';
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
  String get modeMixedPartyBlurb => 'All three, shuffled.';

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
  String get memeVaultTitle => 'Your six photos.';

  @override
  String get memeVaultBody =>
      'Reroll the whole set if something should not be in the game.';

  @override
  String get memeVaultOnly => 'Only these six photos enter the game.';

  @override
  String get memeVaultReady => 'Ready';

  @override
  String get memeVaultReroll => 'Reroll all';

  @override
  String get memeWritingLabel => 'Build the meme';

  @override
  String get memeMatchSwaps => 'Match swaps';

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
  String get memeSwapsMatchWide => '5 swaps for the whole match.';

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
  String get memeNextMeme => 'Next meme';

  @override
  String get memeSeeResult => 'See result';

  @override
  String get memeVoteLocked => 'Vote locked.';

  @override
  String get memeTapToVote => 'Tap one to vote.';

  @override
  String get memeWaitingVotes => 'Waiting for the rest of the table.';

  @override
  String get memeRoundWinner => 'Round winner';

  @override
  String get memeCreatorPoints => 'Creator points';

  @override
  String get memeModelRoyalty => 'Model royalty';

  @override
  String memeRoyaltyBody(String name) {
    return '$name\'s photo was in the winning meme. $name gets +25.';
  }

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
  String get memeSound => 'Sound';

  @override
  String get memeSoundBody => 'Ticks, votes and the podium fanfare';

  @override
  String get memeHaptics => 'Haptics';

  @override
  String get memeHapticsBody => 'A tap when a vote lands';

  @override
  String get pickDecade => 'Pick a decade';

  @override
  String get pickYear => 'Pick a year';

  @override
  String get pickMonth => 'Pick a month';

  @override
  String get actualDate => 'Actual date';

  @override
  String get ownerIncluded => 'Owner included';

  @override
  String averageMiss(String distance) {
    return 'Average miss: $distance';
  }

  @override
  String get yourGuess => 'Your guess';

  @override
  String get ownerLabel => 'OWNER';

  @override
  String get breakingNews => 'BREAKING NEWS';

  @override
  String get liveBadge => '● LIVE';

  @override
  String get gameFeel => 'Game feel';

  @override
  String get alsoInTheRoom => 'Also in the room';

  @override
  String get finalTable => 'Final table';

  @override
  String get memeNoMemes => 'No memes this round.';

  @override
  String get partyPassTitle => 'WhoTook Party Pass';

  @override
  String get partyPassSubtitle => 'One payment. Every party feature, forever.';

  @override
  String get partyPassPerkRelayTitle => '5G & firewall relay';

  @override
  String get partyPassPerkRelayBody =>
      'Play through strict 5G and carrier NATs with our encrypted relay, with a fair-use allowance every day.';

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
    return 'Unlock Forever — $price';
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
      'Relay, soundboard and shared themes are unlocked on this device.';

  @override
  String partyPassFairUse(int remaining, int limit) {
    return '$remaining of $limit relay matches left today';
  }

  @override
  String get partyPassFossIncluded => 'Included in this FOSS build';

  @override
  String get partyPassFossBody =>
      'No store, no tracking. The soundboard and all themes are free, and you can point the app at your own TURN server.';

  @override
  String get partyPassCustomTurn => 'Use your own TURN server';

  @override
  String get partyPassStoreUnavailable =>
      'The store is not available in this build. Restore purchases after installing from the App Store or Google Play.';

  @override
  String get partyPassPurchasePending =>
      'Waiting for the store to confirm your purchase…';

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
  String get partyPassErrorGeneric =>
      'Something went wrong. Try again, or restore purchases.';

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
  String get relayStatusRelay => '5G relay';

  @override
  String get relayStatusCustom => 'Custom TURN';

  @override
  String get relayStatusOffline => 'Not connected';

  @override
  String get relayStatusFoss => 'Self-host ready';

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
  String get firewallTitle => 'Strict 5G firewall detected!';

  @override
  String get firewallBody =>
      'Connect to the same Wi-Fi/Hotspot to play 100% free, or unlock the WhoTook Party Pass (€2.99 once) to use our high-speed 5G Relay Server.';

  @override
  String get firewallWifiAction => 'Play on Wi-Fi/Hotspot';

  @override
  String get firewallUnlockAction => 'Unlock Party Pass';

  @override
  String get firewallFossAction => 'Set up custom TURN';

  @override
  String get firewallRelayDownTitle => 'Relay could not connect';

  @override
  String get firewallRelayDownBody =>
      'Your Party Pass is active, but the relay did not answer. Check your connection, then try again.';

  @override
  String get firewallRetryAction => 'Try again';

  @override
  String get fossTurnTitle => 'Custom TURN Server (Self-Host)';

  @override
  String get fossTurnBody =>
      'FOSS builds never use the official relay. Point the app at your own coturn server for strict networks.';

  @override
  String get fossTurnSaved => 'Custom TURN saved';

  @override
  String get fossBuildBadge => 'FOSS build';

  @override
  String get fossBuildBody => 'No billing, no analytics, no official relay.';

  @override
  String get settingsPartyPassTitle => 'WhoTook Party Pass';

  @override
  String get settingsPartyPassActive => 'Active on this device';

  @override
  String get settingsPartyPassInactive => 'Relay, soundboard and shared themes';

  @override
  String get errorRelayUnavailable =>
      'The relay is unavailable right now. Direct play still works.';

  @override
  String get roomThemeFree => 'Free for everyone';

  @override
  String get turnCredentialPairError =>
      'Fill in both the TURN username and password, or leave both empty.';

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
}
