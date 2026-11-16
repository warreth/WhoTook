import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_nl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('nl'),
  ];

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow the device'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageDutch.
  ///
  /// In en, this message translates to:
  /// **'Nederlands'**
  String get languageDutch;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @player.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get player;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @waitingForHost.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the host'**
  String get waitingForHost;

  /// No description provided for @nextRoundInMoment.
  ///
  /// In en, this message translates to:
  /// **'Next round in a moment.'**
  String get nextRoundInMoment;

  /// No description provided for @hostAGame.
  ///
  /// In en, this message translates to:
  /// **'Host a game'**
  String get hostAGame;

  /// No description provided for @hostAGameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick the mode, rounds and pace'**
  String get hostAGameSubtitle;

  /// No description provided for @joinAGame.
  ///
  /// In en, this message translates to:
  /// **'Join a game'**
  String get joinAGame;

  /// No description provided for @joinAGameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the host\'s QR code'**
  String get joinAGameSubtitle;

  /// No description provided for @homeFooter.
  ///
  /// In en, this message translates to:
  /// **'Same room, same Wi-Fi. Photos stay between players.'**
  String get homeFooter;

  /// No description provided for @lastRoom.
  ///
  /// In en, this message translates to:
  /// **'Last room'**
  String get lastRoom;

  /// No description provided for @roomLabel.
  ///
  /// In en, this message translates to:
  /// **'Room {roomId}'**
  String roomLabel(String roomId);

  /// No description provided for @forgetRoom.
  ///
  /// In en, this message translates to:
  /// **'Forget this room'**
  String get forgetRoom;

  /// No description provided for @howItPlays.
  ///
  /// In en, this message translates to:
  /// **'How it plays'**
  String get howItPlays;

  /// No description provided for @guideSetTable.
  ///
  /// In en, this message translates to:
  /// **'Pick the game'**
  String get guideSetTable;

  /// No description provided for @guideSetTableBody.
  ///
  /// In en, this message translates to:
  /// **'Mode, rounds and pace.'**
  String get guideSetTableBody;

  /// No description provided for @guideScanIn.
  ///
  /// In en, this message translates to:
  /// **'Friends scan in'**
  String get guideScanIn;

  /// No description provided for @guideScanInBody.
  ///
  /// In en, this message translates to:
  /// **'Friends join from the QR.'**
  String get guideScanInBody;

  /// No description provided for @guidePlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get guidePlay;

  /// No description provided for @guidePlayBody.
  ///
  /// In en, this message translates to:
  /// **'Guess a photo, build a meme or travel through time.'**
  String get guidePlayBody;

  /// No description provided for @heroFact.
  ///
  /// In en, this message translates to:
  /// **'2–12 players · Same Wi-Fi or online'**
  String get heroFact;

  /// No description provided for @heroTitle.
  ///
  /// In en, this message translates to:
  /// **'Whose camera\nroll is this?'**
  String get heroTitle;

  /// No description provided for @heroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One photo at a time. Everyone guesses whose it is.'**
  String get heroSubtitle;

  /// No description provided for @onlineRelayUsed.
  ///
  /// In en, this message translates to:
  /// **'Online relay is used up today. Use the same Wi-Fi to keep playing.'**
  String get onlineRelayUsed;

  /// No description provided for @guessWhosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Guess whose photo it is'**
  String get guessWhosePhoto;

  /// No description provided for @onboardingTagline.
  ///
  /// In en, this message translates to:
  /// **'One photo. One guess. Tap who you think took it.'**
  String get onboardingTagline;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @acceptTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of use and Community rules.'**
  String get acceptTerms;

  /// No description provided for @termsLink.
  ///
  /// In en, this message translates to:
  /// **'Terms and community rules'**
  String get termsLink;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @onboardingPhotoNote.
  ///
  /// In en, this message translates to:
  /// **'Photos are only read when a match starts. You can keep private albums out of every game in Settings.'**
  String get onboardingPhotoNote;

  /// No description provided for @pickNameError.
  ///
  /// In en, this message translates to:
  /// **'Pick a name your friends will recognise.'**
  String get pickNameError;

  /// No description provided for @acceptTermsError.
  ///
  /// In en, this message translates to:
  /// **'Agree to the terms before you continue.'**
  String get acceptTermsError;

  /// No description provided for @joinAMatch.
  ///
  /// In en, this message translates to:
  /// **'Join a match'**
  String get joinAMatch;

  /// No description provided for @connectingToHost.
  ///
  /// In en, this message translates to:
  /// **'Connecting to the host'**
  String get connectingToHost;

  /// No description provided for @pasteInvite.
  ///
  /// In en, this message translates to:
  /// **'Or paste an invite link'**
  String get pasteInvite;

  /// No description provided for @useThisLink.
  ///
  /// In en, this message translates to:
  /// **'Use this link'**
  String get useThisLink;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable. Allow access or paste a link below.'**
  String get cameraUnavailable;

  /// No description provided for @joiningAs.
  ///
  /// In en, this message translates to:
  /// **'Joining as'**
  String get joiningAs;

  /// No description provided for @nameShownAtTable.
  ///
  /// In en, this message translates to:
  /// **'Shown to everyone at the table'**
  String get nameShownAtTable;

  /// No description provided for @joinTheRoom.
  ///
  /// In en, this message translates to:
  /// **'Join the room'**
  String get joinTheRoom;

  /// No description provided for @joining.
  ///
  /// In en, this message translates to:
  /// **'Joining'**
  String get joining;

  /// No description provided for @joinRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Join {roomId}'**
  String joinRoomTitle(String roomId);

  /// No description provided for @invalidInvite.
  ///
  /// In en, this message translates to:
  /// **'That invite is not valid. Scan the QR code again.'**
  String get invalidInvite;

  /// No description provided for @chooseGame.
  ///
  /// In en, this message translates to:
  /// **'Choose the game'**
  String get chooseGame;

  /// No description provided for @chooseGameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Classic, Make It Meme, Time Traveler or a bit of everything.'**
  String get chooseGameSubtitle;

  /// No description provided for @nextRounds.
  ///
  /// In en, this message translates to:
  /// **'Next: rounds'**
  String get nextRounds;

  /// No description provided for @howManyRounds.
  ///
  /// In en, this message translates to:
  /// **'How many rounds?'**
  String get howManyRounds;

  /// No description provided for @roundsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Short and sharp. You can always add five more at the podium.'**
  String get roundsSubtitle;

  /// No description provided for @nextPace.
  ///
  /// In en, this message translates to:
  /// **'Next: pick the pace'**
  String get nextPace;

  /// No description provided for @quickGame.
  ///
  /// In en, this message translates to:
  /// **'Quick game'**
  String get quickGame;

  /// No description provided for @partySize.
  ///
  /// In en, this message translates to:
  /// **'Party size'**
  String get partySize;

  /// No description provided for @longTable.
  ///
  /// In en, this message translates to:
  /// **'Long table'**
  String get longTable;

  /// No description provided for @allNighter.
  ///
  /// In en, this message translates to:
  /// **'All nighter'**
  String get allNighter;

  /// No description provided for @pickPace.
  ///
  /// In en, this message translates to:
  /// **'Pick the pace'**
  String get pickPace;

  /// No description provided for @openRoom.
  ///
  /// In en, this message translates to:
  /// **'Open the room'**
  String get openRoom;

  /// No description provided for @couldNotOpenRoom.
  ///
  /// In en, this message translates to:
  /// **'Could not open the room.'**
  String get couldNotOpenRoom;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of 3'**
  String stepOf(int step);

  /// No description provided for @hostAGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Host a game'**
  String get hostAGameTitle;

  /// No description provided for @roundsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 round} other{{count} rounds}}'**
  String roundsCount(int count);

  /// No description provided for @paceClassicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How long does everyone get to guess each photo?'**
  String get paceClassicSubtitle;

  /// No description provided for @paceCaptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How long does everyone get to write a caption?'**
  String get paceCaptionSubtitle;

  /// No description provided for @paceTimelineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How long does everyone get to choose a date?'**
  String get paceTimelineSubtitle;

  /// No description provided for @paceMixedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Each of the three modes keeps its own clock.'**
  String get paceMixedSubtitle;

  /// No description provided for @paceFastClassic.
  ///
  /// In en, this message translates to:
  /// **'Snap decisions.'**
  String get paceFastClassic;

  /// No description provided for @paceNormalClassic.
  ///
  /// In en, this message translates to:
  /// **'The party standard.'**
  String get paceNormalClassic;

  /// No description provided for @paceSlowClassic.
  ///
  /// In en, this message translates to:
  /// **'For the big table.'**
  String get paceSlowClassic;

  /// No description provided for @paceFastCaption.
  ///
  /// In en, this message translates to:
  /// **'A quick caption.'**
  String get paceFastCaption;

  /// No description provided for @paceNormalCaption.
  ///
  /// In en, this message translates to:
  /// **'Time to be funny.'**
  String get paceNormalCaption;

  /// No description provided for @paceSlowCaption.
  ///
  /// In en, this message translates to:
  /// **'No rush, make it good.'**
  String get paceSlowCaption;

  /// No description provided for @paceFastTimeline.
  ///
  /// In en, this message translates to:
  /// **'A quick date.'**
  String get paceFastTimeline;

  /// No description provided for @paceNormalTimeline.
  ///
  /// In en, this message translates to:
  /// **'Think it through.'**
  String get paceNormalTimeline;

  /// No description provided for @paceSlowTimeline.
  ///
  /// In en, this message translates to:
  /// **'For the history buffs.'**
  String get paceSlowTimeline;

  /// No description provided for @paceFastMixed.
  ///
  /// In en, this message translates to:
  /// **'Every mode at its fast clock.'**
  String get paceFastMixed;

  /// No description provided for @paceNormalMixed.
  ///
  /// In en, this message translates to:
  /// **'Every mode at its normal clock.'**
  String get paceNormalMixed;

  /// No description provided for @paceSlowMixed.
  ///
  /// In en, this message translates to:
  /// **'Every mode at its slow clock.'**
  String get paceSlowMixed;

  /// No description provided for @mixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get mixed;

  /// No description provided for @secondsShort.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String secondsShort(int seconds);

  /// No description provided for @paceSemantic.
  ///
  /// In en, this message translates to:
  /// **'{pace}, {detail}. {blurb}'**
  String paceSemantic(String pace, String detail, String blurb);

  /// No description provided for @paceFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get paceFast;

  /// No description provided for @paceNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get paceNormal;

  /// No description provided for @paceSlow.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get paceSlow;

  /// No description provided for @rejoin.
  ///
  /// In en, this message translates to:
  /// **'Rejoin'**
  String get rejoin;

  /// No description provided for @yourRoom.
  ///
  /// In en, this message translates to:
  /// **'Your room'**
  String get yourRoom;

  /// No description provided for @lobby.
  ///
  /// In en, this message translates to:
  /// **'Lobby'**
  String get lobby;

  /// No description provided for @leaveMatch.
  ///
  /// In en, this message translates to:
  /// **'Leave match'**
  String get leaveMatch;

  /// No description provided for @scanToJoin.
  ///
  /// In en, this message translates to:
  /// **'Scan to join'**
  String get scanToJoin;

  /// No description provided for @scanToJoinBody.
  ///
  /// In en, this message translates to:
  /// **'Point any camera at the code. No app download needed to join.'**
  String get scanToJoinBody;

  /// No description provided for @roomCode.
  ///
  /// In en, this message translates to:
  /// **'ROOM {roomId}'**
  String roomCode(String roomId);

  /// No description provided for @sameWifi.
  ///
  /// In en, this message translates to:
  /// **'Same Wi-Fi'**
  String get sameWifi;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @onlineWifiHint.
  ///
  /// In en, this message translates to:
  /// **'If everyone joins the same Wi-Fi, it is faster and your photos stay on your network.'**
  String get onlineWifiHint;

  /// No description provided for @shareInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Share invite link'**
  String get shareInviteLink;

  /// No description provided for @hostStartsPhotoCheck.
  ///
  /// In en, this message translates to:
  /// **'The host starts the photo check when everyone is here.'**
  String get hostStartsPhotoCheck;

  /// No description provided for @waitingForHostToStart.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the host to start'**
  String get waitingForHostToStart;

  /// No description provided for @playersJoined.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 player joined} other{{count} players joined}}'**
  String playersJoined(int count);

  /// No description provided for @waitingFirstFriend.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the first friend'**
  String get waitingFirstFriend;

  /// No description provided for @waitingFirstFriendBody.
  ///
  /// In en, this message translates to:
  /// **'The QR code above is the only thing they need.'**
  String get waitingFirstFriendBody;

  /// No description provided for @editAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editAction;

  /// No description provided for @editGameBody.
  ///
  /// In en, this message translates to:
  /// **'Changes reach everyone in the room. You can edit again until the photo check starts.'**
  String get editGameBody;

  /// No description provided for @tonightsGame.
  ///
  /// In en, this message translates to:
  /// **'Tonight\'s game'**
  String get tonightsGame;

  /// No description provided for @modeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get modeLabel;

  /// No description provided for @roundsLabel.
  ///
  /// In en, this message translates to:
  /// **'Rounds'**
  String get roundsLabel;

  /// No description provided for @paceLabel.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get paceLabel;

  /// No description provided for @removePlayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removePlayerTitle(String name);

  /// No description provided for @removePlayerLobbyBody.
  ///
  /// In en, this message translates to:
  /// **'They leave this room. They can join again with the QR code.'**
  String get removePlayerLobbyBody;

  /// No description provided for @inviteLink.
  ///
  /// In en, this message translates to:
  /// **'Invite link'**
  String get inviteLink;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @playerOptions.
  ///
  /// In en, this message translates to:
  /// **'Player options'**
  String get playerOptions;

  /// No description provided for @removeFromRoom.
  ///
  /// In en, this message translates to:
  /// **'Remove from room'**
  String get removeFromRoom;

  /// No description provided for @startPhotoCheck.
  ///
  /// In en, this message translates to:
  /// **'Start photo check'**
  String get startPhotoCheck;

  /// No description provided for @hostLabel.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get hostLabel;

  /// No description provided for @choosing.
  ///
  /// In en, this message translates to:
  /// **'Choosing'**
  String get choosing;

  /// No description provided for @modeClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get modeClassic;

  /// No description provided for @modeCaptionThis.
  ///
  /// In en, this message translates to:
  /// **'Caption This'**
  String get modeCaptionThis;

  /// No description provided for @modeTimeTraveler.
  ///
  /// In en, this message translates to:
  /// **'Time Traveler'**
  String get modeTimeTraveler;

  /// No description provided for @modeMixedParty.
  ///
  /// In en, this message translates to:
  /// **'Mixed Party'**
  String get modeMixedParty;

  /// No description provided for @rerollAll.
  ///
  /// In en, this message translates to:
  /// **'Reroll all'**
  String get rerollAll;

  /// No description provided for @waitingForPlayersButton.
  ///
  /// In en, this message translates to:
  /// **'Waiting for players'**
  String get waitingForPlayersButton;

  /// No description provided for @checkYourPhotos.
  ///
  /// In en, this message translates to:
  /// **'Check your photos'**
  String get checkYourPhotos;

  /// No description provided for @photosAllHere.
  ///
  /// In en, this message translates to:
  /// **'All {count} photos for this match are here. Reroll all for a different set.'**
  String photosAllHere(int count);

  /// No description provided for @photosPartial.
  ///
  /// In en, this message translates to:
  /// **'You have {count} of {needed}. Reroll all to fill the set.'**
  String photosPartial(int count, int needed);

  /// No description provided for @photosReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the photos for this match.'**
  String get photosReading;

  /// No description provided for @photosTooFew.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Only 1 usable photo found. Add photos or allow more albums in Settings, then reroll. You can still continue with this set.} other{Only {count} usable photos found. Add photos or allow more albums in Settings, then reroll. You can still continue with this set.}}'**
  String photosTooFew(int count);

  /// No description provided for @noUsablePhotos.
  ///
  /// In en, this message translates to:
  /// **'No usable photos found'**
  String get noUsablePhotos;

  /// No description provided for @noUsablePhotosBody.
  ///
  /// In en, this message translates to:
  /// **'Allow photo access, or add a few photos to your gallery. Photos are only read from albums you allow.'**
  String get noUsablePhotosBody;

  /// No description provided for @photoSettings.
  ///
  /// In en, this message translates to:
  /// **'Photo settings'**
  String get photoSettings;

  /// No description provided for @secretPhotoPlanted.
  ///
  /// In en, this message translates to:
  /// **'Secret photo planted'**
  String get secretPhotoPlanted;

  /// No description provided for @plantSecretPhoto.
  ///
  /// In en, this message translates to:
  /// **'Plant one secret photo'**
  String get plantSecretPhoto;

  /// No description provided for @plantSecretPhotoBody.
  ///
  /// In en, this message translates to:
  /// **'One per match. It quietly replaces one of your approved photos.'**
  String get plantSecretPhotoBody;

  /// No description provided for @couldNotReadAlbums.
  ///
  /// In en, this message translates to:
  /// **'Could not read your albums.'**
  String get couldNotReadAlbums;

  /// No description provided for @couldNotReadAlbum.
  ///
  /// In en, this message translates to:
  /// **'Could not read this album.'**
  String get couldNotReadAlbum;

  /// No description provided for @couldNotReadPhoto.
  ///
  /// In en, this message translates to:
  /// **'That photo could not be read. Try another.'**
  String get couldNotReadPhoto;

  /// No description provided for @couldNotSharePhoto.
  ///
  /// In en, this message translates to:
  /// **'That photo could not be shared. Try another.'**
  String get couldNotSharePhoto;

  /// No description provided for @pickPhotoToPlant.
  ///
  /// In en, this message translates to:
  /// **'Pick the photo to plant'**
  String get pickPhotoToPlant;

  /// No description provided for @pickPhotoToPlantBody.
  ///
  /// In en, this message translates to:
  /// **'Any photo from your albums. One per match, and nobody learns which one it was until the podium.'**
  String get pickPhotoToPlantBody;

  /// No description provided for @readingAlbums.
  ///
  /// In en, this message translates to:
  /// **'Reading your albums'**
  String get readingAlbums;

  /// No description provided for @albumsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Albums are not available'**
  String get albumsUnavailable;

  /// No description provided for @albumsUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Photo access may be off. Allow it and try again.'**
  String get albumsUnavailableBody;

  /// No description provided for @noPhotosToPlant.
  ///
  /// In en, this message translates to:
  /// **'No photos to plant'**
  String get noPhotosToPlant;

  /// No description provided for @noPhotosToPlantBody.
  ///
  /// In en, this message translates to:
  /// **'No approved photos are available on this device yet.'**
  String get noPhotosToPlantBody;

  /// No description provided for @fromApprovedPhotos.
  ///
  /// In en, this message translates to:
  /// **'From your approved photos'**
  String get fromApprovedPhotos;

  /// No description provided for @roundOf.
  ///
  /// In en, this message translates to:
  /// **'Round {round} of {total}'**
  String roundOf(int round, int total);

  /// No description provided for @whoTookThis.
  ///
  /// In en, this message translates to:
  /// **'Who took this'**
  String get whoTookThis;

  /// No description provided for @screenshotBy.
  ///
  /// In en, this message translates to:
  /// **'{name} took a screenshot'**
  String screenshotBy(String name);

  /// No description provided for @lockedInWaiting.
  ///
  /// In en, this message translates to:
  /// **'Locked in, waiting for the others.'**
  String get lockedInWaiting;

  /// No description provided for @getReady.
  ///
  /// In en, this message translates to:
  /// **'Get ready'**
  String get getReady;

  /// No description provided for @tapWhoTook.
  ///
  /// In en, this message translates to:
  /// **'Tap who took the photo as soon as it appears'**
  String get tapWhoTook;

  /// No description provided for @tapNameToLock.
  ///
  /// In en, this message translates to:
  /// **'Tap a name to lock in'**
  String get tapNameToLock;

  /// No description provided for @noAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer.'**
  String get noAnswer;

  /// No description provided for @yourPhotoYouGotIt.
  ///
  /// In en, this message translates to:
  /// **'Your photo. You got it. +{points}'**
  String yourPhotoYouGotIt(int points);

  /// No description provided for @youGotIt.
  ///
  /// In en, this message translates to:
  /// **'You got it. +{points}'**
  String youGotIt(int points);

  /// No description provided for @yourPhotoWrongGuess.
  ///
  /// In en, this message translates to:
  /// **'Your photo. Wrong guess.'**
  String get yourPhotoWrongGuess;

  /// No description provided for @wrongGuess.
  ///
  /// In en, this message translates to:
  /// **'Wrong guess.'**
  String get wrongGuess;

  /// No description provided for @playersFooled.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 player fooled} other{{count} players fooled}}'**
  String playersFooled(int count);

  /// No description provided for @playersDidNotAnswer.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 did not answer} other{{count} did not answer}}'**
  String playersDidNotAnswer(int count);

  /// No description provided for @everyoneGotItRight.
  ///
  /// In en, this message translates to:
  /// **'Everyone got it right'**
  String get everyoneGotItRight;

  /// No description provided for @shotBy.
  ///
  /// In en, this message translates to:
  /// **'Shot by {name}'**
  String shotBy(String name);

  /// No description provided for @whoTookIt.
  ///
  /// In en, this message translates to:
  /// **'Who took it?'**
  String get whoTookIt;

  /// No description provided for @fastestAward.
  ///
  /// In en, this message translates to:
  /// **'Fastest: {name} {seconds}s'**
  String fastestAward(String name, String seconds);

  /// No description provided for @nobodyGuessed.
  ///
  /// In en, this message translates to:
  /// **'Nobody guessed it'**
  String get nobodyGuessed;

  /// No description provided for @everyoneNailedIt.
  ///
  /// In en, this message translates to:
  /// **'Everyone nailed it'**
  String get everyoneNailedIt;

  /// No description provided for @writeFunniestCaption.
  ///
  /// In en, this message translates to:
  /// **'Write the funniest caption'**
  String get writeFunniestCaption;

  /// No description provided for @captionSentWaiting.
  ///
  /// In en, this message translates to:
  /// **'Caption sent. Waiting for the others.'**
  String get captionSentWaiting;

  /// No description provided for @yourCaption.
  ///
  /// In en, this message translates to:
  /// **'Your caption'**
  String get yourCaption;

  /// No description provided for @makeItWeird.
  ///
  /// In en, this message translates to:
  /// **'Make it weird.'**
  String get makeItWeird;

  /// No description provided for @waitingForOthers.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the others'**
  String get waitingForOthers;

  /// No description provided for @sendCaption.
  ///
  /// In en, this message translates to:
  /// **'Send caption'**
  String get sendCaption;

  /// No description provided for @votesIn.
  ///
  /// In en, this message translates to:
  /// **'{votes} of {total} votes in. The reveal starts when everyone has voted.'**
  String votesIn(int votes, int total);

  /// No description provided for @tapOneCaption.
  ///
  /// In en, this message translates to:
  /// **'Tap one caption. You cannot pick your own.'**
  String get tapOneCaption;

  /// No description provided for @voteLockedWaiting.
  ///
  /// In en, this message translates to:
  /// **'Vote locked. Waiting for the table.'**
  String get voteLockedWaiting;

  /// No description provided for @revealNow.
  ///
  /// In en, this message translates to:
  /// **'Reveal now'**
  String get revealNow;

  /// No description provided for @noCaptions.
  ///
  /// In en, this message translates to:
  /// **'No captions'**
  String get noCaptions;

  /// No description provided for @thisRoundMovesOn.
  ///
  /// In en, this message translates to:
  /// **'This round will move on.'**
  String get thisRoundMovesOn;

  /// No description provided for @tableHasSpoken.
  ///
  /// In en, this message translates to:
  /// **'The table has spoken'**
  String get tableHasSpoken;

  /// No description provided for @photoBy.
  ///
  /// In en, this message translates to:
  /// **'Photo by {name}'**
  String photoBy(String name);

  /// No description provided for @yourCaptionZero.
  ///
  /// In en, this message translates to:
  /// **'Your caption got zero votes. Brutal.'**
  String get yourCaptionZero;

  /// No description provided for @yourCaptionVotes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Your caption got 1 vote.} other{Your caption got {count} votes.}}'**
  String yourCaptionVotes(int count);

  /// No description provided for @zeroVotes.
  ///
  /// In en, this message translates to:
  /// **'Zero votes'**
  String get zeroVotes;

  /// No description provided for @groupMenace.
  ///
  /// In en, this message translates to:
  /// **'Group menace'**
  String get groupMenace;

  /// No description provided for @topCaption.
  ///
  /// In en, this message translates to:
  /// **'Top caption'**
  String get topCaption;

  /// No description provided for @voteCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 vote} other{{count} votes}}'**
  String voteCount(int count);

  /// No description provided for @captionAuthorBadge.
  ///
  /// In en, this message translates to:
  /// **'{author} · {badge}'**
  String captionAuthorBadge(String author, String badge);

  /// No description provided for @whenWasThisTaken.
  ///
  /// In en, this message translates to:
  /// **'When was this taken?'**
  String get whenWasThisTaken;

  /// No description provided for @guessYearMonth.
  ///
  /// In en, this message translates to:
  /// **'Guess the year and month'**
  String get guessYearMonth;

  /// No description provided for @lockedDate.
  ///
  /// In en, this message translates to:
  /// **'Locked: {date}'**
  String lockedDate(String date);

  /// No description provided for @lockInDate.
  ///
  /// In en, this message translates to:
  /// **'Lock in {date}'**
  String lockInDate(String date);

  /// No description provided for @timeLord.
  ///
  /// In en, this message translates to:
  /// **'Time Lord'**
  String get timeLord;

  /// No description provided for @mostDelusional.
  ///
  /// In en, this message translates to:
  /// **'Most delusional'**
  String get mostDelusional;

  /// No description provided for @noGuess.
  ///
  /// In en, this message translates to:
  /// **'No guess'**
  String get noGuess;

  /// No description provided for @exact.
  ///
  /// In en, this message translates to:
  /// **'exact'**
  String get exact;

  /// No description provided for @offBy.
  ///
  /// In en, this message translates to:
  /// **'off by {distance}'**
  String offBy(String distance);

  /// No description provided for @monthCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String monthCount(int count);

  /// No description provided for @yearCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year} other{{count} years}}'**
  String yearCount(int count);

  /// No description provided for @matchAwards.
  ///
  /// In en, this message translates to:
  /// **'Match awards'**
  String get matchAwards;

  /// No description provided for @oneMoreRound.
  ///
  /// In en, this message translates to:
  /// **'One more round (5)'**
  String get oneMoreRound;

  /// No description provided for @backToLobby.
  ///
  /// In en, this message translates to:
  /// **'Back to lobby'**
  String get backToLobby;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'{score} pts'**
  String points(int score);

  /// No description provided for @quickestDraw.
  ///
  /// In en, this message translates to:
  /// **'Quickest draw'**
  String get quickestDraw;

  /// No description provided for @longestStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest streak'**
  String get longestStreak;

  /// No description provided for @masterOfMystery.
  ///
  /// In en, this message translates to:
  /// **'Master of mystery'**
  String get masterOfMystery;

  /// No description provided for @paparazzi.
  ///
  /// In en, this message translates to:
  /// **'Paparazzi'**
  String get paparazzi;

  /// No description provided for @smoothPlanter.
  ///
  /// In en, this message translates to:
  /// **'Smooth planter'**
  String get smoothPlanter;

  /// No description provided for @awardSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String awardSeconds(String seconds);

  /// No description provided for @awardStreak.
  ///
  /// In en, this message translates to:
  /// **'{count}x'**
  String awardStreak(int count);

  /// No description provided for @awardPoints.
  ///
  /// In en, this message translates to:
  /// **'{count} pts'**
  String awardPoints(int count);

  /// No description provided for @awardFrames.
  ///
  /// In en, this message translates to:
  /// **'{count} screenshots'**
  String awardFrames(int count);

  /// No description provided for @awardFooled.
  ///
  /// In en, this message translates to:
  /// **'fooled {count}'**
  String awardFooled(int count);

  /// No description provided for @moreRounds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more round} other{{count} more rounds}}'**
  String moreRounds(int count);

  /// No description provided for @swapBeforeTimer.
  ///
  /// In en, this message translates to:
  /// **'Swap anything you like before the timer ends.'**
  String get swapBeforeTimer;

  /// No description provided for @pickingExtraPhotos.
  ///
  /// In en, this message translates to:
  /// **'Picking extra photos'**
  String get pickingExtraPhotos;

  /// No description provided for @freshFrames.
  ///
  /// In en, this message translates to:
  /// **'Fresh frames are coming from your albums. This stays on your device.'**
  String get freshFrames;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reviewDemo.
  ///
  /// In en, this message translates to:
  /// **'Review demo'**
  String get reviewDemo;

  /// No description provided for @closeDemo.
  ///
  /// In en, this message translates to:
  /// **'Close demo'**
  String get closeDemo;

  /// No description provided for @demoFake.
  ///
  /// In en, this message translates to:
  /// **'Demo with fake players. No network and no real photos.'**
  String get demoFake;

  /// No description provided for @allDemoPhotos.
  ///
  /// In en, this message translates to:
  /// **'All 4 demo photos are here. Reroll all for a different set.'**
  String get allDemoPhotos;

  /// No description provided for @startDemoRound.
  ///
  /// In en, this message translates to:
  /// **'Start demo round'**
  String get startDemoRound;

  /// No description provided for @timerRanOut.
  ///
  /// In en, this message translates to:
  /// **'The timer ran out.'**
  String get timerRanOut;

  /// No description provided for @youGuessed.
  ///
  /// In en, this message translates to:
  /// **'You guessed {name}. Next time.'**
  String youGuessed(String name);

  /// No description provided for @seePodium.
  ///
  /// In en, this message translates to:
  /// **'See the podium'**
  String get seePodium;

  /// No description provided for @restartDemo.
  ///
  /// In en, this message translates to:
  /// **'Restart demo'**
  String get restartDemo;

  /// No description provided for @placeFirst.
  ///
  /// In en, this message translates to:
  /// **'1st'**
  String get placeFirst;

  /// No description provided for @placeSecond.
  ///
  /// In en, this message translates to:
  /// **'2nd'**
  String get placeSecond;

  /// No description provided for @placeThird.
  ///
  /// In en, this message translates to:
  /// **'3rd'**
  String get placeThird;

  /// No description provided for @placeNth.
  ///
  /// In en, this message translates to:
  /// **'{place}th'**
  String placeNth(int place);

  /// No description provided for @lockedIn.
  ///
  /// In en, this message translates to:
  /// **'Locked in'**
  String get lockedIn;

  /// No description provided for @podium.
  ///
  /// In en, this message translates to:
  /// **'Podium'**
  String get podium;

  /// No description provided for @champion.
  ///
  /// In en, this message translates to:
  /// **'Champion'**
  String get champion;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @nameHelper.
  ///
  /// In en, this message translates to:
  /// **'Shown to other players'**
  String get nameHelper;

  /// No description provided for @avatar.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get avatar;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow the device'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @privateAlbums.
  ///
  /// In en, this message translates to:
  /// **'Private albums'**
  String get privateAlbums;

  /// No description provided for @excludedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} excluded'**
  String excludedCount(int count);

  /// No description provided for @privateAlbumsBody.
  ///
  /// In en, this message translates to:
  /// **'Optional. Excluded albums are never drawn from in any match.'**
  String get privateAlbumsBody;

  /// No description provided for @albumListUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Album list unavailable'**
  String get albumListUnavailable;

  /// No description provided for @albumListUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Photo access was not granted. Allow it and try again.'**
  String get albumListUnavailableBody;

  /// No description provided for @noAlbums.
  ///
  /// In en, this message translates to:
  /// **'No albums found'**
  String get noAlbums;

  /// No description provided for @noAlbumsBody.
  ///
  /// In en, this message translates to:
  /// **'Allow photo access to choose private albums. Photos are only read when a match starts.'**
  String get noAlbumsBody;

  /// No description provided for @allowPhotoAccess.
  ///
  /// In en, this message translates to:
  /// **'Allow photo access'**
  String get allowPhotoAccess;

  /// No description provided for @photosCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String photosCount(int count);

  /// No description provided for @onlineRelay.
  ///
  /// In en, this message translates to:
  /// **'Online relay'**
  String get onlineRelay;

  /// No description provided for @onlineRelayBody.
  ///
  /// In en, this message translates to:
  /// **'Local play never uses a server. Online play uses a small relay for friends elsewhere.'**
  String get onlineRelayBody;

  /// No description provided for @selfHostedRelay.
  ///
  /// In en, this message translates to:
  /// **'Self-hosted relay'**
  String get selfHostedRelay;

  /// No description provided for @selfHostedRelayBody.
  ///
  /// In en, this message translates to:
  /// **'Point the app at your own signaling and TURN server'**
  String get selfHostedRelayBody;

  /// No description provided for @signalingUrl.
  ///
  /// In en, this message translates to:
  /// **'Signaling URL'**
  String get signalingUrl;

  /// No description provided for @signalingUrlHelper.
  ///
  /// In en, this message translates to:
  /// **'Default: {url}'**
  String signalingUrlHelper(String url);

  /// No description provided for @customTurnUrl.
  ///
  /// In en, this message translates to:
  /// **'TURN URI'**
  String get customTurnUrl;

  /// No description provided for @customTurnHelper.
  ///
  /// In en, this message translates to:
  /// **'Optional, e.g. turn:turn.example.org:3478'**
  String get customTurnHelper;

  /// No description provided for @turnUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get turnUsername;

  /// No description provided for @turnCredential.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get turnCredential;

  /// No description provided for @resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get resetToDefault;

  /// No description provided for @saveRelay.
  ///
  /// In en, this message translates to:
  /// **'Save relay'**
  String get saveRelay;

  /// No description provided for @helpAndLegal.
  ///
  /// In en, this message translates to:
  /// **'Help and legal'**
  String get helpAndLegal;

  /// No description provided for @reportContent.
  ///
  /// In en, this message translates to:
  /// **'Report content or a player'**
  String get reportContent;

  /// No description provided for @reportBody.
  ///
  /// In en, this message translates to:
  /// **'Send the room code and what happened to {email}'**
  String reportBody(String email);

  /// No description provided for @termsAndRules.
  ///
  /// In en, this message translates to:
  /// **'Terms and community rules'**
  String get termsAndRules;

  /// No description provided for @openSource.
  ///
  /// In en, this message translates to:
  /// **'Open source under the AGPLv3. Photos stay on your phone.'**
  String get openSource;

  /// No description provided for @trademark.
  ///
  /// In en, this message translates to:
  /// **'WhoTook™ is a trademark of the project owner.'**
  String get trademark;

  /// No description provided for @relaySignalingSchemeError.
  ///
  /// In en, this message translates to:
  /// **'Signaling URL must start with https://, http://, wss:// or ws://'**
  String get relaySignalingSchemeError;

  /// No description provided for @relayTurnSchemeError.
  ///
  /// In en, this message translates to:
  /// **'TURN URL must start with turn: or turns:'**
  String get relayTurnSchemeError;

  /// No description provided for @relaySaved.
  ///
  /// In en, this message translates to:
  /// **'Relay saved'**
  String get relaySaved;

  /// No description provided for @relayDefault.
  ///
  /// In en, this message translates to:
  /// **'Back to the default relay'**
  String get relayDefault;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @avatarOption.
  ///
  /// In en, this message translates to:
  /// **'Avatar {number}'**
  String avatarOption(int number);

  /// No description provided for @yourPhotoAvatar.
  ///
  /// In en, this message translates to:
  /// **'Your photo avatar'**
  String get yourPhotoAvatar;

  /// No description provided for @pickAnAvatar.
  ///
  /// In en, this message translates to:
  /// **'Pick an avatar'**
  String get pickAnAvatar;

  /// No description provided for @photoAvatarStored.
  ///
  /// In en, this message translates to:
  /// **'Stored on this phone and shared only in the room.'**
  String get photoAvatarStored;

  /// No description provided for @avatarChoices.
  ///
  /// In en, this message translates to:
  /// **'A selfie, a photo from your gallery, or an icon.'**
  String get avatarChoices;

  /// No description provided for @takeSelfie.
  ///
  /// In en, this message translates to:
  /// **'Take a selfie'**
  String get takeSelfie;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get choosePhoto;

  /// No description provided for @useIcon.
  ///
  /// In en, this message translates to:
  /// **'Use an icon'**
  String get useIcon;

  /// No description provided for @cropTitle.
  ///
  /// In en, this message translates to:
  /// **'Your photo'**
  String get cropTitle;

  /// No description provided for @cropHint.
  ///
  /// In en, this message translates to:
  /// **'Pinch to zoom and drag to centre your face.'**
  String get cropHint;

  /// No description provided for @savingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Saving photo'**
  String get savingPhoto;

  /// No description provided for @useThisPhoto.
  ///
  /// In en, this message translates to:
  /// **'Use this photo'**
  String get useThisPhoto;

  /// No description provided for @hostControls.
  ///
  /// In en, this message translates to:
  /// **'Host controls'**
  String get hostControls;

  /// No description provided for @skipRound.
  ///
  /// In en, this message translates to:
  /// **'Skip round'**
  String get skipRound;

  /// No description provided for @removePlayer.
  ///
  /// In en, this message translates to:
  /// **'Remove player'**
  String get removePlayer;

  /// No description provided for @skipRoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip this round?'**
  String get skipRoundTitle;

  /// No description provided for @skipRoundBody.
  ///
  /// In en, this message translates to:
  /// **'The current screen ends now and the next round starts.'**
  String get skipRoundBody;

  /// No description provided for @skipButton.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipButton;

  /// No description provided for @removeAPlayer.
  ///
  /// In en, this message translates to:
  /// **'Remove a player'**
  String get removeAPlayer;

  /// No description provided for @removePlayerMatchBody.
  ///
  /// In en, this message translates to:
  /// **'They leave this match. Their photo rounds stay in the game.'**
  String get removePlayerMatchBody;

  /// No description provided for @differentVersions.
  ///
  /// In en, this message translates to:
  /// **'Different app versions'**
  String get differentVersions;

  /// No description provided for @versionWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Someone is on {latestVersion} (build {latestBuild}). You are on {ownVersion} (build {ownBuild}). Update so rounds and photos stay in sync.'**
  String versionWarningBody(
    String latestVersion,
    int latestBuild,
    String ownVersion,
    int ownBuild,
  );

  /// No description provided for @getUpdate.
  ///
  /// In en, this message translates to:
  /// **'Get the update'**
  String get getUpdate;

  /// No description provided for @keepPlaying.
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get keepPlaying;

  /// No description provided for @connectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get connectionLost;

  /// No description provided for @reconnectingIn.
  ///
  /// In en, this message translates to:
  /// **'Trying to reconnect. {seconds, plural, =1{1 second left.} other{{seconds} seconds left.}}'**
  String reconnectingIn(int seconds);

  /// No description provided for @leaveRoom.
  ///
  /// In en, this message translates to:
  /// **'Leave room'**
  String get leaveRoom;

  /// No description provided for @leaveRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this room?'**
  String get leaveRoomTitle;

  /// No description provided for @leaveRoomHostBody.
  ///
  /// In en, this message translates to:
  /// **'The room closes for everyone.'**
  String get leaveRoomHostBody;

  /// No description provided for @leaveRoomGuestBody.
  ///
  /// In en, this message translates to:
  /// **'You leave the room and can rejoin with the QR code.'**
  String get leaveRoomGuestBody;

  /// No description provided for @streakLabel.
  ///
  /// In en, this message translates to:
  /// **'Streak {count}'**
  String streakLabel(int count);

  /// No description provided for @modeClassicBlurb.
  ///
  /// In en, this message translates to:
  /// **'Guess who took it.'**
  String get modeClassicBlurb;

  /// No description provided for @modeCaptionThisBlurb.
  ///
  /// In en, this message translates to:
  /// **'Write the funniest caption.'**
  String get modeCaptionThisBlurb;

  /// No description provided for @modeTimeTravelerBlurb.
  ///
  /// In en, this message translates to:
  /// **'Guess the year and month.'**
  String get modeTimeTravelerBlurb;

  /// No description provided for @modeMixedPartyBlurb.
  ///
  /// In en, this message translates to:
  /// **'All three, shuffled.'**
  String get modeMixedPartyBlurb;

  /// No description provided for @modeSemantic.
  ///
  /// In en, this message translates to:
  /// **'{label}. {blurb}'**
  String modeSemantic(String label, String blurb);

  /// No description provided for @errorNoDatedPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos with a date found. Allow another album or pick a different mode.'**
  String get errorNoDatedPhotos;

  /// No description provided for @errorNeedAnotherPlayer.
  ///
  /// In en, this message translates to:
  /// **'One more player has to scan the QR code before the match starts'**
  String get errorNeedAnotherPlayer;

  /// No description provided for @errorPlayersNotReady.
  ///
  /// In en, this message translates to:
  /// **'Everyone has to tap Ready first'**
  String get errorPlayersNotReady;

  /// No description provided for @errorPhotoAccessHost.
  ///
  /// In en, this message translates to:
  /// **'Photo access is off. Allow photos in Settings, then start the photo check.'**
  String get errorPhotoAccessHost;

  /// No description provided for @errorPhotoAccessClient.
  ///
  /// In en, this message translates to:
  /// **'Photo access is off. Allow photos in Settings, then tap Reroll all.'**
  String get errorPhotoAccessClient;

  /// No description provided for @errorOpenRoom.
  ///
  /// In en, this message translates to:
  /// **'Could not open the room. Try again.'**
  String get errorOpenRoom;

  /// No description provided for @errorInvalidInvite.
  ///
  /// In en, this message translates to:
  /// **'That invite is not valid. Scan the QR code again.'**
  String get errorInvalidInvite;

  /// No description provided for @errorRelayLimit.
  ///
  /// In en, this message translates to:
  /// **'Online relay is used up for today. Join the same Wi-Fi or a hotspot to keep playing.'**
  String get errorRelayLimit;

  /// No description provided for @errorReachHost.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the host. Check that you are on the same Wi-Fi or hotspot.'**
  String get errorReachHost;

  /// No description provided for @errorHostEnded.
  ///
  /// In en, this message translates to:
  /// **'The host ended the room. Scan a new QR or host your own game.'**
  String get errorHostEnded;

  /// No description provided for @errorRoomStarted.
  ///
  /// In en, this message translates to:
  /// **'That room already started. Ask the host to open the lobby again.'**
  String get errorRoomStarted;

  /// No description provided for @errorRemovedByHost.
  ///
  /// In en, this message translates to:
  /// **'The host removed you from the room.'**
  String get errorRemovedByHost;

  /// No description provided for @errorSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errorSomethingWentWrong;

  /// No description provided for @errorNoPhotos.
  ///
  /// In en, this message translates to:
  /// **'The host did not receive your photos'**
  String get errorNoPhotos;

  /// No description provided for @countdown.
  ///
  /// In en, this message translates to:
  /// **'Countdown'**
  String get countdown;

  /// No description provided for @countdownSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 second} other{{count} seconds}}'**
  String countdownSeconds(int count);

  /// No description provided for @loadingStartingMatch.
  ///
  /// In en, this message translates to:
  /// **'Starting match'**
  String get loadingStartingMatch;

  /// No description provided for @loadingReadingPhotos.
  ///
  /// In en, this message translates to:
  /// **'Reading your photos'**
  String get loadingReadingPhotos;

  /// No description provided for @loadingJoining.
  ///
  /// In en, this message translates to:
  /// **'Joining match'**
  String get loadingJoining;

  /// No description provided for @errorPlantUsed.
  ///
  /// In en, this message translates to:
  /// **'This photo plant is once per game.'**
  String get errorPlantUsed;

  /// No description provided for @errorNotReady.
  ///
  /// In en, this message translates to:
  /// **'Tap Ready before planting a photo.'**
  String get errorNotReady;

  /// No description provided for @errorNotPlanter.
  ///
  /// In en, this message translates to:
  /// **'Only the chosen player can plant a photo this game.'**
  String get errorNotPlanter;

  /// No description provided for @errorWrongOwner.
  ///
  /// In en, this message translates to:
  /// **'That photo is not yours.'**
  String get errorWrongOwner;

  /// No description provided for @errorNoUnplayedPhoto.
  ///
  /// In en, this message translates to:
  /// **'Every approved photo has already been shown.'**
  String get errorNoUnplayedPhoto;

  /// No description provided for @errorEmptyCaption.
  ///
  /// In en, this message translates to:
  /// **'Write something first.'**
  String get errorEmptyCaption;

  /// No description provided for @errorCaptionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the caption under 80 characters.'**
  String get errorCaptionTooLong;

  /// No description provided for @errorAlreadyGuessed.
  ///
  /// In en, this message translates to:
  /// **'Your guess is already locked.'**
  String get errorAlreadyGuessed;

  /// No description provided for @errorAlreadyVoted.
  ///
  /// In en, this message translates to:
  /// **'Your vote is already locked.'**
  String get errorAlreadyVoted;

  /// No description provided for @errorAlreadyCaptioned.
  ///
  /// In en, this message translates to:
  /// **'Your caption is already locked.'**
  String get errorAlreadyCaptioned;

  /// No description provided for @secondsLeftShort.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s left'**
  String secondsLeftShort(String seconds);

  /// No description provided for @roundsUnit.
  ///
  /// In en, this message translates to:
  /// **'rounds'**
  String get roundsUnit;

  /// No description provided for @youreIn.
  ///
  /// In en, this message translates to:
  /// **'You\'re in'**
  String get youreIn;

  /// No description provided for @swap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get swap;

  /// No description provided for @revealing.
  ///
  /// In en, this message translates to:
  /// **'Revealing...'**
  String get revealing;

  /// No description provided for @yours.
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get yours;

  /// No description provided for @couldNotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open this link.'**
  String get couldNotOpenLink;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings'**
  String get advancedSettings;

  /// No description provided for @advancedSettingsBody.
  ///
  /// In en, this message translates to:
  /// **'Relay, TURN and self-hosting.'**
  String get advancedSettingsBody;

  /// No description provided for @modeMakeItMeme.
  ///
  /// In en, this message translates to:
  /// **'Make It Meme'**
  String get modeMakeItMeme;

  /// No description provided for @modeMakeItMemeBlurb.
  ///
  /// In en, this message translates to:
  /// **'Make a meme from a friend\'s photo.'**
  String get modeMakeItMemeBlurb;

  /// No description provided for @paceMemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How long does everyone get to build a meme?'**
  String get paceMemeSubtitle;

  /// No description provided for @paceFastMeme.
  ///
  /// In en, this message translates to:
  /// **'A quick meme.'**
  String get paceFastMeme;

  /// No description provided for @paceNormalMeme.
  ///
  /// In en, this message translates to:
  /// **'Time to build the joke.'**
  String get paceNormalMeme;

  /// No description provided for @paceSlowMeme.
  ///
  /// In en, this message translates to:
  /// **'No rush, make it good.'**
  String get paceSlowMeme;

  /// No description provided for @memeVaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Your six photos.'**
  String get memeVaultTitle;

  /// No description provided for @memeVaultBody.
  ///
  /// In en, this message translates to:
  /// **'Reroll the whole set if something should not be in the game.'**
  String get memeVaultBody;

  /// No description provided for @memeVaultOnly.
  ///
  /// In en, this message translates to:
  /// **'Only these six photos enter the game.'**
  String get memeVaultOnly;

  /// No description provided for @memeVaultReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get memeVaultReady;

  /// No description provided for @memeVaultReroll.
  ///
  /// In en, this message translates to:
  /// **'Reroll all'**
  String get memeVaultReroll;

  /// No description provided for @memeWritingLabel.
  ///
  /// In en, this message translates to:
  /// **'Build the meme'**
  String get memeWritingLabel;

  /// No description provided for @memeMatchSwaps.
  ///
  /// In en, this message translates to:
  /// **'Match swaps'**
  String get memeMatchSwaps;

  /// No description provided for @memeTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get memeTemplate;

  /// No description provided for @memeTemplateClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get memeTemplateClassic;

  /// No description provided for @memeTemplatePov.
  ///
  /// In en, this message translates to:
  /// **'POV'**
  String get memeTemplatePov;

  /// No description provided for @memeTemplateBreaking.
  ///
  /// In en, this message translates to:
  /// **'Breaking'**
  String get memeTemplateBreaking;

  /// No description provided for @memeTemplateLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get memeTemplateLive;

  /// No description provided for @memeTemplatePoster.
  ///
  /// In en, this message translates to:
  /// **'Poster'**
  String get memeTemplatePoster;

  /// No description provided for @memeTemplateSnap.
  ///
  /// In en, this message translates to:
  /// **'Snap bar'**
  String get memeTemplateSnap;

  /// No description provided for @memeTemplateSplit.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get memeTemplateSplit;

  /// No description provided for @memeTopLine.
  ///
  /// In en, this message translates to:
  /// **'Top line'**
  String get memeTopLine;

  /// No description provided for @memeBottomLine.
  ///
  /// In en, this message translates to:
  /// **'Bottom line'**
  String get memeBottomLine;

  /// No description provided for @memeHeader.
  ///
  /// In en, this message translates to:
  /// **'Header'**
  String get memeHeader;

  /// No description provided for @memeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Headline'**
  String get memeHeadline;

  /// No description provided for @memeReaction.
  ///
  /// In en, this message translates to:
  /// **'Reaction'**
  String get memeReaction;

  /// No description provided for @memeTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get memeTitle;

  /// No description provided for @memeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get memeSubtitle;

  /// No description provided for @memeBarText.
  ///
  /// In en, this message translates to:
  /// **'Bar text'**
  String get memeBarText;

  /// No description provided for @memeTopPanel.
  ///
  /// In en, this message translates to:
  /// **'Top panel'**
  String get memeTopPanel;

  /// No description provided for @memeBottomPanel.
  ///
  /// In en, this message translates to:
  /// **'Bottom label'**
  String get memeBottomPanel;

  /// No description provided for @memeWritePrompt.
  ///
  /// In en, this message translates to:
  /// **'Make the joke.'**
  String get memeWritePrompt;

  /// No description provided for @memeSend.
  ///
  /// In en, this message translates to:
  /// **'Send meme'**
  String get memeSend;

  /// No description provided for @memeSentWaiting.
  ///
  /// In en, this message translates to:
  /// **'Meme sent. Waiting for the others.'**
  String get memeSentWaiting;

  /// No description provided for @memeSwapPhoto.
  ///
  /// In en, this message translates to:
  /// **'Swap photo'**
  String get memeSwapPhoto;

  /// No description provided for @memeSwapsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String memeSwapsLeft(int count);

  /// No description provided for @memeSwapsMatchWide.
  ///
  /// In en, this message translates to:
  /// **'5 swaps for the whole match.'**
  String get memeSwapsMatchWide;

  /// No description provided for @memeVoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Vote on this meme.'**
  String get memeVoteTitle;

  /// No description provided for @memeVoteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upvote, Meh or Downvote. You cannot vote for your own meme.'**
  String get memeVoteSubtitle;

  /// No description provided for @memeUpvote.
  ///
  /// In en, this message translates to:
  /// **'Upvote'**
  String get memeUpvote;

  /// No description provided for @memeMeh.
  ///
  /// In en, this message translates to:
  /// **'Meh'**
  String get memeMeh;

  /// No description provided for @memeDownvote.
  ///
  /// In en, this message translates to:
  /// **'Downvote'**
  String get memeDownvote;

  /// No description provided for @memeAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous until the reveal'**
  String get memeAnonymous;

  /// No description provided for @memeYourMeme.
  ///
  /// In en, this message translates to:
  /// **'Your meme'**
  String get memeYourMeme;

  /// No description provided for @memeNextMeme.
  ///
  /// In en, this message translates to:
  /// **'Next meme'**
  String get memeNextMeme;

  /// No description provided for @memeSeeResult.
  ///
  /// In en, this message translates to:
  /// **'See result'**
  String get memeSeeResult;

  /// No description provided for @memeVoteLocked.
  ///
  /// In en, this message translates to:
  /// **'Vote locked.'**
  String get memeVoteLocked;

  /// No description provided for @memeTapToVote.
  ///
  /// In en, this message translates to:
  /// **'Tap one to vote.'**
  String get memeTapToVote;

  /// No description provided for @memeWaitingVotes.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the rest of the table.'**
  String get memeWaitingVotes;

  /// No description provided for @memeRoundWinner.
  ///
  /// In en, this message translates to:
  /// **'Round winner'**
  String get memeRoundWinner;

  /// No description provided for @memeCreatorPoints.
  ///
  /// In en, this message translates to:
  /// **'Creator points'**
  String get memeCreatorPoints;

  /// No description provided for @memeModelRoyalty.
  ///
  /// In en, this message translates to:
  /// **'Model royalty'**
  String get memeModelRoyalty;

  /// No description provided for @memeRoyaltyBody.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s photo was in the winning meme. {name} gets +25.'**
  String memeRoyaltyBody(String name);

  /// No description provided for @memeTopMemes.
  ///
  /// In en, this message translates to:
  /// **'Top 3 memes'**
  String get memeTopMemes;

  /// No description provided for @memeFinalRound.
  ///
  /// In en, this message translates to:
  /// **'Final round: everyone gets the same photo. Double points.'**
  String get memeFinalRound;

  /// No description provided for @memeDownload.
  ///
  /// In en, this message translates to:
  /// **'Save meme'**
  String get memeDownload;

  /// No description provided for @memeSaved.
  ///
  /// In en, this message translates to:
  /// **'Meme saved.'**
  String get memeSaved;

  /// No description provided for @memeSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the meme.'**
  String get memeSaveFailed;

  /// No description provided for @memePhotoFrom.
  ///
  /// In en, this message translates to:
  /// **'Photo from {name}'**
  String memePhotoFrom(Object name);

  /// No description provided for @memePoints.
  ///
  /// In en, this message translates to:
  /// **'{score} pts'**
  String memePoints(int score);

  /// No description provided for @memeVotesUp.
  ///
  /// In en, this message translates to:
  /// **'Upvotes'**
  String get memeVotesUp;

  /// No description provided for @memeVotesMeh.
  ///
  /// In en, this message translates to:
  /// **'Meh'**
  String get memeVotesMeh;

  /// No description provided for @memeVotesDown.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get memeVotesDown;

  /// No description provided for @memeWriteSomething.
  ///
  /// In en, this message translates to:
  /// **'Write something first.'**
  String get memeWriteSomething;

  /// No description provided for @memeSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get memeSound;

  /// No description provided for @memeSoundBody.
  ///
  /// In en, this message translates to:
  /// **'Ticks, votes and the podium fanfare'**
  String get memeSoundBody;

  /// No description provided for @memeHaptics.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get memeHaptics;

  /// No description provided for @memeHapticsBody.
  ///
  /// In en, this message translates to:
  /// **'A tap when a vote lands'**
  String get memeHapticsBody;

  /// No description provided for @pickDecade.
  ///
  /// In en, this message translates to:
  /// **'Pick a decade'**
  String get pickDecade;

  /// No description provided for @pickYear.
  ///
  /// In en, this message translates to:
  /// **'Pick a year'**
  String get pickYear;

  /// No description provided for @pickMonth.
  ///
  /// In en, this message translates to:
  /// **'Pick a month'**
  String get pickMonth;

  /// No description provided for @actualDate.
  ///
  /// In en, this message translates to:
  /// **'Actual date'**
  String get actualDate;

  /// No description provided for @ownerIncluded.
  ///
  /// In en, this message translates to:
  /// **'Owner included'**
  String get ownerIncluded;

  /// No description provided for @averageMiss.
  ///
  /// In en, this message translates to:
  /// **'Average miss: {distance}'**
  String averageMiss(String distance);

  /// No description provided for @yourGuess.
  ///
  /// In en, this message translates to:
  /// **'Your guess'**
  String get yourGuess;

  /// No description provided for @ownerLabel.
  ///
  /// In en, this message translates to:
  /// **'OWNER'**
  String get ownerLabel;

  /// No description provided for @breakingNews.
  ///
  /// In en, this message translates to:
  /// **'BREAKING NEWS'**
  String get breakingNews;

  /// No description provided for @liveBadge.
  ///
  /// In en, this message translates to:
  /// **'● LIVE'**
  String get liveBadge;

  /// No description provided for @gameFeel.
  ///
  /// In en, this message translates to:
  /// **'Game feel'**
  String get gameFeel;

  /// No description provided for @alsoInTheRoom.
  ///
  /// In en, this message translates to:
  /// **'Also in the room'**
  String get alsoInTheRoom;

  /// No description provided for @finalTable.
  ///
  /// In en, this message translates to:
  /// **'Final table'**
  String get finalTable;

  /// No description provided for @memeNoMemes.
  ///
  /// In en, this message translates to:
  /// **'No memes this round.'**
  String get memeNoMemes;

  /// No description provided for @partyPassTitle.
  ///
  /// In en, this message translates to:
  /// **'WhoTook Party Pass'**
  String get partyPassTitle;

  /// No description provided for @partyPassSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One payment. Every party feature, forever.'**
  String get partyPassSubtitle;

  /// No description provided for @partyPassPerkRelayTitle.
  ///
  /// In en, this message translates to:
  /// **'5G & firewall relay'**
  String get partyPassPerkRelayTitle;

  /// No description provided for @partyPassPerkRelayBody.
  ///
  /// In en, this message translates to:
  /// **'Play through strict 5G and carrier NATs with our encrypted relay, with a fair-use allowance every day.'**
  String get partyPassPerkRelayBody;

  /// No description provided for @partyPassPerkSoundboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Live soundboard'**
  String get partyPassPerkSoundboardTitle;

  /// No description provided for @partyPassPerkSoundboardBody.
  ///
  /// In en, this message translates to:
  /// **'Drop Airhorn, Vine Boom and more during rounds. Everyone in the room hears it.'**
  String get partyPassPerkSoundboardBody;

  /// No description provided for @partyPassPerkThemesTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared room themes'**
  String get partyPassPerkThemesTitle;

  /// No description provided for @partyPassPerkThemesBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a premium theme and every friend\'s phone switches with you for the whole match.'**
  String get partyPassPerkThemesBody;

  /// partyPassUnlockButton
  ///
  /// In en, this message translates to:
  /// **'Unlock Forever — {price}'**
  String partyPassUnlockButton(String price);

  /// No description provided for @partyPassRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get partyPassRestore;

  /// No description provided for @partyPassRestoreHint.
  ///
  /// In en, this message translates to:
  /// **'Already bought it? Restore it on this device.'**
  String get partyPassRestoreHint;

  /// No description provided for @partyPassActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'Party Pass Active'**
  String get partyPassActiveBadge;

  /// No description provided for @partyPassActiveBody.
  ///
  /// In en, this message translates to:
  /// **'Relay, soundboard and shared themes are unlocked on this device.'**
  String get partyPassActiveBody;

  /// partyPassFairUse
  ///
  /// In en, this message translates to:
  /// **'{remaining} of {limit} relay matches left today'**
  String partyPassFairUse(int remaining, int limit);

  /// No description provided for @partyPassFossIncluded.
  ///
  /// In en, this message translates to:
  /// **'Included in this FOSS build'**
  String get partyPassFossIncluded;

  /// No description provided for @partyPassFossBody.
  ///
  /// In en, this message translates to:
  /// **'No store, no tracking. The soundboard and all themes are free, and you can point the app at your own TURN server.'**
  String get partyPassFossBody;

  /// No description provided for @partyPassCustomTurn.
  ///
  /// In en, this message translates to:
  /// **'Use your own TURN server'**
  String get partyPassCustomTurn;

  /// No description provided for @partyPassStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The store is not available in this build. Restore purchases after installing from the App Store or Google Play.'**
  String get partyPassStoreUnavailable;

  /// No description provided for @partyPassPurchasePending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the store to confirm your purchase…'**
  String get partyPassPurchasePending;

  /// No description provided for @partyPassErrorCanceled.
  ///
  /// In en, this message translates to:
  /// **'Purchase canceled. Nothing was charged.'**
  String get partyPassErrorCanceled;

  /// No description provided for @partyPassErrorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The store is not available right now. Try again in a moment.'**
  String get partyPassErrorUnavailable;

  /// No description provided for @partyPassErrorProduct.
  ///
  /// In en, this message translates to:
  /// **'The Party Pass product is not available in this store yet.'**
  String get partyPassErrorProduct;

  /// No description provided for @partyPassErrorRestoreEmpty.
  ///
  /// In en, this message translates to:
  /// **'No previous Party Pass purchase was found on this account.'**
  String get partyPassErrorRestoreEmpty;

  /// No description provided for @partyPassErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again, or restore purchases.'**
  String get partyPassErrorGeneric;

  /// No description provided for @partyPassRelayError.
  ///
  /// In en, this message translates to:
  /// **'The relay could not verify this purchase right now. Direct play still works.'**
  String get partyPassRelayError;

  /// No description provided for @partyPassTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get partyPassTerms;

  /// No description provided for @partyPassPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get partyPassPrivacy;

  /// partyPassLobbyButton
  ///
  /// In en, this message translates to:
  /// **'Party Pass ({price})'**
  String partyPassLobbyButton(String price);

  /// No description provided for @partyPassLobbyActive.
  ///
  /// In en, this message translates to:
  /// **'Party Pass Active'**
  String get partyPassLobbyActive;

  /// No description provided for @partyPassLoading.
  ///
  /// In en, this message translates to:
  /// **'Checking your pass…'**
  String get partyPassLoading;

  /// No description provided for @roomThemePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Room theme'**
  String get roomThemePickerTitle;

  /// No description provided for @roomThemePickerBody.
  ///
  /// In en, this message translates to:
  /// **'The theme applies to every phone in this lobby for the whole match.'**
  String get roomThemePickerBody;

  /// No description provided for @roomThemeClassicParty.
  ///
  /// In en, this message translates to:
  /// **'Classic Party'**
  String get roomThemeClassicParty;

  /// No description provided for @roomThemeMidnightArcade.
  ///
  /// In en, this message translates to:
  /// **'Midnight Arcade'**
  String get roomThemeMidnightArcade;

  /// No description provided for @roomThemeCyberNeon.
  ///
  /// In en, this message translates to:
  /// **'Cyber Neon'**
  String get roomThemeCyberNeon;

  /// No description provided for @roomThemeRetroPolaroid.
  ///
  /// In en, this message translates to:
  /// **'Retro Polaroid 90s'**
  String get roomThemeRetroPolaroid;

  /// No description provided for @roomThemePubKroeg.
  ///
  /// In en, this message translates to:
  /// **'Pub / Kroeg Mode'**
  String get roomThemePubKroeg;

  /// No description provided for @roomThemePremium.
  ///
  /// In en, this message translates to:
  /// **'Party Pass'**
  String get roomThemePremium;

  /// No description provided for @roomThemeSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get roomThemeSelected;

  /// No description provided for @roomThemeLocked.
  ///
  /// In en, this message translates to:
  /// **'Unlock the Party Pass to share this theme'**
  String get roomThemeLocked;

  /// No description provided for @lobbyThemeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get lobbyThemeLabel;

  /// No description provided for @lobbySoundboardLabel.
  ///
  /// In en, this message translates to:
  /// **'Soundboard'**
  String get lobbySoundboardLabel;

  /// No description provided for @lobbyRelayLabel.
  ///
  /// In en, this message translates to:
  /// **'Relay'**
  String get lobbyRelayLabel;

  /// No description provided for @lobbySoundboardOn.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get lobbySoundboardOn;

  /// No description provided for @lobbySoundboardOff.
  ///
  /// In en, this message translates to:
  /// **'Pass only'**
  String get lobbySoundboardOff;

  /// No description provided for @relayStatusLocal.
  ///
  /// In en, this message translates to:
  /// **'Same Wi-Fi'**
  String get relayStatusLocal;

  /// No description provided for @relayStatusDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct P2P'**
  String get relayStatusDirect;

  /// No description provided for @relayStatusRelay.
  ///
  /// In en, this message translates to:
  /// **'5G relay'**
  String get relayStatusRelay;

  /// No description provided for @relayStatusCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom TURN'**
  String get relayStatusCustom;

  /// No description provided for @relayStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get relayStatusOffline;

  /// No description provided for @relayStatusFoss.
  ///
  /// In en, this message translates to:
  /// **'Self-host ready'**
  String get relayStatusFoss;

  /// No description provided for @soundboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Soundboard'**
  String get soundboardTitle;

  /// No description provided for @soundboardHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a sound. Everyone hears it.'**
  String get soundboardHint;

  /// No description provided for @soundboardCollapse.
  ///
  /// In en, this message translates to:
  /// **'Hide soundboard'**
  String get soundboardCollapse;

  /// No description provided for @soundboardExpand.
  ///
  /// In en, this message translates to:
  /// **'Show soundboard'**
  String get soundboardExpand;

  /// soundboardCooldown
  ///
  /// In en, this message translates to:
  /// **'Wait {seconds}s'**
  String soundboardCooldown(int seconds);

  /// No description provided for @soundboardLocked.
  ///
  /// In en, this message translates to:
  /// **'The live soundboard is part of the Party Pass.'**
  String get soundboardLocked;

  /// No description provided for @soundVineBoom.
  ///
  /// In en, this message translates to:
  /// **'Vine Boom'**
  String get soundVineBoom;

  /// No description provided for @soundAirhorn.
  ///
  /// In en, this message translates to:
  /// **'Airhorn'**
  String get soundAirhorn;

  /// No description provided for @soundCrickets.
  ///
  /// In en, this message translates to:
  /// **'Crickets'**
  String get soundCrickets;

  /// No description provided for @soundSadTrombone.
  ///
  /// In en, this message translates to:
  /// **'Sad Trombone'**
  String get soundSadTrombone;

  /// No description provided for @soundDrumroll.
  ///
  /// In en, this message translates to:
  /// **'Drumroll'**
  String get soundDrumroll;

  /// No description provided for @soundLaughTrack.
  ///
  /// In en, this message translates to:
  /// **'Laugh Track'**
  String get soundLaughTrack;

  /// soundPlayedToast
  ///
  /// In en, this message translates to:
  /// **'{name} played {sound}'**
  String soundPlayedToast(String name, String sound);

  /// No description provided for @firewallTitle.
  ///
  /// In en, this message translates to:
  /// **'Strict 5G firewall detected!'**
  String get firewallTitle;

  /// No description provided for @firewallBody.
  ///
  /// In en, this message translates to:
  /// **'Connect to the same Wi-Fi/Hotspot to play 100% free, or unlock the WhoTook Party Pass (€2.99 once) to use our high-speed 5G Relay Server.'**
  String get firewallBody;

  /// No description provided for @firewallWifiAction.
  ///
  /// In en, this message translates to:
  /// **'Play on Wi-Fi/Hotspot'**
  String get firewallWifiAction;

  /// No description provided for @firewallUnlockAction.
  ///
  /// In en, this message translates to:
  /// **'Unlock Party Pass'**
  String get firewallUnlockAction;

  /// No description provided for @firewallFossAction.
  ///
  /// In en, this message translates to:
  /// **'Set up custom TURN'**
  String get firewallFossAction;

  /// No description provided for @firewallRelayDownTitle.
  ///
  /// In en, this message translates to:
  /// **'Relay could not connect'**
  String get firewallRelayDownTitle;

  /// No description provided for @firewallRelayDownBody.
  ///
  /// In en, this message translates to:
  /// **'Your Party Pass is active, but the relay did not answer. Check your connection, then try again.'**
  String get firewallRelayDownBody;

  /// No description provided for @firewallRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get firewallRetryAction;

  /// No description provided for @fossTurnTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom TURN Server (Self-Host)'**
  String get fossTurnTitle;

  /// No description provided for @fossTurnBody.
  ///
  /// In en, this message translates to:
  /// **'FOSS builds never use the official relay. Point the app at your own coturn server for strict networks.'**
  String get fossTurnBody;

  /// No description provided for @fossTurnSaved.
  ///
  /// In en, this message translates to:
  /// **'Custom TURN saved'**
  String get fossTurnSaved;

  /// No description provided for @fossBuildBadge.
  ///
  /// In en, this message translates to:
  /// **'FOSS build'**
  String get fossBuildBadge;

  /// No description provided for @fossBuildBody.
  ///
  /// In en, this message translates to:
  /// **'No billing, no analytics, no official relay.'**
  String get fossBuildBody;

  /// No description provided for @settingsPartyPassTitle.
  ///
  /// In en, this message translates to:
  /// **'WhoTook Party Pass'**
  String get settingsPartyPassTitle;

  /// No description provided for @settingsPartyPassActive.
  ///
  /// In en, this message translates to:
  /// **'Active on this device'**
  String get settingsPartyPassActive;

  /// No description provided for @settingsPartyPassInactive.
  ///
  /// In en, this message translates to:
  /// **'Relay, soundboard and shared themes'**
  String get settingsPartyPassInactive;

  /// No description provided for @errorRelayUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The relay is unavailable right now. Direct play still works.'**
  String get errorRelayUnavailable;

  /// No description provided for @roomThemeFree.
  ///
  /// In en, this message translates to:
  /// **'Free for everyone'**
  String get roomThemeFree;

  /// No description provided for @turnCredentialPairError.
  ///
  /// In en, this message translates to:
  /// **'Fill in both the TURN username and password, or leave both empty.'**
  String get turnCredentialPairError;

  /// No description provided for @firewallQuotaTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily relay limit reached'**
  String get firewallQuotaTitle;

  /// No description provided for @firewallQuotaBody.
  ///
  /// In en, this message translates to:
  /// **'Your Party Pass relay allowance is used up. It resets on a rolling 24-hour window. Play on the same Wi-Fi/hotspot, or configure your own TURN server.'**
  String get firewallQuotaBody;

  /// No description provided for @firewallVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not verify this purchase'**
  String get firewallVerificationTitle;

  /// No description provided for @firewallVerificationBody.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases from the Party Pass sheet, or contact support. Direct play still works.'**
  String get firewallVerificationBody;

  /// Reset time for the daily relay allowance
  ///
  /// In en, this message translates to:
  /// **'Next allowance: {time}'**
  String firewallQuotaReset(String time);

  /// No description provided for @firewallBusyTitle.
  ///
  /// In en, this message translates to:
  /// **'Relay is busy'**
  String get firewallBusyTitle;

  /// No description provided for @firewallBusyBody.
  ///
  /// In en, this message translates to:
  /// **'Too many relay attempts from this network. Wait a moment and try again.'**
  String get firewallBusyBody;

  /// Retry time after an IP rate limit
  ///
  /// In en, this message translates to:
  /// **'Try again after {time}'**
  String firewallBusyReset(String time);

  /// No description provided for @firewallRetryNow.
  ///
  /// In en, this message translates to:
  /// **'Retry now'**
  String get firewallRetryNow;

  /// No description provided for @errorHostStarting.
  ///
  /// In en, this message translates to:
  /// **'The host is still opening the room. Try again in a moment.'**
  String get errorHostStarting;

  /// No description provided for @errorInviteExpired.
  ///
  /// In en, this message translates to:
  /// **'This invite has expired. Ask the host for a new QR code.'**
  String get errorInviteExpired;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'nl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'nl':
      return AppLocalizationsNl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
