import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/game_audio_service.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/whotook_theme.dart';
import '../../../l10n/l10n.dart';
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
          content: Text(next.errorMessage ?? context.l10n.couldNotOpenRoom),
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
      title: context.l10n.pickPace,
      subtitle: _subtitle(mode, context.l10n),
      primaryLabel: context.l10n.openRoom,
      primaryEnabled: !_opening,
      busy: _opening,
      onPrimary: () => unawaited(_openRoom()),
      child: Column(
        children: <Widget>[
          for (final option in _paceOptions(mode, context.l10n))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: _PaceCard(
                option: option,
                selected: option.pace == state.config.pace,
                onTap: () {
                  unawaited(GameHaptics.instance.selection());
                  unawaited(coordinator.setPace(option.pace));
                },
              ),
            ),
        ],
      ),
    );
  }
}

String _subtitle(GameMode mode, AppLocalizations l10n) => switch (mode) {
  GameMode.classic => l10n.paceClassicSubtitle,
  GameMode.captionThis => l10n.paceCaptionSubtitle,
  GameMode.zoomOut => l10n.paceZoomSubtitle,
  GameMode.makeItMeme => l10n.paceMemeSubtitle,
  GameMode.photoSabotage => l10n.paceSabotageSubtitle,
  GameMode.timeTraveler => l10n.paceTimelineSubtitle,
  GameMode.mixedParty => l10n.paceMixedSubtitle,
};

String _paceLabel(AppLocalizations l10n, GamePace pace) => switch (pace) {
  GamePace.fast => l10n.paceFast,
  GamePace.normal => l10n.paceNormal,
  GamePace.slow => l10n.paceSlow,
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

List<_PaceOption> _paceOptions(GameMode mode, AppLocalizations l10n) =>
    switch (mode) {
      GameMode.classic => <_PaceOption>[
        _PaceOption(
          pace: GamePace.fast,
          blurb: l10n.paceFastClassic,
          seconds: GamePace.fast.classicSeconds,
          icon: Icons.bolt_outlined,
        ),
        _PaceOption(
          pace: GamePace.normal,
          blurb: l10n.paceNormalClassic,
          seconds: GamePace.normal.classicSeconds,
          icon: Icons.timer_outlined,
        ),
        _PaceOption(
          pace: GamePace.slow,
          blurb: l10n.paceSlowClassic,
          seconds: GamePace.slow.classicSeconds,
          icon: Icons.hourglass_empty,
        ),
      ],
      GameMode.captionThis => <_PaceOption>[
        _PaceOption(
          pace: GamePace.fast,
          blurb: l10n.paceFastCaption,
          seconds: GamePace.fast.captionSeconds,
          icon: Icons.bolt_outlined,
        ),
        _PaceOption(
          pace: GamePace.normal,
          blurb: l10n.paceNormalCaption,
          seconds: GamePace.normal.captionSeconds,
          icon: Icons.timer_outlined,
        ),
        _PaceOption(
          pace: GamePace.slow,
          blurb: l10n.paceSlowCaption,
          seconds: GamePace.slow.captionSeconds,
          icon: Icons.hourglass_empty,
        ),
      ],
      GameMode.makeItMeme => <_PaceOption>[
        _PaceOption(
          pace: GamePace.fast,
          blurb: l10n.paceFastMeme,
          seconds: GamePace.fast.memeSeconds,
          icon: Icons.bolt_outlined,
        ),
        _PaceOption(
          pace: GamePace.normal,
          blurb: l10n.paceNormalMeme,
          seconds: GamePace.normal.memeSeconds,
          icon: Icons.timer_outlined,
        ),
        _PaceOption(
          pace: GamePace.slow,
          blurb: l10n.paceSlowMeme,
          seconds: GamePace.slow.memeSeconds,
          icon: Icons.hourglass_empty,
        ),
      ],
      GameMode.timeTraveler => <_PaceOption>[
        _PaceOption(
          pace: GamePace.fast,
          blurb: l10n.paceFastTimeline,
          seconds: GamePace.fast.timelineSeconds,
          icon: Icons.bolt_outlined,
        ),
        _PaceOption(
          pace: GamePace.normal,
          blurb: l10n.paceNormalTimeline,
          seconds: GamePace.normal.timelineSeconds,
          icon: Icons.timer_outlined,
        ),
        _PaceOption(
          pace: GamePace.slow,
          blurb: l10n.paceSlowTimeline,
          seconds: GamePace.slow.timelineSeconds,
          icon: Icons.hourglass_empty,
        ),
      ],
      GameMode.zoomOut => <_PaceOption>[
        _PaceOption(
          pace: GamePace.fast,
          blurb: l10n.paceFastZoom,
          seconds: GamePace.fast.zoomOutSeconds,
          icon: Icons.bolt_outlined,
        ),
        _PaceOption(
          pace: GamePace.normal,
          blurb: l10n.paceNormalZoom,
          seconds: GamePace.normal.zoomOutSeconds,
          icon: Icons.zoom_in,
        ),
        _PaceOption(
          pace: GamePace.slow,
          blurb: l10n.paceSlowZoom,
          seconds: GamePace.slow.zoomOutSeconds,
          icon: Icons.hourglass_empty,
        ),
      ],
      GameMode.photoSabotage => <_PaceOption>[
        _PaceOption(
          pace: GamePace.fast,
          blurb: l10n.paceFastSabotage,
          seconds: GamePace.fast.sabotageSeconds,
          icon: Icons.bolt_outlined,
        ),
        _PaceOption(
          pace: GamePace.normal,
          blurb: l10n.paceNormalSabotage,
          seconds: GamePace.normal.sabotageSeconds,
          icon: Icons.brush_outlined,
        ),
        _PaceOption(
          pace: GamePace.slow,
          blurb: l10n.paceSlowSabotage,
          seconds: GamePace.slow.sabotageSeconds,
          icon: Icons.hourglass_empty,
        ),
      ],
      GameMode.mixedParty => <_PaceOption>[
        _PaceOption(
          pace: GamePace.fast,
          blurb: l10n.paceFastMixed,
          seconds: null,
          icon: Icons.bolt_outlined,
        ),
        _PaceOption(
          pace: GamePace.normal,
          blurb: l10n.paceNormalMixed,
          seconds: null,
          icon: Icons.timer_outlined,
        ),
        _PaceOption(
          pace: GamePace.slow,
          blurb: l10n.paceSlowMixed,
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
    final l10n = context.l10n;
    return Semantics(
      selected: selected,
      button: true,
      label: l10n.paceSemantic(
        _paceLabel(context.l10n, option.pace),
        option.seconds == null
            ? l10n.mixed
            : l10n.secondsShort(option.seconds!),
        option.blurb,
      ),
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
                        _paceLabel(l10n, option.pace),
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
                  option.seconds == null
                      ? l10n.mixed
                      : l10n.secondsShort(option.seconds!),
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
