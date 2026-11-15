import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart' show PermissionState;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/constants.dart';
import '../core/media/photo_service.dart';
import '../core/models/models.dart';
import '../core/avatars.dart';
import '../core/storage/last_room_repository.dart';
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
    this.timelineSubmitted = false,
    this.timelineGuesses = 0,
    this.lockedTimelineYear,
    this.lockedTimelineMonth,
    this.lastTimelineReveal,
    this.versionWarning,
    this.versionWarningDismissed = false,
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
  final bool timelineSubmitted;
  final int timelineGuesses;
  final int? lockedTimelineYear;
  final int? lockedTimelineMonth;
  final TimelineReveal? lastTimelineReveal;
  final VersionWarning? versionWarning;
  final bool versionWarningDismissed;

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
    bool? timelineSubmitted,
    int? timelineGuesses,
    int? lockedTimelineYear,
    int? lockedTimelineMonth,
    TimelineReveal? lastTimelineReveal,
    VersionWarning? versionWarning,
    bool? versionWarningDismissed,
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

  String get _noDatedPhotosMessage =>
      'No photos with a date found. Allow another album or pick a different mode.';

  final StreamController<MatchUiState> _states =
      StreamController<MatchUiState>.broadcast();
  final Map<String, List<PhotoCandidate>> _remotePhotos =
      <String, List<PhotoCandidate>>{};
  final Map<String, Uint8List> _assembledHostBytes = <String, Uint8List>{};
  final Map<String, Uint8List> _clientRoundPhotos = <String, Uint8List>{};
  final Map<String, PhotoChunkAssembler> _assemblers =
      <String, PhotoChunkAssembler>{};
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  final List<Timer> _timers = <Timer>[];

  MatchUiState _state = const MatchUiState();
  AppSettings _settingsValue = const AppSettings();
  HostGameEngine? _engine;
  HostTransport? _hostTransport;
  ClientTransport? _clientTransport;

  Timer? _roundTimer;
  Timer? _countdownTicker;
  Timer? _extendTicker;
  Timer? _captionRevealTimer;
  Timer? _timelineRevealTimer;
  Timer? _clientPhaseTicker;
  final Map<String, int> _clientBuilds = <String, int>{};
  final Map<String, String> _clientVersions = <String, String>{};
  String? _pendingInviteUrl;
  String? _pendingRoomId;
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

  Future<void> hostMatch({MatchConfig config = const MatchConfig()}) async {
    _emit(_state.copyWith(loadingMessage: 'Starting match', clearError: true));
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
    } on Object catch (error) {
      _emit(
        _state.copyWith(
          errorMessage: 'Could not open the match: $error',
          clearLoading: true,
        ),
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
        config: config,
        connectionMode: ConnectionMode.localLan,
        clearLoading: true,
      ),
    );
    await _broadcastLobby();
  }

  final List<String> _lanAddresses = const <String>[];

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
        entry.key,
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
        _remotePhotos.remove(clientId);
        _clientBuilds.remove(clientId);
        _clientVersions.remove(clientId);
        _engine?.removePlayer(clientId);
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
            id: clientId,
            name: name,
            avatar: normalizeAvatar(payload['avatar'] as String?),
            avatarColorIndex: payload['avatarColorIndex'] as int? ?? 0,
          );
        } on EngineException {
          // A reconnect keeps the existing player object.
        }
        final build = payload['appBuild'];
        if (build is int) {
          _clientBuilds[clientId] = build;
          _clientVersions[clientId] = payload['appVersion'] as String? ?? '';
        }
        _emit(_state.copyWith(players: engine.players));
        await _hostTransport?.sendToClient(
          clientId,
          WireMessage(
            type: WireType.joinAck,
            seq: _nextSeq(),
            payload: <String, dynamic>{'playerId': clientId},
          ),
        );
        await _broadcastLobby();
        await _sendVersionWarnings();
      case WireType.submitPhotoMeta:
        final photos = <PhotoCandidate>[];
        for (final entry in (payload['photos'] as List<dynamic>? ?? const [])) {
          if (entry is Map<String, dynamic>) {
            photos.add(PhotoCandidate.fromJson(entry));
          }
        }
        _remotePhotos[clientId] = photos;
      case WireType.photoChunk:
        final chunk = PhotoChunk.fromJson(payload);
        final assembler = _assemblers.putIfAbsent(
          clientId,
          PhotoChunkAssembler.new,
        );
        final bytes = assembler.add(chunk);
        if (bytes != null) {
          _assembledHostBytes['$clientId:${chunk.photoId}'] = bytes;
          final photos = _remotePhotos[clientId];
          if (photos != null) {
            for (var i = 0; i < photos.length; i++) {
              if (photos[i].photoId == chunk.photoId) {
                photos[i] = photos[i].copyWith(bytes: bytes);
              }
            }
          }
        }
      case WireType.playerReady:
        final approved = _remotePhotos[clientId];
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
          engine.submitInitialPhotos(clientId, approved);
          engine.markReady(clientId);
        } on EngineException {
          return;
        }
        await _afterReadinessChanged();
        if (engine.phase == RoundPhase.preparing) {
          await _broadcastLobby();
        }
      case WireType.plantPhoto:
        final photo = PhotoCandidate.fromJson(
          payload['photo'] as Map<String, dynamic>,
        );
        var assembled = _assembledHostBytes['$clientId:${photo.photoId}'];
        if (assembled == null) {
          for (final candidate
              in _remotePhotos[clientId] ?? const <PhotoCandidate>[]) {
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
          engine.plantSecretPhoto(clientId, hydrated);
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
        final playerId = payload['playerId'] as String? ?? clientId;
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
        _onRemoteScreenshot(clientId, payload);
      case WireType.extendSubmit:
        final photos = <PhotoCandidate>[];
        for (final entry in (payload['photos'] as List<dynamic>? ?? const [])) {
          if (entry is Map<String, dynamic>) {
            final photo = PhotoCandidate.fromJson(entry);
            final assembled = _assembledHostBytes['$clientId:${photo.photoId}'];
            photos.add(
              assembled == null ? photo : photo.copyWith(bytes: assembled),
            );
          }
        }
        try {
          _engineExtend(photos, clientId);
        } on EngineException {
          return;
        }
        await _maybeCommitExtension();
      case WireType.captionSubmit:
        try {
          engine.submitCaption(clientId, payload['text'] as String? ?? '');
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
            clientId,
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
      case WireType.timelineSubmit:
        try {
          engine.submitTimelineGuess(
            playerId: clientId,
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

  void _onRemoteScreenshot(String clientId, Map<String, dynamic> payload) {
    final engine = _engine;
    if (engine == null) return;
    engine.recordScreenshot(clientId);
    _rememberScreenshot(clientId, engine);
    unawaited(
      _hostTransport?.broadcast(
        WireMessage(
          type: WireType.screenshotAlert,
          seq: _nextSeq(),
          payload: <String, dynamic>{
            'playerId': clientId,
            'playerName': engine.player(clientId)?.name ?? 'Player',
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
      _emit(
        _state.copyWith(
          errorMessage: error.code == 'too_few_players'
              ? 'One more player has to scan the QR code before the match starts'
              : error.message,
        ),
      );
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
    if (bytes != null) {
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
        case GameMode.timeTraveler:
          unawaited(_finishTimelineRound());
      }
    });
    _tickPhaseProgress(duration, engine.phase);
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
          if (engine.allCaptionsSubmitted) {
            timer.cancel();
            unawaited(_startCaptionVoting());
          }
        case RoundPhase.captionVoting:
          if (engine.allCaptionVotesSubmitted) {
            timer.cancel();
            unawaited(_finishCaptionRound());
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

  Future<void> _startCaptionVoting() async {
    final engine = _engine;
    if (engine == null || engine.phase != RoundPhase.captionWriting) return;
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
      await _hostTransport?.sendToClient(
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
    if (engine.phase != RoundPhase.captionWriting &&
        engine.phase != RoundPhase.captionVoting) {
      return;
    }
    _roundTimer?.cancel();
    _countdownTicker?.cancel();
    final reveal = engine.finishCaptionRound();
    unawaited(HapticFeedback.mediumImpact());
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
    unawaited(HapticFeedback.mediumImpact());
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
      _emit(_state.copyWith(errorMessage: error.message));
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    unawaited(SystemSound.play(SystemSoundType.click));
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
      _emit(_state.copyWith(errorMessage: error.message));
      return;
    }
    unawaited(HapticFeedback.selectionClick());
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
      _emit(_state.copyWith(errorMessage: error.message));
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    unawaited(SystemSound.play(SystemSoundType.click));
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
    unawaited(HapticFeedback.mediumImpact());
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
      await _stopScreenshots();
      _emit(
        _state.copyWith(
          phase: RoundPhase.podium,
          awards: awards,
          players: engine.players,
          hostDeciding: true,
          activePhotoBytes: null,
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
    await _hostTransport?.sendToClient(
      playerId,
      WireMessage(
        type: WireType.kick,
        seq: _nextSeq(),
        payload: <String, dynamic>{'reason': 'removed'},
      ),
    );
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
      _emit(
        _state.copyWith(
          errorMessage: 'Photo access is off. Allow photos in Settings, then start the photo check.',
        ),
      );
      return;
    }
    try {
      engine.startPrepare();
    } on EngineException catch (error) {
      _emit(_state.copyWith(errorMessage: error.message));
      return;
    }
    _emit(
      _state.copyWith(
        phase: RoundPhase.preparing,
        photosNeeded: engine.photosNeeded,
        plantEligible: engine.isPlanter('host'),
        loadingMessage: 'Reading your photos',
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
      await _hostTransport?.sendToClient(
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
      _emit(_state.copyWith(errorMessage: error.message));
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
      _emit(_state.copyWith(errorMessage: error.message));
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
    unawaited(HapticFeedback.selectionClick());
    unawaited(SystemSound.play(SystemSoundType.click));
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
      _emit(_state.copyWith(errorMessage: error.message));
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
    await _stopScreenshots();
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
        },
      ),
    );
    _emit(_state.copyWith(players: engine.players, config: engine.config));
  }

  Future<void> joinMatch(String rawInvite) async {
    _pendingInviteUrl = null;
    _pendingRoomId = null;
    _emit(_state.copyWith(loadingMessage: 'Joining match', clearError: true));
    final InvitePayload invite;
    try {
      invite = tryParseInvite(rawInvite);
    } on InvalidInviteException catch (error) {
      _emit(
        _state.copyWith(
          errorMessage: 'That invite is not valid: ${error.reason}',
          clearLoading: true,
        ),
      );
      return;
    }

    _pendingInviteUrl = encodeInviteUrl(invite, baseUrl: kInviteBaseUrl);
    _pendingRoomId = invite.roomId;
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
          errorMessage: 'Online relay is used up for today. Join the same Wi-Fi or a hotspot to keep playing.',
          clearLoading: true,
        ),
      );
      return;
    } on Object catch (error) {
      _emit(
        _state.copyWith(
          errorMessage: 'Could not reach the host: $error',
          clearLoading: true,
        ),
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
    _subscriptions.add(transport.messages.listen(_handleClientMessage));
    _subscriptions.add(
      transport.disconnected.listen(
        (_) => unawaited(_endOnHostLeave()),
        onDone: () => unawaited(_endOnHostLeave()),
      ),
    );
  }

  Future<void> _endOnHostLeave() async {
    if (_leaving || _endingOnHostLeave) return;
    _endingOnHostLeave = true;
    await leaveMatch();
    _endingOnHostLeave = false;
    _emit(
      _state.copyWith(
        errorMessage:
            'The host ended the room. Scan a new QR or host your own game.',
      ),
    );
  }

  Future<void> _handleClientMessage(WireMessage message) async {
    final payload = message.payload;
    switch (message.type) {
      case WireType.joinAck:
        final inviteUrl = _pendingInviteUrl;
        final roomId = _pendingRoomId;
        if (inviteUrl != null && roomId != null) {
          unawaited(
            _lastRooms.remember(
              LastRoom(
                inviteUrl: inviteUrl,
                roomId: roomId,
                joinedAtUtc: DateTime.now().toUtc(),
              ),
            ),
          );
        }
        _emit(_state.copyWith(localPlayerId: payload['playerId'] as String?));
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
      case WireType.kick:
        final reason = payload['reason'] as String?;
        await leaveMatch();
        _emit(
          _state.copyWith(
            errorMessage: reason == 'started'
                ? 'That room already started. Ask the host to open the lobby again.'
                : 'The host removed you from the room.',
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
        _emit(
          _state.copyWith(
            players: players,
            config: config is Map<String, dynamic>
                ? MatchConfig.fromJson(config)
                : _state.config,
            phase: parsedPhase,
            plantUnlocked: plantUnlocked,
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
          _emit(
            _state.copyWith(
              errorMessage: 'Photo access is off. Allow photos in Settings, then tap Reroll all.',
            ),
          );
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
            activeRoundOptions: options,
            clearGuess: true,
            clearRoundInput: true,
            lockedGuessOwnerId: null,
          ),
        );
        _startClientPhaseTicker(payload['durationMs'] as int? ?? 0);
      case WireType.roundReveal:
        _stopClientPhaseTicker();
        unawaited(HapticFeedback.mediumImpact());
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
        unawaited(HapticFeedback.mediumImpact());
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
      case WireType.timelineReveal:
        _stopClientPhaseTicker();
        unawaited(HapticFeedback.mediumImpact());
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
          playerName: payload['playerName'] as String? ?? 'Player',
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
        unawaited(HapticFeedback.heavyImpact());
        final awards = <MatchAward>[
          for (final entry in (payload['awards'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) MatchAward.fromJson(entry),
        ];
        final players = <Player>[
          for (final entry
              in (payload['players'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) Player.fromJson(entry),
        ];
        await _stopScreenshots();
        _assembledHostBytes.clear();
        _clientRoundPhotos.clear();
        _emit(
          _state.copyWith(
            phase: RoundPhase.podium,
            awards: awards,
            players: players,
            activePhotoBytes: null,
          ),
        );
      case WireType.plantPhoto:
        if (payload['accepted'] == true) {
          _emit(_state.copyWith(plantUsed: true));
        }
      case WireType.errorNotice:
        _emit(
          _state.copyWith(
            errorMessage: payload['code'] as String? ?? 'The host refused that',
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
    unawaited(HapticFeedback.selectionClick());
    unawaited(SystemSound.play(SystemSoundType.click));
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
    unawaited(HapticFeedback.selectionClick());
    unawaited(SystemSound.play(SystemSoundType.click));
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
    unawaited(HapticFeedback.selectionClick());
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
    unawaited(HapticFeedback.selectionClick());
    unawaited(SystemSound.play(SystemSoundType.click));
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
    const sharingPhases = <RoundPhase>{
      RoundPhase.guessing,
      RoundPhase.reveal,
      RoundPhase.captionWriting,
      RoundPhase.captionVoting,
      RoundPhase.captionReveal,
      RoundPhase.timelineGuessing,
      RoundPhase.timelineReveal,
    };
    if (!sharingPhases.contains(_state.phase)) {
      return;
    }
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
    return nickname.isEmpty ? 'Player' : nickname;
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
    _remotePhotos.clear();
    _assemblers.clear();
    _assembledHostBytes.clear();
    _clientRoundPhotos.clear();
    _clientBuilds.clear();
    _clientVersions.clear();
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
