import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/audio/game_audio_service.dart';

void main() {
  final audio = GameAudioService.instance;

  tearDown(() async {
    audio.enabled = true;
    await audio.applyRoomRole(isHost: true, inRoom: false);
    await audio.setMusicEnabled(true);
  });

  test('the host becomes the room speaker and a guest starts silent', () async {
    await audio.applyRoomRole(isHost: true, inRoom: true);
    expect(audio.musicEnabled, isTrue);

    await audio.applyRoomRole(isHost: false, inRoom: true);
    expect(audio.musicEnabled, isFalse);
  });

  test('a guest can opt into their own soundtrack', () async {
    await audio.applyRoomRole(isHost: false, inRoom: true);
    expect(audio.musicEnabled, isFalse);
    await audio.setMusicEnabled(true);
    expect(audio.musicEnabled, isTrue);

    // Rebuilding the same room must not silently mute the guest again.
    await audio.applyRoomRole(isHost: false, inRoom: true);
    expect(audio.musicEnabled, isTrue);
  });

  test('the host can mute the room speaker', () async {
    await audio.applyRoomRole(isHost: true, inRoom: true);
    await audio.setMusicEnabled(false);
    expect(audio.musicEnabled, isFalse);
    await audio.setMusicEnabled(true);
    expect(audio.musicEnabled, isTrue);
  });

  test('the sfx and music switches stay independent', () async {
    await audio.configure(sfx: false, music: true);
    expect(audio.enabled, isFalse);
    expect(audio.musicEnabled, isTrue);
    await audio.configure(sfx: true, music: false);
    expect(audio.enabled, isTrue);
    expect(audio.musicEnabled, isFalse);
  });
}
