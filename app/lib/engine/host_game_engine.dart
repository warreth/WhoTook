import 'dart:math';

import '../core/models/models.dart';

class EngineException implements Exception {
  const EngineException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'EngineException($code): $message';
}

/// One slot of the balanced deck.
class DeckEntry {
  DeckEntry({
    required this.roundNumber,
    required this.ownerId,
    required this.photo,
    this.mode = GameMode.classic,
  });

  final int roundNumber;
  final String ownerId;
  final PhotoCandidate photo;
  final GameMode mode;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'roundNumber': roundNumber,
    'ownerId': ownerId,
    'photo': photo.toJson(),
    'mode': mode.name,
  };
}

/// Host-authoritative match state machine. All randomness comes from [random],
/// so a seeded engine replays identically.
class HostGameEngine {
  HostGameEngine({
    MatchConfig config = const MatchConfig(),
    Random? random,
    this.planterOverride,
    DateTime Function()? clock,
  }) : _roundsK = config.roundsK,
       _roundSeconds = config.roundSeconds,
       _mode = config.mode,
       _pace = config.pace,
       _random = random ?? Random(),
       _clock = clock ?? DateTime.now;

  static const int minPhotosNeeded = 3;
  static const int mysteryBonusPerFooledOpponent = 150;
  static const int streakBonusCap = 400;
  static const int streakBonusStep = 100;
  static const int correctBasePoints = 500;
  static const int correctSpeedPoints = 500;
  static const int extendWindowMs = 10000;
  static const int defaultExtraRounds = 5;
  static const int defaultExtraPhotos = 3;

  final Random _random;
  final String? planterOverride;
  final DateTime Function() _clock;
  final Map<String, Player> _players = <String, Player>{};
  final List<DeckEntry> _deck = <DeckEntry>[];
  final Map<String, List<PhotoCandidate>> _photoQueue =
      <String, List<PhotoCandidate>>{};
  final Map<String, int> _photoCursor = <String, int>{};
  final Map<String, int> _roundDeltas = <String, int>{};
  final Map<String, GuessRecord> _guesses = <String, GuessRecord>{};
  final Map<String, String> _captions = <String, String>{};
  final Map<String, String> _captionIdByPlayer = <String, String>{};
  final Map<String, String> _captionPlayerById = <String, String>{};
  final Map<String, String> _captionVotes = <String, String>{};
  final Map<String, TimelineGuess> _timelineGuesses = <String, TimelineGuess>{};
  final Map<String, MemeSubmission> _memes = <String, MemeSubmission>{};
  final Map<String, String> _memeIdByPlayer = <String, String>{};
  final Map<String, String> _memePlayerById = <String, String>{};
  final Map<String, Map<String, MemeVote>> _memeVotes =
      <String, Map<String, MemeVote>>{};
  final Map<String, PhotoCandidate> _memeAssignments =
      <String, PhotoCandidate>{};
  final Map<String, int> _memeSwaps = <String, int>{};
  final List<MemeEntry> _memeHistory = <MemeEntry>[];
  int _memeSerial = 0;
  MemeReveal? _lastMemeReveal;
  final List<GameMode> _mixedCycle = <GameMode>[];
  final Map<String, List<PhotoCandidate>> _pendingExtension =
      <String, List<PhotoCandidate>>{};

  int _roundsK;
  int _roundSeconds;
  GameMode _mode;
  GamePace _pace;
  GameMode _activeMode = GameMode.classic;
  int _captionSerial = 0;
  RoundPhase _phase = RoundPhase.lobby;
  int _photosNeeded = 0;
  int _currentRound = 0;
  int _roundStartedAtMs = 0;
  int _extendDeadlineMs = 0;
  bool _plantedThisGame = false;
  int _plantedFooledCount = 0;
  String? _plantedOwnerId;
  String? _planterId;
  RoundReveal? _lastReveal;
  CaptionReveal? _lastCaptionReveal;
  TimelineReveal? _lastTimelineReveal;
  MicroAward? _lastMicroAward;

  MatchConfig get config => MatchConfig(
    roundsK: _roundsK,
    roundSeconds: _roundSeconds,
    mode: _mode,
    pace: _pace,
  );
  RoundPhase get phase => _phase;
  GameMode get mode => _mode;
  GameMode get activeMode => _activeMode;
  CaptionReveal? get lastCaptionReveal => _lastCaptionReveal;
  TimelineReveal? get lastTimelineReveal => _lastTimelineReveal;
  MemeReveal? get lastMemeReveal => _lastMemeReveal;
  int get captionCount => _captions.length;
  int get captionVoteCount => _captionVotes.length;
  int get timelineGuessCount => _timelineGuesses.length;
  int get memeCount => _memes.length;
  int get memeVoteCount =>
      _memeVotes.values.fold<int>(0, (sum, votes) => sum + votes.length);
  bool hasMeme(String playerId) => _memes.containsKey(playerId);
  int memeSwapsLeft(String playerId) => _memeSwaps[playerId] ?? 0;
  Set<String> memeVotedIds(String playerId) => <String>{
    for (final entry in _memeVotes.entries)
      if (entry.value.containsKey(playerId)) entry.key,
  };
  List<MemeOption> get memeOptions => List<MemeOption>.unmodifiable(
    _memePlayerById.entries
        .map((entry) {
          final meme = _memes[entry.value];
          if (meme == null) {
            return const MemeOption(
              id: '',
              photoId: '',
              template: MemeTemplate.classic,
              topText: '',
              bottomText: '',
              snapY: 48,
            );
          }
          return MemeOption(
            id: meme.id,
            photoId: meme.photoId,
            template: meme.template,
            topText: meme.topText,
            bottomText: meme.bottomText,
            snapY: meme.snapY,
          );
        })
        .where((option) => option.id.isNotEmpty),
  );
  List<MemeEntry> get topMemes => List<MemeEntry>.unmodifiable(
    (List<MemeEntry>.of(_memeHistory)..sort((a, b) {
          final byPoints = b.points.compareTo(a.points);
          if (byPoints != 0) return byPoints;
          return b.upVotes.compareTo(a.upVotes);
        }))
        .take(3),
  );

  bool hasCaption(String playerId) => _captions.containsKey(playerId);
  String? captionVoteFor(String playerId) => _captionVotes[playerId];
  bool hasTimelineGuess(String playerId) =>
      _timelineGuesses.containsKey(playerId);
  TimelineGuess? timelineGuessFor(String playerId) =>
      _timelineGuesses[playerId];
  GuessRecord? guessFor(String playerId) => _guesses[playerId];
  int get roundsK => _roundsK;
  int get roundSeconds => _roundSeconds;
  int get roundMs => _roundSeconds * 1000;
  int get photosNeeded => _photosNeeded;
  int get currentRound => _currentRound;
  int get totalRounds => _deck.length;
  int get playerCount => _players.length;
  bool get plantAvailable => _isPlantWindowOpen;
  MicroAward? get lastMicroAward => _lastMicroAward;
  RoundReveal? get lastReveal => _lastReveal;
  int get extendDeadlineMs => _extendDeadlineMs;
  DeckEntry? get currentEntry =>
      _currentRound >= 1 && _currentRound <= _deck.length
      ? _deck[_currentRound - 1]
      : null;

  List<Player> get players => List<Player>.unmodifiable(_players.values);

  Player? player(String id) => _players[id];

  List<Player> get leaderboard {
    final list = List<Player>.of(_players.values);
    list.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.id.compareTo(b.id);
    });
    return List<Player>.unmodifiable(list);
  }

  List<DeckEntry> get deck => List<DeckEntry>.unmodifiable(_deck);

  Player addPlayer({
    required String id,
    required String name,
    String avatar = 'pets',
    int avatarColorIndex = 0,
    bool isHost = false,
  }) {
    if (_players.containsKey(id)) {
      throw const EngineException('duplicate_player', 'player already joined');
    }
    if (_phase != RoundPhase.lobby) {
      throw const EngineException('wrong_phase', 'match already started');
    }
    final player = Player(
      id: id,
      name: name,
      avatar: avatar,
      avatarColorIndex: avatarColorIndex,
      isHost: isHost,
    );
    _players[id] = player;
    return player;
  }

  void removePlayer(String playerId) {
    if (_phase == RoundPhase.lobby) {
      _players.remove(playerId);
      return;
    }
    final player = _players[playerId];
    if (player == null) {
      return;
    }
    player.connected = false;
  }

  void setConnected(String playerId, bool connected) {
    final player = _requirePlayer(playerId);
    player.connected = connected;
  }

  void setRoundsK(int rounds) {
    if (_phase != RoundPhase.lobby) {
      throw const EngineException(
        'wrong_phase',
        'rounds can only change in the lobby',
      );
    }
    if (rounds < 1) {
      throw const EngineException('invalid_rounds', 'rounds must be >= 1');
    }
    _roundsK = rounds;
  }

  void setRoundSeconds(int seconds) {
    if (_phase != RoundPhase.lobby) {
      throw const EngineException(
        'wrong_phase',
        'timer can only change in the lobby',
      );
    }
    if (seconds < 1) {
      throw const EngineException('invalid_timer', 'timer must be >= 1s');
    }
    _roundSeconds = seconds;
  }

  void setMode(GameMode mode) {
    if (_phase != RoundPhase.lobby) {
      throw const EngineException(
        'wrong_phase',
        'the game mode can only change in the lobby',
      );
    }
    _mode = mode;
    _roundSeconds = _pace.mainSeconds(mode);
  }

  void setPace(GamePace pace) {
    if (_phase != RoundPhase.lobby) {
      throw const EngineException(
        'wrong_phase',
        'the pace can only change in the lobby',
      );
    }
    _pace = pace;
    _roundSeconds = pace.mainSeconds(_mode);
  }

  void startPrepare() {
    if (_phase != RoundPhase.lobby) {
      throw const EngineException('wrong_phase', 'prepare already started');
    }
    if (_players.isEmpty) {
      throw const EngineException('no_players', 'need at least one player');
    }
    _photosNeeded = _mode == GameMode.makeItMeme
        ? 6
        : computePhotosNeeded(_roundsK, _players.length);
    _planterId = _players.isEmpty
        ? null
        : (planterOverride ??
              _players.keys.elementAt(_random.nextInt(_players.length)));
    _phase = RoundPhase.preparing;
  }

  /// `max(3, ceil(K / playerCount) + 1)`.
  static int computePhotosNeeded(int roundsK, int playerCount) {
    if (playerCount <= 0) {
      return minPhotosNeeded;
    }
    final perPlayer = (roundsK / playerCount).ceil() + 1;
    return max(minPhotosNeeded, perPlayer);
  }

  void submitInitialPhotos(String playerId, List<PhotoCandidate> photos) {
    final player = _requirePlayer(playerId);
    if (_phase != RoundPhase.preparing) {
      throw const EngineException('wrong_phase', 'not preparing');
    }
    if (photos.length > _photosNeeded) {
      throw EngineException(
        'too_many_photos',
        'expected at most $_photosNeeded photos',
      );
    }
    final ids = <String>{};
    final queue = <PhotoCandidate>[];
    for (final photo in photos) {
      if (photo.ownerId != playerId) {
        throw const EngineException(
          'wrong_owner',
          'photo owner must match the submitting player',
        );
      }
      if (!ids.add(photo.photoId)) {
        throw const EngineException('duplicate_photo', 'photo id repeated');
      }
      queue.add(photo);
    }
    _photoQueue[playerId] = queue;
    _photoCursor[playerId] = 0;
    player.ready = false;
  }

  void markReady(String playerId) {
    final player = _requirePlayer(playerId);
    if (_phase != RoundPhase.preparing) {
      throw const EngineException('wrong_phase', 'not preparing');
    }
    final queue = _photoQueue[playerId] ?? const <PhotoCandidate>[];
    if (queue.isEmpty || (_mode == GameMode.makeItMeme && queue.length < 6)) {
      throw const EngineException(
        'no_photos',
        'submit approved photos before ready',
      );
    }
    player.ready = true;
  }

  void unmarkReady(String playerId) {
    final player = _requirePlayer(playerId);
    if (_phase != RoundPhase.preparing) {
      throw const EngineException('wrong_phase', 'not preparing');
    }
    player.ready = false;
  }

  String? get planterId => _planterId;

  bool isPlanter(String playerId) => _planterId == playerId;

  bool get _isPlantWindowOpen {
    if (_phase != RoundPhase.preparing) {
      return false;
    }
    final players = _players.values;
    if (players.length < 2) {
      return false;
    }
    final readyCount = players.where((p) => p.ready).length;
    return readyCount >= 1 && readyCount < players.length;
  }

  /// Swaps one unplayed photo for [photo]. Only allowed once per game, after
  /// the player is Ready and while another player is still not Ready.
  void plantSecretPhoto(String playerId, PhotoCandidate photo) {
    final player = _requirePlayer(playerId);
    if (!isPlanter(playerId)) {
      throw const EngineException(
        'not_planter',
        'this player is not the planter this game',
      );
    }
    if (photo.ownerId != playerId) {
      throw const EngineException(
        'wrong_owner',
        'planted photo owner must match the player',
      );
    }
    if (!_isPlantWindowOpen) {
      throw const EngineException('plant_closed', 'plant window is closed');
    }
    if (player.plantUsed) {
      throw const EngineException('plant_used', 'plant is once per game');
    }
    if (!player.ready) {
      throw const EngineException(
        'not_ready',
        'tap Ready before planting a photo',
      );
    }
    final queue = _photoQueue[playerId];
    if (queue == null || queue.isEmpty) {
      throw const EngineException('no_photos', 'nothing to replace');
    }
    // Every photo in the queue is unplayed: the deck draws them in order and
    // only advances the cursor when it deals one.
    final cursor = _photoCursor[playerId] ?? 0;
    final unplayed = <int>[];
    for (var i = cursor; i < queue.length; i++) {
      unplayed.add(i);
    }
    if (unplayed.isEmpty) {
      throw const EngineException(
        'no_unplayed_photo',
        'every approved photo has already been shown',
      );
    }
    final target = unplayed[_random.nextInt(unplayed.length)];
    queue[target] = photo.copyWith(ownerId: playerId, isPlanted: true);
    player.plantUsed = true;
    _plantedThisGame = true;
    _plantedOwnerId = playerId;
  }

  /// Builds `roundsK` rounds as consecutive round-robin cycles. Each cycle is
  /// a shuffle of every player, and a cycle never starts with the player who
  /// closed the previous one when there is a real choice.
  void _buildDeck(int rounds) {
    if (_players.isEmpty || rounds <= 0) {
      return;
    }
    final order = _players.keys.toList();
    final startRound = _deck.length + 1;
    if (_mode == GameMode.mixedParty && _mixedCycle.isEmpty) {
      _mixedCycle.addAll(
        <GameMode>[GameMode.classic, GameMode.makeItMeme, GameMode.timeTraveler]
          ..shuffle(_random),
      );
    }
    var previousLast = _deck.isEmpty ? null : _deck.last.ownerId;
    final neededCycles = (rounds / order.length).ceil();
    final entries = <DeckEntry>[];
    for (var cycle = 0; cycle < neededCycles; cycle++) {
      final cycleOrder = List<String>.of(order)..shuffle(_random);
      if (order.length > 2 &&
          previousLast != null &&
          cycleOrder.first == previousLast) {
        final swapAt = 1 + _random.nextInt(cycleOrder.length - 1);
        final first = cycleOrder[0];
        cycleOrder[0] = cycleOrder[swapAt];
        cycleOrder[swapAt] = first;
      }
      for (final ownerId in cycleOrder) {
        final photo = _drawPhoto(ownerId);
        if (photo == null) {
          continue;
        }
        final roundIndex = startRound - 1 + entries.length;
        var mode = _mode == GameMode.mixedParty
            ? _mixedCycle[roundIndex % _mixedCycle.length]
            : _mode;
        if (mode == GameMode.timeTraveler && !photo.hasCaptureDate) {
          mode = GameMode.classic;
        }
        entries.add(
          DeckEntry(
            roundNumber: startRound + entries.length,
            ownerId: ownerId,
            photo: photo,
            mode: mode,
          ),
        );
      }
      if (cycleOrder.isNotEmpty) {
        previousLast = cycleOrder.last;
      }
    }
    final trimmed = entries.take(rounds).toList();
    _deck.addAll(trimmed);
  }

  PhotoCandidate? _drawPhoto(String ownerId) {
    final queue = _photoQueue[ownerId];
    if (queue == null) {
      return null;
    }
    var cursor = _photoCursor[ownerId] ?? 0;
    if (cursor < queue.length) {
      final photo = queue[cursor];
      _photoCursor[ownerId] = cursor + 1;
      return photo;
    }
    _photoCursor[ownerId] = cursor;
    return null;
  }

  void startGame() {
    if (_phase != RoundPhase.preparing) {
      throw const EngineException('wrong_phase', 'not preparing');
    }
    if (_players.length < 2) {
      throw const EngineException('too_few_players', 'need at least 2 players');
    }
    final notReady = _players.values.where((p) => !p.ready).toList();
    if (notReady.isNotEmpty) {
      throw const EngineException(
        'players_not_ready',
        'all players must be ready',
      );
    }
    _memeSwaps
      ..clear()
      ..addEntries(_players.keys.map((id) => MapEntry(id, 5)));
    _buildDeck(_roundsK);
    if (_deck.isEmpty) {
      throw const EngineException('empty_deck', 'no photos to play');
    }
    _currentRound = 0;
    _phase = RoundPhase.countdown;
  }

  DeckEntry startRound() {
    if (_phase != RoundPhase.countdown) {
      throw const EngineException('wrong_phase', 'not ready for a round');
    }
    if (_currentRound >= _deck.length) {
      throw const EngineException('deck_exhausted', 'no rounds left');
    }
    _currentRound++;
    _guesses.clear();
    _captions.clear();
    _captionIdByPlayer.clear();
    _captionPlayerById.clear();
    _captionVotes.clear();
    _captionSerial = 0;
    _timelineGuesses.clear();
    _memes.clear();
    _memeIdByPlayer.clear();
    _memePlayerById.clear();
    _memeVotes.clear();
    _memeAssignments.clear();
    _memeSerial = 0;
    _lastMemeReveal = null;
    _roundDeltas
      ..clear()
      ..addEntries(_players.keys.map((id) => MapEntry(id, 0)));
    for (final player in _players.values) {
      player.ready = false;
    }
    _roundStartedAtMs = _clock().millisecondsSinceEpoch;
    final entry = _deck[_currentRound - 1];
    _activeMode = entry.mode;
    _phase = switch (entry.mode) {
      GameMode.classic => RoundPhase.guessing,
      GameMode.captionThis => RoundPhase.captionWriting,
      GameMode.makeItMeme => RoundPhase.captionWriting,
      GameMode.timeTraveler => RoundPhase.timelineGuessing,
      GameMode.mixedParty => RoundPhase.guessing,
    };
    if (entry.mode == GameMode.makeItMeme) {
      _assignMemePhotos();
    }
    return entry;
  }

  void submitGuess(String playerId, String guessedOwnerId, int elapsedMs) {
    final player = _requirePlayer(playerId);
    if (_phase != RoundPhase.guessing) {
      throw const EngineException('wrong_phase', 'not guessing');
    }
    final entry = _deck[_currentRound - 1];
    if (!_players.containsKey(guessedOwnerId)) {
      throw const EngineException('unknown_player', 'guess target not in room');
    }
    if (_guesses.containsKey(playerId)) {
      throw const EngineException('already_guessed', 'guess is locked');
    }
    final clamped = elapsedMs.clamp(0, roundMs);
    final isOwnPhoto = entry.ownerId == playerId;
    final isCorrect = entry.ownerId == guessedOwnerId;

    var points = 0;
    if (isCorrect) {
      final remaining = roundMs - clamped;
      points =
          correctBasePoints +
          (correctSpeedPoints * remaining) ~/ roundMs +
          _streakBonus(player.streak);
    }

    if (isCorrect) {
      player.streak += 1;
      player.correctCount += 1;
      player.totalCorrectMs += clamped;
    } else {
      player.streak = 0;
    }
    player.longestStreak = max(player.longestStreak, player.streak);

    _guesses[playerId] = GuessRecord(
      playerId: playerId,
      guessedOwnerId: guessedOwnerId,
      elapsedMs: clamped,
      isCorrect: isCorrect,
      isOwnPhoto: isOwnPhoto,
      pointsAwarded: points,
    );
    _roundDeltas[playerId] = (_roundDeltas[playerId] ?? 0) + points;
  }

  static int _streakBonus(int streak) {
    if (streak < 2) {
      return 0;
    }
    return min(streakBonusCap, streakBonusStep * (streak - 1));
  }

  bool get allGuessed =>
      _phase == RoundPhase.guessing &&
      _players.values
          .where((p) => p.connected)
          .every((p) => _guesses.containsKey(p.id));

  /// Timeout for players who did not answer: a timeout is a wrong answer.
  void timeoutRemaining() {
    if (_phase != RoundPhase.guessing) {
      throw const EngineException('wrong_phase', 'not guessing');
    }
    final entry = _deck[_currentRound - 1];
    for (final player in _players.values) {
      if (!player.connected || _guesses.containsKey(player.id)) {
        continue;
      }
      final isOwnPhoto = entry.ownerId == player.id;
      player.streak = 0;
      _guesses[player.id] = GuessRecord(
        playerId: player.id,
        guessedOwnerId: '',
        elapsedMs: roundMs,
        isCorrect: false,
        isOwnPhoto: isOwnPhoto,
        pointsAwarded: 0,
      );
    }
  }

  // Caption This ------------------------------------------------------------

  bool get allCaptionsSubmitted =>
      _phase == RoundPhase.captionWriting &&
      _players.values
          .where((player) => player.connected)
          .every((player) => _captions.containsKey(player.id));

  bool get allCaptionVotesSubmitted =>
      _phase == RoundPhase.captionVoting &&
      _players.values
          .where((player) => player.connected)
          .every((player) => _captionVotes.containsKey(player.id));

  List<CaptionOption> get captionOptions {
    final options = <CaptionOption>[
      for (final entry in _captionPlayerById.entries)
        if (_captions[entry.value] != null)
          CaptionOption(id: entry.key, text: _captions[entry.value]!),
    ]..sort((a, b) => a.id.compareTo(b.id));
    return List<CaptionOption>.unmodifiable(options);
  }

  String? captionIdFor(String playerId) => _captionIdByPlayer[playerId];

  bool isOwnCaption(String playerId, String captionId) =>
      _captionPlayerById[captionId] == playerId;

  void submitCaption(String playerId, String text) {
    _requirePlayer(playerId);
    if (_phase != RoundPhase.captionWriting) {
      throw const EngineException('wrong_phase', 'not writing captions');
    }
    if (_captions.containsKey(playerId)) {
      throw const EngineException('already_captioned', 'caption is locked');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const EngineException('empty_caption', 'write something first');
    }
    if (trimmed.length > 80) {
      throw const EngineException('caption_too_long', 'keep it under 80');
    }
    final id = 'cap-${_captionSerial++}';
    _captions[playerId] = trimmed;
    _captionIdByPlayer[playerId] = id;
    _captionPlayerById[id] = playerId;
  }

  void beginCaptionVoting() {
    if (_phase != RoundPhase.captionWriting) {
      throw const EngineException('wrong_phase', 'not writing captions');
    }
    if (_captions.isEmpty) {
      throw const EngineException('no_captions', 'nothing to vote on');
    }
    _phase = RoundPhase.captionVoting;
  }

  void submitCaptionVote(String playerId, String captionId) {
    _requirePlayer(playerId);
    if (_phase != RoundPhase.captionVoting) {
      throw const EngineException('wrong_phase', 'not voting');
    }
    if (!_captionPlayerById.containsKey(captionId)) {
      throw const EngineException('unknown_caption', 'caption not found');
    }
    if (_captionPlayerById[captionId] == playerId) {
      throw const EngineException(
        'own_caption',
        'you cannot vote for yourself',
      );
    }
    if (_captionVotes.containsKey(playerId)) {
      throw const EngineException('already_voted', 'vote is locked');
    }
    _captionVotes[playerId] = captionId;
  }

  CaptionReveal finishCaptionRound() {
    if (_phase != RoundPhase.captionWriting &&
        _phase != RoundPhase.captionVoting) {
      throw const EngineException('wrong_phase', 'no caption round running');
    }
    final entry = _deck[_currentRound - 1];
    final deltas = <String, int>{
      for (final player in _players.values) player.id: 0,
    };
    final votesById = <String, int>{
      for (final id in _captionPlayerById.keys) id: 0,
    };
    for (final captionId in _captionVotes.values) {
      votesById[captionId] = (votesById[captionId] ?? 0) + 1;
    }
    final maxVotes = votesById.values.fold<int>(0, max);

    final entries = <CaptionEntry>[];
    for (final mapEntry in _captionPlayerById.entries) {
      final author = _players[mapEntry.value];
      if (author == null) continue;
      final votes = votesById[mapEntry.key] ?? 0;
      final points =
          votes * 100 + (maxVotes > 0 && votes == maxVotes ? 200 : 0);
      deltas[author.id] = (deltas[author.id] ?? 0) + points;
      entries.add(
        CaptionEntry(
          id: mapEntry.key,
          text: _captions[author.id] ?? '',
          authorId: author.id,
          authorName: author.name,
          votes: votes,
          points: points,
        ),
      );
    }
    entries.sort((a, b) {
      final byVotes = b.votes.compareTo(a.votes);
      return byVotes != 0 ? byVotes : a.id.compareTo(b.id);
    });
    if (maxVotes > 0 && entries.isNotEmpty) {
      final winner = entries.first;
      entries.removeAt(0);
      entries.insert(0, winner);
    }
    for (final player in _players.values) {
      player.score += deltas[player.id] ?? 0;
    }
    final winners = maxVotes <= 0
        ? const <String>[]
        : <String>[
            for (final caption in entries)
              if (caption.votes == maxVotes) caption.id,
          ];
    final reveal = CaptionReveal(
      roundNumber: entry.roundNumber,
      photoId: entry.photo.photoId,
      ownerId: entry.ownerId,
      entries: List<CaptionEntry>.unmodifiable(entries),
      winnerIds: List<String>.unmodifiable(winners),
      scoreDeltas: Map<String, int>.unmodifiable(deltas),
    );
    _lastCaptionReveal = reveal;
    _phase = RoundPhase.captionReveal;
    return reveal;
  }

  // Make It Meme -----------------------------------------------------------

  void _assignMemePhotos() {
    final connected = _players.values
        .where((player) => player.connected)
        .toList();
    for (final player in connected) {
      final pool = <PhotoCandidate>[];
      for (final other in connected) {
        if (other.id == player.id) continue;
        pool.addAll(_photoQueue[other.id] ?? const <PhotoCandidate>[]);
      }
      if (pool.isEmpty) {
        pool.addAll(_photoQueue[player.id] ?? const <PhotoCandidate>[]);
      }
      if (pool.isEmpty) continue;
      _memeAssignments[player.id] = pool[_random.nextInt(pool.length)];
      _memeSwaps[player.id] = _memeSwaps[player.id] ?? 5;
    }
  }

  MemeAssignment? memeAssignmentFor(String playerId) {
    final photo = _memeAssignments[playerId];
    if (photo == null) return null;
    final owner = _players[photo.ownerId];
    return MemeAssignment(
      playerId: playerId,
      photoId: photo.photoId,
      ownerId: photo.ownerId,
      ownerName: owner?.name ?? '',
      isPanorama: photo.isPanorama,
    );
  }

  PhotoCandidate? memeAssignmentPhoto(String playerId) =>
      _memeAssignments[playerId];

  bool get allMemesSubmitted =>
      _phase == RoundPhase.captionWriting &&
      _players.values
          .where((player) => player.connected)
          .every((player) => _memes.containsKey(player.id));

  bool get allMemeVotesSubmitted {
    if (_phase != RoundPhase.captionVoting) return false;
    final memes = _memePlayerById.keys;
    for (final player in _players.values.where((p) => p.connected)) {
      for (final memeId in memes) {
        if (_memePlayerById[memeId] == player.id) continue;
        if (_memeVotes[memeId]?[player.id] == null) return false;
      }
    }
    return true;
  }

  bool isOwnMeme(String playerId, String memeId) =>
      _memePlayerById[memeId] == playerId;

  /// Stable display order for the voting loop: submissions arrive in player
  /// order, which keeps every phone in step.
  List<String> get memeIds => List<String>.unmodifiable(_memePlayerById.keys);

  String? memeAuthorFor(String memeId) => _memePlayerById[memeId];

  List<Player> eligibleVotersFor(String memeId) {
    final authorId = _memePlayerById[memeId];
    return List<Player>.unmodifiable(
      _players.values.where(
        (player) => player.connected && player.id != authorId,
      ),
    );
  }

  Set<String> voterIdsFor(String memeId) => Set<String>.unmodifiable(
    (_memeVotes[memeId] ?? const <String, MemeVote>{}).keys,
  );

  int voteCountFor(String memeId) => _memeVotes[memeId]?.length ?? 0;

  Map<String, int> voteSplitFor(String memeId) {
    final votes = _memeVotes[memeId] ?? const <String, MemeVote>{};
    return <String, int>{
      'up': votes.values.where((vote) => vote == MemeVote.up).length,
      'meh': votes.values.where((vote) => vote == MemeVote.meh).length,
      'down': votes.values.where((vote) => vote == MemeVote.down).length,
    };
  }

  bool allVotesFor(String memeId) {
    final authorId = _memePlayerById[memeId];
    if (authorId == null) return false;
    for (final player in _players.values) {
      if (!player.connected || player.id == authorId) continue;
      if (_memeVotes[memeId]?[player.id] == null) return false;
    }
    return true;
  }

  PhotoCandidate swapMemePhoto(String playerId) {
    _requirePlayer(playerId);
    if (_phase != RoundPhase.captionWriting) {
      throw const EngineException('wrong_phase', 'not writing memes');
    }
    if (_memes.containsKey(playerId)) {
      throw const EngineException('already_captioned', 'meme is locked');
    }
    final left = _memeSwaps[playerId] ?? 0;
    if (left <= 0) {
      throw const EngineException('no_swaps', 'no photo swaps left');
    }
    final current = _memeAssignments[playerId];
    if (current == null) {
      throw const EngineException('no_photo', 'no photo assigned');
    }
    final pool = <PhotoCandidate>[];
    for (final player in _players.values) {
      if (player.id == playerId || !player.connected) continue;
      for (final photo in _photoQueue[player.id] ?? const <PhotoCandidate>[]) {
        if (photo.photoId != current.photoId) pool.add(photo);
      }
    }
    if (pool.isEmpty) {
      throw const EngineException('no_swap_photo', 'no other photo available');
    }
    final next = pool[_random.nextInt(pool.length)];
    _memeAssignments[playerId] = next;
    _memeSwaps[playerId] = left - 1;
    return next;
  }

  void submitMeme({
    required String playerId,
    required MemeTemplate template,
    required String topText,
    required String bottomText,
    required double snapY,
  }) {
    _requirePlayer(playerId);
    if (_phase != RoundPhase.captionWriting) {
      throw const EngineException('wrong_phase', 'not writing memes');
    }
    final assignment = _memeAssignments[playerId];
    if (assignment == null) {
      throw const EngineException('no_photo', 'no photo assigned');
    }
    if (_memes.containsKey(playerId)) {
      throw const EngineException('already_captioned', 'meme is locked');
    }
    final top = topText.trim();
    final bottom = bottomText.trim();
    if (top.isEmpty && bottom.isEmpty) {
      throw const EngineException('empty_caption', 'write something first');
    }
    if (top.length > 70 || bottom.length > 70) {
      throw const EngineException('caption_too_long', 'keep it under 70');
    }
    final id = 'meme-${_memeSerial++}';
    final meme = MemeSubmission(
      id: id,
      playerId: playerId,
      photoId: assignment.photoId,
      photoOwnerId: assignment.ownerId,
      template: template,
      topText: top,
      bottomText: bottom,
      snapY: snapY.clamp(10, 90),
    );
    _memes[playerId] = meme;
    _memeIdByPlayer[playerId] = id;
    _memePlayerById[id] = playerId;
  }

  void beginMemeVoting() {
    if (_phase != RoundPhase.captionWriting) {
      throw const EngineException('wrong_phase', 'not writing memes');
    }
    if (_memes.isEmpty) {
      throw const EngineException('no_captions', 'nothing to vote on');
    }
    _phase = RoundPhase.captionVoting;
  }

  void submitMemeVote({
    required String playerId,
    required String memeId,
    required MemeVote vote,
  }) {
    _requirePlayer(playerId);
    if (_phase != RoundPhase.captionVoting) {
      throw const EngineException('wrong_phase', 'not voting');
    }
    if (!_memePlayerById.containsKey(memeId)) {
      throw const EngineException('unknown_caption', 'meme not found');
    }
    if (_memePlayerById[memeId] == playerId) {
      throw const EngineException(
        'own_caption',
        'you cannot vote for yourself',
      );
    }
    final votes = _memeVotes.putIfAbsent(memeId, () => <String, MemeVote>{});
    if (votes.containsKey(playerId)) {
      throw const EngineException('already_voted', 'vote is locked');
    }
    votes[playerId] = vote;
  }

  MemeReveal finishMemeRound() {
    if (_phase != RoundPhase.captionWriting &&
        _phase != RoundPhase.captionVoting) {
      throw const EngineException('wrong_phase', 'no meme round running');
    }
    final entry = _deck[_currentRound - 1];
    final deltas = <String, int>{
      for (final player in _players.values) player.id: 0,
    };
    final entries = <MemeEntry>[];
    for (final mapEntry in _memePlayerById.entries) {
      final meme = _memes[mapEntry.value];
      if (meme == null) continue;
      final author = _players[meme.playerId];
      final owner = _players[meme.photoOwnerId];
      if (author == null) continue;
      final votes = _memeVotes[mapEntry.key] ?? const <String, MemeVote>{};
      final up = votes.values.where((vote) => vote == MemeVote.up).length;
      final meh = votes.values.where((vote) => vote == MemeVote.meh).length;
      final down = votes.values.where((vote) => vote == MemeVote.down).length;
      final points = up * 100 - down * 50;
      deltas[author.id] = (deltas[author.id] ?? 0) + points;
      entries.add(
        MemeEntry(
          id: meme.id,
          authorId: author.id,
          authorName: author.name,
          photoId: meme.photoId,
          photoOwnerId: meme.photoOwnerId,
          photoOwnerName: owner?.name ?? '',
          template: meme.template,
          topText: meme.topText,
          bottomText: meme.bottomText,
          snapY: meme.snapY,
          upVotes: up,
          mehVotes: meh,
          downVotes: down,
          points: points,
        ),
      );
    }
    entries.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      if (byPoints != 0) return byPoints;
      final byUp = b.upVotes.compareTo(a.upVotes);
      if (byUp != 0) return byUp;
      return a.id.compareTo(b.id);
    });
    final maxPoints = entries.isEmpty ? 0 : entries.first.points;
    final winners = maxPoints > 0
        ? <String>[
            for (final entry in entries)
              if (entry.points == maxPoints) entry.id,
          ]
        : const <String>[];
    final royaltyWinners = <MemeEntry>[
      for (final entry in entries)
        if (winners.contains(entry.id)) entry,
    ];
    for (final winner in royaltyWinners) {
      deltas[winner.photoOwnerId] = (deltas[winner.photoOwnerId] ?? 0) + 25;
    }
    for (final player in _players.values) {
      player.score += deltas[player.id] ?? 0;
    }
    _memeHistory.addAll(entries);
    final reveal = MemeReveal(
      roundNumber: entry.roundNumber,
      entries: List<MemeEntry>.unmodifiable(entries),
      winnerIds: List<String>.unmodifiable(winners),
      scoreDeltas: Map<String, int>.unmodifiable(deltas),
    );
    _lastMemeReveal = reveal;
    _phase = RoundPhase.captionReveal;
    return reveal;
  }

  // Time Traveler -----------------------------------------------------------

  bool get allTimelineGuessed {
    if (_phase != RoundPhase.timelineGuessing) return false;
    // The owner guesses their own photo too, so the round cannot close before
    // they have had the same turn as everyone else.
    return _players.values
        .where((player) => player.connected)
        .every((player) => _timelineGuesses.containsKey(player.id));
  }

  void submitTimelineGuess({
    required String playerId,
    required int year,
    required int month,
    required int elapsedMs,
  }) {
    _requirePlayer(playerId);
    if (_phase != RoundPhase.timelineGuessing) {
      throw const EngineException('wrong_phase', 'not guessing a date');
    }
    final now = _clock().year;
    if (year < 1970 || year > now + 1 || month < 1 || month > 12) {
      throw const EngineException('invalid_date', 'that date is out of range');
    }
    if (_timelineGuesses.containsKey(playerId)) {
      throw const EngineException('already_guessed', 'guess is locked');
    }
    _timelineGuesses[playerId] = TimelineGuess(
      playerId: playerId,
      year: year,
      month: month,
      elapsedMs: elapsedMs.clamp(0, 3600000),
    );
  }

  TimelineReveal finishTimelineRound({int durationMs = 30000}) {
    if (_phase != RoundPhase.timelineGuessing) {
      throw const EngineException('wrong_phase', 'not guessing a date');
    }
    final entry = _deck[_currentRound - 1];
    final actualYear = entry.photo.capturedYear;
    final actualMonth = entry.photo.capturedMonth;
    if (actualYear == null || actualMonth == null) {
      throw const EngineException('no_date', 'photo has no capture date');
    }
    final deltas = <String, int>{
      for (final player in _players.values) player.id: 0,
    };
    final entries = <TimelineEntry>[];
    String? closestId;
    String? furthestId;
    int? closestOff;
    int? furthestOff;
    int? closestMs;
    int? furthestMs;

    for (final player in _players.values) {
      final isOwner = player.id == entry.ownerId;
      final guess = _timelineGuesses[player.id];
      if (guess == null) {
        entries.add(
          TimelineEntry(
            playerId: player.id,
            playerName: player.name,
            points: 0,
            timedOut: true,
            isOwner: isOwner,
          ),
        );
        continue;
      }
      final monthsOff =
          ((guess.year - actualYear) * 12 + (guess.month - actualMonth)).abs();
      final accuracy = max(0, 1000 - monthsOff * 35);
      final speed = max(
        0,
        200 - ((guess.elapsedMs / max(1, durationMs)) * 200).round(),
      );
      final points = accuracy + speed;
      deltas[player.id] = points;
      entries.add(
        TimelineEntry(
          playerId: player.id,
          playerName: player.name,
          points: points,
          year: guess.year,
          month: guess.month,
          monthsOff: monthsOff,
          isOwner: isOwner,
        ),
      );
      if (closestOff == null ||
          monthsOff < closestOff ||
          (monthsOff == closestOff &&
              guess.elapsedMs < (closestMs ?? 1 << 30))) {
        closestId = player.id;
        closestOff = monthsOff;
        closestMs = guess.elapsedMs;
      }
      if (furthestOff == null ||
          monthsOff > furthestOff ||
          (monthsOff == furthestOff && guess.elapsedMs > (furthestMs ?? -1))) {
        furthestId = player.id;
        furthestOff = monthsOff;
        furthestMs = guess.elapsedMs;
      }
    }
    for (final player in _players.values) {
      player.score += deltas[player.id] ?? 0;
    }
    entries.sort((a, b) {
      if (a.isOwner != b.isOwner) return a.isOwner ? 1 : -1;
      return (a.monthsOff ?? 9999).compareTo(b.monthsOff ?? 9999);
    });
    final reveal = TimelineReveal(
      roundNumber: entry.roundNumber,
      photoId: entry.photo.photoId,
      ownerId: entry.ownerId,
      actualYear: actualYear,
      actualMonth: actualMonth,
      entries: List<TimelineEntry>.unmodifiable(entries),
      scoreDeltas: Map<String, int>.unmodifiable(deltas),
      closestId: closestId,
      furthestId: furthestId,
    );
    _lastTimelineReveal = reveal;
    _phase = RoundPhase.timelineReveal;
    return reveal;
  }

  RoundReveal finishRound() {
    if (_phase != RoundPhase.guessing) {
      throw const EngineException('wrong_phase', 'not guessing');
    }
    timeoutRemaining();
    final entry = _deck[_currentRound - 1];
    final owner = _players[entry.ownerId]!;
    final guesses = _guesses.values.toList();

    var fooled = 0;
    GuessRecord? fastest;
    for (final guess in guesses) {
      if (guess.isOwnPhoto) {
        continue;
      }
      if (guess.isCorrect) {
        if (fastest == null || guess.elapsedMs < fastest.elapsedMs) {
          fastest = guess;
        }
      } else if (guess.guessedOwnerId.isNotEmpty) {
        fooled++;
      }
    }

    if (fooled > 0) {
      final bonus = mysteryBonusPerFooledOpponent * fooled;
      owner.mysteryPointsEarned += bonus;
      _roundDeltas[entry.ownerId] = (_roundDeltas[entry.ownerId] ?? 0) + bonus;
    }
    if (entry.photo.isPlanted && _plantedOwnerId == entry.ownerId) {
      _plantedFooledCount += fooled;
    }

    for (final player in _players.values) {
      player.score += _roundDeltas[player.id] ?? 0;
    }

    final opponentGuesses = guesses.where((g) => !g.isOwnPhoto).toList();
    final nobodyGuessed =
        opponentGuesses.isNotEmpty && fooled == opponentGuesses.length;
    final everyoneGuessed =
        opponentGuesses.isNotEmpty && opponentGuesses.every((g) => g.isCorrect);

    MicroAward? micro;
    if (fastest != null) {
      micro = MicroAward(
        kind: MicroAwardKind.fastestGuess,
        playerId: fastest.playerId,
        playerName: _players[fastest.playerId]!.name,
        elapsedMs: fastest.elapsedMs,
      );
    } else if (nobodyGuessed) {
      micro = MicroAward(
        kind: MicroAwardKind.nobodyGuessed,
        playerId: entry.ownerId,
        playerName: owner.name,
      );
    } else if (everyoneGuessed) {
      micro = const MicroAward(kind: MicroAwardKind.everyoneGuessed);
    }

    final reveal = RoundReveal(
      roundNumber: entry.roundNumber,
      ownerId: entry.ownerId,
      photoId: entry.photo.photoId,
      isPlanted: entry.photo.isPlanted,
      guesses: List<GuessRecord>.unmodifiable(guesses),
      scoreDeltas: Map<String, int>.unmodifiable(_roundDeltas),
      streaks: Map<String, int>.unmodifiable(
        _players.map((id, p) => MapEntry(id, p.streak)),
      ),
      microAward: micro,
      nobodyGuessed: nobodyGuessed,
      everyoneGuessed: everyoneGuessed,
    );
    _lastReveal = reveal;
    _lastMicroAward = micro;
    _phase = RoundPhase.reveal;
    return reveal;
  }

  /// Closes the reveal. Moves to the podium after the last round, otherwise
  /// to the next countdown.
  void advanceAfterReveal() {
    if (_phase != RoundPhase.reveal &&
        _phase != RoundPhase.captionReveal &&
        _phase != RoundPhase.timelineReveal) {
      throw const EngineException('wrong_phase', 'not revealing');
    }
    if (_currentRound >= _deck.length) {
      _phase = RoundPhase.podium;
      return;
    }
    _phase = RoundPhase.countdown;
  }

  /// Opens the 10 second approve/reroll window. Returns the deadline in
  /// milliseconds since epoch.
  int extendGame({
    int extraRounds = defaultExtraRounds,
    int extraPhotos = defaultExtraPhotos,
  }) {
    if (_phase != RoundPhase.podium) {
      throw const EngineException('wrong_phase', 'match is not finished');
    }
    if (extraRounds < 1) {
      throw const EngineException(
        'invalid_extension',
        'extraRounds must be >= 1',
      );
    }
    _pendingExtension.clear();
    _roundsK += extraRounds;
    _photosNeeded = max(_photosNeeded, extraPhotos);
    _extendDeadlineMs = _clock().millisecondsSinceEpoch + extendWindowMs;
    _phase = RoundPhase.extendPrompt;
    return _extendDeadlineMs;
  }

  /// Player approved their extra photos. Anything not approved by the deadline
  /// is auto-approved from what they already hold.
  void submitExtensionPhotos(String playerId, List<PhotoCandidate> photos) {
    final player = _requirePlayer(playerId);
    if (_phase != RoundPhase.extendPrompt) {
      throw const EngineException('wrong_phase', 'no extension running');
    }
    if (photos.isEmpty) {
      throw const EngineException('no_photos', 'approve at least one photo');
    }
    final ids = <String>{};
    for (final photo in photos) {
      if (photo.ownerId != playerId) {
        throw const EngineException('wrong_owner', 'photo owner mismatch');
      }
      if (!ids.add(photo.photoId)) {
        throw const EngineException('duplicate_photo', 'photo id repeated');
      }
    }
    _pendingExtension[playerId] = List<PhotoCandidate>.of(photos);
    player.ready = true;
    if (_players.values.every((p) => p.ready)) {
      commitExtension();
    }
  }

  /// Auto-approves whatever is missing and appends the new rounds. Safe to
  /// call once the deadline passed; a no-op when nothing is pending.
  void handleExtensionTimeout() {
    if (_phase != RoundPhase.extendPrompt) {
      return;
    }
    if (_clock().millisecondsSinceEpoch < _extendDeadlineMs) {
      return;
    }
    commitExtension();
  }

  /// Appends the extension rounds and returns to countdown at round K + 1.
  void commitExtension() {
    if (_phase != RoundPhase.extendPrompt) {
      throw const EngineException('wrong_phase', 'no extension running');
    }
    for (final player in _players.values) {
      final extra = _pendingExtension[player.id];
      if (extra != null) {
        _photoQueue[player.id] = extra;
        _photoCursor[player.id] = 0;
      } else {
        // Fallback: reuse the photos this player has left, or their last set.
        final queue = _photoQueue[player.id] ?? const <PhotoCandidate>[];
        final cursor = _photoCursor[player.id] ?? 0;
        final remaining = queue.skip(cursor).toList();
        final fallback = remaining.isNotEmpty ? remaining : queue;
        _photoQueue[player.id] = List<PhotoCandidate>.of(fallback);
        _photoCursor[player.id] = 0;
      }
      player.ready = false;
    }
    _pendingExtension.clear();
    final extraRounds = _roundsK - _deck.length;
    _buildDeck(extraRounds);
    _phase = RoundPhase.countdown;
  }

  void recordScreenshot(String playerId) {
    final player = _requirePlayer(playerId);
    player.screenshotCount += 1;
    _lastMicroAward = MicroAward(
      kind: MicroAwardKind.screenshot,
      playerId: player.id,
      playerName: player.name,
    );
  }

  /// Champion, Quickest Draw, Unstoppable, Master of Mystery, Paparazzi (only
  /// when someone took a screenshot) and Smooth Planter (only when the planted
  /// photo fooled at least one opponent).
  List<MatchAward> buildPodiumAwards() {
    final awards = <MatchAward>[];
    final all = _players.values.toList();
    if (all.isEmpty) {
      return awards;
    }

    final champion = _best(all, (p) => p.score);
    if (champion != null) {
      awards.add(
        MatchAward(
          kind: MatchAwardKind.champion,
          playerId: champion.id,
          playerName: champion.name,
          value: champion.score,
        ),
      );
    }

    final quick = _best(
      all.where((p) => p.correctCount > 0).toList(),
      (p) => p.averageCorrectMs!,
      lowerIsBetter: true,
    );
    if (quick != null) {
      awards.add(
        MatchAward(
          kind: MatchAwardKind.quickestDraw,
          playerId: quick.id,
          playerName: quick.name,
          value: quick.averageCorrectMs,
        ),
      );
    }

    final unstoppable = _best(
      all.where((p) => p.longestStreak > 0).toList(),
      (p) => p.longestStreak,
    );
    if (unstoppable != null) {
      awards.add(
        MatchAward(
          kind: MatchAwardKind.unstoppable,
          playerId: unstoppable.id,
          playerName: unstoppable.name,
          value: unstoppable.longestStreak,
        ),
      );
    }

    final mystery = _best(
      all.where((p) => p.mysteryPointsEarned > 0).toList(),
      (p) => p.mysteryPointsEarned,
    );
    if (mystery != null) {
      awards.add(
        MatchAward(
          kind: MatchAwardKind.masterOfMystery,
          playerId: mystery.id,
          playerName: mystery.name,
          value: mystery.mysteryPointsEarned,
        ),
      );
    }

    final paparazzi = _best(
      all.where((p) => p.screenshotCount > 0).toList(),
      (p) => p.screenshotCount,
    );
    if (paparazzi != null) {
      awards.add(
        MatchAward(
          kind: MatchAwardKind.paparazzi,
          playerId: paparazzi.id,
          playerName: paparazzi.name,
          value: paparazzi.screenshotCount,
        ),
      );
    }

    if (_plantedFooledCount >= 1 &&
        _plantedOwnerId != null &&
        _players.containsKey(_plantedOwnerId)) {
      final owner = _players[_plantedOwnerId]!;
      awards.add(
        MatchAward(
          kind: MatchAwardKind.smoothPlanter,
          playerId: owner.id,
          playerName: owner.name,
          value: _plantedFooledCount,
        ),
      );
    }
    return List<MatchAward>.unmodifiable(awards);
  }

  /// Highest value wins; ties go to the earliest joined player. When
  /// [lowerIsBetter] the smallest value wins.
  Player? _best(
    List<Player> candidates,
    int Function(Player) value, {
    bool lowerIsBetter = false,
  }) {
    Player? best;
    var bestValue = 0;
    for (final candidate in candidates) {
      final v = value(candidate);
      if (best == null || (lowerIsBetter ? v < bestValue : v > bestValue)) {
        best = candidate;
        bestValue = v;
      }
    }
    return best;
  }

  Map<String, dynamic> buildStateSnapshot() => <String, dynamic>{
    'phase': _phase.name,
    'config': config.toJson(),
    'roundsK': _roundsK,
    'photosNeeded': _photosNeeded,
    'currentRound': _currentRound,
    'totalRounds': _deck.length,
    'roundStartedAtMs': _roundStartedAtMs,
    'extendDeadlineMs': _extendDeadlineMs,
    'plantedThisGame': _plantedThisGame,
    'players': _players.values.map((p) => p.toJson()).toList(),
    'currentEntry': currentEntry?.toJson(),
    'guesses': _guesses.values.map((g) => g.toJson()).toList(),
    'lastReveal': _lastReveal?.toJson(),
    'mode': _mode.name,
    'activeMode': _activeMode.name,
    'captionReveal': _lastCaptionReveal?.toJson(),
    'timelineReveal': _lastTimelineReveal?.toJson(),
  };

  Player _requirePlayer(String id) {
    final player = _players[id];
    if (player == null) {
      throw EngineException('unknown_player', 'no player $id');
    }
    return player;
  }
}
