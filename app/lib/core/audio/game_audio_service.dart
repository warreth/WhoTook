import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_contexts.dart';

/// Layered party audio: short tactile effects plus a looping music bed with
/// panic ducking. Every call is fire-and-forget and safely ignores a missing
/// audio plugin, which keeps widget tests quiet.
class GameAudioService {
  GameAudioService._();

  static final GameAudioService instance = GameAudioService._();
  final Map<String, AudioPlayer> _players = <String, AudioPlayer>{};
  final Set<String> _configuredSfx = <String>{};

  /// SFX switch. Music has its own switch next to it.
  bool enabled = true;
  bool musicEnabled = true;
  bool get isSfxMuted => !enabled;
  set isSfxMuted(bool muted) => enabled = !muted;

  AudioPlayer? _music;
  AudioPlayer? _panic;
  bool _panicActive = false;
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
  static const String musicTrackId = 'party_loop_60';
  static const Duration musicTrackDuration = Duration(seconds: 60);

  DateTime? _trackStartedAt;
  GameMusicTrack? _remoteTrack;
  void Function(GameMusicTrack track)? onHostTrackStarted;
  int _hostOffsetMs = 0;
  int? _lastSeekHostMs;

  int get hostTimeOffsetMs => _hostOffsetMs;

  Future<void> _play(String asset, {double volume = 1}) async {
    if (!enabled || _isTest) return;
    try {
      final player = _players.putIfAbsent(
        asset,
        () => AudioPlayer(playerId: 'whotook-$asset'),
      );
      if (_configuredSfx.add(asset)) {
        await player.setAudioContext(gameSfxContext());
        await player.setPlayerMode(PlayerMode.lowLatency);
      }
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
      await player.setAudioContext(gameMusicContext());
      await player.setPlayerMode(PlayerMode.mediaPlayer);
      await player.setVolume(_ducking ? _duckedVolume : _musicVolume);
      _musicLevel = _ducking ? _duckedVolume : _musicVolume;
      _trackStartedAt ??= DateTime.now();
      await player.play(AssetSource('audio/party_loop.mp3'));
      if (_remoteTrack != null) {
        await _seekToRemoteTrack(force: true);
      } else {
        final anchor = _trackStartedAt;
        if (anchor != null) {
          final elapsed =
              (DateTime.now().millisecondsSinceEpoch -
                  anchor.millisecondsSinceEpoch) %
              musicTrackDuration.inMilliseconds;
          if (elapsed > 300) {
            await player.seek(Duration(milliseconds: elapsed));
          }
        }
      }
      if (generation != _musicGeneration || !musicEnabled) {
        await player.stop();
        return;
      }
      _musicStarted = true;
      final callback = onHostTrackStarted;
      if (callback != null) callback(hostTrackInfo());
    } on Object {
      // Music is optional; the game must play without audio.
    } finally {
      _musicStarting = false;
    }
  }

  Future<void> stopMusic() async {
    _musicGeneration++;
    _musicStarted = false;
    _trackStartedAt = null;
    _lastSeekHostMs = null;
    _panicActive = false;
    try {
      await _panic?.stop();
      await _music?.stop();
    } on Object {
      // Ignore a missing plugin.
    }
  }

  GameMusicTrack hostTrackInfo() {
    final start = _trackStartedAt ??= DateTime.now();
    return GameMusicTrack(
      trackId: musicTrackId,
      hostStartMs: start.millisecondsSinceEpoch,
      durationMs: musicTrackDuration.inMilliseconds,
    );
  }

  /// Hosts call this once when a room opens. It returns the exact loop anchor
  /// that every client should seek to.
  Future<GameMusicTrack> startHostTrack() async {
    if (!_isTest && musicEnabled && !_musicStarted) await startMusic();
    return hostTrackInfo();
  }

  void setHostOffsetMs(int offsetMs) {
    _hostOffsetMs = offsetMs;
    if (_remoteTrack != null) {
      unawaited(_seekToRemoteTrack());
    }
  }

  /// Clients call this with the host's loop anchor. The elapsed position is
  /// computed with the measured clock offset so every phone lands on the same
  /// beat, even when it joins late.
  Future<void> syncToTrack(GameMusicTrack track, {int? offsetMs}) async {
    _remoteTrack = track;
    if (offsetMs != null) _hostOffsetMs = offsetMs;
    if (!musicEnabled || _isTest) return;
    if (!_musicStarted) await startMusic();
    await _seekToRemoteTrack(force: true);
  }

  Future<void> _seekToRemoteTrack({bool force = false}) async {
    final track = _remoteTrack;
    final player = _music;
    if (track == null || player == null || track.durationMs <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch + _hostOffsetMs;
    final elapsed = (now - track.hostStartMs) % track.durationMs;
    final last = _lastSeekHostMs;
    if (!force && last != null && (now - last).abs() < 180 && elapsed >= 0) {
      return;
    }
    _lastSeekHostMs = now;
    try {
      await player.seek(Duration(milliseconds: elapsed));
      if (force) await player.resume();
    } on Object {
      // Syncing is best-effort; the loop keeps playing from wherever it is.
    }
  }

  /// Final-five-second layer: a faster percussion loop under the ducked
  /// party track, then back to the normal groove.
  Future<void> setPanic(bool active) async {
    if (_panicActive == active) return;
    _panicActive = active;
    if (!musicEnabled || _isTest) return;
    try {
      final player = _panic ??= AudioPlayer(playerId: 'whotook-panic');
      if (active) {
        await player.setReleaseMode(ReleaseMode.loop);
        await player.setAudioContext(gameSfxContext());
        await player.setPlayerMode(PlayerMode.mediaPlayer);
        await player.setVolume(0.38);
        await player.play(AssetSource('audio/panic_loop.mp3'));
      } else {
        await player.stop();
      }
    } on Object {
      // The panic layer is optional.
    }
    await setDucking(active);
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
    _remoteTrack = null;
    _trackStartedAt = null;
    await _panic?.dispose();
    _panic = null;
    await _music?.dispose();
    _music = null;
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}

class GameMusicTrack {
  const GameMusicTrack({
    required this.trackId,
    required this.hostStartMs,
    required this.durationMs,
  });

  final String trackId;
  final int hostStartMs;
  final int durationMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'trackId': trackId,
    'hostTrackStartTimestampMs': hostStartMs,
    'trackDurationMs': durationMs,
  };

  factory GameMusicTrack.fromJson(Map<String, dynamic> json) => GameMusicTrack(
    trackId: json['trackId'] as String? ?? GameAudioService.musicTrackId,
    hostStartMs:
        (json['hostTrackStartTimestampMs'] as int?) ??
        (json['hostStartMs'] as int?) ??
        0,
    durationMs:
        (json['trackDurationMs'] as int?) ??
        (json['durationMs'] as int?) ??
        GameAudioService.musicTrackDuration.inMilliseconds,
  );
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
