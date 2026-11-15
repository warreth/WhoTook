import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/providers.dart';
import '../../widgets/mode_picker.dart';
import 'rounds_setup_screen.dart';
import 'setup_scaffold.dart';

class ModeSetupScreen extends ConsumerWidget {
  const ModeSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    return SetupScaffold(
      step: 1,
      title: context.l10n.chooseGame,
      subtitle: context.l10n.chooseGameSubtitle,
      primaryLabel: context.l10n.nextRounds,
      onPrimary: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const RoundsSetupScreen()),
      ),
      child: ModePicker(
        mode: state.config.mode,
        onSelect: (mode) => unawaited(coordinator.setMode(mode)),
      ),
    );
  }
}
