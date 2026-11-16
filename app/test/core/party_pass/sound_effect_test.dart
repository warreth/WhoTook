import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/party_pass/sound_effect.dart';

void main() {
  test('wire ids are unique and parse back', () {
    final ids = PartySound.values.map((sound) => sound.wireId).toSet();
    expect(ids.length, PartySound.values.length);
    for (final sound in PartySound.values) {
      expect(PartySound.fromWire(sound.wireId), sound);
    }
    expect(PartySound.fromWire('nope'), isNull);
  });

  test('the gate allows one sound every three seconds', () {
    var now = DateTime.utc(2026, 11, 16, 12);
    final gate = SoundboardGate(clock: () => now);

    expect(gate.tryPlay('host'), isTrue);
    expect(gate.tryPlay('host'), isFalse);
    expect(gate.remaining('host'), const Duration(seconds: 3));

    now = now.add(const Duration(seconds: 2));
    expect(gate.tryPlay('host'), isFalse);
    expect(gate.remaining('host'), const Duration(seconds: 1));

    now = now.add(const Duration(seconds: 1));
    expect(gate.tryPlay('host'), isTrue);
    expect(gate.remaining('host'), const Duration(seconds: 3));
  });

  test('cooldowns are per player', () {
    var now = DateTime.utc(2026, 11, 16, 12);
    final gate = SoundboardGate(clock: () => now);
    expect(gate.tryPlay('host'), isTrue);
    expect(gate.tryPlay('p2'), isTrue);
    expect(gate.remaining('host'), const Duration(seconds: 3));
    expect(gate.remaining('p2'), const Duration(seconds: 3));
    gate.clear();
    expect(gate.tryPlay('host'), isTrue);
  });

  test('a broadcast event serializes only the sound id and sender', () {
    const event = SoundEffectEvent(
      playerId: 'p2',
      playerName: 'Lotte',
      sound: PartySound.airhorn,
      atMs: 123,
    );
    expect(event.toJson(), <String, dynamic>{
      'id': 'airhorn',
      'playerId': 'p2',
      'playerName': 'Lotte',
    });
    final parsed = SoundEffectEvent.fromJson(event.toJson(), atMs: 456);
    expect(parsed.sound, PartySound.airhorn);
    expect(parsed.playerName, 'Lotte');
    expect(parsed.atMs, 456);
  });
}
