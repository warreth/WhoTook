import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/models/models.dart';

void main() {
  test('MatchConfig defaults to 10 rounds of 8 seconds', () {
    const config = MatchConfig();
    expect(config.roundsK, 10);
    expect(config.roundSeconds, 8);
    expect(config.roundMs, 8000);
    expect(config.copyWith(roundsK: 5).roundsK, 5);
    expect(config.copyWith(roundsK: 5).roundSeconds, 8);
    expect(MatchConfig.fromJson(config.toJson()).roundsK, 10);
  });

  test('Player tracks averages and roundtrips through JSON', () {
    final player = Player(
      id: 'p1',
      name: 'Sam',
      avatarColorIndex: 2,
      isHost: true,
      score: 1200,
      streak: 3,
      longestStreak: 4,
      correctCount: 2,
      totalCorrectMs: 900,
      mysteryPointsEarned: 450,
      screenshotCount: 1,
      plantUsed: true,
    );
    expect(player.averageCorrectMs, 450);

    final restored = Player.fromJson(player.toJson());
    expect(restored.id, 'p1');
    expect(restored.name, 'Sam');
    expect(restored.isHost, isTrue);
    expect(restored.score, 1200);
    expect(restored.longestStreak, 4);
    expect(restored.mysteryPointsEarned, 450);
    expect(restored.plantUsed, isTrue);
    expect(Player(id: 'x', name: 'X').averageCorrectMs, isNull);
  });

  test('PhotoCandidate JSON omits bytes but keeps the identity', () {
    final photo = PhotoCandidate(
      photoId: 'ph1',
      localAssetId: 'asset1',
      ownerId: 'p1',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      isPlanted: true,
    );
    final json = photo.toJson();
    expect(json.containsKey('bytes'), isFalse);
    expect(json['isPlanted'], isTrue);
    final restored = PhotoCandidate.fromJson(json);
    expect(restored.photoId, 'ph1');
    expect(restored.ownerId, 'p1');
    expect(restored.bytes, isNull);
    expect(photo.copyWith(isPlanted: false).isPlanted, isFalse);
  });

  test(
    'RoundReveal roundtrips guesses, deltas, streaks and the micro award',
    () {
      final reveal = RoundReveal(
        roundNumber: 2,
        ownerId: 'p1',
        photoId: 'ph1',
        isPlanted: false,
        guesses: const <GuessRecord>[
          GuessRecord(
            playerId: 'p2',
            guessedOwnerId: 'p1',
            elapsedMs: 400,
            isCorrect: true,
            isOwnPhoto: false,
            pointsAwarded: 975,
          ),
        ],
        scoreDeltas: const <String, int>{'p2': 975},
        streaks: const <String, int>{'p2': 1},
        microAward: const MicroAward(
          kind: MicroAwardKind.fastestGuess,
          playerId: 'p2',
          playerName: 'Sam',
          elapsedMs: 400,
        ),
        everyoneGuessed: true,
      );
      final restored = RoundReveal.fromJson(reveal.toJson());
      expect(restored.roundNumber, 2);
      expect(restored.guesses.single.pointsAwarded, 975);
      expect(restored.scoreDeltas['p2'], 975);
      expect(restored.microAward!.kind, MicroAwardKind.fastestGuess);
      expect(restored.everyoneGuessed, isTrue);
      expect(restored.microAward!.toJson()['elapsedMs'], 400);
    },
  );

  test('MatchAward roundtrips', () {
    const award = MatchAward(
      kind: MatchAwardKind.smoothPlanter,
      playerId: 'p1',
      playerName: 'Sam',
      value: 2,
    );
    final restored = MatchAward.fromJson(award.toJson());
    expect(restored.kind, MatchAwardKind.smoothPlanter);
    expect(restored.playerName, 'Sam');
    expect(restored.value, 2);
  });

  test('AppSettings roundtrips and defaults cleanly', () {
    const settings = AppSettings(
      nickname: 'Sam',
      excludedAlbumIds: <String>{'b', 'a'},
      themePreference: ThemePreference.light,
      onboardingCompleted: true,
    );
    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.nickname, 'Sam');
    expect(restored.excludedAlbumIds, <String>{'a', 'b'});
    expect(restored.themePreference, ThemePreference.light);
    expect(restored.onboardingCompleted, isTrue);
    expect(restored.copyWith(nickname: 'Alex').nickname, 'Alex');
    expect(restored.copyWith(nickname: 'Alex').avatarColorIndex, 0);
  });

  test('TurnLimitNotice parses the signaling error body', () {
    final notice = TurnLimitNotice.fromJson(<String, dynamic>{
      'reason': 'DAILY_TURN_LIMIT_REACHED',
      'dailyLimit': 5,
      'usedToday': 5,
      'retryAtUtc': '2026-11-14T00:00:00.000Z',
    });
    expect(notice.reason, 'DAILY_TURN_LIMIT_REACHED');
    expect(notice.dailyLimit, 5);
    expect(notice.usedToday, 5);
    expect(notice.retryAtUtc.isUtc, isTrue);
    expect(
      TurnLimitNotice.fromJson(notice.toJson()).retryAtUtc,
      notice.retryAtUtc,
    );
  });

  test('photo metadata carries only the year and month', () {
    final photo = PhotoCandidate(
      photoId: 'p1',
      localAssetId: 'a1',
      ownerId: 'host',
      capturedYear: 2019,
      capturedMonth: 8,
    );
    final json = photo.toJson();
    expect(json['capturedYear'], 2019);
    expect(json['capturedMonth'], 8);
    expect(json.containsKey('capturedAtMs'), isFalse);

    final legacy = PhotoCandidate.fromJson(<String, dynamic>{
      'photoId': 'p2',
      'localAssetId': 'a2',
      'ownerId': 'client',
      'capturedAtMs': DateTime(2019, 8, 12).millisecondsSinceEpoch,
    });
    expect(legacy.capturedYear, 2019);
    expect(legacy.capturedMonth, 8);
  });

  test('enums cover the documented phases and modes', () {
    expect(RoundPhase.values, <RoundPhase>[
      RoundPhase.lobby,
      RoundPhase.preparing,
      RoundPhase.countdown,
      RoundPhase.guessing,
      RoundPhase.reveal,
      RoundPhase.captionWriting,
      RoundPhase.captionVoting,
      RoundPhase.captionReveal,
      RoundPhase.timelineGuessing,
      RoundPhase.timelineReveal,
      RoundPhase.extendPrompt,
      RoundPhase.podium,
    ]);
    expect(GameMode.values, <GameMode>[
      GameMode.classic,
      GameMode.captionThis,
      GameMode.timeTraveler,
      GameMode.mixedParty,
    ]);
    expect(ConnectionMode.values.length, 4);
    expect(ThemePreference.values.length, 3);
  });
}
