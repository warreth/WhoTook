import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

/// The finish line: a champion print, a two-step podium and one burst of
/// paper confetti. The animation runs once and stops, so nothing loops.
class PodiumScreen extends ConsumerStatefulWidget {
  const PodiumScreen({super.key});

  @override
  ConsumerState<PodiumScreen> createState() => _PodiumScreenState();
}

class _PodiumScreenState extends ConsumerState<PodiumScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stage;
  late final List<_ConfettiPiece> _confetti = _buildConfetti();

  @override
  void initState() {
    super.initState();
    _stage = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _stage.value = 1;
    }
  }

  @override
  void dispose() {
    _stage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final board = state.leaderboard;
    final top = board.take(3).toList();
    final champion = top.isEmpty ? null : top.first;
    final runners = top.skip(1).toList();

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
            SizedBox(
              height: 304,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ConfettiPainter(
                          pieces: _confetti,
                          progress: _stage,
                          colors: colors,
                        ),
                      ),
                    ),
                  ),
                  if (champion != null)
                    Align(
                      alignment: Alignment.topCenter,
                      child: ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _stage,
                          curve: const Interval(
                            0,
                            0.55,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                        child: _ChampionPrint(player: champion),
                      ),
                    ),
                  if (runners.isNotEmpty)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          for (var i = 0; i < runners.length; i++)
                            SizedBox(
                              width: 140,
                              child: _RunnerUp(
                                player: runners[i],
                                place: i + 2,
                                topScore: champion?.score ?? 0,
                                stage: _stage,
                                delay: i == 0 ? 0.18 : 0.28,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
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
                label: 'One more round (5)',
                icon: Icons.replay,
                onPressed: () => unawaited(coordinator.extendMatch()),
              ),
              const SizedBox(height: AppSpacing.s12),
              SecondaryButton(
                label: 'Play again',
                onPressed: () => unawaited(coordinator.playAgain()),
              ),
              const SizedBox(height: AppSpacing.s12),
              SecondaryButton(
                label: 'Leave',
                onPressed: () => unawaited(coordinator.leaveMatch()),
              ),
            ] else
              NoticeBanner(
                message: 'Waiting for the host',
                icon: Icons.hourglass_empty,
              ),
            if (state.screenshotAlerts.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.s16),
              NoticeBanner(
                message: 'Screenshots: ${state.screenshotAlerts.length}',
                icon: Icons.camera_alt_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChampionPrint extends StatelessWidget {
  const _ChampionPrint({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Semantics(
      label: 'Champion ${player.name}, ${player.score} points',
      child: Transform.rotate(
        angle: -0.022,
        child: Container(
          width: 244,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            AppSpacing.s12,
            AppSpacing.s16,
            AppSpacing.s12,
          ),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppRadii.rCard),
            border: Border.all(color: colors.hairline),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.ink.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: IgnorePointer(
                  child: CropFrameOverlay(
                    color: colors.ink3,
                    inset: 2,
                    armLength: 10,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      PlayerAvatar(
                        initial: player.name,
                        isHost: player.isHost,
                        size: 42,
                      ),
                      const Spacer(),
                      Transform.rotate(
                        angle: 0.06,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.accent),
                            borderRadius: BorderRadius.circular(AppRadii.rSm),
                          ),
                          child: Text(
                            'CHAMPION',
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 9,
                              letterSpacing: 0.9,
                              color: colors.accent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    player.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${player.score} pts',
                    style: tabularFigures(
                      TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: colors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Container(
                    width: 34,
                    height: 3,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunnerUp extends StatelessWidget {
  const _RunnerUp({
    required this.player,
    required this.place,
    required this.topScore,
    required this.stage,
    required this.delay,
  });

  final Player player;
  final int place;
  final int topScore;
  final Animation<double> stage;
  final double delay;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final share = topScore <= 0 ? 0.0 : player.score / topScore;
    final height = (44 + 58 * share).clamp(44.0, 102.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
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
        AnimatedBuilder(
          animation: stage,
          builder: (context, _) {
            final raw = ((stage.value - delay) / (0.86 - delay)).clamp(
              0.0,
              1.0,
            );
            final value = Curves.easeOutCubic.transform(raw);
            return Container(
              height: height * value,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: colors.raised,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.rSm),
                ),
                border: Border.all(color: colors.hairline),
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 6,
                    left: 0,
                    right: 0,
                    child: Text(
                      '$place',
                      textAlign: TextAlign.center,
                      style: tabularFigures(
                        TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 11,
                          color: colors.ink3,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 2,
                    child: Text(
                      '$place',
                      textAlign: TextAlign.center,
                      style: tabularFigures(
                        TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 44,
                          height: 1,
                          color: colors.ink3.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
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

class _ConfettiPiece {
  const _ConfettiPiece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.rotation,
    required this.spin,
    required this.phase,
    required this.tone,
    required this.circle,
  });

  final double x;
  final double delay;
  final double speed;
  final double size;
  final double rotation;
  final double spin;
  final double phase;
  final int tone;
  final bool circle;
}

List<_ConfettiPiece> _buildConfetti() {
  final random = Random(14);
  return <_ConfettiPiece>[
    for (var i = 0; i < 34; i++)
      _ConfettiPiece(
        x: random.nextDouble(),
        delay: random.nextDouble() * 0.22,
        speed: 0.62 + random.nextDouble() * 0.5,
        size: 4 + random.nextDouble() * 5,
        rotation: random.nextDouble() * pi,
        spin: (random.nextDouble() - 0.5) * 5,
        phase: random.nextDouble() * 6,
        tone: random.nextInt(4),
        circle: random.nextInt(5) == 0,
      ),
  ];
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.pieces,
    required this.progress,
    required this.colors,
  }) : super(repaint: progress);

  final List<_ConfettiPiece> pieces;
  final Animation<double> progress;
  final WhoTookColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1) return;
    final palette = <Color>[
      colors.accent,
      colors.ink,
      colors.ink3,
      colors.positive,
    ];
    for (final piece in pieces) {
      final local = ((t - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -16 + local * (size.height + 28) * piece.speed;
      final x = piece.x * size.width + sin(local * 9 + piece.phase) * 10;
      final opacity = (1 - local).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.rotation + local * piece.spin);
      final paint = Paint()
        ..color = palette[piece.tone].withValues(alpha: opacity * 0.9);
      if (piece.circle) {
        canvas.drawCircle(Offset.zero, piece.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: piece.size,
              height: piece.size * 0.55,
            ),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.colors != colors || oldDelegate.pieces != pieces;
}
