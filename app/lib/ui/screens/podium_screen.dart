import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

class PodiumScreen extends ConsumerWidget {
  const PodiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final board = state.leaderboard;
    final top = board.take(3).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s20,
            AppSpacing.s16,
            AppSpacing.s20,
            AppSpacing.s32,
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Podium',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.4,
                      color: colors.ink,
                    ),
                  ),
                ),
                Text(
                  '${state.totalRounds} rounds',
                  style: tabularFigures(
                    TextStyle(fontSize: 12, color: colors.ink3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            SurfaceCard(
              child: SizedBox(
                height: 252,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (top.length > 1)
                      _PodiumBar(
                        player: top[1],
                        place: 2,
                        topScore: top[0].score,
                      ),
                    if (top.isNotEmpty)
                      _PodiumBar(
                        player: top[0],
                        place: 1,
                        topScore: top[0].score,
                      ),
                    if (top.length > 2)
                      _PodiumBar(
                        player: top[2],
                        place: 3,
                        topScore: top[0].score,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            if (state.awards.isNotEmpty)
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SectionLabel('Match awards'),
                    for (final award in state.awards) _AwardRow(award: award),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.s16),
            if (board.length > 3)
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (var i = 3; i < board.length; i++)
                      ScoreRow(
                        position: i + 1,
                        player: board[i],
                        score: board[i].score,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.s16),
            if (state.isHosting) ...<Widget>[
              PrimaryButton(
                label: 'Keep playing, 5 more rounds',
                onPressed: () => unawaited(coordinator.extendMatch()),
              ),
              const SizedBox(height: AppSpacing.s12),
              SecondaryButton(
                label: 'Play again with the same players',
                icon: Icons.replay,
                onPressed: () => unawaited(coordinator.playAgain()),
              ),
              const SizedBox(height: AppSpacing.s12),
              SecondaryButton(
                label: 'Leave the match',
                onPressed: () => unawaited(coordinator.leaveMatch()),
              ),
            ] else
              NoticeBanner(
                message: 'The host decides whether to play on',
                icon: Icons.hourglass_empty,
              ),
            if (state.screenshotAlerts.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.s16),
              NoticeBanner(
                message:
                    'Screenshots this match: ${state.screenshotAlerts.length}',
                icon: Icons.camera_alt_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PodiumBar extends StatelessWidget {
  const _PodiumBar({
    required this.player,
    required this.place,
    required this.topScore,
  });

  final Player player;
  final int place;
  final int topScore;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final tallest = 132.0;
    final share = topScore <= 0 ? 0.0 : player.score / topScore;
    final height = (56 + 76 * share).clamp(56.0, tallest);
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          PlayerAvatar(initial: player.name, isHost: player.isHost, size: 32),
          const SizedBox(height: AppSpacing.s8),
          Text(
            player.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            '${player.score}',
            style: tabularFigures(
              TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: colors.ink2,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: height),
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Container(
              height: value,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
              decoration: BoxDecoration(
                color: place == 1 ? colors.accent : colors.raised,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.rSm),
                ),
                border: Border.all(color: colors.hairline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AwardRow extends StatelessWidget {
  const _AwardRow({required this.award});

  final MatchAward award;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final (label, icon) = switch (award.kind) {
      MatchAwardKind.champion => ('Champion', Icons.emoji_events_outlined),
      MatchAwardKind.quickestDraw => ('Quickest draw', Icons.bolt_outlined),
      MatchAwardKind.unstoppable => ('Longest streak', Icons.trending_up),
      MatchAwardKind.masterOfMystery => (
        'Master of mystery',
        Icons.visibility_off_outlined,
      ),
      MatchAwardKind.paparazzi => ('Paparazzi', Icons.camera_alt_outlined),
      MatchAwardKind.smoothPlanter => (
        'Secret planter',
        Icons.local_florist_outlined,
      ),
    };
    final suffix = switch (award.kind) {
      MatchAwardKind.quickestDraw =>
        ' ${((award.value ?? 0) / 1000).toStringAsFixed(1)}s',
      MatchAwardKind.unstoppable => ' ${award.value}x',
      MatchAwardKind.masterOfMystery => ' ${award.value} pts',
      MatchAwardKind.paparazzi => ' ${award.value} frames',
      MatchAwardKind.smoothPlanter => ' fooled ${award.value}',
      MatchAwardKind.champion => '',
    };
    return SizedBox(
      height: 40,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: colors.ink3),
          const SizedBox(width: AppSpacing.s8),
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: colors.ink2),
            ),
          ),
          Expanded(
            child: Text(
              '${award.playerName}$suffix',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
