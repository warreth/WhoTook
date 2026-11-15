import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

/// One photo, one timer, and every player in the room as a button, including
/// yourself, so a glance at a screen never gives the owner away.
class RoundScreen extends ConsumerWidget {
  const RoundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final reveal = state.lastReveal;
    final showingReveal = state.phase == RoundPhase.reveal && reveal != null;
    final showingCountdown = state.phase == RoundPhase.countdown;
    final roundNumber = showingReveal ? reveal.roundNumber : state.currentRound;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s20,
            AppSpacing.s12,
            AppSpacing.s20,
            AppSpacing.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      showingReveal || showingCountdown
                          ? 'Round $roundNumber of ${state.totalRounds}'
                          : 'Who took this',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.3,
                        color: colors.ink,
                      ),
                    ),
                  ),
                  FrameCounter(current: roundNumber, total: state.totalRounds),
                ],
              ),
              if (state.totalRounds > 0) ...<Widget>[
                const SizedBox(height: AppSpacing.s8),
                ProgressSegments(
                  current: roundNumber,
                  total: state.totalRounds,
                ),
              ],
              const SizedBox(height: AppSpacing.s12),
              if (showingCountdown)
                Expanded(
                  child: _CountdownView(
                    seconds: ((state.remainingMs + 999) ~/ 1000).clamp(1, 9),
                  ),
                )
              else ...<Widget>[
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    child: _PhotoFrame(
                      key: ValueKey<int>(state.currentRound),
                      bytes: state.activePhotoBytes,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                if (showingReveal)
                  _RevealBlock(
                    reveal: reveal,
                    players: state.players,
                    localPlayerId: state.localPlayerId,
                  )
                else ...<Widget>[
                  const SizedBox(height: AppSpacing.s12),
                  _TimerBar(
                    remainingMs: state.remainingMs,
                    totalMs: (state.config.roundSeconds * 1000).clamp(1, 60000),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  _GuessGrid(
                    options: state.activeRoundOptions,
                    lockedOwnerId: state.lockedGuessOwnerId,
                    onGuess: (ownerId) {
                      unawaited(HapticFeedback.selectionClick());
                      unawaited(
                        state.isHosting
                            ? coordinator.submitGuess(ownerId)
                            : coordinator.clientSubmitGuess(ownerId),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  if (state.screenshotAlerts.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 14,
                          color: colors.ink2,
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Flexible(
                          child: Text(
                            '${state.screenshotAlerts.last.playerName} took a screenshot',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: colors.ink2),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    state.lockedGuessOwnerId == null
                        ? 'Same names on every phone.'
                        : 'Locked in, waiting for the others.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: colors.ink2),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The gap between "photos are ready" and the first frame. A calm numeral, no
/// empty photo box and no ticking timer that is not running yet.
class _CountdownView extends StatelessWidget {
  const _CountdownView({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Center(
      child: Semantics(
        liveRegion: true,
        label: 'Countdown',
        value: '$seconds seconds',
        child: SurfaceCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s24,
            vertical: AppSpacing.s32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Get ready',
                style: TextStyle(fontSize: 15, color: colors.ink2),
              ),
              const SizedBox(height: AppSpacing.s8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: Tween<double>(begin: 0.88, end: 1).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Text(
                  '$seconds',
                  key: ValueKey<int>(seconds),
                  style: tabularFigures(
                    TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 48,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                      color: colors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                'Tap who took the photo as soon as it appears',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.ink2, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({super.key, required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rCard),
        border: Border.all(color: colors.hairline),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x241F1B16),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.s8),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.rSm),
            child: _Photo(bytes: bytes),
          ),
          Positioned.fill(
            child: CropFrameOverlay(color: colors.ink, inset: 4, armLength: 14),
          ),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final data = bytes;
    if (data == null || data.isEmpty) {
      return Container(
        color: colors.raised,
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined, size: 28, color: colors.ink3),
      );
    }
    return Image.memory(
      data,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) => Container(
        color: colors.raised,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 28,
          color: colors.ink3,
        ),
      ),
    );
  }
}

class _TimerBar extends StatelessWidget {
  const _TimerBar({required this.remainingMs, required this.totalMs});

  final int remainingMs;
  final int totalMs;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final fraction = remainingMs <= 0
        ? 0.0
        : (remainingMs / totalMs).clamp(0.0, 1.0);
    final seconds = (remainingMs / 1000).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '$seconds s left',
              style: tabularFigures(
                TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colors.ink,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                'Tap a name to lock in',
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.ink2),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Semantics(
          label: 'Seconds left to guess',
          value: seconds,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: colors.raised,
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _GuessGrid extends StatelessWidget {
  const _GuessGrid({
    required this.options,
    required this.lockedOwnerId,
    required this.onGuess,
  });

  final List<Player> options;
  final String? lockedOwnerId;
  final ValueChanged<String> onGuess;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s8),
          child: Row(
            children: <Widget>[
              for (var column = 0; column < 2; column++) ...<Widget>[
                if (column == 1) const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: i + column < options.length
                      ? _guessButton(context, options[i + column])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _guessButton(BuildContext context, Player player) {
    final colors = WhoTookColors.of(context);
    final picked = lockedOwnerId == player.id;
    final dimmed = lockedOwnerId != null && !picked;
    return Material(
      color: picked ? colors.ink : (dimmed ? colors.raised : colors.card),
      borderRadius: BorderRadius.circular(AppRadii.rControl),
      child: InkWell(
        onTap: lockedOwnerId == null ? () => onGuess(player.id) : null,
        borderRadius: BorderRadius.circular(AppRadii.rControl),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.rControl),
            border: Border.all(color: colors.hairline),
          ),
          child: Row(
            children: <Widget>[
              PlayerAvatar(
                initial: player.name,
                isHost: player.isHost,
                size: 26,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  player.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: picked
                        ? colors.bg
                        : (dimmed ? colors.ink3 : colors.ink),
                  ),
                ),
              ),
              if (picked) Icon(Icons.check, size: 16, color: colors.bg),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevealBlock extends StatefulWidget {
  const _RevealBlock({
    required this.reveal,
    required this.players,
    required this.localPlayerId,
  });

  final RoundReveal reveal;
  final List<Player> players;
  final String? localPlayerId;

  @override
  State<_RevealBlock> createState() => _RevealBlockState();
}

class _RevealBlockState extends State<_RevealBlock> {
  bool _shown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleReveal();
  }

  @override
  void didUpdateWidget(covariant _RevealBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reveal.roundNumber != widget.reveal.roundNumber) {
      _scheduleReveal();
    }
  }

  void _scheduleReveal() {
    _timer?.cancel();
    _shown = false;
    _timer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _shown = true);
      unawaited(SystemSound.play(SystemSoundType.click));
      unawaited(HapticFeedback.lightImpact());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final reveal = widget.reveal;
    final owner = widget.players
        .where((p) => p.id == reveal.ownerId)
        .firstOrNull;
    final fooled = reveal.guesses
        .where((g) => !g.isOwnPhoto && !g.isCorrect)
        .length;
    final localId = widget.localPlayerId;
    final guess = localId == null
        ? null
        : reveal.guesses.where((g) => g.playerId == localId).firstOrNull;
    final ownPhoto = localId != null && reveal.ownerId == localId;

    var result = '';
    var tone = colors.ink2;
    var icon = Icons.remove_circle_outline;
    if (localId != null) {
      if (ownPhoto) {
        final fooledOnOwn = reveal.guesses
            .where(
              (g) =>
                  !g.isOwnPhoto && !g.isCorrect && g.guessedOwnerId.isNotEmpty,
            )
            .length;
        result = fooledOnOwn == 0
            ? 'Your photo. Nobody was fooled.'
            : 'Your photo. $fooledOnOwn fooled.';
        tone = fooledOnOwn > 0 ? colors.positive : colors.ink2;
        icon = Icons.local_florist_outlined;
      } else if (guess == null) {
        result = 'Out of time.';
        tone = colors.negative;
        icon = Icons.timer_off_outlined;
      } else if (guess.isCorrect) {
        result = 'You got it. +${guess.pointsAwarded}';
        tone = colors.positive;
        icon = Icons.check_circle_outline;
      } else {
        result = 'You were fooled.';
        tone = colors.negative;
        icon = Icons.cancel_outlined;
      }
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            liveRegion: true,
            child: SurfaceCard(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Row(
                children: <Widget>[
                  PlayerAvatar(
                    initial: _shown ? (owner?.name ?? '?') : '?',
                    isHost: _shown && (owner?.isHost ?? false),
                    size: 32,
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _shown
                              ? 'Shot by ${owner?.name ?? 'someone'}'
                              : 'Who took it?',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _shown
                              ? (fooled == 0
                                    ? 'Everyone got it right'
                                    : fooled == 1
                                    ? '1 player was fooled'
                                    : '$fooled players were fooled')
                              : 'Revealing...',
                          style: TextStyle(fontSize: 12, color: colors.ink2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          SizedBox(
            height: 24,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _shown && localId != null
                  ? Row(
                      key: ValueKey<String>('result-${reveal.roundNumber}'),
                      children: <Widget>[
                        Icon(icon, size: 15, color: tone),
                        const SizedBox(width: AppSpacing.s4),
                        Flexible(
                          child: Text(
                            result,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: tone,
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Expanded(
            child: SurfaceCard(
              padding: EdgeInsets.zero,
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  for (var i = 0; i < reveal.guesses.length; i++)
                    ScoreRow(
                      position: i + 1,
                      player: _playerFor(reveal.guesses[i]),
                      score: _playerFor(reveal.guesses[i]).score,
                      delta:
                          reveal.scoreDeltas[_playerFor(reveal.guesses[i]).id],
                      streak: reveal.streaks[_playerFor(reveal.guesses[i]).id],
                      highlighted: reveal.guesses[i].isOwnPhoto,
                    ),
                ],
              ),
            ),
          ),
          if (reveal.microAward != null) ...<Widget>[
            const SizedBox(height: AppSpacing.s8),
            Row(
              children: <Widget>[
                Icon(Icons.bolt_outlined, size: 14, color: colors.ink2),
                const SizedBox(width: AppSpacing.s4),
                Flexible(
                  child: Text(
                    _microLabel(reveal.microAward!),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colors.ink2),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Player _playerFor(GuessRecord guess) {
    return widget.players.firstWhere(
      (p) => p.id == guess.playerId,
      orElse: () => Player(id: guess.playerId, name: 'Player'),
    );
  }

  String _microLabel(MicroAward award) {
    return switch (award.kind) {
      MicroAwardKind.fastestGuess =>
        'Fastest: ${award.playerName ?? ''} ${((award.elapsedMs ?? 0) / 1000).toStringAsFixed(1)}s',
      MicroAwardKind.nobodyGuessed => 'Nobody guessed it',
      MicroAwardKind.everyoneGuessed => 'Everyone nailed it',
      MicroAwardKind.screenshot => 'Screenshot by ${award.playerName ?? ''}',
    };
  }
}
