import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/game_audio_service.dart';
import '../../core/media/photo_memory_cache.dart';
import '../../core/models/models.dart';
import '../../core/theme/game_skin.dart';
import '../../core/theme/responsive_game_layout.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/game_background.dart';
import '../../ui/widgets/game_widgets.dart';
import '../../ui/widgets/host_controls.dart';

/// Adrenaline photo guessing: a detail opens up over fifteen seconds while the
/// room races to lock the right photographer. A wrong early guess is out.
class ZoomOutScreen extends ConsumerStatefulWidget {
  const ZoomOutScreen({super.key});

  @override
  ConsumerState<ZoomOutScreen> createState() => _ZoomOutScreenState();
}

class _ZoomOutScreenState extends ConsumerState<ZoomOutScreen> {
  @override
  Widget build(BuildContext context) {
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final colors = WhoTookColors.of(context);
    final layout = ResponsiveGameLayout.of(context);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameBackdrop(
        mode: GameMode.zoomOut,
        child: SafeArea(
          child: ScreenBody(
            maxWidth: layout.isTablet ? 560 : 720,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                layout.pagePadding,
                layout.sectionGap,
                layout.pagePadding,
                layout.isCompactHeight ? 8 : AppSpacing.s16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          state.phase == RoundPhase.reveal
                              ? l10n.zoomFullPhoto
                              : l10n.modeZoomOut,
                          style: gameDisplay(
                            size: layout.titleSize,
                            color: colors.ink,
                          ),
                        ),
                      ),
                      const HostControlsButton(),
                      FrameCounter(
                        current: state.currentRound,
                        total: state.totalRounds,
                        label: l10n.roundBadge(
                          state.currentRound,
                          state.totalRounds,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  ProgressSegments(
                    current: state.currentRound,
                    total: state.totalRounds,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  if (state.phase == RoundPhase.countdown)
                    Expanded(
                      child: _ZoomCountdown(
                        seconds: ((state.remainingMs + 999) ~/ 1000).clamp(
                          1,
                          9,
                        ),
                      ),
                    )
                  else if (state.phase == RoundPhase.reveal)
                    Expanded(child: _ZoomReveal(state: state))
                  else ...<Widget>[
                    Expanded(child: _ZoomPhoto(state: state)),
                    const SizedBox(height: AppSpacing.s8),
                    PanicTimerBar(
                      remainingMs: state.remainingMs,
                      totalMs: state.phaseDurationMs,
                      label: l10n.modeZoomOut,
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    _ZoomLockFeedback(state: state),
                    const SizedBox(height: AppSpacing.s4),
                    _ZoomAnswerGrid(
                      options: state.activeRoundOptions,
                      avatarPhotos: state.avatarPhotos,
                      lockedOwnerId: state.lockedGuessOwnerId,
                      buttonHeight: layout.controlHeight,
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

class _ZoomCountdown extends StatelessWidget {
  const _ZoomCountdown({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return Center(
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s32,
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
            Text('$seconds', style: gameDisplay(size: 56, color: colors.ink)),
          ],
        ),
      ),
    );
  }
}

class _ZoomPhoto extends StatelessWidget {
  const _ZoomPhoto({required this.state});

  final MatchUiState state;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final total = state.phaseDurationMs > 0 ? state.phaseDurationMs : 15000;
    final remaining = state.remainingMs.clamp(0, total);
    final scale = (1 + 5 * (remaining / total)).clamp(1.0, 6.0);
    final potential = 300 + (700 * remaining) ~/ total;
    final photoId = state.activePhotoId ?? '';
    final bytes =
        state.activePhotoBytes ?? PhotoMemoryCache.instance.bytesFor(photoId);
    final anchorX = state.zoomAnchorX.clamp(0.25, 0.75);
    final anchorY = state.zoomAnchorY.clamp(0.25, 0.75);

    return Semantics(
      container: true,
      image: true,
      label: l10n.gamePhoto,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.rCard),
              border: Border.all(color: colors.ink, width: 2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: colors.ink,
                  offset: const Offset(0, 5),
                  blurRadius: 0,
                ),
              ],
            ),
              clipBehavior: Clip.antiAlias,
              child: ClipRect(
                child: bytes == null
                    ? ColoredBox(
                        color: colors.raised,
                        child: Center(
                          child: Icon(
                            Icons.photo_outlined,
                            size: 42,
                            color: colors.ink3,
                          ),
                        ),
                      )
                    : Transform.scale(
                        scale: scale,
                        alignment: Alignment(anchorX * 2 - 1, anchorY * 2 - 1),
                        child: Image.memory(
                          bytes,
                          key: ValueKey<String>('zoom-$photoId'),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          semanticLabel: l10n.gamePhoto,
                        ),
                      ),
              ),
            ),
            Positioned(
              top: AppSpacing.s8,
              left: AppSpacing.s8,
              child: StickerBadge(
                label: '${scale.toStringAsFixed(1)}x',
                background: colors.ink,
                foreground: Colors.white,
                angle: -0.05,
                icon: Icons.zoom_in,
              ),
            ),
            Positioned(
              top: AppSpacing.s8,
              right: AppSpacing.s8,
              child: StickerBadge(
                label: l10n.zoomPotential(potential),
                background: GamePalette.gold,
                foreground: GamePalette.onGold,
                angle: 0.04,
              ),
            ),
          ],
        ),
    );
  }
}

class _ZoomLockFeedback extends StatefulWidget {
  const _ZoomLockFeedback({required this.state});

  final MatchUiState state;

  @override
  State<_ZoomLockFeedback> createState() => _ZoomLockFeedbackState();
}

class _ZoomLockFeedbackState extends State<_ZoomLockFeedback> {
  bool? _last;

  @override
  void didUpdateWidget(covariant _ZoomLockFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.state.lastGuessCorrect;
    if (next != null && next != _last) {
      _last = next;
      // Neutral feedback while others are still guessing so audio never leaks
      // whether a nearby player guessed right or got locked out.
      unawaited(GameAudioService.instance.pop());
      unawaited(GameHaptics.instance.light());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final l10n = context.l10n;
    if (state.lockedGuessOwnerId == null) {
      return const SizedBox.shrink();
    }
    final correct = state.lastGuessCorrect;
    final scale = (state.lockedGuessScale ?? 1).clamp(1.0, 6.0);
    final wrong = correct == false;
    return NoticeBanner(
      message: wrong
          ? l10n.zoomWrongLocked
          : l10n.zoomLockedIn('${scale.toStringAsFixed(1)}x'),
      icon: wrong ? Icons.close : Icons.check,
      tone: wrong ? StatusTone.warning : StatusTone.positive,
    );
  }
}

class _ZoomAnswerGrid extends StatelessWidget {
  const _ZoomAnswerGrid({
    required this.options,
    required this.avatarPhotos,
    required this.lockedOwnerId,
    required this.onGuess,
    required this.buttonHeight,
  });

  final List<Player> options;
  final Map<String, String> avatarPhotos;
  final String? lockedOwnerId;
  final ValueChanged<String> onGuess;
  final double buttonHeight;

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
                      ? _button(context, options[i + column])
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

  Widget _button(BuildContext context, Player player) {
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
          height: buttonHeight,
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
                    fontWeight: FontWeight.w600,
                    color: picked ? colors.bg : colors.ink,
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

class _ZoomReveal extends ConsumerWidget {
  const _ZoomReveal({required this.state});

  final MatchUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final coordinator = ref.read(matchCoordinatorProvider);
    final reveal = state.lastReveal;
    if (reveal == null) {
      return Center(child: CircularProgressIndicator(color: colors.accent));
    }
    final owner = state.players
        .where((player) => player.id == reveal.ownerId)
        .firstOrNull;
    final eagle =
        reveal.guesses
            .where(
              (guess) => guess.isCorrect && guess.playerId != reveal.ownerId,
            )
            .toList()
          ..sort((a, b) => a.elapsedMs.compareTo(b.elapsedMs));
    final first = eagle.firstOrNull;
    final eagleName = first == null
        ? ''
        : state.players
                  .where((player) => player.id == first.playerId)
                  .firstOrNull
                  ?.name ??
              l10n.player;
    final scale = first == null
        ? 1.0
        : (1 + 5 * (1 - first.elapsedMs / 15000)).clamp(1.0, 6.0);
    final photoId = reveal.photoId;
    final bytes =
        state.activePhotoBytes ?? PhotoMemoryCache.instance.bytesFor(photoId);
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      children: <Widget>[
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.rCard),
            border: Border.all(color: colors.ink, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.ink,
                offset: const Offset(0, 5),
                blurRadius: 0,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: bytes == null
              ? ColoredBox(color: colors.raised)
              : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: <Widget>[
            PlayerAvatar(
              initial: owner?.name ?? '',
              avatar: owner?.avatar ?? '',
              photoBase64: state.avatarPhotos[owner?.id],
              isHost: owner?.isHost ?? false,
              size: 36,
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                l10n.memePhotoFrom(owner?.name ?? l10n.player),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        NoticeBanner(
          message: first == null
              ? l10n.zoomNoEagleEye
              : l10n.zoomEagleEye(eagleName, '${scale.toStringAsFixed(1)}x'),
          icon: Icons.visibility_outlined,
        ),
        const SizedBox(height: AppSpacing.s12),
        _ZoomScores(reveal: reveal, state: state),
        const SizedBox(height: AppSpacing.s16),
        if (state.isHosting)
          GameButton(
            label: l10n.nextRound,
            icon: Icons.arrow_forward,
            onPressed: () => unawaited(coordinator.skipRound()),
            fullWidth: true,
          )
        else
          NoticeBanner(
            message: l10n.waitingForHostToContinue,
            icon: Icons.hourglass_empty,
          ),
      ],
    );
  }
}

class _ZoomScores extends StatelessWidget {
  const _ZoomScores({required this.reveal, required this.state});

  final RoundReveal reveal;
  final MatchUiState state;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final rows = <Widget>[];
    for (final player in state.players) {
      final delta = reveal.scoreDeltas[player.id] ?? 0;
      if (delta == 0) continue;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s4),
          child: Row(
            children: <Widget>[
              PlayerAvatar(
                initial: player.name,
                avatar: player.avatar,
                photoBase64: state.avatarPhotos[player.id],
                isHost: player.isHost,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  player.name,
                  style: TextStyle(fontSize: 13, color: colors.ink),
                ),
              ),
              Text(
                l10n.points(delta),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.positive,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}
