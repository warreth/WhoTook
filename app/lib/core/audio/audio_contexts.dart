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
  iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
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
