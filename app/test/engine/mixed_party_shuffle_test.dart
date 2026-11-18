import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/engine/mixed_party_shuffle.dart';

void main() {
  test('mixed party queues are balanced and never repeat a neighbour', () {
    const core = <GameMode>[
      GameMode.classic,
      GameMode.makeItMeme,
      GameMode.timeTraveler,
    ];
    for (final rounds in <int>[3, 5, 6, 10, 15]) {
      for (var seed = 0; seed < 1000; seed++) {
        final queue = balancedMixedPartyModes(rounds, Random(seed));
        expect(queue, hasLength(rounds), reason: 'seed $seed rounds $rounds');
        expect(
          queue.toSet(),
          containsAll(core),
          reason: 'seed $seed rounds $rounds must contain every mode',
        );
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
    final ten = balancedMixedPartyModes(10, Random(3));
    expect(ten.where((mode) => mode == GameMode.classic), hasLength(4));
    expect(ten.where((mode) => mode == GameMode.makeItMeme), hasLength(3));
    expect(ten.where((mode) => mode == GameMode.timeTraveler), hasLength(3));
    final eleven = balancedMixedPartyModes(11, Random(4));
    expect(eleven.where((mode) => mode == GameMode.classic), hasLength(4));
    expect(eleven.where((mode) => mode == GameMode.makeItMeme), hasLength(4));
    expect(eleven.where((mode) => mode == GameMode.timeTraveler), hasLength(3));
  });

  test('short queues use distinct modes when possible', () {
    expect(balancedMixedPartyModes(1, Random(1)), hasLength(1));
    final two = balancedMixedPartyModes(2, Random(2));
    expect(two, hasLength(2));
    expect(two[0], isNot(two[1]));
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
