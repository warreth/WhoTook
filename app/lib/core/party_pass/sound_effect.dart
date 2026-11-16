import '../../l10n/l10n.dart';

/// The six buyer-only sounds. The wire only carries [wireId], never audio.
enum PartySound {
  vineBoom(wireId: 'vine_boom', asset: 'soundboard_vine_boom'),
  airhorn(wireId: 'airhorn', asset: 'soundboard_airhorn'),
  crickets(wireId: 'crickets', asset: 'soundboard_crickets'),
  sadTrombone(wireId: 'sad_trombone', asset: 'soundboard_sad_trombone'),
  drumroll(wireId: 'drumroll', asset: 'soundboard_drumroll'),
  laughTrack(wireId: 'laugh_track', asset: 'soundboard_laugh_track');

  const PartySound({required this.wireId, required this.asset});

  final String wireId;

  /// File name without `.wav` under `assets/audio/`.
  final String asset;

  static PartySound? fromWire(String? id) {
    for (final sound in PartySound.values) {
      if (sound.wireId == id) return sound;
    }
    return null;
  }
}

String partySoundLabel(AppLocalizations l10n, PartySound sound) =>
    switch (sound) {
      PartySound.vineBoom => l10n.soundVineBoom,
      PartySound.airhorn => l10n.soundAirhorn,
      PartySound.crickets => l10n.soundCrickets,
      PartySound.sadTrombone => l10n.soundSadTrombone,
      PartySound.drumroll => l10n.soundDrumroll,
      PartySound.laughTrack => l10n.soundLaughTrack,
    };

/// One broadcast sound event. [atMs] is local wall-clock time and only keys the
/// toast animation; it never leaves the device.
class SoundEffectEvent {
  const SoundEffectEvent({
    required this.playerId,
    required this.playerName,
    required this.sound,
    required this.atMs,
  });

  final String playerId;
  final String playerName;
  final PartySound sound;
  final int atMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': sound.wireId,
    'playerId': playerId,
    'playerName': playerName,
  };

  factory SoundEffectEvent.fromJson(
    Map<String, dynamic> json, {
    required int atMs,
  }) => SoundEffectEvent(
    playerId: json['playerId'] as String? ?? '',
    playerName: json['playerName'] as String? ?? '',
    sound:
        PartySound.fromWire(json['id'] as String?) ?? PartySound.vineBoom,
    atMs: atMs,
  );

  SoundEffectEvent copyWith({int? atMs}) => SoundEffectEvent(
    playerId: playerId,
    playerName: playerName,
    sound: sound,
    atMs: atMs ?? this.atMs,
  );
}

/// Per-player 3 second anti-spam gate. The host enforces it for remote events
/// and the buyer's own phone enforces it before sending.
class SoundboardGate {
  SoundboardGate({
    this.cooldown = const Duration(seconds: 3),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration cooldown;
  final DateTime Function() _clock;
  final Map<String, DateTime> _lastPlayed = <String, DateTime>{};

  bool canPlay(String playerId) {
    final last = _lastPlayed[playerId];
    if (last == null) return true;
    return _clock().difference(last) >= cooldown;
  }

  bool tryPlay(String playerId) {
    if (!canPlay(playerId)) return false;
    _lastPlayed[playerId] = _clock();
    return true;
  }

  Duration remaining(String playerId) {
    final last = _lastPlayed[playerId];
    if (last == null) return Duration.zero;
    final elapsed = _clock().difference(last);
    if (elapsed >= cooldown) return Duration.zero;
    return cooldown - elapsed;
  }

  void clear() => _lastPlayed.clear();
}
