import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/date_label.dart';
import '../../l10n/l10n.dart';
import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/host_controls.dart';

/// Time Traveler: drag the year, tap the month, then watch the pins drop.
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  static const int minYear = 1990;
  int _year = 2015;
  int _month = 6;

  void _setYear(double value) {
    setState(() => _year = value.round());
  }

  void _setMonth(int month) {
    setState(() => _month = month);
    unawaited(HapticFeedback.selectionClick());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final maxYear = DateTime.now().year;
    final submitted = state.timelineSubmitted;
    final year = state.lockedTimelineYear ?? _year;
    final month = state.lockedTimelineMonth ?? _month;

    if (state.phase == RoundPhase.timelineReveal) {
      return _TimelineRevealView(state: state);
    }

    return Scaffold(
      body: SafeArea(
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
            PhotoPanel(
              bytes: state.activePhotoBytes,
              aspectRatio: 1.4,
              isPanorama: state.activePhotoIsPanorama,
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              submitted ? l10n.lockedIn : l10n.whenWasThisTaken,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colorsOf(context).ink2),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              monthYear(l10n, year, month),
              textAlign: TextAlign.center,
              style: tabularFigures(
                TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1,
                  color: colorsOf(context).ink,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            CountdownBar(
              remainingMs: state.remainingMs,
              totalMs: state.phaseDurationMs,
              label: l10n.guessYearMonth,
            ),
            const SizedBox(height: AppSpacing.s8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                activeTrackColor: colorsOf(context).accent,
                inactiveTrackColor: colorsOf(context).raised,
                thumbColor: colorsOf(context).accent,
                overlayColor: colorsOf(context).accent.withValues(alpha: 0.12),
                showValueIndicator: ShowValueIndicator.onDrag,
                valueIndicatorColor: colorsOf(context).ink,
                valueIndicatorTextStyle: TextStyle(
                  color: colorsOf(context).bg,
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                ),
              ),
              child: Slider(
                value: year.toDouble().clamp(
                  minYear.toDouble(),
                  maxYear.toDouble(),
                ),
                min: minYear.toDouble(),
                max: maxYear.toDouble(),
                divisions: maxYear - minYear,
                label: '$year',
                onChanged: submitted ? null : _setYear,
                onChangeEnd: (_) => unawaited(HapticFeedback.selectionClick()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
              child: Row(
                children: <Widget>[
                  Text(
                    '$minYear',
                    style: tabularFigures(
                      TextStyle(fontSize: 11, color: colorsOf(context).ink3),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    l10n.now,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorsOf(context).ink3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            SectionLabel(l10n.monthLabel),
            GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.18,
              children: <Widget>[
                for (var monthIndex = 1; monthIndex <= 12; monthIndex++)
                  _MonthTile(
                    label: monthShort(l10n, monthIndex),
                    selected: month == monthIndex,
                    onTap: submitted ? null : () => _setMonth(monthIndex),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s20),
            if (submitted) ...<Widget>[
              NoticeBanner(
                message: l10n.lockedInWaiting,
                icon: Icons.hourglass_empty,
              ),
              const SizedBox(height: AppSpacing.s12),
              SecondaryButton(
                label: l10n.lockedDate(monthYear(l10n, year, month)),
                onPressed: null,
              ),
            ] else
              PrimaryButton(
                label: l10n.lockInDate(monthYear(l10n, year, month)),
                onPressed: () => unawaited(
                  state.isHosting
                      ? coordinator.submitTimeline(year, month)
                      : coordinator.clientSubmitTimeline(year, month),
                ),
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
    );
  }
}

WhoTookColors colorsOf(BuildContext context) => WhoTookColors.of(context);

class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Material(
      color: selected ? colors.accent : colors.card,
      borderRadius: BorderRadius.circular(AppRadii.rSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.rSm),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.rSm),
            border: Border.all(
              color: selected ? colors.accent : colors.hairline,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? colors.onAccent : colors.ink2,
            ),
          ),
        ),
      ),
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
    return Scaffold(
      body: SafeArea(
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
            PhotoPanel(
              bytes: state.activePhotoBytes,
              aspectRatio: 2.1,
              isPanorama: state.activePhotoIsPanorama,
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              l10n.theTimeline,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.3,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            _TimelineChart(reveal: reveal),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: <Widget>[
                if (closest != null)
                  Expanded(
                    child: _TitleCard(
                      label: l10n.timeLord,
                      entry: closest,
                      accent: true,
                      icon: Icons.schedule,
                    ),
                  ),
                if (closest != null && furthest != null)
                  const SizedBox(width: AppSpacing.s8),
                if (furthest != null && (furthest.monthsOff ?? 0) > 0)
                  Expanded(
                    child: _TitleCard(
                      label: l10n.mostDelusional,
                      entry: furthest,
                      accent: false,
                      icon: Icons.explore_off_outlined,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  for (final entry in reveal.entries)
                    _TimelineResultRow(
                      entry: entry,
                      avatar:
                          state.players
                              .where((player) => player.id == entry.playerId)
                              .firstOrNull
                              ?.avatar ??
                          '',
                      photoBase64: state.avatarPhotos[entry.playerId],
                    ),
                ],
              ),
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
    );
  }
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({
    required this.label,
    required this.entry,
    required this.accent,
    required this.icon,
  });

  final String label;
  final TimelineEntry entry;
  final bool accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final off = entry.monthsOff ?? 0;
    final guess = entry.year == null
        ? l10n.noGuess
        : monthYear(l10n, entry.year!, entry.month ?? 1);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: accent ? colors.accent : colors.ink3),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: accent ? colors.accent : colors.ink2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            entry.playerName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '$guess · ${off == 0 ? l10n.exact : l10n.offBy(monthDistance(l10n, off))}',
            style: TextStyle(fontSize: 10, color: colors.ink2),
          ),
        ],
      ),
    );
  }
}

class _TimelineResultRow extends StatelessWidget {
  const _TimelineResultRow({
    required this.entry,
    this.avatar = '',
    this.photoBase64,
  });

  final TimelineEntry entry;
  final String avatar;
  final String? photoBase64;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final guessedDate = entry.year == null
        ? l10n.noGuess
        : monthYear(l10n, entry.year!, entry.month ?? 1);
    final guess = entry.isOwner ? l10n.yourPhotoDate(guessedDate) : guessedDate;
    final off = entry.timedOut || entry.year == null
        ? ''
        : entry.monthsOff == 0
        ? l10n.exact
        : l10n.offBy(monthDistance(l10n, entry.monthsOff ?? 0));
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: Row(
        children: <Widget>[
          PlayerAvatar(
            initial: entry.playerName,
            avatar: avatar,
            photoBase64: photoBase64,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.playerName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$guess${off.isEmpty ? '' : ' · $off'}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: colors.ink2),
                ),
              ],
            ),
          ),
          Text(
            '+${entry.points}',
            style: tabularFigures(
              TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: entry.points > 0 ? colors.ink : colors.ink3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineChart extends StatefulWidget {
  const _TimelineChart({required this.reveal});

  final TimelineReveal reveal;

  @override
  State<_TimelineChart> createState() => _TimelineChartState();
}

class _TimelineChartState extends State<_TimelineChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final reveal = widget.reveal;
    final years = <int>[
      reveal.actualYear,
      for (final entry in reveal.entries)
        if (entry.year != null) entry.year!,
    ];
    var minYear = years.reduce(min) - 1;
    var maxYear = years.reduce(max) + 1;
    if (maxYear - minYear < 4) {
      minYear -= 1;
      maxYear += 1;
    }
    final totalMonths = (maxYear - minYear + 1) * 12;

    double fraction(int year, int month) =>
        ((year - minYear) * 12 + (month - 1)) / totalMonths;

    final guesses = <TimelineEntry>[
      for (final entry in reveal.entries)
        if (entry.year != null && !entry.isOwner) entry,
    ];
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rCard),
        border: Border.all(color: colors.hairline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth - 16;
          final trackY = 150.0;
          return Stack(
            children: <Widget>[
              Positioned(
                left: 8,
                right: 8,
                top: trackY,
                child: Container(height: 2, color: colors.hairline),
              ),
              for (final year in <int>[
                minYear,
                (minYear + maxYear) ~/ 2,
                maxYear,
              ])
                Positioned(
                  left: 8 + fraction(year, 1) * width,
                  top: trackY + 8,
                  child: Text(
                    '$year',
                    style: tabularFigures(
                      TextStyle(fontSize: 10, color: colors.ink3),
                    ),
                  ),
                ),
              for (var i = 0; i < guesses.length; i++)
                _pin(
                  context,
                  entry: guesses[i],
                  width: width,
                  trackY: trackY,
                  fraction: fraction,
                  index: i,
                ),
              _actualPin(
                context,
                width: width,
                trackY: trackY,
                fraction: fraction,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pin(
    BuildContext context, {
    required TimelineEntry entry,
    required double width,
    required double trackY,
    required double Function(int year, int month) fraction,
    required int index,
  }) {
    final colors = WhoTookColors.of(context);
    final x = 8 + fraction(entry.year!, entry.month ?? 1) * width;
    final row = index % 2;
    final top = 40.0 - row * 34;
    final start = 0.12 + (index * 0.1);
    final end = (start + 0.45).clamp(0.0, 0.95);
    return Positioned(
      left: x - 24,
      top: top,
      width: 48,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = CurvedAnimation(
            parent: _controller,
            curve: Interval(start, end, curve: Curves.easeOutBack),
          ).value;
          return Opacity(
            opacity: t.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, -18 * (1 - t)),
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PlayerAvatar(initial: entry.playerName, size: 26),
            const SizedBox(height: 2),
            Text(
              entry.playerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: colors.ink2,
              ),
            ),
            Text(
              '${monthShort(context.l10n, entry.month ?? 1)} ${entry.year}',
              maxLines: 1,
              style: TextStyle(fontSize: 8, color: colors.ink3),
            ),
            Container(
              width: 1,
              height: max(0.0, trackY - top - 46),
              color: colors.hairline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actualPin(
    BuildContext context, {
    required double width,
    required double trackY,
    required double Function(int year, int month) fraction,
  }) {
    final colors = WhoTookColors.of(context);
    final reveal = widget.reveal;
    final x = 8 + fraction(reveal.actualYear, reveal.actualMonth) * width;
    return Positioned(
      left: x - 34,
      top: 2,
      width: 68,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.72, 1, curve: Curves.easeOut),
          ).value;
          return Opacity(
            opacity: t.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, -12 * (1 - t)),
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(AppRadii.rSm),
              ),
              child: Text(
                monthYear(context.l10n, reveal.actualYear, reveal.actualMonth),
                style: tabularFigures(
                  TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 9,
                    color: colors.onAccent,
                  ),
                ),
              ),
            ),
            Container(width: 2, height: 14, color: colors.accent),
          ],
        ),
      ),
    );
  }
}
