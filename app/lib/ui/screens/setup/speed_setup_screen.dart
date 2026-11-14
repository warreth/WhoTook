import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/whotook_theme.dart';
import '../../../state/providers.dart';
import 'mode_setup_screen.dart';
import 'setup_scaffold.dart';

class SpeedSetupScreen extends ConsumerWidget {
  const SpeedSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final seconds = state.config.roundSeconds;
    return SetupScaffold(
      step: 2,
      title: 'Pick the pace',
      subtitle: 'How long does everyone get to guess each photo?',
      primaryLabel: 'Next: pick a mode',
      onPrimary: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ModeSetupScreen())),
      child: Column(
        children: <Widget>[
          for (final option in _SpeedOptions.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: _SpeedOption(
                option: option,
                selected: option.seconds == seconds,
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  unawaited(coordinator.setRoundSeconds(option.seconds));
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SpeedOptions {
  const _SpeedOptions({
    required this.seconds,
    required this.label,
    required this.blurb,
    required this.icon,
  });

  final int seconds;
  final String label;
  final String blurb;
  final IconData icon;

  static const List<_SpeedOptions> values = <_SpeedOptions>[
    _SpeedOptions(
      seconds: 6,
      label: 'Fast',
      blurb: 'Snap decisions. Six seconds.',
      icon: Icons.bolt_outlined,
    ),
    _SpeedOptions(
      seconds: 8,
      label: 'Normal',
      blurb: 'The party standard. Eight seconds.',
      icon: Icons.timer_outlined,
    ),
    _SpeedOptions(
      seconds: 12,
      label: 'Slow',
      blurb: 'For the big table. Twelve seconds.',
      icon: Icons.hourglass_empty,
    ),
  ];
}

class _SpeedOption extends StatelessWidget {
  const _SpeedOption({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _SpeedOptions option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Semantics(
      selected: selected,
      button: true,
      label: '${option.label}, ${option.seconds} seconds. ${option.blurb}',
      child: Material(
        color: selected ? colors.raised : colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.rCard),
          child: Container(
            height: 76,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.rCard),
              border: Border.all(
                color: selected ? colors.accent : colors.hairline,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  option.icon,
                  size: 22,
                  color: selected ? colors.accent : colors.ink2,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        option.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option.blurb,
                        style: TextStyle(fontSize: 12, color: colors.ink2),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${option.seconds}s',
                  style: tabularFigures(
                    TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: selected ? colors.accent : colors.ink2,
                    ),
                  ),
                ),
                if (selected) ...<Widget>[
                  const SizedBox(width: AppSpacing.s8),
                  Icon(Icons.check, size: 18, color: colors.accent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
