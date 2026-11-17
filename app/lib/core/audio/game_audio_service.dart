import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Layered party audio: short tactile effects plus a looping music bed with
/// panic ducking. Every call is fire-and-forget and safely ignores a missing
/// audio plugin, which keeps widget tests quiet.
class GameAudioService {
  GameAudioService._();

  static final GameAudioService instance = GameAudioService._();
  final Map<String, AudioPlayer> _players = <String, AudioPlayer>{};

  /// SFX switch. Music has its own switch next to it.
  bool enabled = true;
  bool musicEnabled = true;

  AudioPlayer? _music;
  Timer? _duckTimer;
  bool _ducking = false;
  int _fadeGeneration = 0;
  bool _musicStarting = false;
  bool _musicStarted = false;
  int _musicGeneration = 0;
  double _musicLevel = _musicVolume;

  static final bool _isTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static const double _musicVolume = 0.60;
  static const double _duckedVolume = 0.25;

  Future<void> _play(String asset, {double volume = 1}) async {
    if (!enabled || _isTest) return;
    try {
      final player = _players.putIfAbsent(
        asset,
        () => AudioPlayer(playerId: 'whotook-$asset'),
      );
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource('audio/$asset.wav'));
    } on Object {
      // A missing platform plugin must never break a match.
    }
  }

  // Tactile controls -------------------------------------------------------
  Future<void> tapDown() => _play('click_down');
  Future<void> tapUp() => _play('click_up');
  Future<void> tap() => tapUp();

  Future<void> swap() async {
    await Future.wait(<Future<void>>[
      _play('whoosh'),
      _play('click_up', volume: 0.55),
    ]);
  }

  Future<void> pop() => _play('pop');

  Future<void> ding() async {
    unawaited(duckFor(const Duration(milliseconds: 900)));
    await _play('ding');
  }

  Future<void> meh() => _play('meh');
  Future<void> bad() => _play('boom');
  Future<void> tick() => _play('tick_hard');
  Future<void> heartbeat() => _play('heartbeat');

  Future<void> voteUp() async {
    await Future.wait(<Future<void>>[
      _play('vote_up'),
      _play('ding', volume: 0.30),
    ]);
  }

  Future<void> voteMeh() => _play('vote_meh');
  Future<void> voteDown() => _play('vote_down');

  Future<void> fanfare() async {
    unawaited(duckFor(const Duration(seconds: 2)));
    await Future.wait(<Future<void>>[
      _play('fanfare_win'),
      _play('pop', volume: 0.55),
    ]);
  }

  // Music bed --------------------------------------------------------------
  Future<void> configure({required bool sfx, required bool music}) async {
    enabled = sfx;
    musicEnabled = music;
    if (music) {
      await startMusic();
    } else {
      await stopMusic();
    }
  }

  Future<void> startMusic() async {
    if (!musicEnabled || _isTest || _musicStarting || _musicStarted) return;
    _musicStarting = true;
    final generation = ++_musicGeneration;
    try {
      final player = _music ??= AudioPlayer(playerId: 'whotook-music');
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_ducking ? _duckedVolume : _musicVolume);
      _musicLevel = _ducking ? _duckedVolume : _musicVolume;
      await player.play(AssetSource('audio/party_loop.mp3'));
      if (generation != _musicGeneration || !musicEnabled) {
        await player.stop();
        return;
      }
      _musicStarted = true;
    } on Object {
      // Music is optional; the game must play without audio.
    } finally {
      _musicStarting = false;
    }
  }

  Future<void> stopMusic() async {
    _musicGeneration++;
    _musicStarted = false;
    try {
      await _music?.stop();
    } on Object {
      // Ignore a missing plugin.
    }
  }

  /// Duck the music while the panic timer or a reveal effect needs the stage.
  Future<void> setDucking(bool ducked) async {
    if (_ducking == ducked) return;
    _ducking = ducked;
    _duckTimer?.cancel();
    if (!musicEnabled || _isTest) return;
    final target = ducked ? _duckedVolume : _musicVolume;
    final generation = ++_fadeGeneration;
    final player = _music;
    if (player == null) return;
    const steps = 10;
    final from = _musicLevel;
    for (var i = 1; i <= steps; i++) {
      if (generation != _fadeGeneration) return;
      final value = from + (target - from) * (i / steps);
      _musicLevel = value;
      try {
        await player.setVolume(value.clamp(0, 1));
      } on Object {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 45));
    }
  }

  Future<void> duckFor(Duration duration) async {
    if (_isTest) return;
    await setDucking(true);
    _duckTimer?.cancel();
    _duckTimer = Timer(duration, () {
      unawaited(setDucking(false));
    });
  }

  Future<void> dispose() async {
    _duckTimer?.cancel();
    _musicStarted = false;
    await _music?.dispose();
    _music = null;
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
