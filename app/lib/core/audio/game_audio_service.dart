import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Small, optional sound and haptic layer. Every call is fire-and-forget and
/// safely ignores a missing audio plugin, which keeps widget tests quiet.
class GameAudioService {
  GameAudioService._();

  static final GameAudioService instance = GameAudioService._();
  final Map<String, AudioPlayer> _players = <String, AudioPlayer>{};
  bool enabled = true;

  static final bool _isTest = Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> _play(String asset) async {
    if (!enabled || _isTest) return;
    try {
      final player = _players.putIfAbsent(
        asset,
        () => AudioPlayer(playerId: 'whotook-$asset'),
      );
      await player.stop();
      await player.play(AssetSource('audio/$asset.wav'));
    } on Object {
      // A missing platform plugin must never break a match.
    }
  }

  Future<void> tap() => _play('tap');
  Future<void> pop() => _play('pop');
  Future<void> ding() => _play('ding');
  Future<void> meh() => _play('meh');
  Future<void> bad() => _play('boom');
  Future<void> tick() => _play('tick');
  Future<void> fanfare() => _play('fanfare');

  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}

/// Haptics with one switch for the whole game.
class GameHaptics {
  GameHaptics._();

  static final GameHaptics instance = GameHaptics._();
  bool enabled = true;

  Future<void> selection() async {
    if (!enabled) return;
    try {
      await HapticFeedback.selectionClick();
    } on Object {
      // Haptics are best-effort.
    }
  }

  Future<void> light() async {
    if (!enabled) return;
    try {
      await HapticFeedback.lightImpact();
    } on Object {
      // Haptics are best-effort.
    }
  }

  Future<void> heavy() async {
    if (!enabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } on Object {
      // Haptics are best-effort.
    }
  }
}
