import 'package:audioplayers/audioplayers.dart';

/// Android gives audio focus per player. A short click must never steal focus
/// from the looping music bed, so SFX request no focus at all. Music keeps the
/// game usage type but owns focus for the room.
AudioContext gameSfxContext() => AudioContext(
  android: const AudioContextAndroid(
    usageType: AndroidUsageType.game,
    contentType: AndroidContentType.sonification,
    audioFocus: AndroidAudioFocus.none,
    stayAwake: false,
  ),
  // iOS uses the same playback category as music: an ambient SFX session
  // would silence the whole game when the Ring/Silent switch is on and can
  // reconfigure AVAudioSession away from the music session.
  iOS: AudioContextIOS(
    category: AVAudioSessionCategory.playback,
    options: <AVAudioSessionOptions>{AVAudioSessionOptions.mixWithOthers},
  ),
);

AudioContext gameMusicContext() => AudioContext(
  android: const AudioContextAndroid(
    usageType: AndroidUsageType.game,
    contentType: AndroidContentType.music,
    audioFocus: AndroidAudioFocus.gain,
    stayAwake: false,
  ),
  iOS: AudioContextIOS(
    category: AVAudioSessionCategory.playback,
    options: <AVAudioSessionOptions>{AVAudioSessionOptions.mixWithOthers},
  ),
);
