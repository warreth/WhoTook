import 'dart:math';

import '../core/models/models.dart';

/// Balanced bag shuffle for Mixed Party.
///
/// Every core mode appears as evenly as the round count allows. At every
/// position the most frequent remaining mode is chosen, with random ties and
/// the previous mode excluded. That is a deterministic constraint repair: for
/// balanced counts (max <= all other counts + 1) it cannot create two equal
/// neighbours, and it never skips a mode in matches of three or more rounds.
List<GameMode> balancedMixedPartyModes(
  int rounds,
  Random random, {
  GameMode? previous,
}) {
  if (rounds <= 0) return const <GameMode>[];
  const core = <GameMode>[
    GameMode.classic,
    GameMode.makeItMeme,
    GameMode.timeTraveler,
  ];
  if (rounds < core.length) {
    final pool = List<GameMode>.of(core)..shuffle(random);
    if (previous != null) {
      final alternative = pool.where((mode) => mode != previous).toList();
      if (alternative.length >= rounds) {
        return alternative.take(rounds).toList();
      }
    }
    return pool.take(rounds).toList();
  }

  final counts = <GameMode, int>{
    for (final mode in core) mode: rounds ~/ core.length,
  };
  final remainder = List<GameMode>.of(core)..shuffle(random);
  for (var i = 0; i < rounds % core.length; i++) {
    counts[remainder[i]] = counts[remainder[i]]! + 1;
  }

  final result = <GameMode>[];
  var last = previous;
  while (result.length < rounds) {
    final available = core.where((mode) => counts[mode]! > 0).toList();
    if (available.isEmpty) break;
    final withoutLast = available.where((mode) => mode != last).toList();
    final choices = withoutLast.isEmpty ? available : withoutLast;
    final most = choices
        .map((mode) => counts[mode]!)
        .reduce((a, b) => a > b ? a : b);
    final best = choices.where((mode) => counts[mode] == most).toList();
    final next = best[random.nextInt(best.length)];
    result.add(next);
    counts[next] = counts[next]! - 1;
    last = next;
  }
  return result;
}
