import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/engine/mixed_party_shuffle.dart';

void main() {
  test('mixed party queues are balanced and never repeat a neighbour', () {
    const core = <GameMode>[
      GameMode.classic,
      GameMode.zoomOut,
      GameMode.makeItMeme,
      GameMode.photoSabotage,
      GameMode.timeTraveler,
    ];
    for (final rounds in <int>[3, 5, 6, 10, 15]) {
      for (var seed = 0; seed < 1000; seed++) {
        final queue = balancedMixedPartyModes(rounds, Random(seed));
        expect(queue, hasLength(rounds), reason: 'seed $seed rounds $rounds');
        if (rounds >= core.length) {
          expect(
            queue.toSet(),
            containsAll(core),
            reason: 'seed $seed rounds $rounds must contain every mode',
          );
        } else {
          expect(queue.toSet(), hasLength(rounds));
        }
        for (var i = 1; i < queue.length; i++) {
          expect(
            queue[i] == queue[i - 1],
            isFalse,
            reason: 'seed $seed rounds $rounds repeated at $i',
          );
        }
        final counts = <GameMode, int>{
          for (final mode in core) mode: queue.where((m) => m == mode).length,
        };
        final maxCount = counts.values.reduce(max);
        final minCount = counts.values.reduce(min);
        expect(maxCount - minCount, lessThanOrEqualTo(1));
      }
    }
  });

  test('remainders go to Classic first', () {
    const three = <GameMode>{
      GameMode.classic,
      GameMode.makeItMeme,
      GameMode.timeTraveler,
    };
    final ten = balancedMixedPartyModes(10, Random(3), enabled: three);
    expect(ten.where((mode) => mode == GameMode.classic), hasLength(4));
    expect(ten.where((mode) => mode == GameMode.makeItMeme), hasLength(3));
    expect(ten.where((mode) => mode == GameMode.timeTraveler), hasLength(3));
    final eleven = balancedMixedPartyModes(11, Random(4), enabled: three);
    expect(eleven.where((mode) => mode == GameMode.classic), hasLength(4));
    expect(eleven.where((mode) => mode == GameMode.makeItMeme), hasLength(4));
    expect(eleven.where((mode) => mode == GameMode.timeTraveler), hasLength(3));
  });

  test('all five modes share an even schedule', () {
    final ten = balancedMixedPartyModes(10, Random(7));
    for (final mode in MatchConfig.coreMixedModes) {
      expect(ten.where((candidate) => candidate == mode), hasLength(2));
    }
    final eleven = balancedMixedPartyModes(11, Random(8));
    expect(eleven.where((mode) => mode == GameMode.classic), hasLength(3));
  });

  test('short queues use distinct modes when possible', () {
    expect(balancedMixedPartyModes(1, Random(1)), hasLength(1));
    final two = balancedMixedPartyModes(2, Random(2));
    expect(two, hasLength(2));
    expect(two[0], isNot(two[1]));
  });

  test('two enabled modes stay balanced and never repeat a neighbour', () {
    const pairs = <Set<GameMode>>[
      <GameMode>{GameMode.classic, GameMode.makeItMeme},
      <GameMode>{GameMode.classic, GameMode.timeTraveler},
      <GameMode>{GameMode.makeItMeme, GameMode.timeTraveler},
    ];
    for (final enabled in pairs) {
      for (final rounds in <int>[5, 6, 10, 11]) {
        for (var seed = 0; seed < 300; seed++) {
          final queue = balancedMixedPartyModes(
            rounds,
            Random(seed),
            enabled: enabled,
          );
          expect(queue, hasLength(rounds));
          expect(queue.toSet(), enabled);
          final counts = <GameMode, int>{
            for (final mode in enabled)
              mode: queue.where((m) => m == mode).length,
          };
          final maxCount = counts.values.reduce(max);
          final minCount = counts.values.reduce(min);
          expect(maxCount - minCount, lessThanOrEqualTo(1));
          for (var i = 1; i < queue.length; i++) {
            expect(queue[i], isNot(queue[i - 1]));
          }
        }
      }
    }
  });

  test('the odd round goes to Classic when it is enabled', () {
    final queue = balancedMixedPartyModes(
      11,
      Random(9),
      enabled: <GameMode>{GameMode.classic, GameMode.makeItMeme},
    );
    expect(queue.where((mode) => mode == GameMode.classic), hasLength(6));
    expect(queue.where((mode) => mode == GameMode.makeItMeme), hasLength(5));
  });

  test('a malformed enabled set still produces a playable schedule', () {
    final queue = balancedMixedPartyModes(
      6,
      Random(4),
      enabled: <GameMode>{GameMode.classic},
    );
    expect(queue.toSet(), containsAll(MatchConfig.coreMixedModes));
  });

  test('a continued queue never repeats the previous mode', () {
    for (var seed = 0; seed < 200; seed++) {
      final first = balancedMixedPartyModes(6, Random(seed));
      final second = balancedMixedPartyModes(
        6,
        Random(seed + 1000),
        previous: first.last,
      );
      expect(second.first, isNot(first.last));
      for (var i = 1; i < second.length; i++) {
        expect(second[i], isNot(second[i - 1]));
      }
    }
  });
}
