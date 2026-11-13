import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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
                      showingReveal
                          ? 'Round ${reveal.roundNumber} of ${state.totalRounds}'
                          : 'Who took this',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.3,
                        color: colors.ink,
                      ),
                    ),
                  ),
                  FrameCounter(
                    current: reveal?.roundNumber ?? state.currentRound,
                    total: state.totalRounds,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              _PhotoFrame(bytes: state.activePhotoBytes),
              const SizedBox(height: AppSpacing.s12),
              if (showingReveal)
                _RevealBlock(reveal: reveal, players: state.players)
              else ...<Widget>[
                const SizedBox(height: AppSpacing.s12),
                _TimerBar(
                  remainingMs: state.remainingMs,
                  totalMs: (state.config.roundSeconds * 1000).clamp(1, 60000),
                ),
                if (state.screenshotAlerts.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.s8),
                  NoticeBanner(
                    message:
                        '${state.screenshotAlerts.last.playerName} took a screenshot',
                    icon: Icons.camera_alt_outlined,
                  ),
                ],
                const SizedBox(height: AppSpacing.s12),
                _GuessGrid(
                  options: state.activeRoundOptions,
                  lockedOwnerId: state.lockedGuessOwnerId,
                  onGuess: (ownerId) => unawaited(
                    state.isHosting
                        ? coordinator.submitGuess(ownerId)
                        : coordinator.clientSubmitGuess(ownerId),
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Everyone sees the same names, including their own',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: colors.ink3),
                ),
                const Spacer(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 340),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadii.rCard),
          border: Border.all(color: colors.hairline),
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
                child: CropFrameOverlay(
                  color: colors.ink,
                  inset: 4,
                  armLength: 14,
                ),
              ),
            ],
          ),
        ),
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
              '$seconds s',
              style: tabularFigures(
                TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colors.ink,
                ),
              ),
            ),
            const Spacer(),
            Text(
              'Tap a name to lock in',
              style: TextStyle(fontSize: 12, color: colors.ink2),
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
              for (var column = 0; column < 2; column++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: column == 0 ? AppSpacing.s8 : 0,
                    ),
                    child: i + column < options.length
                        ? _guessButton(context, options[i + column])
                        : const SizedBox.shrink(),
                  ),
                ),
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
    return Material(
      color: picked ? colors.ink : colors.card,
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
                    color: picked ? colors.bg : colors.ink,
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

class _RevealBlock extends StatelessWidget {
  const _RevealBlock({required this.reveal, required this.players});

  final RoundReveal reveal;
  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final owner = players.where((p) => p.id == reveal.ownerId).firstOrNull;
    final fooled = reveal.guesses
        .where((g) => !g.isOwnPhoto && !g.isCorrect)
        .length;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SurfaceCard(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Row(
              children: <Widget>[
                PlayerAvatar(
                  initial: owner?.name ?? '?',
                  isHost: owner?.isHost ?? false,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Shot by ${owner?.name ?? 'someone'}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fooled == 0
                            ? 'Everyone got it right'
                            : fooled == 1
                            ? '1 player was fooled'
                            : '$fooled players were fooled',
                        style: TextStyle(fontSize: 12, color: colors.ink2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Expanded(
            child: SurfaceCard(
              padding: EdgeInsets.zero,
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  for (var i = 0; i < reveal.guesses.length; i++)
                    ScoreRow(
                      position: i + 1,
                      player: _playerFor(reveal.guesses[i], players),
                      score: _playerFor(
                        reveal.guesses[i],
                        players,
                      ).score,
                      delta: reveal.scoreDeltas[_playerFor(
                        reveal.guesses[i],
                        players,
                      ).id],
                      streak: reveal.streaks[_playerFor(
                        reveal.guesses[i],
                        players,
                      ).id],
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
                Text(
                  _microLabel(reveal.microAward!),
                  style: TextStyle(fontSize: 12, color: colors.ink2),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Player _playerFor(GuessRecord guess, List<Player> players) {
    return players.firstWhere(
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
