import 'dart:typed_data';

/// One participant in a match. Owned and mutated by the host engine.
class Player {
  Player({
    required this.id,
    required this.name,
    this.avatar = 'pets',
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
  String avatar;
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
    'avatar': avatar,
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
    avatar: (json['avatar'] as String?) ?? 'pets',
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

enum GameMode { classic, captionThis, makeItMeme, timeTraveler, mixedParty }

/// Match shape chosen before the room opens.
enum GamePace {
  fast,
  normal,
  slow;

  int get classicSeconds => switch (this) {
    GamePace.fast => 5,
    GamePace.normal => 8,
    GamePace.slow => 12,
  };

  int get captionSeconds => switch (this) {
    GamePace.fast => 25,
    GamePace.normal => 40,
    GamePace.slow => 60,
  };

  int get timelineSeconds => switch (this) {
    GamePace.fast => 15,
    GamePace.normal => 25,
    GamePace.slow => 40,
  };

  int get memeSeconds => switch (this) {
    GamePace.fast => 60,
    GamePace.normal => 90,
    GamePace.slow => 120,
  };

  int mainSeconds(GameMode mode) => switch (mode) {
    GameMode.classic || GameMode.mixedParty => classicSeconds,
    GameMode.captionThis => captionSeconds,
    GameMode.makeItMeme => memeSeconds,
    GameMode.timeTraveler => timelineSeconds,
  };
}

class MatchConfig {
  const MatchConfig({
    this.roundsK = 10,
    this.roundSeconds = 8,
    this.mode = GameMode.classic,
    this.pace = GamePace.normal,
  }) : assert(roundsK > 0),
       assert(roundSeconds > 0);

  final int roundsK;
  final int roundSeconds;
  final GameMode mode;
  final GamePace pace;

  int get roundMs => roundSeconds * 1000;

  /// Time Traveler needs a verified capture date, and a mixed match uses the
  /// same photo pool for its timeline rounds.
  bool get needsPhotoDates =>
      mode == GameMode.timeTraveler || mode == GameMode.mixedParty;

  bool get needsSixPhotoVault => mode == GameMode.makeItMeme;

  MatchConfig copyWith({
    int? roundsK,
    int? roundSeconds,
    GameMode? mode,
    GamePace? pace,
  }) => MatchConfig(
    roundsK: roundsK ?? this.roundsK,
    roundSeconds: roundSeconds ?? this.roundSeconds,
    mode: mode ?? this.mode,
    pace: pace ?? this.pace,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'roundsK': roundsK,
    'roundSeconds': roundSeconds,
    'mode': mode.name,
    'pace': pace.name,
  };

  factory MatchConfig.fromJson(Map<String, dynamic> json) => MatchConfig(
    roundsK: (json['roundsK'] as int?) ?? 10,
    roundSeconds: (json['roundSeconds'] as int?) ?? 8,
    mode: GameMode.values.firstWhere(
      (mode) => mode.name == json['mode'],
      orElse: () => GameMode.classic,
    ),
    pace: GamePace.values.firstWhere(
      (pace) => pace.name == json['pace'],
      orElse: () => GamePace.normal,
    ),
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
    this.isPanorama = false,
    this.capturedYear,
    this.capturedMonth,
  });

  final String photoId;
  final String localAssetId;
  final String ownerId;
  final Uint8List? bytes;
  final bool isPlanted;
  final bool isPanorama;

  /// Capture month from the gallery. Only the year and month are ever sent
  /// over the wire, so a Time Traveler round cannot leak the full timestamp.
  final int? capturedYear;
  final int? capturedMonth;

  bool get hasCaptureDate => capturedYear != null && capturedMonth != null;

  PhotoCandidate copyWith({
    String? photoId,
    String? localAssetId,
    String? ownerId,
    Uint8List? bytes,
    bool? isPlanted,
    bool? isPanorama,
    int? capturedYear,
    int? capturedMonth,
  }) => PhotoCandidate(
    photoId: photoId ?? this.photoId,
    localAssetId: localAssetId ?? this.localAssetId,
    ownerId: ownerId ?? this.ownerId,
    bytes: bytes ?? this.bytes,
    isPlanted: isPlanted ?? this.isPlanted,
    isPanorama: isPanorama ?? this.isPanorama,
    capturedYear: capturedYear ?? this.capturedYear,
    capturedMonth: capturedMonth ?? this.capturedMonth,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'photoId': photoId,
    'localAssetId': localAssetId,
    'ownerId': ownerId,
    'isPlanted': isPlanted,
    'isPanorama': isPanorama,
    'capturedYear': capturedYear,
    'capturedMonth': capturedMonth,
  };

  factory PhotoCandidate.fromJson(Map<String, dynamic> json) {
    var year = json['capturedYear'] as int?;
    var month = json['capturedMonth'] as int?;
    final legacy = json['capturedAtMs'];
    if (legacy is int && (year == null || month == null)) {
      final date = DateTime.fromMillisecondsSinceEpoch(legacy);
      year ??= date.year;
      month ??= date.month;
    }
    return PhotoCandidate(
      photoId: json['photoId'] as String,
      localAssetId: (json['localAssetId'] as String?) ?? '',
      ownerId: json['ownerId'] as String,
      isPlanted: (json['isPlanted'] as bool?) ?? false,
      isPanorama: (json['isPanorama'] as bool?) ?? false,
      capturedYear: year,
      capturedMonth: month,
    );
  }
}

enum RoundPhase {
  lobby,
  preparing,
  countdown,
  guessing,
  reveal,
  captionWriting,
  captionVoting,
  captionReveal,
  timelineGuessing,
  timelineReveal,
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

/// One anonymous caption shown to voters.
class CaptionOption {
  const CaptionOption({required this.id, required this.text});

  final String id;
  final String text;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'text': text};

  factory CaptionOption.fromJson(Map<String, dynamic> json) =>
      CaptionOption(id: json['id'] as String, text: json['text'] as String);
}

/// A caption after the votes are counted, with its author revealed.
class CaptionEntry {
  const CaptionEntry({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.votes,
    required this.points,
  });

  final String id;
  final String text;
  final String authorId;
  final String authorName;
  final int votes;
  final int points;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'text': text,
    'authorId': authorId,
    'authorName': authorName,
    'votes': votes,
    'points': points,
  };

  factory CaptionEntry.fromJson(Map<String, dynamic> json) => CaptionEntry(
    id: json['id'] as String,
    text: json['text'] as String,
    authorId: json['authorId'] as String,
    authorName: json['authorName'] as String,
    votes: json['votes'] as int,
    points: json['points'] as int,
  );
}

class CaptionReveal {
  const CaptionReveal({
    required this.roundNumber,
    required this.photoId,
    required this.ownerId,
    required this.entries,
    required this.winnerIds,
    required this.scoreDeltas,
  });

  final int roundNumber;
  final String photoId;
  final String ownerId;
  final List<CaptionEntry> entries;
  final List<String> winnerIds;
  final Map<String, int> scoreDeltas;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'roundNumber': roundNumber,
    'photoId': photoId,
    'ownerId': ownerId,
    'entries': entries.map((entry) => entry.toJson()).toList(),
    'winnerIds': winnerIds,
    'scoreDeltas': scoreDeltas,
  };

  factory CaptionReveal.fromJson(Map<String, dynamic> json) => CaptionReveal(
    roundNumber: json['roundNumber'] as int,
    photoId: json['photoId'] as String,
    ownerId: json['ownerId'] as String,
    entries: (json['entries'] as List<dynamic>)
        .map((entry) => CaptionEntry.fromJson(entry as Map<String, dynamic>))
        .toList(),
    winnerIds: ((json['winnerIds'] as List<dynamic>?) ?? const [])
        .cast<String>(),
    scoreDeltas: (json['scoreDeltas'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as int),
    ),
  );
}

enum MemeTemplate { classic, pov, breaking, live, poster, snap, split }

enum MemeVote { up, meh, down }

/// Host-side assignment of one photo from another player's six-photo vault.
class MemeAssignment {
  const MemeAssignment({
    required this.playerId,
    required this.photoId,
    required this.ownerId,
    required this.ownerName,
    this.isPanorama = false,
  });

  final String playerId;
  final String photoId;
  final String ownerId;
  final String ownerName;
  final bool isPanorama;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'playerId': playerId,
    'photoId': photoId,
    'ownerId': ownerId,
    'ownerName': ownerName,
    'isPanorama': isPanorama,
  };

  factory MemeAssignment.fromJson(Map<String, dynamic> json) => MemeAssignment(
    playerId: json['playerId'] as String? ?? '',
    photoId: json['photoId'] as String? ?? '',
    ownerId: json['ownerId'] as String? ?? '',
    ownerName: json['ownerName'] as String? ?? '',
    isPanorama: json['isPanorama'] as bool? ?? false,
  );
}

/// A completed meme submission. Author is kept on the host until the reveal.
class MemeSubmission {
  const MemeSubmission({
    required this.id,
    required this.playerId,
    required this.photoId,
    required this.photoOwnerId,
    required this.template,
    required this.topText,
    required this.bottomText,
    required this.snapY,
  });

  final String id;
  final String playerId;
  final String photoId;
  final String photoOwnerId;
  final MemeTemplate template;
  final String topText;
  final String bottomText;
  final double snapY;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'playerId': playerId,
    'photoId': photoId,
    'photoOwnerId': photoOwnerId,
    'template': template.name,
    'topText': topText,
    'bottomText': bottomText,
    'snapY': snapY,
  };
}

/// One anonymous meme shown during voting.
class MemeOption {
  const MemeOption({
    required this.id,
    required this.photoId,
    required this.template,
    required this.topText,
    required this.bottomText,
    required this.snapY,
  });

  final String id;
  final String photoId;
  final MemeTemplate template;
  final String topText;
  final String bottomText;
  final double snapY;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'photoId': photoId,
    'template': template.name,
    'topText': topText,
    'bottomText': bottomText,
    'snapY': snapY,
  };

  factory MemeOption.fromJson(Map<String, dynamic> json) => MemeOption(
    id: json['id'] as String,
    photoId: json['photoId'] as String,
    template: MemeTemplate.values.firstWhere(
      (value) => value.name == json['template'],
      orElse: () => MemeTemplate.classic,
    ),
    topText: (json['topText'] as String?) ?? '',
    bottomText: (json['bottomText'] as String?) ?? '',
    snapY: (json['snapY'] as num?)?.toDouble() ?? 48,
  );
}

class MemeVoteRecord {
  const MemeVoteRecord({
    required this.voterId,
    required this.memeId,
    required this.vote,
  });

  final String voterId;
  final String memeId;
  final MemeVote vote;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'voterId': voterId,
    'memeId': memeId,
    'vote': vote.name,
  };

  factory MemeVoteRecord.fromJson(Map<String, dynamic> json) => MemeVoteRecord(
    voterId: json['voterId'] as String,
    memeId: json['memeId'] as String,
    vote: MemeVote.values.firstWhere(
      (value) => value.name == json['vote'],
      orElse: () => MemeVote.meh,
    ),
  );
}

/// A meme after the votes are counted. The author is revealed here.
class MemeEntry {
  const MemeEntry({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.photoId,
    required this.photoOwnerId,
    required this.photoOwnerName,
    required this.template,
    required this.topText,
    required this.bottomText,
    required this.snapY,
    required this.upVotes,
    required this.mehVotes,
    required this.downVotes,
    required this.points,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String photoId;
  final String photoOwnerId;
  final String photoOwnerName;
  final MemeTemplate template;
  final String topText;
  final String bottomText;
  final double snapY;
  final int upVotes;
  final int mehVotes;
  final int downVotes;
  final int points;

  int get totalVotes => upVotes + mehVotes + downVotes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'authorId': authorId,
    'authorName': authorName,
    'photoId': photoId,
    'photoOwnerId': photoOwnerId,
    'photoOwnerName': photoOwnerName,
    'template': template.name,
    'topText': topText,
    'bottomText': bottomText,
    'snapY': snapY,
    'upVotes': upVotes,
    'mehVotes': mehVotes,
    'downVotes': downVotes,
    'points': points,
  };

  factory MemeEntry.fromJson(Map<String, dynamic> json) => MemeEntry(
    id: json['id'] as String,
    authorId: json['authorId'] as String,
    authorName: json['authorName'] as String,
    photoId: json['photoId'] as String,
    photoOwnerId: json['photoOwnerId'] as String,
    photoOwnerName: json['photoOwnerName'] as String,
    template: MemeTemplate.values.firstWhere(
      (value) => value.name == json['template'],
      orElse: () => MemeTemplate.classic,
    ),
    topText: (json['topText'] as String?) ?? '',
    bottomText: (json['bottomText'] as String?) ?? '',
    snapY: (json['snapY'] as num?)?.toDouble() ?? 48,
    upVotes: (json['upVotes'] as int?) ?? 0,
    mehVotes: (json['mehVotes'] as int?) ?? 0,
    downVotes: (json['downVotes'] as int?) ?? 0,
    points: (json['points'] as int?) ?? 0,
  );
}

class MemeReveal {
  const MemeReveal({
    required this.roundNumber,
    required this.entries,
    required this.winnerIds,
    required this.scoreDeltas,
  });

  final int roundNumber;
  final List<MemeEntry> entries;
  final List<String> winnerIds;
  final Map<String, int> scoreDeltas;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'roundNumber': roundNumber,
    'entries': entries.map((entry) => entry.toJson()).toList(),
    'winnerIds': winnerIds,
    'scoreDeltas': scoreDeltas,
  };

  factory MemeReveal.fromJson(Map<String, dynamic> json) => MemeReveal(
    roundNumber: json['roundNumber'] as int,
    entries: (json['entries'] as List<dynamic>? ?? const [])
        .map((entry) => MemeEntry.fromJson(entry as Map<String, dynamic>))
        .toList(),
    winnerIds: ((json['winnerIds'] as List<dynamic>?) ?? const [])
        .cast<String>(),
    scoreDeltas: (json['scoreDeltas'] as Map<String, dynamic>? ?? const {}).map(
      (key, value) => MapEntry(key, value as int),
    ),
  );
}

class TimelineGuess {
  const TimelineGuess({
    required this.playerId,
    required this.year,
    required this.month,
    required this.elapsedMs,
  });

  final String playerId;
  final int year;
  final int month;
  final int elapsedMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'playerId': playerId,
    'year': year,
    'month': month,
    'elapsedMs': elapsedMs,
  };

  factory TimelineGuess.fromJson(Map<String, dynamic> json) => TimelineGuess(
    playerId: json['playerId'] as String,
    year: json['year'] as int,
    month: json['month'] as int,
    elapsedMs: json['elapsedMs'] as int,
  );
}

class TimelineEntry {
  const TimelineEntry({
    required this.playerId,
    required this.playerName,
    required this.points,
    this.year,
    this.month,
    this.monthsOff,
    this.isOwner = false,
    this.timedOut = false,
  });

  final String playerId;
  final String playerName;
  final int points;
  final int? year;
  final int? month;
  final int? monthsOff;
  final bool isOwner;
  final bool timedOut;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'playerId': playerId,
    'playerName': playerName,
    'points': points,
    'year': year,
    'month': month,
    'monthsOff': monthsOff,
    'isOwner': isOwner,
    'timedOut': timedOut,
  };

  factory TimelineEntry.fromJson(Map<String, dynamic> json) => TimelineEntry(
    playerId: json['playerId'] as String,
    playerName: json['playerName'] as String,
    points: json['points'] as int,
    year: json['year'] as int?,
    month: json['month'] as int?,
    monthsOff: json['monthsOff'] as int?,
    isOwner: (json['isOwner'] as bool?) ?? false,
    timedOut: (json['timedOut'] as bool?) ?? false,
  );
}

class TimelineReveal {
  const TimelineReveal({
    required this.roundNumber,
    required this.photoId,
    required this.ownerId,
    required this.actualYear,
    required this.actualMonth,
    required this.entries,
    required this.scoreDeltas,
    this.closestId,
    this.furthestId,
  });

  final int roundNumber;
  final String photoId;
  final String ownerId;
  final int actualYear;
  final int actualMonth;
  final List<TimelineEntry> entries;
  final Map<String, int> scoreDeltas;
  final String? closestId;
  final String? furthestId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'roundNumber': roundNumber,
    'photoId': photoId,
    'ownerId': ownerId,
    'actualYear': actualYear,
    'actualMonth': actualMonth,
    'entries': entries.map((entry) => entry.toJson()).toList(),
    'scoreDeltas': scoreDeltas,
    'closestId': closestId,
    'furthestId': furthestId,
  };

  factory TimelineReveal.fromJson(Map<String, dynamic> json) => TimelineReveal(
    roundNumber: json['roundNumber'] as int,
    photoId: json['photoId'] as String,
    ownerId: json['ownerId'] as String,
    actualYear: json['actualYear'] as int,
    actualMonth: json['actualMonth'] as int,
    entries: (json['entries'] as List<dynamic>)
        .map((entry) => TimelineEntry.fromJson(entry as Map<String, dynamic>))
        .toList(),
    scoreDeltas: (json['scoreDeltas'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as int),
    ),
    closestId: json['closestId'] as String?,
    furthestId: json['furthestId'] as String?,
  );
}

enum ThemePreference { system, light, dark }

enum AppLanguage { system, english, dutch }

enum ConnectionMode { localLan, webrtcP2p, webrtcTurn, offlineLoopback }

/// Wire id for the free theme. Premium ids live in room_theme.dart.
const String kDefaultRoomThemeId = 'classic_party';

/// Locally persisted preferences. No account, no server-side profile.
class AppSettings {
  const AppSettings({
    this.nickname = '',
    this.avatar = 'pets',
    this.avatarColorIndex = 0,
    this.excludedAlbumIds = const <String>{},
    this.themePreference = ThemePreference.system,
    this.language = AppLanguage.system,
    this.avatarPhoto,
    this.onboardingCompleted = false,
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.hapticsEnabled = true,
    this.customSignalingUrl,
    this.customTurnUrl,
    this.customTurnUsername,
    this.customTurnCredential,
  });

  final String nickname;
  final String avatar;
  final int avatarColorIndex;
  final Set<String> excludedAlbumIds;
  final ThemePreference themePreference;
  final AppLanguage language;

  /// A 192 px JPEG data URL for the optional photo avatar. It is stored on
  /// this phone and sent only inside a match.
  final String? avatarPhoto;
  final bool onboardingCompleted;
  final bool soundEnabled;
  final bool musicEnabled;
  final bool hapticsEnabled;
  final String? customSignalingUrl;
  final String? customTurnUrl;
  final String? customTurnUsername;
  final String? customTurnCredential;

  AppSettings copyWith({
    String? nickname,
    String? avatar,
    int? avatarColorIndex,
    Set<String>? excludedAlbumIds,
    ThemePreference? themePreference,
    AppLanguage? language,
    String? avatarPhoto,
    bool? onboardingCompleted,
    bool? soundEnabled,
    bool? musicEnabled,
    bool? hapticsEnabled,
    bool clearAvatarPhoto = false,
    String? customSignalingUrl,
    String? customTurnUrl,
    String? customTurnUsername,
    String? customTurnCredential,
    bool clearCustomSignalingUrl = false,
    bool clearTurn = false,
  }) => AppSettings(
    nickname: nickname ?? this.nickname,
    avatar: avatar ?? this.avatar,
    avatarColorIndex: avatarColorIndex ?? this.avatarColorIndex,
    excludedAlbumIds: excludedAlbumIds ?? this.excludedAlbumIds,
    themePreference: themePreference ?? this.themePreference,
    language: language ?? this.language,
    avatarPhoto: clearAvatarPhoto ? null : (avatarPhoto ?? this.avatarPhoto),
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    musicEnabled: musicEnabled ?? this.musicEnabled,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
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
    'avatar': avatar,
    'avatarColorIndex': avatarColorIndex,
    'excludedAlbumIds': excludedAlbumIds.toList()..sort(),
    'themePreference': themePreference.name,
    'language': language.name,
    'avatarPhoto': avatarPhoto,
    'onboardingCompleted': onboardingCompleted,
    'soundEnabled': soundEnabled,
    'musicEnabled': musicEnabled,
    'hapticsEnabled': hapticsEnabled,
    'customSignalingUrl': customSignalingUrl,
    'customTurnUrl': customTurnUrl,
    'customTurnUsername': customTurnUsername,
    'customTurnCredential': customTurnCredential,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    nickname: (json['nickname'] as String?) ?? '',
    avatar: (json['avatar'] as String?) ?? 'pets',
    avatarColorIndex: (json['avatarColorIndex'] as int?) ?? 0,
    excludedAlbumIds: ((json['excludedAlbumIds'] as List<dynamic>?) ?? const [])
        .cast<String>()
        .toSet(),
    themePreference: ThemePreference.values.firstWhere(
      (t) => t.name == json['themePreference'],
      orElse: () => ThemePreference.system,
    ),
    language: AppLanguage.values.firstWhere(
      (value) => value.name == json['language'],
      orElse: () => AppLanguage.system,
    ),
    avatarPhoto: json['avatarPhoto'] as String?,
    onboardingCompleted: (json['onboardingCompleted'] as bool?) ?? false,
    soundEnabled: (json['soundEnabled'] as bool?) ?? true,
    musicEnabled: (json['musicEnabled'] as bool?) ?? true,
    hapticsEnabled: (json['hapticsEnabled'] as bool?) ?? true,
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
        dailyLimit: (json['dailyLimit'] as int?) ?? 20,
        usedToday: (json['usedToday'] as int?) ?? 0,
        retryAtUtc: DateTime.parse(json['retryAtUtc'] as String),
      );
}

/// Raised when someone in the room runs a newer build. The room keeps playing;
/// the warning only asks the older phone to update.
class VersionWarning {
  const VersionWarning({
    required this.latestVersion,
    required this.latestBuild,
    required this.ownVersion,
    required this.ownBuild,
  });

  final String latestVersion;
  final int latestBuild;
  final String ownVersion;
  final int ownBuild;

  bool get isNewer => latestBuild > ownBuild;
}
