import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';

import '../party_pass/sound_effect.dart';

/// Buyer-only soundboard playback. Like [GameAudioService], every call is
/// fire-and-forget and a missing audio plugin never breaks a match.
class SoundboardService {
  SoundboardService._();

  static final SoundboardService instance = SoundboardService._();
  final Map<PartySound, AudioPlayer> _players = <PartySound, AudioPlayer>{};
  bool enabled = true;

  static final bool _isTest = Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> play(PartySound sound) async {
    if (!enabled || _isTest) return;
    try {
      final player = _players.putIfAbsent(
        sound,
        () => AudioPlayer(playerId: 'whotook-${sound.wireId}'),
      );
      await player.stop();
      await player.play(AssetSource('audio/${sound.asset}.wav'));
    } on Object {
      // A missing platform plugin must never break the round.
    }
  }

  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}
