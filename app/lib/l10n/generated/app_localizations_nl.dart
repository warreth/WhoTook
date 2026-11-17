// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get language => 'Taal';

  @override
  String get languageSystem => 'Zelfde als toestel';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageDutch => 'Nederlands';

  @override
  String get cancel => 'Annuleren';

  @override
  String get continueLabel => 'Doorgaan';

  @override
  String get close => 'Sluiten';

  @override
  String get remove => 'Verwijderen';

  @override
  String get done => 'Klaar';

  @override
  String get retry => 'Opnieuw proberen';

  @override
  String get back => 'Terug';

  @override
  String get leave => 'Verlaten';

  @override
  String get stay => 'Blijven';

  @override
  String get settings => 'Instellingen';

  @override
  String get player => 'Speler';

  @override
  String get ready => 'Klaar';

  @override
  String get waitingForHost => 'Wachten op de host';

  @override
  String get nextRoundInMoment => 'Volgende ronde begint zo.';

  @override
  String get hostAGame => 'Start een spel';

  @override
  String get hostAGameSubtitle => 'Kies de modus, rondes en tempo';

  @override
  String get joinAGame => 'Doe mee met een spel';

  @override
  String get joinAGameSubtitle => 'Scan de QR-code van de host';

  @override
  String get homeFooter => 'Foto\'s blijven bij de spelers.';

  @override
  String get lastRoom => 'Vorige ruimte';

  @override
  String roomLabel(String roomId) {
    return 'Ruimte $roomId';
  }

  @override
  String get forgetRoom => 'Deze ruimte vergeten';

  @override
  String get howItPlays => 'Zo werkt het';

  @override
  String get guideSetTable => 'Kies het spel';

  @override
  String get guideSetTableBody => 'Modus, rondes en tempo.';

  @override
  String get guideScanIn => 'Vrienden scannen in';

  @override
  String get guideScanInBody => 'Vrienden komen binnen via de QR.';

  @override
  String get guidePlay => 'Spelen';

  @override
  String get guidePlayBody =>
      'Raad een foto, maak een meme of reis door de tijd.';

  @override
  String get heroFact => '2–12 spelers · Zelfde wifi of online';

  @override
  String get heroTitle => 'Wiens foto\'s\nzijn dit?';

  @override
  String get heroSubtitle => 'Eén foto per keer. Iedereen raadt wie hem nam.';

  @override
  String get onlineRelayUsed =>
      'De online relay is vandaag op. Speel verder op dezelfde wifi.';

  @override
  String get guessWhosePhoto => 'Raad van wie de foto is';

  @override
  String get onboardingTagline =>
      'Eén foto. Eén gok. Tik op wie volgens jou de foto nam.';

  @override
  String get yourName => 'Je naam';

  @override
  String get acceptTerms =>
      'Ik ga akkoord met de voorwaarden en de spelregels.';

  @override
  String get termsLink => 'Voorwaarden en spelregels';

  @override
  String get privacy => 'Privacy';

  @override
  String get onboardingPhotoNote =>
      'Foto\'s worden pas gelezen als een spel start. Je kunt privéalbums in Instellingen buiten elk spel houden.';

  @override
  String get pickNameError => 'Kies een naam die je vrienden herkennen.';

  @override
  String get acceptTermsError =>
      'Ga akkoord met de voorwaarden voor je doorgaat.';

  @override
  String get joinAMatch => 'Doe mee met een spel';

  @override
  String get connectingToHost => 'Verbinden met de host';

  @override
  String get pasteInvite => 'Of plak een uitnodigingslink';

  @override
  String get useThisLink => 'Deze link gebruiken';

  @override
  String get cameraUnavailable =>
      'Camera niet beschikbaar. Geef toegang of plak hieronder een link.';

  @override
  String get joiningAs => 'Je doet mee als';

  @override
  String get nameShownAtTable => 'Zichtbaar voor iedereen aan tafel';

  @override
  String get joinTheRoom => 'Meedoen';

  @override
  String get joining => 'Deelnemen';

  @override
  String joinRoomTitle(String roomId) {
    return 'Deelnemen aan ruimte $roomId';
  }

  @override
  String get invalidInvite =>
      'Die uitnodiging is niet geldig. Scan de QR-code opnieuw.';

  @override
  String get chooseGame => 'Kies het spel';

  @override
  String get chooseGameSubtitle =>
      'Klassiek, Make It Meme, Tijdreiziger of van alles wat.';

  @override
  String get nextRounds => 'Volgende: rondes';

  @override
  String get howManyRounds => 'Hoeveel rondes?';

  @override
  String get roundsSubtitle =>
      'Bij het podium kun je er altijd vijf rondes bij doen.';

  @override
  String get nextPace => 'Volgende: kies het tempo';

  @override
  String get quickGame => 'Snel spel';

  @override
  String get partySize => 'Voor een feestje';

  @override
  String get longTable => 'Lange tafel';

  @override
  String get allNighter => 'De hele nacht';

  @override
  String get pickPace => 'Kies het tempo';

  @override
  String get openRoom => 'Open de ruimte';

  @override
  String get couldNotOpenRoom => 'De ruimte kon niet worden geopend.';

  @override
  String stepOf(int step) {
    return 'Stap $step van 3';
  }

  @override
  String get hostAGameTitle => 'Start een spel';

  @override
  String roundsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rondes',
      one: '1 ronde',
    );
    return '$_temp0';
  }

  @override
  String get paceClassicSubtitle =>
      'Hoeveel tijd krijgt iedereen om elke foto te raden?';

  @override
  String get paceCaptionSubtitle =>
      'Hoeveel tijd krijgt iedereen om een bijschrift te schrijven?';

  @override
  String get paceTimelineSubtitle =>
      'Hoeveel tijd krijgt iedereen om een datum te kiezen?';

  @override
  String get paceMixedSubtitle => 'Elke modus houdt zijn eigen klok.';

  @override
  String get paceFastClassic => 'Snel beslissen.';

  @override
  String get paceNormalClassic => 'Het feesttempo.';

  @override
  String get paceSlowClassic => 'Voor de grote tafel.';

  @override
  String get paceFastCaption => 'Snel een bijschrift.';

  @override
  String get paceNormalCaption => 'Tijd om grappig te zijn.';

  @override
  String get paceSlowCaption => 'Geen haast, maak het goed.';

  @override
  String get paceFastTimeline => 'Snel een datum.';

  @override
  String get paceNormalTimeline => 'Denk er rustig over na.';

  @override
  String get paceSlowTimeline => 'Voor de geschiedenisfans.';

  @override
  String get paceFastMixed => 'Elke modus op snel tempo.';

  @override
  String get paceNormalMixed => 'Elke modus op normaal tempo.';

  @override
  String get paceSlowMixed => 'Elke modus op rustig tempo.';

  @override
  String get mixed => 'Gemengd';

  @override
  String secondsShort(int seconds) {
    return '${seconds}s';
  }

  @override
  String paceSemantic(String pace, String detail, String blurb) {
    return '$pace, $detail. $blurb';
  }

  @override
  String get paceFast => 'Snel';

  @override
  String get paceNormal => 'Normaal';

  @override
  String get paceSlow => 'Rustig';

  @override
  String get rejoin => 'Opnieuw deelnemen';

  @override
  String get yourRoom => 'Jouw ruimte';

  @override
  String get lobby => 'Lobby';

  @override
  String get leaveMatch => 'Spel verlaten';

  @override
  String get scanToJoin => 'Scan om mee te doen';

  @override
  String get scanToJoinBody =>
      'Richt een camera op de code. Je hebt geen app nodig om mee te doen.';

  @override
  String roomCode(String roomId) {
    return 'RUIMTE $roomId';
  }

  @override
  String get sameWifi => 'Zelfde wifi';

  @override
  String get online => 'Online';

  @override
  String get onlineWifiHint =>
      'Als iedereen op dezelfde wifi zit, is het sneller en blijven je foto\'s op je netwerk.';

  @override
  String get shareInviteLink => 'Deel de uitnodigingslink';

  @override
  String get hostStartsPhotoCheck =>
      'De host start de fotocheck zodra iedereen er is.';

  @override
  String get waitingForHostToStart => 'Wachten tot de host start';

  @override
  String playersJoined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spelers doen mee',
      one: '1 speler doet mee',
    );
    return '$_temp0';
  }

  @override
  String get waitingFirstFriend => 'Wachten op de eerste vriend';

  @override
  String get waitingFirstFriendBody =>
      'De QR-code hierboven is alles wat ze nodig hebben.';

  @override
  String get editAction => 'Wijzigen';

  @override
  String get editGameBody => 'Iedereen in de ruimte ziet je wijzigingen.';

  @override
  String get tonightsGame => 'Het spel van vanavond';

  @override
  String get modeLabel => 'Modus';

  @override
  String get roundsLabel => 'Rondes';

  @override
  String get paceLabel => 'Tempo';

  @override
  String removePlayerTitle(String name) {
    return '$name verwijderen?';
  }

  @override
  String get removePlayerLobbyBody =>
      'Die persoon verlaat deze ruimte en kan met de QR-code opnieuw deelnemen.';

  @override
  String get inviteLink => 'Uitnodigingslink';

  @override
  String get copied => 'Gekopieerd';

  @override
  String get copyLink => 'Link kopiëren';

  @override
  String get playerOptions => 'Speleropties';

  @override
  String get removeFromRoom => 'Uit de ruimte verwijderen';

  @override
  String get startPhotoCheck => 'Start de fotocheck';

  @override
  String get hostLabel => 'Host';

  @override
  String get choosing => 'Nog niet klaar';

  @override
  String get modeClassic => 'Klassiek';

  @override
  String get modeCaptionThis => 'Bijschrift';

  @override
  String get modeTimeTraveler => 'Tijdreiziger';

  @override
  String get modeMixedParty => 'Feestmix';

  @override
  String get rerollAll => 'Nieuwe foto\'s';

  @override
  String get waitingForPlayersButton => 'Wachten';

  @override
  String get checkYourPhotos => 'Controleer je foto\'s';

  @override
  String photosAllHere(int count) {
    return 'Alle $count foto\'s voor dit spel staan klaar. Tik op Nieuwe foto\'s voor een andere set.';
  }

  @override
  String photosPartial(int count, int needed) {
    return 'Je hebt $count van $needed. Tik op Nieuwe foto\'s om de set aan te vullen.';
  }

  @override
  String get photosReading => 'De foto\'s voor dit spel worden gelezen.';

  @override
  String photosTooFew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Slechts $count bruikbare foto\'s gevonden. Voeg foto\'s toe of sta meer albums toe in Instellingen en kies opnieuw. Je kunt ook doorgaan met deze set.',
      one: 'Slechts 1 bruikbare foto gevonden. Voeg foto\'s toe of sta meer albums toe in Instellingen en kies opnieuw. Je kunt ook doorgaan met deze set.',
    );
    return '$_temp0';
  }

  @override
  String get noUsablePhotos => 'Geen bruikbare foto\'s gevonden';

  @override
  String get noUsablePhotosBody =>
      'Geef toegang tot je foto\'s of voeg wat foto\'s toe aan je galerij. Foto\'s worden alleen uit toegestane albums gelezen.';

  @override
  String get photoSettings => 'Foto-instellingen';

  @override
  String get secretPhotoPlanted => 'Geheime foto geplant';

  @override
  String get plantSecretPhoto => 'Plant één geheime foto';

  @override
  String get plantSecretPhotoBody =>
      'Eén per spel. Het vervangt stilletjes een van je goedgekeurde foto\'s.';

  @override
  String get couldNotReadAlbums => 'Je albums konden niet worden gelezen.';

  @override
  String get couldNotReadAlbum => 'Dit album kon niet worden gelezen.';

  @override
  String get couldNotReadPhoto =>
      'Die foto kon niet worden gelezen. Probeer een andere.';

  @override
  String get couldNotSharePhoto =>
      'Die foto kon niet worden gedeeld. Probeer een andere.';

  @override
  String get pickPhotoToPlant => 'Kies de foto om te planten';

  @override
  String get pickPhotoToPlantBody =>
      'Een foto uit je albums. Eén per spel en niemand weet welke tot het podium.';

  @override
  String get readingAlbums => 'Je albums worden gelezen';

  @override
  String get albumsUnavailable => 'Albums zijn niet beschikbaar';

  @override
  String get albumsUnavailableBody =>
      'Toegang tot foto\'s staat misschien uit. Geef toegang en probeer opnieuw.';

  @override
  String get noPhotosToPlant => 'Geen foto\'s om te planten';

  @override
  String get noPhotosToPlantBody =>
      'Er zijn nog geen goedgekeurde foto\'s op dit toestel.';

  @override
  String get fromApprovedPhotos => 'Uit je goedgekeurde foto\'s';

  @override
  String roundOf(int round, int total) {
    return 'Ronde $round van $total';
  }

  @override
  String get whoTookThis => 'Wie nam deze?';

  @override
  String screenshotBy(String name) {
    return '$name nam een schermafbeelding';
  }

  @override
  String get lockedInWaiting => 'Vastgelegd, wachten op de anderen.';

  @override
  String get getReady => 'Maak je klaar';

  @override
  String get tapWhoTook => 'Tik op wie de foto nam zodra hij verschijnt';

  @override
  String get tapNameToLock => 'Tik een naam aan om te gokken.';

  @override
  String get noAnswer => 'Geen antwoord.';

  @override
  String yourPhotoYouGotIt(int points) {
    return 'Jouw foto. Juist geraden. +$points';
  }

  @override
  String youGotIt(int points) {
    return 'Juist geraden. +$points';
  }

  @override
  String get yourPhotoWrongGuess => 'Jouw foto. Fout geraden.';

  @override
  String get wrongGuess => 'Fout geraden.';

  @override
  String playersFooled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spelers erin getrapt',
      one: '1 speler erin getrapt',
    );
    return '$_temp0';
  }

  @override
  String playersDidNotAnswer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spelers gaven geen antwoord',
      one: '1 speler gaf geen antwoord',
    );
    return '$_temp0';
  }

  @override
  String get everyoneGotItRight => 'Iedereen had het juist';

  @override
  String shotBy(String name) {
    return 'Foto van $name';
  }

  @override
  String get whoTookIt => 'Wie nam de foto?';

  @override
  String fastestAward(String name, String seconds) {
    return 'Snelste: $name ${seconds}s';
  }

  @override
  String get nobodyGuessed => 'Niemand had het juist';

  @override
  String get everyoneNailedIt => 'Allemaal juist';

  @override
  String get writeFunniestCaption => 'Schrijf het grappigste bijschrift';

  @override
  String get captionSentWaiting =>
      'Bijschrift verstuurd. Wachten op de anderen.';

  @override
  String get yourCaption => 'Jouw bijschrift';

  @override
  String get makeItWeird => 'Maak het raar.';

  @override
  String get waitingForOthers => 'Wachten op de anderen';

  @override
  String get sendCaption => 'Bijschrift versturen';

  @override
  String votesIn(int votes, int total) {
    return '$votes van $total stemmen binnen. De onthulling start zodra iedereen heeft gestemd.';
  }

  @override
  String get tapOneCaption =>
      'Tik op één bijschrift. Je kunt niet op je eigen bijschrift stemmen.';

  @override
  String get voteLockedWaiting =>
      'Stem vastgelegd. Wachten tot de rest klaar is.';

  @override
  String get revealNow => 'Nu onthullen';

  @override
  String get noCaptions => 'Geen bijschriften';

  @override
  String get thisRoundMovesOn => 'Deze ronde gaat verder.';

  @override
  String get tableHasSpoken => 'De groep heeft gesproken';

  @override
  String photoBy(String name) {
    return 'Foto van $name';
  }

  @override
  String get yourCaptionZero => 'Je bijschrift kreeg geen stemmen. Genadeloos.';

  @override
  String yourCaptionVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Je bijschrift kreeg $count stemmen.',
      one: 'Je bijschrift kreeg 1 stem.',
    );
    return '$_temp0';
  }

  @override
  String get zeroVotes => 'Geen stemmen';

  @override
  String get groupMenace => 'Groepsgevaar';

  @override
  String get topCaption => 'Topbijschrift';

  @override
  String voteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stemmen',
      one: '1 stem',
    );
    return '$_temp0';
  }

  @override
  String captionAuthorBadge(String author, String badge) {
    return '$author · $badge';
  }

  @override
  String get whenWasThisTaken => 'Wanneer is dit genomen?';

  @override
  String get guessYearMonth => 'Raad het jaar en de maand';

  @override
  String lockedDate(String date) {
    return 'Vastgelegd: $date';
  }

  @override
  String lockInDate(String date) {
    return '$date vastleggen';
  }

  @override
  String get timeLord => 'Tijdheer';

  @override
  String get mostDelusional => 'Meest ernaast';

  @override
  String get noGuess => 'Geen gok';

  @override
  String get exact => 'exact';

  @override
  String offBy(String distance) {
    return '$distance ernaast';
  }

  @override
  String monthCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count maanden',
      one: '1 maand',
    );
    return '$_temp0';
  }

  @override
  String yearCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jaar',
      one: '1 jaar',
    );
    return '$_temp0';
  }

  @override
  String get matchAwards => 'Prijzen van het spel';

  @override
  String get oneMoreRound => '5 rondes erbij';

  @override
  String get backToLobby => 'Terug naar de lobby';

  @override
  String points(int score) {
    return '$score punten';
  }

  @override
  String get quickestDraw => 'Snelste vinger';

  @override
  String get longestStreak => 'Langste reeks';

  @override
  String get masterOfMystery => 'Mysteriespeurder';

  @override
  String get paparazzi => 'Paparazzi';

  @override
  String get smoothPlanter => 'Slimme smokkelaar';

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
    return '$count punten';
  }

  @override
  String awardFrames(int count) {
    return '$count schermafbeeldingen';
  }

  @override
  String awardFooled(int count) {
    return '$count erin getrapt';
  }

  @override
  String moreRounds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nog $count rondes',
      one: 'Nog 1 ronde',
    );
    return '$_temp0';
  }

  @override
  String get swapBeforeTimer =>
      'Wissel zoveel als je wilt voor de timer stopt.';

  @override
  String get pickingExtraPhotos => 'Extra foto\'s kiezen';

  @override
  String get freshFrames =>
      'Er komen nieuwe foto\'s uit je albums. Dit blijft op je toestel.';

  @override
  String get approve => 'Goedkeuren';

  @override
  String get reviewDemo => 'Demo bekijken';

  @override
  String get closeDemo => 'Demo sluiten';

  @override
  String get demoFake =>
      'Demo met nepspelers. Geen netwerk en geen echte foto\'s.';

  @override
  String get allDemoPhotos =>
      'Alle 4 demofoto\'s staan klaar. Tik op Nieuwe foto\'s voor een andere set.';

  @override
  String get startDemoRound => 'Demo-ronde starten';

  @override
  String get timerRanOut => 'De tijd is op.';

  @override
  String youGuessed(String name) {
    return 'Je gokte $name. Volgende keer beter.';
  }

  @override
  String get seePodium => 'Naar het podium';

  @override
  String get restartDemo => 'Demo opnieuw starten';

  @override
  String get placeFirst => '1e';

  @override
  String get placeSecond => '2e';

  @override
  String get placeThird => '3e';

  @override
  String placeNth(int place) {
    return '${place}e';
  }

  @override
  String get lockedIn => 'Vastgelegd';

  @override
  String get podium => 'Podium';

  @override
  String get champion => 'Kampioen';

  @override
  String get settingsTitle => 'Instellingen';

  @override
  String get nameLabel => 'Naam';

  @override
  String get nameHelper => 'Zichtbaar voor andere spelers';

  @override
  String get avatar => 'Avatar';

  @override
  String get theme => 'Thema';

  @override
  String get themeSystem => 'Zelfde als toestel';

  @override
  String get themeLight => 'Licht';

  @override
  String get themeDark => 'Donker';

  @override
  String get privateAlbums => 'Privéalbums';

  @override
  String excludedCount(int count) {
    return '$count uitgesloten';
  }

  @override
  String get privateAlbumsBody =>
      'Optioneel. Uitgesloten albums worden nooit gebruikt in een spel.';

  @override
  String get albumListUnavailable => 'Albumlijst niet beschikbaar';

  @override
  String get albumListUnavailableBody =>
      'Toegang tot foto\'s is niet gegeven. Geef toegang en probeer opnieuw.';

  @override
  String get noAlbums => 'Geen albums gevonden';

  @override
  String get noAlbumsBody =>
      'Geef toegang tot foto\'s om privéalbums te kiezen. Foto\'s worden pas gelezen als een spel start.';

  @override
  String get allowPhotoAccess => 'Toegang tot foto\'s geven';

  @override
  String photosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foto\'s',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String get onlineRelay => 'Online relay';

  @override
  String get onlineRelayBody =>
      'Lokaal spelen gebruikt nooit een server. Online spelen gebruikt een kleine relay voor vrienden elders.';

  @override
  String get selfHostedRelay => 'Eigen relay';

  @override
  String get selfHostedRelayBody =>
      'Laat de app je eigen signalerings- en TURN-server gebruiken';

  @override
  String get signalingUrl => 'Signalerings-URL';

  @override
  String signalingUrlHelper(String url) {
    return 'Standaard: $url';
  }

  @override
  String get customTurnUrl => 'TURN-URI';

  @override
  String get customTurnHelper =>
      'Optioneel, bijvoorbeeld turn:turn.example.org:3478';

  @override
  String get turnUsername => 'Gebruikersnaam';

  @override
  String get turnCredential => 'Wachtwoord';

  @override
  String get resetToDefault => 'Herstellen';

  @override
  String get saveRelay => 'Relay bewaren';

  @override
  String get helpAndLegal => 'Help en juridische info';

  @override
  String get reportContent => 'Inhoud of een speler melden';

  @override
  String reportBody(String email) {
    return 'Stuur de ruimtecode en wat er gebeurde naar $email';
  }

  @override
  String get termsAndRules => 'Voorwaarden en spelregels';

  @override
  String get openSource =>
      'Open source onder de AGPLv3. Foto\'s blijven op je telefoon.';

  @override
  String get trademark => 'WhoTook™ is een merk van de projecteigenaar.';

  @override
  String get relaySignalingSchemeError =>
      'De signalerings-URL moet beginnen met https://, http://, wss:// of ws://';

  @override
  String get relayTurnSchemeError =>
      'De TURN-URL moet beginnen met turn: of turns:';

  @override
  String get relaySaved => 'Relay bewaard';

  @override
  String get relayDefault => 'Standaardrelay hersteld.';

  @override
  String get about => 'Over';

  @override
  String get support => 'Ondersteuning';

  @override
  String avatarOption(int number) {
    return 'Avatar $number';
  }

  @override
  String get yourPhotoAvatar => 'Je foto-avatar';

  @override
  String get pickAnAvatar => 'Kies een avatar';

  @override
  String get photoAvatarStored =>
      'Bewaard op dit toestel en alleen in de ruimte gedeeld.';

  @override
  String get avatarChoices =>
      'Een selfie, een foto uit je galerij of een icoon.';

  @override
  String get takeSelfie => 'Neem een selfie';

  @override
  String get choosePhoto => 'Kies een foto';

  @override
  String get useIcon => 'Gebruik een icoon';

  @override
  String get cropTitle => 'Je foto';

  @override
  String get cropHint =>
      'Knijp om te zoomen en sleep om je gezicht te centreren.';

  @override
  String get savingPhoto => 'Foto bewaren';

  @override
  String get useThisPhoto => 'Deze foto gebruiken';

  @override
  String get hostControls => 'Host-opties';

  @override
  String get skipRound => 'Ronde overslaan';

  @override
  String get removePlayer => 'Speler verwijderen';

  @override
  String get skipRoundTitle => 'Deze ronde overslaan?';

  @override
  String get skipRoundBody =>
      'Deze ronde stopt nu en de volgende ronde begint.';

  @override
  String get skipButton => 'Overslaan';

  @override
  String get removeAPlayer => 'Een speler verwijderen';

  @override
  String get removePlayerMatchBody =>
      'Die persoon verlaat dit spel. De fotorondes van die speler blijven in het spel.';

  @override
  String get differentVersions => 'Verschillende appversies';

  @override
  String versionWarningBody(
    String latestVersion,
    int latestBuild,
    String ownVersion,
    int ownBuild,
  ) {
    return 'Iemand gebruikt $latestVersion (build $latestBuild). Jij gebruikt $ownVersion (build $ownBuild). Werk bij zodat rondes en foto\'s synchroon blijven.';
  }

  @override
  String get getUpdate => 'Update halen';

  @override
  String get keepPlaying => 'Blijven spelen';

  @override
  String get connectionLost => 'Verbinding verbroken';

  @override
  String reconnectingIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Nog $seconds seconden.',
      one: 'Nog 1 seconde.',
    );
    return 'Opnieuw verbinden. $_temp0';
  }

  @override
  String get leaveRoom => 'Ruimte verlaten';

  @override
  String get leaveRoomTitle => 'Deze ruimte verlaten?';

  @override
  String get leaveRoomHostBody => 'De ruimte sluit voor iedereen.';

  @override
  String get leaveRoomGuestBody =>
      'Je verlaat de ruimte en kunt opnieuw deelnemen met de QR-code.';

  @override
  String streakLabel(int count) {
    return 'Reeks $count';
  }

  @override
  String get modeClassicBlurb => 'Raad wie de foto nam.';

  @override
  String get modeCaptionThisBlurb => 'Schrijf het grappigste bijschrift.';

  @override
  String get modeTimeTravelerBlurb => 'Raad het jaar en de maand.';

  @override
  String get modeMixedPartyBlurb => 'Alle drie, door elkaar.';

  @override
  String modeSemantic(String label, String blurb) {
    return '$label. $blurb';
  }

  @override
  String get errorNoDatedPhotos =>
      'Geen foto\'s met een datum gevonden. Sta een ander album toe of kies een andere modus.';

  @override
  String get errorNeedAnotherPlayer =>
      'Er moet nog één speler de QR-code scannen voor het spel begint';

  @override
  String get errorPlayersNotReady => 'Iedereen moet eerst op Klaar tikken';

  @override
  String get errorPhotoAccessHost =>
      'Toegang tot foto\'s staat uit. Geef toegang in Instellingen en start dan de fotocheck.';

  @override
  String get errorPhotoAccessClient =>
      'Toegang tot foto\'s staat uit. Geef toegang in Instellingen en tik dan op Nieuwe foto\'s.';

  @override
  String get errorOpenRoom =>
      'De ruimte kon niet worden geopend. Probeer het opnieuw.';

  @override
  String get errorInvalidInvite =>
      'Die uitnodiging is niet geldig. Scan de QR-code opnieuw.';

  @override
  String get errorRelayLimit =>
      'De online relay is vandaag op. Speel verder op dezelfde wifi of een hotspot.';

  @override
  String get errorReachHost =>
      'De host kon niet worden bereikt. Controleer of je op dezelfde wifi of hotspot zit.';

  @override
  String get errorHostEnded =>
      'De host heeft de ruimte beëindigd. Scan een nieuwe QR of start zelf een spel.';

  @override
  String get errorRoomStarted =>
      'Dat spel is al begonnen. Vraag de host om de lobby opnieuw te openen.';

  @override
  String get errorRemovedByHost => 'De host heeft je uit de ruimte verwijderd.';

  @override
  String get errorSomethingWentWrong => 'Er ging iets mis. Probeer opnieuw.';

  @override
  String get errorNoPhotos => 'De host heeft je foto\'s niet ontvangen';

  @override
  String get countdown => 'Aftellen';

  @override
  String countdownSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconden',
      one: '1 seconde',
    );
    return '$_temp0';
  }

  @override
  String get syncingVaults => 'Foto\'s synchroniseren';

  @override
  String syncingVaultsProgress(int received, int total) {
    return '$received van $total foto\'s klaar';
  }

  @override
  String get loadingStartingMatch => 'Spel starten';

  @override
  String get loadingReadingPhotos => 'Je foto\'s lezen';

  @override
  String get loadingJoining => 'Deelnemen';

  @override
  String get errorPlantUsed => 'Je kunt maar één foto per spel planten.';

  @override
  String get errorNotReady => 'Tik op Klaar voor je een foto plant.';

  @override
  String get errorNotPlanter =>
      'Alleen de gekozen speler kan in dit spel een foto planten.';

  @override
  String get errorWrongOwner => 'Die foto is niet van jou.';

  @override
  String get errorNoUnplayedPhoto => 'Elke goedgekeurde foto is al getoond.';

  @override
  String get errorEmptyCaption => 'Schrijf eerst iets.';

  @override
  String get errorCaptionTooLong => 'Houd het bijschrift onder 80 tekens.';

  @override
  String get errorAlreadyGuessed => 'Je gok is al vastgelegd.';

  @override
  String get errorAlreadyVoted => 'Je stem is al vastgelegd.';

  @override
  String get errorAlreadyCaptioned => 'Je bijschrift is al vastgelegd.';

  @override
  String secondsLeftShort(String seconds) {
    return '$seconds s over';
  }

  @override
  String get roundsUnit => 'rondes';

  @override
  String get youreIn => 'Je bent erbij';

  @override
  String get swap => 'Wisselen';

  @override
  String get revealing => 'Onthullen...';

  @override
  String get yours => 'Van jou';

  @override
  String get couldNotOpenLink => 'Deze link kon niet worden geopend.';

  @override
  String get you => 'Jij';

  @override
  String get advancedSettings => 'Geavanceerde instellingen';

  @override
  String get advancedSettingsBody => 'Relay, TURN en eigen hosting.';

  @override
  String get modeMakeItMeme => 'Make It Meme';

  @override
  String get modeMakeItMemeBlurb => 'Maak een meme met de foto van een vriend.';

  @override
  String get paceMemeSubtitle =>
      'Hoeveel tijd krijgt iedereen om een meme te maken?';

  @override
  String get paceFastMeme => 'Snel een meme.';

  @override
  String get paceNormalMeme => 'Tijd om de grap te bouwen.';

  @override
  String get paceSlowMeme => 'Geen haast, maak het goed.';

  @override
  String get memeVaultTitle => 'Je zes foto\'s.';

  @override
  String get memeVaultBody =>
      'Reroll de hele set als er iets niet in het spel mag.';

  @override
  String get memeVaultOnly => 'Alleen deze zes foto\'s komen in het spel.';

  @override
  String get memeVaultReady => 'Klaar';

  @override
  String get memeVaultReroll => 'Alles rerollen';

  @override
  String get memeWritingLabel => 'Bouw de meme';

  @override
  String get memeMatchSwaps => 'Swaps in het spel';

  @override
  String get memeTemplate => 'Template';

  @override
  String get memeTemplateClassic => 'Klassiek';

  @override
  String get memeTemplatePov => 'POV';

  @override
  String get memeTemplateBreaking => 'Breaking';

  @override
  String get memeTemplateLive => 'Live';

  @override
  String get memeTemplatePoster => 'Poster';

  @override
  String get memeTemplateSnap => 'Snapbalk';

  @override
  String get memeTemplateSplit => 'Split';

  @override
  String get memeTopLine => 'Bovenste regel';

  @override
  String get memeBottomLine => 'Onderste regel';

  @override
  String get memeHeader => 'Kop';

  @override
  String get memeHeadline => 'Kop';

  @override
  String get memeReaction => 'Reactie';

  @override
  String get memeTitle => 'Titel';

  @override
  String get memeSubtitle => 'Ondertitel';

  @override
  String get memeBarText => 'Balktekst';

  @override
  String get memeTopPanel => 'Bovenpaneel';

  @override
  String get memeBottomPanel => 'Onderlabel';

  @override
  String get memeWritePrompt => 'Maak de grap.';

  @override
  String get memeSend => 'Meme versturen';

  @override
  String get memeSentWaiting => 'Meme verstuurd. Wachten op de anderen.';

  @override
  String get memeSwapPhoto => 'Foto wisselen';

  @override
  String memeSwapsLeft(int count) {
    return 'Nog $count';
  }

  @override
  String get memeSwapsMatchWide => '5 swaps voor het hele spel.';

  @override
  String get memeVoteTitle => 'Stem op deze meme.';

  @override
  String get memeVoteSubtitle =>
      'Upvote, Meh of Downvote. Je kunt niet op je eigen meme stemmen.';

  @override
  String get memeUpvote => 'Upvote';

  @override
  String get memeMeh => 'Meh';

  @override
  String get memeDownvote => 'Downvote';

  @override
  String get memeAnonymous => 'Anoniem tot de onthulling';

  @override
  String get memeYourMeme => 'Jouw meme';

  @override
  String get memeVoteLocked => 'Stem vastgelegd.';

  @override
  String get memeTapToVote => 'Tik om te stemmen.';

  @override
  String get memeRoundWinner => 'Rondewinnaar';

  @override
  String get memeCreatorPoints => 'Punten maker';

  @override
  String get memeModelRoyalty => 'Modelroyalty';

  @override
  String memeRoyaltyBody(String name) {
    return 'De foto van $name zit in de winnende meme. $name krijgt +25.';
  }

  @override
  String get memeTopMemes => 'Top 3 memes';

  @override
  String get memeFinalRound =>
      'Laatste ronde: iedereen krijgt dezelfde foto. Dubbele punten.';

  @override
  String get memeDownload => 'Meme bewaren';

  @override
  String get memeSaved => 'Meme bewaard.';

  @override
  String get memeSaveFailed => 'De meme kon niet worden bewaard.';

  @override
  String memePhotoFrom(Object name) {
    return 'Foto van $name';
  }

  @override
  String memePoints(int score) {
    return '$score punten';
  }

  @override
  String get memeVotesUp => 'Upvotes';

  @override
  String get memeVotesMeh => 'Meh';

  @override
  String get memeVotesDown => 'Down';

  @override
  String get memeWriteSomething => 'Schrijf eerst iets.';

  @override
  String get music => 'Muziek';

  @override
  String get musicBody => 'Partyloop voor de lobby en rondes';

  @override
  String get soundEffects => 'Geluidseffecten';

  @override
  String get soundEffectsBody => 'Knoppen, stemmen en onthullingen';

  @override
  String get memeHaptics => 'Trilfeedback';

  @override
  String get memeHapticsBody => 'Een tik als er een stem binnenkomt';

  @override
  String get photoLoading => 'Foto laden...';

  @override
  String roundBadge(int current, int total) {
    return 'RONDE $current/$total';
  }

  @override
  String waitingForVotes(int voted, int eligible) {
    return 'Wachten op stemmen: $voted/$eligible gestemd';
  }

  @override
  String get endVoting => 'Stemmen sluiten / AFK overslaan';

  @override
  String get votesAreIn => 'Alle stemmen binnen!';

  @override
  String get countingVotes => 'Stemmen tellen...';

  @override
  String get nextRound => 'Volgende ronde';

  @override
  String get waitingForHostToContinue => 'Wachten tot de host verdergaat...';

  @override
  String get winningMemeTitle => 'Winnende meme van de match';

  @override
  String memeVoteTally(int up, int meh, int down) {
    return '$up op · $meh meh · $down neer';
  }

  @override
  String roundSplash(int round, String mode) {
    return 'RONDE $round: $mode!';
  }

  @override
  String get selfieStickerTitle => 'Jouw sticker';

  @override
  String get selfieStickerBody =>
      'Maak een snelle selfie of kies een stripgezicht.';

  @override
  String get playerVoted => 'Gestemd';

  @override
  String get pickDecade => 'Kies een decennium';

  @override
  String get pickYear => 'Kies een jaar';

  @override
  String get pickMonth => 'Kies een maand';

  @override
  String get actualDate => 'Echte datum';

  @override
  String get yourGuess => 'Jouw gok';

  @override
  String averageMiss(String distance) {
    return 'Gemiddeld ernaast: $distance';
  }

  @override
  String get ownerLabel => 'EIGENAAR';

  @override
  String get breakingNews => 'BREAKING NIEUWS';

  @override
  String get liveBadge => '● LIVE';

  @override
  String get gameFeel => 'Gamegevoel';

  @override
  String get finalTable => 'Eindstand';

  @override
  String get memeNoMemes => 'Geen memes deze ronde.';

  @override
  String get partyPassTitle => 'WhoTook Party Pass';

  @override
  String get partyPassSubtitle =>
      'Eén betaling. Alle feestfuncties, voor altijd.';

  @override
  String get partyPassPerkRelayTitle => '5G- en firewallrelay';

  @override
  String get partyPassPerkRelayBody =>
      'Speel door strikte 5G- en providerfirewalls met onze versleutelde relay, met een eerlijk dagelijks gebruik.';

  @override
  String get partyPassPerkSoundboardTitle => 'Live-soundboard';

  @override
  String get partyPassPerkSoundboardBody =>
      'Laat Airhorn, Vine Boom en meer horen tijdens rondes. Iedereen in de kamer hoort het.';

  @override
  String get partyPassPerkThemesTitle => 'Gedeelde kamerthema\'s';

  @override
  String get partyPassPerkThemesBody =>
      'Kies een premium thema en elke telefoon van je vrienden schakelt mee voor de hele wedstrijd.';

  @override
  String partyPassUnlockButton(String price) {
    return 'Voor altijd ontgrendelen, $price';
  }

  @override
  String get partyPassRestore => 'Aankopen herstellen';

  @override
  String get partyPassRestoreHint => 'Al gekocht? Herstel het op dit toestel.';

  @override
  String get partyPassActiveBadge => 'Party Pass actief';

  @override
  String get partyPassActiveBody =>
      'Relay, soundboard en gedeelde thema\'s zijn op dit toestel ontgrendeld.';

  @override
  String partyPassFairUse(int remaining, int limit) {
    return '$remaining van $limit relaywedstrijden vandaag over';
  }

  @override
  String get partyPassFossIncluded => 'Inbegrepen in deze FOSS-build';

  @override
  String get partyPassFossBody =>
      'Geen winkel, geen tracking. Het soundboard en alle thema\'s zijn gratis, en je kunt de app op je eigen TURN-server richten.';

  @override
  String get partyPassCustomTurn => 'Gebruik je eigen TURN-server';

  @override
  String get partyPassStoreUnavailable =>
      'De winkel is niet beschikbaar in deze build. Herstel je aankopen na installatie via de App Store of Google Play.';

  @override
  String get partyPassPurchasePending =>
      'Wachten op bevestiging van de winkel…';

  @override
  String get partyPassErrorCanceled =>
      'Aankoop geannuleerd. Er is niets afgeschreven.';

  @override
  String get partyPassErrorUnavailable =>
      'De winkel is nu niet beschikbaar. Probeer het zo opnieuw.';

  @override
  String get partyPassErrorProduct =>
      'Het Party Pass-product is nog niet beschikbaar in deze winkel.';

  @override
  String get partyPassErrorRestoreEmpty =>
      'Er is geen eerdere Party Pass-aankoop op dit account gevonden.';

  @override
  String get partyPassErrorGeneric =>
      'Er ging iets mis. Probeer opnieuw of herstel je aankopen.';

  @override
  String get partyPassRelayError =>
      'De relay kon deze aankoop nu niet verifiëren. Direct spelen werkt nog.';

  @override
  String get partyPassTerms => 'Voorwaarden';

  @override
  String get partyPassPrivacy => 'Privacy';

  @override
  String partyPassLobbyButton(String price) {
    return 'Party Pass ($price)';
  }

  @override
  String get partyPassLobbyActive => 'Party Pass actief';

  @override
  String get partyPassLoading => 'Je pass wordt gecontroleerd…';

  @override
  String get roomThemePickerTitle => 'Kamerthema';

  @override
  String get roomThemePickerBody =>
      'Het thema geldt op elke telefoon in deze lobby, voor de hele wedstrijd.';

  @override
  String get roomThemeClassicParty => 'Klassiek feest';

  @override
  String get roomThemeMidnightArcade => 'Midnight Arcade';

  @override
  String get roomThemeCyberNeon => 'Cyber Neon';

  @override
  String get roomThemeRetroPolaroid => 'Retro Polaroid 90s';

  @override
  String get roomThemePubKroeg => 'Kroegmodus';

  @override
  String get roomThemePremium => 'Party Pass';

  @override
  String get roomThemeSelected => 'Geselecteerd';

  @override
  String get roomThemeLocked =>
      'Ontgrendel de Party Pass om dit thema te delen';

  @override
  String get lobbyThemeLabel => 'Thema';

  @override
  String get lobbySoundboardLabel => 'Soundboard';

  @override
  String get lobbyRelayLabel => 'Relay';

  @override
  String get lobbySoundboardOn => 'Klaar';

  @override
  String get lobbySoundboardOff => 'Alleen met pass';

  @override
  String get relayStatusLocal => 'Zelfde wifi';

  @override
  String get relayStatusDirect => 'Direct P2P';

  @override
  String get relayStatusRelay => '5G-relay';

  @override
  String get relayStatusCustom => 'Eigen TURN';

  @override
  String get relayStatusOffline => 'Niet verbonden';

  @override
  String get relayStatusFoss => 'Self-host klaar';

  @override
  String get soundboardTitle => 'Soundboard';

  @override
  String get soundboardHint => 'Tik op een geluid. Iedereen hoort het.';

  @override
  String get soundboardCollapse => 'Soundboard verbergen';

  @override
  String get soundboardExpand => 'Soundboard tonen';

  @override
  String soundboardCooldown(int seconds) {
    return 'Wacht ${seconds}s';
  }

  @override
  String get soundboardLocked => 'Het live-soundboard hoort bij de Party Pass.';

  @override
  String get soundVineBoom => 'Vine Boom';

  @override
  String get soundAirhorn => 'Luchthoorn';

  @override
  String get soundCrickets => 'Krekels';

  @override
  String get soundSadTrombone => 'Treurige trombone';

  @override
  String get soundDrumroll => 'Tromgeroffel';

  @override
  String get soundLaughTrack => 'Lachband';

  @override
  String soundPlayedToast(String name, String sound) {
    return '$name speelde $sound';
  }

  @override
  String get firewallTitle => 'Strikte 5G-firewall gedetecteerd!';

  @override
  String get firewallBody =>
      'Verbind met dezelfde wifi/hotspot om 100% gratis te spelen, of ontgrendel de WhoTook Party Pass (€2,99 eenmalig) voor onze snelle 5G-relayserver.';

  @override
  String get firewallWifiAction => 'Speel via wifi/hotspot';

  @override
  String get firewallUnlockAction => 'Party Pass ontgrendelen';

  @override
  String get firewallFossAction => 'Eigen TURN instellen';

  @override
  String get firewallRelayDownTitle => 'Relay kon niet verbinden';

  @override
  String get firewallRelayDownBody =>
      'Je Party Pass is actief, maar de relay antwoordde niet. Controleer je verbinding en probeer opnieuw.';

  @override
  String get firewallRetryAction => 'Opnieuw proberen';

  @override
  String get fossTurnTitle => 'Eigen TURN-server (self-host)';

  @override
  String get fossTurnBody =>
      'FOSS-builds gebruiken nooit de officiële relay. Richt de app op je eigen coturn-server voor strikte netwerken.';

  @override
  String get fossTurnSaved => 'Eigen TURN opgeslagen';

  @override
  String get fossBuildBadge => 'FOSS-build';

  @override
  String get fossBuildBody =>
      'Geen betalingen, geen analytics, geen officiële relay.';

  @override
  String get settingsPartyPassTitle => 'WhoTook Party Pass';

  @override
  String get settingsPartyPassActive => 'Actief op dit toestel';

  @override
  String get settingsPartyPassInactive =>
      'Relay, soundboard en gedeelde thema\'s';

  @override
  String get errorRelayUnavailable =>
      'De relay is nu niet beschikbaar. Direct spelen werkt nog.';

  @override
  String get roomThemeFree => 'Gratis voor iedereen';

  @override
  String get turnCredentialPairError =>
      'Vul zowel de TURN-gebruikersnaam als het wachtwoord in, of laat beide leeg.';

  @override
  String get firewallQuotaTitle => 'Daglimiet voor relay bereikt';

  @override
  String get firewallQuotaBody =>
      'Je relaytegoed van de Party Pass is op. Het vernieuwt na een rollend venster van 24 uur. Speel via dezelfde wifi/hotspot of stel je eigen TURN-server in.';

  @override
  String get firewallVerificationTitle =>
      'Deze aankoop kon niet worden geverifieerd';

  @override
  String get firewallVerificationBody =>
      'Herstel je aankopen via het Party Pass-venster of neem contact op met support. Direct spelen werkt nog.';

  @override
  String firewallQuotaReset(String time) {
    return 'Volgende tegoed: $time';
  }

  @override
  String get firewallBusyTitle => 'Relay is bezet';

  @override
  String get firewallBusyBody =>
      'Te veel relaypogingen vanaf dit netwerk. Wacht even en probeer opnieuw.';

  @override
  String firewallBusyReset(String time) {
    return 'Probeer opnieuw na $time';
  }

  @override
  String get firewallRetryNow => 'Nu opnieuw';

  @override
  String get errorHostStarting =>
      'De host opent de ruimte nog. Probeer het zo meteen opnieuw.';

  @override
  String get errorInviteExpired =>
      'Deze uitnodiging is verlopen. Vraag de host om een nieuwe QR-code.';
}
