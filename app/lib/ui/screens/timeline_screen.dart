import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/game_audio_service.dart';
import '../../core/format/date_label.dart';
import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
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
      return _TimelineRevealView(state: state);
    }
    final years = <int>[
      for (var value = _eraStart; value <= _eraEnd(_eraStart); value++) value,
    ];
    return Scaffold(
      body: SafeArea(
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
                meta: l10n.ownerIncluded,
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
              _YearGrid(years: years, selected: year, onSelected: _selectYear),
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
                    Text(
                      l10n.ownerIncluded,
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11, color: colors.ink2),
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
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.4,
                  color: colors.ink,
                ),
              ),
            ),
            const HostControlsButton(),
            FrameCounter(current: state.currentRound, total: state.totalRounds),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        ProgressSegments(current: state.currentRound, total: state.totalRounds),
      ],
    );
  }
}

class _TimelineRevealView extends StatelessWidget {
  const _TimelineRevealView({required this.state});

  final MatchUiState state;

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
      body: SafeArea(
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
                  const SizedBox(width: 8),
                  Text(
                    l10n.ownerIncluded,
                    style: TextStyle(fontSize: 10, color: colors.ink3),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                l10n.nextRoundInMoment,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.ink3),
              ),
            ],
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
            entry?.playerName ?? '—',
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
            SizedBox(
              height: 112,
              child: _EvidenceTimeline(
                state: widget.state,
                entries: widget.entries,
                actualYear: widget.reveal.actualYear,
                actualMonth: widget.reveal.actualMonth,
                l10n: l10n,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 560 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 7,
                  crossAxisSpacing: 7,
                  childAspectRatio: columns == 4 ? 1.15 : 1.52,
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
    final years = <int>[
      actualYear,
      for (final entry in entries)
        if (entry.year != null) entry.year!,
    ];
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _StringPainter(
                  actualFraction: actualFraction,
                  fractions: <double>[
                    for (final entry in entries)
                      if (entry.year != null)
                        fraction(entry.year!, entry.month ?? 1),
                  ],
                  color: colors.accent,
                ),
              ),
            ),
            Positioned(
              left: 4,
              right: 4,
              top: 56,
              child: Container(height: 3, color: colors.ink),
            ),
            for (var i = 0; i < 3; i++)
              Positioned(
                left: 4 + (width - 8) * (i / 2) - 16,
                top: 64,
                child: SizedBox(
                  width: 32,
                  child: Text(
                    '${minYear + ((maxYear - minYear) * i / 2).round()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 8,
                      color: colors.ink2,
                    ),
                  ),
                ),
              ),
            for (final entry in entries)
              if (entry.year != null)
                Positioned(
                  left: fraction(entry.year!, entry.month ?? 1) * width - 20,
                  top: 36,
                  child: Tooltip(
                    message:
                        '${entry.playerName} · ${monthYear(l10n, entry.year!, entry.month ?? 1)}',
                    child: PlayerAvatar(
                      initial: entry.playerName,
                      avatar:
                          state.players
                              .where((player) => player.id == entry.playerId)
                              .firstOrNull
                              ?.avatar ??
                          '',
                      photoBase64: state.avatarPhotos[entry.playerId],
                      size: 40,
                    ),
                  ),
                ),
            Positioned(
              left: actualFraction * width - 24,
              top: 0,
              child: Column(
                children: <Widget>[
                  Tooltip(
                    message: l10n.actualDate,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: GamePalette.goldDeep,
                          width: 3,
                        ),
                        color: colors.raised,
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x44B46B12),
                            blurRadius: 8,
                            spreadRadius: 2,
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
                          : Image.memory(
                              state.activePhotoBytes!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  Container(width: 2, height: 8, color: GamePalette.goldDeep),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StringPainter extends CustomPainter {
  const _StringPainter({
    required this.actualFraction,
    required this.fractions,
    required this.color,
  });

  final double actualFraction;
  final List<double> fractions;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final start = Offset(size.width * actualFraction, 0);
    for (final fraction in fractions) {
      final end = Offset(size.width * fraction, 56);
      final delta = end - start;
      final length = delta.distance;
      if (length < 1) continue;
      final direction = delta / length;
      var distance = 0.0;
      while (distance < length) {
        final a = start + direction * distance;
        final b = start + direction * math.min(distance + 4, length);
        canvas.drawLine(a, b, paint);
        distance += 8;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StringPainter oldDelegate) =>
      oldDelegate.actualFraction != actualFraction ||
      oldDelegate.fractions != fractions ||
      oldDelegate.color != color;
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
