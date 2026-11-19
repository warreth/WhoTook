import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_contexts.dart';

/// Layered party audio: a fixed pool of tactile sound effects plus one looping
/// music bed with panic ducking.
///
/// The music policy is room-aware: the host is the room speaker by default,
/// while guests start silent and can opt into their own soundtrack from the
/// top bar. Sound-effect players are created once, never disposed mid-match,
/// which keeps iOS `AVAudioSession` stable across a whole party.
class GameAudioService {
  GameAudioService._();

  static final GameAudioService instance = GameAudioService._();

  /// Do not recreate players on taps: four fixed voices are enough for the
  /// overlapping click/whoosh/vote effects and keep Android latency low.
  static const int sfxPoolSize = 4;

  final List<AudioPlayer> _sfxPool = <AudioPlayer>[];
  int _nextSfx = 0;
  bool _initialized = false;
  Future<void>? _initializing;

  /// SFX switch. Effective music follows [roomRoleApplied].
  bool enabled = true;
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

  bool _inRoom = false;
  bool _roleIsHost = false;
  bool _userMusic = true;
  bool _hostMusicChoice = true;
  bool _guestMusicChoice = false;

  /// Effective music state: the host starts as the room speaker, a guest only
  /// plays after turning their own speaker on.
  bool get musicEnabled => _inRoom
      ? (_roleIsHost ? _hostMusicChoice : _guestMusicChoice)
      : _userMusic;

  static final bool _isTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static const double _musicVolume = 0.60;
  static const double _duckedVolume = 0.25;

  /// Configure the global session and allocate every player once. Safe to call
  /// more than once; concurrent callers share the same future.
  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      // One global AVAAudioSession for the whole process. Re-applying this
      // during a match is what used to cut iOS audio out.
      await AudioPlayer.global.setAudioContext(gameMusicContext());
      if (!_isTest) {
        for (var i = 0; i < sfxPoolSize; i++) {
          final player = AudioPlayer(playerId: 'whotook-sfx-$i');
          await player.setAudioContext(gameSfxContext());
          await player.setPlayerMode(PlayerMode.lowLatency);
          await player.setReleaseMode(ReleaseMode.stop);
          _sfxPool.add(player);
        }
        _music = AudioPlayer(playerId: 'whotook-music');
        await _music!.setReleaseMode(ReleaseMode.loop);
        await _music!.setAudioContext(gameMusicContext());
        await _music!.setPlayerMode(PlayerMode.mediaPlayer);
        _panic = AudioPlayer(playerId: 'whotook-panic');
        await _panic!.setReleaseMode(ReleaseMode.loop);
        await _panic!.setAudioContext(gameSfxContext());
        await _panic!.setPlayerMode(PlayerMode.mediaPlayer);
        await AudioPlayer.global.ensureInitialized();
      }
      _initialized = true;
    } on Object {
      // Audio is optional; a missing plugin must never stop the app.
      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _play(String asset, {double volume = 1}) async {
    if (!enabled || _isTest) return;
    await initialize();
    if (_sfxPool.isEmpty) return;
    final player = _sfxPool[_nextSfx];
    _nextSfx = (_nextSfx + 1) % _sfxPool.length;
    try {
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
  /// Apply persisted preferences. Outside a room this decides whether music
  /// plays; inside a room the room role wins but the SFX switch still applies.
  Future<void> configure({required bool sfx, required bool music}) async {
    enabled = sfx;
    _userMusic = music;
    if (!_inRoom) _guestMusicChoice = music;
    await _applyMusic();
  }

  /// Called once when the local phone enters or leaves a room. The host becomes
  /// the room speaker; guests default to silent until they tap the music
  /// toggle themselves.
  Future<void> applyRoomRole({
    required bool isHost,
    required bool inRoom,
  }) async {
    final enteringRoom = inRoom && (!_inRoom || _roleIsHost != isHost);
    _inRoom = inRoom;
    _roleIsHost = isHost;
    if (enteringRoom) {
      _hostMusicChoice = true;
      _guestMusicChoice = false;
    }
    await _applyMusic();
  }

  /// Top-bar and settings music switch. Guests toggle their own speaker;
  /// outside a room this is the home-screen soundtrack switch.
  Future<void> setMusicEnabled(bool music) async {
    _userMusic = music;
    if (_inRoom) {
      if (_roleIsHost) {
        _hostMusicChoice = music;
      } else {
        _guestMusicChoice = music;
      }
    }
    await _applyMusic();
  }

  Future<void> _applyMusic() async {
    if (musicEnabled && !_ducking) {
      await startMusic();
    } else if (!musicEnabled) {
      await stopMusic();
    }
  }

  Future<void> startMusic() async {
    if (!musicEnabled || _isTest || _musicStarting || _musicStarted) return;
    await initialize();
    final player = _music;
    if (player == null) return;
    _musicStarting = true;
    final generation = ++_musicGeneration;
    try {
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
    _panicActive = false;
    try {
      await _panic?.stop();
      await _music?.stop();
    } on Object {
      // Ignore a missing plugin.
    }
  }

  /// Final-five-second layer: a faster percussion loop under the ducked party
  /// track, then back to the normal groove.
  Future<void> setPanic(bool active) async {
    if (_panicActive == active) return;
    _panicActive = active;
    if (!musicEnabled || _isTest) return;
    await initialize();
    final player = _panic;
    if (player == null) return;
    try {
      if (active) {
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
    for (final player in _sfxPool) {
      await player.dispose();
    }
    _sfxPool.clear();
    await _panic?.dispose();
    _panic = null;
    await _music?.dispose();
    _music = null;
    _initialized = false;
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
