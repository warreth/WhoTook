import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/whotook_theme.dart';
import '../../../state/providers.dart';
import 'setup_scaffold.dart';
import 'speed_setup_screen.dart';

class RoundsSetupScreen extends ConsumerWidget {
  const RoundsSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final rounds = state.config.roundsK;
    return SetupScaffold(
      step: 2,
      title: 'How many rounds?',
      subtitle: 'Short and sharp. You can always add five more at the podium.',
      primaryLabel: 'Next: pick the pace',
      onPrimary: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SpeedSetupScreen())),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.s12,
        crossAxisSpacing: AppSpacing.s12,
        childAspectRatio: 1.12,
        children: <Widget>[
          for (final option in _RoundOptions.values)
            _RoundOption(
              option: option,
              selected: option.rounds == rounds,
              onTap: () {
                unawaited(HapticFeedback.selectionClick());
                unawaited(coordinator.setRounds(option.rounds));
              },
            ),
        ],
      ),
    );
  }
}

class _RoundOptions {
  const _RoundOptions(this.rounds, this.blurb);

  final int rounds;
  final String blurb;

  static const List<_RoundOptions> values = <_RoundOptions>[
    _RoundOptions(5, 'Quick game'),
    _RoundOptions(10, 'Party size'),
    _RoundOptions(15, 'Long table'),
    _RoundOptions(20, 'All nighter'),
  ];
}

class _RoundOption extends StatelessWidget {
  const _RoundOption({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _RoundOptions option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Semantics(
      selected: selected,
      button: true,
      label: '${option.rounds} rounds. ${option.blurb}.',
      child: Material(
        color: selected ? colors.raised : colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.rCard),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.rCard),
              border: Border.all(
                color: selected ? colors.accent : colors.hairline,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${option.rounds}',
                  style: tabularFigures(
                    TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 38,
                      fontWeight: FontWeight.w500,
                      height: 1,
                      color: selected ? colors.accent : colors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'rounds',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.ink2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  option.blurb,
                  style: TextStyle(fontSize: 11, color: colors.ink3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
