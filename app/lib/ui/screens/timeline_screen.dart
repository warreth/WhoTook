import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/game_audio_service.dart';
import '../../core/format/date_label.dart';
import '../../core/models/models.dart';
import '../../core/theme/game_skin.dart';
import '../../core/theme/responsive_game_layout.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/game_background.dart';
import '../widgets/game_widgets.dart';
import '../widgets/host_controls.dart';

/// Time Traveler: a decade, a year, a month, then the evidence timeline.
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  int _eraStart = 2010;
  int _year = 2015;
  int _month = 6;

  static const List<int> _eraStarts = <int>[1990, 2000, 2010, 2020];

  int get _currentYear => DateTime.now().year;

  int _eraEnd(int start) => start == 2020 ? _currentYear : start + 9;

  void _selectEra(int start) {
    setState(() {
      _eraStart = start;
      _year = _year.clamp(start, _eraEnd(start));
    });
    unawaited(GameHaptics.instance.selection());
    unawaited(GameAudioService.instance.tap());
  }

  void _selectYear(int year) {
    setState(() => _year = year);
    unawaited(GameHaptics.instance.selection());
    unawaited(GameAudioService.instance.tap());
  }

  void _selectMonth(int month) {
    setState(() => _month = month);
    unawaited(GameHaptics.instance.selection());
    unawaited(GameAudioService.instance.tap());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = WhoTookColors.of(context);
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final submitted = state.timelineSubmitted;
    final year = state.lockedTimelineYear ?? _year;
    final month = state.lockedTimelineMonth ?? _month;
    if (state.phase == RoundPhase.timelineReveal) {
      return _TimelineRevealView(state: state, coordinator: coordinator);
    }
    final layout = ResponsiveGameLayout.of(context);
    if (layout.isCompactHeight) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: GameBackdrop(
          mode: GameMode.timeTraveler,
          child: SafeArea(
            child: _buildCompact(
              context,
              state,
              coordinator,
              colors,
              l10n,
              year,
              month,
              submitted,
            ),
          ),
        ),
      );
    }
    final years = <int>[
      for (var value = _eraStart; value <= _eraEnd(_eraStart); value++) value,
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameBackdrop(
        mode: GameMode.timeTraveler,
        child: SafeArea(
          child: ScreenBody(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s20,
                AppSpacing.s12,
                AppSpacing.s20,
                AppSpacing.s24,
              ),
              children: <Widget>[
                _TimelineHeader(state: state),
                const SizedBox(height: AppSpacing.s12),
                PolaroidPhotoCard(
                  bytes: state.activePhotoBytes,
                  caption: l10n.modeTimeTraveler,
                  tilt: -0.018,
                  aspectRatio: 1.35,
                ),
                const SizedBox(height: AppSpacing.s12),
                Text(
                  submitted ? l10n.lockedIn : l10n.whenWasThisTaken,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colors.ink2),
                ),
                const SizedBox(height: 2),
                Text(
                  monthYear(l10n, year, month),
                  textAlign: TextAlign.center,
                  style: tabularFigures(
                    TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 38,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -1.8,
                      color: colors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                PanicTimerBar(
                  remainingMs: state.remainingMs,
                  totalMs: state.phaseDurationMs,
                  label: l10n.guessYearMonth,
                ),
                const SizedBox(height: AppSpacing.s12),
                _StepLabel(number: '01', label: l10n.pickDecade),
                _EraGrid(
                  starts: _eraStarts,
                  selected: _eraStart,
                  currentYear: _currentYear,
                  onSelected: _selectEra,
                ),
                const SizedBox(height: AppSpacing.s12),
                _StepLabel(number: '02', label: l10n.pickYear),
                _YearGrid(
                  years: years,
                  selected: year,
                  onSelected: _selectYear,
                ),
                const SizedBox(height: AppSpacing.s12),
                _StepLabel(number: '03', label: l10n.pickMonth),
                _MonthGrid(selected: month, onSelected: _selectMonth),
                const SizedBox(height: AppSpacing.s12),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: colors.raised,
                    borderRadius: BorderRadius.circular(AppRadii.rCard),
                    border: Border.all(color: colors.hairline),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              l10n.yourGuess.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 8,
                                letterSpacing: 0.8,
                                color: colors.ink3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              monthYear(l10n, year, month),
                              style: tabularFigures(
                                TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -1,
                                  color: colors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                if (submitted) ...<Widget>[
                  NoticeBanner(
                    message: l10n.lockedInWaiting,
                    icon: Icons.hourglass_empty,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  GameButton(
                    label: l10n.lockedDate(monthYear(l10n, year, month)),
                    onPressed: null,
                    fullWidth: true,
                    variant: GameButtonVariant.secondary,
                  ),
                ] else
                  GameButton(
                    label: l10n.lockInDate(monthYear(l10n, year, month)),
                    onPressed: () => unawaited(
                      state.isHosting
                          ? coordinator.submitTimeline(year, month)
                          : coordinator.clientSubmitTimeline(year, month),
                    ),
                    fullWidth: true,
                    icon: Icons.lock_outline,
                  ),
                if (state.errorMessage != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.s12),
                  NoticeBanner(
                    message: state.errorMessage!,
                    tone: StatusTone.warning,
                    icon: Icons.error_outline,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(
    BuildContext context,
    MatchUiState state,
    MatchCoordinator coordinator,
    WhoTookColors colors,
    AppLocalizations l10n,
    int year,
    int month,
    bool submitted,
  ) {
    final years = <int>[
      for (var value = _eraStart; value <= _eraEnd(_eraStart); value++) value,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 8, 13, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.modeTimeTraveler,
                  style: gameDisplay(size: 21, color: colors.ink),
                ),
              ),
              const HostControlsButton(),
              FrameCounter(
                current: state.currentRound,
                total: state.totalRounds,
                label: l10n.roundBadge(state.currentRound, state.totalRounds),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ProgressSegments(
            current: state.currentRound,
            total: state.totalRounds,
          ),
          const SizedBox(height: 5),
          Row(
            children: <Widget>[
              SizedBox(
                width: 108,
                height: 82,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.card,
                      border: Border.all(color: colors.ink, width: 2),
                    ),
                    child: GamePhoto(
                      bytes: state.activePhotoBytes ?? Uint8List(0),
                      photoId: state.activePhotoId,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      submitted ? l10n.lockedIn : l10n.whenWasThisTaken,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: colors.ink2),
                    ),
                    Text(
                      monthYear(l10n, year, month),
                      style: gameDisplay(size: 21, color: colors.ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          PanicTimerBar(
            remainingMs: state.remainingMs,
            totalMs: state.phaseDurationMs,
            label: l10n.guessYearMonth,
          ),
          const SizedBox(height: 5),
          Row(
            children: <Widget>[
              for (final start in _eraStarts)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: start == _eraStarts.last ? 0 : 5,
                    ),
                    child: _CompactChoice(
                      label: '${start}s',
                      selected: start == _eraStart,
                      onTap: () => _selectEra(start),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 20) / 5;
              return Wrap(
                spacing: 5,
                runSpacing: 4,
                children: <Widget>[
                  for (final value in years)
                    SizedBox(
                      width: width,
                      height: 29,
                      child: _CompactChoice(
                        label: '$value',
                        selected: value == year,
                        onTap: () => _selectYear(value),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 25) / 6;
              return Wrap(
                spacing: 5,
                runSpacing: 4,
                children: <Widget>[
                  for (var value = 1; value <= 12; value++)
                    SizedBox(
                      width: width,
                      height: 28,
                      child: _CompactChoice(
                        label: monthName(l10n, value),
                        selected: value == month,
                        onTap: () => _selectMonth(value),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          if (submitted)
            GameButton(
              label: l10n.lockedDate(monthYear(l10n, year, month)),
              onPressed: null,
              fullWidth: true,
              variant: GameButtonVariant.secondary,
            )
          else
            GameButton(
              label: l10n.lockInDate(monthYear(l10n, year, month)),
              onPressed: () => unawaited(
                state.isHosting
                    ? coordinator.submitTimeline(year, month)
                    : coordinator.clientSubmitTimeline(year, month),
              ),
              fullWidth: true,
              icon: Icons.lock_outline,
            ),
        ],
      ),
    );
  }
}

class _CompactChoice extends StatelessWidget {
  const _CompactChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.ink : colors.card,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: selected ? colors.ink : colors.hairline),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 9,
              color: selected ? colors.bg : colors.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Text(
            number,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 9,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.ink2,
            ),
          ),
        ],
      ),
    );
  }
}

class _EraGrid extends StatelessWidget {
  const _EraGrid({
    required this.starts,
    required this.selected,
    required this.currentYear,
    required this.onSelected,
  });

  final List<int> starts;
  final int selected;
  final int currentYear;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 7,
      crossAxisSpacing: 7,
      childAspectRatio: 1.55,
      children: <Widget>[
        for (final start in starts)
          Semantics(
            button: true,
            selected: start == selected,
            child: GestureDetector(
              onTap: () => onSelected(start),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 110),
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: start == selected ? colors.ink : colors.card,
                  borderRadius: BorderRadius.circular(AppRadii.rControl),
                  border: Border.all(
                    color: start == selected ? colors.ink : colors.hairline,
                    width: 2,
                  ),
                  boxShadow: start == selected
                      ? const <BoxShadow>[
                          BoxShadow(
                            color: GamePalette.gold,
                            offset: Offset(0, 3),
                            blurRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      '${start}s',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1,
                        color: start == selected ? colors.bg : colors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$start–${start == 2020 ? currentYear : start + 9}',
                      style: TextStyle(
                        fontSize: 10,
                        color: start == selected ? colors.ink3 : colors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _YearGrid extends StatelessWidget {
  const _YearGrid({
    required this.years,
    required this.selected,
    required this.onSelected,
  });

  final List<int> years;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: <Widget>[
        for (final year in years)
          SizedBox(
            width: (MediaQuery.sizeOf(context).width - 40 - 20) / 5,
            height: 42,
            child: Semantics(
              button: true,
              selected: year == selected,
              child: GestureDetector(
                onTap: () => onSelected(year),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: year == selected ? colors.ink : colors.card,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: year == selected ? colors.ink : colors.hairline,
                    ),
                  ),
                  child: Text(
                    '$year',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: year == selected ? colors.bg : colors.ink2,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final width = (MediaQuery.sizeOf(context).width - 40 - 18) / 4;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (var month = 1; month <= 12; month++)
          SizedBox(
            width: width,
            height: 44,
            child: Semantics(
              button: true,
              selected: month == selected,
              label: monthName(l10n, month),
              child: GestureDetector(
                onTap: () => onSelected(month),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: month == selected ? colors.ink : colors.card,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: month == selected ? colors.ink : colors.hairline,
                    ),
                  ),
                  child: Text(
                    monthName(l10n, month),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: month == selected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: month == selected ? colors.bg : colors.ink2,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TimelineHeader extends StatelessWidget {
  const _TimelineHeader({required this.state});

  final MatchUiState state;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.modeTimeTraveler,
                style: gameDisplay(size: 26, color: colors.ink),
              ),
            ),
            const HostControlsButton(),
            FrameCounter(
              current: state.currentRound,
              total: state.totalRounds,
              label: l10n.roundBadge(state.currentRound, state.totalRounds),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        ProgressSegments(current: state.currentRound, total: state.totalRounds),
      ],
    );
  }
}

class _TimelineRevealView extends StatelessWidget {
  const _TimelineRevealView({required this.state, required this.coordinator});

  final MatchUiState state;
  final MatchCoordinator coordinator;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final reveal = state.lastTimelineReveal;
    if (reveal == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final closest = reveal.entries
        .where((entry) => entry.playerId == reveal.closestId)
        .firstOrNull;
    final furthest = reveal.entries
        .where((entry) => entry.playerId == reveal.furthestId)
        .firstOrNull;
    final owner = state.players
        .where((player) => player.id == reveal.ownerId)
        .firstOrNull;
    final entries = <TimelineEntry>[...reveal.entries]
      ..sort((a, b) => (a.monthsOff ?? 9999).compareTo(b.monthsOff ?? 9999));
    final average = entries.isEmpty
        ? 0
        : (entries
                      .map((entry) => entry.monthsOff ?? 0)
                      .reduce((a, b) => a + b) /
                  entries.length)
              .round();
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: ColoredBox(
        color: colors.card,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(
            AppSpacing.s20,
            AppSpacing.s8,
            AppSpacing.s20,
            AppSpacing.s16,
          ),
          child: state.isHosting
              ? GameButton(
                  label: l10n.nextRound,
                  onPressed: () => unawaited(coordinator.skipRound()),
                  icon: Icons.arrow_forward,
                  fullWidth: true,
                )
              : NoticeBanner(
                  message: l10n.waitingForHostToContinue,
                  icon: Icons.hourglass_empty,
                ),
        ),
      ),
      body: GameBackdrop(
        mode: GameMode.timeTraveler,
        child: SafeArea(
          child: ScreenBody(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s20,
                AppSpacing.s12,
                AppSpacing.s20,
                AppSpacing.s24,
              ),
              children: <Widget>[
                _TimelineHeader(state: state),
                const SizedBox(height: AppSpacing.s12),
                _AwardDuo(closest: closest, furthest: furthest, l10n: l10n),
                const SizedBox(height: AppSpacing.s12),
                _EvidenceBoard(
                  state: state,
                  reveal: reveal,
                  entries: entries,
                  ownerName: owner?.name ?? l10n.player,
                ),
                const SizedBox(height: AppSpacing.s12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.averageMiss(monthDistance(l10n, average)),
                        style: TextStyle(fontSize: 12, color: colors.ink2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AwardDuo extends StatelessWidget {
  const _AwardDuo({
    required this.closest,
    required this.furthest,
    required this.l10n,
  });

  final TimelineEntry? closest;
  final TimelineEntry? furthest;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: _AwardCard(
            label: l10n.timeLord,
            entry: closest,
            gold: true,
            l10n: l10n,
            colors: colors,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AwardCard(
            label: l10n.mostDelusional,
            entry: furthest,
            gold: false,
            l10n: l10n,
            colors: colors,
          ),
        ),
      ],
    );
  }
}

class _AwardCard extends StatelessWidget {
  const _AwardCard({
    required this.label,
    required this.entry,
    required this.gold,
    required this.l10n,
    required this.colors,
  });

  final String label;
  final TimelineEntry? entry;
  final bool gold;
  final AppLocalizations l10n;
  final WhoTookColors colors;

  @override
  Widget build(BuildContext context) {
    final off = entry?.monthsOff;
    // Gold is a light surface in both themes, so it needs its own ink instead
    // of the theme's light-on-dark foreground.
    final ink = gold ? const Color(0xFF2A1B06) : colors.ink;
    final ink2 = gold ? const Color(0xFF5B3A0E) : colors.ink2;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: gold ? GamePalette.gold : colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rControl),
        border: Border.all(color: colors.ink, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.ink,
            offset: const Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 8,
              letterSpacing: 0.7,
              color: ink2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            entry?.playerName ?? '...',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          if (off != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              '${off == 0 ? l10n.exact : l10n.offBy(monthDistance(l10n, off))} · +${entry!.points}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: ink2),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceBoard extends StatefulWidget {
  const _EvidenceBoard({
    required this.state,
    required this.reveal,
    required this.entries,
    required this.ownerName,
  });

  final MatchUiState state;
  final TimelineReveal reveal;
  final List<TimelineEntry> entries;
  final String ownerName;

  @override
  State<_EvidenceBoard> createState() => _EvidenceBoardState();
}

class _EvidenceBoardState extends State<_EvidenceBoard> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cork = dark ? const Color(0xFF2A241D) : const Color(0xFFD9C6A5);
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 420),
      tween: Tween<double>(begin: 0, end: _shown ? 1 : 0),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: 0.98 + value * 0.02, child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cork,
          borderRadius: BorderRadius.circular(AppRadii.rCard),
          border: Border.all(color: colors.ink, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.ink,
              offset: const Offset(0, 6),
              blurRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Column(
          children: <Widget>[
            SizedBox(
              width: 180,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  PolaroidPhotoCard(
                    bytes: widget.state.activePhotoBytes,
                    caption: widget.ownerName,
                    meta: monthYear(
                      l10n,
                      widget.reveal.actualYear,
                      widget.reveal.actualMonth,
                    ),
                    tilt: -0.035,
                    aspectRatio: 1.05,
                  ),
                  Positioned(
                    left: -6,
                    top: -6,
                    child: Transform.rotate(
                      angle: -0.06,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accent,
                          border: Border.all(color: colors.ink, width: 2),
                        ),
                        child: Text(
                          l10n.actualDate.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: colors.onAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            _EvidenceTimeline(
              state: widget.state,
              entries: widget.entries,
              actualYear: widget.reveal.actualYear,
              actualMonth: widget.reveal.actualMonth,
              l10n: l10n,
            ),
            const SizedBox(height: AppSpacing.s8),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 560 ? 4 : 2;
                final scale = MediaQuery.textScalerOf(context)
                    .scale(1)
                    .clamp(1.0, 1.8);
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 7,
                  crossAxisSpacing: 7,
                  mainAxisExtent: 122 * scale,
                  children: <Widget>[
                    for (final entry in widget.entries)
                      _EvidenceNote(
                        entry: entry,
                        l10n: l10n,
                        state: widget.state,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceTimeline extends StatelessWidget {
  const _EvidenceTimeline({
    required this.state,
    required this.entries,
    required this.actualYear,
    required this.actualMonth,
    required this.l10n,
  });

  final MatchUiState state;
  final List<TimelineEntry> entries;
  final int actualYear;
  final int actualMonth;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final dated = entries.where((entry) => entry.year != null).toList();
    final years = <int>[actualYear, for (final entry in dated) entry.year!];
    var minYear = years.reduce(math.min) - 1;
    var maxYear = years.reduce(math.max) + 1;
    if (maxYear - minYear < 4) {
      minYear -= 1;
      maxYear += 1;
    }
    final totalMonths = (maxYear - minYear + 1) * 12;
    double fraction(int year, int month) =>
        ((year - minYear) * 12 + (month - 1)) / totalMonths;
    final actualFraction = fraction(actualYear, actualMonth);
    final clusters = _cluster(dated, fraction);
    final lanes = _assignLanes(clusters);
    final maxTier = lanes.isEmpty ? 0 : lanes.reduce(math.max) ~/ 2;
    final height = 170.0 + maxTier * 76;
    final axisY = height / 2;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: _TimelinePainter(
                    axisY: axisY,
                    actualFraction: actualFraction,
                    pins: <_PinPoint>[
                      for (var i = 0; i < clusters.length; i++)
                        _PinPoint(
                          fraction: clusters[i].fraction,
                          lane: lanes[i],
                        ),
                    ],
                    minYear: minYear,
                    maxYear: maxYear,
                    ink: colors.ink,
                    accent: colors.accent,
                    gold: GamePalette.goldDeep,
                  ),
                ),
              ),
              for (var i = 0; i < clusters.length; i++)
                _ClusterPin(
                  cluster: clusters[i],
                  lane: lanes[i],
                  width: width,
                  axisY: axisY,
                  state: state,
                  l10n: l10n,
                ),
              Positioned(
                left: actualFraction * (width - 44) + 22 - 24,
                top: axisY - 24,
                child: Tooltip(
                  message:
                      '${l10n.actualDate}: ${monthYear(l10n, actualYear, actualMonth)}',
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: GamePalette.goldDeep, width: 3),
                      color: colors.raised,
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x66F5B82E),
                          blurRadius: 14,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child:
                        state.activePhotoBytes == null ||
                            state.activePhotoBytes!.isEmpty
                        ? const Icon(
                            Icons.star,
                            color: GamePalette.goldDeep,
                            size: 22,
                          )
                        : GamePhoto(
                            bytes: state.activePhotoBytes!,
                            fit: BoxFit.cover,
                            compact: true,
                          ),
                  ),
                ),
              ),
              Positioned(
                left: (actualFraction * width - 38).clamp(0, width - 76),
                top: axisY + 40,
                child: Container(
                  width: 76,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    border: Border.all(color: colors.ink, width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l10n.actualDate.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: gameDisplay(
                      size: 7,
                      color: colors.onAccent,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_DateCluster> _cluster(
    List<TimelineEntry> dated,
    double Function(int, int) fraction,
  ) {
    final sorted = <TimelineEntry>[...dated]
      ..sort(
        (a, b) => fraction(
          a.year!,
          a.month ?? 1,
        ).compareTo(fraction(b.year!, b.month ?? 1)),
      );
    final clusters = <_DateCluster>[];
    for (final entry in sorted) {
      final x = fraction(entry.year!, entry.month ?? 1);
      if (clusters.isNotEmpty && (x - clusters.last.fraction).abs() < 0.075) {
        clusters.last.entries.add(entry);
      } else {
        clusters.add(
          _DateCluster(fraction: x, entries: <TimelineEntry>[entry]),
        );
      }
    }
    return clusters;
  }

  List<int> _assignLanes(List<_DateCluster> clusters) {
    final lanes = <double>[];
    final result = <int>[];
    for (final cluster in clusters) {
      var lane = -1;
      for (var i = 0; i < lanes.length; i++) {
        if (cluster.fraction - lanes[i] >= 0.075) {
          lane = i;
          break;
        }
      }
      if (lane == -1) {
        if (lanes.length < 6) {
          lanes.add(cluster.fraction);
          lane = lanes.length - 1;
        } else {
          // Pack the extra cluster into the least crowded lane.
          lane = 0;
          for (var i = 1; i < lanes.length; i++) {
            if (lanes[i] < lanes[lane]) lane = i;
          }
          lanes[lane] = cluster.fraction;
        }
      } else {
        lanes[lane] = cluster.fraction;
      }
      result.add(lane);
    }
    return result;
  }
}

class _DateCluster {
  _DateCluster({required this.fraction, required this.entries});

  final double fraction;
  final List<TimelineEntry> entries;
}

class _PinPoint {
  const _PinPoint({required this.fraction, required this.lane});

  final double fraction;
  final int lane;
}

class _ClusterPin extends StatelessWidget {
  const _ClusterPin({
    required this.cluster,
    required this.lane,
    required this.width,
    required this.axisY,
    required this.state,
    required this.l10n,
  });

  final _DateCluster cluster;
  final int lane;
  final double width;
  final double axisY;
  final MatchUiState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final above = lane.isEven;
    final tier = lane ~/ 2;
    final clusterWidth = 26.0 + math.min(cluster.entries.length - 1, 2) * 12;
    final centre = cluster.fraction * (width - 44) + 22;
    final top = above ? axisY - 54 - tier * 38 : axisY + 34 + tier * 38;
    final names = cluster.entries
        .map(
          (entry) =>
              '${entry.playerName} · ${monthYear(l10n, entry.year!, entry.month ?? 1)}',
        )
        .join('\n');
    return Positioned(
      left: (centre - clusterWidth / 2).clamp(0, width - clusterWidth),
      top: top,
      child: Tooltip(
        message: names,
        child: SizedBox(
          width: clusterWidth,
          height: 26,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (var i = 0; i < math.min(cluster.entries.length, 3); i++)
                Positioned(
                  left: i * 12,
                  child: PlayerAvatar(
                    initial: cluster.entries[i].playerName,
                    avatar:
                        state.players
                            .where(
                              (player) =>
                                  player.id == cluster.entries[i].playerId,
                            )
                            .firstOrNull
                            ?.avatar ??
                        '',
                    photoBase64:
                        state.avatarPhotos[cluster.entries[i].playerId],
                    size: 26,
                  ),
                ),
              if (cluster.entries.length > 3)
                Positioned(
                  right: 0,
                  top: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: colors.ink,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: colors.card, width: 1),
                    ),
                    child: Text(
                      '+${cluster.entries.length - 3}',
                      style: TextStyle(fontSize: 7, color: colors.bg),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.axisY,
    required this.actualFraction,
    required this.pins,
    required this.minYear,
    required this.maxYear,
    required this.ink,
    required this.accent,
    required this.gold,
  });

  final double axisY;
  final double actualFraction;
  final List<_PinPoint> pins;
  final int minYear;
  final int maxYear;
  final Color ink;
  final Color accent;
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()
      ..color = ink
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(4, axisY), Offset(size.width - 4, axisY), axis);

    final pinLine = Paint()
      ..color = ink.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = ink;
    for (final pin in pins) {
      final x = pin.fraction * (size.width - 44) + 22;
      final above = pin.lane.isEven;
      final tier = pin.lane ~/ 2;
      final y = above ? axisY - 28 - tier * 38 : axisY + 26 + tier * 38;
      canvas.drawLine(Offset(x, y), Offset(x, axisY), pinLine);
      canvas.drawCircle(Offset(x, axisY), 3.2, dot);
    }

    final tick = Paint()
      ..color = ink.withValues(alpha: 0.40)
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final x = 4 + (size.width - 8) * (i / 2);
      canvas.drawLine(Offset(x, axisY - 4), Offset(x, axisY + 4), tick);
      final label = TextPainter(
        text: TextSpan(
          text: '${minYear + ((maxYear - minYear) * i / 2).round()}',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 8,
            color: ink.withValues(alpha: 0.55),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(x - label.width / 2, axisY + 10));
    }

    final actualX = actualFraction * (size.width - 44) + 22;
    final glow = Paint()
      ..color = gold.withValues(alpha: 0.35)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(actualX, axisY), 24, glow);
    canvas.drawCircle(
      Offset(actualX, axisY),
      25,
      Paint()
        ..color = accent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      oldDelegate.axisY != axisY ||
      oldDelegate.actualFraction != actualFraction ||
      oldDelegate.pins != pins ||
      oldDelegate.minYear != minYear ||
      oldDelegate.maxYear != maxYear;
}

class _EvidenceNote extends StatelessWidget {
  const _EvidenceNote({
    required this.entry,
    required this.l10n,
    required this.state,
  });

  final TimelineEntry entry;
  final AppLocalizations l10n;
  final MatchUiState state;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final player = state.players
        .where((player) => player.id == entry.playerId)
        .firstOrNull;
    return Transform.rotate(
      angle: entry.isOwner ? 0.012 : -0.01,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s8),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.ink, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.ink.withValues(alpha: 0.16),
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                PlayerAvatar(
                  initial: entry.playerName,
                  avatar: player?.avatar ?? '',
                  photoBase64: state.avatarPhotos[entry.playerId],
                  size: 24,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    entry.playerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.ink,
                    ),
                  ),
                ),
                if (entry.isOwner)
                  Text(
                    l10n.ownerLabel,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 7,
                      color: colors.ink3,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              entry.year == null
                  ? l10n.noGuess
                  : monthYear(l10n, entry.year!, entry.month ?? 1),
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 8,
                color: colors.ink3,
              ),
            ),
            if (entry.monthsOff != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                entry.monthsOff == 0
                    ? l10n.exact
                    : l10n.offBy(monthDistance(l10n, entry.monthsOff!)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, color: colors.ink2),
              ),
            ],
            const Spacer(),
            Text(
              '+${entry.points}',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10,
                color: colors.positive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
