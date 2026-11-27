import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart' show PermissionState;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/audio/game_audio_service.dart';
import '../core/audio/soundboard_service.dart';
import '../core/constants.dart';
import '../core/diagnostics/bug_report_service.dart';
import '../core/media/photo_memory_cache.dart';
import '../core/media/photo_service.dart';
import '../core/models/models.dart';
import '../core/avatars.dart';
import '../core/storage/last_room_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/platform/screenshot_detector.dart';
import '../core/party_pass/room_theme.dart';
import '../core/party_pass/sound_effect.dart';
import '../core/party_pass/turn_relay_client.dart';
import '../core/playtest_config.dart';
import '../core/protocol/wire_message.dart';
import '../core/version.dart';
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
    this.photoId = '',
    this.isOwn = false,
    this.authorId,
    this.authorName,
    this.photoOwnerId,
    this.photoOwnerName,
    this.upVotes = 0,
    this.mehVotes = 0,
    this.downVotes = 0,
    this.points = 0,
    this.isWinner = false,
    this.isSabotage = false,
    this.strokes = const <SabotageStroke>[],
    this.stickers = const <SabotageSticker>[],
  });

  final String id;
  final String photoBase64;
  final String photoId;
  final MemeTemplate template;
  final String topText;
  final String bottomText;
  final double snapY;
  final bool isOwn;
  final String? authorId;
  final String? authorName;
  final String? photoOwnerId;
  final String? photoOwnerName;
  final int upVotes;
  final int mehVotes;
  final int downVotes;
  final int points;
  final bool isWinner;
  final bool isSabotage;
  final List<SabotageStroke> strokes;
  final List<SabotageSticker> stickers;

  MemeCard copyWith({bool? isOwn, bool? isWinner, String? photoBase64}) =>
      MemeCard(
        id: id,
        photoBase64: photoBase64 ?? this.photoBase64,
        photoId: photoId,
        template: template,
        topText: topText,
        bottomText: bottomText,
        snapY: snapY,
        isOwn: isOwn ?? this.isOwn,
        authorId: authorId,
        authorName: authorName,
        photoOwnerId: photoOwnerId,
        photoOwnerName: photoOwnerName,
        upVotes: upVotes,
        mehVotes: mehVotes,
        downVotes: downVotes,
        points: points,
        isWinner: isWinner ?? this.isWinner,
        isSabotage: isSabotage,
        strokes: strokes,
        stickers: stickers,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'photoBase64': photoBase64,
    'photoId': photoId,
    'template': template.name,
    'topText': topText,
    'bottomText': bottomText,
    'snapY': snapY,
    'isOwn': isOwn,
    'authorId': authorId,
    'authorName': authorName,
    'photoOwnerId': photoOwnerId,
    'photoOwnerName': photoOwnerName,
    'upVotes': upVotes,
    'mehVotes': mehVotes,
    'downVotes': downVotes,
    'points': points,
    'isWinner': isWinner,
    'isSabotage': isSabotage,
    'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
    'stickers': stickers.map((sticker) => sticker.toJson()).toList(),
  };

  factory MemeCard.fromJson(Map<String, dynamic> json) => MemeCard(
    id: json['id'] as String? ?? '',
    photoBase64: json['photoBase64'] as String? ?? '',
    photoId: json['photoId'] as String? ?? '',
    template: MemeTemplate.values.firstWhere(
      (value) => value.name == json['template'],
      orElse: () => MemeTemplate.classic,
    ),
    topText: json['topText'] as String? ?? '',
    bottomText: json['bottomText'] as String? ?? '',
    snapY: (json['snapY'] as num?)?.toDouble() ?? 48,
    isOwn: json['isOwn'] as bool? ?? false,
    authorId: json['authorId'] as String?,
    authorName: json['authorName'] as String?,
    photoOwnerId: json['photoOwnerId'] as String?,
    photoOwnerName: json['photoOwnerName'] as String?,
    upVotes: json['upVotes'] as int? ?? 0,
    mehVotes: json['mehVotes'] as int? ?? 0,
    downVotes: json['downVotes'] as int? ?? 0,
    points: json['points'] as int? ?? 0,
    isWinner: json['isWinner'] as bool? ?? false,
    isSabotage: json['isSabotage'] as bool? ?? false,
    strokes: (json['strokes'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(SabotageStroke.fromJson)
        .toList(growable: false),
    stickers: (json['stickers'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(SabotageSticker.fromJson)
        .toList(growable: false),
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
    this.forceStartAvailable = false,
    this.plantUsed = false,
    this.plantUnlocked = false,
    this.plantEligible = false,
    this.currentRound = 0,
    this.totalRounds = 0,
    this.isFinalDoubleRound = false,
    this.remainingMs = 0,
    this.phaseDurationMs = 0,
    this.activePhotoBytes,
    this.activePhotoId,
    this.activePhotoIsPanorama = false,
    this.avatarPhotos = const <String, String>{},
    this.activeRoundOptions = const <Player>[],
    this.lockedGuessOwnerId,
    this.lastGuessCorrect,
    this.lockedGuessScale,
    this.zoomAnchorX = 0.5,
    this.zoomAnchorY = 0.5,
    this.lastReveal,
    this.awards = const <MatchAward>[],
    this.screenshotAlerts = const <ScreenshotBanner>[],
    this.extensionSecondsLeft = 0,
    this.extensionCandidates = const <PhotoCandidate>[],
    this.extensionApproved = false,
    this.loadingMessage,
    this.vaultSyncReceived = 0,
    this.vaultSyncTotal = 0,
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
    this.memeFocusId,
    this.memeFocusIndex = 0,
    this.memeFocusCount = 0,
    this.memeFocusVotes = 0,
    this.memeFocusEligible = 0,
    this.memeFocusVoterIds = const <String>{},
    this.memeTallying = false,
    this.memeTallyUp = 0,
    this.memeTallyMeh = 0,
    this.memeTallyDown = 0,
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
    this.waitingForMatch = false,
    this.waitingPlayersCount = 0,
    this.reconnectSecondsLeft = 0,
    this.roomThemeId = kDefaultRoomThemeId,
    this.lastSoundEffect,
    this.firewallPrompt = false,
    this.firewallRelayAttempted = false,
    this.firewallRelayErrorCode,
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
  final bool forceStartAvailable;
  final bool plantUsed;
  final bool plantUnlocked;
  final bool plantEligible;
  final int currentRound;
  final int totalRounds;
  final int remainingMs;
  final int phaseDurationMs;
  final Uint8List? activePhotoBytes;
  final String? activePhotoId;
  final bool activePhotoIsPanorama;

  /// Player id to a small base64 JPEG avatar. Kept out of Player so the
  /// round payload stays light.
  final Map<String, String> avatarPhotos;
  final List<Player> activeRoundOptions;
  final String? lockedGuessOwnerId;

  /// True when the local Zoom-Out guess was right, false when the player is
  /// locked out for the rest of the round. Null before a guess.
  final bool? lastGuessCorrect;

  /// The zoom level frozen when this phone locked its guess.
  final double? lockedGuessScale;
  final double zoomAnchorX;
  final double zoomAnchorY;
  final RoundReveal? lastReveal;
  final List<MatchAward> awards;
  final List<ScreenshotBanner> screenshotAlerts;
  final int extensionSecondsLeft;
  final List<PhotoCandidate> extensionCandidates;
  final bool extensionApproved;
  final String? loadingMessage;

  /// Non-zero while a Make It Meme round waits for every assigned vault photo.
  final int vaultSyncReceived;
  final int vaultSyncTotal;

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

  /// The one meme the whole room is looking at. The host owns this pointer so
  /// every phone stays on the same card.
  final String? memeFocusId;
  final int memeFocusIndex;
  final int memeFocusCount;
  final int memeFocusVotes;
  final int memeFocusEligible;
  final Set<String> memeFocusVoterIds;
  final bool memeTallying;
  final int memeTallyUp;
  final int memeTallyMeh;
  final int memeTallyDown;
  final MemeReveal? lastMemeReveal;
  final List<MemeCard> memeRevealCards;
  final List<MemeCard> topMemes;
  final bool timelineSubmitted;
  final int timelineGuesses;
  final int? lockedTimelineYear;
  final int? lockedTimelineMonth;
  final TimelineReveal? lastTimelineReveal;
  final bool isFinalDoubleRound;
  final VersionWarning? versionWarning;
  final bool versionWarningDismissed;
  final bool reconnecting;
  final int reconnectSecondsLeft;

  /// A player who scanned the QR while a match was running. They are held in
  /// the room, see a clean waiting screen, and join the next match with a
  /// normal photo check instead of desynchronising the active round.
  final bool waitingForMatch;
  final int waitingPlayersCount;

  /// Shared premium theme selected by a Party Pass holder. Applies to every
  /// phone for the duration of the match.
  final String roomThemeId;
  final SoundEffectEvent? lastSoundEffect;

  /// A direct connection failed and no relay was available. The UI explains
  /// the free Wi-Fi/hotspot route and the Party Pass relay.
  final bool firewallPrompt;
  final bool firewallRelayAttempted;
  final String? firewallRelayErrorCode;

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
    bool? forceStartAvailable,
    bool? plantUsed,
    bool? plantUnlocked,
    bool? plantEligible,
    int? currentRound,
    int? totalRounds,
    bool? isFinalDoubleRound,
    int? remainingMs,
    int? phaseDurationMs,
    Uint8List? activePhotoBytes,
    String? activePhotoId,
    bool? activePhotoIsPanorama,
    Map<String, String>? avatarPhotos,
    List<Player>? activeRoundOptions,
    String? lockedGuessOwnerId,
    bool? lastGuessCorrect,
    double? lockedGuessScale,
    double? zoomAnchorX,
    double? zoomAnchorY,
    RoundReveal? lastReveal,
    List<MatchAward>? awards,
    List<ScreenshotBanner>? screenshotAlerts,
    int? extensionSecondsLeft,
    List<PhotoCandidate>? extensionCandidates,
    bool? extensionApproved,
    String? loadingMessage,
    int? vaultSyncReceived,
    int? vaultSyncTotal,
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
    String? memeFocusId,
    int? memeFocusIndex,
    int? memeFocusCount,
    int? memeFocusVotes,
    int? memeFocusEligible,
    Set<String>? memeFocusVoterIds,
    bool? memeTallying,
    int? memeTallyUp,
    int? memeTallyMeh,
    int? memeTallyDown,
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
    bool? waitingForMatch,
    int? waitingPlayersCount,
    String? roomThemeId,
    SoundEffectEvent? lastSoundEffect,
    bool? firewallPrompt,
    bool? firewallRelayAttempted,
    String? firewallRelayErrorCode,
    bool clearFirewallError = false,
    bool clearMemeFocus = false,
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
    forceStartAvailable: forceStartAvailable ?? this.forceStartAvailable,
    plantUsed: plantUsed ?? this.plantUsed,
    plantUnlocked: plantUnlocked ?? this.plantUnlocked,
    plantEligible: plantEligible ?? this.plantEligible,
    currentRound: currentRound ?? this.currentRound,
    totalRounds: totalRounds ?? this.totalRounds,
    isFinalDoubleRound: isFinalDoubleRound ?? this.isFinalDoubleRound,
    remainingMs: remainingMs ?? this.remainingMs,
    phaseDurationMs: phaseDurationMs ?? this.phaseDurationMs,
    activePhotoBytes: activePhotoBytes ?? this.activePhotoBytes,
    activePhotoId: activePhotoId ?? this.activePhotoId,
    activePhotoIsPanorama: activePhotoIsPanorama ?? this.activePhotoIsPanorama,
    avatarPhotos: avatarPhotos ?? this.avatarPhotos,
    activeRoundOptions: activeRoundOptions ?? this.activeRoundOptions,
    lockedGuessOwnerId: clearGuess
        ? null
        : (lockedGuessOwnerId ?? this.lockedGuessOwnerId),
    lastGuessCorrect: clearGuess
        ? null
        : (lastGuessCorrect ?? this.lastGuessCorrect),
    lockedGuessScale: clearGuess
        ? null
        : (lockedGuessScale ?? this.lockedGuessScale),
    zoomAnchorX: zoomAnchorX ?? this.zoomAnchorX,
    zoomAnchorY: zoomAnchorY ?? this.zoomAnchorY,
    lastReveal: lastReveal ?? this.lastReveal,
    awards: awards ?? this.awards,
    screenshotAlerts: screenshotAlerts ?? this.screenshotAlerts,
    extensionSecondsLeft: extensionSecondsLeft ?? this.extensionSecondsLeft,
    extensionCandidates: extensionCandidates ?? this.extensionCandidates,
    extensionApproved: extensionApproved ?? this.extensionApproved,
    loadingMessage: clearLoading
        ? null
        : (loadingMessage ?? this.loadingMessage),
    vaultSyncReceived: vaultSyncReceived ?? this.vaultSyncReceived,
    vaultSyncTotal: vaultSyncTotal ?? this.vaultSyncTotal,
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
    memeFocusId: clearMemeFocus
        ? null
        : clearRoundInput
        ? memeFocusId
        : (memeFocusId ?? this.memeFocusId),
    memeFocusIndex: clearRoundInput
        ? (memeFocusIndex ?? 0)
        : (memeFocusIndex ?? this.memeFocusIndex),
    memeFocusCount: clearRoundInput
        ? (memeFocusCount ?? 0)
        : (memeFocusCount ?? this.memeFocusCount),
    memeFocusVotes: clearRoundInput
        ? (memeFocusVotes ?? 0)
        : (memeFocusVotes ?? this.memeFocusVotes),
    memeFocusEligible: clearRoundInput
        ? (memeFocusEligible ?? 0)
        : (memeFocusEligible ?? this.memeFocusEligible),
    memeFocusVoterIds: clearRoundInput
        ? (memeFocusVoterIds ?? const <String>{})
        : (memeFocusVoterIds ?? this.memeFocusVoterIds),
    memeTallying: clearRoundInput
        ? (memeTallying ?? false)
        : (memeTallying ?? this.memeTallying),
    memeTallyUp: clearRoundInput
        ? (memeTallyUp ?? 0)
        : (memeTallyUp ?? this.memeTallyUp),
    memeTallyMeh: clearRoundInput
        ? (memeTallyMeh ?? 0)
        : (memeTallyMeh ?? this.memeTallyMeh),
    memeTallyDown: clearRoundInput
        ? (memeTallyDown ?? 0)
        : (memeTallyDown ?? this.memeTallyDown),
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
    waitingForMatch: waitingForMatch ?? this.waitingForMatch,
    waitingPlayersCount: waitingPlayersCount ?? this.waitingPlayersCount,
    reconnectSecondsLeft: reconnectSecondsLeft ?? this.reconnectSecondsLeft,
    roomThemeId: roomThemeId ?? this.roomThemeId,
    lastSoundEffect: lastSoundEffect ?? this.lastSoundEffect,
    firewallPrompt: firewallPrompt ?? this.firewallPrompt,
    firewallRelayAttempted:
        firewallRelayAttempted ?? this.firewallRelayAttempted,
    firewallRelayErrorCode: clearFirewallError
        ? null
        : (firewallRelayErrorCode ?? this.firewallRelayErrorCode),
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
    this.platformServices = true,
    this.turnRelay,
    this.wakeLock,
    this.planterOverride,
    this.photoCompressor,
    this.appVersion = kAppVersion,
    this.appBuild = kAppBuildNumber,
    this.playerIdOverride,
    this.playerTokenOverride,
    this.reconnectAttemptDelay = Duration.zero,
    Duration? roundDuration,
    this.countdownDuration = const Duration(seconds: 3),
    this.vaultFallbackDelay = const Duration(seconds: 10),
    this.revealDuration = const Duration(seconds: 6),
    this.captionRevealDuration = const Duration(seconds: 10),
    this.memeTallyDuration = const Duration(milliseconds: 2500),
    Duration? sabotageDuration,
    this.emptyMemeAdvanceDuration = const Duration(milliseconds: 2500),
    this.timelineRevealDuration = const Duration(seconds: 10),
    this.extendWindow = const Duration(seconds: 10),
  }) : _settings = settings ?? SettingsRepository(),
       _lastRooms = lastRooms ?? LastRoomRepository(),
       _connector = connector ?? HybridConnector(turnRelay: turnRelay),
       _screenshots = screenshots ?? ScreenshotDetector(),
       _roundDurationOverride = roundDuration,
       _sabotageDurationOverride = sabotageDuration;

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

  /// Off for the offline demo. Screenshot detection and the wake lock are
  /// platform services that can stall on a device without the native bridge;
  /// the demo must still open.
  final bool platformServices;

  /// Supplies verified Party Pass relay credentials when one is available.
  final Future<TurnRelayAttempt> Function()? turnRelay;

  /// Injectable in tests so a widget test does not wait on a platform channel.
  final Future<void> Function(bool awake)? wakeLock;

  /// Test seam for the randomly assigned planter.
  final String? planterOverride;

  /// Test seam for relayed photo compression; production uses the codec.
  final PhotoCompressor? photoCompressor;

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
  final Duration vaultFallbackDelay;
  final Duration revealDuration;
  final Duration captionRevealDuration;
  final Duration memeTallyDuration;

  /// Drawing window for Foto-Sabotage, overridden in fast simulation tests.
  final Duration? _sabotageDurationOverride;
  final Duration emptyMemeAdvanceDuration;
  final Duration timelineRevealDuration;
  final Duration extendWindow;

  Duration get sabotageDuration =>
      _sabotageDurationOverride ??
      Duration(seconds: (_engine?.config ?? _state.config).pace.sabotageSeconds);

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
  final Map<String, Set<String>> _pendingMemeAssignments =
      <String, Set<String>>{};
  final Map<String, int> _photoRequestAttempts = <String, int>{};
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
  Timer? _revealAutoTimer;
  Timer? _countdownTicker;
  Timer? _vaultWatchdog;
  Timer? _clientReadyRetry;
  DateTime? _preparingSince;
  bool _startingMatch = false;
  bool _vaultPreloaded = false;
  Timer? _extendTicker;
  Timer? _captionRevealTimer;
  Timer? _timelineRevealTimer;
  Timer? _memeTallyTimer;
  Timer? _memesEmptyAdvanceTimer;
  List<String> _memeFocusOrder = <String>[];
  int _memeFocusIndex = 0;
  bool _memeTallying = false;
  Timer? _clientPhaseTicker;
  Timer? _reconnectTimer;
  Completer<void>? _reconnectAck;
  bool _reconnectInFlight = false;
  bool _hostClosed = false;
  final Map<String, String> _clientPlayerIds = <String, String>{};
  final Map<String, String> _playerClientIds = <String, String>{};
  final Map<String, String> _playerTokens = <String, String>{};
  final Map<String, Player> _waitingPlayers = <String, Player>{};
  final Map<String, String> _waitingClientIds = <String, String>{};
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
  bool _partyPassActive = false;
  final Set<String> _partyPassPlayers = <String>{};
  final SoundboardGate _localSoundGate = SoundboardGate();
  final SoundboardGate _remoteSoundGate = SoundboardGate();

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

  /// Changes the local player's sticker or selfie while a room is open. The
  /// host patches the player and rebroadcasts the lobby; a guest asks the host.
  Future<void> setLocalAvatar(String avatar, String? photoBase64) async {
    final normalized = normalizeAvatar(avatar);
    _settingsValue = _settingsValue.copyWith(
      avatar: normalized,
      avatarPhoto: photoBase64,
      clearAvatarPhoto: photoBase64 == null,
    );
    await _settings.save(_settingsValue);
    final localId = _state.localPlayerId;
    if (localId == null) return;
    if (_state.isHosting) {
      final player = _engine?.player(localId);
      if (player != null) player.avatar = normalized;
      if (photoBase64 != null && photoBase64.isNotEmpty) {
        _avatarPhotos[localId] = photoBase64;
      } else {
        _avatarPhotos.remove(localId);
      }
      _emit(
        _state.copyWith(
          players: _engine?.players ?? _state.players,
          avatarPhotos: Map<String, String>.unmodifiable(_avatarPhotos),
        ),
      );
      await _broadcastLobby();
      return;
    }
    await _clientTransport?.send(
      WireMessage(
        type: WireType.avatarUpdate,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'avatar': normalized,
          'avatarPhoto': photoBase64 ?? '',
        },
      ),
    );
    _emit(
      _state.copyWith(
        avatarPhotos: <String, String>{
          ..._state.avatarPhotos,
          if (photoBase64 != null && photoBase64.isNotEmpty)
            localId: photoBase64
          else
            localId: '',
        },
        players: <Player>[
          for (final player in _state.players)
            player.id == localId
                ? (Player.fromJson(player.toJson())..avatar = normalized)
                : player,
        ],
      ),
    );
  }

  /// The local Party Pass decides whether this phone may start sound effects
  /// and premium themes. The relay is still verified server-side per request.
  void updatePartyPass({required bool active}) {
    final wasActive = _partyPassActive;
    _partyPassActive = active;
    if (wasActive != active) {
      _sendPartyPassClaim();
    }
    if (wasActive && !active) {
      _localSoundGate.clear();
      _remoteSoundGate.clear();
      if (_state.roomThemeId != RoomThemeIds.classicParty && _state.isHosting) {
        unawaited(_applyRoomTheme(RoomThemeId.classicParty, broadcast: true));
      }
    }
  }

  bool get partyPassActive => _partyPassActive;

  /// Tells the host that this client's cosmetic pass state changed after the
  /// initial handshake, for example when a purchase completes in the lobby.
  void _sendPartyPassClaim() {
    if (_state.isHosting || _clientTransport == null) return;
    if (_state.localPlayerId == null) return;
    unawaited(
      _clientTransport!.send(
        WireMessage(
          type: WireType.partyPass,
          seq: _nextSeq(),
          payload: <String, dynamic>{'active': _partyPassActive},
        ),
      ),
    );
  }

  void dismissFirewallPrompt() {
    if (!_state.firewallPrompt && _state.firewallRelayErrorCode == null) {
      return;
    }
    _emit(_state.copyWith(firewallPrompt: false, clearFirewallError: true));
  }

  Future<void> retryPendingJoin() async {
    final invite = _pendingInviteUrl;
    if (invite == null) {
      dismissFirewallPrompt();
      return;
    }
    await joinMatch(invite);
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
    PhotoMemoryCache.instance.clear();
    _vaultPreloaded = false;
    _partyPassPlayers.clear();
    _clientPlayerIds.clear();
    _playerClientIds.clear();
    _playerTokens.clear();
    _waitingPlayers.clear();
    _waitingClientIds.clear();
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
    final playtest = PlaytestConfig.enabled;
    final local =
        injected ??
        (playtest
            ? null
            : LocalWsHostTransport(
                roomId: roomId,
                secret: secret,
                advertiser: BonsoirMdnsAdvertiser(),
              ));

    if (local != null) {
      try {
        await local.start();
      } on Object {
        _emit(
          _state.copyWith(
            errorMessage: _l10n.errorOpenRoom,
            clearLoading: true,
          ),
        );
        return;
      }
    }

    final lanAddresses = local is LocalWsHostTransport
        ? await local.refreshLanAddresses()
        : const <String>[];
    final lan = <String>[
      if (local?.localLanEndpoint != null) local!.localLanEndpoint!,
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
      hostName: _displayName,
    );

    // Online players are optional, except in the browser playtest, which has
    // no LAN sockets and therefore uses the local signaling relay directly.
    final online = includeOnlineTransport
        ? WebRtcHostTransport(
            invite: invite,
            iceClient: SignalingIceClient(
              signalingUrl: invite.signalingUrl!,
              turnRelay: turnRelay,
            ),
            settings: _settingsValue,
          )
        : null;
    final transport =
        injected ??
        (playtest
            ? (online ?? const _UnavailableHostTransport())
            : CompositeHostTransport(<HostTransport>[
                local!,
                if (online != null) BestEffortHostTransport(online),
              ]));
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
    await _startPlatformServices();

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
    final relayed = _hostTransport?.isRelayed(clientId) ?? false;
    final payload = relayed
        ? await _compressPhoto(
            bytes,
            maxDimension: kRelayPhotoDimension,
            quality: kRelayPhotoQuality,
          )
        : bytes;
    for (final chunk in PhotoChunker.split(photoId, payload)) {
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

  Future<Uint8List> _compressPhoto(
    Uint8List bytes, {
    required int maxDimension,
    required int quality,
  }) {
    final compressor = photoCompressor;
    if (compressor != null) {
      return compressor(bytes, maxDimension: maxDimension, quality: quality);
    }
    return compressPhotoBytes(
      bytes,
      maxDimension: maxDimension,
      quality: quality,
    );
  }

  /// Sends one copy of the round photo to direct peers and a smaller copy to
  /// peers whose path relays through TURN.
  Future<void> _sendRoundPhoto(
    HostTransport transport,
    String photoId,
    Uint8List bytes,
  ) async {
    final relayed = <String>[];
    final direct = <String>[];
    for (final clientId in transport.clientIds) {
      (transport.isRelayed(clientId) ? relayed : direct).add(clientId);
    }

    if (direct.isNotEmpty) {
      for (final chunk in PhotoChunker.split(photoId, bytes)) {
        final message = WireMessage(
          type: WireType.photoChunk,
          seq: _nextSeq(),
          payload: chunk.toJson(),
        );
        for (final clientId in direct) {
          await transport.sendToClient(clientId, message);
        }
      }
    }

    if (relayed.isNotEmpty) {
      final relayBytes = await _compressPhoto(
        bytes,
        maxDimension: kRelayPhotoDimension,
        quality: kRelayPhotoQuality,
      );
      for (final chunk in PhotoChunker.split(photoId, relayBytes)) {
        final message = WireMessage(
          type: WireType.photoChunk,
          seq: _nextSeq(),
          payload: chunk.toJson(),
        );
        for (final clientId in relayed) {
          await transport.sendToClient(clientId, message);
        }
      }
    }
  }

  int get _connectedWaitingCount =>
      _waitingPlayers.values.where((player) => player.connected).length;

  Future<void> _sendPodiumSnapshot(String clientId) async {
    final engine = _engine;
    if (engine == null) return;
    final awards = _state.awards.isNotEmpty
        ? _state.awards
        : engine.buildPodiumAwards();
    final topMemes = _state.topMemes.isNotEmpty
        ? _state.topMemes
        : _topMemeCards();
    await _hostTransport?.sendToClient(
      clientId,
      WireMessage(
        type: WireType.gamePodium,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'awards': awards.map((a) => a.toJson()).toList(),
          'players': engine.players.map((p) => p.toJson()).toList(),
          'topMemes': topMemes.map((card) => card.toJson()).toList(),
          'waitingCount': _connectedWaitingCount,
        },
      ),
    );
  }

  /// Restores a player who dropped or restarted mid-match. The photo bytes go
  /// first, then one snapshot the client can apply atomically.
  /// Gives a waiting client the current round immediately, so a mid-game QR
  /// scan can spectate instead of staring at an empty card until the next
  /// round. Later rounds arrive through the normal roundShow broadcast.
  Future<void> _sendSpectatorSnapshot(String clientId) async {
    final state = _state;
    if (state.phase == RoundPhase.podium) {
      await _sendPodiumSnapshot(clientId);
      return;
    }
    if (state.currentRound <= 0 || state.activePhotoId == null) return;
    final photoId = state.activePhotoId!;
    final bytes = state.activePhotoBytes;
    if (bytes != null && bytes.isNotEmpty) {
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
    await _hostTransport?.sendToClient(
      clientId,
      WireMessage(
        type: WireType.roundShow,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'mode': state.activeMode.name,
          'roundNumber': state.currentRound,
          'totalRounds': state.totalRounds,
          'photoId': photoId,
          'isPanorama': state.activePhotoIsPanorama,
          // Count down from what is left, not from the full round.
          'durationMs': state.remainingMs > 0
              ? state.remainingMs
              : state.phaseDurationMs,
          'options': state.activeRoundOptions
              .map((player) => player.toJson())
              .toList(),
        },
      ),
    );
  }

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
      'isFinalDoubleRound': engine.isFinalDoubleRound,
      'remainingMs': _state.remainingMs,
      'phaseDurationMs': _state.phaseDurationMs,
      'activeMode': _state.activeMode.name,
      'activePhotoId': activeId,
      'activePhotoIsPanorama': entry?.photo.isPanorama ?? false,
      'zoomAnchorX': _state.zoomAnchorX,
      'zoomAnchorY': _state.zoomAnchorY,
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
      'memeFocusId': _currentMemeFocusId.isEmpty ? null : _currentMemeFocusId,
      'memeFocusIndex': _memeFocusIndex,
      'memeFocusCount': _memeFocusOrder.length,
      'memeFocusVotes': _currentMemeFocusId.isEmpty
          ? 0
          : engine.voteCountFor(_currentMemeFocusId),
      'memeFocusEligible': _currentMemeFocusId.isEmpty
          ? 0
          : engine.eligibleVotersFor(_currentMemeFocusId).length,
      'memeFocusVoterIds': _currentMemeFocusId.isEmpty
          ? const <String>[]
          : engine.voterIdsFor(_currentMemeFocusId).toList(),
      'memeTallying': _memeTallying,
      'memeTallyUp': _currentMemeFocusId.isEmpty
          ? 0
          : engine.voteSplitFor(_currentMemeFocusId)['up'] ?? 0,
      'memeTallyMeh': _currentMemeFocusId.isEmpty
          ? 0
          : engine.voteSplitFor(_currentMemeFocusId)['meh'] ?? 0,
      'memeTallyDown': _currentMemeFocusId.isEmpty
          ? 0
          : engine.voteSplitFor(_currentMemeFocusId)['down'] ?? 0,
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
      'roomThemeId': _state.roomThemeId,
      'rejoined': true,
    };
    await _hostTransport?.sendToClient(
      clientId,
      WireMessage(type: WireType.stateSync, seq: _nextSeq(), payload: payload),
    );
  }

  /// Compares every phone's semantic version (Major.Minor.Patch) with the
  /// newest one in the room. Build numbers are deliberately ignored: iOS
  /// TestFlight and Android bump `+N` independently for the same app release.
  Future<void> _sendVersionWarnings() async {
    var latestVersion = appVersion;
    for (final entry in _clientVersions.entries) {
      final version = entry.value;
      if (version.isNotEmpty && isNewerAppVersion(version, latestVersion)) {
        latestVersion = version;
      }
    }
    final hostIsBehind = isNewerAppVersion(latestVersion, appVersion);
    if (hostIsBehind && _state.versionWarning?.latestVersion != latestVersion) {
      _emit(
        _state.copyWith(
          versionWarning: VersionWarning(
            latestVersion: latestVersion,
            latestBuild: appBuild,
            ownVersion: appVersion,
            ownBuild: appBuild,
          ),
          versionWarningDismissed: false,
        ),
      );
    }
    final transport = _hostTransport;
    if (transport == null) return;
    for (final entry in _clientVersions.entries) {
      final version = entry.value;
      if (version.isEmpty || !isNewerAppVersion(latestVersion, version)) {
        continue;
      }
      await transport.sendToClient(
        _clientIdFor(entry.key),
        WireMessage(
          type: WireType.versionWarning,
          seq: _nextSeq(),
          payload: <String, dynamic>{
            'latestVersion': latestVersion,
            'latestBuild': _clientBuilds[entry.key] ?? 0,
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
        _partyPassPlayers.remove(playerId);
        final waiting = _waitingPlayers[playerId];
        if (waiting != null) {
          _waitingClientIds.remove(clientId);
          if (_engine?.phase == RoundPhase.lobby) {
            _waitingPlayers.remove(playerId);
          } else {
            waiting.connected = false;
          }
        }
        _engine?.removePlayer(playerId);
        var newestVersion = appVersion;
        for (final version in _clientVersions.values) {
          if (version.isNotEmpty && isNewerAppVersion(version, newestVersion)) {
            newestVersion = version;
          }
        }
        _emit(
          _state.copyWith(
            players: _engine?.players ?? _state.players,
            waitingPlayersCount: _connectedWaitingCount,
            clearVersionWarning: !isNewerAppVersion(newestVersion, appVersion),
          ),
        );
        final engine = _engine;
        if (engine != null &&
            engine.activeMode == GameMode.makeItMeme &&
            engine.phase == RoundPhase.captionVoting &&
            !_memeTallying) {
          await _publishMemeFocus();
          if (engine.allVotesFor(_currentMemeFocusId)) {
            await _startMemeTally();
          }
        }
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
        final claimsPartyPass = payload['partyPass'] == true;
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
        final waiting = _waitingPlayers[playerId];
        if (waiting != null) {
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
          _waitingClientIds[clientId] = playerId;
          _clientPlayerIds[clientId] = playerId;
          _playerClientIds[playerId] = clientId;
          waiting
            ..connected = true
            ..name = name
            ..avatar = normalizeAvatar(payload['avatar'] as String?);
          if (avatarPhoto != null && avatarPhoto.isNotEmpty) {
            _avatarPhotos[playerId] = avatarPhoto;
          }
          if (build is int) {
            _clientBuilds[playerId] = build;
            _clientVersions[playerId] = version;
          }
          final atPodium = engine.phase == RoundPhase.podium;
          _emit(_state.copyWith(waitingPlayersCount: _connectedWaitingCount));
          await _hostTransport?.sendToClient(
            clientId,
            WireMessage(
              type: WireType.joinAck,
              seq: _nextSeq(),
              payload: <String, dynamic>{
                'playerId': playerId,
                'resumed': true,
                'waiting': !atPodium,
                'phase': engine.phase.name,
              },
            ),
          );
          await _sendSpectatorSnapshot(clientId);
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
          if (claimsPartyPass) {
            _partyPassPlayers.add(playerId);
          } else {
            _partyPassPlayers.remove(playerId);
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
          // A QR scan during a match joins the room's waiting area. The host
          // adds these players to the fresh engine on the next rematch, so the
          // active round and its scores are never disturbed.
          final waitingPlayer = Player(
            id: playerId,
            name: name,
            avatar: normalizeAvatar(payload['avatar'] as String?),
            avatarColorIndex: payload['avatarColorIndex'] as int? ?? 0,
          );
          _waitingPlayers[playerId] = waitingPlayer;
          _waitingClientIds[clientId] = playerId;
          _clientPlayerIds[clientId] = playerId;
          _playerClientIds[playerId] = clientId;
          if (token.isNotEmpty) _playerTokens[playerId] = token;
          if (avatarPhoto != null && avatarPhoto.isNotEmpty) {
            _avatarPhotos[playerId] = avatarPhoto;
          }
          if (claimsPartyPass) {
            _partyPassPlayers.add(playerId);
          }
          if (build is int) {
            _clientBuilds[playerId] = build;
            _clientVersions[playerId] = version;
          }
          final atPodium = engine.phase == RoundPhase.podium;
          _emit(_state.copyWith(waitingPlayersCount: _connectedWaitingCount));
          await _hostTransport?.sendToClient(
            clientId,
            WireMessage(
              type: WireType.joinAck,
              seq: _nextSeq(),
              payload: <String, dynamic>{
                'playerId': playerId,
                'resumed': false,
                'waiting': !atPodium,
                'phase': engine.phase.name,
              },
            ),
          );
          await _sendSpectatorSnapshot(clientId);
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
        if (claimsPartyPass) {
          _partyPassPlayers.add(playerId);
        } else {
          _partyPassPlayers.remove(playerId);
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
          _memePhotoBytes[chunk.photoId] = bytes;
          PhotoMemoryCache.instance.put(chunk.photoId, bytes);
          _photoRequestAttempts.remove(chunk.photoId);
          final photos = _remotePhotos[playerId];
          if (photos != null) {
            for (var i = 0; i < photos.length; i++) {
              if (photos[i].photoId == chunk.photoId) {
                photos[i] = photos[i].copyWith(bytes: bytes);
              }
            }
          }
          unawaited(_resendMemeAssignmentsFor(chunk.photoId));
        }
      case WireType.playerReady:
        final playerId = _playerIdFor(clientId);
        if (engine.phase != RoundPhase.preparing) return;
        if (engine.player(playerId)?.ready == true) {
          await _afterReadinessChanged();
          return;
        }
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
        final hydrated = <PhotoCandidate>[
          for (final photo in approved)
            if (photo.bytes != null)
              photo
            else
              (() {
                final assembled =
                    _assembledHostBytes['$playerId:${photo.photoId}'];
                return assembled == null
                    ? photo
                    : photo.copyWith(bytes: assembled);
              })(),
        ];
        try {
          engine.submitInitialPhotos(playerId, hydrated);
          engine.markReady(playerId);
        } on EngineException {
          if (engine.player(playerId)?.ready == true) {
            await _afterReadinessChanged();
          }
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
      case WireType.photoRequest:
        final photoId = payload['photoId'] as String?;
        if (photoId == null || photoId.isEmpty) return;
        final bytes = _photoBytesFor(photoId);
        if (bytes != null && bytes.isNotEmpty) {
          await _sendPhotoChunks(clientId, photoId, bytes);
        } else {
          final owner = _ownerForPhotoId(photoId);
          if (owner != null) _requestPhotoFromOwner(photoId, owner);
        }
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
        final record = engine.guessFor(playerId);
        if (record != null) {
          await _hostTransport?.sendToClient(
            clientId,
            WireMessage(
              type: WireType.guessResult,
              seq: _nextSeq(),
              payload: <String, dynamic>{
                'correct': record.isCorrect,
                'points': record.pointsAwarded,
              },
            ),
          );
        }
        await _syncGuesses();
      case WireType.avatarUpdate:
        final playerId = _playerIdFor(clientId);
        final player = engine.player(playerId);
        if (player == null) return;
        player.avatar = normalizeAvatar(payload['avatar'] as String?);
        final photo = payload['avatarPhoto'] as String?;
        if (photo != null && photo.isNotEmpty) {
          _avatarPhotos[playerId] = photo;
        } else {
          _avatarPhotos.remove(playerId);
        }
        _emit(
          _state.copyWith(
            players: engine.players,
            avatarPhotos: Map<String, String>.unmodifiable(_avatarPhotos),
          ),
        );
        await _broadcastLobby();
      case WireType.screenshotTaken:
        _onRemoteScreenshot(_playerIdFor(clientId), payload);
      case WireType.partyPass:
        if (!_clientPlayerIds.containsKey(clientId)) return;
        final playerId = _playerIdFor(clientId);
        if (payload['active'] == true) {
          _partyPassPlayers.add(playerId);
        } else {
          _partyPassPlayers.remove(playerId);
        }
      case WireType.roomTheme:
        final playerId = _playerIdFor(clientId);
        final theme = RoomThemeId.fromWire(payload['themeId'] as String?);
        if (theme.premium && !_partyPassPlayers.contains(playerId)) {
          return;
        }
        await _applyRoomTheme(theme, broadcast: true);
      case WireType.soundEffect:
        final playerId = _playerIdFor(clientId);
        if (!_partyPassPlayers.contains(playerId)) return;
        final incoming = SoundEffectEvent.fromJson(
          payload,
          atMs: DateTime.now().millisecondsSinceEpoch,
        );
        if (!_remoteSoundGate.tryPlay(playerId)) return;
        final event = SoundEffectEvent(
          playerId: playerId,
          playerName: engine.player(playerId)?.name ?? incoming.playerName,
          sound: incoming.sound,
          atMs: incoming.atMs,
        );
        unawaited(SoundboardService.instance.play(event.sound));
        _emit(_state.copyWith(lastSoundEffect: event));
        unawaited(
          _hostTransport?.broadcast(
            WireMessage(
              type: WireType.soundEffect,
              seq: _nextSeq(),
              payload: event.toJson(),
            ),
          ),
        );
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
        final strokes = <SabotageStroke>[
          for (final entry
              in (payload['strokes'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) SabotageStroke.fromJson(entry),
        ];
        final stickers = <SabotageSticker>[
          for (final entry
              in (payload['stickers'] as List<dynamic>? ?? const []))
            if (entry is Map<String, dynamic>) SabotageSticker.fromJson(entry),
        ];
        try {
          engine.submitMeme(
            playerId: playerId,
            template: template,
            topText: payload['topText'] as String? ?? '',
            bottomText: payload['bottomText'] as String? ?? '',
            snapY: (payload['snapY'] as num?)?.toDouble() ?? 48,
            strokes: strokes,
            stickers: stickers,
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
        if (_memeTallying) return;
        await _publishMemeFocus();
        if (engine.allVotesFor(_currentMemeFocusId)) {
          await _startMemeTally();
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
    if (engine == null || _startingMatch) return;
    if (engine.phase != RoundPhase.preparing) return;
    _startingMatch = true;
    try {
      _emit(_state.copyWith(players: engine.players));
      if (!engine.allConnectedPlayersReady) return;
      _stopVaultWatchdog();
      await _preloadVaultToClients().timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
      if (_disposed || engine.phase != RoundPhase.preparing) return;
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
          forceStartAvailable: false,
        ),
      );
      await _enterRoundCountdown();
    } finally {
      _startingMatch = false;
    }
  }

  /// Sends every approved vault photo to every other phone once, before the
  /// first round. Meme payloads can then stay tiny for the rest of the match.
  Future<void> _preloadVaultToClients() async {
    if (_vaultPreloaded) return;
    final transport = _hostTransport;
    final engine = _engine;
    if (transport == null || engine == null) return;
    _vaultPreloaded = true;
    final photos = <String, Uint8List>{};
    for (final candidate in <PhotoCandidate>[
      ..._state.candidates,
      ..._state.extensionCandidates,
    ]) {
      final bytes = candidate.bytes;
      if (bytes != null && bytes.isNotEmpty) photos[candidate.photoId] = bytes;
    }
    for (final entries in _remotePhotos.values) {
      for (final photo in entries) {
        final bytes = photo.bytes;
        if (bytes != null && bytes.isNotEmpty) photos[photo.photoId] = bytes;
      }
    }
    for (final entry in _assembledHostBytes.entries) {
      final separator = entry.key.indexOf(':');
      if (separator < 0 || entry.value.isEmpty) continue;
      photos[entry.key.substring(separator + 1)] = entry.value;
    }
    for (final entry in _memePhotoBytes.entries) {
      if (entry.value.isNotEmpty) photos[entry.key] = entry.value;
    }
    for (final entry in photos.entries) {
      PhotoMemoryCache.instance.put(entry.key, entry.value);
    }
    final sends = <(String, String, Uint8List)>[];
    for (final player in engine.players) {
      if (!player.connected || player.id == 'host') continue;
      final clientId = _clientIdFor(player.id);
      if (!transport.clientIds.contains(clientId)) continue;
      final own = <String>{
        for (final photo
            in _remotePhotos[player.id] ?? const <PhotoCandidate>[])
          photo.photoId,
      };
      for (final entry in photos.entries) {
        if (own.contains(entry.key)) continue;
        sends.add((clientId, entry.key, entry.value));
      }
    }
    if (sends.isEmpty) return;
    var sent = 0;
    _emit(_state.copyWith(vaultSyncReceived: 0, vaultSyncTotal: sends.length));
    for (final send in sends) {
      if (_disposed || _leaving) return;
      await _sendPhotoChunks(send.$1, send.$2, send.$3);
      sent++;
      _emit(_state.copyWith(vaultSyncReceived: sent));
    }
    _emit(_state.copyWith(vaultSyncReceived: 0, vaultSyncTotal: 0));
    await _hostTransport?.broadcast(
      WireMessage(type: WireType.vaultPreloaded, seq: _nextSeq()),
    );
  }

  void _startVaultWatchdog() {
    _vaultWatchdog?.cancel();
    _preparingSince = DateTime.now();
    _emit(_state.copyWith(forceStartAvailable: false));
    _vaultWatchdog = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      final engine = _engine;
      if (_disposed ||
          _leaving ||
          engine == null ||
          engine.phase != RoundPhase.preparing ||
          _state.phase != RoundPhase.preparing) {
        timer.cancel();
        return;
      }
      final connected = engine.players.where((p) => p.connected).toList();
      final allReady = connected.isNotEmpty && connected.every((p) => p.ready);
      final waited = DateTime.now().difference(_preparingSince!);
      if ((allReady || waited >= vaultFallbackDelay) &&
          !_state.forceStartAvailable &&
          !_startingMatch) {
        _emit(
          _state.copyWith(forceStartAvailable: true, players: engine.players),
        );
      }
      unawaited(_maybeStartMatch());
    });
  }

  void _stopVaultWatchdog() {
    _vaultWatchdog?.cancel();
    _vaultWatchdog = null;
    _preparingSince = null;
  }

  /// Host escape hatch for a lost READY packet. It marks every connected
  /// player ready and starts with the photos already received.
  Future<void> forceStartMatch() async {
    final engine = _engine;
    if (engine == null ||
        !_state.isHosting ||
        _startingMatch ||
        engine.phase != RoundPhase.preparing) {
      return;
    }
    _startingMatch = true;
    try {
      _stopVaultWatchdog();
      try {
        engine.forceStartGame();
      } on EngineException catch (error) {
        _emit(
          _state.copyWith(
            errorMessage: _engineError(error),
            forceStartAvailable: true,
          ),
        );
        return;
      }
      _emit(
        _state.copyWith(
          phase: RoundPhase.countdown,
          totalRounds: engine.totalRounds,
          forceStartAvailable: false,
        ),
      );
      await _enterRoundCountdown();
    } finally {
      _startingMatch = false;
    }
  }

  /// Shows the between-round countdown, or starts the round at once when the
  /// countdown is disabled (tests and offline rehearsals).
  Future<void> _enterRoundCountdown() async {
    final engine = _engine;
    if (engine == null) return;
    _stopVaultWatchdog();
    if (countdownDuration <= Duration.zero) {
      await _beginRound();
      return;
    }
    _countdownTicker?.cancel();
    _roundTimer?.cancel();
    final nextRound = engine.currentRound + 1;
    final total = engine.totalRounds;
    final ms = countdownDuration.inMilliseconds;

    final nextMode = engine.deck.length > engine.currentRound
        ? engine.deck[engine.currentRound].mode
        : _state.activeMode;
    _emit(
      _state.copyWith(
        phase: RoundPhase.countdown,
        currentRound: nextRound,
        totalRounds: total,
        remainingMs: ms,
        activeMode: nextMode,
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
          'mode': nextMode.name,
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
    _memeTallyTimer?.cancel();
    _memeTallying = false;

    final bytes = entry.photo.bytes;
    final isMemeRound =
        entry.mode == GameMode.makeItMeme ||
        entry.mode == GameMode.photoSabotage;
    if (isMemeRound) {
      await _ensureMemePhotoBytes(engine, entry.roundNumber);
    }
    if (!isMemeRound && bytes != null) {
      await _sendRoundPhoto(transport, entry.photo.photoId, bytes);
    }

    final mode = entry.mode;
    final pace = engine.config.pace;
    final duration = switch (mode) {
      GameMode.classic || GameMode.mixedParty => effectiveRoundDuration,
      GameMode.captionThis => Duration(seconds: pace.captionSeconds),
      GameMode.zoomOut => Duration(seconds: pace.zoomOutSeconds),
      GameMode.makeItMeme => Duration(seconds: pace.memeSeconds),
      GameMode.photoSabotage => sabotageDuration,
      GameMode.timeTraveler => Duration(seconds: pace.timelineSeconds),
    };
    if (isMemeRound) {
      // Deliver every assignment, photo included, before the round timer
      // starts. Clients stay on the countdown until roundShow arrives, so no
      // creation canvas can open without its photo.
      for (final player in engine.players) {
        if (!player.connected) continue;
        await _sendMemeAssignment(player.id);
      }
    }
    await transport.broadcast(
      WireMessage(
        type: WireType.roundShow,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'mode': mode.name,
          'roundNumber': entry.roundNumber,
          'totalRounds': engine.totalRounds,
          'isFinalDoubleRound': engine.isFinalDoubleRound,
          'photoId': entry.photo.photoId,
          'isPanorama': entry.photo.isPanorama,
          'zoomAnchorX': entry.zoomAnchorX,
          'zoomAnchorY': entry.zoomAnchorY,
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
        isFinalDoubleRound: engine.isFinalDoubleRound,
        activePhotoBytes: bytes,
        activePhotoId: entry.photo.photoId,
        activePhotoIsPanorama: entry.photo.isPanorama,
        zoomAnchorX: entry.zoomAnchorX,
        zoomAnchorY: entry.zoomAnchorY,
        activeRoundOptions: engine.players,
        remainingMs: duration.inMilliseconds,
        phaseDurationMs: duration.inMilliseconds,
        vaultSyncReceived: 0,
        vaultSyncTotal: 0,
        memeAssignment: isMemeRound ? _state.memeAssignment : null,
        memePhotoBase64: isMemeRound ? _state.memePhotoBase64 : null,
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
        case GameMode.photoSabotage:
          unawaited(_startMemeVoting());
        case GameMode.zoomOut:
          unawaited(_finishRound());
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

  void _requestMissingMemePhotos() {
    final activeId = _state.activePhotoId;
    if (activeId != null && _state.activePhotoBytes == null) {
      requestPhoto(activeId);
    }
    final assignment = _state.memeAssignment;
    final encoded = _state.memePhotoBase64;
    if (assignment != null && (encoded == null || encoded.isEmpty)) {
      requestPhoto(assignment.photoId);
    }
    for (final card in <MemeCard>[
      ..._state.memeCards,
      ..._state.memeRevealCards,
      ..._state.topMemes,
    ]) {
      if (card.photoBase64.isEmpty) requestPhoto(card.photoId);
    }
  }

  MemeCard _withPhoto(MemeCard card, String photoId, String encoded) =>
      card.photoId == photoId && card.photoBase64.isEmpty
      ? card.copyWith(photoBase64: encoded)
      : card;

  /// Asks the host for one photo that has not arrived yet. Retries twice with
  /// a short gap; the UI keeps showing the photo shimmer while it waits.
  void requestPhoto(String photoId) {
    if (_state.isHosting || photoId.isEmpty) return;
    if (PhotoMemoryCache.instance.hasPhoto(photoId) ||
        _clientRoundPhotos.containsKey(photoId) ||
        _memePhotoBytes.containsKey(photoId)) {
      return;
    }
    final transport = _clientTransport;
    if (transport == null) return;
    final attempts = _photoRequestAttempts[photoId] ?? 0;
    if (attempts >= 3) return;
    _photoRequestAttempts[photoId] = attempts + 1;
    unawaited(
      transport.send(
        WireMessage(
          type: WireType.photoRequest,
          seq: _nextSeq(),
          payload: <String, dynamic>{'photoId': photoId},
        ),
      ),
    );
    Timer(const Duration(milliseconds: 1500), () {
      if (_disposed) return;
      if (_clientRoundPhotos.containsKey(photoId) ||
          _memePhotoBytes.containsKey(photoId)) {
        return;
      }
      if ((_photoRequestAttempts[photoId] ?? 0) < 3) requestPhoto(photoId);
    });
  }

  Uint8List? _photoBytesFor(String photoId) {
    final cached = _memePhotoBytes[photoId];
    if (cached != null && cached.isNotEmpty) return cached;
    for (final photo in <PhotoCandidate>[
      ..._state.candidates,
      ..._state.extensionCandidates,
    ]) {
      final bytes = photo.bytes;
      if (photo.photoId == photoId && bytes != null && bytes.isNotEmpty) {
        _memePhotoBytes[photoId] = bytes;
        return bytes;
      }
    }
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
        if (photo != null) {
          _memePhotoBytes[option.photoId] = photo;
          PhotoMemoryCache.instance.put(option.photoId, photo);
        }
        return MemeCard(
          id: option.id,
          photoBase64: '',
          photoId: option.photoId,
          template: option.template,
          topText: option.topText,
          bottomText: option.bottomText,
          snapY: option.snapY,
          isOwn: engine.isOwnMeme(playerId, option.id),
          isSabotage: option.isSabotage,
          strokes: option.strokes,
          stickers: option.stickers,
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
        if (photo != null) {
          _memePhotoBytes[entry.photoId] = photo;
          PhotoMemoryCache.instance.put(entry.photoId, photo);
        }
        return MemeCard(
          id: entry.id,
          photoBase64: '',
          photoId: entry.photoId,
          template: entry.template,
          topText: entry.topText,
          bottomText: entry.bottomText,
          snapY: entry.snapY,
          authorId: entry.authorId,
          authorName: entry.authorName,
          photoOwnerId: entry.photoOwnerId,
          photoOwnerName: entry.photoOwnerName,
          upVotes: entry.upVotes,
          mehVotes: entry.mehVotes,
          downVotes: entry.downVotes,
          points: entry.points,
          isWinner: reveal.winnerIds.contains(entry.id),
          isSabotage: entry.isSabotage,
          strokes: entry.strokes,
          stickers: entry.stickers,
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
        if (photo != null) {
          _memePhotoBytes[entry.photoId] = photo;
          PhotoMemoryCache.instance.put(entry.photoId, photo);
        }
        return MemeCard(
          id: entry.id,
          photoBase64: '',
          photoId: entry.photoId,
          template: entry.template,
          topText: entry.topText,
          bottomText: entry.bottomText,
          snapY: entry.snapY,
          authorId: entry.authorId,
          authorName: entry.authorName,
          photoOwnerId: entry.photoOwnerId,
          photoOwnerName: entry.photoOwnerName,
          upVotes: entry.upVotes,
          mehVotes: entry.mehVotes,
          downVotes: entry.downVotes,
          points: entry.points,
          isWinner: true,
          isSabotage: entry.isSabotage,
          strokes: entry.strokes,
          stickers: entry.stickers,
        );
      }),
    );
  }

  Future<void> _resendMemeAssignmentsFor(String photoId) async {
    if (_state.memeAssignment?.photoId == photoId) {
      await _sendMemeAssignment('host');
    }
    final waiting = _pendingMemeAssignments.remove(photoId);
    if (waiting == null || waiting.isEmpty) return;
    for (final playerId in waiting) {
      await _sendMemeAssignment(playerId);
    }
  }

  /// Make It Meme starts only after every assigned photo is in the host's
  /// cache. Missing vault chunks are requested directly from their owner and
  /// the countdown is held until every connected player's photo is present, so
  /// no creation timer can start on a blank canvas.
  Future<void> _ensureMemePhotoBytes(
    HostGameEngine engine,
    int roundNumber,
  ) async {
    final nextRequest = <String, DateTime>{};
    while (!_disposed && !_leaving) {
      var received = 0;
      var total = 0;
      for (final player in engine.players) {
        if (!player.connected) continue;
        final assignment = engine.memeAssignmentFor(player.id);
        if (assignment == null) continue;
        total++;
        final bytes = _photoBytesFor(assignment.photoId);
        if (bytes == null || bytes.isEmpty) {
          final now = DateTime.now();
          final due = nextRequest[assignment.photoId];
          if (due == null || !now.isBefore(due)) {
            nextRequest[assignment.photoId] = now.add(
              const Duration(milliseconds: 700),
            );
            _photoRequestAttempts.remove(assignment.photoId);
            _requestPhotoFromOwner(assignment.photoId, assignment.ownerId);
          }
        } else {
          PhotoMemoryCache.instance.put(assignment.photoId, bytes);
          if (PhotoMemoryCache.instance.hasPhoto(assignment.photoId)) {
            received++;
          }
        }
      }
      if (received >= total) return;
      _emit(
        _state.copyWith(
          phase: RoundPhase.countdown,
          currentRound: roundNumber,
          totalRounds: engine.totalRounds,
          remainingMs: 0,
          vaultSyncReceived: received,
          vaultSyncTotal: total,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  Future<void> _sendMemeAssignment(String playerId) async {
    final engine = _engine;
    if (engine == null) return;
    final assignment = engine.memeAssignmentFor(playerId);
    if (assignment == null) return;
    var bytes = _photoBytesFor(assignment.photoId);
    if (bytes != null && bytes.isNotEmpty) {
      _memePhotoBytes[assignment.photoId] = bytes;
      PhotoMemoryCache.instance.put(assignment.photoId, bytes);
    } else {
      bytes = null;
      _pendingMemeAssignments
          .putIfAbsent(assignment.photoId, () => <String>{})
          .add(playerId);
      _requestPhotoFromOwner(assignment.photoId, assignment.ownerId);
    }
    final payload = <String, dynamic>{
      'assignment': assignment.toJson(),
      // The vault preload already put every photo in PhotoMemoryCache. Keep
      // this payload light so state sync can never re-send binary data.
      'photoBase64': '',
      'swapsLeft': engine.memeSwapsLeft(playerId),
    };
    if (playerId == 'host') {
      _emit(
        _state.copyWith(
          memeAssignment: assignment,
          memePhotoBase64: null,
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

  String? _ownerForPhotoId(String photoId) {
    for (final entry in _remotePhotos.entries) {
      if (entry.value.any((photo) => photo.photoId == photoId)) {
        return entry.key;
      }
    }
    final engine = _engine;
    if (engine != null) {
      for (final player in engine.players) {
        final assigned = engine.memeAssignmentPhoto(player.id);
        if (assigned?.photoId == photoId) return assigned!.ownerId;
      }
    }
    return null;
  }

  void _requestPhotoFromOwner(String photoId, String ownerId) {
    if (ownerId == 'host') return;
    final clientId = _playerClientIds[ownerId];
    if (clientId == null) return;
    final attempts = _photoRequestAttempts[photoId] ?? 0;
    if (attempts >= 3) return;
    _photoRequestAttempts[photoId] = attempts + 1;
    unawaited(
      _hostTransport?.sendToClient(
        clientId,
        WireMessage(
          type: WireType.photoRequest,
          seq: _nextSeq(),
          payload: <String, dynamic>{'photoId': photoId},
        ),
      ),
    );
  }

  String get _currentMemeFocusId =>
      _memeFocusIndex >= 0 && _memeFocusIndex < _memeFocusOrder.length
      ? _memeFocusOrder[_memeFocusIndex]
      : '';

  Map<String, dynamic> _memeFocusPayload({
    bool tallying = false,
    Map<String, int>? split,
  }) {
    final engine = _engine;
    final memeId = _currentMemeFocusId;
    if (engine == null || memeId.isEmpty) {
      return <String, dynamic>{
        'memeId': '',
        'index': 0,
        'count': 0,
        'votes': 0,
        'eligible': 0,
        'voterIds': const <String>[],
        'tallying': tallying,
      };
    }
    final voters = engine.voterIdsFor(memeId);
    final eligible = engine.eligibleVotersFor(memeId).length;
    final counts = split ?? engine.voteSplitFor(memeId);
    return <String, dynamic>{
      'memeId': memeId,
      'index': _memeFocusIndex,
      'count': _memeFocusOrder.length,
      'votes': voters.length,
      'eligible': eligible,
      'voterIds': voters.toList(),
      'tallying': tallying,
      'tallyUp': counts['up'] ?? 0,
      'tallyMeh': counts['meh'] ?? 0,
      'tallyDown': counts['down'] ?? 0,
    };
  }

  MatchUiState _withMemeFocus(
    MatchUiState state,
    Map<String, dynamic> payload,
  ) {
    final id = payload['memeId'] as String? ?? '';
    final voterIds = <String>{
      for (final value in (payload['voterIds'] as List<dynamic>? ?? const []))
        if (value is String) value,
    };
    return state.copyWith(
      phase: RoundPhase.captionVoting,
      activeMode: _engine?.activeMode ?? state.activeMode,
      memeFocusId: id.isEmpty ? null : id,
      memeFocusIndex: payload['index'] as int? ?? 0,
      memeFocusCount: payload['count'] as int? ?? 0,
      memeFocusVotes: payload['votes'] as int? ?? 0,
      memeFocusEligible: payload['eligible'] as int? ?? 0,
      memeFocusVoterIds: voterIds,
      memeTallying: payload['tallying'] as bool? ?? false,
      memeTallyUp: payload['tallyUp'] as int? ?? 0,
      memeTallyMeh: payload['tallyMeh'] as int? ?? 0,
      memeTallyDown: payload['tallyDown'] as int? ?? 0,
      memeVotesSubmitted: _engine?.memeVoteCount ?? state.memeVotesSubmitted,
      clearError: true,
    );
  }

  Future<void> _sendMemeOptions(String playerId) async {
    final engine = _engine;
    if (engine == null) return;
    final cards = _memeCardsFor(playerId);
    final focus = _memeFocusPayload(tallying: _memeTallying);
    final payload = <String, dynamic>{
      'cards': cards.map((card) => card.toJson()).toList(),
      'votedIds': engine.memeVotedIds(playerId).toList(),
      'submissions': engine.memeCount,
      'votes': engine.memeVoteCount,
      'durationMs': 0,
      ...focus,
    };
    if (playerId == 'host') {
      _emit(
        _withMemeFocus(
          _state.copyWith(
            memeCards: cards,
            memeVotedIds: engine.memeVotedIds(playerId),
            memeSubmissions: engine.memeCount,
            remainingMs: 0,
            phaseDurationMs: 0,
          ),
          focus,
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

  /// Pushes the host's current focus (or its tally moment) to every phone.
  Future<void> _publishMemeFocus({bool tallying = false}) async {
    final engine = _engine;
    if (engine == null) return;
    final payload = _memeFocusPayload(tallying: tallying);
    _emit(_withMemeFocus(_state, payload));
    await _hostTransport?.broadcast(
      WireMessage(
        type: tallying ? WireType.memeTally : WireType.memeFocus,
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
    _memeTallyTimer?.cancel();
    _memeTallying = false;
    _memeFocusOrder = engine.memeIds;
    _memeFocusIndex = 0;
    for (final player in engine.players) {
      if (!player.connected) continue;
      await _sendMemeOptions(player.id);
    }
  }

  Future<void> _startMemeTally() async {
    final engine = _engine;
    if (engine == null || _memeTallying) return;
    final memeId = _currentMemeFocusId;
    if (memeId.isEmpty) return;
    _memeTallying = true;
    _roundTimer?.cancel();
    _memeTallyTimer?.cancel();
    unawaited(GameAudioService.instance.ding());
    unawaited(GameHaptics.instance.light());
    await _publishMemeFocus(tallying: true);
    _memeTallyTimer = Timer(memeTallyDuration, () {
      unawaited(_advanceMemeFocus());
    });
  }

  Future<void> _advanceMemeFocus() async {
    if (!_memeTallying) return;
    _memeTallying = false;
    final engine = _engine;
    if (engine == null) return;
    if (_memeFocusIndex + 1 < _memeFocusOrder.length) {
      _memeFocusIndex += 1;
      await _publishMemeFocus();
      if (engine.allVotesFor(_currentMemeFocusId)) {
        await _startMemeTally();
      }
      return;
    }
    await _finishMemeRound();
  }

  /// Host-only: close the current meme even if an AFK player never votes.
  Future<void> endMemeVoting() async {
    if (!_state.isHosting || _state.phase != RoundPhase.captionVoting) return;
    await _startMemeTally();
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
    _memeTallyTimer?.cancel();
    _memeTallying = false;
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
        activeMode: engine.activeMode,
        lastMemeReveal: reveal,
        memeRevealCards: cards,
        memeCards: const <MemeCard>[],
        memeVotedIds: const <String>{},
        memeSubmissions: engine.memeCount,
        memeVotesSubmitted: engine.memeVoteCount,
        memeFocusVotes: 0,
        memeFocusEligible: 0,
        memeFocusVoterIds: const <String>{},
        memeTallying: false,
        memeTallyUp: 0,
        memeTallyMeh: 0,
        memeTallyDown: 0,
        clearMemeFocus: true,
        players: engine.players,
        topMemes: _topMemeCards(),
        remainingMs: 0,
      ),
    );
    // Meme reveals wait for the host. Everyone gets time to laugh at the
    // winning meme, and the host decides when the room moves on. A round with
    // zero memes still moves on by itself: the host also gets a Next button,
    // but this timer is the last line of defence against a frozen screen.
    _captionRevealTimer?.cancel();
    if (cards.isEmpty) {
      _memesEmptyAdvanceTimer?.cancel();
      _memesEmptyAdvanceTimer = Timer(emptyMemeAdvanceDuration, () {
        if (!_leaving && !_disposed) unawaited(advanceMemeReveal());
      });
    }
  }

  /// Host-only: move from the meme reveal to the next round or the podium.
  Future<void> advanceMemeReveal() async {
    if (!_state.isHosting || _state.phase != RoundPhase.captionReveal) return;
    _captionRevealTimer?.cancel();
    await _advanceAfterReveal();
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

  Future<void> submitSabotage(
    List<SabotageStroke> strokes, {
    List<SabotageSticker> stickers = const <SabotageSticker>[],
  }) async {
    final engine = _engine;
    if (engine == null) return;
    try {
      engine.submitMeme(
        playerId: 'host',
        template: MemeTemplate.classic,
        topText: '',
        bottomText: '',
        snapY: 50,
        strokes: strokes,
        stickers: stickers,
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

  Future<void> clientSubmitSabotage(
    List<SabotageStroke> strokes, {
    List<SabotageSticker> stickers = const <SabotageSticker>[],
  }) async {
    await _clientTransport?.send(
      WireMessage(
        type: WireType.memeSubmit,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'sabotage': true,
          'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
          'stickers': stickers.map((sticker) => sticker.toJson()).toList(),
        },
      ),
    );
    unawaited(GameAudioService.instance.pop());
    _emit(_state.copyWith(memeSubmitted: true));
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
    unawaited(GameAudioService.instance.swap());
    unawaited(GameHaptics.instance.selection());
  }

  Future<void> clientSwapMemePhoto() async {
    await _clientTransport?.send(
      WireMessage(type: WireType.memeSwap, seq: _nextSeq()),
    );
    unawaited(GameAudioService.instance.swap());
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
          ? GameAudioService.instance.voteUp()
          : vote == MemeVote.meh
          ? GameAudioService.instance.voteMeh()
          : GameAudioService.instance.voteDown(),
    );
    unawaited(GameHaptics.instance.selection());
    _emit(
      _state.copyWith(
        memeVotedIds: voted,
        memeVotesSubmitted: engine.memeVoteCount,
        clearError: true,
      ),
    );
    if (_memeTallying) return;
    await _publishMemeFocus();
    if (engine.allVotesFor(_currentMemeFocusId)) {
      await _startMemeTally();
    }
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
          ? GameAudioService.instance.voteUp()
          : vote == MemeVote.meh
          ? GameAudioService.instance.voteMeh()
          : GameAudioService.instance.voteDown(),
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
    unawaited(GameAudioService.instance.ding());
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
    // The host decides when the group has laughed enough; the reveal never
    // advances on a hidden timer.
    _timelineRevealTimer?.cancel();
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
    _revealAutoTimer?.cancel();
    _revealAutoTimer = Timer(
      revealDuration,
      () => unawaited(_advanceAfterReveal()),
    );
  }

  Future<void> _advanceAfterReveal() async {
    final engine = _engine;
    if (engine == null) return;
    // A host tap and the reveal timer can race. Only the first one may move
    // the match; a stale timer from the previous round must never advance the
    // next round's reveal.
    if (engine.phase != RoundPhase.reveal &&
        engine.phase != RoundPhase.captionReveal &&
        engine.phase != RoundPhase.timelineReveal) {
      return;
    }
    _revealAutoTimer?.cancel();
    _revealAutoTimer = null;
    _captionRevealTimer?.cancel();
    _captionRevealTimer = null;
    _timelineRevealTimer?.cancel();
    _timelineRevealTimer = null;
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
            'waitingCount': _connectedWaitingCount,
          },
        ),
      );
      _emit(
        _state.copyWith(
          phase: RoundPhase.podium,
          awards: awards,
          players: engine.players,
          waitingPlayersCount: _connectedWaitingCount,
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
    _partyPassPlayers.remove(playerId);
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

  /// Host-only Mixed Party choice. The engine rejects fewer than two modes.
  Future<void> setMixedModes(Set<GameMode> modes) async {
    final normalized = modes.where(MatchConfig.coreMixedModes.contains).toSet();
    if (normalized.length < 2) return;
    final engine = _engine;
    if (engine == null) {
      _emit(
        _state.copyWith(
          config: _state.config.copyWith(enabledMixedModes: normalized),
        ),
      );
      return;
    }
    try {
      engine.setMixedModes(normalized);
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
    _vaultPreloaded = false;
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
        forceStartAvailable: false,
        clearError: true,
      ),
    );
    if (engine.players.any((p) => p.id != 'host')) {
      _startVaultWatchdog();
    }
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
    unawaited(GameAudioService.instance.swap());
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
    unawaited(GameAudioService.instance.swap());
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
    for (final candidate in _state.candidates) {
      final bytes = candidate.bytes;
      if (bytes != null) {
        PhotoMemoryCache.instance.put(candidate.photoId, bytes);
      }
    }
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

  double get _currentZoomScale {
    final total = _state.phaseDurationMs;
    if (total <= 0) return 1;
    return (1 + 5 * (_state.remainingMs / total)).clamp(1.0, 6.0);
  }

  Future<void> submitGuess(String guessedOwnerId) async {
    final engine = _engine;
    if (engine == null || _state.lockedGuessOwnerId != null) return;
    unawaited(GameHaptics.instance.selection());
    unawaited(GameAudioService.instance.tap());
    final elapsed = DateTime.now().millisecondsSinceEpoch - _roundStartMs;
    engine.submitGuess('host', guessedOwnerId, elapsed);
    final record = engine.guessFor('host');
    _emit(
      _state.copyWith(
        lockedGuessOwnerId: guessedOwnerId,
        lastGuessCorrect: record?.isCorrect,
        lockedGuessScale: _currentZoomScale,
      ),
    );
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
    final waiting = List<Player>.of(_waitingPlayers.values);
    _waitingPlayers.clear();
    _waitingClientIds.clear();
    for (final player in waiting) {
      if (player.connected) {
        engine.promoteWaitingPlayer(player);
      }
    }
    _vaultPreloaded = false;
    final deadline = engine.extendGame(
      extraRounds: extraRounds,
      extraPhotos: extraPhotos,
    );
    final seconds = extendWindow.inSeconds;
    _emit(
      _state.copyWith(
        phase: RoundPhase.extendPrompt,
        players: engine.players,
        waitingPlayersCount: 0,
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
          'players': engine.players.map((p) => p.toJson()).toList(),
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
    final topMemes = _topMemeCards();
    await _hostTransport?.broadcast(
      WireMessage(
        type: WireType.gamePodium,
        seq: _nextSeq(),
        payload: <String, dynamic>{
          'awards': awards.map((a) => a.toJson()).toList(),
          'players': engine.players.map((p) => p.toJson()).toList(),
          'topMemes': topMemes.map((card) => card.toJson()).toList(),
          'waitingCount': _connectedWaitingCount,
        },
      ),
    );
    _emit(
      _state.copyWith(
        phase: RoundPhase.podium,
        awards: awards,
        players: engine.players,
        waitingPlayersCount: _connectedWaitingCount,
        hostDeciding: false,
        topMemes: topMemes,
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
    final waiting = List<Player>.of(_waitingPlayers.values);
    _waitingPlayers.clear();
    _waitingClientIds.clear();
    final config = _state.config;
    final fresh = HostGameEngine(
      config: config,
      random: random,
      planterOverride: planterOverride,
    );
    _engine = fresh;
    for (final player in <Player>[...players, ...waiting]) {
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
    _memePhotoBytes.clear();
    _pendingMemeAssignments.clear();
    _photoRequestAttempts.clear();
    _assemblers.clear();
    _vaultPreloaded = false;
    PhotoMemoryCache.instance.clear();
    _memeTallyTimer?.cancel();
    _memeFocusOrder = <String>[];
    _memeFocusIndex = 0;
    _memeTallying = false;
    _emit(
      MatchUiState(
        isHosting: true,
        roomId: _state.roomId,
        inviteUrl: _state.inviteUrl,
        localPlayerId: 'host',
        phase: RoundPhase.lobby,
        players: fresh.players,
        waitingPlayersCount: 0,
        avatarPhotos: Map<String, String>.unmodifiable(_avatarPhotos),
        config: config,
        connectionMode: _state.connectionMode,
        roomThemeId: _state.roomThemeId,
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
          'roomThemeId': _state.roomThemeId,
          'waitingCount': _connectedWaitingCount,
        },
      ),
    );
    _emit(
      _state.copyWith(
        players: engine.players,
        config: engine.config,
        avatarPhotos: Map<String, String>.unmodifiable(_avatarPhotos),
        waitingPlayersCount: _connectedWaitingCount,
      ),
    );
  }

  Future<void> joinMatch(String rawInvite) async {
    PhotoMemoryCache.instance.clear();
    _pendingInviteUrl = null;
    _pendingRoomId = null;
    _pendingPlayerId = null;
    _pendingPlayerToken = null;
    _emit(
      _state.copyWith(
        loadingMessage: _l10n.loadingJoining,
        firewallPrompt: false,
        clearFirewallError: true,
        clearError: true,
      ),
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
      BugReportService.instance.record('P2P', 'join quota blocked');
      _emit(
        _state.copyWith(
          turnLimitNotice: error.notice,
          errorMessage: _l10n.errorRelayLimit,
          clearLoading: true,
        ),
      );
      return;
    } on RelayRequiredException catch (error) {
      BugReportService.instance.record('P2P', 'join relay required');
      _emit(
        _state.copyWith(
          firewallPrompt: true,
          firewallRelayAttempted: error.passActive,
          firewallRelayErrorCode: error.relayErrorCode,
          errorMessage: error.passActive ? _l10n.errorRelayUnavailable : null,
          clearLoading: true,
        ),
      );
      return;
    } on TransportException catch (error) {
      BugReportService.instance.record('P2P', 'join ${error.code}');
      final message = switch (error.code) {
        'room_not_ready' => _l10n.errorHostStarting,
        'unauthorized' => _l10n.errorInviteExpired,
        'relay_unavailable' => _l10n.errorRelayUnavailable,
        _ => _l10n.errorReachHost,
      };
      _emit(_state.copyWith(errorMessage: message, clearLoading: true));
      return;
    } on Object catch (error, stack) {
      if (PlaytestConfig.enabled) {
        debugPrint('WhoTook playtest join failed: $error');
        debugPrintStack(stackTrace: stack);
      }
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
          'partyPass': _partyPassActive,
        },
      ),
    );
    if (_state.roomId == null) return;
    await _startPlatformServices();
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
        // A mobile reconnect can take longer than the countdown; let it finish.
        if (_reconnectInFlight) {
          _emit(_state.copyWith(reconnectSecondsLeft: 0));
          return;
        }
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
            'partyPass': _partyPassActive,
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
        _emit(
          _state.copyWith(
            localPlayerId: _currentPlayerId,
            waitingForMatch: payload['waiting'] == true,
          ),
        );
        _sendPartyPassClaim();
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
            isFinalDoubleRound: payload['isFinalDoubleRound'] as bool? ?? false,
            remainingMs: payload['remainingMs'] as int? ?? 0,
            phaseDurationMs: payload['phaseDurationMs'] as int? ?? 0,
            activeMode: activeMode,
            activePhotoBytes: activeBytes,
            activePhotoId: activePhotoId,
            activePhotoIsPanorama:
                payload['activePhotoIsPanorama'] as bool? ?? false,
            zoomAnchorX: (payload['zoomAnchorX'] as num?)?.toDouble() ?? 0.5,
            zoomAnchorY: (payload['zoomAnchorY'] as num?)?.toDouble() ?? 0.5,
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
            memeFocusId: payload['memeFocusId'] as String?,
            memeFocusIndex: payload['memeFocusIndex'] as int? ?? 0,
            memeFocusCount: payload['memeFocusCount'] as int? ?? 0,
            memeFocusVotes: payload['memeFocusVotes'] as int? ?? 0,
            memeFocusEligible: payload['memeFocusEligible'] as int? ?? 0,
            memeFocusVoterIds: <String>{
              for (final value
                  in (payload['memeFocusVoterIds'] as List<dynamic>? ??
                      const []))
                if (value is String) value,
            },
            memeTallying: payload['memeTallying'] as bool? ?? false,
            memeTallyUp: payload['memeTallyUp'] as int? ?? 0,
            memeTallyMeh: payload['memeTallyMeh'] as int? ?? 0,
            memeTallyDown: payload['memeTallyDown'] as int? ?? 0,
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
            roomThemeId: RoomThemeId.fromWire(payload['roomThemeId'] as String?)
                .wireId,
            clearError: true,
          ),
        );
        _requestMissingMemePhotos();
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
        final latestVersion = payload['latestVersion'] as String? ?? appVersion;
        if (isNewerAppVersion(latestVersion, appVersion)) {
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
      case WireType.roomTheme:
        final theme = RoomThemeId.fromWire(payload['themeId'] as String?);
        _emit(_state.copyWith(roomThemeId: theme.wireId));
      case WireType.soundEffect:
        final event = SoundEffectEvent.fromJson(
          payload,
          atMs: DateTime.now().millisecondsSinceEpoch,
        );
        if (event.playerId == (_state.localPlayerId ?? '')) return;
        if (!_remoteSoundGate.tryPlay(event.playerId)) return;
        unawaited(SoundboardService.instance.play(event.sound));
        _emit(_state.copyWith(lastSoundEffect: event));
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
            waitingForMatch:
                _state.waitingForMatch && parsedPhase != RoundPhase.lobby,
            waitingPlayersCount: payload['waitingCount'] as int? ?? 0,
            roomThemeId: RoomThemeId.fromWire(payload['roomThemeId'] as String?)
                .wireId,
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
            waitingForMatch: false,
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
      case WireType.photoRequest:
        final photoId = payload['photoId'] as String?;
        if (photoId == null || photoId.isEmpty) return;
        Uint8List? localBytes;
        for (final candidate in _state.candidates) {
          if (candidate.photoId == photoId && candidate.bytes != null) {
            localBytes = candidate.bytes;
            break;
          }
        }
        localBytes ??= _memePhotoBytes[photoId] ?? _clientRoundPhotos[photoId];
        if (localBytes == null || localBytes.isEmpty) return;
        for (final chunk in PhotoChunker.split(photoId, localBytes)) {
          await _clientTransport?.send(
            WireMessage(
              type: WireType.photoChunk,
              seq: _nextSeq(),
              payload: chunk.toJson(),
            ),
          );
        }
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
          _memePhotoBytes[chunk.photoId] = bytes;
          PhotoMemoryCache.instance.put(chunk.photoId, bytes);
          _photoRequestAttempts.remove(chunk.photoId);
          final encoded = base64Encode(bytes);
          final active = _state.activePhotoId;
          _emit(
            _state.copyWith(
              activePhotoBytes: active == null || active == chunk.photoId
                  ? bytes
                  : _state.activePhotoBytes,
              memePhotoBase64: _state.memeAssignment?.photoId == chunk.photoId
                  ? encoded
                  : _state.memePhotoBase64,
              memeCards: _state.memeCards
                  .map((card) => _withPhoto(card, chunk.photoId, encoded))
                  .toList(),
              memeRevealCards: _state.memeRevealCards
                  .map((card) => _withPhoto(card, chunk.photoId, encoded))
                  .toList(),
              topMemes: _state.topMemes
                  .map((card) => _withPhoto(card, chunk.photoId, encoded))
                  .toList(),
            ),
          );
        }
      case WireType.roundCountdown:
        final countdownMode = GameMode.values.firstWhere(
          (value) => value.name == payload['mode'],
          orElse: () => _state.activeMode,
        );
        _emit(
          _state.copyWith(
            phase: RoundPhase.countdown,
            currentRound: payload['roundNumber'] as int? ?? 0,
            totalRounds: payload['totalRounds'] as int? ?? _state.totalRounds,
            remainingMs: payload['durationMs'] as int? ?? 0,
            activeMode: countdownMode,
            clearGuess: true,
            lockedGuessOwnerId: null,
          ),
        );
        _startClientPhaseTicker(payload['durationMs'] as int? ?? 0);
      case WireType.vaultPreloaded:
        // Every vault photo is now in PhotoMemoryCache. Rebuild once so the
        // prepare screen can decode the photos before the first round.
        _emit(
          _state.copyWith(
            candidates: List<PhotoCandidate>.of(_state.candidates),
            vaultSyncReceived: 0,
            vaultSyncTotal: 0,
          ),
        );
      case WireType.guessResult:
        _emit(
          _state.copyWith(
            lastGuessCorrect: payload['correct'] as bool? ?? false,
            lockedGuessScale: _currentZoomScale,
          ),
        );
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
          GameMode.classic || GameMode.zoomOut => RoundPhase.guessing,
          GameMode.captionThis ||
          GameMode.makeItMeme ||
          GameMode.photoSabotage => RoundPhase.captionWriting,
          GameMode.timeTraveler => RoundPhase.timelineGuessing,
          GameMode.mixedParty => RoundPhase.guessing,
        };
        _clientReadyRetry?.cancel();
        _clientReadyRetry = null;
        _roundStartMs = DateTime.now().millisecondsSinceEpoch;
        _emit(
          _state.copyWith(
            phase: phase,
            activeMode: mode,
            currentRound: payload['roundNumber'] as int? ?? 0,
            totalRounds: payload['totalRounds'] as int? ?? _state.totalRounds,
            isFinalDoubleRound: payload['isFinalDoubleRound'] as bool? ?? false,
            remainingMs: payload['durationMs'] as int? ?? 8000,
            phaseDurationMs: payload['durationMs'] as int? ?? 8000,
            activePhotoBytes: photoId == null
                ? null
                : _clientRoundPhotos[photoId],
            activePhotoId: photoId,
            activePhotoIsPanorama: payload['isPanorama'] as bool? ?? false,
            zoomAnchorX: (payload['zoomAnchorX'] as num?)?.toDouble() ?? 0.5,
            zoomAnchorY: (payload['zoomAnchorY'] as num?)?.toDouble() ?? 0.5,
            activeRoundOptions: options,
            memeAssignment:
                mode == GameMode.makeItMeme || mode == GameMode.photoSabotage
                ? _state.memeAssignment
                : null,
            memePhotoBase64:
                mode == GameMode.makeItMeme || mode == GameMode.photoSabotage
                ? _state.memePhotoBase64
                : null,
            memeSwapsLeft:
                mode == GameMode.makeItMeme || mode == GameMode.photoSabotage
                ? _state.memeSwapsLeft
                : 5,
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
            final decoded = base64Decode(encoded);
            _memePhotoBytes[assignment.photoId] = decoded;
            PhotoMemoryCache.instance.put(assignment.photoId, decoded);
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
          if ((encoded == null || encoded.isEmpty) &&
              !PhotoMemoryCache.instance.hasPhoto(assignment.photoId)) {
            requestPhoto(assignment.photoId);
          }
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
          _withMemeFocus(
            _state.copyWith(
              phase: RoundPhase.captionVoting,
              activeMode: _state.activeMode,
              memeCards: cards,
              memeVotedIds: votedIds,
              memeSubmissions: payload['submissions'] as int? ?? cards.length,
              memeVotesSubmitted: payload['votes'] as int? ?? 0,
              remainingMs: 0,
              phaseDurationMs: 0,
              clearError: true,
            ),
            payload,
          ),
        );
        _requestMissingMemePhotos();
      case WireType.memeFocus:
      case WireType.memeTally:
        final tally = message.type == WireType.memeTally;
        _emit(_withMemeFocus(_state.copyWith(memeTallying: tally), payload));
        if (tally) {
          unawaited(GameHaptics.instance.light());
          unawaited(GameAudioService.instance.ding());
        }
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
            activeMode: _state.activeMode,
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
        unawaited(GameAudioService.instance.ding());
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
        final rawPlayers = payload['players'] as List<dynamic>?;
        final updatedPlayers = rawPlayers == null
            ? _state.players
            : <Player>[
                for (final entry in rawPlayers)
                  if (entry is Map<String, dynamic>) Player.fromJson(entry),
              ];
        _emit(
          _state.copyWith(
            phase: RoundPhase.extendPrompt,
            players: updatedPlayers,
            waitingForMatch: false,
            waitingPlayersCount: 0,
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
            waitingForMatch: false,
            waitingPlayersCount: payload['waitingCount'] as int? ?? 0,
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
    if (drawn.isEmpty) return;
    unawaited(GameAudioService.instance.swap());
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
    unawaited(GameAudioService.instance.swap());
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
      PhotoMemoryCache.instance.put(candidate.photoId, bytes);
      final payload = transport.usesRelay
          ? await _compressPhoto(
              bytes,
              maxDimension: kRelayUploadDimension,
              quality: kRelayUploadQuality,
            )
          : bytes;
      for (final chunk in PhotoChunker.split(candidate.photoId, payload)) {
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
    _startClientReadyRetry();
  }

  void _startClientReadyRetry() {
    _clientReadyRetry?.cancel();
    _clientReadyRetry = Timer.periodic(const Duration(milliseconds: 1500), (
      timer,
    ) async {
      if (_disposed ||
          _leaving ||
          _state.phase != RoundPhase.preparing ||
          _state.roomId == null ||
          _clientTransport == null) {
        timer.cancel();
        _clientReadyRetry = null;
        return;
      }
      try {
        await _clientTransport!.send(
          WireMessage(
            type: WireType.submitPhotoMeta,
            seq: _nextSeq(),
            payload: <String, dynamic>{
              'photos': _state.candidates.map((c) => c.toJson()).toList(),
            },
          ),
        );
        await _clientTransport!.send(
          WireMessage(type: WireType.playerReady, seq: _nextSeq()),
        );
      } on Object {
        // A retry is best-effort; the host watchdog covers the ACK.
      }
    });
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
    final payload = transport.usesRelay
        ? await _compressPhoto(
            bytes,
            maxDimension: kRelayUploadDimension,
            quality: kRelayUploadQuality,
          )
        : bytes;
    for (final chunk in PhotoChunker.split(photo.photoId, payload)) {
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

  /// Screenshot detection and the wake lock are conveniences, never a
  /// precondition for opening a room. A platform channel that never answers
  /// must not leave the demo or a real lobby on a spinner forever.
  Future<void> _startPlatformServices() async {
    if (!platformServices) return;
    await _startScreenshots();
    await _setAwake(true);
  }

  Future<void> _stopPlatformServices() async {
    if (!platformServices) return;
    await _stopScreenshots();
    await _setAwake(false);
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
  /// A Party Pass holder can share a premium theme with the whole room. The
  /// host is authoritative and re-broadcasts it; a client only sends an intent.
  Future<void> setRoomTheme(RoomThemeId theme) async {
    if (theme.premium && !_partyPassActive) return;
    if (_state.roomId == null) return;
    if (!_state.isHosting) {
      _emit(_state.copyWith(roomThemeId: theme.wireId));
      await _clientTransport?.send(
        WireMessage(
          type: WireType.roomTheme,
          seq: _nextSeq(),
          payload: <String, dynamic>{'themeId': theme.wireId},
        ),
      );
      return;
    }
    await _applyRoomTheme(theme, broadcast: true);
  }

  Future<void> _applyRoomTheme(
    RoomThemeId theme, {
    required bool broadcast,
  }) async {
    _emit(_state.copyWith(roomThemeId: theme.wireId));
    if (!broadcast) return;
    await _hostTransport?.broadcast(
      WireMessage(
        type: WireType.roomTheme,
        seq: _nextSeq(),
        payload: <String, dynamic>{'themeId': theme.wireId},
      ),
    );
  }

  /// Buyer-only live soundboard. Plays locally first, then broadcasts the
  /// lightweight event so every phone in the room hears it.
  void playSoundEffect(PartySound sound) {
    if (!_partyPassActive) return;
    final playerId = _state.isHosting
        ? 'host'
        : (_state.localPlayerId ?? 'local');
    if (!_localSoundGate.tryPlay(playerId)) return;
    final event = SoundEffectEvent(
      playerId: playerId,
      playerName: _displayName,
      sound: sound,
      atMs: DateTime.now().millisecondsSinceEpoch,
    );
    unawaited(SoundboardService.instance.play(sound));
    _emit(_state.copyWith(lastSoundEffect: event));
    final message = WireMessage(
      type: WireType.soundEffect,
      seq: _nextSeq(),
      payload: event.toJson(),
    );
    if (_state.isHosting) {
      unawaited(_hostTransport?.broadcast(message));
    } else {
      unawaited(_clientTransport?.send(message));
    }
  }

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
    } on Object {
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
    _vaultWatchdog?.cancel();
    _vaultWatchdog = null;
    _clientReadyRetry?.cancel();
    _clientReadyRetry = null;
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
    await _stopPlatformServices();
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _roundTimer?.cancel();
    _countdownTicker?.cancel();
    _vaultWatchdog?.cancel();
    _vaultWatchdog = null;
    _vaultPreloaded = false;
    _clientReadyRetry?.cancel();
    _clientReadyRetry = null;
    _clientPhaseTicker?.cancel();
    _extendTicker?.cancel();
    _captionRevealTimer?.cancel();
    _revealAutoTimer?.cancel();
    _memesEmptyAdvanceTimer?.cancel();
    _timelineRevealTimer?.cancel();
    _memeTallyTimer?.cancel();
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
    _memePhotoBytes.clear();
    _pendingMemeAssignments.clear();
    _photoRequestAttempts.clear();
    _waitingPlayers.clear();
    _waitingClientIds.clear();
    _clientBuilds.clear();
    _clientVersions.clear();
    _clientPlayerIds.clear();
    _playerClientIds.clear();
    _playerTokens.clear();
    _blockedPlayers.clear();
    _avatarPhotos.clear();
    _partyPassPlayers.clear();
    _localSoundGate.clear();
    _remoteSoundGate.clear();
    if (forgetRoom) {
      await _lastRooms.forget();
    }
    PhotoMemoryCache.instance.clear();
    _emit(const MatchUiState());
    _leaving = false;
  }

  Future<void> dispose() async {
    _disposed = true;
    _memesEmptyAdvanceTimer?.cancel();
    _vaultWatchdog?.cancel();
    _clientReadyRetry?.cancel();
    await leaveMatch();
    await _states.close();
  }
}

/// Wraps an optional transport so a failed online path (no relay, no network)
/// never stops the local room from opening. The inner start runs in the
/// background, so a slow relay cannot delay the lobby or the QR code.
class BestEffortHostTransport implements HostTransport {
  BestEffortHostTransport(
    this._inner, {
    this.retryDelays = const <Duration>[
      Duration.zero,
      Duration(seconds: 1),
      Duration(seconds: 3),
    ],
  });

  final HostTransport _inner;
  final List<Duration> retryDelays;
  final StreamController<String> _connected =
      StreamController<String>.broadcast();
  final StreamController<String> _disconnected =
      StreamController<String>.broadcast();
  final StreamController<HostIncomingMessage> _messages =
      StreamController<HostIncomingMessage>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  final List<Future<void> Function()> _queued = <Future<void> Function()>[];
  int _queuedBytes = 0;
  bool _started = false;
  bool _closed = false;

  static const int _maxQueuedBytes = 16 * 1024 * 1024;
  static const int _maxQueuedItems = 1024;

  @override
  Stream<String> get clientConnected => _connected.stream;

  @override
  Stream<String> get clientDisconnected => _disconnected.stream;

  @override
  Stream<HostIncomingMessage> get messages => _messages.stream;

  @override
  String? get localLanEndpoint => null;

  @override
  Set<String> get clientIds => _started ? _inner.clientIds : const <String>{};

  @override
  bool isRelayed(String clientId) => _started && _inner.isRelayed(clientId);

  @override
  Future<void> start() async {
    if (_closed) return;
    _subscriptions.add(_inner.clientConnected.listen(_connected.add));
    _subscriptions.add(_inner.clientDisconnected.listen(_disconnected.add));
    _subscriptions.add(_inner.messages.listen(_messages.add));
    // The LAN side is already listening; a slow relay fetch must not hold the
    // lobby behind it. Retry in the background and replay sends when ready.
    unawaited(_startWithRetry());
  }

  Future<void> _startWithRetry() async {
    for (final delay in retryDelays) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (_closed) return;
      try {
        await _inner.start();
        if (_closed) {
          await _inner.close();
          return;
        }
        _started = true;
        final queued = List<Future<void> Function()>.of(_queued);
        _queued.clear();
        _queuedBytes = 0;
        for (final send in queued) {
          try {
            await send();
          } on Object {
            // One dropped frame must not stop the rest of the replay.
          }
        }
        return;
      } on Object {
        _started = false;
      }
    }
    _queued.clear();
    _queuedBytes = 0;
  }

  @override
  Future<void> sendToClient(String clientId, WireMessage message) async {
    if (_closed) return;
    if (_started) {
      await _inner.sendToClient(clientId, message);
      return;
    }
    _queue(message, () => _inner.sendToClient(clientId, message));
  }

  @override
  Future<void> broadcast(WireMessage message) async {
    if (_closed) return;
    if (_started) {
      await _inner.broadcast(message);
      return;
    }
    _queue(message, () => _inner.broadcast(message));
  }

  void _queue(WireMessage message, Future<void> Function() send) {
    final bytes = message.encode().length;
    if (_queued.length >= _maxQueuedItems ||
        _queuedBytes + bytes > _maxQueuedBytes) {
      assert(() {
        debugPrint('BestEffortHostTransport queue budget exhausted');
        return true;
      }());
      return;
    }
    _queuedBytes += bytes;
    _queued.add(send);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _queued.clear();
    _queuedBytes = 0;
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

/// Used only by the web playtest when the online transport is disabled.
class _UnavailableHostTransport implements HostTransport {
  const _UnavailableHostTransport();

  @override
  Stream<String> get clientConnected => const Stream<String>.empty();

  @override
  Stream<String> get clientDisconnected => const Stream<String>.empty();

  @override
  Stream<HostIncomingMessage> get messages =>
      const Stream<HostIncomingMessage>.empty();

  @override
  Set<String> get clientIds => const <String>{};

  @override
  String? get localLanEndpoint => null;

  @override
  bool isRelayed(String clientId) => false;

  @override
  Future<void> start() async {}

  @override
  Future<void> broadcast(WireMessage message) async {}

  @override
  Future<void> sendToClient(String clientId, WireMessage message) async {}

  @override
  Future<void> close() async {}
}
