import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/engine/host_game_engine.dart';

class _FakeClock {
  DateTime now = DateTime.utc(2026, 1, 1, 20);
  DateTime call() => now;
  void advance(int ms) => now = now.add(Duration(milliseconds: ms));
}

List<PhotoCandidate> photos(
  String ownerId,
  int count, {
  String prefix = 'p',
  bool dated = false,
}) => List<PhotoCandidate>.generate(
  count,
  (i) => PhotoCandidate(
    photoId: '$prefix-$ownerId-$i',
    localAssetId: 'asset-$ownerId-$i',
    ownerId: ownerId,
    capturedYear: dated ? 2015 + (i % 6) : null,
    capturedMonth: dated ? 1 + ((i * 3) % 12) : null,
  ),
);

/// Lobby with [count] players and a config, all prepped and ready.
HostGameEngine readyEngine({
  int players = 4,
  int roundsK = 10,
  int roundSeconds = 8,
  int seed = 7,
  int? photosPerPlayer,
  GameMode mode = GameMode.classic,
  bool datedPhotos = false,
}) {
  final engine = HostGameEngine(
    config: MatchConfig(
      roundsK: roundsK,
      roundSeconds: roundSeconds,
      mode: mode,
    ),
    random: Random(seed),
    planterOverride: 'p0',
  );
  for (var i = 0; i < players; i++) {
    engine.addPlayer(id: 'p$i', name: 'Player $i', isHost: i == 0);
  }
  engine.startPrepare();
  final perPlayer = photosPerPlayer ?? engine.photosNeeded;
  for (var i = 0; i < players; i++) {
    engine.submitInitialPhotos(
      'p$i',
      photos('p$i', perPlayer, dated: datedPhotos),
    );
    engine.markReady('p$i');
  }
  return engine;
}

/// Plays every round of the current deck with correct opponent guesses at
/// [elapsedMs] and own-photo taps by the owner.
void playAllCorrect(HostGameEngine engine, {int elapsedMs = 2000}) {
  while (engine.phase == RoundPhase.countdown) {
    final entry = engine.startRound();
    for (final player in engine.players) {
      final guess = player.id == entry.ownerId ? entry.ownerId : entry.ownerId;
      engine.submitGuess(player.id, guess, elapsedMs);
    }
    engine.finishRound();
    engine.advanceAfterReveal();
  }
}

void main() {
  group('lobby and preparation', () {
    test('photosNeeded is max(3, ceil(K / n) + 1)', () {
      expect(HostGameEngine.computePhotosNeeded(10, 4), 4);
      expect(HostGameEngine.computePhotosNeeded(10, 3), 5);
      expect(HostGameEngine.computePhotosNeeded(2, 6), 3);
      expect(HostGameEngine.computePhotosNeeded(20, 2), 11);
      expect(HostGameEngine.computePhotosNeeded(10, 0), 3);
    });

    test('startPrepare exposes photosNeeded to the clients', () {
      final engine = HostGameEngine(config: const MatchConfig(roundsK: 10));
      for (var i = 0; i < 4; i++) {
        engine.addPlayer(id: 'p$i', name: 'P$i');
      }
      engine.startPrepare();
      expect(engine.phase, RoundPhase.preparing);
      expect(engine.photosNeeded, 4);
    });

    test('cannot start the match before every player is ready', () {
      final engine = HostGameEngine();
      engine.addPlayer(id: 'a', name: 'A');
      engine.addPlayer(id: 'b', name: 'B');
      engine.startPrepare();
      engine.submitInitialPhotos('a', photos('a', 3));
      engine.submitInitialPhotos('b', photos('b', 3));
      engine.markReady('a');
      expect(
        () => engine.startGame(),
        throwsA(
          isA<EngineException>().having(
            (e) => e.code,
            'code',
            'players_not_ready',
          ),
        ),
      );
      engine.markReady('b');
      engine.startGame();
      expect(engine.phase, RoundPhase.countdown);
    });

    test('rejects photos owned by someone else', () {
      final engine = HostGameEngine();
      engine.addPlayer(id: 'a', name: 'A');
      engine.addPlayer(id: 'b', name: 'B');
      engine.startPrepare();
      expect(
        () => engine.submitInitialPhotos('a', photos('b', 3)),
        throwsA(
          isA<EngineException>().having((e) => e.code, 'code', 'wrong_owner'),
        ),
      );
    });

    test('seeded engines build identical decks', () {
      final a = readyEngine(seed: 42);
      final b = readyEngine(seed: 42);
      a.startGame();
      b.startGame();
      expect(
        a.deck.map((e) => e.photo.photoId).toList(),
        b.deck.map((e) => e.photo.photoId).toList(),
      );
    });
  });

  group('balanced round-robin deck', () {
    for (final playerCount in <int>[2, 3, 4, 5, 6]) {
      test(
        'no player gets a 2nd photo before everyone has a 1st ($playerCount players)',
        () {
          final engine = readyEngine(
            players: playerCount,
            roundsK: 20,
            seed: 3,
          );
          engine.startGame();
          final deck = engine.deck;
          expect(deck.length, 20);

          final counts = <String, int>{};
          for (final entry in deck) {
            // The invariant: before this entry, every player must have the same
            // number of appearances, or this player must be one behind.
            final minCount = counts.values.isEmpty
                ? 0
                : counts.values.reduce(min);
            final own = counts[entry.ownerId] ?? 0;
            expect(
              own,
              lessThanOrEqualTo(minCount + 1),
              reason: 'round ${entry.roundNumber} broke the round-robin order',
            );
            counts[entry.ownerId] = own + 1;
          }
        },
      );
    }

    test('every player appears exactly once per cycle for K = n * cycles', () {
      final engine = readyEngine(players: 4, roundsK: 12, seed: 11);
      engine.startGame();
      final deck = engine.deck;
      for (var cycle = 0; cycle < 3; cycle++) {
        final owners = deck
            .skip(cycle * 4)
            .take(4)
            .map((e) => e.ownerId)
            .toSet();
        expect(owners, <String>{'p0', 'p1', 'p2', 'p3'});
      }
    });

    test('cycle boundaries never repeat the owner back to back (n > 2)', () {
      for (var seed = 0; seed < 40; seed++) {
        final engine = readyEngine(players: 4, roundsK: 16, seed: seed);
        engine.startGame();
        final deck = engine.deck;
        for (var i = 1; i < deck.length; i++) {
          expect(
            deck[i].ownerId,
            isNot(deck[i - 1].ownerId),
            reason: 'seed $seed repeated ${deck[i].ownerId} at round ${i + 1}',
          );
        }
      }
    });

    test('a player never sees their own photo twice in a row', () {
      final engine = readyEngine(players: 3, roundsK: 9, seed: 5);
      engine.startGame();
      final seen = <String, List<String>>{};
      for (final entry in engine.deck) {
        seen
            .putIfAbsent(entry.ownerId, () => <String>[])
            .add(entry.photo.photoId);
      }
      for (final ids in seen.values) {
        expect(ids.toSet().length, ids.length);
      }
    });

    test('deck draws distinct photos per owner', () {
      final engine = readyEngine(players: 4, roundsK: 12, seed: 9);
      engine.startGame();
      final byOwner = <String, List<String>>{};
      for (final entry in engine.deck) {
        byOwner
            .putIfAbsent(entry.ownerId, () => <String>[])
            .add(entry.photo.photoId);
      }
      for (final ids in byOwner.values) {
        expect(ids.toSet().length, ids.length);
      }
    });
  });

  group('Caption This', () {
    test('keeps captions anonymous and pays the vote winners', () {
      final engine = readyEngine(
        players: 3,
        roundsK: 3,
        photosPerPlayer: 3,
        mode: GameMode.captionThis,
      );
      engine.startGame();
      final entry = engine.startRound();
      expect(entry.mode, GameMode.captionThis);
      expect(engine.phase, RoundPhase.captionWriting);

      engine.submitCaption('p0', 'the first one');
      engine.submitCaption('p1', 'the funny one');
      engine.submitCaption('p2', 'the quiet one');
      expect(engine.allCaptionsSubmitted, isTrue);
      engine.beginCaptionVoting();
      expect(engine.phase, RoundPhase.captionVoting);
      expect(engine.captionOptions, hasLength(3));

      final p0Caption = engine.captionIdFor('p0')!;
      final p1Caption = engine.captionIdFor('p1')!;
      expect(
        () => engine.submitCaptionVote('p0', p0Caption),
        throwsA(
          isA<EngineException>().having((e) => e.code, 'code', 'own_caption'),
        ),
      );
      engine.submitCaptionVote('p0', p1Caption);
      engine.submitCaptionVote('p1', p0Caption);
      engine.submitCaptionVote('p2', p1Caption);
      expect(engine.allCaptionVotesSubmitted, isTrue);

      final reveal = engine.finishCaptionRound();
      expect(engine.phase, RoundPhase.captionReveal);
      expect(reveal.entries.first.authorId, 'p1');
      expect(reveal.entries.first.votes, 2);
      expect(reveal.entries.first.points, 400);
      expect(reveal.winnerIds, <String>[p1Caption]);
      expect(engine.player('p1')!.score, 400);
      expect(engine.player('p0')!.score, 100);
      expect(engine.player('p2')!.score, 0);
      final before = engine.player('p1')!.score;
      engine.advanceAfterReveal();
      expect(engine.phase, RoundPhase.countdown);
      expect(engine.player('p1')!.score, before);
    });
  });

  group('Time Traveler', () {
    test('scores by month distance and crowns the closest and furthest', () {
      final engine = readyEngine(
        players: 3,
        roundsK: 3,
        photosPerPlayer: 3,
        mode: GameMode.timeTraveler,
        datedPhotos: true,
      );
      engine.startGame();
      final entry = engine.startRound();
      expect(entry.mode, GameMode.timeTraveler);
      expect(engine.phase, RoundPhase.timelineGuessing);
      final actualYear = entry.photo.capturedYear!;
      final actualMonth = entry.photo.capturedMonth!;
      final others = engine.players
          .where((player) => player.id != entry.ownerId)
          .toList();
      final exact = others.first;
      final far = others.last;
      if (exact.id == far.id) {
        return;
      }
      engine.submitTimelineGuess(
        playerId: exact.id,
        year: actualYear,
        month: actualMonth,
        elapsedMs: 1000,
      );
      final farDate = DateTime(actualYear - 3, actualMonth, 1);
      engine.submitTimelineGuess(
        playerId: far.id,
        year: farDate.year,
        month: farDate.month,
        elapsedMs: 9000,
      );
      engine.submitTimelineGuess(
        playerId: entry.ownerId,
        year: actualYear,
        month: actualMonth,
        elapsedMs: 2000,
      );
      expect(engine.allTimelineGuessed, isTrue);

      final reveal = engine.finishTimelineRound(durationMs: 30000);
      expect(engine.phase, RoundPhase.timelineReveal);
      expect(reveal.actualYear, actualYear);
      expect(reveal.actualMonth, actualMonth);
      expect(reveal.closestId, exact.id);
      expect(reveal.furthestId, far.id);
      final exactEntry = reveal.entries.firstWhere(
        (item) => item.playerId == exact.id,
      );
      final farEntry = reveal.entries.firstWhere(
        (item) => item.playerId == far.id,
      );
      final ownerEntry = reveal.entries.firstWhere(
        (item) => item.playerId == entry.ownerId,
      );
      expect(exactEntry.monthsOff, 0);
      expect(exactEntry.points, greaterThan(farEntry.points));
      expect(farEntry.monthsOff, 36);
      expect(ownerEntry.isOwner, isTrue);
      // The owner guesses their own photo and scores like everyone else:
      // 1000 accuracy + 200 speed - round(200 * 2000 / 30000) = 1187.
      expect(ownerEntry.monthsOff, 0);
      expect(ownerEntry.points, 1187);
      expect(reveal.scoreDeltas[entry.ownerId], 1187);
    });
  });

  group('Mixed Party', () {
    test('rotates through all three modes and repeats the cycle', () {
      final engine = readyEngine(
        players: 3,
        roundsK: 6,
        photosPerPlayer: 3,
        mode: GameMode.mixedParty,
        datedPhotos: true,
      );
      engine.startGame();
      final modes = engine.deck.map((entry) => entry.mode).toList();
      final firstCycle = modes.take(3).toSet();
      expect(firstCycle, hasLength(3));
      expect(firstCycle, isNot(contains(GameMode.mixedParty)));
      expect(modes[3], modes[0]);
      expect(modes[4], modes[1]);
      expect(modes[5], modes[2]);
    });
  });

  group('scoring', () {
    test('opponent correct guess: 500 + floor(500 * remaining / total)', () {
      final engine = readyEngine(players: 2, roundsK: 2, roundSeconds: 8);
      engine.startGame();
      final entry = engine.startRound();
      final guesser = entry.ownerId == 'p0' ? 'p1' : 'p0';
      engine.submitGuess(guesser, entry.ownerId, 2000);
      final reveal = engine.finishRound();
      // remaining 6000 of 8000 -> 500 + 375 = 875
      expect(reveal.scoreDeltas[guesser], 875);
      expect(engine.player(guesser)!.score, 875);
    });

    test('instant correct guess is worth 1000', () {
      final engine = readyEngine(players: 2, roundsK: 2);
      engine.startGame();
      final entry = engine.startRound();
      final guesser = entry.ownerId == 'p0' ? 'p1' : 'p0';
      engine.submitGuess(guesser, entry.ownerId, 0);
      final reveal = engine.finishRound();
      expect(reveal.scoreDeltas[guesser], 1000);
    });

    test('guess at the buzzer is worth the 500 base', () {
      final engine = readyEngine(players: 2, roundsK: 2);
      engine.startGame();
      final entry = engine.startRound();
      final guesser = entry.ownerId == 'p0' ? 'p1' : 'p0';
      engine.submitGuess(guesser, entry.ownerId, 8000);
      final reveal = engine.finishRound();
      expect(reveal.scoreDeltas[guesser], 500);
    });

    test('elapsed beyond the timer is clamped, never negative', () {
      final engine = readyEngine(players: 2, roundsK: 2);
      engine.startGame();
      final entry = engine.startRound();
      final guesser = entry.ownerId == 'p0' ? 'p1' : 'p0';
      engine.submitGuess(guesser, entry.ownerId, 99999);
      final reveal = engine.finishRound();
      expect(reveal.scoreDeltas[guesser], 500);
    });

    test('streak bonus: +100 per streak step above 1, capped at 400', () {
      final engine = readyEngine(players: 2, roundsK: 8);
      engine.startGame();
      final guesser = 'p1';
      final bonuses = <int>[];
      for (var round = 0; round < 8; round++) {
        final entry = engine.startRound();
        final scoreBefore = engine.player(guesser)!.score;
        final streakBefore = engine.player(guesser)!.streak;
        engine.submitGuess(guesser, entry.ownerId, 2000);
        engine.finishRound();
        final gained = engine.player(guesser)!.score - scoreBefore;
        expect(engine.player(guesser)!.streak, streakBefore + 1);
        final expectedBonus = streakBefore < 2
            ? 0
            : min(400, 100 * (streakBefore - 1));
        // 2000 ms of 8000 elapsed leaves 6000 ms -> floor(500 * 6 / 8) = 375.
        expect(gained, 875 + expectedBonus);
        bonuses.add(expectedBonus);
        engine.advanceAfterReveal();
      }
      // Every round is a correct guess now, own photo or not, so the bonus
      // sequence only climbs until it hits the cap.
      expect(bonuses, isNotEmpty);
      for (var i = 1; i < bonuses.length; i++) {
        expect(bonuses[i], greaterThanOrEqualTo(bonuses[i - 1]));
      }
      expect(bonuses.first, 0);
      expect(bonuses.last, 400);
      expect(engine.player(guesser)!.longestStreak, 8);
    });

    test('wrong guess scores 0 and resets the streak', () {
      final engine = readyEngine(players: 3, roundsK: 4);
      engine.startGame();
      final entry = engine.startRound();
      final guesser = entry.ownerId == 'p0' ? 'p1' : 'p0';
      final wrong = <String>[
        'p0',
        'p1',
        'p2',
      ].firstWhere((id) => id != entry.ownerId && id != guesser);
      engine.submitGuess(guesser, wrong, 1000);
      final reveal = engine.finishRound();
      expect(reveal.scoreDeltas[guesser], 0);
      expect(engine.player(guesser)!.streak, 0);
    });

    test('timeout scores 0 and resets the streak', () {
      final engine = readyEngine(players: 2, roundsK: 2);
      engine.startGame();
      final entry = engine.startRound();
      final guesser = entry.ownerId == 'p0' ? 'p1' : 'p0';
      engine.player(guesser)!.streak = 4;
      final reveal = engine.finishRound();
      expect(reveal.scoreDeltas[guesser], 0);
      expect(engine.player(guesser)!.streak, 0);
      final record = reveal.guesses.firstWhere((g) => g.playerId == guesser);
      expect(record.isCorrect, isFalse);
      expect(record.guessedOwnerId, isEmpty);
    });

    test('guesses are locked once submitted', () {
      final engine = readyEngine(players: 2, roundsK: 2);
      engine.startGame();
      final entry = engine.startRound();
      final guesser = entry.ownerId == 'p0' ? 'p1' : 'p0';
      engine.submitGuess(guesser, entry.ownerId, 1000);
      expect(
        () => engine.submitGuess(guesser, 'p0', 500),
        throwsA(
          isA<EngineException>().having(
            (e) => e.code,
            'code',
            'already_guessed',
          ),
        ),
      );
    });

    test('own photo: tapping your own name pays like any correct guess', () {
      final engine = readyEngine(players: 2, roundsK: 2);
      engine.startGame();
      final entry = engine.startRound();
      final owner = engine.player(entry.ownerId)!;
      owner.streak = 3;
      engine.submitGuess(owner.id, owner.id, 100);
      final reveal = engine.finishRound();
      // 500 + floor(500 * 7900 / 8000) + streak bonus 200 = 1193.
      expect(reveal.scoreDeltas[owner.id], 1193);
      expect(owner.streak, 4);
    });

    test('own photo: tapping someone else gives 0 and resets the streak', () {
      final engine = readyEngine(players: 3, roundsK: 3);
      engine.startGame();
      final entry = engine.startRound();
      final owner = engine.player(entry.ownerId)!;
      owner.streak = 2;
      final other = engine.players.firstWhere((p) => p.id != owner.id).id;
      engine.submitGuess(owner.id, other, 100);
      final reveal = engine.finishRound();
      expect(reveal.scoreDeltas[owner.id], 0);
      expect(owner.streak, 0);
    });

    test('mystery bonus: owner earns +150 per opponent who guessed wrong', () {
      final engine = readyEngine(players: 4, roundsK: 4);
      engine.startGame();
      final entry = engine.startRound();
      final ownerId = entry.ownerId;
      final others = engine.players
          .map((p) => p.id)
          .where((id) => id != ownerId)
          .toList();
      // Two opponents fooled, one right. The owner also nailed their own
      // photo: 500 + floor(500 * 7900 / 8000) = 993, plus 2 * 150 mystery.
      engine.submitGuess(ownerId, ownerId, 100);
      engine.submitGuess(others[0], others[1], 500);
      engine.submitGuess(others[1], others[0], 500);
      engine.submitGuess(others[2], others[0], 500);
      final reveal = engine.finishRound();
      final owner = engine.player(ownerId)!;
      expect(reveal.scoreDeltas[ownerId], 993 + 450);
      expect(owner.mysteryPointsEarned, 450);
      expect(owner.score, 1443);
    });

    test(
      'mystery bonus still applies when the owner bluffs on their own photo',
      () {
        final engine = readyEngine(players: 3, roundsK: 3);
        engine.startGame();
        final entry = engine.startRound();
        final ownerId = entry.ownerId;
        final others = engine.players
            .map((p) => p.id)
            .where((id) => id != ownerId)
            .toList();
        engine.submitGuess(ownerId, others.first, 100);
        engine.submitGuess(others[0], others[1], 500);
        engine.submitGuess(others[1], others[0], 500);
        final reveal = engine.finishRound();
        expect(reveal.scoreDeltas[ownerId], 300);
        expect(engine.player(ownerId)!.streak, 0);
      },
    );

    test('micro awards: fastest guess, nobody guessed, everyone nailed it', () {
      final engine = readyEngine(players: 3, roundsK: 3);
      engine.startGame();

      var entry = engine.startRound();
      var ownerId = entry.ownerId;
      final others = engine.players
          .map((p) => p.id)
          .where((id) => id != ownerId)
          .toList();
      engine.submitGuess(ownerId, ownerId, 100);
      engine.submitGuess(others[0], ownerId, 900);
      engine.submitGuess(others[1], ownerId, 400);
      var reveal = engine.finishRound();
      expect(reveal.microAward!.kind, MicroAwardKind.fastestGuess);
      expect(reveal.microAward!.playerId, others[1]);
      expect(reveal.microAward!.elapsedMs, 400);
      expect(reveal.everyoneGuessed, isTrue);
      expect(reveal.nobodyGuessed, isFalse);
      engine.advanceAfterReveal();

      entry = engine.startRound();
      ownerId = entry.ownerId;
      final rest = engine.players
          .map((p) => p.id)
          .where((id) => id != ownerId)
          .toList();
      engine.submitGuess(ownerId, ownerId, 100);
      engine.submitGuess(rest[0], rest[1], 300);
      engine.submitGuess(rest[1], rest[0], 300);
      reveal = engine.finishRound();
      expect(reveal.nobodyGuessed, isTrue);
      expect(reveal.microAward!.kind, MicroAwardKind.nobodyGuessed);
    });

    test('round ends once every connected player guessed', () {
      final engine = readyEngine(players: 3, roundsK: 3);
      engine.startGame();
      final entry = engine.startRound();
      expect(engine.allGuessed, isFalse);
      for (final player in engine.players) {
        engine.submitGuess(player.id, entry.ownerId, 1000);
      }
      expect(engine.allGuessed, isTrue);
    });

    test('longest streak tracks the best run', () {
      final engine = readyEngine(players: 2, roundsK: 4);
      engine.startGame();
      final guesser = 'p1';
      for (var round = 0; round < 4; round++) {
        final entry = engine.startRound();
        final target = entry.ownerId == 'p1' ? 'p0' : entry.ownerId;
        final correct = round != 2;
        engine.submitGuess(guesser, correct ? target : 'p0', 1000);
        engine.finishRound();
        engine.advanceAfterReveal();
      }
      final player = engine.player(guesser)!;
      expect(player.longestStreak, greaterThanOrEqualTo(2));
    });
  });

  group('plant a photo', () {
    HostGameEngine preparingEngine({int players = 3}) {
      final engine = HostGameEngine(random: Random(1), planterOverride: 'p0');
      for (var i = 0; i < players; i++) {
        engine.addPlayer(id: 'p$i', name: 'P$i');
      }
      engine.startPrepare();
      for (var i = 0; i < players; i++) {
        engine.submitInitialPhotos('p$i', photos('p$i', 4));
      }
      return engine;
    }

    PhotoCandidate planted(String owner) => PhotoCandidate(
      photoId: 'planted-$owner',
      localAssetId: 'gallery-$owner',
      ownerId: owner,
    );

    test('blocked before the player is Ready', () {
      final engine = preparingEngine();
      engine.markReady('p1');
      expect(engine.player('p0')!.ready, isFalse);
      expect(
        () => engine.plantSecretPhoto('p0', planted('p0')),
        throwsA(
          isA<EngineException>().having((e) => e.code, 'code', 'not_ready'),
        ),
      );
    });

    test('blocked for a player who is not the planter', () {
      final engine = preparingEngine();
      engine.markReady('p1');
      expect(
        () => engine.plantSecretPhoto('p1', planted('p1')),
        throwsA(
          isA<EngineException>().having((e) => e.code, 'code', 'not_planter'),
        ),
      );
    });

    test('blocked once every player is Ready', () {
      final engine = preparingEngine();
      for (var i = 0; i < 3; i++) {
        engine.markReady('p$i');
      }
      expect(engine.plantAvailable, isFalse);
      expect(
        () => engine.plantSecretPhoto('p0', planted('p0')),
        throwsA(
          isA<EngineException>().having((e) => e.code, 'code', 'plant_closed'),
        ),
      );
    });

    test('succeeds while the player is Ready and someone else is not', () {
      final engine = preparingEngine();
      engine.markReady('p0');
      expect(engine.plantAvailable, isTrue);
      engine.plantSecretPhoto('p0', planted('p0'));
      expect(engine.player('p0')!.plantUsed, isTrue);
    });

    test('blocked a second time in the same game', () {
      final engine = preparingEngine();
      engine.markReady('p0');
      engine.plantSecretPhoto('p0', planted('p0'));
      expect(
        () => engine.plantSecretPhoto('p0', planted('p0')),
        throwsA(
          isA<EngineException>().having((e) => e.code, 'code', 'plant_used'),
        ),
      );
    });

    test(
      'the planted photo replaces an approved one and stays secret in the deck',
      () {
        final engine = preparingEngine(players: 2);
        engine.markReady('p0');
        engine.plantSecretPhoto('p0', planted('p0'));
        engine.markReady('p1');
        engine.startGame();
        final ownEntries = engine.deck.where((e) => e.ownerId == 'p0').toList();
        expect(ownEntries.length, 4);
        expect(ownEntries.where((e) => e.photo.isPlanted).length, 1);
        expect(
          ownEntries.firstWhere((e) => e.photo.isPlanted).photo.photoId,
          'planted-p0',
        );
      },
    );

    test('plant window is closed for a single player room', () {
      final engine = preparingEngine(players: 1);
      engine.markReady('p0');
      expect(engine.plantAvailable, isFalse);
    });

    test('smooth planter award only when the planted photo fooled someone', () {
      final engine = preparingEngine(players: 2);
      engine.markReady('p0');
      engine.plantSecretPhoto('p0', planted('p0'));
      engine.markReady('p1');
      engine.startGame();
      while (engine.phase == RoundPhase.countdown) {
        final entry = engine.startRound();
        for (final player in engine.players) {
          if (player.id == entry.ownerId) {
            engine.submitGuess(player.id, player.id, 100);
          } else if (entry.photo.isPlanted) {
            engine.submitGuess(
              player.id,
              'p0' == entry.ownerId ? 'p1' : 'p0',
              100,
            );
          } else {
            engine.submitGuess(player.id, entry.ownerId, 100);
          }
        }
        engine.finishRound();
        engine.advanceAfterReveal();
      }
      final awards = engine.buildPodiumAwards();
      final planter = awards.where(
        (a) => a.kind == MatchAwardKind.smoothPlanter,
      );
      expect(planter.length, 1);
      expect(planter.first.playerId, 'p0');
      expect(planter.first.value, 1);
    });
  });

  group('dynamic K extension', () {
    test('extendGame opens a 10 second window after the podium', () {
      final clock = _FakeClock();
      final engine = HostGameEngine(random: Random(2), clock: clock.call);
      for (var i = 0; i < 3; i++) {
        engine.addPlayer(id: 'p$i', name: 'P$i');
      }
      engine.setRoundsK(3);
      engine.startPrepare();
      for (var i = 0; i < 3; i++) {
        engine.submitInitialPhotos('p$i', photos('p$i', engine.photosNeeded));
        engine.markReady('p$i');
      }
      engine.startGame();
      playAllCorrect(engine);
      expect(engine.phase, RoundPhase.podium);
      expect(engine.totalRounds, 3);

      final deadline = engine.extendGame(extraRounds: 5);
      expect(engine.phase, RoundPhase.extendPrompt);
      expect(engine.roundsK, 8);
      expect(deadline - clock.now.millisecondsSinceEpoch, 10000);
    });

    test(
      'commit appends +5 rounds and continues at K + 1 with scores kept',
      () {
        final clock = _FakeClock();
        final engine = HostGameEngine(random: Random(4), clock: clock.call);
        for (var i = 0; i < 4; i++) {
          engine.addPlayer(id: 'p$i', name: 'P$i');
        }
        engine.setRoundsK(4);
        engine.startPrepare();
        for (var i = 0; i < 4; i++) {
          engine.submitInitialPhotos('p$i', photos('p$i', engine.photosNeeded));
          engine.markReady('p$i');
        }
        engine.startGame();
        playAllCorrect(engine);
        final scoresBefore = engine.players.map((p) => p.score).toList();
        final lastRound = engine.currentRound;
        expect(lastRound, 4);

        engine.extendGame(extraRounds: 5);
        for (final player in engine.players) {
          engine.submitExtensionPhotos(
            player.id,
            photos(player.id, 3, prefix: 'extra'),
          );
        }
        expect(engine.phase, RoundPhase.countdown);
        expect(engine.totalRounds, 9);
        expect(engine.players.map((p) => p.score).toList(), scoresBefore);

        final next = engine.startRound();
        expect(next.roundNumber, 5);
        expect(next.roundNumber, lastRound + 1);
      },
    );

    test('timeout auto-commits so the match never stalls', () {
      final clock = _FakeClock();
      final engine = HostGameEngine(random: Random(6), clock: clock.call);
      for (var i = 0; i < 3; i++) {
        engine.addPlayer(id: 'p$i', name: 'P$i');
      }
      engine.setRoundsK(3);
      engine.startPrepare();
      for (var i = 0; i < 3; i++) {
        engine.submitInitialPhotos('p$i', photos('p$i', engine.photosNeeded));
        engine.markReady('p$i');
      }
      engine.startGame();
      playAllCorrect(engine);
      engine.extendGame(extraRounds: 5);

      engine.handleExtensionTimeout();
      expect(
        engine.phase,
        RoundPhase.extendPrompt,
        reason: 'window still open',
      );

      clock.advance(9999);
      engine.handleExtensionTimeout();
      expect(engine.phase, RoundPhase.extendPrompt);

      clock.advance(1);
      engine.handleExtensionTimeout();
      expect(engine.phase, RoundPhase.countdown);
      expect(engine.totalRounds, 8);
      final next = engine.startRound();
      expect(next.roundNumber, 4);
    });

    test('partial approvals commit once everyone answered', () {
      final engine = HostGameEngine(random: Random(8));
      for (var i = 0; i < 3; i++) {
        engine.addPlayer(id: 'p$i', name: 'P$i');
      }
      engine.setRoundsK(3);
      engine.startPrepare();
      for (var i = 0; i < 3; i++) {
        engine.submitInitialPhotos('p$i', photos('p$i', engine.photosNeeded));
        engine.markReady('p$i');
      }
      engine.startGame();
      playAllCorrect(engine);
      engine.extendGame();
      engine.submitExtensionPhotos('p0', photos('p0', 3, prefix: 'e'));
      expect(engine.phase, RoundPhase.extendPrompt);
      engine.submitExtensionPhotos('p1', photos('p1', 3, prefix: 'e'));
      expect(engine.phase, RoundPhase.extendPrompt);
      engine.submitExtensionPhotos('p2', photos('p2', 3, prefix: 'e'));
      expect(engine.phase, RoundPhase.countdown);
      expect(engine.totalRounds, 8);
    });

    test('extension deck stays balanced and never repeats back to back', () {
      final engine = readyEngine(players: 4, roundsK: 4, seed: 13);
      engine.startGame();
      playAllCorrect(engine);
      engine.extendGame(extraRounds: 5);
      for (final player in engine.players) {
        engine.submitExtensionPhotos(
          player.id,
          photos(player.id, 3, prefix: 'x'),
        );
      }
      final deck = engine.deck;
      expect(deck.length, 9);
      for (var i = 1; i < deck.length; i++) {
        expect(deck[i].ownerId, isNot(deck[i - 1].ownerId));
      }
      final counts = <String, int>{};
      for (final entry in deck.take(8)) {
        counts[entry.ownerId] = (counts[entry.ownerId] ?? 0) + 1;
      }
      expect(counts.values.toSet(), <int>{2});
    });

    test('cannot extend before the podium', () {
      final engine = readyEngine(players: 2, roundsK: 2);
      engine.startGame();
      expect(
        () => engine.extendGame(),
        throwsA(
          isA<EngineException>().having((e) => e.code, 'code', 'wrong_phase'),
        ),
      );
    });
  });

  group('screenshots and podium awards', () {
    test('recordScreenshot counts per player and exposes a banner award', () {
      final engine = readyEngine(players: 3, roundsK: 3);
      engine.startGame();
      engine.startRound();
      engine.recordScreenshot('p1');
      engine.recordScreenshot('p1');
      engine.recordScreenshot('p2');
      expect(engine.player('p1')!.screenshotCount, 2);
      expect(engine.player('p2')!.screenshotCount, 1);
      expect(engine.lastMicroAward!.kind, MicroAwardKind.screenshot);
      expect(engine.lastMicroAward!.playerName, 'Player 2');
    });

    test('full podium awards', () {
      final engine = readyEngine(players: 3, roundsK: 6);
      engine.startGame();
      final first = engine.startRound();
      // One fooled opponent on the first photo earns the owner mystery points.
      final ownerId = first.ownerId;
      final others = engine.players
          .map((p) => p.id)
          .where((id) => id != ownerId)
          .toList();
      engine.submitGuess(ownerId, ownerId, 100);
      engine.submitGuess(others[0], others[1], 200);
      engine.submitGuess(others[1], ownerId, 300);
      engine.finishRound();
      engine.advanceAfterReveal();
      playAllCorrect(engine);
      engine.recordScreenshot('p2');
      final awards = engine.buildPodiumAwards();
      final kinds = awards.map((a) => a.kind).toSet();
      expect(kinds, contains(MatchAwardKind.champion));
      expect(kinds, contains(MatchAwardKind.quickestDraw));
      expect(kinds, contains(MatchAwardKind.unstoppable));
      expect(kinds, contains(MatchAwardKind.masterOfMystery));
      expect(kinds, contains(MatchAwardKind.paparazzi));
      expect(kinds, isNot(contains(MatchAwardKind.smoothPlanter)));

      final mystery = awards.firstWhere(
        (a) => a.kind == MatchAwardKind.masterOfMystery,
      );
      expect(mystery.playerId, ownerId);
      expect(mystery.value, 150);

      final champion = awards.firstWhere(
        (a) => a.kind == MatchAwardKind.champion,
      );
      final top = engine.leaderboard.first;
      expect(champion.playerId, top.id);
      expect(champion.value, top.score);

      final paparazzi = awards.firstWhere(
        (a) => a.kind == MatchAwardKind.paparazzi,
      );
      expect(paparazzi.playerId, 'p2');
      expect(paparazzi.value, 1);
    });

    test('paparazzi is omitted when nobody took a screenshot', () {
      final engine = readyEngine(players: 3, roundsK: 3);
      engine.startGame();
      playAllCorrect(engine);
      final awards = engine.buildPodiumAwards();
      expect(awards.where((a) => a.kind == MatchAwardKind.paparazzi), isEmpty);
    });

    test('quickest draw uses the average correct time', () {
      final engine = readyEngine(players: 2, roundsK: 2);
      engine.startGame();
      final entry = engine.startRound();
      final guesser = entry.ownerId == 'p0' ? 'p1' : 'p0';
      engine.submitGuess(guesser, entry.ownerId, 300);
      engine.finishRound();
      engine.advanceAfterReveal();
      final awards = engine.buildPodiumAwards();
      final quick = awards.firstWhere(
        (a) => a.kind == MatchAwardKind.quickestDraw,
      );
      expect(quick.playerId, guesser);
      expect(quick.value, 300);
    });
  });

  group('state snapshot', () {
    test('carries phase, players and the active round for reconnect', () {
      final engine = readyEngine(players: 3, roundsK: 3);
      engine.startGame();
      final entry = engine.startRound();
      engine.submitGuess('p0', entry.ownerId, 500);
      final snapshot = engine.buildStateSnapshot();
      expect(snapshot['phase'], 'guessing');
      expect(snapshot['currentRound'], 1);
      expect(snapshot['totalRounds'], 3);
      expect((snapshot['players'] as List).length, 3);
      final current = snapshot['currentEntry'] as Map<String, dynamic>;
      expect(
        (current['photo'] as Map<String, dynamic>)['photoId'],
        entry.photo.photoId,
      );

      expect((snapshot['guesses'] as List).length, 1);
    });

    test(
      'removing a player mid match keeps their score but marks them offline',
      () {
        final engine = readyEngine(players: 3, roundsK: 3);
        engine.startGame();
        engine.player('p1')!.score = 900;
        engine.removePlayer('p1');
        expect(engine.playerCount, 3);
        expect(engine.player('p1')!.connected, isFalse);
        expect(engine.player('p1')!.score, 900);
      },
    );
  });
}
