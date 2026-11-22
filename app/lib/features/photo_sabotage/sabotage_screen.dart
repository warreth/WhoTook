import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
import 'sabotage_art.dart';
import 'sabotage_painter.dart';
import 'sabotage_stroke_utils.dart';

/// Foto-Sabotage: draw on a friend's photo, swap up to five times, then let
/// the room vote. The photo itself never travels again; only small normalized
/// stroke JSON does.
class SabotageScreen extends ConsumerWidget {
  const SabotageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final colors = WhoTookColors.of(context);
    final layout = ResponsiveGameLayout.of(context);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameBackdrop(
        mode: GameMode.photoSabotage,
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
                          state.phase == RoundPhase.captionReveal
                              ? l10n.sabotageRevealTitle
                              : l10n.modePhotoSabotage,
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
                  Expanded(
                    child: switch (state.phase) {
                      RoundPhase.captionVoting => _SabotageVoting(state: state),
                      RoundPhase.captionReveal => _SabotageReveal(state: state),
                      _ => _buildEditor(context, state, coordinator),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(
    BuildContext context,
    MatchUiState state,
    MatchCoordinator coordinator,
  ) {
    final assignment = state.memeAssignment;
    if (assignment == null) {
      final l10n = context.l10n;
      return EmptyState(
        title: l10n.sabotageDrawTitle,
        body: l10n.sabotagePreparing,
      );
    }
    return _SabotageEditor(
      key: ValueKey<String>('sabotage-${assignment.photoId}'),
      state: state,
      assignment: assignment,
      onSwap: () => unawaited(
        state.isHosting
            ? coordinator.swapMemePhoto()
            : coordinator.clientSwapMemePhoto(),
      ),
      onSubmit: (strokes) => unawaited(
        state.isHosting
            ? coordinator.submitSabotage(strokes)
            : coordinator.clientSubmitSabotage(strokes),
      ),
    );
  }
}

class _SabotageEditor extends StatefulWidget {
  const _SabotageEditor({
    super.key,
    required this.state,
    required this.assignment,
    required this.onSwap,
    required this.onSubmit,
  });

  final MatchUiState state;
  final MemeAssignment assignment;
  final VoidCallback onSwap;
  final ValueChanged<List<SabotageStroke>> onSubmit;

  @override
  State<_SabotageEditor> createState() => _SabotageEditorState();
}

class _SabotageEditorState extends State<_SabotageEditor> {
  final List<SabotageStroke> _strokes = <SabotageStroke>[];
  SabotageStroke? _live;
  int _colorIndex = 0;
  bool _thick = false;
  bool _sending = false;

  List<SabotageStroke> get _visibleStrokes => <SabotageStroke>[
    ..._strokes,
    ?_live,
  ];

  Uint8List? get _bytes {
    final direct = _decode(widget.state.memePhotoBase64 ?? '');
    if (direct != null) return direct;
    return PhotoMemoryCache.instance.bytesFor(widget.assignment.photoId);
  }

  void _start(Offset position, Size size) {
    if (widget.state.memeSubmitted) return;
    setState(() {
      _live = SabotageStroke(
        colorIndex: _colorIndex,
        width: _thick ? 0.018 : 0.008,
        points: <Offset>[_normalized(position, size)],
      );
    });
  }

  void _update(Offset position, Size size) {
    final live = _live;
    if (live == null) return;
    final point = _normalized(position, size);
    if ((point - live.points.last).distance < 0.002) return;
    setState(() {
      _live = SabotageStroke(
        colorIndex: live.colorIndex,
        width: live.width,
        points: <Offset>[...live.points, point],
      );
    });
  }

  void _end() {
    final live = _live;
    if (live == null) return;
    setState(() {
      if (live.points.length >= 2) _strokes.add(live);
      _live = null;
    });
  }

  Offset _normalized(Offset position, Size size) => Offset(
    (position.dx / size.width).clamp(0.0, 1.0),
    (position.dy / size.height).clamp(0.0, 1.0),
  );

  void _send() {
    final simplified = simplifySabotageStrokes(_visibleStrokes);
    if (simplified.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.sabotageDrawFirst)));
      return;
    }
    setState(() => _sending = true);
    widget.onSubmit(simplified);
    unawaited(GameHaptics.instance.light());
    unawaited(GameAudioService.instance.pop());
  }

  @override
  void didUpdateWidget(covariant _SabotageEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A rejected submission (the clock ran out, the round moved on) must not
    // leave the send and swap buttons disabled forever.
    if (_sending &&
        widget.state.errorMessage != null &&
        widget.state.errorMessage != oldWidget.state.errorMessage) {
      _sending = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final state = widget.state;
    final owner = state.players
        .where((player) => player.id == widget.assignment.ownerId)
        .firstOrNull;
    final bytes = _bytes;
    if (bytes == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final coordinator = ProviderScope.containerOf(context)
            .read(matchCoordinatorProvider);
        coordinator.requestPhoto(widget.assignment.photoId);
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PanicTimerBar(
          remainingMs: state.remainingMs,
          totalMs: state.phaseDurationMs,
          label: l10n.modePhotoSabotage,
        ),
        const SizedBox(height: AppSpacing.s4),
        Row(
          children: <Widget>[
            PlayerAvatar(
              initial: owner?.name ?? widget.assignment.ownerName,
              avatar: owner?.avatar ?? '',
              photoBase64: state.avatarPhotos[owner?.id],
              size: 24,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.sabotageDrawHint(
                  owner?.name ?? widget.assignment.ownerName,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: colors.ink2),
              ),
            ),
            _SwapBadge(left: state.memeSwapsLeft),
          ],
        ),
        const SizedBox(height: 5),
        Expanded(
          child: state.memeSubmitted
              ? Center(
                  child: NoticeBanner(
                    message: l10n.sabotageSent,
                    icon: Icons.hourglass_empty,
                  ),
                )
              : Center(
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        return GestureDetector(
                          onPanStart: (details) =>
                              _start(details.localPosition, size),
                          onPanUpdate: (details) =>
                              _update(details.localPosition, size),
                          onPanEnd: (_) => _end(),
                          onPanCancel: _end,
                          child: SabotageArt(
                            photoId: widget.assignment.photoId,
                            photoBytes: bytes,
                            strokes: _visibleStrokes,
                            borderColor: colors.ink,
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
        if (!state.memeSubmitted) ...<Widget>[
          const SizedBox(height: 5),
          _Toolbar(
            colorIndex: _colorIndex,
            thick: _thick,
            canUndo: _strokes.isNotEmpty,
            canSwap: state.memeSwapsLeft > 0 && !_sending,
            sending: _sending,
            swapsLeft: state.memeSwapsLeft,
            onColor: (index) => setState(() => _colorIndex = index),
            onThick: () => setState(() => _thick = !_thick),
            onUndo: () => setState(() {
              if (_strokes.isNotEmpty) _strokes.removeLast();
            }),
            onClear: () => setState(_strokes.clear),
            onSwap: () {
              setState(() {
                _strokes.clear();
                _live = null;
              });
              widget.onSwap();
            },
            onSend: _send,
          ),
        ],
      ],
    );
  }
}

class _SwapBadge extends StatelessWidget {
  const _SwapBadge({required this.left});

  final int left;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.hairline),
      ),
      child: Text(
        '$left/5',
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: left > 0 ? colors.accent : colors.ink3,
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.colorIndex,
    required this.thick,
    required this.canUndo,
    required this.canSwap,
    required this.sending,
    required this.swapsLeft,
    required this.onColor,
    required this.onThick,
    required this.onUndo,
    required this.onClear,
    required this.onSwap,
    required this.onSend,
  });

  final int colorIndex;
  final bool thick;
  final bool canUndo;
  final bool canSwap;
  final bool sending;
  final int swapsLeft;
  final ValueChanged<int> onColor;
  final VoidCallback onThick;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onSwap;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (var i = 0; i < sabotageColors.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 2),
              Semantics(
                button: true,
                selected: i == colorIndex,
                label: _colorLabel(l10n, i),
                child: Tooltip(
                  message: _colorLabel(l10n, i),
                  child: InkResponse(
                    onTap: () => onColor(i),
                    radius: 20,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 120),
                          scale: i == colorIndex ? 1.18 : 1,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: sabotageColors[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: i == colorIndex
                                    ? colors.accent
                                    : colors.ink,
                                width: i == colorIndex ? 3 : 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const Spacer(),
            _ToolButton(
              icon: thick ? Icons.line_weight : Icons.horizontal_rule,
              label: thick ? l10n.sabotageThick : l10n.sabotageThin,
              onTap: onThick,
            ),
            _ToolButton(
              icon: Icons.undo,
              label: l10n.sabotageUndo,
              onTap: canUndo ? onUndo : null,
            ),
            _ToolButton(
              icon: Icons.delete_outline,
              label: l10n.sabotageClear,
              onTap: canUndo ? onClear : null,
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: <Widget>[
            Expanded(
              child: GameButton(
                label: '${l10n.memeSwapPhoto} ${l10n.memeSwapsLeft(swapsLeft)}',
                icon: Icons.swap_horiz,
                variant: GameButtonVariant.secondary,
                small: true,
                onPressed: canSwap ? onSwap : null,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: GameButton(
                label: l10n.sabotageSend,
                icon: Icons.arrow_upward,
                small: true,
                onPressed: sending ? null : onSend,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _colorLabel(AppLocalizations l10n, int index) => switch (index) {
  0 => l10n.sabotageColor1,
  1 => l10n.sabotageColor2,
  2 => l10n.sabotageColor3,
  3 => l10n.sabotageColor4,
  _ => l10n.sabotageColor5,
};

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 22,
        color: onTap == null ? colors.ink3 : colors.ink,
      ),
    );
  }
}

class _SabotageVoting extends ConsumerWidget {
  const _SabotageVoting({required this.state});

  final MatchUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final coordinator = ref.read(matchCoordinatorProvider);
    final cards = state.memeCards;
    if (cards.isEmpty) {
      return EmptyState(
        title: l10n.sabotageNoSubmissions,
        body: l10n.nextRoundInMoment,
      );
    }
    final card =
        cards.where((item) => item.id == state.memeFocusId).firstOrNull ??
        cards.first;
    final voted =
        state.memeVotedIds.contains(card.id) ||
        state.memeFocusVoterIds.contains(state.localPlayerId);
    final waiting = state.memeFocusVotes;
    final eligible = state.memeFocusEligible > 0
        ? state.memeFocusEligible
        : cards.where((item) => !item.isOwn).length;
    final bytes = PhotoMemoryCache.instance.bytesFor(card.photoId);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.sabotageVoteTitle,
          style: gameDisplay(size: 24, height: 0.98, color: colors.ink),
        ),
        Text(
          l10n.sabotageVoteSubtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: colors.ink2),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: reduce ? 1 : 0, end: 1),
                duration: reduce
                    ? Duration.zero
                    : const Duration(milliseconds: 800),
                builder: (context, progress, _) => SabotageArt(
                  photoId: card.photoId,
                  photoBytes: bytes,
                  strokes: card.strokes,
                  progress: progress,
                  borderColor: colors.ink,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          l10n.sabotageWaitingVotes(waiting, eligible),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: colors.ink2),
        ),
        const SizedBox(height: 5),
        if (state.memeTallying)
          _TallyStrip(state: state)
        else if (!voted && !card.isOwn)
          Row(
            children: <Widget>[
              Expanded(
                child: _VoteButton(
                  icon: Icons.thumb_up_alt_outlined,
                  label: l10n.memeVotesUp,
                  onTap: () => unawaited(
                    state.isHosting
                        ? coordinator.voteMeme(card.id, MemeVote.up)
                        : coordinator.clientVoteMeme(card.id, MemeVote.up),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _VoteButton(
                  icon: Icons.remove_circle_outline,
                  label: l10n.memeVotesMeh,
                  onTap: () => unawaited(
                    state.isHosting
                        ? coordinator.voteMeme(card.id, MemeVote.meh)
                        : coordinator.clientVoteMeme(card.id, MemeVote.meh),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _VoteButton(
                  icon: Icons.thumb_down_alt_outlined,
                  label: l10n.memeVotesDown,
                  onTap: () => unawaited(
                    state.isHosting
                        ? coordinator.voteMeme(card.id, MemeVote.down)
                        : coordinator.clientVoteMeme(card.id, MemeVote.down),
                  ),
                ),
              ),
            ],
          )
        else
          NoticeBanner(
            message: l10n.lockedInWaiting,
            icon: Icons.hourglass_empty,
          ),
        if (state.isHosting) ...<Widget>[
          const SizedBox(height: 5),
          GameButton(
            label: l10n.endVoting,
            onPressed: () => unawaited(coordinator.endMemeVoting()),
            variant: GameButtonVariant.secondary,
            small: true,
            fullWidth: true,
          ),
        ],
      ],
    );
  }
}

class _TallyStrip extends StatelessWidget {
  const _TallyStrip({required this.state});

  final MatchUiState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = WhoTookColors.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Text('${l10n.memeVotesUp}: ${state.memeTallyUp}'),
          Text('${l10n.memeVotesMeh}: ${state.memeTallyMeh}'),
          Text(
            '${l10n.memeVotesDown}: ${state.memeTallyDown}',
            style: TextStyle(color: colors.negative),
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(AppRadii.rControl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.rControl),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: colors.card,
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 18, color: colors.ink),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, color: colors.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SabotageReveal extends ConsumerWidget {
  const _SabotageReveal({required this.state});

  final MatchUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final coordinator = ref.read(matchCoordinatorProvider);
    final reveal = state.lastMemeReveal;
    if (reveal == null || reveal.entries.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          EmptyState(
            title: l10n.sabotageNoSubmissions,
            body: l10n.nextRoundInMoment,
          ),
          if (state.isHosting)
            GameButton(
              label: l10n.nextRound,
              icon: Icons.arrow_forward,
              onPressed: () => unawaited(coordinator.advanceMemeReveal()),
            ),
        ],
      );
    }
    final winner = reveal.entries.first;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppRadii.rModal),
            border: Border.all(color: colors.ink, width: 2.5),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.ink,
                offset: const Offset(0, 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  PlayerAvatar(
                    initial: winner.authorName,
                    avatar:
                        state.players
                            .where((p) => p.id == winner.authorId)
                            .firstOrNull
                            ?.avatar ??
                        '',
                    photoBase64: state.avatarPhotos[winner.authorId],
                    size: 32,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      winner.authorName,
                      style: gameDisplay(size: 22, color: colors.ink),
                    ),
                  ),
                  StickerBadge(
                    label: l10n.points(winner.points),
                    background: GamePalette.gold,
                    foreground: GamePalette.onGold,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              AspectRatio(
                aspectRatio: 4 / 5,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: reduce ? 1 : 0, end: 1),
                  duration: reduce
                      ? Duration.zero
                      : const Duration(milliseconds: 800),
                  builder: (context, progress, _) => SabotageArt(
                    photoId: winner.photoId,
                    photoBytes: PhotoMemoryCache.instance.bytesFor(
                      winner.photoId,
                    ),
                    strokes: winner.strokes,
                    progress: progress,
                    borderColor: colors.ink,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                l10n.memeVoteTally(
                  winner.upVotes,
                  winner.mehVotes,
                  winner.downVotes,
                ),
                style: TextStyle(fontSize: 12, color: colors.ink2),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        if (state.isHosting)
          GameButton(
            label: l10n.nextRound,
            icon: Icons.arrow_forward,
            onPressed: () => unawaited(coordinator.advanceMemeReveal()),
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

Uint8List? _decode(String value) {
  if (value.isEmpty) return null;
  try {
    return base64Decode(value);
  } on FormatException {
    return null;
  }
}
