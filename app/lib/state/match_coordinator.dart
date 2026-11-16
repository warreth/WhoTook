import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart' show PermissionState;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/audio/game_audio_service.dart';
import '../core/constants.dart';
import '../core/media/photo_service.dart';
import '../core/models/models.dart';
import '../core/avatars.dart';
import '../core/storage/last_room_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/platform/screenshot_detector.dart';
import '../core/protocol/wire_message.dart';
import '../core/qr/invite_codec.dart';
import '../core/storage/settings_repository.dart';
import '../engine/host_game_engine.dart';
import '../transport/game_transport.dart';
import '../transport/hybrid_connector.dart';
import '../transport/local_ws_transport.dart';
import '../transport/webrtc_transport.dart';

class ScreenshotBanner {
  const ScreenshotBanner({
    required this.playerId,
    required this.playerName,
    required this.atMs,
  });

  final String playerId;
  final String playerName;
  final int atMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'playerId': playerId,
    'playerName': playerName,
    'atMs': atMs,
  };

  factory ScreenshotBanner.fromJson(Map<String, dynamic> json) =>
      ScreenshotBanner(
        playerId: json['playerId'] as String? ?? '',
        playerName: json['playerName'] as String? ?? '',
        atMs: json['atMs'] as int? ?? 0,
      );
}

/// One meme rendered in the local UI. Author and photo owner stay null during
/// voting and are filled only after the reveal.
class MemeCard {
  const MemeCard({
    required this.id,
    required this.photoBase64,
    required this.template,
    required this.topText,
    required this.bottomText,
    required this.snapY,
    this.isOwn = false,
    this.authorName,
    this.photoOwnerName,
    this.upVotes = 0,
    this.mehVotes = 0,
    this.downVotes = 0,
    this.points = 0,
    this.isWinner = false,
  });

  final String id;
  final String photoBase64;
  final MemeTemplate template;
  final String topText;
  final String bottomText;
  final double snapY;
  final bool isOwn;
  final String? authorName;
  final String? photoOwnerName;
  final int upVotes;
  final int mehVotes;
  final int downVotes;
  final int points;
  final bool isWinner;

  MemeCard copyWith({bool? isOwn, bool? isWinner, String? photoBase64}) =>
      MemeCard(
        id: id,
        photoBase64: photoBase64 ?? this.photoBase64,
        template: template,
        topText: topText,
        bottomText: bottomText,
        snapY: snapY,
        isOwn: isOwn ?? this.isOwn,
        authorName: authorName,
        photoOwnerName: photoOwnerName,
        upVotes: upVotes,
        mehVotes: mehVotes,
        downVotes: downVotes,
        points: points,
        isWinner: isWinner ?? this.isWinner,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'photoBase64': photoBase64,
    'template': template.name,
    'topText': topText,
    'bottomText': bottomText,
    'snapY': snapY,
    'isOwn': isOwn,
    'authorName': authorName,
    'photoOwnerName': photoOwnerName,
    'upVotes': upVotes,
    'mehVotes': mehVotes,
    'downVotes': downVotes,
    'points': points,
    'isWinner': isWinner,
  };

  factory MemeCard.fromJson(Map<String, dynamic> json) => MemeCard(
    id: json['id'] as String? ?? '',
    photoBase64: json['photoBase64'] as String? ?? '',
    template: MemeTemplate.values.firstWhere(
      (value) => value.name == json['template'],
      orElse: () => MemeTemplate.classic,
    ),
    topText: json['topText'] as String? ?? '',
    bottomText: json['bottomText'] as String? ?? '',
    snapY: (json['snapY'] as num?)?.toDouble() ?? 48,
    isOwn: json['isOwn'] as bool? ?? false,
    authorName: json['authorName'] as String?,
    photoOwnerName: json['photoOwnerName'] as String?,
    upVotes: json['upVotes'] as int? ?? 0,
    mehVotes: json['mehVotes'] as int? ?? 0,
    downVotes: json['downVotes'] as int? ?? 0,
    points: json['points'] as int? ?? 0,
    isWinner: json['isWinner'] as bool? ?? false,
  );
}

/// Everything the UI renders. Replaced wholesale on every change so widgets can
/// diff cheaply and no screen reaches into mutable engine state.
class MatchUiState {
  const MatchUiState({
    this.isHosting = false,
    this.roomId,
    this.inviteUrl,
    this.localPlayerId,
    this.connectionMode,
    this.phase = RoundPhase.lobby,
    this.players = const <Player>[],
    this.config = const MatchConfig(),
    this.photosNeeded = 0,
    this.candidates = const <PhotoCandidate>[],
    this.localReady = false,
    this.plantUsed = false,
    this.plantUnlocked = false,
    this.plantEligible = false,
    this.currentRound = 0,
    this.totalRounds = 0,
    this.remainingMs = 0,
    this.phaseDurationMs = 0,
    this.activePhotoBytes,
    this.activePhotoIsPanorama = false,
    this.avatarPhotos = const <String, String>{},
    this.activeRoundOptions = const <Player>[],
    this.lockedGuessOwnerId,
    this.lastReveal,
    this.awards = const <MatchAward>[],
    this.screenshotAlerts = const <ScreenshotBanner>[],
    this.extensionSecondsLeft = 0,
    this.extensionCandidates = const <PhotoCandidate>[],
    this.extensionApproved = false,
    this.loadingMessage,
    this.errorMessage,
    this.turnLimitNotice,
    this.hostDeciding = false,
    this.activeMode = GameMode.classic,
    this.captionOptions = const <CaptionOption>[],
    this.ownCaptionId,
    this.votedCaptionId,
    this.captionSubmitted = false,
    this.captionsSubmitted = 0,
    this.votesSubmitted = 0,
    this.lastCaptionReveal,
    this.memeAssignment,
    this.memePhotoBase64,
    this.memeSwapsLeft = 5,
    this.memeSubmitted = false,
    this.memeCards = const <MemeCard>[],
    this.memeVotedIds = const <String>{},
    this.memeSubmissions = 0,
    this.memeVotesSubmitted = 0,
    this.lastMemeReveal,
    this.memeRevealCards = const <MemeCard>[],
    this.topMemes = const <MemeCard>[],
    this.timelineSubmitted = false,
    this.timelineGuesses = 0,
    this.lockedTimelineYear,
    this.lockedTimelineMonth,
    this.lastTimelineReveal,
    this.versionWarning,
    this.versionWarningDismissed = false,
    this.reconnecting = false,
    this.reconnectSecondsLeft = 0,
  });

  final bool isHosting;
  final String? roomId;
  final String? inviteUrl;
  final String? localPlayerId;
  final ConnectionMode? connectionMode;
  final RoundPhase phase;
  final List<Player> players;
  final MatchConfig config;
  final int photosNeeded;
  final List<PhotoCandidate> candidates;
  final bool localReady;
  final bool plantUsed;
  final bool plantUnlocked;
  final bool plantEligible;
  final int currentRound;
  final int totalRounds;
  final int remainingMs;
  final int phaseDurationMs;
  final Uint8List? activePhotoBytes;
  final bool activePhotoIsPanorama;

  /// Player id to a small base64 JPEG avatar. Kept out of Player so the
  /// round payload stays light.
  final Map<String, String> avatarPhotos;
  final List<Player> activeRoundOptions;
  final String? lockedGuessOwnerId;
  final RoundReveal? lastReveal;
  final List<MatchAward> awards;
  final List<ScreenshotBanner> screenshotAlerts;
  final int extensionSecondsLeft;
  final List<PhotoCandidate> extensionCandidates;
  final bool extensionApproved;
  final String? loadingMessage;
  final String? errorMessage;
  final TurnLimitNotice? turnLimitNotice;
  final GameMode activeMode;
  final List<CaptionOption> captionOptions;
  final String? ownCaptionId;
  final String? votedCaptionId;
  final bool captionSubmitted;
  final int captionsSubmitted;
  final int votesSubmitted;
  final CaptionReveal? lastCaptionReveal;
  final MemeAssignment? memeAssignment;
  final String? memePhotoBase64;
  final int memeSwapsLeft;
  final bool memeSubmitted;
  final List<MemeCard> memeCards;
  final Set<String> memeVotedIds;
  final int memeSubmissions;
  final int memeVotesSubmitted;
  final MemeReveal? lastMemeReveal;
  final List<MemeCard> memeRevealCards;
  final List<MemeCard> topMemes;
  final bool timelineSubmitted;
  final int timelineGuesses;
  final int? lockedTimelineYear;
  final int? lockedTimelineMonth;
  final TimelineReveal? lastTimelineReveal;
  final VersionWarning? versionWarning;
  final bool versionWarningDismissed;
  final bool reconnecting;
  final int reconnectSecondsLeft;

  /// True when the host has to choose between the podium and `+5` rounds.
  final bool hostDeciding;

  List<Player> get leaderboard {
    final sorted = List<Player>.of(players)
      ..sort((a, b) => b.score.compareTo(a.score));
    return sorted;
  }

  MatchUiState copyWith({
    bool? isHosting,
    String? roomId,
    String? inviteUrl,
    String? localPlayerId,
    ConnectionMode? connectionMode,
    RoundPhase? phase,
    List<Player>? players,
    MatchConfig? config,
    int? photosNeeded,
    List<PhotoCandidate>? candidates,
    bool? localReady,
    bool? plantUsed,
    bool? plantUnlocked,
    bool? plantEligible,
    int? currentRound,
    int? totalRounds,
    int? remainingMs,
    int? phaseDurationMs,
    Uint8List? activePhotoBytes,
    bool? activePhotoIsPanorama,
    Map<String, String>? avatarPhotos,
    List<Player>? activeRoundOptions,
    String? lockedGuessOwnerId,
    RoundReveal? lastReveal,
    List<MatchAward>? awards,
    List<ScreenshotBanner>? screenshotAlerts,
    int? extensionSecondsLeft,
    List<PhotoCandidate>? extensionCandidates,
    bool? extensionApproved,
    String? loadingMessage,
    String? errorMessage,
    TurnLimitNotice? turnLimitNotice,
    bool? hostDeciding,
    GameMode? activeMode,
    List<CaptionOption>? captionOptions,
    String? ownCaptionId,
    String? votedCaptionId,
    bool? captionSubmitted,
    int? captionsSubmitted,
    int? votesSubmitted,
    CaptionReveal? lastCaptionReveal,
    MemeAssignment? memeAssignment,
    String? memePhotoBase64,
    int? memeSwapsLeft,
    bool? memeSubmitted,
    List<MemeCard>? memeCards,
    Set<String>? memeVotedIds,
    int? memeSubmissions,
    int? memeVotesSubmitted,
    MemeReveal? lastMemeReveal,
    List<MemeCard>? memeRevealCards,
    List<MemeCard>? topMemes,
    bool? timelineSubmitted,
    int? timelineGuesses,
    int? lockedTimelineYear,
    int? lockedTimelineMonth,
    TimelineReveal? lastTimelineReveal,
    VersionWarning? versionWarning,
    bool? versionWarningDismissed,
    bool? reconnecting,
    int? reconnectSecondsLeft,
    bool clearVersionWarning = false,
    bool clearError = false,
    bool clearLoading = false,
    bool clearGuess = false,
    bool clearRoundInput = false,
  }) => MatchUiState(
    isHosting: isHosting ?? this.isHosting,
    roomId: roomId ?? this.roomId,
    inviteUrl: inviteUrl ?? this.inviteUrl,
    localPlayerId: localPlayerId ?? this.localPlayerId,
    connectionMode: connectionMode ?? this.connectionMode,
    phase: phase ?? this.phase,
    players: players ?? this.players,
    config: config ?? this.config,
    photosNeeded: photosNeeded ?? this.photosNeeded,
    candidates: candidates ?? this.candidates,
    localReady: localReady ?? this.localReady,
    plantUsed: plantUsed ?? this.plantUsed,
    plantUnlocked: plantUnlocked ?? this.plantUnlocked,
    plantEligible: plantEligible ?? this.plantEligible,
    currentRound: currentRound ?? this.currentRound,
    totalRounds: totalRounds ?? this.totalRounds,
    remainingMs: remainingMs ?? this.remainingMs,
    phaseDurationMs: phaseDurationMs ?? this.phaseDurationMs,
    activePhotoBytes: activePhotoBytes ?? this.activePhotoBytes,
    activePhotoIsPanorama: activePhotoIsPanorama ?? this.activePhotoIsPanorama,
    avatarPhotos: avatarPhotos ?? this.avatarPhotos,
    activeRoundOptions: activeRoundOptions ?? this.activeRoundOptions,
    lockedGuessOwnerId: clearGuess
        ? null
        : (lockedGuessOwnerId ?? this.lockedGuessOwnerId),
    lastReveal: lastReveal ?? this.lastReveal,
    awards: awards ?? this.awards,
    screenshotAlerts: screenshotAlerts ?? this.screenshotAlerts,
    extensionSecondsLeft: extensionSecondsLeft ?? this.extensionSecondsLeft,
    extensionCandidates: extensionCandidates ?? this.extensionCandidates,
    extensionApproved: extensionApproved ?? this.extensionApproved,
    loadingMessage: clearLoading
        ? null
        : (loadingMessage ?? this.loadingMessage),
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    turnLimitNotice: turnLimitNotice ?? this.turnLimitNotice,
    hostDeciding: hostDeciding ?? this.hostDeciding,
    activeMode: activeMode ?? this.activeMode,
    captionOptions: clearRoundInput
        ? const <CaptionOption>[]
        : (captionOptions ?? this.captionOptions),
    ownCaptionId: clearRoundInput ? null : (ownCaptionId ?? this.ownCaptionId),
    votedCaptionId: clearRoundInput
        ? null
        : (votedCaptionId ?? this.votedCaptionId),
    captionSubmitted: clearRoundInput
        ? false
        : (captionSubmitted ?? this.captionSubmitted),
    captionsSubmitted: clearRoundInput
        ? 0
        : (captionsSubmitted ?? this.captionsSubmitted),
    votesSubmitted: clearRoundInput
        ? 0
        : (votesSubmitted ?? this.votesSubmitted),
    lastCaptionReveal: clearRoundInput
        ? null
        : (lastCaptionReveal ?? this.lastCaptionReveal),
    memeAssignment: clearRoundInput
        ? memeAssignment
        : (memeAssignment ?? this.memeAssignment),
    memePhotoBase64: clearRoundInput
        ? memePhotoBase64
        : (memePhotoBase64 ?? this.memePhotoBase64),
    memeSwapsLeft: clearRoundInput
        ? (memeSwapsLeft ?? 5)
        : (memeSwapsLeft ?? this.memeSwapsLeft),
    memeSubmitted: clearRoundInput
        ? (memeSubmitted ?? false)
        : (memeSubmitted ?? this.memeSubmitted),
    memeCards: clearRoundInput
        ? (memeCards ?? const <MemeCard>[])
        : (memeCards ?? this.memeCards),
    memeVotedIds: clearRoundInput
        ? (memeVotedIds ?? const <String>{})
        : (memeVotedIds ?? this.memeVotedIds),
    memeSubmissions: clearRoundInput
        ? (memeSubmissions ?? 0)
        : (memeSubmissions ?? this.memeSubmissions),
    memeVotesSubmitted: clearRoundInput
        ? (memeVotesSubmitted ?? 0)
        : (memeVotesSubmitted ?? this.memeVotesSubmitted),
    lastMemeReveal: clearRoundInput
        ? null
        : (lastMemeReveal ?? this.lastMemeReveal),
    memeRevealCards: clearRoundInput
        ? (memeRevealCards ?? const <MemeCard>[])
        : (memeRevealCards ?? this.memeRevealCards),
    topMemes: topMemes ?? this.topMemes,
    timelineSubmitted: clearRoundInput
        ? false
        : (timelineSubmitted ?? this.timelineSubmitted),
    timelineGuesses: clearRoundInput
        ? 0
        : (timelineGuesses ?? this.timelineGuesses),
    lockedTimelineYear: clearRoundInput
        ? null
        : (lockedTimelineYear ?? this.lockedTimelineYear),
    lockedTimelineMonth: clearRoundInput
        ? null
        : (lockedTimelineMonth ?? this.lockedTimelineMonth),
    lastTimelineReveal: clearRoundInput
        ? null
        : (lastTimelineReveal ?? this.lastTimelineReveal),
    versionWarning: clearVersionWarning
        ? null
        : (versionWarning ?? this.versionWarning),
    versionWarningDismissed:
        versionWarningDismissed ?? this.versionWarningDismissed,
    reconnecting: reconnecting ?? this.reconnecting,
    reconnectSecondsLeft: reconnectSecondsLeft ?? this.reconnectSecondsLeft,
  );
}

/// Drives a whole match. Host-authoritative: the host owns the engine and the
/// clients only send intents. Both roles share this class so the UI does not
/// branch on `isHosting` for message handling.
class MatchCoordinator {
  MatchCoordinator({
    required this._photos,
    SettingsRepository? settings,
    LastRoomRepository? lastRooms,
    HybridConnector? connector,
    this._hostTransportFactory,
    ScreenshotDetector? screenshots,
    this.random,
    this.includeOnlineTransport = true,
    this.wakeLock,
    this.planterOverride,
    this.appVersion = kAppVersion,
    this.appBuild = kAppBuildNumber,
    this.playerIdOverride,
    this.playerTokenOverride,
    this.reconnectAttemptDelay = Duration.zero,
    Duration? roundDuration,
    this.countdownDuration = const Duration(seconds: 3),
    this.revealDuration = const Duration(seconds: 6),
    this.captionRevealDuration = const Duration(seconds: 10),
    this.timelineRevealDuration = const Duration(seconds: 10),
    this.extendWindow = const Duration(seconds: 10),
  }) : _settings = settings ?? SettingsRepository(),
       _lastRooms = lastRooms ?? LastRoomRepository(),
       _connector = connector ?? HybridConnector(),
       _screenshots = screenshots ?? ScreenshotDetector(),
       _roundDurationOverride = roundDuration;

  final PhotoLibraryService _photos;
  final SettingsRepository _settings;
  final LastRoomRepository _lastRooms;
  final HybridConnector _connector;
  final HostTransport Function(String, String, List<String>)?
  _hostTransportFactory;
  final ScreenshotDetector _screenshots;
  final Random? random;

  /// Off for tests and offline rehearsals; a LAN match never needs the relay.
  final bool includeOnlineTransport;

  /// Injectable in tests so a widget test does not wait on a platform channel.
  final Future<void> Function(bool awake)? wakeLock;

  /// Test seam for the randomly assigned planter.
  final String? planterOverride;

  /// The build this phone reports to the room. Defaults to the release
  /// constants; tests override them to rehearse a mixed-version room.
  final String appVersion;
  final int appBuild;

  /// Test seam for deterministic identities. Production leaves these null.
  final String? playerIdOverride;
  final String? playerTokenOverride;

  /// Tests use a short delay so the reconnecting state is observable.
  final Duration reconnectAttemptDelay;
  final Duration? _roundDurationOverride;
  final Duration countdownDuration;
  final Duration revealDuration;
  final Duration captionRevealDuration;
  final Duration timelineRevealDuration;
  final Duration extendWindow;

  /// The live round length, following the lobby timer once the engine exists.
  Duration get effectiveRoundDuration =>
      _roundDurationOverride ??
      Duration(seconds: _engine?.roundSeconds ?? _state.config.roundSeconds);

  bool get _needsPhotoDates =>
      (_engine?.config ?? _state.config).needsPhotoDates;

  String get _noDatedPhotosMessage => _l10n.errorNoDatedPhotos;

  String _engineError(EngineException error) => _engineCode(error.code);

  String _engineCode(String code) => switch (code) {
    'too_few_players' => _l10n.errorNeedAnotherPlayer,
    'players_not_ready' => _l10n.errorPlayersNotReady,
    'no_photos' => _l10n.errorNoPhotos,
    'plant_used' => _l10n.errorPlantUsed,
    'not_ready' => _l10n.errorNotReady,
    'not_planter' => _l10n.errorNotPlanter,
    'wrong_owner' => _l10n.errorWrongOwner,
    'no_unplayed_photo' => _l10n.errorNoUnplayedPhoto,
    'empty_caption' => _l10n.errorEmptyCaption,
    'caption_too_long' => _l10n.errorCaptionTooLong,
    'already_guessed' => _l10n.errorAlreadyGuessed,
    'already_voted' => _l10n.errorAlreadyVoted,
    'already_captioned' => _l10n.errorAlreadyCaptioned,
    _ => _l10n.errorSomethingWentWrong,
  };

  final StreamController<MatchUiState> _states =
      StreamController<MatchUiState>.broadcast();
  final Map<String, List<PhotoCandidate>> _remotePhotos =
      <String, List<PhotoCandidate>>{};
  final Map<String, Uint8List> _assembledHostBytes = <String, Uint8List>{};
  final Map<String, Uint8List> _clientRoundPhotos = <String, Uint8List>{};
  final Map<String, Uint8List> _memePhotoBytes = <String, Uint8List>{};
  final Map<String, PhotoChunkAssembler> _assemblers =
      <String, PhotoChunkAssembler>{};
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  final List<Timer> _timers = <Timer>[];

  MatchUiState _state = const MatchUiState();
  AppSettings _settingsValue = const AppSettings();
  Locale _locale = const Locale('en');

  AppLocalizations get _l10n => lookupAppLocalizations(_locale);
  HostGameEngine? _engine;
  HostTransport? _hostTransport;
  ClientTransport? _clientTransport;

  Timer? _roundTimer;
  Timer? _countdownTicker;
  Timer? _extendTicker;
  Timer? _captionRevealTimer;
  Timer? _timelineRevealTimer;
  Timer? _clientPhaseTicker;
  Timer? _reconnectTimer;
  Completer<void>? _reconnectAck;
  bool _reconnectInFlight = false;
  bool _hostClosed = false;
  final Map<String, String> _clientPlayerIds = <String, String>{};
  final Map<String, String> _playerClientIds = <String, String>{};
  final Map<String, String> _playerTokens = <String, String>{};
  final Set<String> _blockedPlayers = <String>{};
  final Map<String, String> _avatarPhotos = <String, String>{};
  final Map<String, int> _clientBuilds = <String, int>{};
  final Map<String, String> _clientVersions = <String, String>{};
  final List<StreamSubscription<dynamic>> _clientSubs =
      <StreamSubscription<dynamic>>[];
  String? _pendingInviteUrl;
  String? _pendingRoomId;
  String? _pendingPlayerId;
  String? _pendingPlayerToken;
  String? _currentPlayerId;
  String? _currentPlayerToken;
  bool _endingOnHostLeave = false;
  bool _leaving = false;
  int _roundStartMs = 0;
  int _seq = 0;
  bool _disposed = false;
  bool _roundFinishing = false;

  Stream<MatchUiState> get states => _states.stream;

  MatchUiState get state => _state;

  /// Exposed for integration tests that assert on the authoritative deck.
  @visibleForTesting
  HostGameEngine? get engine => _engine;

  /// Simulates a network drop without ending the room.
  @visibleForTesting
  Future<void> debugDropClientConnection() async {
    await _clientTransport?.close();
  }

  void _emit(MatchUiState next) {
    if (_disposed) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  Future<void> loadSettings() async {
    _settingsValue = await _settings.load();
    _emit(_state.copyWith(config: _state.config));
  }

  /// Keeps the coordinator in sync with the settings screen and onboarding.
  /// Without this, names and excluded albums only reached the repository.
  void updateSettings(AppSettings settings) {
    _settingsValue = settings;
  }

  /// Keeps coordinator errors in the same language as the interface. A
  /// message already on screen is cleared so it cannot stay in the old
  /// language after a switch.
  void updateLocale(Locale locale) {
    if (locale == _locale) return;
    _locale = locale;
    if (_state.errorMessage == null) return;
    scheduleMicrotask(() {
      if (!_disposed) _emit(_state.copyWith(clearError: true));
    });
  }

  Future<void> hostMatch({MatchConfig config = const MatchConfig()}) async {
    _clientPlayerIds.clear();
    _playerClientIds.clear();
    _playerTokens.clear();
    _blockedPlayers.clear();
    _avatarPhotos.clear();
    final ownAvatarPhoto = _settingsValue.avatarPhoto;
    if (ownAvatarPhoto != null && ownAvatarPhoto.isNotEmpty) {
      _avatarPhotos['host'] = ownAvatarPhoto;
    }
    _emit(
      _state.copyWith(
        loadingMessage: _l10n.loadingStartingMatch,
        clearError: true,
      ),
    );
    final roomId = _randomToken(8);
    final secret = _randomToken(24);
    final engine = HostGameEngine(
      config: config,
      random: random == null ? null : Random(random!.nextInt(1 << 32)),
      planterOverride: planterOverride,
    );
    _engine = engine;

    final injected = _hostTransportFactory?.call(roomId, secret, _lanAddresses);
    final local =
        injected ??
        LocalWsHostTransport(
          roomId: roomId,
          secret: secret,
          advertiser: BonsoirMdnsAdvertiser(),
        );

    try {
      await local.start();
    } on Object {
      _emit(
        _state.copyWith(errorMessage: _l10n.errorOpenRoom, clearLoading: true),
      );
      return;
    }

    final lanAddresses = local is LocalWsHostTransport
        ? await local.refreshLanAddresses()
        : const <String>[];
    final lan = <String>[
      if (local.localLanEndpoint != null) local.localLanEndpoint!,
      ...(lanAddresses.isEmpty ? _lanAddresses : lanAddresses).map(
        (address) =>
            '$address:${local is LocalWsHostTransport ? local.port : 0}',
      ),
    ].where((entry) => !entry.endsWith(':0')).toSet().toList();

    final invite = InvitePayload(
      roomId: roomId,
      hostId: 'host',
      secret: secret,
      lanEndpoints: List<String>.unmodifiable(lan),
      signalingUrl: _settings.resolveSignalingUrl(_settingsValue),
    );

    // Online players are optional: when the relay is unreachable or not
    // configured the LAN room must still open.
    final transport =
        injected ??
        CompositeHostTransport(<HostTransport>[
          local,
          if (includeOnlineTransport)
            BestEffortHostTransport(
              WebRtcHostTransport(
                invite: invite,
                iceClient: SignalingIceClient(
                  signalingUrl: invite.signalingUrl!,
                ),
                settings: _settingsValue,
              ),
            ),
        ]);
    _hostTransport = transport;
    _bindHostTransport(transport);
    if (injected == null) {
      await transport.start();
    }

    final player = engine.addPlayer(
      id: 'host',
      name: _displayName,
      avatar: _settingsValue.avatar,
      isHost: true,
    );
    await _startScreenshots();
    await _setAwake(true);

    _emit(
      _state.copyWith(
        isHosting: true,
        roomId: roomId,
        inviteUrl: encodeInviteUrl(invite, baseUrl: kInviteBaseUrl),
        localPlayerId: player.id,
        phase: RoundPhase.lobby,
        players: engine.players,
        avatarPhotos: Map<String, String>.unmodifiable(_avatarPhotos),
        config: config,
        connectionMode: ConnectionMode.localLan,
        clearLoading: true,
      ),
    );
    await _broadcastLobby();
  }

  final List<String> _lanAddresses = const <String>[];

  String _playerIdFor(String clientId) =>
      _clientPlayerIds[clientId] ?? clientId;

  String _clientIdFor(String playerId) =>
      _playerClientIds[playerId] ?? playerId;

  Future<void> _sendToPlayer(String playerId, WireMessage message) async {
    await _hostTransport?.sendToClient(_clientIdFor(playerId), message);
  }

  Future<void> _sendPhotoChunks(
    String clientId,
    String photoId,
    Uint8List? bytes,
  ) async {
    if (bytes == null || bytes.isEmpty) return;
    for (final chunk in PhotoChunker.split(photoId, bytes)) {
      await _hostTransport?.sendToClient(
        clientId,
        WireMessage(
          type: WireType.photoChunk,
          seq: _nextSeq(),
          payload: chunk.toJson(),
        ),
      );
    }
  }

  /// Restores a player who dropped or restarted mid-match. The photo bytes go
  /// first, then one snapshot the client can apply atomically.
  Future<void> _sendRejoinState(String clientId, String playerId) async {
    final engine = _engine;
    if (engine == null) return;
    final player = engine.player(playerId);
    if (player == null) return;
    final phase = _state.phase;
    final entry = engine.currentEntry;
    final activeId = entry?.photo.photoId;
    final activeBytes = entry?.photo.bytes;
    if (activeId != null) {
      await _sendPhotoChunks(clientId, activeId, activeBytes);
    }
    final candidates = _remotePhotos[playerId] ?? const <PhotoCandidate>[];
    for (final candidate in candidates) {
      await _sendPhotoChunks(clientId, candidate.photoId, candidate.bytes);
    }
    final guess = engine.guessFor(playerId);
    final timelineGuess = engine.timelineGuessFor(playerId);
    final plantUnlocked =
        phase == RoundPhase.preparing &&
        player.ready &&
        !player.plantUsed &&
        engine.players.length >= 2 &&
        engine.players.any((other) => !other.ready);
    final payload = <String, dynamic>{
      'phase': phase.name,
      'config': engine.config.toJson(),
      'players': engine.players.map((p) => p.toJson()).toList(),
      'avatarPhotos': _avatarPhotos,
      'currentRound': _state.currentRound,
      'totalRounds': _state.totalRounds,
      'remainingMs': _state.remainingMs,
      'phaseDurationMs': _state.phaseDurationMs,
      'activeMode': _state.activeMode.name,
      'activePhotoId': activeId,
      'activePhotoIsPanorama': entry?.photo.isPanorama ?? false,
      'activeRoundOptions': engine.players.map((p) => p.toJson()).toList(),
      'localReady': player.ready,
      'photosNeeded': engine.photosNeeded,
      'candidates': candidates.map((p) => p.toJson()).toList(),
      'plantUnlocked': plantUnlocked,
      'plantEligible': engine.isPlanter(playerId),
      'plantUsed': player.plantUsed,
      'lockedGuessOwnerId': guess?.guessedOwnerId,
      'memeAssignment': engine.memeAssignmentFor(playerId)?.toJson(),
      'memePhotoBase64': engine.memeAssignmentPhoto(playerId)?.bytes == null
          ? null
          : base64Encode(engine.memeAssignmentPhoto(playerId)!.bytes!),
      'memeSwapsLeft': engine.memeSwapsLeft(playerId),
      'memeSubmitted': engine.hasMeme(playerId),
      'memeCards': phase == RoundPhase.captionVoting
          ? _memeCardsFor(playerId).map((card) => card.toJson()).toList()
          : const <Map<String, dynamic>>[],
      'memeVotedIds': engine.memeVotedIds(playerId).toList(),
      'memeSubmissions': engine.memeCount,
      'memeVotesSubmitted': engine.memeVoteCount,
      'lastMemeReveal': engine.lastMemeReveal?.toJson(),
      'memeRevealCards': phase == RoundPhase.captionReveal
          ? _memeRevealCards().map((card) => card.toJson()).toList()
          : const <Map<String, dynamic>>[],
      'topMemes': _topMemeCards().map((card) => card.toJson()).toList(),
      'captionSubmitted': engine.hasCaption(playerId),
      'captionOptions': phase == RoundPhase.captionVoting
          ? engine.captionOptions.map((option) => option.toJson()).toList()
          : const <Map<String, dynamic>>[],
      'ownCaptionId': engine.captionIdFor(playerId),
      'votedCaptionId': engine.captionVoteFor(playerId),
      'captionsSubmitted': engine.captionCount,
      'votesSubmitted': engine.captionVoteCount,
      'lastReveal': engine.lastReveal?.toJson(),
      'lastCaptionReveal': engine.lastCaptionReveal?.toJson(),
      'lastTimelineReveal': engine.lastTimelineReveal?.toJson(),
      'timelineSubmitted': engine.hasTimelineGuess(playerId),
      'lockedTimelineYear': timelineGuess?.year,
      'lockedTimelineMonth': timelineGuess?.month,
      'awards': _state.awards.map((award) => award.toJson()).toList(),
      'hostDeciding': _state.hostDeciding,
      'screenshotAlerts': _state.screenshotAlerts
          .map((banner) => banner.toJson())
          .toList(),
      'extensionSecondsLeft': _state.extensionSecondsLeft,
      'rejoined': true,
    };
    await _hostTransport?.sendToClient(
      clientId,
      WireMessage(type: WireType.stateSync, seq: _nextSeq(), payload: payload),
    );
  }

  /// Compares every phone's build with the newest one in the room. The host
  /// warns older clients, and shows the same warning when the host is behind.
  Future<void> _sendVersionWarnings() async {
    final builds = <int>[appBuild, ..._clientBuilds.values];
    final latestBuild = builds.reduce(max);
    var latestVersion = appVersion;
    for (final entry in _clientBuilds.entries) {
      if (entry.value != latestBuild) continue;
      final version = _clientVersions[entry.key];
      if (version != null && version.isNotEmpty) {
        latestVersion = version;
        break;
      }
    }
    if (appBuild < latestBuild &&
        _state.versionWarning?.latestBuild != latestBuild) {
      _emit(
        _state.copyWith(
          versionWarning: VersionWarning(
            latestVersion: latestVersion,
            latestBuild: latestBuild,
            ownVersion: appVersion,
            ownBuild: appBuild,
          ),
          versionWarningDismissed: false,
        ),
      );
    }
    final transport = _hostTransport;
    if (transport == null) return;
    for (final entry in _clientBuilds.entries) {
      if (entry.value >= latestBuild) continue;
      await transport.sendToClient(
        _clientIdFor(entry.key),
        WireMessage(
          type: WireType.versionWarning,
          seq: _nextSeq(),
          payload: <String, dynamic>{
            'latestVersion': latestVersion,
            'latestBuild': latestBuild,
          },
        ),
      );
    }
  }

  void _bindHostTransport(HostTransport transport) {
    _subscriptions.add(
      transport.clientConnected.listen((clientId) async {
        await _broadcastLobby();
      }),
    );
    _subscriptions.add(
      transport.clientDisconnected.listen((clientId) async {
        final playerId = _clientPlayerIds.remove(clientId) ?? clientId;
        _playerClientIds.remove(playerId);
        _clientBuilds.remove(playerId);
        _clientVersions.remove(playerId);
        _engine?.removePlayer(playerId);
        final latestBuild = <int>[
          appBuild,
          ..._clientBuilds.values,
        ].reduce(max);
        _emit(
          _state.copyWith(
            players: _engine?.players ?? _state.players,
            clearVersionWarning: latestBuild <= appBuild,
          ),
        );
        await _broadcastLobby();
      }),
    );
    _subscriptions.add(transport.messages.listen(_handleHostMessage));
  }

  Future<void> _handleHostMessage(HostIncomingMessage incoming) async {
    final engine = _engine;
    if (engine == null) return;
    final message = incoming.message;
    final payload = message.payload;
    final clientId = incoming.clientId;

    switch (message.type) {
      case WireType.joinReq:
        final name = (payload['name'] as String?)?.trim();
        if (name == null || name.isEmpty) return;
        final requestedId = (payload['playerId'] as String?)?.trim();
        final playerId = requestedId == null || requestedId.isEmpty
            ? clientId
            : requestedId;
        final token = (payload['playerToken'] as String?)?.trim() ?? '';
        final avatarPhoto = payload['avatarPhoto'] as String?;
        final build = payload['appBuild'];
        final version = payload['appVersion'] as String? ?? '';
        if (_blockedPlayers.contains(playerId)) {
          await _hostTransport?.sendToClient(
            clientId,
            WireMessage(
              type: WireType.kick,
              seq: _nextSeq(),
              payload: <String, dynamic>{'reason': 'removed'},
            ),
          );
          return;
        }
        final existing = engine.player(playerId);

        if (existing != null) {
          final expectedToken = _playerTokens[playerId];
          if (expectedToken != null && token != expectedToken) {
            await _hostTransport?.sendToClient(
              clientId,
              WireMessage(
                type: WireType.kick,
                seq: _nextSeq(),
                payload: <String, dynamic>{'reason': 'identity'},
              ),
            );
            return;
          }
          final oldClientId = _playerClientIds[playerId];
          if (oldClientId != null && oldClientId != clientId) {
            await _hostTransport?.sendToClient(
              oldClientId,
              WireMessage(
                type: WireType.kick,
                seq: _nextSeq(),
                payload: <String, dynamic>{'reason': 'replaced'},
              ),
            );
          }
          _clientPlayerIds[clientId] = playerId;
          _playerClientIds[playerId] = clientId;
          existing.connected = true;
          existing.name = name;
          existing.avatar = normalizeAvatar(payload['avatar'] as String?);
          if (avatarPhoto != null && avatarPhoto.isNotEmpty) {
            _avatarPhotos[playerId] = avatarPhoto;
          }
          if (build is int) {
            _clientBuilds[playerId] = build;
            _clientVersions[playerId] = version;
          }
          _emit(
            _state.copyWith(
              players: engine.players,
              avatarPhotos: Map<String, String>.unmodifiable(_avatarPhotos),
            ),
          );
          await _hostTransport?.sendToClient(
            clientId,
            WireMessage(
              type: WireType.joinAck,
              seq: _nextSeq(),
              payload: <String, dynamic>{'playerId': playerId, 'resumed': true},
            ),
          );
          await _sendRejoinState(clientId, playerId);
          await _sendVersionWarnings();
          return;
        }

        if (engine.phase != RoundPhase.lobby) {
          await _hostTransport?.sendToClient(
            clientId,
            WireMessage(
              type: WireType.kick,
              seq: _nextSeq(),
              payload: <String, dynamic>{'reason': 'started'},
            ),
          );
          return;
        }
        try {
          engine.addPlayer(
            id: playerId,
            name: name,
            avatar: normalizeAvatar(payload['avatar'] as String?),
            avatarColorIndex: payload['avatarColorIndex'] as int? ?? 0,
          );
        } on EngineException {
          return;
        }
        _clientPlayerIds[clientId] = playerId;
        _playerClientIds[playerId] = clientId;
        if (token.isNotEmpty) _playerTokens[playerId] = token;
        if (avatarPhoto != null && avatarPhoto.isNotEmpty) {
          _avatarPhotos[playerId] = avatarPhoto;
        }
        if (build is int) {
          _clientBuilds[playerId] = build;
          _clientVersions[playerId] = version;
        }
        _emit(
          _state.copyWith(
            players: engine.players,
            avatarPhotos: Map<String, String>.unmodifiable(_avatarPhotos),
          ),
        );
        await _hostTransport?.sendToClient(
          clientId,
          WireMessage(
            type: WireType.joinAck,
            seq: _nextSeq(),
            payload: <String, dynamic>{'playerId': playerId, 'resumed': false},
          ),
        );
        await _broadcastLobby();
        await _sendVersionWarnings();
      case WireType.submitPhotoMeta:
        final playerId = _playerIdFor(clientId);
        final photos = <PhotoCandidate>[];
        for (final entry in (payload['photos'] as List<dynamic>? ?? const [])) {
          if (entry is Map<String, dynamic>) {
            photos.add(PhotoCandidate.fromJson(entry));
          }
        }
        _remotePhotos[playerId] = photos;
      case WireType.photoChunk:
        final playerId = _playerIdFor(clientId);
        final chunk = PhotoChunk.fromJson(payload);
        final assembler = _assemblers.putIfAbsent(
          playerId,
          PhotoChunkAssembler.new,
        );
        final bytes = assembler.add(chunk);
        if (bytes != null) {
          _assembledHostBytes['$playerId:${chunk.photoId}'] = bytes;
          final photos = _remotePhotos[playerId];
          if (photos != null) {
            for (var i = 0; i < photos.length; i++) {
              if (photos[i].photoId == chunk.photoId) {
                photos[i] = photos[i].copyWith(bytes: bytes);
              }
            }
          }
        }
      case WireType.playerReady:
        final playerId = _playerIdFor(clientId);
        final approved = _remotePhotos[playerId];
        if (approved == null || approved.isEmpty) {
          await _hostTransport?.sendToClient(
            clientId,
            WireMessage(
              type: WireType.errorNotice,
              seq: _nextSeq(),
              payload: <String, dynamic>{'code': 'no_photos'},
            ),
          );
          return;
        }
        try {
          engine.submitInitialPhotos(playerId, approved);
          engine.markReady(playerId);
        } on EngineException {
          return;
        }
        await _afterReadinessChanged();
        if (engine.phase == RoundPhase.preparing) {
          await _broadcastLobby();
        }
      case WireType.plantPhoto:
        final playerId = _playerIdFor(clientId);
        final photo = PhotoCandidate.fromJson(
          payload['photo'] as Map<String, dynamic>,
        );
        var assembled = _assembledHostBytes['$playerId:${photo.photoId}'];
        if (assembled == null) {
          for (final candidate
              in _remotePhotos[playerId] ?? const <PhotoCandidate>[]) {
            if (candidate.photoId == photo.photoId && candidate.bytes != null) {
              assembled = candidate.bytes;
              break;
            }
          }
        }
        final hydrated = assembled == null
            ? photo
            : photo.copyWith(bytes: assembled);
        try {
          engine.plantSecretPhoto(playerId, hydrated);
          await _hostTransport?.sendToClient(
            clientId,
            WireMessage(
              type: WireType.plantPhoto,
              seq: _nextSeq(),
              payload: <String, dynamic>{'accepted': true},
            ),
          );
        } on EngineException catch (error) {
          await _hostTransport?.sendToClient(
            clientId,
            WireMessage(
              type: WireType.errorNotice,
              seq: _nextSeq(),
              payload: <String, dynamic>{'code': error.code},
            ),
          );
        }
        _emit(_state.copyWith(players: engine.players));
      case WireType.submitGuess:
        final playerId = _playerIdFor(clientId);
        try {
          engine.submitGuess(
            playerId,
            payload['guessedOwnerId'] as String? ?? '',
            payload['elapsedMs'] as int? ?? 0,
          );
        } on EngineException {
          return;
        }
        await _syncGuesses();
      case WireType.screenshotTaken:
        _onRemoteScreenshot(_playerIdFor(clientId), payload);
      case WireType.extendSubmit:
        final playerId = _playerIdFor(clientId);
        final photos = <PhotoCandidate>[];
        for (final entry in (payload['photos'] as List<dynamic>? ?? const [])) {
          if (entry is Map<String, dynamic>) {
            final photo = PhotoCandidate.fromJson(entry);
            final assembled = _assembledHostBytes['$playerId:${photo.photoId}'];
            photos.add(
              assembled == null ? photo : photo.copyWith(bytes: assembled),
            );
          }
        }
        try {
          _engineExtend(photos, playerId);
        } on EngineException {
          return;
        }
        await _maybeCommitExtension();
      case WireType.captionSubmit:
        try {
          engine.submitCaption(
            _playerIdFor(clientId),
            payload['text'] as String? ?? '',
          );
        } on EngineException catch (error) {
          await _hostTransport?.sendToClient(
            clientId,
            WireMessage(
              type: WireType.errorNotice,
              seq: _nextSeq(),
              payload: <String, dynamic>{'code': error.code},
            ),
          );
          return;
        }
        _emit(_state.copyWith(captionsSubmitted: engine.captionCount));
        if (engine.allCaptionsSubmitted) {
          await _startCaptionVoting();
        }
      case WireType.captionVote:
        try {
          engine.submitCaptionVote(
            _playerIdFor(clientId),
            payload['captionId'] as String? ?? '',
          );
        } on EngineException catch (error) {
          await _hostTransport?.sendToClient(
            clientId,
            WireMessage(
              type: WireType.errorNotice,
              seq: _nextSeq(),
              payload: <String, dynamic>{'code': error.code},
            ),
          );
          return;
        }
        _emit(_state.copyWith(votesSubmitted: engine.captionVoteCount));
        if (engine.allCaptionVotesSubmitted) {
          await _finishCaptionRound();
        }
      case WireType.memeSubmit:
        final playerId = _playerIdFor(clientId);
        final templateName = payload['template'] as String?;
        final template = MemeTemplate.values.firstWhere(
          (value) => value.name == templateName,
          orElse: () => MemeTemplate.classic,
        );
        try {
          engine.submitMeme(
            playerId: playerId,
            template: template,
            topText: payload['topText'] as String? ?? '',
            bottomText: payload['bottomText'] as String? ?? '',
            snapY: (payload['snapY'] as num?)?.toDouble() ?? 48,
          );
        } on EngineException catch (error) {
          await _hostTransport?.sendToClient(
            clientId,
            WireMessage(
              type: WireType.errorNotice,
              seq: _nextSeq(),
              payload: <String, dynamic>{'code': error.code},
            ),
          );
          return;
        }
        _emit(
          _state.copyWith(
            memeSubmissions: engine.memeCount,
            memeVotesSubmitted: engine.memeVoteCount,
          ),
        );
        if (engine.allMemesSubmitted) {
          await _startMemeVoting();
        }
      case WireType.memeVote:
        final voteName = payload['vote'] as String?;
        final vote = MemeVote.values.firstWhere(
          (value) => value.name == voteName,
          orElse: () => MemeVote.meh,
        );
        try {
          engine.submitMemeVote(
            playerId: _playerIdFor(clientId),
            memeId: payload['memeId'] as String? ?? '',
            vote: vote,
          );
        } on EngineException catch (error) {
          await _hostTransport?.sendToClient(
            clientId,
            WireMessage(
              type: WireType.errorNotice,
              seq: _nextSeq(),
              payload: <String, dynamic>{'code': error.code},
            ),
          );
          return;
        }
        _emit(_state.copyWith(memeVotesSubmitted: engine.memeVoteCount));
        if (engine.allMemeVotesSubmitted) {
          await _finishMemeRound();
        }
      case WireType.memeSwap:
        try {
          engine.swapMemePhoto(_playerIdFor(clientId));
        } on EngineException catch (error) {
          await _hostTransport?.sendToClient(
            clientId,
            WireMessage(
              type: WireType.errorNotice,
              seq: _nextSeq(),
              payload: <String, dynamic>{'code': error.code},
            ),
          );
          return;
        }
        await _sendMemeAssignment(_playerIdFor(clientId));
      case WireType.timelineSubmit:
        try {
          engine.submitTimelineGuess(
            playerId: _playerIdFor(clientId),
            year: payload['year'] as int? ?? 0,
            month: payload['month'] as int? ?? 0,
            elapsedMs: payload['elapsedMs'] as int? ?? 0,
          );
        } on EngineException catch (error) {
          await _hostTransport?.sendToClient(
            clientId,
            WireMessage(
              type: WireType.errorNotice,
              seq: _nextSeq(),
              payload: <String, dynamic>{'code': error.code},
            ),
          );
          return;
        }
        _emit(_state.copyWith(timelineGuesses: engine.timelineGuessCount));
        if (engine.allTimelineGuessed) {
          await _finishTimelineRound();
        }
      case WireType.ping:
        await _hostTransport?.sendToClient(
          clientId,
          WireMessage(type: WireType.pong, seq: _nextSeq()),
        );
    }
  }

  void _onRemoteScreenshot(String playerId, Map<String, dynamic> payload) {
    final engine = _engine;
    if (engine == null) return;
    engine.recordScreenshot(playerId);
    _rememberScreenshot(playerId, engine);
    unawaited(
      _hostTransport?.broadcast(
        WireMessage(
          type: WireType.screenshotAlert,
          seq: _nextSeq(),
          payload: <String, dynamic>{
            'playerId': playerId,
            'playerName': engine.player(playerId)?.name ?? _l10n.player,
          },
        ),
      ),
    );
  }

  void _rememberScreenshot(String playerId, HostGameEngine engine) {
    final player = engine.player(playerId);
    if (player == null) return;
    final banner = ScreenshotBanner(
      playerId: playerId,
      playerName: player.name,
      atMs: DateTime.now().millisecondsSinceEpoch,
    );
    final alerts = List<ScreenshotBanner>.of(_state.screenshotAlerts)
      ..add(banner);
    _emit(
      _state.copyWith(
        screenshotAlerts: List<ScreenshotBanner>.unmodifiable(
          alerts.length > 8 ? alerts.sublist(alerts.length - 8) : alerts,
        ),
        players: engine.players,
      ),
    );
  }

  Future<void> _afterReadinessChanged() => _maybeStartMatch();

  Future<void> _maybeStartMatch() async {
    final engine = _engine;
    if (engine == null) return;
    _emit(_state.copyWith(players: engine.players));
    final everyoneReady = engine.players.every((p) => p.ready);
    if (!everyoneReady) return;
    try {
      engine.startGame();
    } on EngineException catch (error) {
      _emit(_state.copyWith(errorMessage: _engineError(error)));
      return;
    }
    _emit(
      _state.copyWith(
        phase: RoundPhase.countdown,
        totalRounds: engine.totalRounds,
      ),
    );
    await _enterRoundCountdown();
  }

  /// Shows the between-round countdown, or starts the round at once when the
  /// countdown is disabled (tests and offline rehearsals).
  Future<void> _enterRoundCountdown() async {
    final engine = _engine;
    if (engine == null) return;
    if (countdownDuration <= Duration.zero) {
      await _beginRound();
      return;
    }
    _countdownTicker?.cancel();
    _roundTimer?.cancel();
    final nextRound = engine.currentRound + 1;
    final total = engine.totalRounds;
    final ms = countdownDuration.inMilliseconds;

    _emit(
      _state.copyWith(
        phase: RoundPhase.countdown,
        currentRound: nextRound,
        totalRounds: total,
        remainingMs: ms,
        clearGuess: true,
        lockedGuessOwnerId: null,
      ),
    );
    await _hostTransport?.broadcast(
      WireMessage(
        type: WireType.roundCountdown,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'roundNumber': nextRound,
          'totalRounds': total,
          'durationMs': ms,
        },
      ),
    );

    final startedAt = DateTime.now().millisecondsSinceEpoch;
    _countdownTicker = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      final engine = _engine;
      if (_disposed ||
          engine == null ||
          _state.phase != RoundPhase.countdown ||
          engine.phase != RoundPhase.countdown) {
        timer.cancel();
        return;
      }
      final elapsed = DateTime.now().millisecondsSinceEpoch - startedAt;
      final remaining = (ms - elapsed).clamp(0, ms);
      _emit(_state.copyWith(remainingMs: remaining));
      if (remaining <= 0) {
        timer.cancel();
        unawaited(_beginRound());
      }
    });
  }

  Future<void> _beginRound() async {
    final engine = _engine;
    final transport = _hostTransport;
    if (engine == null || transport == null) return;
    final entry = engine.startRound();
    _roundFinishing = false;
    _roundStartMs = DateTime.now().millisecondsSinceEpoch;

    final bytes = entry.photo.bytes;
    final isMemeRound = entry.mode == GameMode.makeItMeme;
    if (!isMemeRound && bytes != null) {
      for (final chunk in PhotoChunker.split(entry.photo.photoId, bytes)) {
        await transport.broadcast(
          WireMessage(
            type: WireType.photoChunk,
            seq: _nextSeq(),
            payload: chunk.toJson(),
          ),
        );
      }
    }

    final mode = entry.mode;
    final pace = engine.config.pace;
    final duration = switch (mode) {
      GameMode.classic || GameMode.mixedParty => effectiveRoundDuration,
      GameMode.captionThis => Duration(seconds: pace.captionSeconds),
      GameMode.makeItMeme => Duration(seconds: pace.memeSeconds),
      GameMode.timeTraveler => Duration(seconds: pace.timelineSeconds),
    };
    await transport.broadcast(
      WireMessage(
        type: WireType.roundShow,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'mode': mode.name,
          'roundNumber': entry.roundNumber,
          'totalRounds': engine.totalRounds,
          'photoId': entry.photo.photoId,
          'isPanorama': entry.photo.isPanorama,
          'durationMs': duration.inMilliseconds,
          'options': engine.players.map((p) => p.toJson()).toList(),
        },
      ),
    );

    _emit(
      _state.copyWith(
        phase: engine.phase,
        activeMode: mode,
        currentRound: entry.roundNumber,
        totalRounds: engine.totalRounds,
        activePhotoBytes: bytes,
        activePhotoIsPanorama: entry.photo.isPanorama,
        activeRoundOptions: engine.players,
        remainingMs: duration.inMilliseconds,
        phaseDurationMs: duration.inMilliseconds,
        clearGuess: true,
        clearRoundInput: true,
        lockedGuessOwnerId: null,
      ),
    );

    _roundTimer?.cancel();
    _roundTimer = Timer(duration, () {
      switch (mode) {
        case GameMode.classic || GameMode.mixedParty:
          unawaited(_finishRound());
        case GameMode.captionThis:
          unawaited(_startCaptionVoting());
        case GameMode.makeItMeme:
          unawaited(_startMemeVoting());
        case GameMode.timeTraveler:
          unawaited(_finishTimelineRound());
      }
    });
    _tickPhaseProgress(duration, engine.phase);
    if (isMemeRound) {
      for (final player in engine.players) {
        if (!player.connected) continue;
        await _sendMemeAssignment(player.id);
      }
    }
  }

  void _tickPhaseProgress(Duration duration, RoundPhase phase) {
    _countdownTicker?.cancel();
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    _countdownTicker = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (_disposed || _state.phase != phase) {
        timer.cancel();
        return;
      }
      final elapsed = DateTime.now().millisecondsSinceEpoch - startedAt;
      final remaining = (duration.inMilliseconds - elapsed).clamp(
        0,
        duration.inMilliseconds,
      );
      _emit(_state.copyWith(remainingMs: remaining));
      final engine = _engine;
      if (engine == null) return;
      switch (phase) {
        case RoundPhase.guessing:
          if (engine.allGuessed) {
            timer.cancel();
            unawaited(_finishRound());
          }
        case RoundPhase.captionWriting:
          final ready = engine.activeMode == GameMode.makeItMeme
              ? engine.allMemesSubmitted
              : engine.allCaptionsSubmitted;
          if (ready) {
            timer.cancel();
            if (engine.activeMode == GameMode.makeItMeme) {
              unawaited(_startMemeVoting());
            } else {
              unawaited(_startCaptionVoting());
            }
          }
        case RoundPhase.captionVoting:
          final ready = engine.activeMode == GameMode.makeItMeme
              ? engine.allMemeVotesSubmitted
              : engine.allCaptionVotesSubmitted;
          if (ready) {
            timer.cancel();
            if (engine.activeMode == GameMode.makeItMeme) {
              unawaited(_finishMemeRound());
            } else {
              unawaited(_finishCaptionRound());
            }
          }
        case RoundPhase.timelineGuessing:
          if (engine.allTimelineGuessed) {
            timer.cancel();
            unawaited(_finishTimelineRound());
          }
        default:
          break;
      }
    });
  }

  Uint8List? _photoBytesFor(String photoId) {
    final cached = _memePhotoBytes[photoId];
    if (cached != null && cached.isNotEmpty) return cached;
    final client = _clientRoundPhotos[photoId];
    if (client != null && client.isNotEmpty) {
      _memePhotoBytes[photoId] = client;
      return client;
    }
    for (final entry in _assembledHostBytes.entries) {
      if (entry.key.endsWith(':$photoId') && entry.value.isNotEmpty) {
        _memePhotoBytes[photoId] = entry.value;
        return entry.value;
      }
    }
    for (final photos in _remotePhotos.values) {
      for (final photo in photos) {
        if (photo.photoId == photoId && photo.bytes != null) {
          _memePhotoBytes[photoId] = photo.bytes!;
          return photo.bytes;
        }
      }
    }
    final engine = _engine;
    if (engine != null) {
      for (final player in engine.players) {
        final photo = engine.memeAssignmentPhoto(player.id);
        if (photo?.photoId == photoId && photo?.bytes != null) {
          _memePhotoBytes[photoId] = photo!.bytes!;
          return photo.bytes;
        }
      }
    }
    return null;
  }

  List<MemeCard> _memeCardsFor(String playerId) {
    final engine = _engine;
    if (engine == null) return const <MemeCard>[];
    return List<MemeCard>.unmodifiable(
      engine.memeOptions.map((option) {
        final photo = _photoBytesFor(option.photoId);
        if (photo != null) _memePhotoBytes[option.photoId] = photo;
        return MemeCard(
          id: option.id,
          photoBase64: photo == null ? '' : base64Encode(photo),
          template: option.template,
          topText: option.topText,
          bottomText: option.bottomText,
          snapY: option.snapY,
          isOwn: engine.isOwnMeme(playerId, option.id),
        );
      }),
    );
  }

  List<MemeCard> _memeRevealCards() {
    final engine = _engine;
    final reveal = engine?.lastMemeReveal;
    if (engine == null || reveal == null) return const <MemeCard>[];
    return List<MemeCard>.unmodifiable(
      reveal.entries.map((entry) {
        final photo = _photoBytesFor(entry.photoId);
        if (photo != null) _memePhotoBytes[entry.photoId] = photo;
        return MemeCard(
          id: entry.id,
          photoBase64: photo == null ? '' : base64Encode(photo),
          template: entry.template,
          topText: entry.topText,
          bottomText: entry.bottomText,
          snapY: entry.snapY,
          authorName: entry.authorName,
          photoOwnerName: entry.photoOwnerName,
          upVotes: entry.upVotes,
          mehVotes: entry.mehVotes,
          downVotes: entry.downVotes,
          points: entry.points,
          isWinner: reveal.winnerIds.contains(entry.id),
        );
      }),
    );
  }

  List<MemeCard> _topMemeCards() {
    final engine = _engine;
    if (engine == null) return const <MemeCard>[];
    return List<MemeCard>.unmodifiable(
      engine.topMemes.map((entry) {
        final photo = _photoBytesFor(entry.photoId);
        if (photo != null) _memePhotoBytes[entry.photoId] = photo;
        return MemeCard(
          id: entry.id,
          photoBase64: photo == null ? '' : base64Encode(photo),
          template: entry.template,
          topText: entry.topText,
          bottomText: entry.bottomText,
          snapY: entry.snapY,
          authorName: entry.authorName,
          photoOwnerName: entry.photoOwnerName,
          upVotes: entry.upVotes,
          mehVotes: entry.mehVotes,
          downVotes: entry.downVotes,
          points: entry.points,
          isWinner: true,
        );
      }),
    );
  }

  Future<void> _sendMemeAssignment(String playerId) async {
    final engine = _engine;
    if (engine == null) return;
    final assignment = engine.memeAssignmentFor(playerId);
    if (assignment == null) return;
    final bytes = _photoBytesFor(assignment.photoId);
    if (bytes != null) _memePhotoBytes[assignment.photoId] = bytes;
    final payload = <String, dynamic>{
      'assignment': assignment.toJson(),
      'photoBase64': bytes == null ? '' : base64Encode(bytes),
      'swapsLeft': engine.memeSwapsLeft(playerId),
    };
    if (playerId == 'host') {
      _emit(
        _state.copyWith(
          memeAssignment: assignment,
          memePhotoBase64: bytes == null ? null : base64Encode(bytes),
          memeSwapsLeft: engine.memeSwapsLeft(playerId),
          memeSubmitted: engine.hasMeme(playerId),
          memeSubmissions: engine.memeCount,
          memeVotesSubmitted: engine.memeVoteCount,
          clearError: true,
        ),
      );
      return;
    }
    await _sendToPlayer(
      playerId,
      WireMessage(
        type: WireType.memeAssignment,
        seq: _nextSeq(),
        payload: payload,
      ),
    );
  }

  Future<void> _sendMemeOptions(String playerId) async {
    final engine = _engine;
    if (engine == null) return;
    final cards = _memeCardsFor(playerId);
    final payload = <String, dynamic>{
      'cards': cards.map((card) => card.toJson()).toList(),
      'votedIds': engine.memeVotedIds(playerId).toList(),
      'submissions': engine.memeCount,
      'votes': engine.memeVoteCount,
      'durationMs': 0,
    };
    if (playerId == 'host') {
      _emit(
        _state.copyWith(
          phase: RoundPhase.captionVoting,
          activeMode: GameMode.makeItMeme,
          memeCards: cards,
          memeVotedIds: engine.memeVotedIds(playerId),
          memeSubmissions: engine.memeCount,
          memeVotesSubmitted: engine.memeVoteCount,
          remainingMs: 0,
          phaseDurationMs: 0,
          clearError: true,
        ),
      );
      return;
    }
    await _sendToPlayer(
      playerId,
      WireMessage(
        type: WireType.memeOptions,
        seq: _nextSeq(),
        payload: payload,
      ),
    );
  }

  Future<void> _startMemeVoting() async {
    final engine = _engine;
    if (engine == null || engine.phase != RoundPhase.captionWriting) return;
    _roundTimer?.cancel();
    _countdownTicker?.cancel();
    if (engine.memeCount < 2) {
      await _finishMemeRound();
      return;
    }
    try {
      engine.beginMemeVoting();
    } on EngineException {
      return;
    }
    for (final player in engine.players) {
      if (!player.connected) continue;
      await _sendMemeOptions(player.id);
    }
  }

  Future<void> _finishMemeRound() async {
    final engine = _engine;
    if (engine == null) return;
    if (engine.phase != RoundPhase.captionWriting &&
        engine.phase != RoundPhase.captionVoting) {
      return;
    }
    _roundTimer?.cancel();
    _countdownTicker?.cancel();
    final reveal = engine.finishMemeRound();
    unawaited(GameAudioService.instance.fanfare());
    unawaited(GameHaptics.instance.heavy());
    final cards = _memeRevealCards();
    final topMemes = _topMemeCards();
    await _hostTransport?.broadcast(
      WireMessage(
        type: WireType.memeReveal,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          ...reveal.toJson(),
          'cards': cards.map((card) => card.toJson()).toList(),
          'players': engine.players.map((player) => player.toJson()).toList(),
          'topMemes': topMemes.map((card) => card.toJson()).toList(),
        },
      ),
    );
    _emit(
      _state.copyWith(
        phase: RoundPhase.captionReveal,
        activeMode: GameMode.makeItMeme,
        lastMemeReveal: reveal,
        memeRevealCards: cards,
        memeCards: const <MemeCard>[],
        memeVotedIds: const <String>{},
        memeSubmissions: engine.memeCount,
        memeVotesSubmitted: engine.memeVoteCount,
        players: engine.players,
        topMemes: _topMemeCards(),
        remainingMs: 0,
      ),
    );
    _captionRevealTimer?.cancel();
    _captionRevealTimer = Timer(
      captionRevealDuration,
      () => unawaited(_advanceAfterReveal()),
    );
  }

  Future<void> submitMeme({
    required MemeTemplate template,
    required String topText,
    required String bottomText,
    required double snapY,
  }) async {
    final engine = _engine;
    if (engine == null) return;
    try {
      engine.submitMeme(
        playerId: 'host',
        template: template,
        topText: topText,
        bottomText: bottomText,
        snapY: snapY,
      );
    } on EngineException catch (error) {
      _emit(_state.copyWith(errorMessage: _engineError(error)));
      return;
    }
    unawaited(GameAudioService.instance.pop());
    unawaited(GameHaptics.instance.selection());
    _emit(
      _state.copyWith(
        memeSubmitted: true,
        memeSubmissions: engine.memeCount,
        memeVotesSubmitted: engine.memeVoteCount,
        clearError: true,
      ),
    );
    if (engine.allMemesSubmitted) await _startMemeVoting();
  }

  Future<void> clientSubmitMeme({
    required MemeTemplate template,
    required String topText,
    required String bottomText,
    required double snapY,
  }) async {
    await _clientTransport?.send(
      WireMessage(
        type: WireType.memeSubmit,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'template': template.name,
          'topText': topText,
          'bottomText': bottomText,
          'snapY': snapY,
        },
      ),
    );
    unawaited(GameAudioService.instance.pop());
    _emit(_state.copyWith(memeSubmitted: true));
  }

  Future<void> swapMemePhoto() async {
    final engine = _engine;
    if (engine == null) return;
    try {
      engine.swapMemePhoto('host');
    } on EngineException catch (error) {
      _emit(_state.copyWith(errorMessage: _engineError(error)));
      return;
    }
    await _sendMemeAssignment('host');
    unawaited(GameAudioService.instance.pop());
    unawaited(GameHaptics.instance.selection());
  }

  Future<void> clientSwapMemePhoto() async {
    await _clientTransport?.send(
      WireMessage(type: WireType.memeSwap, seq: _nextSeq()),
    );
    unawaited(GameAudioService.instance.pop());
  }

  Future<void> voteMeme(String memeId, MemeVote vote) async {
    final engine = _engine;
    if (engine == null || _state.memeVotedIds.contains(memeId)) return;
    try {
      engine.submitMemeVote(playerId: 'host', memeId: memeId, vote: vote);
    } on EngineException catch (error) {
      _emit(_state.copyWith(errorMessage: _engineError(error)));
      return;
    }
    final voted = <String>{..._state.memeVotedIds, memeId};
    unawaited(
      vote == MemeVote.up
          ? GameAudioService.instance.ding()
          : vote == MemeVote.meh
          ? GameAudioService.instance.meh()
          : GameAudioService.instance.bad(),
    );
    unawaited(GameHaptics.instance.selection());
    _emit(
      _state.copyWith(
        memeVotedIds: voted,
        memeVotesSubmitted: engine.memeVoteCount,
        clearError: true,
      ),
    );
    if (engine.allMemeVotesSubmitted) await _finishMemeRound();
  }

  Future<void> clientVoteMeme(String memeId, MemeVote vote) async {
    if (_state.memeVotedIds.contains(memeId)) return;
    await _clientTransport?.send(
      WireMessage(
        type: WireType.memeVote,
        seq: _nextSeq(),
        payload: <String, dynamic>{'memeId': memeId, 'vote': vote.name},
      ),
    );
    unawaited(
      vote == MemeVote.up
          ? GameAudioService.instance.ding()
          : vote == MemeVote.meh
          ? GameAudioService.instance.meh()
          : GameAudioService.instance.bad(),
    );
    unawaited(GameHaptics.instance.selection());
    _emit(
      _state.copyWith(memeVotedIds: <String>{..._state.memeVotedIds, memeId}),
    );
  }

  Future<void> _startCaptionVoting() async {
    final engine = _engine;
    if (engine == null || engine.phase != RoundPhase.captionWriting) return;
    if (engine.activeMode == GameMode.makeItMeme) {
      await _startMemeVoting();
      return;
    }
    _roundTimer?.cancel();
    _countdownTicker?.cancel();
    if (engine.captionCount < 2) {
      await _finishCaptionRound();
      return;
    }
    try {
      engine.beginCaptionVoting();
    } on EngineException {
      return;
    }
    final options = engine.captionOptions;
    _emit(
      _state.copyWith(
        phase: RoundPhase.captionVoting,
        captionOptions: options,
        ownCaptionId: engine.captionIdFor('host'),
        votedCaptionId: null,
        remainingMs: 0,
        phaseDurationMs: 0,
        captionsSubmitted: engine.captionCount,
        clearError: true,
      ),
    );
    for (final player in engine.players) {
      if (!player.connected || player.id == 'host') continue;
      await _sendToPlayer(
        player.id,
        WireMessage(
          type: WireType.captionOptions,
          seq: _nextSeq(),
          payload: <String, dynamic>{
            'captions': options.map((option) => option.toJson()).toList(),
            'ownId': engine.captionIdFor(player.id),
            'durationMs': 0,
          },
        ),
      );
    }
  }

  Future<void> _finishCaptionRound() async {
    final engine = _engine;
    if (engine == null) return;
    if (engine.activeMode == GameMode.makeItMeme) {
      await _finishMemeRound();
      return;
    }
    if (engine.phase != RoundPhase.captionWriting &&
        engine.phase != RoundPhase.captionVoting) {
      return;
    }
    _roundTimer?.cancel();
    _countdownTicker?.cancel();
    final reveal = engine.finishCaptionRound();
    unawaited(GameHaptics.instance.light());
    await _hostTransport?.broadcast(
      WireMessage(
        type: WireType.captionReveal,
        seq: _nextSeq(),
        payload: reveal.toJson(),
      ),
    );
    _emit(
      _state.copyWith(
        phase: RoundPhase.captionReveal,
        lastCaptionReveal: reveal,
        players: engine.players,
        captionOptions: const <CaptionOption>[],
        remainingMs: 0,
      ),
    );
    _captionRevealTimer?.cancel();
    _captionRevealTimer = Timer(
      captionRevealDuration,
      () => unawaited(_advanceAfterReveal()),
    );
  }

  Future<void> _finishTimelineRound() async {
    final engine = _engine;
    if (engine == null || engine.phase != RoundPhase.timelineGuessing) return;
    _roundTimer?.cancel();
    _countdownTicker?.cancel();
    final reveal = engine.finishTimelineRound(
      durationMs: _state.phaseDurationMs > 0
          ? _state.phaseDurationMs
          : Duration(seconds: engine.config.pace.timelineSeconds)
                .inMilliseconds,
    );
    unawaited(GameHaptics.instance.light());
    await _hostTransport?.broadcast(
      WireMessage(
        type: WireType.timelineReveal,
        seq: _nextSeq(),
        payload: reveal.toJson(),
      ),
    );
    _emit(
      _state.copyWith(
        phase: RoundPhase.timelineReveal,
        lastTimelineReveal: reveal,
        players: engine.players,
        remainingMs: 0,
      ),
    );
    _timelineRevealTimer?.cancel();
    _timelineRevealTimer = Timer(
      timelineRevealDuration,
      () => unawaited(_advanceAfterReveal()),
    );
  }

  Future<void> submitCaption(String text) async {
    final engine = _engine;
    if (engine == null) return;
    try {
      engine.submitCaption('host', text);
    } on EngineException catch (error) {
      _emit(_state.copyWith(errorMessage: _engineError(error)));
      return;
    }
    unawaited(GameHaptics.instance.selection());
    unawaited(GameAudioService.instance.tap());
    _emit(
      _state.copyWith(
        captionSubmitted: true,
        captionsSubmitted: engine.captionCount,
        clearError: true,
      ),
    );
    if (engine.allCaptionsSubmitted) {
      await _startCaptionVoting();
    }
  }

  Future<void> voteCaption(String captionId) async {
    final engine = _engine;
    if (engine == null || _state.votedCaptionId != null) return;
    try {
      engine.submitCaptionVote('host', captionId);
    } on EngineException catch (error) {
      _emit(_state.copyWith(errorMessage: _engineError(error)));
      return;
    }
    unawaited(GameHaptics.instance.selection());
    _emit(
      _state.copyWith(
        votedCaptionId: captionId,
        votesSubmitted: engine.captionVoteCount,
        clearError: true,
      ),
    );
    if (engine.allCaptionVotesSubmitted) {
      await _finishCaptionRound();
    }
  }

  Future<void> submitTimeline(int year, int month) async {
    final engine = _engine;
    if (engine == null || _state.timelineSubmitted) return;
    final elapsed = DateTime.now().millisecondsSinceEpoch - _roundStartMs;
    try {
      engine.submitTimelineGuess(
        playerId: 'host',
        year: year,
        month: month,
        elapsedMs: elapsed,
      );
    } on EngineException catch (error) {
      _emit(_state.copyWith(errorMessage: _engineError(error)));
      return;
    }
    unawaited(GameHaptics.instance.selection());
    unawaited(GameAudioService.instance.tap());
    _emit(
      _state.copyWith(
        timelineSubmitted: true,
        lockedTimelineYear: year,
        lockedTimelineMonth: month,
        clearError: true,
      ),
    );
    if (engine.allTimelineGuessed) {
      await _finishTimelineRound();
    }
  }

  Future<void> _syncGuesses() async {
    final engine = _engine;
    if (engine == null) return;
    _emit(_state.copyWith(players: engine.players));
    if (engine.allGuessed) {
      await _finishRound();
    }
  }

  Future<void> _finishRound() async {
    final engine = _engine;
    if (engine == null || _roundFinishing) return;
    if (engine.phase != RoundPhase.guessing) return;
    _roundFinishing = true;
    _roundTimer?.cancel();
    _countdownTicker?.cancel();
    final reveal = engine.finishRound();
    unawaited(GameHaptics.instance.light());
    await _hostTransport?.broadcast(
      WireMessage(
        type: WireType.roundReveal,
        seq: _nextSeq(),
        payload: reveal.toJson(),
      ),
    );
    _emit(
      _state.copyWith(
        phase: RoundPhase.reveal,
        lastReveal: reveal,
        players: engine.players,
        activePhotoBytes: _state.activePhotoBytes,
      ),
    );
    _timers.add(Timer(revealDuration, () => unawaited(_advanceAfterReveal())));
  }

  Future<void> _advanceAfterReveal() async {
    final engine = _engine;
    if (engine == null) return;
    engine.advanceAfterReveal();
    if (engine.phase == RoundPhase.podium) {
      final awards = engine.buildPodiumAwards();
      final topMemes = _topMemeCards();
      await _hostTransport?.broadcast(
        WireMessage(
          type: WireType.gamePodium,
          seq: _nextSeq(),
          payload: <String, dynamic>{
            'awards': awards.map((a) => a.toJson()).toList(),
            'players': engine.players.map((p) => p.toJson()).toList(),
            'topMemes': topMemes.map((card) => card.toJson()).toList(),
          },
        ),
      );
      _emit(
        _state.copyWith(
          phase: RoundPhase.podium,
          awards: awards,
          players: engine.players,
          hostDeciding: true,
          activePhotoBytes: null,
          topMemes: topMemes,
        ),
      );
      return;
    }
    _emit(_state.copyWith(phase: RoundPhase.countdown));
    await _enterRoundCountdown();
  }

  Future<void> setMode(GameMode mode) async {
    final engine = _engine;
    if (engine == null) {
      if (mode == _state.config.mode) return;
      _emit(
        _state.copyWith(
          config: _state.config.copyWith(
            mode: mode,
            roundSeconds: _state.config.pace.mainSeconds(mode),
          ),
          candidates: const <PhotoCandidate>[],
        ),
      );
      return;
    }
    try {
      engine.setMode(mode);
    } on EngineException {
      return;
    }
    _emit(_state.copyWith(config: engine.config, clearError: true));
    await _broadcastLobby();
  }

  Future<void> setRounds(int rounds) async {
    final engine = _engine;
    if (engine == null) {
      if (rounds < 1 || rounds == _state.config.roundsK) return;
      _emit(
        _state.copyWith(
          config: _state.config.copyWith(roundsK: rounds),
          candidates: const <PhotoCandidate>[],
        ),
      );
      return;
    }
    try {
      engine.setRoundsK(rounds);
    } on EngineException {
      return;
    }
    _emit(_state.copyWith(config: engine.config, players: engine.players));
    await _broadcastLobby();
  }

  Future<void> setRoundSeconds(int seconds) async {
    final engine = _engine;
    if (engine == null) {
      if (seconds < 1) return;
      _emit(
        _state.copyWith(config: _state.config.copyWith(roundSeconds: seconds)),
      );
      return;
    }
    try {
      engine.setRoundSeconds(seconds);
    } on EngineException {
      return;
    }
    _emit(_state.copyWith(config: engine.config));
    await _broadcastLobby();
  }

  /// Removes a connected player from the lobby. The host can use this to
  /// stop harassment without ending the whole room.
  Future<void> kickPlayer(String playerId) async {
    final engine = _engine;
    if (engine == null || playerId == 'host') return;
    await _sendToPlayer(
      playerId,
      WireMessage(
        type: WireType.kick,
        seq: _nextSeq(),
        payload: <String, dynamic>{'reason': 'removed'},
      ),
    );
    _blockedPlayers.add(playerId);
    _playerTokens.remove(playerId);
    _avatarPhotos.remove(playerId);
    final clientId = _playerClientIds.remove(playerId);
    if (clientId != null) _clientPlayerIds.remove(clientId);
    engine.removePlayer(playerId);
    _remotePhotos.remove(playerId);
    _emit(_state.copyWith(players: engine.players));
    await _broadcastLobby();
  }

  Future<void> setPace(GamePace pace) async {
    final engine = _engine;
    if (engine == null) {
      _emit(
        _state.copyWith(
          config: _state.config.copyWith(
            pace: pace,
            roundSeconds: pace.mainSeconds(_state.config.mode),
          ),
        ),
      );
      return;
    }
    try {
      engine.setPace(pace);
    } on EngineException {
      return;
    }
    _emit(_state.copyWith(config: engine.config, clearError: true));
    await _broadcastLobby();
  }

  /// Host opens the prepare phase and draws its own candidates.
  Future<void> startPrepare() async {
    final engine = _engine;
    if (engine == null) return;
    final permission = await _photos.requestPermission();
    if (permission == PermissionState.denied) {
      _emit(_state.copyWith(errorMessage: _l10n.errorPhotoAccessHost));
      return;
    }
    try {
      engine.startPrepare();
    } on EngineException catch (error) {
      _emit(_state.copyWith(errorMessage: _engineError(error)));
      return;
    }
    _emit(
      _state.copyWith(
        phase: RoundPhase.preparing,
        photosNeeded: engine.photosNeeded,
        plantEligible: engine.isPlanter('host'),
        loadingMessage: _l10n.loadingReadingPhotos,
        clearError: true,
      ),
    );
    await _hostTransport?.broadcast(
      WireMessage(
        type: WireType.startPrepare,
        seq: _nextSeq(),
        payload: <String, dynamic>{'photosNeeded': engine.photosNeeded},
      ),
    );
    for (final player in engine.players) {
      if (player.id == 'host' || !player.connected) continue;
      await _sendToPlayer(
        player.id,
        WireMessage(
          type: WireType.plantAssignment,
          seq: _nextSeq(),
          payload: <String, dynamic>{'eligible': engine.isPlanter(player.id)},
        ),
      );
    }
    if (_state.candidates.isEmpty) {
      await rerollCandidates();
    } else if (_state.candidates.length > engine.photosNeeded) {
      _emit(
        _state.copyWith(
          candidates: _state.candidates.take(engine.photosNeeded).toList(),
        ),
      );
    } else if (_state.candidates.length < engine.photosNeeded) {
      // The host picked a starter set before the room opened. Now that the
      // player count is known, fill the set so the review screen shows every
      // photo that will go into the deck.
      await _topUpHostCandidates(engine.photosNeeded);
    }
    _emit(_state.copyWith(clearLoading: true));
  }

  Future<void> _topUpHostCandidates(int target) async {
    final current = _state.candidates;
    final missing = target - current.length;
    if (missing <= 0) return;
    final picked = await _photos.sampleCandidates(
      excludedAlbumIds: _settingsValue.excludedAlbumIds,
      count: missing,
      excludeAssetIds: current.map((c) => c.localAssetId).toSet(),
      requireDate: _needsPhotoDates,
    );
    if (picked.isEmpty) {
      if (_needsPhotoDates) {
        _emit(_state.copyWith(errorMessage: _noDatedPhotosMessage));
      }
      return;
    }
    final added = <PhotoCandidate>[
      for (var i = 0; i < picked.length; i++)
        PhotoCandidate(
          photoId: 'host-${current.length + i}-${picked[i].assetId}',
          localAssetId: picked[i].assetId,
          ownerId: 'host',
          bytes: picked[i].bytes,
          isPanorama: picked[i].isPanorama,
          capturedYear: picked[i].capturedAt?.year,
          capturedMonth: picked[i].capturedAt?.month,
        ),
    ];
    _emit(
      _state.copyWith(
        candidates: <PhotoCandidate>[...current, ...added],
        clearError: true,
      ),
    );
  }

  Future<void> rerollCandidates() async {
    final engine = _engine;
    if (engine == null) return;
    final count = engine.photosNeeded;
    final excluded = <String>{..._settingsValue.excludedAlbumIds};
    final picked = await _photos.sampleCandidates(
      excludedAlbumIds: excluded,
      count: count,
      excludeAssetIds: _state.candidates.map((c) => c.localAssetId).toSet(),
      requireDate: _needsPhotoDates,
    );
    final candidates = <PhotoCandidate>[
      for (var i = 0; i < picked.length; i++)
        PhotoCandidate(
          photoId: 'host-$i-${picked[i].assetId}',
          localAssetId: picked[i].assetId,
          ownerId: 'host',
          bytes: picked[i].bytes,
          isPanorama: picked[i].isPanorama,
          capturedYear: picked[i].capturedAt?.year,
          capturedMonth: picked[i].capturedAt?.month,
        ),
    ];
    _emit(
      _state.copyWith(
        candidates: candidates,
        clearError: candidates.isNotEmpty || !_needsPhotoDates,
        errorMessage: candidates.isEmpty && _needsPhotoDates
            ? _noDatedPhotosMessage
            : null,
      ),
    );
  }

  Future<void> swapCandidate(int index) async {
    final engine = _engine;
    if (engine == null) return;
    final current = _state.candidates;
    if (index < 0 || index >= current.length) return;
    final picked = await _photos.sampleCandidates(
      excludedAlbumIds: _settingsValue.excludedAlbumIds,
      count: 1,
      excludeAssetIds: current.map((c) => c.localAssetId).toSet(),
      requireDate: _needsPhotoDates,
    );
    if (picked.isEmpty) return;
    final replacement = PhotoCandidate(
      photoId: 'host-$index-${picked.first.assetId}',
      localAssetId: picked.first.assetId,
      ownerId: 'host',
      bytes: picked.first.bytes,
      isPanorama: picked.first.isPanorama,
      capturedYear: picked.first.capturedAt?.year,
      capturedMonth: picked.first.capturedAt?.month,
    );
    final next = List<PhotoCandidate>.of(current)..[index] = replacement;
    _emit(_state.copyWith(candidates: next));
  }

  Future<void> rerollExtensionCandidates() async {
    final engine = _engine;
    if (engine == null) return;
    final current = _state.extensionCandidates;
    if (current.isEmpty) return;
    final picked = await _photos.sampleCandidates(
      excludedAlbumIds: _settingsValue.excludedAlbumIds,
      count: current.length,
      excludeAssetIds: <String>{
        ..._state.candidates.map((c) => c.localAssetId),
        ...current.map((c) => c.localAssetId),
      },
      requireDate: _needsPhotoDates,
    );
    final candidates = <PhotoCandidate>[
      for (var i = 0; i < picked.length; i++)
        PhotoCandidate(
          photoId: 'ext-$i-${picked[i].assetId}',
          localAssetId: picked[i].assetId,
          ownerId: 'host',
          bytes: picked[i].bytes,
          isPanorama: picked[i].isPanorama,
          capturedYear: picked[i].capturedAt?.year,
          capturedMonth: picked[i].capturedAt?.month,
        ),
    ];
    _emit(_state.copyWith(extensionCandidates: candidates));
  }

  Future<void> swapExtensionCandidate(int index) async {
    final engine = _engine;
    if (engine == null) return;
    final current = _state.extensionCandidates;
    if (index < 0 || index >= current.length) return;
    final picked = await _photos.sampleCandidates(
      excludedAlbumIds: _settingsValue.excludedAlbumIds,
      count: 1,
      excludeAssetIds: <String>{
        ..._state.candidates.map((c) => c.localAssetId),
        ...current.map((c) => c.localAssetId),
      },
      requireDate: _needsPhotoDates,
    );
    if (picked.isEmpty) return;
    final replacement = PhotoCandidate(
      photoId: 'ext-$index-${picked.first.assetId}',
      localAssetId: picked.first.assetId,
      ownerId: 'host',
      bytes: picked.first.bytes,
      isPanorama: picked.first.isPanorama,
      capturedYear: picked.first.capturedAt?.year,
      capturedMonth: picked.first.capturedAt?.month,
    );
    final next = List<PhotoCandidate>.of(current)..[index] = replacement;
    _emit(_state.copyWith(extensionCandidates: next));
  }

  Future<void> markLocalReady() async {
    final engine = _engine;
    if (engine == null) return;
    try {
      engine.submitInitialPhotos('host', _state.candidates);
      engine.markReady('host');
    } on EngineException catch (error) {
      _emit(_state.copyWith(errorMessage: _engineError(error)));
      return;
    }
    _emit(
      _state.copyWith(
        localReady: true,
        plantUnlocked: engine.plantAvailable,
        players: engine.players,
        clearError: true,
      ),
    );
    await _maybeStartMatch();
    if (engine.phase == RoundPhase.preparing) {
      await _broadcastLobby();
    }
  }

  Future<void> plantSecretPhoto(
    String assetId,
    Uint8List bytes, {
    int? capturedYear,
    int? capturedMonth,
  }) async {
    final engine = _engine;
    if (engine == null) return;
    final photo = PhotoCandidate(
      photoId: 'plant-${DateTime.now().microsecondsSinceEpoch}',
      localAssetId: assetId,
      ownerId: 'host',
      bytes: bytes,
      isPlanted: true,
      capturedYear: capturedYear,
      capturedMonth: capturedMonth,
    );
    try {
      engine.plantSecretPhoto('host', photo);
    } on EngineException catch (error) {
      _emit(_state.copyWith(errorMessage: _engineError(error)));
      return;
    }
    _emit(
      _state.copyWith(
        plantUsed: true,
        plantUnlocked: engine.plantAvailable,
        players: engine.players,
      ),
    );
  }

  Future<void> submitGuess(String guessedOwnerId) async {
    final engine = _engine;
    if (engine == null || _state.lockedGuessOwnerId != null) return;
    unawaited(GameHaptics.instance.selection());
    unawaited(GameAudioService.instance.tap());
    final elapsed = DateTime.now().millisecondsSinceEpoch - _roundStartMs;
    engine.submitGuess('host', guessedOwnerId, elapsed);
    _emit(_state.copyWith(lockedGuessOwnerId: guessedOwnerId));
    await _syncGuesses();
  }

  Future<void> notifyScreenshot() async {
    final engine = _engine;
    if (engine == null) {
      await _clientTransport?.send(
        WireMessage(type: WireType.screenshotTaken, seq: _nextSeq()),
      );
      return;
    }
    engine.recordScreenshot('host');
    _rememberScreenshot('host', engine);
    await _hostTransport?.broadcast(
      WireMessage(
        type: WireType.screenshotAlert,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'playerId': 'host',
          'playerName': _displayName,
        },
      ),
    );
  }

  /// Host keeps the match going with five more rounds.
  Future<void> extendMatch({int extraRounds = 5, int extraPhotos = 3}) async {
    final engine = _engine;
    if (engine == null) return;
    final deadline = engine.extendGame(
      extraRounds: extraRounds,
      extraPhotos: extraPhotos,
    );
    final seconds = extendWindow.inSeconds;
    _emit(
      _state.copyWith(
        phase: RoundPhase.extendPrompt,
        hostDeciding: false,
        extensionSecondsLeft: seconds,
        extensionCandidates: const <PhotoCandidate>[],
        extensionApproved: false,
        clearError: true,
      ),
    );
    await _hostTransport?.broadcast(
      WireMessage(
        type: WireType.extendPrepare,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'extraPhotos': extraPhotos,
          'timeoutMs': extendWindow.inMilliseconds,
        },
      ),
    );
    await _drawExtensionCandidates(extraPhotos);
    _startExtendTicker(deadline);
  }

  Future<void> _drawExtensionCandidates(int count) async {
    final picked = await _photos.sampleCandidates(
      excludedAlbumIds: _settingsValue.excludedAlbumIds,
      count: count,
      excludeAssetIds: _state.candidates.map((c) => c.localAssetId).toSet(),
      requireDate: _needsPhotoDates,
    );
    final candidates = <PhotoCandidate>[
      for (var i = 0; i < picked.length; i++)
        PhotoCandidate(
          photoId: 'ext-$i-${picked[i].assetId}',
          localAssetId: picked[i].assetId,
          ownerId: 'host',
          bytes: picked[i].bytes,
          isPanorama: picked[i].isPanorama,
          capturedYear: picked[i].capturedAt?.year,
          capturedMonth: picked[i].capturedAt?.month,
        ),
    ];
    _emit(_state.copyWith(extensionCandidates: candidates));
  }

  Future<void> approveExtension() async {
    final engine = _engine;
    if (engine == null) return;
    try {
      engine.submitExtensionPhotos('host', _state.extensionCandidates);
    } on EngineException catch (error) {
      _emit(_state.copyWith(errorMessage: _engineError(error)));
      return;
    }
    _emit(_state.copyWith(extensionApproved: true, clearError: true));
    await _maybeCommitExtension();
  }

  void _startExtendTicker(int deadlineMs) {
    _extendTicker?.cancel();
    _extendTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining =
          ((deadlineMs - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
      if (_disposed) {
        timer.cancel();
        return;
      }
      _emit(_state.copyWith(extensionSecondsLeft: max(0, remaining)));
      if (remaining <= 0) {
        timer.cancel();
        unawaited(_forceCommitExtension());
      }
    });
  }

  Future<void> _forceCommitExtension() async {
    final engine = _engine;
    if (engine == null) return;
    engine.handleExtensionTimeout();
    await _maybeCommitExtension();
  }

  Future<void> _maybeCommitExtension() async {
    final engine = _engine;
    if (engine == null) return;
    if (engine.phase != RoundPhase.countdown) return;
    _extendTicker?.cancel();
    _emit(
      _state.copyWith(
        phase: RoundPhase.countdown,
        totalRounds: engine.totalRounds,
        extensionSecondsLeft: 0,
        extensionCandidates: const <PhotoCandidate>[],
        extensionApproved: false,
        localReady: false,
      ),
    );
    await _enterRoundCountdown();
  }

  void _engineExtend(List<PhotoCandidate> photos, String playerId) {
    final engine = _engine;
    if (engine == null) return;
    engine.submitExtensionPhotos(playerId, photos);
  }

  Future<void> endMatch() async {
    final engine = _engine;
    if (engine == null) return;
    final awards = engine.buildPodiumAwards();
    await _hostTransport?.broadcast(
      WireMessage(
        type: WireType.gamePodium,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'awards': awards.map((a) => a.toJson()).toList(),
          'players': engine.players.map((p) => p.toJson()).toList(),
        },
      ),
    );
    _emit(
      _state.copyWith(
        phase: RoundPhase.podium,
        awards: awards,
        hostDeciding: false,
        activePhotoBytes: null,
        candidates: const <PhotoCandidate>[],
        extensionCandidates: const <PhotoCandidate>[],
      ),
    );
  }

  /// Host escape hatch: end the current timed screen and move on. It never
  /// commits a score twice; the normal finish paths keep their own guards.
  Future<void> skipRound() async {
    if (!_state.isHosting) return;
    switch (_state.phase) {
      case RoundPhase.countdown:
        _countdownTicker?.cancel();
        await _beginRound();
      case RoundPhase.guessing:
        await _finishRound();
      case RoundPhase.captionWriting:
      case RoundPhase.captionVoting:
        await _finishCaptionRound();
      case RoundPhase.timelineGuessing:
        await _finishTimelineRound();
      case RoundPhase.reveal:
      case RoundPhase.captionReveal:
      case RoundPhase.timelineReveal:
        await _advanceAfterReveal();
      case RoundPhase.lobby:
      case RoundPhase.preparing:
      case RoundPhase.extendPrompt:
      case RoundPhase.podium:
        return;
    }
  }

  /// Host-only escape hatch when a connected player never votes.
  Future<void> revealCaptionNow() async {
    if (!_state.isHosting || _state.phase != RoundPhase.captionVoting) return;
    await _finishCaptionRound();
  }

  void dismissVersionWarning() {
    if (_state.versionWarning == null) return;
    _emit(_state.copyWith(versionWarningDismissed: true));
  }

  /// Returns to the lobby keeping the players that are still connected.
  Future<void> playAgain() async {
    final engine = _engine;
    if (engine == null) return;
    final players = engine.players;
    final config = _state.config;
    final fresh = HostGameEngine(
      config: config,
      random: random,
      planterOverride: planterOverride,
    );
    _engine = fresh;
    for (final player in players) {
      if (!player.connected) continue;
      try {
        fresh.addPlayer(
          id: player.id,
          name: player.name,
          avatar: player.avatar,
          avatarColorIndex: player.avatarColorIndex,
          isHost: player.isHost,
        );
      } on EngineException {
        continue;
      }
    }
    _remotePhotos.clear();
    _assembledHostBytes.clear();
    _clientRoundPhotos.clear();
    _emit(
      MatchUiState(
        isHosting: true,
        roomId: _state.roomId,
        inviteUrl: _state.inviteUrl,
        localPlayerId: 'host',
        phase: RoundPhase.lobby,
        players: fresh.players,
        avatarPhotos: Map<String, String>.unmodifiable(_avatarPhotos),
        config: config,
        connectionMode: _state.connectionMode,
      ),
    );
    await _broadcastLobby();
  }

  Future<void> _broadcastLobby() async {
    final engine = _engine;
    if (engine == null) return;
    await _hostTransport?.broadcast(
      WireMessage(
        type: WireType.lobbyState,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'players': engine.players.map((p) => p.toJson()).toList(),
          'config': engine.config.toJson(),
          'phase': engine.phase.name,
          'avatarPhotos': _avatarPhotos,
        },
      ),
    );
    _emit(
      _state.copyWith(
        players: engine.players,
        config: engine.config,
        avatarPhotos: Map<String, String>.unmodifiable(_avatarPhotos),
      ),
    );
  }

  Future<void> joinMatch(String rawInvite) async {
    _pendingInviteUrl = null;
    _pendingRoomId = null;
    _pendingPlayerId = null;
    _pendingPlayerToken = null;
    _emit(
      _state.copyWith(loadingMessage: _l10n.loadingJoining, clearError: true),
    );
    final InvitePayload invite;
    try {
      invite = tryParseInvite(rawInvite);
    } on InvalidInviteException {
      _emit(
        _state.copyWith(
          errorMessage: _l10n.errorInvalidInvite,
          clearLoading: true,
        ),
      );
      return;
    }

    _pendingInviteUrl = encodeInviteUrl(invite, baseUrl: kInviteBaseUrl);
    _pendingRoomId = invite.roomId;
    final identityOverride = playerIdOverride;
    final tokenOverride = playerTokenOverride;
    final previousRoom = await _lastRooms.load();
    if (identityOverride != null && tokenOverride != null) {
      _pendingPlayerId = identityOverride;
      _pendingPlayerToken = tokenOverride;
    } else if (previousRoom != null &&
        previousRoom.roomId == invite.roomId &&
        previousRoom.playerId.isNotEmpty &&
        previousRoom.playerToken.isNotEmpty) {
      _pendingPlayerId = previousRoom.playerId;
      _pendingPlayerToken = previousRoom.playerToken;
    } else {
      _pendingPlayerId = 'p${_randomToken(10)}';
      _pendingPlayerToken = _randomToken(24);
    }
    final ClientTransport transport;
    try {
      transport = await _connector.connect(
        invite: invite,
        settings: _settingsValue,
      );
    } on TurnQuotaBlockedException catch (error) {
      _emit(
        _state.copyWith(
          turnLimitNotice: error.notice,
          errorMessage: _l10n.errorRelayLimit,
          clearLoading: true,
        ),
      );
      return;
    } on Object {
      _emit(
        _state.copyWith(errorMessage: _l10n.errorReachHost, clearLoading: true),
      );
      return;
    }

    _clientTransport = transport;
    _bindClient(transport);
    // Enter the room before the handshake so a refusal can reset this state
    // instead of being overwritten by a late emit.
    _emit(
      _state.copyWith(
        isHosting: false,
        roomId: invite.roomId,
        connectionMode: transport.mode,
        turnLimitNotice: transport.turnLimitNotice,
        phase: RoundPhase.lobby,
        clearLoading: true,
      ),
    );
    await transport.send(
      WireMessage(
        type: WireType.joinReq,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'name': _displayName,
          'avatar': _settingsValue.avatar,
          'avatarColorIndex': _settingsValue.avatarColorIndex,
          'avatarPhoto': _settingsValue.avatarPhoto,
          'playerId': _pendingPlayerId,
          'playerToken': _pendingPlayerToken,
          'appVersion': appVersion,
          'appBuild': appBuild,
        },
      ),
    );
    if (_state.roomId == null) return;
    await _startScreenshots();
    await _setAwake(true);
  }

  void _startClientPhaseTicker(int durationMs) {
    _clientPhaseTicker?.cancel();
    if (durationMs <= 0 || _state.isHosting) return;
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    _clientPhaseTicker = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      final elapsed = DateTime.now().millisecondsSinceEpoch - startedAt;
      final remaining = (durationMs - elapsed).clamp(0, durationMs);
      _emit(_state.copyWith(remainingMs: remaining));
      if (remaining <= 0) {
        timer.cancel();
        _clientPhaseTicker = null;
      }
    });
  }

  void _stopClientPhaseTicker() {
    _clientPhaseTicker?.cancel();
    _clientPhaseTicker = null;
  }

  void _bindClient(ClientTransport transport) {
    _clientSubs.add(transport.messages.listen(_handleClientMessage));
    _clientSubs.add(
      transport.disconnected.listen(
        (_) => unawaited(_startReconnect()),
        onDone: () => unawaited(_startReconnect()),
      ),
    );
  }

  Future<void> _cancelClientSubs() async {
    for (final sub in _clientSubs) {
      await sub.cancel();
    }
    _clientSubs.clear();
  }

  Future<void> _startReconnect() async {
    if (_leaving ||
        _endingOnHostLeave ||
        _state.isHosting ||
        _hostClosed ||
        _state.roomId == null) {
      return;
    }
    if (_reconnectTimer != null) return;
    _stopClientPhaseTicker();
    _emit(_state.copyWith(reconnecting: true, reconnectSecondsLeft: 20));
    _reconnectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed || _leaving || !_state.reconnecting) {
        timer.cancel();
        _reconnectTimer = null;
        return;
      }
      final left = _state.reconnectSecondsLeft - 1;
      if (left <= 0) {
        timer.cancel();
        _reconnectTimer = null;
        unawaited(_endOnHostLeave());
        return;
      }
      _emit(_state.copyWith(reconnectSecondsLeft: left));
      unawaited(_attemptReconnect());
    });
    if (reconnectAttemptDelay != Duration.zero) {
      Timer(reconnectAttemptDelay, () => unawaited(_attemptReconnect()));
    } else {
      await _attemptReconnect();
    }
  }

  Future<void> _attemptReconnect() async {
    if (_reconnectInFlight || !_state.reconnecting || _leaving || _hostClosed) {
      return;
    }
    final rawInvite = _pendingInviteUrl;
    final playerId = _currentPlayerId ?? _pendingPlayerId;
    final playerToken = _currentPlayerToken ?? _pendingPlayerToken;
    if (rawInvite == null || playerId == null || playerToken == null) {
      return;
    }
    final InvitePayload invite;
    try {
      invite = tryParseInvite(rawInvite);
    } on InvalidInviteException {
      return;
    }
    _reconnectInFlight = true;
    ClientTransport? transport;
    try {
      transport = await _connector.connect(
        invite: invite,
        settings: _settingsValue,
      );
      final ack = Completer<void>();
      _reconnectAck = ack;
      await _cancelClientSubs();
      _clientTransport = transport;
      _clientRoundPhotos.clear();
      _assemblers.clear();
      _bindClient(transport);
      await transport.send(
        WireMessage(
          type: WireType.joinReq,
          seq: _nextSeq(),
          payload: <String, dynamic>{
            'name': _displayName,
            'avatar': _settingsValue.avatar,
            'avatarColorIndex': _settingsValue.avatarColorIndex,
            'avatarPhoto': _settingsValue.avatarPhoto,
            'playerId': playerId,
            'playerToken': playerToken,
            'appVersion': appVersion,
            'appBuild': appBuild,
          },
        ),
      );
      await ack.future.timeout(const Duration(seconds: 4));
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _emit(_state.copyWith(reconnecting: false, reconnectSecondsLeft: 0));
    } on Object {
      await transport?.close();
    } finally {
      _reconnectAck = null;
      _reconnectInFlight = false;
    }
  }

  Future<void> _endOnHostLeave() async {
    if (_leaving || _endingOnHostLeave) return;
    _endingOnHostLeave = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _hostClosed = true;
    await leaveMatch();
    _endingOnHostLeave = false;
    _emit(_state.copyWith(errorMessage: _l10n.errorHostEnded));
  }

  Future<void> _handleClientMessage(WireMessage message) async {
    final payload = message.payload;
    switch (message.type) {
      case WireType.joinAck:
        _reconnectAck?.complete();
        final acknowledgedId = payload['playerId'] as String?;
        _currentPlayerId = acknowledgedId ?? _pendingPlayerId;
        _currentPlayerToken = _pendingPlayerToken;
        final inviteUrl = _pendingInviteUrl;
        final roomId = _pendingRoomId;
        if (inviteUrl != null &&
            roomId != null &&
            _currentPlayerId != null &&
            _currentPlayerToken != null) {
          unawaited(
            _lastRooms.remember(
              LastRoom(
                inviteUrl: inviteUrl,
                roomId: roomId,
                playerId: _currentPlayerId!,
                playerToken: _currentPlayerToken!,
                joinedAtUtc: DateTime.now().toUtc(),
              ),
            ),
          );
        }
        _emit(_state.copyWith(localPlayerId: _currentPlayerId));
      case WireType.stateSync:
        _reconnectAck?.complete();
        final phaseName = payload['phase'] as String?;
        var phase = _state.phase;
        for (final candidate in RoundPhase.values) {
          if (candidate.name == phaseName) {
            phase = candidate;
            break;
          }
        }
        final players = <Player>[
          for (final entry
              in (payload['players'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) Player.fromJson(entry),
        ];
        final config = payload['config'];
        final activeMode = GameMode.values.firstWhere(
          (value) => value.name == payload['activeMode'],
          orElse: () => _state.activeMode,
        );
        final activePhotoId = payload['activePhotoId'] as String?;
        final activeBytes = activePhotoId == null
            ? null
            : _clientRoundPhotos[activePhotoId];
        final candidates = <PhotoCandidate>[
          for (final entry
              in (payload['candidates'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>)
              PhotoCandidate.fromJson(entry).copyWith(
                bytes: _clientRoundPhotos[entry['photoId'] as String?],
              ),
        ];
        final options = <Player>[
          for (final entry
              in (payload['activeRoundOptions'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) Player.fromJson(entry),
        ];
        final captionOptions = <CaptionOption>[
          for (final entry
              in (payload['captionOptions'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) CaptionOption.fromJson(entry),
        ];
        final memeAssignmentJson = payload['memeAssignment'];
        final memeAssignment = memeAssignmentJson is Map<String, dynamic>
            ? MemeAssignment.fromJson(memeAssignmentJson)
            : null;
        final memeCards = <MemeCard>[
          for (final entry
              in (payload['memeCards'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) MemeCard.fromJson(entry),
        ];
        final memeRevealCards = <MemeCard>[
          for (final entry
              in (payload['memeRevealCards'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) MemeCard.fromJson(entry),
        ];
        final topMemes = <MemeCard>[
          for (final entry
              in (payload['topMemes'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) MemeCard.fromJson(entry),
        ];
        final memeVotedIds = <String>{
          for (final value
              in (payload['memeVotedIds'] as List<dynamic>? ?? const []))
            if (value is String) value,
        };
        final lastMemeRevealJson = payload['lastMemeReveal'];
        final awards = <MatchAward>[
          for (final entry in (payload['awards'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) MatchAward.fromJson(entry),
        ];
        final alerts = <ScreenshotBanner>[
          for (final entry
              in (payload['screenshotAlerts'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) ScreenshotBanner.fromJson(entry),
        ];
        final avatarPhotos = <String, String>{
          for (final entry
              in (payload['avatarPhotos'] as Map<String, dynamic>? ??
                      const <String, dynamic>{})
                  .entries)
            if (entry.value is String) entry.key: entry.value as String,
        };
        final lastReveal = payload['lastReveal'];
        final captionReveal = payload['lastCaptionReveal'];
        final timelineReveal = payload['lastTimelineReveal'];
        _stopClientPhaseTicker();
        _assemblers.clear();
        _emit(
          _state.copyWith(
            phase: phase,
            config: config is Map<String, dynamic>
                ? MatchConfig.fromJson(config)
                : _state.config,
            players: players,
            avatarPhotos: avatarPhotos,
            currentRound:
                payload['currentRound'] as int? ?? _state.currentRound,
            totalRounds: payload['totalRounds'] as int? ?? _state.totalRounds,
            remainingMs: payload['remainingMs'] as int? ?? 0,
            phaseDurationMs: payload['phaseDurationMs'] as int? ?? 0,
            activeMode: activeMode,
            activePhotoBytes: activeBytes,
            activePhotoIsPanorama:
                payload['activePhotoIsPanorama'] as bool? ?? false,
            activeRoundOptions: options,
            localReady: payload['localReady'] as bool? ?? false,
            photosNeeded: payload['photosNeeded'] as int? ?? 0,
            candidates: candidates,
            plantUnlocked: payload['plantUnlocked'] as bool? ?? false,
            plantEligible: payload['plantEligible'] as bool? ?? false,
            plantUsed: payload['plantUsed'] as bool? ?? false,
            lockedGuessOwnerId: payload['lockedGuessOwnerId'] as String?,
            captionSubmitted: payload['captionSubmitted'] as bool? ?? false,
            captionOptions: captionOptions,
            ownCaptionId: payload['ownCaptionId'] as String?,
            votedCaptionId: payload['votedCaptionId'] as String?,
            captionsSubmitted: payload['captionsSubmitted'] as int? ?? 0,
            votesSubmitted: payload['votesSubmitted'] as int? ?? 0,
            memeAssignment: memeAssignment,
            memePhotoBase64: payload['memePhotoBase64'] as String?,
            memeSwapsLeft: payload['memeSwapsLeft'] as int? ?? 5,
            memeSubmitted: payload['memeSubmitted'] as bool? ?? false,
            memeCards: memeCards,
            memeVotedIds: memeVotedIds,
            memeSubmissions: payload['memeSubmissions'] as int? ?? 0,
            memeVotesSubmitted: payload['memeVotesSubmitted'] as int? ?? 0,
            lastMemeReveal: lastMemeRevealJson is Map<String, dynamic>
                ? MemeReveal.fromJson(lastMemeRevealJson)
                : null,
            memeRevealCards: memeRevealCards,
            topMemes: topMemes,
            lastReveal: lastReveal is Map<String, dynamic>
                ? RoundReveal.fromJson(lastReveal)
                : null,
            lastCaptionReveal: captionReveal is Map<String, dynamic>
                ? CaptionReveal.fromJson(captionReveal)
                : null,
            lastTimelineReveal: timelineReveal is Map<String, dynamic>
                ? TimelineReveal.fromJson(timelineReveal)
                : null,
            timelineSubmitted: payload['timelineSubmitted'] as bool? ?? false,
            lockedTimelineYear: payload['lockedTimelineYear'] as int?,
            lockedTimelineMonth: payload['lockedTimelineMonth'] as int?,
            awards: awards,
            hostDeciding: payload['hostDeciding'] as bool? ?? false,
            screenshotAlerts: alerts,
            extensionSecondsLeft: payload['extensionSecondsLeft'] as int? ?? 0,
            reconnecting: false,
            reconnectSecondsLeft: 0,
            clearError: true,
          ),
        );
        if (phase == RoundPhase.countdown ||
            phase == RoundPhase.guessing ||
            phase == RoundPhase.captionWriting ||
            phase == RoundPhase.timelineGuessing) {
          _startClientPhaseTicker(payload['remainingMs'] as int? ?? 0);
        }
        if (phase == RoundPhase.preparing &&
            candidates.isEmpty &&
            !(payload['localReady'] as bool? ?? false)) {
          final permission = await _photos.requestPermission();
          if (permission != PermissionState.denied) {
            final drawn = await _drawClientCandidates(
              payload['photosNeeded'] as int? ?? 3,
            );
            _emit(_state.copyWith(candidates: drawn));
          }
        }
        if (phase == RoundPhase.extendPrompt) {
          final drawn = await _drawClientCandidates(3);
          _emit(_state.copyWith(extensionCandidates: drawn));
        }
      case WireType.versionWarning:
        final latestBuild = payload['latestBuild'] as int? ?? appBuild;
        if (latestBuild > appBuild) {
          _emit(
            _state.copyWith(
              versionWarning: VersionWarning(
                latestVersion:
                    payload['latestVersion'] as String? ?? appVersion,
                latestBuild: latestBuild,
                ownVersion: appVersion,
                ownBuild: appBuild,
              ),
              versionWarningDismissed: false,
            ),
          );
        }
      case WireType.roomClosed:
        _hostClosed = true;
        await _endOnHostLeave();
      case WireType.kick:
        final reason = payload['reason'] as String?;
        await leaveMatch();
        _emit(
          _state.copyWith(
            errorMessage: switch (reason) {
              'started' => _l10n.errorRoomStarted,
              'removed' || 'identity' => _l10n.errorRemovedByHost,
              _ => _l10n.errorRemovedByHost,
            },
          ),
        );
      case WireType.lobbyState:
        final players = <Player>[
          for (final entry
              in (payload['players'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) Player.fromJson(entry),
        ];
        final config = payload['config'];
        final phaseName = payload['phase'] as String?;
        var parsedPhase = RoundPhase.lobby;
        for (final phase in RoundPhase.values) {
          if (phase.name == phaseName) {
            parsedPhase = phase;
            break;
          }
        }
        final plantUnlocked =
            parsedPhase == RoundPhase.preparing &&
            _state.localReady &&
            !_state.plantUsed &&
            players.length >= 2 &&
            players.any((p) => !p.ready);
        final avatarPhotos = <String, String>{
          for (final entry
              in (payload['avatarPhotos'] as Map<String, dynamic>? ??
                      const <String, dynamic>{})
                  .entries)
            if (entry.value is String) entry.key: entry.value as String,
        };
        _emit(
          _state.copyWith(
            players: players,
            config: config is Map<String, dynamic>
                ? MatchConfig.fromJson(config)
                : _state.config,
            phase: parsedPhase,
            plantUnlocked: plantUnlocked,
            avatarPhotos: avatarPhotos,
          ),
        );
      case WireType.startPrepare:
        final needed = payload['photosNeeded'] as int? ?? 3;
        _emit(
          _state.copyWith(
            phase: RoundPhase.preparing,
            photosNeeded: needed,
            candidates: const <PhotoCandidate>[],
            localReady: false,
          ),
        );
        final permission = await _photos.requestPermission();
        if (permission == PermissionState.denied) {
          _emit(_state.copyWith(errorMessage: _l10n.errorPhotoAccessClient));
          return;
        }
        final drawn = await _drawClientCandidates(needed);
        _emit(
          _state.copyWith(
            candidates: drawn,
            errorMessage: drawn.isEmpty && _state.config.needsPhotoDates
                ? _noDatedPhotosMessage
                : null,
            clearError: drawn.isNotEmpty || !_state.config.needsPhotoDates,
          ),
        );
      case WireType.plantAssignment:
        _emit(
          _state.copyWith(plantEligible: payload['eligible'] as bool? ?? false),
        );
      case WireType.photoChunk:
        final chunk = PhotoChunk.fromJson(payload);
        final localId = _state.localPlayerId ?? 'client';
        final assembler = _assemblers.putIfAbsent(
          localId,
          PhotoChunkAssembler.new,
        );
        final bytes = assembler.add(chunk);
        if (bytes != null) {
          _clientRoundPhotos[chunk.photoId] = bytes;
          _emit(_state.copyWith(activePhotoBytes: bytes));
        }
      case WireType.roundCountdown:
        _emit(
          _state.copyWith(
            phase: RoundPhase.countdown,
            currentRound: payload['roundNumber'] as int? ?? 0,
            totalRounds: payload['totalRounds'] as int? ?? _state.totalRounds,
            remainingMs: payload['durationMs'] as int? ?? 0,
            clearGuess: true,
            lockedGuessOwnerId: null,
          ),
        );
        _startClientPhaseTicker(payload['durationMs'] as int? ?? 0);
      case WireType.roundShow:
        final options = <Player>[
          for (final entry
              in (payload['options'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) Player.fromJson(entry),
        ];
        final photoId = payload['photoId'] as String?;
        final mode = GameMode.values.firstWhere(
          (value) => value.name == payload['mode'],
          orElse: () => GameMode.classic,
        );
        final phase = switch (mode) {
          GameMode.classic || GameMode.mixedParty => RoundPhase.guessing,
          GameMode.captionThis => RoundPhase.captionWriting,
          GameMode.makeItMeme => RoundPhase.captionWriting,
          GameMode.timeTraveler => RoundPhase.timelineGuessing,
        };
        _roundStartMs = DateTime.now().millisecondsSinceEpoch;
        _emit(
          _state.copyWith(
            phase: phase,
            activeMode: mode,
            currentRound: payload['roundNumber'] as int? ?? 0,
            totalRounds: payload['totalRounds'] as int? ?? _state.totalRounds,
            remainingMs: payload['durationMs'] as int? ?? 8000,
            phaseDurationMs: payload['durationMs'] as int? ?? 8000,
            activePhotoBytes: photoId == null
                ? null
                : _clientRoundPhotos[photoId],
            activePhotoIsPanorama: payload['isPanorama'] as bool? ?? false,
            activeRoundOptions: options,
            clearGuess: true,
            clearRoundInput: true,
            lockedGuessOwnerId: null,
          ),
        );
        _startClientPhaseTicker(payload['durationMs'] as int? ?? 0);
      case WireType.roundReveal:
        _stopClientPhaseTicker();
        unawaited(GameHaptics.instance.light());
        final reveal = RoundReveal.fromJson(payload);
        final updated = <Player>[
          for (final player in _state.players)
            if (reveal.scoreDeltas.containsKey(player.id) ||
                reveal.streaks.containsKey(player.id))
              (Player.fromJson(player.toJson())
                ..score = player.score + (reveal.scoreDeltas[player.id] ?? 0)
                ..streak = reveal.streaks[player.id] ?? player.streak
                ..longestStreak =
                    player.longestStreak <
                        (reveal.streaks[player.id] ?? player.streak)
                    ? (reveal.streaks[player.id] ?? player.streak)
                    : player.longestStreak)
            else
              player,
        ];
        _emit(
          _state.copyWith(
            phase: RoundPhase.reveal,
            lastReveal: reveal,
            players: updated,
          ),
        );
      case WireType.captionOptions:
        final captions = <CaptionOption>[
          for (final entry
              in (payload['captions'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) CaptionOption.fromJson(entry),
        ];
        _emit(
          _state.copyWith(
            phase: RoundPhase.captionVoting,
            captionOptions: captions,
            ownCaptionId: payload['ownId'] as String?,
            votedCaptionId: null,
            remainingMs: payload['durationMs'] as int? ?? 0,
            phaseDurationMs: payload['durationMs'] as int? ?? 0,
            captionsSubmitted: _state.captionsSubmitted,
            clearError: true,
          ),
        );
        _startClientPhaseTicker(payload['durationMs'] as int? ?? 0);
      case WireType.captionReveal:
        _stopClientPhaseTicker();
        unawaited(GameHaptics.instance.light());
        final reveal = CaptionReveal.fromJson(payload);
        _emit(
          _state.copyWith(
            phase: RoundPhase.captionReveal,
            lastCaptionReveal: reveal,
            players: _playersWithDeltas(reveal.scoreDeltas),
            captionOptions: const <CaptionOption>[],
            remainingMs: 0,
          ),
        );
      case WireType.memeAssignment:
        final assignmentJson = payload['assignment'];
        if (assignmentJson is Map<String, dynamic>) {
          final assignment = MemeAssignment.fromJson(assignmentJson);
          final encoded = payload['photoBase64'] as String?;
          if (encoded != null && encoded.isNotEmpty) {
            _memePhotoBytes[assignment.photoId] = base64Decode(encoded);
          }
          _emit(
            _state.copyWith(
              memeAssignment: assignment,
              memePhotoBase64: encoded,
              memeSwapsLeft: payload['swapsLeft'] as int? ?? 5,
              memeSubmitted: false,
              memeSubmissions: _state.memeSubmissions,
              clearError: true,
            ),
          );
        }
      case WireType.memeOptions:
        final cards = <MemeCard>[
          for (final entry in (payload['cards'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) MemeCard.fromJson(entry),
        ];
        final votedIds = <String>{
          for (final value
              in (payload['votedIds'] as List<dynamic>? ?? const []))
            if (value is String) value,
        };
        _emit(
          _state.copyWith(
            phase: RoundPhase.captionVoting,
            activeMode: GameMode.makeItMeme,
            memeCards: cards,
            memeVotedIds: votedIds,
            memeSubmissions: payload['submissions'] as int? ?? cards.length,
            memeVotesSubmitted: payload['votes'] as int? ?? 0,
            remainingMs: 0,
            phaseDurationMs: 0,
            clearError: true,
          ),
        );
      case WireType.memeReveal:
        _stopClientPhaseTicker();
        unawaited(GameAudioService.instance.fanfare());
        unawaited(GameHaptics.instance.heavy());
        final reveal = MemeReveal.fromJson(payload);
        final cards = <MemeCard>[
          for (final entry in (payload['cards'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) MemeCard.fromJson(entry),
        ];
        final players = <Player>[
          for (final entry
              in (payload['players'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) Player.fromJson(entry),
        ];
        final topMemes = <MemeCard>[
          for (final entry
              in (payload['topMemes'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) MemeCard.fromJson(entry),
        ];
        _emit(
          _state.copyWith(
            phase: RoundPhase.captionReveal,
            activeMode: GameMode.makeItMeme,
            lastMemeReveal: reveal,
            memeRevealCards: cards,
            memeCards: const <MemeCard>[],
            memeVotedIds: const <String>{},
            memeVotesSubmitted: 0,
            players: players,
            topMemes: topMemes,
            remainingMs: 0,
          ),
        );
      case WireType.timelineReveal:
        _stopClientPhaseTicker();
        unawaited(GameHaptics.instance.light());
        final reveal = TimelineReveal.fromJson(payload);
        _emit(
          _state.copyWith(
            phase: RoundPhase.timelineReveal,
            lastTimelineReveal: reveal,
            players: _playersWithDeltas(reveal.scoreDeltas),
            remainingMs: 0,
          ),
        );
      case WireType.screenshotAlert:
        final banner = ScreenshotBanner(
          playerId: payload['playerId'] as String? ?? '',
          playerName: payload['playerName'] as String? ?? '',
          atMs: DateTime.now().millisecondsSinceEpoch,
        );
        _emit(
          _state.copyWith(
            screenshotAlerts: List<ScreenshotBanner>.unmodifiable(
              <ScreenshotBanner>[..._state.screenshotAlerts, banner],
            ),
          ),
        );
      case WireType.extendPrepare:
        final timeoutMs = payload['timeoutMs'] as int? ?? 10000;
        _emit(
          _state.copyWith(
            phase: RoundPhase.extendPrompt,
            extensionSecondsLeft: (timeoutMs / 1000).ceil(),
            extensionApproved: false,
          ),
        );
        final drawn = await _drawClientCandidates(
          payload['extraPhotos'] as int? ?? 3,
        );
        _emit(_state.copyWith(extensionCandidates: drawn));
      case WireType.gamePodium:
        _stopClientPhaseTicker();
        unawaited(GameHaptics.instance.heavy());
        final awards = <MatchAward>[
          for (final entry in (payload['awards'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) MatchAward.fromJson(entry),
        ];
        final players = <Player>[
          for (final entry
              in (payload['players'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) Player.fromJson(entry),
        ];
        final topMemes = <MemeCard>[
          for (final entry
              in (payload['topMemes'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) MemeCard.fromJson(entry),
        ];
        _assembledHostBytes.clear();
        _clientRoundPhotos.clear();
        _emit(
          _state.copyWith(
            phase: RoundPhase.podium,
            awards: awards,
            players: players,
            activePhotoBytes: null,
            topMemes: topMemes,
          ),
        );
      case WireType.plantPhoto:
        if (payload['accepted'] == true) {
          _emit(_state.copyWith(plantUsed: true));
        }
      case WireType.errorNotice:
        _emit(
          _state.copyWith(
            errorMessage: _engineCode(payload['code'] as String? ?? ''),
          ),
        );
    }
  }

  List<Player> _playersWithDeltas(Map<String, int> deltas) => <Player>[
    for (final player in _state.players)
      if (deltas.containsKey(player.id))
        (Player.fromJson(player.toJson())
          ..score = player.score + (deltas[player.id] ?? 0))
      else
        player,
  ];

  Future<List<PhotoCandidate>> _drawClientCandidates(int count) async {
    final picked = await _photos.sampleCandidates(
      excludedAlbumIds: _settingsValue.excludedAlbumIds,
      count: count,
      excludeAssetIds: _state.candidates.map((c) => c.localAssetId).toSet(),
      requireDate: _needsPhotoDates,
    );
    final localId = _state.localPlayerId ?? 'pending';
    return <PhotoCandidate>[
      for (var i = 0; i < picked.length; i++)
        PhotoCandidate(
          photoId: '$localId-$i-${picked[i].assetId}',
          localAssetId: picked[i].assetId,
          ownerId: localId,
          bytes: picked[i].bytes,
          isPanorama: picked[i].isPanorama,
          capturedYear: picked[i].capturedAt?.year,
          capturedMonth: picked[i].capturedAt?.month,
        ),
    ];
  }

  Future<void> clientRerollAll() async {
    final drawn = await _drawClientCandidates(_state.photosNeeded);
    _emit(_state.copyWith(candidates: drawn));
  }

  Future<void> clientSwapCandidate(int index) async {
    final current = _state.candidates;
    if (index < 0 || index >= current.length) return;
    final picked = await _photos.sampleCandidates(
      excludedAlbumIds: _settingsValue.excludedAlbumIds,
      count: 1,
      excludeAssetIds: current.map((c) => c.localAssetId).toSet(),
      requireDate: _needsPhotoDates,
    );
    if (picked.isEmpty) return;
    final localId = _state.localPlayerId ?? 'pending';
    final next = List<PhotoCandidate>.of(current)
      ..[index] = PhotoCandidate(
        photoId: '$localId-$index-${picked.first.assetId}',
        localAssetId: picked.first.assetId,
        ownerId: localId,
        bytes: picked.first.bytes,
        isPanorama: picked.first.isPanorama,
        capturedYear: picked.first.capturedAt?.year,
        capturedMonth: picked.first.capturedAt?.month,
      );
    _emit(_state.copyWith(candidates: next));
  }

  Future<void> clientRerollExtension() async {
    final current = _state.extensionCandidates;
    if (current.isEmpty) return;
    final picked = await _photos.sampleCandidates(
      excludedAlbumIds: _settingsValue.excludedAlbumIds,
      count: current.length,
      excludeAssetIds: <String>{
        ..._state.candidates.map((c) => c.localAssetId),
        ...current.map((c) => c.localAssetId),
      },
      requireDate: _needsPhotoDates,
    );
    final localId = _state.localPlayerId ?? 'pending';
    _emit(
      _state.copyWith(
        extensionCandidates: <PhotoCandidate>[
          for (var i = 0; i < picked.length; i++)
            PhotoCandidate(
              photoId: '$localId-ext-$i-${picked[i].assetId}',
              localAssetId: picked[i].assetId,
              ownerId: localId,
              bytes: picked[i].bytes,
              isPanorama: picked[i].isPanorama,
              capturedYear: picked[i].capturedAt?.year,
              capturedMonth: picked[i].capturedAt?.month,
            ),
        ],
      ),
    );
  }

  Future<void> clientSwapExtensionCandidate(int index) async {
    final current = _state.extensionCandidates;
    if (index < 0 || index >= current.length) return;
    final picked = await _photos.sampleCandidates(
      excludedAlbumIds: _settingsValue.excludedAlbumIds,
      count: 1,
      excludeAssetIds: <String>{
        ..._state.candidates.map((c) => c.localAssetId),
        ...current.map((c) => c.localAssetId),
      },
      requireDate: _needsPhotoDates,
    );
    if (picked.isEmpty) return;
    final localId = _state.localPlayerId ?? 'pending';
    final next = List<PhotoCandidate>.of(current)
      ..[index] = PhotoCandidate(
        photoId: '$localId-ext-$index-${picked.first.assetId}',
        localAssetId: picked.first.assetId,
        ownerId: localId,
        bytes: picked.first.bytes,
        isPanorama: picked.first.isPanorama,
        capturedYear: picked.first.capturedAt?.year,
        capturedMonth: picked.first.capturedAt?.month,
      );
    _emit(_state.copyWith(extensionCandidates: next));
  }

  Future<void> clientMarkReady() async {
    final transport = _clientTransport;
    if (transport == null) return;
    await transport.send(
      WireMessage(
        type: WireType.submitPhotoMeta,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'photos': _state.candidates.map((c) => c.toJson()).toList(),
        },
      ),
    );
    for (final candidate in _state.candidates) {
      final bytes = candidate.bytes;
      if (bytes == null) continue;
      for (final chunk in PhotoChunker.split(candidate.photoId, bytes)) {
        await transport.send(
          WireMessage(
            type: WireType.photoChunk,
            seq: _nextSeq(),
            payload: chunk.toJson(),
          ),
        );
      }
    }
    _emit(_state.copyWith(localReady: true));
    await transport.send(
      WireMessage(type: WireType.playerReady, seq: _nextSeq()),
    );
  }

  Future<void> clientPlantPhoto(int index) async {
    if (index < 0 || index >= _state.candidates.length) return;
    await clientPlantPickedPhoto(_state.candidates[index]);
  }

  Future<void> clientPlantPickedPhoto(PhotoCandidate candidate) async {
    final transport = _clientTransport;
    if (transport == null) return;
    final bytes = candidate.bytes;
    if (bytes == null || bytes.isEmpty) return;
    final photo = candidate.copyWith(
      ownerId: _state.localPlayerId ?? candidate.ownerId,
    );
    for (final chunk in PhotoChunker.split(photo.photoId, bytes)) {
      await transport.send(
        WireMessage(
          type: WireType.photoChunk,
          seq: _nextSeq(),
          payload: chunk.toJson(),
        ),
      );
    }
    await transport.send(
      WireMessage(
        type: WireType.plantPhoto,
        seq: _nextSeq(),
        payload: <String, dynamic>{'photo': photo.toJson()},
      ),
    );
    _emit(_state.copyWith(plantUsed: true));
  }

  Future<void> clientSubmitGuess(String guessedOwnerId) async {
    final transport = _clientTransport;
    if (transport == null || _state.lockedGuessOwnerId != null) return;
    unawaited(GameHaptics.instance.selection());
    unawaited(GameAudioService.instance.tap());
    final elapsed = DateTime.now().millisecondsSinceEpoch - _roundStartMs;
    await transport.send(
      WireMessage(
        type: WireType.submitGuess,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'guessedOwnerId': guessedOwnerId,
          'elapsedMs': elapsed,
        },
      ),
    );
    _emit(_state.copyWith(lockedGuessOwnerId: guessedOwnerId));
  }

  Future<void> clientSubmitCaption(String text) async {
    final transport = _clientTransport;
    if (transport == null || _state.captionSubmitted) return;
    await transport.send(
      WireMessage(
        type: WireType.captionSubmit,
        seq: _nextSeq(),
        payload: <String, dynamic>{'text': text},
      ),
    );
    unawaited(GameHaptics.instance.selection());
    unawaited(GameAudioService.instance.tap());
    _emit(_state.copyWith(captionSubmitted: true, clearError: true));
  }

  Future<void> clientVoteCaption(String captionId) async {
    final transport = _clientTransport;
    if (transport == null || _state.votedCaptionId != null) return;
    await transport.send(
      WireMessage(
        type: WireType.captionVote,
        seq: _nextSeq(),
        payload: <String, dynamic>{'captionId': captionId},
      ),
    );
    unawaited(GameHaptics.instance.selection());
    _emit(_state.copyWith(votedCaptionId: captionId, clearError: true));
  }

  Future<void> clientSubmitTimeline(int year, int month) async {
    final transport = _clientTransport;
    if (transport == null || _state.timelineSubmitted) return;
    final elapsed = DateTime.now().millisecondsSinceEpoch - _roundStartMs;
    await transport.send(
      WireMessage(
        type: WireType.timelineSubmit,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'year': year,
          'month': month,
          'elapsedMs': elapsed,
        },
      ),
    );
    unawaited(GameHaptics.instance.selection());
    unawaited(GameAudioService.instance.tap());
    _emit(
      _state.copyWith(
        timelineSubmitted: true,
        lockedTimelineYear: year,
        lockedTimelineMonth: month,
        clearError: true,
      ),
    );
  }

  Future<void> clientApproveExtension() async {
    final transport = _clientTransport;
    if (transport == null) return;
    for (final candidate in _state.extensionCandidates) {
      final bytes = candidate.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      for (final chunk in PhotoChunker.split(candidate.photoId, bytes)) {
        await transport.send(
          WireMessage(
            type: WireType.photoChunk,
            seq: _nextSeq(),
            payload: chunk.toJson(),
          ),
        );
      }
    }
    await transport.send(
      WireMessage(
        type: WireType.extendSubmit,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'photos': _state.extensionCandidates.map((c) => c.toJson()).toList(),
        },
      ),
    );
    _emit(_state.copyWith(extensionApproved: true));
  }

  Future<void> _startScreenshots() async {
    await _screenshots.start(() {
      unawaited(_onLocalScreenshot());
    });
  }

  Future<void> _onLocalScreenshot() async {
    // A screenshot is worth reporting wherever it happens in the room: lobby,
    // photo check, a round or the podium. The detector only runs while a room
    // is open, so this cannot leak a screenshot from the home screen.
    if (_state.isHosting) {
      await notifyScreenshot();
      return;
    }
    await _clientTransport?.send(
      WireMessage(type: WireType.screenshotTaken, seq: _nextSeq()),
    );
  }

  Future<void> _stopScreenshots() async {
    await _screenshots.stop();
  }

  /// The host keeps the socket alive only while the screen stays on, so the
  /// wake lock is part of the transport contract, not a nicety.
  Future<void> _setAwake(bool awake) async {
    final override = wakeLock;
    if (override != null) {
      await override(awake);
      return;
    }
    try {
      await WakelockPlus.toggle(enable: awake);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  String get _displayName {
    final nickname = _settingsValue.nickname.trim();
    return nickname.isEmpty ? _l10n.player : nickname;
  }

  int _nextSeq() => ++_seq;

  String _randomToken(int length) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final source = random ?? Random.secure();
    return List<String>.generate(
      length,
      (_) => alphabet[source.nextInt(alphabet.length)],
    ).join();
  }

  Future<void> leaveMatch() async {
    if (_leaving) return;
    _leaving = true;
    if (_state.isHosting && _hostTransport != null) {
      try {
        await _hostTransport?.broadcast(
          WireMessage(type: WireType.roomClosed, seq: _nextSeq()),
        );
      } on Object {
        // Closing the room matters more than the courtesy message.
      }
    }
    final forgetRoom = !_state.isHosting && _state.roomId != null;
    _pendingInviteUrl = null;
    _pendingRoomId = null;
    await _stopScreenshots();
    await _setAwake(false);
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _roundTimer?.cancel();
    _countdownTicker?.cancel();
    _clientPhaseTicker?.cancel();
    _extendTicker?.cancel();
    _captionRevealTimer?.cancel();
    _timelineRevealTimer?.cancel();
    _roundTimer = null;
    _clientPhaseTicker = null;
    _countdownTicker = null;
    _extendTicker = null;
    _captionRevealTimer = null;
    _timelineRevealTimer = null;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _hostTransport?.close();
    await _clientTransport?.close();
    _hostTransport = null;
    _clientTransport = null;
    _engine = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAck = null;
    _reconnectInFlight = false;
    _hostClosed = false;
    _currentPlayerId = null;
    _currentPlayerToken = null;
    await _cancelClientSubs();
    _remotePhotos.clear();
    _assemblers.clear();
    _assembledHostBytes.clear();
    _clientRoundPhotos.clear();
    _clientBuilds.clear();
    _clientVersions.clear();
    _clientPlayerIds.clear();
    _playerClientIds.clear();
    _playerTokens.clear();
    _blockedPlayers.clear();
    _avatarPhotos.clear();
    if (forgetRoom) {
      await _lastRooms.forget();
    }
    _emit(const MatchUiState());
    _leaving = false;
  }

  Future<void> dispose() async {
    await leaveMatch();
    _disposed = true;
    await _states.close();
  }
}

/// Wraps an optional transport so a failed online path (no relay, no network)
/// never stops the local room from opening.
class BestEffortHostTransport implements HostTransport {
  BestEffortHostTransport(this._inner);

  final HostTransport _inner;
  final StreamController<String> _connected =
      StreamController<String>.broadcast();
  final StreamController<String> _disconnected =
      StreamController<String>.broadcast();
  final StreamController<HostIncomingMessage> _messages =
      StreamController<HostIncomingMessage>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  bool _started = false;

  @override
  Stream<String> get clientConnected => _connected.stream;

  @override
  Stream<String> get clientDisconnected => _disconnected.stream;

  @override
  Stream<HostIncomingMessage> get messages => _messages.stream;

  @override
  String? get localLanEndpoint => null;

  @override
  Future<void> start() async {
    _subscriptions.add(_inner.clientConnected.listen(_connected.add));
    _subscriptions.add(_inner.clientDisconnected.listen(_disconnected.add));
    _subscriptions.add(_inner.messages.listen(_messages.add));
    try {
      await _inner.start();
      _started = true;
    } on Object {
      _started = false;
    }
  }

  @override
  Future<void> sendToClient(String clientId, WireMessage message) async {
    if (!_started) return;
    await _inner.sendToClient(clientId, message);
  }

  @override
  Future<void> broadcast(WireMessage message) async {
    if (!_started) return;
    await _inner.broadcast(message);
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _inner.close();
    await _connected.close();
    await _disconnected.close();
    await _messages.close();
  }
}
