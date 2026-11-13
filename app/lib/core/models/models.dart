import 'dart:typed_data';

/// One participant in a match. Owned and mutated by the host engine.
class Player {
  Player({
    required this.id,
    required this.name,
    this.avatarColorIndex = 0,
    this.isHost = false,
    this.ready = false,
    this.connected = true,
    this.score = 0,
    this.streak = 0,
    this.longestStreak = 0,
    this.plantUsed = false,
    this.screenshotCount = 0,
    this.correctCount = 0,
    this.totalCorrectMs = 0,
    this.mysteryPointsEarned = 0,
  });

  final String id;
  String name;
  int avatarColorIndex;
  final bool isHost;
  bool ready;
  bool connected;
  int score;
  int streak;
  int longestStreak;
  bool plantUsed;
  int screenshotCount;
  int correctCount;
  int totalCorrectMs;
  int mysteryPointsEarned;

  /// Average milliseconds per correct opponent guess, or null when none.
  int? get averageCorrectMs =>
      correctCount == 0 ? null : totalCorrectMs ~/ correctCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'avatarColorIndex': avatarColorIndex,
    'isHost': isHost,
    'ready': ready,
    'connected': connected,
    'score': score,
    'streak': streak,
    'longestStreak': longestStreak,
    'plantUsed': plantUsed,
    'screenshotCount': screenshotCount,
    'correctCount': correctCount,
    'totalCorrectMs': totalCorrectMs,
    'mysteryPointsEarned': mysteryPointsEarned,
  };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    id: json['id'] as String,
    name: json['name'] as String,
    avatarColorIndex: (json['avatarColorIndex'] as int?) ?? 0,
    isHost: (json['isHost'] as bool?) ?? false,
    ready: (json['ready'] as bool?) ?? false,
    connected: (json['connected'] as bool?) ?? true,
    score: (json['score'] as int?) ?? 0,
    streak: (json['streak'] as int?) ?? 0,
    longestStreak: (json['longestStreak'] as int?) ?? 0,
    plantUsed: (json['plantUsed'] as bool?) ?? false,
    screenshotCount: (json['screenshotCount'] as int?) ?? 0,
    correctCount: (json['correctCount'] as int?) ?? 0,
    totalCorrectMs: (json['totalCorrectMs'] as int?) ?? 0,
    mysteryPointsEarned: (json['mysteryPointsEarned'] as int?) ?? 0,
  );
}

/// Match shape chosen in the lobby.
class MatchConfig {
  const MatchConfig({this.roundsK = 10, this.roundSeconds = 8})
    : assert(roundsK > 0),
      assert(roundSeconds > 0);

  final int roundsK;
  final int roundSeconds;

  int get roundMs => roundSeconds * 1000;

  MatchConfig copyWith({int? roundsK, int? roundSeconds}) => MatchConfig(
    roundsK: roundsK ?? this.roundsK,
    roundSeconds: roundSeconds ?? this.roundSeconds,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'roundsK': roundsK,
    'roundSeconds': roundSeconds,
  };

  factory MatchConfig.fromJson(Map<String, dynamic> json) => MatchConfig(
    roundsK: (json['roundsK'] as int?) ?? 10,
    roundSeconds: (json['roundSeconds'] as int?) ?? 8,
  );
}

/// A photo a player approved for the match. [bytes] is only carried on the
/// device that owns the photo; the host may hold compressed bytes in memory.
class PhotoCandidate {
  const PhotoCandidate({
    required this.photoId,
    required this.localAssetId,
    required this.ownerId,
    this.bytes,
    this.isPlanted = false,
  });

  final String photoId;
  final String localAssetId;
  final String ownerId;
  final Uint8List? bytes;
  final bool isPlanted;

  PhotoCandidate copyWith({
    String? photoId,
    String? localAssetId,
    String? ownerId,
    Uint8List? bytes,
    bool? isPlanted,
  }) => PhotoCandidate(
    photoId: photoId ?? this.photoId,
    localAssetId: localAssetId ?? this.localAssetId,
    ownerId: ownerId ?? this.ownerId,
    bytes: bytes ?? this.bytes,
    isPlanted: isPlanted ?? this.isPlanted,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'photoId': photoId,
    'localAssetId': localAssetId,
    'ownerId': ownerId,
    'isPlanted': isPlanted,
  };

  factory PhotoCandidate.fromJson(Map<String, dynamic> json) => PhotoCandidate(
    photoId: json['photoId'] as String,
    localAssetId: (json['localAssetId'] as String?) ?? '',
    ownerId: json['ownerId'] as String,
    isPlanted: (json['isPlanted'] as bool?) ?? false,
  );
}

enum RoundPhase {
  lobby,
  preparing,
  countdown,
  guessing,
  reveal,
  extendPrompt,
  podium,
}

/// One player's locked-in guess for a round.
class GuessRecord {
  const GuessRecord({
    required this.playerId,
    required this.guessedOwnerId,
    required this.elapsedMs,
    required this.isCorrect,
    required this.isOwnPhoto,
    required this.pointsAwarded,
  });

  final String playerId;
  final String guessedOwnerId;
  final int elapsedMs;
  final bool isCorrect;
  final bool isOwnPhoto;
  final int pointsAwarded;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'playerId': playerId,
    'guessedOwnerId': guessedOwnerId,
    'elapsedMs': elapsedMs,
    'isCorrect': isCorrect,
    'isOwnPhoto': isOwnPhoto,
    'pointsAwarded': pointsAwarded,
  };

  factory GuessRecord.fromJson(Map<String, dynamic> json) => GuessRecord(
    playerId: json['playerId'] as String,
    guessedOwnerId: json['guessedOwnerId'] as String,
    elapsedMs: json['elapsedMs'] as int,
    isCorrect: json['isCorrect'] as bool,
    isOwnPhoto: json['isOwnPhoto'] as bool,
    pointsAwarded: json['pointsAwarded'] as int,
  );
}

/// Everything the reveal screen needs for one round.
class RoundReveal {
  const RoundReveal({
    required this.roundNumber,
    required this.ownerId,
    required this.photoId,
    required this.isPlanted,
    required this.guesses,
    required this.scoreDeltas,
    required this.streaks,
    this.microAward,
    this.nobodyGuessed = false,
    this.everyoneGuessed = false,
  });

  final int roundNumber;
  final String ownerId;
  final String photoId;
  final bool isPlanted;
  final List<GuessRecord> guesses;
  final Map<String, int> scoreDeltas;
  final Map<String, int> streaks;
  final MicroAward? microAward;
  final bool nobodyGuessed;
  final bool everyoneGuessed;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'roundNumber': roundNumber,
    'ownerId': ownerId,
    'photoId': photoId,
    'isPlanted': isPlanted,
    'guesses': guesses.map((g) => g.toJson()).toList(),
    'scoreDeltas': scoreDeltas,
    'streaks': streaks,
    'microAward': microAward?.toJson(),
    'nobodyGuessed': nobodyGuessed,
    'everyoneGuessed': everyoneGuessed,
  };

  factory RoundReveal.fromJson(Map<String, dynamic> json) => RoundReveal(
    roundNumber: json['roundNumber'] as int,
    ownerId: json['ownerId'] as String,
    photoId: json['photoId'] as String,
    isPlanted: (json['isPlanted'] as bool?) ?? false,
    guesses: (json['guesses'] as List<dynamic>)
        .map((e) => GuessRecord.fromJson(e as Map<String, dynamic>))
        .toList(),
    scoreDeltas: (json['scoreDeltas'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as int),
    ),
    streaks: (json['streaks'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as int),
    ),
    microAward: json['microAward'] == null
        ? null
        : MicroAward.fromJson(json['microAward'] as Map<String, dynamic>),
    nobodyGuessed: (json['nobodyGuessed'] as bool?) ?? false,
    everyoneGuessed: (json['everyoneGuessed'] as bool?) ?? false,
  );
}

enum MicroAwardKind { fastestGuess, nobodyGuessed, everyoneGuessed, screenshot }

/// The single rotating callout shown on the inter-round scoreboard.
class MicroAward {
  const MicroAward({
    required this.kind,
    this.playerId,
    this.playerName,
    this.elapsedMs,
  });

  final MicroAwardKind kind;
  final String? playerId;
  final String? playerName;
  final int? elapsedMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.name,
    'playerId': playerId,
    'playerName': playerName,
    'elapsedMs': elapsedMs,
  };

  factory MicroAward.fromJson(Map<String, dynamic> json) => MicroAward(
    kind: MicroAwardKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => MicroAwardKind.fastestGuess,
    ),
    playerId: json['playerId'] as String?,
    playerName: json['playerName'] as String?,
    elapsedMs: json['elapsedMs'] as int?,
  );
}

enum MatchAwardKind {
  champion,
  quickestDraw,
  unstoppable,
  masterOfMystery,
  paparazzi,
  smoothPlanter,
}

class MatchAward {
  const MatchAward({
    required this.kind,
    required this.playerId,
    required this.playerName,
    this.value,
  });

  final MatchAwardKind kind;
  final String playerId;
  final String playerName;

  /// Kind specific figure: ms for quickest draw, streak length, points, count.
  final int? value;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.name,
    'playerId': playerId,
    'playerName': playerName,
    'value': value,
  };

  factory MatchAward.fromJson(Map<String, dynamic> json) => MatchAward(
    kind: MatchAwardKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => MatchAwardKind.champion,
    ),
    playerId: json['playerId'] as String,
    playerName: json['playerName'] as String,
    value: json['value'] as int?,
  );
}

enum ThemePreference { system, light, dark }

enum ConnectionMode { localLan, webrtcP2p, webrtcTurn, offlineLoopback }

/// Locally persisted preferences. No account, no server-side profile.
class AppSettings {
  const AppSettings({
    this.nickname = '',
    this.avatarColorIndex = 0,
    this.excludedAlbumIds = const <String>{},
    this.themePreference = ThemePreference.system,
    this.onboardingCompleted = false,
    this.customSignalingUrl,
    this.customTurnUrl,
    this.customTurnUsername,
    this.customTurnCredential,
  });

  final String nickname;
  final int avatarColorIndex;
  final Set<String> excludedAlbumIds;
  final ThemePreference themePreference;
  final bool onboardingCompleted;
  final String? customSignalingUrl;
  final String? customTurnUrl;
  final String? customTurnUsername;
  final String? customTurnCredential;

  AppSettings copyWith({
    String? nickname,
    int? avatarColorIndex,
    Set<String>? excludedAlbumIds,
    ThemePreference? themePreference,
    bool? onboardingCompleted,
    String? customSignalingUrl,
    String? customTurnUrl,
    String? customTurnUsername,
    String? customTurnCredential,
    bool clearCustomSignalingUrl = false,
    bool clearTurn = false,
  }) => AppSettings(
    nickname: nickname ?? this.nickname,
    avatarColorIndex: avatarColorIndex ?? this.avatarColorIndex,
    excludedAlbumIds: excludedAlbumIds ?? this.excludedAlbumIds,
    themePreference: themePreference ?? this.themePreference,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    customSignalingUrl: clearCustomSignalingUrl
        ? null
        : (customSignalingUrl ?? this.customSignalingUrl),
    customTurnUrl: clearTurn ? null : (customTurnUrl ?? this.customTurnUrl),
    customTurnUsername: clearTurn
        ? null
        : (customTurnUsername ?? this.customTurnUsername),
    customTurnCredential: clearTurn
        ? null
        : (customTurnCredential ?? this.customTurnCredential),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'nickname': nickname,
    'avatarColorIndex': avatarColorIndex,
    'excludedAlbumIds': excludedAlbumIds.toList()..sort(),
    'themePreference': themePreference.name,
    'onboardingCompleted': onboardingCompleted,
    'customSignalingUrl': customSignalingUrl,
    'customTurnUrl': customTurnUrl,
    'customTurnUsername': customTurnUsername,
    'customTurnCredential': customTurnCredential,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    nickname: (json['nickname'] as String?) ?? '',
    avatarColorIndex: (json['avatarColorIndex'] as int?) ?? 0,
    excludedAlbumIds: ((json['excludedAlbumIds'] as List<dynamic>?) ?? const [])
        .cast<String>()
        .toSet(),
    themePreference: ThemePreference.values.firstWhere(
      (t) => t.name == json['themePreference'],
      orElse: () => ThemePreference.system,
    ),
    onboardingCompleted: (json['onboardingCompleted'] as bool?) ?? false,
    customSignalingUrl: json['customSignalingUrl'] as String?,
    customTurnUrl: json['customTurnUrl'] as String?,
    customTurnUsername: json['customTurnUsername'] as String?,
    customTurnCredential: json['customTurnCredential'] as String?,
  );
}

/// Returned by the signaling server when TURN relay quota is exhausted.
class TurnLimitNotice {
  const TurnLimitNotice({
    required this.reason,
    required this.dailyLimit,
    required this.usedToday,
    required this.retryAtUtc,
  });

  final String reason;
  final int dailyLimit;
  final int usedToday;
  final DateTime retryAtUtc;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'reason': reason,
    'dailyLimit': dailyLimit,
    'usedToday': usedToday,
    'retryAtUtc': retryAtUtc.toUtc().toIso8601String(),
  };

  factory TurnLimitNotice.fromJson(Map<String, dynamic> json) =>
      TurnLimitNotice(
        reason: (json['reason'] as String?) ?? 'DAILY_TURN_LIMIT_REACHED',
        dailyLimit: (json['dailyLimit'] as int?) ?? 5,
        usedToday: (json['usedToday'] as int?) ?? 0,
        retryAtUtc: DateTime.parse(json['retryAtUtc'] as String),
      );
}
