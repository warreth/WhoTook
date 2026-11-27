import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/storage/last_room_repository.dart';
import 'package:whotook/core/storage/settings_repository.dart';
import 'package:whotook/engine/host_game_engine.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/transport/game_transport.dart';
import 'package:whotook/transport/hybrid_connector.dart';

import 'support/test_photo_library.dart';

const int _simPlayerCount = int.fromEnvironment(
  'SIM_PLAYER_COUNT',
  defaultValue: 5,
);
const int _simRoundsOverride = int.fromEnvironment(
  'SIM_ROUNDS',
  defaultValue: 0,
);

int _roundsFor(int fallback) =>
    _simRoundsOverride > 0 ? _simRoundsOverride : fallback;

/// A real host plus three to five real clients over the in-memory WebRTC
/// bridge. Every phone runs the production coordinator, so this covers the same
/// wire messages, vault sync, phase timers and host/client branches as a LAN
/// match.
class Simulation {
  Simulation({int? playerCount})
    : players = (playerCount ?? _simPlayerCount).clamp(4, 6);

  final int players;

  int get clients => players - 1;
  final LoopbackHub hub = LoopbackHub();
  final List<MatchCoordinator> peers = <MatchCoordinator>[];
  late final MatchCoordinator host;
  late final String inviteUrl;

  Future<void> start({required GameMode mode, required int rounds}) async {
    host = MatchCoordinator(
      photos: TestPhotoLibrary(seed: 1),
      settings: SettingsRepository(),
      hostTransportFactory: (roomId, secret, lan) => LoopbackHostTransport(hub),
      planterOverride: 'host',
      roundDuration: const Duration(milliseconds: 500),
      countdownDuration: Duration.zero,
      vaultFallbackDelay: const Duration(milliseconds: 400),
      revealDuration: const Duration(milliseconds: 30),
      captionRevealDuration: const Duration(seconds: 5),
      timelineRevealDuration: const Duration(seconds: 5),
      memeTallyDuration: const Duration(milliseconds: 30),
      sabotageDuration: const Duration(milliseconds: 500),
      emptyMemeAdvanceDuration: const Duration(milliseconds: 80),
      extendWindow: const Duration(milliseconds: 200),
      reconnectAttemptDelay: const Duration(milliseconds: 30),
    );
    peers.add(host);
    await host.loadSettings();
    await host.hostMatch();
    inviteUrl = host.state.inviteUrl!;
    for (var i = 0; i < clients; i++) {
      final client = MatchCoordinator(
        photos: TestPhotoLibrary(seed: 10 + i),
        settings: SettingsRepository(),
        lastRooms: LastRoomRepository(storageKey: 'whotook.sim.room.$i'),
        playerIdOverride: 'sim-$i',
        playerTokenOverride: 'sim-token-$i',
        connector: HybridConnector(
          onlineClientFactory: () => LoopbackClientTransport(hub),
        ),
        reconnectAttemptDelay: const Duration(milliseconds: 30),
        roundDuration: const Duration(milliseconds: 500),
        countdownDuration: Duration.zero,
      );
      await client.loadSettings();
      await client.joinMatch(inviteUrl);
      peers.add(client);
    }
    await waitFor(() => host.state.players.length == players);
    await host.setMode(mode);
    await host.setRounds(rounds);
  }

  Future<void> prepare() async {
    await host.startPrepare();
    await waitFor(() => host.state.candidates.isNotEmpty);
    for (final client in peers.skip(1)) {
      await waitFor(() => client.state.candidates.isNotEmpty);
    }
    await host.markLocalReady();
    for (final client in peers.skip(1)) {
      await client.clientMarkReady();
    }
    await waitFor(
      () => host.state.phase != RoundPhase.preparing,
      timeout: const Duration(seconds: 15),
    );
  }

  Future<void> dispose() async {
    for (final peer in peers.reversed) {
      await peer.dispose();
    }
    await hub.dispose();
  }
}

Future<void> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException(reason ?? 'condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _waitForPhase(
  MatchCoordinator coordinator,
  RoundPhase phase, {
  Duration timeout = const Duration(seconds: 20),
}) => waitFor(
  () => coordinator.state.phase == phase,
  timeout: timeout,
  reason: 'never reached ${phase.name}, still ${coordinator.state.phase.name}',
);

Future<void> _waitForNextRound(MatchCoordinator host) async {
  await waitFor(
    () =>
        host.state.phase == RoundPhase.countdown ||
        host.state.phase == RoundPhase.guessing ||
        host.state.phase == RoundPhase.captionWriting ||
        host.state.phase == RoundPhase.timelineGuessing ||
        host.state.phase == RoundPhase.podium,
    timeout: const Duration(seconds: 20),
  );
}

Future<void> playClassicRound(
  Simulation sim, {
  required int round,
  bool timeoutHalf = false,
}) async {
  final host = sim.host;
  await _waitForPhase(host, RoundPhase.guessing);
  final options = host.state.activeRoundOptions;
  final cursor = (round - 1) % options.length;
  await host.submitGuess(options[cursor].id);
  if (!timeoutHalf) {
    var offset = 1;
    for (final client in sim.peers.skip(1)) {
      final target = options[(cursor + offset) % options.length].id;
      await client.clientSubmitGuess(target);
      offset += 1;
    }
  }
  await _waitForPhase(host, RoundPhase.reveal);
  if (host.state.phase == RoundPhase.reveal) {
    await host.skipRound();
  }
  await _waitForNextRound(host);
}

Future<void> playMemeRound(Simulation sim, {required int round}) async {
  final host = sim.host;
  await _waitForPhase(host, RoundPhase.captionWriting);
  for (final client in sim.peers.skip(1)) {
    await _waitForPhase(client, RoundPhase.captionWriting);
  }
  await host.submitMeme(
    template: MemeTemplate.classic,
    topText: 'Host meme $round',
    bottomText: 'bottom',
    snapY: 48,
  );
  for (var i = 0; i < sim.clients; i++) {
    await sim.peers[i + 1].clientSubmitMeme(
      template: MemeTemplate.classic,
      topText: 'Meme $round from $i',
      bottomText: 'bottom $i',
      snapY: 48 + i.toDouble(),
    );
  }
  await _waitForPhase(host, RoundPhase.captionVoting);
  for (final client in sim.peers.skip(1)) {
    await _waitForPhase(client, RoundPhase.captionVoting);
  }

  var guard = 0;
  while (host.state.phase == RoundPhase.captionVoting && guard < 12) {
    guard += 1;
    final focus = host.state.memeFocusId;
    if (focus == null || focus.isEmpty) break;
    for (final peer in sim.peers) {
      final cards = peer.state.memeCards;
      if (cards.isEmpty) continue;
      final ownId = cards.where((card) => card.isOwn).firstOrNull?.id;
      if (ownId == focus) continue;
      if (peer == host) {
        await host.voteMeme(focus, MemeVote.up);
      } else {
        await peer.clientVoteMeme(focus, MemeVote.up);
      }
    }
    await waitFor(
      () => host.state.memeFocusId != focus,
      timeout: const Duration(seconds: 10),
      reason: 'meme focus never advanced',
    );
  }
  await _waitForPhase(host, RoundPhase.captionReveal);
  expect(host.state.memeRevealCards, isNotEmpty);
  await host.advanceMemeReveal();
  await _waitForNextRound(host);
}

Future<void> playTimelineRound(Simulation sim, {required int round}) async {
  final host = sim.host;
  await _waitForPhase(host, RoundPhase.timelineGuessing);
  for (final client in sim.peers.skip(1)) {
    await _waitForPhase(client, RoundPhase.timelineGuessing);
  }
  await host.submitTimeline(2012 + round, (round % 12) + 1);
  for (var i = 0; i < sim.clients; i++) {
    await sim.peers[i + 1].clientSubmitTimeline(
      2010 + round + i,
      ((round + i) % 12) + 1,
    );
    final expected = i + 2;
    await waitFor(
      () => host.state.timelineGuesses >= expected,
      reason: 'host missed timeline guess ${i + 1}',
    );
  }
  await _waitForPhase(host, RoundPhase.timelineReveal);
  final reveal = host.state.lastTimelineReveal!;
  expect(reveal.entries, hasLength(sim.players));
  expect(reveal.actualYear, inInclusiveRange(1970, DateTime.now().year));
  expect(reveal.actualMonth, inInclusiveRange(1, 12));
  // The reveal is host-paced: it must not jump by itself.
  await Future<void>.delayed(const Duration(milliseconds: 120));
  expect(host.state.phase, RoundPhase.timelineReveal);
  await host.skipRound();
  await _waitForNextRound(host);
}

Future<void> playZoomRound(Simulation sim, {required int round}) async {
  final host = sim.host;
  await _waitForPhase(host, RoundPhase.guessing);
  for (final client in sim.peers.skip(1)) {
    await _waitForPhase(client, RoundPhase.guessing);
    expect(client.state.zoomAnchorX, closeTo(host.state.zoomAnchorX, 0.0001));
    expect(client.state.zoomAnchorY, closeTo(host.state.zoomAnchorY, 0.0001));
  }
  final options = host.state.activeRoundOptions;
  final target = options[(round - 1) % options.length].id;
  await host.submitGuess(target);
  for (final client in sim.peers.skip(1)) {
    await client.clientSubmitGuess(target);
  }
  await _waitForPhase(host, RoundPhase.reveal);
  expect(host.state.lastReveal, isNotNull);
  await host.skipRound();
  await _waitForNextRound(host);
}

Future<void> playSabotageRound(Simulation sim, {required int round}) async {
  final host = sim.host;
  await _waitForPhase(host, RoundPhase.captionWriting);
  for (final client in sim.peers.skip(1)) {
    await _waitForPhase(client, RoundPhase.captionWriting);
  }
  final strokes = <SabotageStroke>[
    SabotageStroke(
      colorIndex: round % 5,
      width: 0.01,
      points: const <Offset>[
        Offset(0.25, 0.3),
        Offset(0.55, 0.45),
        Offset(0.7, 0.7),
      ],
    ),
  ];
  await host.submitSabotage(strokes);
  for (var i = 0; i < sim.clients; i++) {
    await sim.peers[i + 1].clientSubmitSabotage(strokes);
  }
  await _waitForPhase(host, RoundPhase.captionVoting);
  for (final client in sim.peers.skip(1)) {
    await _waitForPhase(client, RoundPhase.captionVoting);
  }
  var guard = 0;
  while (host.state.phase == RoundPhase.captionVoting && guard < 12) {
    guard += 1;
    final focus = host.state.memeFocusId;
    if (focus == null || focus.isEmpty) break;
    for (final peer in sim.peers) {
      final cards = peer.state.memeCards;
      if (cards.isEmpty) continue;
      final ownId = cards.where((card) => card.isOwn).firstOrNull?.id;
      if (ownId == focus) continue;
      if (peer == host) {
        await host.voteMeme(focus, MemeVote.up);
      } else {
        await peer.clientVoteMeme(focus, MemeVote.up);
      }
    }
    await waitFor(
      () => host.state.memeFocusId != focus,
      timeout: const Duration(seconds: 10),
      reason: 'sabotage focus never advanced',
    );
  }
  await _waitForPhase(host, RoundPhase.captionReveal);
  expect(host.state.memeRevealCards, isNotEmpty);
  expect(host.state.memeRevealCards.every((card) => card.isSabotage), isTrue);
  await host.advanceMemeReveal();
  await _waitForNextRound(host);
}

Future<void> playRound(Simulation sim, {required int round}) async {
  final mode = sim.host.state.activeMode;
  switch (mode) {
    case GameMode.classic:
    case GameMode.captionThis:
      await playClassicRound(sim, round: round);
    case GameMode.zoomOut:
      await playZoomRound(sim, round: round);
    case GameMode.makeItMeme:
      await playMemeRound(sim, round: round);
    case GameMode.photoSabotage:
      await playSabotageRound(sim, round: round);
    case GameMode.timeTraveler:
      await playTimelineRound(sim, round: round);
    case GameMode.mixedParty:
      throw StateError('mixed party is a room mode, not a round mode');
  }
}

Map<String, int> _wrongGuessesByOwner(List<RoundReveal> reveals) {
  final counts = <String, int>{};
  for (final reveal in reveals) {
    final wrong = reveal.guesses
        .where(
          (guess) =>
              !guess.isOwnPhoto &&
              !guess.isCorrect &&
              guess.guessedOwnerId.isNotEmpty,
        )
        .length;
    counts[reveal.ownerId] = (counts[reveal.ownerId] ?? 0) + wrong;
  }
  return counts;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'classic tracks wrong guesses, timeouts and the Onraadbare foto award',
    () async {
      final sim = Simulation();
      addTearDown(sim.dispose);
      await sim.start(mode: GameMode.classic, rounds: 4);
      await sim.prepare();

      final reveals = <RoundReveal>[];
      for (var round = 1; round <= 4; round++) {
        await playClassicRound(sim, round: round, timeoutHalf: round.isEven);
        if (sim.host.state.lastReveal != null) {
          reveals.add(sim.host.state.lastReveal!);
        }
      }
      await _waitForPhase(sim.host, RoundPhase.podium);

      final wrongByOwner = _wrongGuessesByOwner(reveals);
      final expectedMax = wrongByOwner.values.fold<int>(0, max);
      expect(expectedMax, greaterThan(0));
      final award = sim.host.state.awards.firstWhere(
        (award) => award.kind == MatchAwardKind.masterOfMystery,
      );
      expect(award.value, expectedMax);
      final sorted = wrongByOwner.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      expect(award.value, sorted.first.value);

      final hasTimeout = reveals.any(
        (reveal) => reveal.guesses.any(
          (guess) => !guess.isOwnPhoto && guess.guessedOwnerId.isEmpty,
        ),
      );
      expect(hasTimeout, isTrue);
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'make it meme swaps photos, collects every vote and reveals a winner',
    () async {
      final sim = Simulation();
      addTearDown(sim.dispose);
      await sim.start(mode: GameMode.makeItMeme, rounds: 2);
      await sim.prepare();

      await _waitForPhase(sim.host, RoundPhase.captionWriting);
      final firstAssignment = sim.host.state.memeAssignment!.photoId;
      await sim.host.swapMemePhoto();
      await waitFor(
        () => sim.host.state.memeAssignment!.photoId != firstAssignment,
        reason: 'host meme photo did not swap',
      );

      await playMemeRound(sim, round: 1);
      await _waitForPhase(sim.host, RoundPhase.captionWriting);
      expect(sim.host.state.memeAssignment!.photoId, isNot(firstAssignment));
      await playMemeRound(sim, round: 2);
      await _waitForPhase(sim.host, RoundPhase.podium);

      expect(sim.host.state.topMemes, isNotEmpty);
      expect(
        sim.host.state.topMemes.every(
          (meme) => meme.photoBase64.isNotEmpty || meme.photoId.isNotEmpty,
        ),
        isTrue,
      );
      expect(sim.host.state.topMemes.first.upVotes, greaterThan(0));
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'zero memes never freezes: the host advances to the next round',
    () async {
      final sim = Simulation();
      addTearDown(sim.dispose);
      await sim.start(mode: GameMode.makeItMeme, rounds: 2);
      await sim.prepare();

      await _waitForPhase(sim.host, RoundPhase.captionWriting);
      await sim.host.skipRound();
      await _waitForPhase(sim.host, RoundPhase.captionReveal);
      expect(sim.host.state.memeRevealCards, isEmpty);

      await waitFor(
        () => sim.host.state.phase != RoundPhase.captionReveal,
        timeout: const Duration(seconds: 3),
        reason: 'empty meme reveal stayed frozen',
      );
      expect(sim.host.state.currentRound, greaterThanOrEqualTo(2));
      expect(sim.host.state.phase, isNot(RoundPhase.podium));
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test('time traveler carries EXIF dates and host-paced reveals', () async {
    final sim = Simulation();
    addTearDown(sim.dispose);
    final rounds = _roundsFor(3);
    await sim.start(mode: GameMode.timeTraveler, rounds: rounds);
    await sim.prepare();

    for (var round = 1; round <= rounds; round++) {
      await playTimelineRound(sim, round: round);
    }
    await _waitForPhase(sim.host, RoundPhase.podium);
    expect(sim.host.state.awards, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('eight player timeline reveals stagger all eight guesses', () {
    final engine = HostGameEngine(
      config: const MatchConfig(
        roundsK: 1,
        roundSeconds: 8,
        mode: GameMode.timeTraveler,
      ),
      random: Random(31),
      planterOverride: 'p0',
    );
    for (var i = 0; i < 8; i++) {
      engine.addPlayer(id: 'p$i', name: 'Player $i', isHost: i == 0);
    }
    engine.startPrepare();
    for (var i = 0; i < 8; i++) {
      engine.submitInitialPhotos(
        'p$i',
        List<PhotoCandidate>.generate(
          2,
          (index) => PhotoCandidate(
            photoId: 'p$i-$index',
            localAssetId: 'asset-$i-$index',
            ownerId: 'p$i',
            capturedYear: 1994 + index * 4,
            capturedMonth: 1 + (index * 5) % 12,
          ),
        ),
      );
      engine.markReady('p$i');
    }
    engine.startGame();
    final entry = engine.startRound();
    expect(engine.phase, RoundPhase.timelineGuessing);
    for (var i = 0; i < 8; i++) {
      engine.submitTimelineGuess(
        playerId: 'p$i',
        year: 1990 + i * 3,
        month: (i % 12) + 1,
        elapsedMs: 1000 + i * 250,
      );
    }
    final reveal = engine.finishTimelineRound(durationMs: 8000);
    expect(reveal.actualYear, isNotNull);
    expect(reveal.actualMonth, isNotNull);
    expect(reveal.entries, hasLength(8));
    expect(reveal.entries.where((entry) => entry.year != null), hasLength(8));
    // Every guess lands on a different fraction of the timeline, so the pin
    // layouter has eight distinct horizontal anchors to stack.
    final fractions = reveal.entries
        .map((entry) => entry.year! * 12 + (entry.month ?? 1))
        .toSet();
    expect(fractions, hasLength(8));
    expect(entry.ownerId, isNotEmpty);
  });

  test('zoom-out keeps every phone on the same anchor', () async {
    final sim = Simulation();
    addTearDown(sim.dispose);
    await sim.start(mode: GameMode.zoomOut, rounds: 2);
    await sim.prepare();
    for (var round = 1; round <= 2; round++) {
      await playZoomRound(sim, round: round);
    }
    await _waitForPhase(sim.host, RoundPhase.podium);
    expect(sim.host.state.awards, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('an empty sabotage round skips cleanly', () async {
    final sim = Simulation();
    addTearDown(sim.dispose);
    await sim.start(mode: GameMode.photoSabotage, rounds: 1);
    await sim.prepare();
    await _waitForPhase(sim.host, RoundPhase.captionWriting);
    await _waitForPhase(
      sim.host,
      RoundPhase.captionReveal,
      timeout: const Duration(seconds: 5),
    );
    expect(sim.host.state.memeRevealCards, isEmpty);
    await sim.host.advanceMemeReveal();
    await _waitForPhase(sim.host, RoundPhase.podium);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('mixed party is two of each mode with unique photos', () async {
    final sim = Simulation();
    addTearDown(sim.dispose);
    await sim.start(mode: GameMode.mixedParty, rounds: 10);
    await sim.prepare();

    final modes = <GameMode>[];
    final photos = <String>[];
    for (var round = 1; round <= 10; round++) {
      await waitFor(
        () =>
            sim.host.state.phase == RoundPhase.guessing ||
            sim.host.state.phase == RoundPhase.captionWriting ||
            sim.host.state.phase == RoundPhase.timelineGuessing ||
            sim.host.state.phase == RoundPhase.podium,
        timeout: const Duration(seconds: 20),
      );
      if (sim.host.state.phase == RoundPhase.podium) break;
      final mode = sim.host.state.activeMode;
      modes.add(mode);
      final photoId =
          mode == GameMode.makeItMeme || mode == GameMode.photoSabotage
          ? sim.host.state.memeAssignment?.photoId
          : sim.host.state.activePhotoId;
      expect(photoId, isNotNull, reason: 'round $round has no photo');
      photos.add(photoId!);
      await playRound(sim, round: round);
    }
    await _waitForPhase(sim.host, RoundPhase.podium);

    expect(modes, hasLength(10));
    for (final mode in <GameMode>[
      GameMode.classic,
      GameMode.zoomOut,
      GameMode.makeItMeme,
      GameMode.photoSabotage,
    ]) {
      expect(
        modes.where((candidate) => candidate == mode).length,
        greaterThanOrEqualTo(2),
      );
    }
    expect(modes.where((candidate) => candidate == GameMode.timeTraveler), isEmpty);
    for (var i = 1; i < modes.length; i++) {
      expect(modes[i], isNot(modes[i - 1]), reason: 'consecutive mode $i');
    }
    expect(photos.toSet(), hasLength(photos.length));
    expect(sim.host.state.awards, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 180)));
}
