import 'dart:math';

import '../core/models/models.dart';

/// Balanced bag shuffle for Mixed Party.
///
/// Every enabled core mode appears as evenly as the round count allows. At
/// every position the most frequent remaining mode is chosen, with random ties
/// and the previous mode excluded. That is a deterministic constraint repair:
/// for balanced counts (max <= all other counts + 1) it cannot create two equal
/// neighbours, and it never skips an enabled mode in matches of two or more
/// rounds.
List<GameMode> balancedMixedPartyModes(
  int rounds,
  Random random, {
  GameMode? previous,
  Set<GameMode> enabled = MatchConfig.coreMixedModes,
}) {
  if (rounds <= 0) return const <GameMode>[];
  final ordered = <GameMode>[
    for (final mode in const <GameMode>[
      GameMode.classic,
      GameMode.zoomOut,
      GameMode.makeItMeme,
      GameMode.photoSabotage,
      GameMode.timeTraveler,
    ])
      if (enabled.contains(mode)) mode,
  ];
  // Never produce an empty or single-mode Mixed Party queue. The UI prevents
  // this, but a malformed wire config or an old client must still play.
  final modes = ordered.length >= 2
      ? ordered
      : MatchConfig.coreMixedModes.toList();
  if (rounds < modes.length) {
    final pool = List<GameMode>.of(modes)..shuffle(random);
    if (previous != null) {
      final alternative = pool.where((mode) => mode != previous).toList();
      if (alternative.length >= rounds) {
        return alternative.take(rounds).toList();
      }
    }
    return pool.take(rounds).toList();
  }

  final counts = <GameMode, int>{
    for (final mode in modes) mode: rounds ~/ modes.length,
  };
  // Remainders go to Classic first, then Make It Meme, then Time Traveler.
  // With two enabled modes the classic half gets the odd round.
  for (var i = 0; i < rounds % modes.length; i++) {
    counts[modes[i]] = counts[modes[i]]! + 1;
  }

  final result = <GameMode>[];
  var last = previous;
  while (result.length < rounds) {
    final available = modes.where((mode) => counts[mode]! > 0).toList();
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
