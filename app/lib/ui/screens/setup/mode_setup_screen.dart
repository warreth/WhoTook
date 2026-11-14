import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/providers.dart';
import '../../widgets/mode_picker.dart';
import 'host_photos_screen.dart';
import 'setup_scaffold.dart';

class ModeSetupScreen extends ConsumerWidget {
  const ModeSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    return SetupScaffold(
      step: 3,
      title: 'Choose the game',
      subtitle: 'Classic, Caption This, Time Traveler or a bit of everything.',
      primaryLabel: 'Next: your photos',
      onPrimary: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const HostPhotosScreen())),
      child: ModePicker(
        mode: state.config.mode,
        onSelect: (mode) => unawaited(coordinator.setMode(mode)),
      ),
    );
  }
}
