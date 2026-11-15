import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/whotook_theme.dart';
import '../../../state/providers.dart';
import 'setup_scaffold.dart';

class SpeedSetupScreen extends ConsumerStatefulWidget {
  const SpeedSetupScreen({super.key});

  @override
  ConsumerState<SpeedSetupScreen> createState() => _SpeedSetupScreenState();
}

class _SpeedSetupScreenState extends ConsumerState<SpeedSetupScreen> {
  bool _opening = false;

  Future<void> _openRoom() async {
    if (_opening) return;
    final coordinator = ref.read(matchCoordinatorProvider);
    final current = ref.read(matchStateProvider).value ?? coordinator.state;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _opening = true);
    await coordinator.hostMatch(config: current.config);
    if (!mounted) return;
    final next = coordinator.state;
    if (next.roomId == null || next.errorMessage != null) {
      setState(() => _opening = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(next.errorMessage ?? 'Could not open the room.'),
        ),
      );
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final mode = state.config.mode;
    return SetupScaffold(
      step: 3,
      title: 'Pick the pace',
      subtitle: _subtitle(mode),
      primaryLabel: 'Open the room',
      primaryEnabled: !_opening,
      busy: _opening,
      onPrimary: () => unawaited(_openRoom()),
      child: Column(
        children: <Widget>[
          for (final option in _paceOptions(mode))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: _PaceCard(
                option: option,
                selected: option.pace == state.config.pace,
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  unawaited(coordinator.setPace(option.pace));
                },
              ),
            ),
        ],
      ),
    );
  }
}

String _subtitle(GameMode mode) => switch (mode) {
  GameMode.classic => 'How long does everyone get to guess each photo?',
  GameMode.captionThis => 'How long does everyone get to write a caption?',
  GameMode.timeTraveler => 'How long does everyone get to choose a date?',
  GameMode.mixedParty => 'Each of the three modes keeps its own clock.',
};

class _PaceOption {
  const _PaceOption({
    required this.pace,
    required this.blurb,
    required this.seconds,
    required this.icon,
  });

  final GamePace pace;
  final String blurb;
  final int? seconds;
  final IconData icon;
}

List<_PaceOption> _paceOptions(GameMode mode) => switch (mode) {
  GameMode.classic => <_PaceOption>[
    _PaceOption(
      pace: GamePace.fast,
      blurb: 'Snap decisions.',
      seconds: GamePace.fast.classicSeconds,
      icon: Icons.bolt_outlined,
    ),
    _PaceOption(
      pace: GamePace.normal,
      blurb: 'The party standard.',
      seconds: GamePace.normal.classicSeconds,
      icon: Icons.timer_outlined,
    ),
    _PaceOption(
      pace: GamePace.slow,
      blurb: 'For the big table.',
      seconds: GamePace.slow.classicSeconds,
      icon: Icons.hourglass_empty,
    ),
  ],
  GameMode.captionThis => <_PaceOption>[
    _PaceOption(
      pace: GamePace.fast,
      blurb: 'A quick caption.',
      seconds: GamePace.fast.captionSeconds,
      icon: Icons.bolt_outlined,
    ),
    _PaceOption(
      pace: GamePace.normal,
      blurb: 'Time to be funny.',
      seconds: GamePace.normal.captionSeconds,
      icon: Icons.timer_outlined,
    ),
    _PaceOption(
      pace: GamePace.slow,
      blurb: 'No rush, make it good.',
      seconds: GamePace.slow.captionSeconds,
      icon: Icons.hourglass_empty,
    ),
  ],
  GameMode.timeTraveler => <_PaceOption>[
    _PaceOption(
      pace: GamePace.fast,
      blurb: 'A quick date.',
      seconds: GamePace.fast.timelineSeconds,
      icon: Icons.bolt_outlined,
    ),
    _PaceOption(
      pace: GamePace.normal,
      blurb: 'Think it through.',
      seconds: GamePace.normal.timelineSeconds,
      icon: Icons.timer_outlined,
    ),
    _PaceOption(
      pace: GamePace.slow,
      blurb: 'For the history buffs.',
      seconds: GamePace.slow.timelineSeconds,
      icon: Icons.hourglass_empty,
    ),
  ],
  GameMode.mixedParty => <_PaceOption>[
    _PaceOption(
      pace: GamePace.fast,
      blurb: 'Every mode at its fast clock.',
      seconds: null,
      icon: Icons.bolt_outlined,
    ),
    _PaceOption(
      pace: GamePace.normal,
      blurb: 'Every mode at its normal clock.',
      seconds: null,
      icon: Icons.timer_outlined,
    ),
    _PaceOption(
      pace: GamePace.slow,
      blurb: 'Every mode at its slow clock.',
      seconds: null,
      icon: Icons.hourglass_empty,
    ),
  ],
};

class _PaceCard extends StatelessWidget {
  const _PaceCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _PaceOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Semantics(
      selected: selected,
      button: true,
      label:
          '${option.pace.label}, ${option.seconds == null ? option.blurb : '${option.seconds} seconds'}. ${option.blurb}',
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
                        option.pace.label,
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
                  option.seconds == null ? 'Mixed' : '${option.seconds}s',
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
