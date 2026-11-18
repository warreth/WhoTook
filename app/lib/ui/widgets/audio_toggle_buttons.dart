import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/game_audio_service.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';

/// Two persistent 44 px switches shared by the home header, lobby and
/// settings. Music and SFX are deliberately separate.
class AudioToggleButtons extends ConsumerWidget {
  const AudioToggleButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).value;
    final sfx = settings?.soundEnabled ?? true;
    final music = settings?.musicEnabled ?? true;
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: l10n.music,
          onPressed: () {
            final next = !music;
            unawaited(
              ref
                  .read(appSettingsProvider.notifier)
                  .apply((value) => value.copyWith(musicEnabled: next)),
            );
            unawaited(
              GameAudioService.instance.configure(sfx: sfx, music: next),
            );
          },
          icon: Icon(music ? Icons.music_note : Icons.music_off),
        ),
        IconButton(
          tooltip: l10n.soundEffects,
          onPressed: () {
            final next = !sfx;
            unawaited(
              ref
                  .read(appSettingsProvider.notifier)
                  .apply((value) => value.copyWith(soundEnabled: next)),
            );
            GameAudioService.instance.isSfxMuted = !next;
            if (next) unawaited(GameAudioService.instance.tapUp());
          },
          icon: Icon(
            sfx ? Icons.volume_up_outlined : Icons.volume_off_outlined,
          ),
        ),
      ],
    );
  }
}
