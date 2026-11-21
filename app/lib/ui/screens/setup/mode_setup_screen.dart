import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/whotook_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/mode_picker.dart';
import 'rounds_setup_screen.dart';
import 'setup_scaffold.dart';

class ModeSetupScreen extends ConsumerWidget {
  const ModeSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final l10n = context.l10n;
    return SetupScaffold(
      step: 1,
      title: l10n.chooseGame,
      subtitle: l10n.chooseGameSubtitle,
      primaryLabel: l10n.nextRounds,
      onPrimary: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const RoundsSetupScreen()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ModePicker(
            mode: state.config.mode,
            onSelect: (mode) => unawaited(coordinator.setMode(mode)),
          ),
          if (state.config.mode == GameMode.mixedParty) ...<Widget>[
            const SizedBox(height: AppSpacing.s20),
            SectionLabel(l10n.mixedModesLabel),
            const SizedBox(height: AppSpacing.s4),
            Text(
              l10n.mixedModesHint,
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: AppSpacing.s12),
            MixedModePicker(
              selected: state.config.activeMixedModes,
              onChanged: (modes) => unawaited(coordinator.setMixedModes(modes)),
            ),
          ],
        ],
      ),
    );
  }
}
