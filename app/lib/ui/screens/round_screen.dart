import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/game_audio_service.dart';
import '../../core/models/models.dart';
import '../../core/theme/game_skin.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/game_background.dart';
import '../widgets/game_widgets.dart';
import '../widgets/host_controls.dart';

/// One photo, one timer, and every player in the room as a button, including
/// yourself, so a glance at a screen never gives the owner away.
class RoundScreen extends ConsumerWidget {
  const RoundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final reveal = state.lastReveal;
    final showingReveal = state.phase == RoundPhase.reveal && reveal != null;
    final showingCountdown = state.phase == RoundPhase.countdown;
    final roundNumber = showingReveal ? reveal.roundNumber : state.currentRound;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameBackdrop(
        mode: state.activeMode,
        child: SafeArea(
          child: ScreenBody(
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
                              ? l10n.roundOf(roundNumber, state.totalRounds)
                              : l10n.whoTookThis,
                          style: gameDisplay(size: 28, color: colors.ink),
                        ),
                      ),
                      const HostControlsButton(),
                      FrameCounter(
                        current: roundNumber,
                        total: state.totalRounds,
                        label: l10n.roundBadge(roundNumber, state.totalRounds),
                      ),
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
                        seconds: ((state.remainingMs + 999) ~/ 1000).clamp(
                          1,
                          9,
                        ),
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
                          isPanorama: state.activePhotoIsPanorama,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    if (showingReveal)
                      _RevealBlock(
                        reveal: reveal,
                        players: state.players,
                        avatarPhotos: state.avatarPhotos,
                        localPlayerId: state.localPlayerId,
                      )
                    else ...<Widget>[
                      const SizedBox(height: AppSpacing.s12),
                      PanicTimerBar(
                        remainingMs: state.remainingMs,
                        totalMs: (state.config.roundSeconds * 1000).clamp(
                          1,
                          60000,
                        ),
                        label: l10n.tapNameToLock,
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      _GuessGrid(
                        options: state.activeRoundOptions,
                        avatarPhotos: state.avatarPhotos,
                        lockedOwnerId: state.lockedGuessOwnerId,
                        onGuess: (ownerId) {
                          unawaited(GameHaptics.instance.selection());
                          unawaited(GameAudioService.instance.tap());
                          unawaited(
                            state.isHosting
                                ? coordinator.submitGuess(ownerId)
                                : coordinator.clientSubmitGuess(ownerId),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      const SizedBox(height: AppSpacing.s8),
                      if (state.lockedGuessOwnerId != null)
                        Text(
                          l10n.lockedInWaiting,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: colors.ink2),
                        ),
                    ],
                  ],
                ],
              ),
            ),
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
    final l10n = context.l10n;
    return Center(
      child: Semantics(
        liveRegion: true,
        label: l10n.countdown,
        value: l10n.countdownSeconds(seconds),
        child: SurfaceCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s24,
            vertical: AppSpacing.s32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                l10n.getReady,
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
                l10n.tapWhoTook,
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
  const _PhotoFrame({super.key, required this.bytes, this.isPanorama = false});

  final Uint8List? bytes;
  final bool isPanorama;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rCard),
        border: Border.all(color: colors.ink, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.ink,
            blurRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.s8),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.rSm),
            child: _Photo(bytes: bytes, isPanorama: isPanorama),
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
  const _Photo({required this.bytes, this.isPanorama = false});

  final Uint8List? bytes;
  final bool isPanorama;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final data = bytes;
    if (data == null || data.isEmpty) {
      return const PhotoShimmer();
    }
    return ColoredBox(
      color: colors.ink,
      child: GamePhoto(
        bytes: data,
        fit: isPanorama ? BoxFit.contain : BoxFit.cover,
      ),
    );
  }
}

class _GuessGrid extends StatelessWidget {
  const _GuessGrid({
    required this.options,
    required this.avatarPhotos,
    required this.lockedOwnerId,
    required this.onGuess,
  });

  final List<Player> options;
  final Map<String, String> avatarPhotos;
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
            color: picked ? colors.ink : (dimmed ? colors.raised : colors.card),
            borderRadius: BorderRadius.circular(AppRadii.rControl),
            border: Border.all(color: colors.ink, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.ink,
                blurRadius: 0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              PlayerAvatar(
                initial: player.name,
                avatar: player.avatar,
                photoBase64: avatarPhotos[player.id],
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
    required this.avatarPhotos,
    required this.localPlayerId,
  });

  final RoundReveal reveal;
  final List<Player> players;
  final Map<String, String> avatarPhotos;
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
      unawaited(GameAudioService.instance.tap());
      unawaited(GameHaptics.instance.light());
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
    final l10n = context.l10n;
    final reveal = widget.reveal;
    final owner = widget.players
        .where((p) => p.id == reveal.ownerId)
        .firstOrNull;
    final fooled = reveal.guesses
        .where(
          (g) => !g.isOwnPhoto && !g.isCorrect && g.guessedOwnerId.isNotEmpty,
        )
        .length;
    final missed = reveal.guesses
        .where((g) => !g.isOwnPhoto && g.guessedOwnerId.isEmpty)
        .length;
    final localId = widget.localPlayerId;
    final guess = localId == null
        ? null
        : reveal.guesses.where((g) => g.playerId == localId).firstOrNull;
    final ownPhoto = localId != null && reveal.ownerId == localId;
    final maxScore = widget.players.isEmpty
        ? 0
        : widget.players.map((player) => player.score).reduce(math.max);

    var result = '';
    var tone = colors.ink2;
    var icon = Icons.remove_circle_outline;
    if (localId != null) {
      if (guess == null || guess.guessedOwnerId.isEmpty) {
        result = l10n.noAnswer;
        tone = colors.negative;
        icon = Icons.timer_off_outlined;
      } else if (guess.isCorrect) {
        result = ownPhoto
            ? l10n.yourPhotoYouGotIt(guess.pointsAwarded)
            : l10n.youGotIt(guess.pointsAwarded);
        tone = colors.positive;
        icon = Icons.check_circle_outline;
      } else {
        result = ownPhoto ? l10n.yourPhotoWrongGuess : l10n.wrongGuess;
        tone = colors.negative;
        icon = Icons.cancel_outlined;
      }
    }
    final summary = <String>[
      if (fooled > 0) l10n.playersFooled(fooled),
      if (missed > 0) l10n.playersDidNotAnswer(missed),
    ].join(' · ');

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
                    avatar: _shown ? (owner?.avatar ?? '') : '',
                    photoBase64: _shown && owner != null
                        ? widget.avatarPhotos[owner.id]
                        : null,
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
                              ? l10n.shotBy(owner?.name ?? l10n.player)
                              : l10n.whoTookIt,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _shown
                              ? (summary.isEmpty
                                    ? l10n.everyoneGotItRight
                                    : summary)
                              : l10n.revealing,
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
                      player: _playerFor(context, reveal.guesses[i]),
                      photoBase64:
                          widget.avatarPhotos[_playerFor(
                            context,
                            reveal.guesses[i],
                          ).id],
                      score: _playerFor(context, reveal.guesses[i]).score,
                      delta:
                          reveal.scoreDeltas[_playerFor(
                            context,
                            reveal.guesses[i],
                          ).id],
                      streak: reveal
                          .streaks[_playerFor(context, reveal.guesses[i]).id],
                      highlighted: reveal.guesses[i].isOwnPhoto,
                      maxScore: maxScore,
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
                    _microLabel(context, reveal.microAward!),
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

  Player _playerFor(BuildContext context, GuessRecord guess) {
    return widget.players.firstWhere(
      (p) => p.id == guess.playerId,
      orElse: () => Player(id: guess.playerId, name: context.l10n.player),
    );
  }

  String _microLabel(BuildContext context, MicroAward award) {
    final l10n = context.l10n;
    return switch (award.kind) {
      MicroAwardKind.fastestGuess => l10n.fastestAward(
        award.playerName ?? '',
        ((award.elapsedMs ?? 0) / 1000).toStringAsFixed(1),
      ),
      MicroAwardKind.nobodyGuessed => l10n.nobodyGuessed,
      MicroAwardKind.everyoneGuessed => l10n.everyoneNailedIt,
      MicroAwardKind.screenshot => l10n.screenshotBy(award.playerName ?? ''),
    };
  }
}
