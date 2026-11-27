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
import '../../ui/widgets/round_scoreboard.dart';
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
      onSubmit: (strokes, stickers) => unawaited(
        state.isHosting
            ? coordinator.submitSabotage(strokes, stickers: stickers)
            : coordinator.clientSubmitSabotage(strokes, stickers: stickers),
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
  final void Function(
    List<SabotageStroke> strokes,
    List<SabotageSticker> stickers,
  )
  onSubmit;

  @override
  State<_SabotageEditor> createState() => _SabotageEditorState();
}

class _SabotageEditorState extends State<_SabotageEditor> {
  static const List<double> _brushWidths = <double>[0.006, 0.012, 0.024];

  final List<SabotageStroke> _strokes = <SabotageStroke>[];
  final List<SabotageSticker> _stickers = <SabotageSticker>[];
  final List<bool> _undoIsStroke = <bool>[];
  SabotageStroke? _live;
  int _colorIndex = 0;
  int _widthIndex = 1;
  bool _showStickers = false;
  SabotageStickerKind? _activeSticker;
  bool _sending = false;
  int? _autoSubmittedRound;

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
    final point = _normalized(position, size);
    final sticker = _activeSticker;
    if (sticker != null) {
      setState(() {
        _stickers.add(SabotageSticker(kind: sticker, x: point.dx, y: point.dy));
        _undoIsStroke.add(false);
      });
      return;
    }
    setState(() {
      _live = SabotageStroke(
        colorIndex: _colorIndex,
        width: _brushWidths[_widthIndex],
        points: <Offset>[point],
      );
    });
  }

  void _update(Offset position, Size size) {
    final point = _normalized(position, size);
    if (_activeSticker != null && _stickers.isNotEmpty) {
      setState(() {
        final last = _stickers.last;
        _stickers[_stickers.length - 1] = SabotageSticker(
          kind: last.kind,
          x: point.dx,
          y: point.dy,
          scale: last.scale,
        );
      });
      return;
    }
    final live = _live;
    if (live == null) return;
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
    if (_activeSticker != null) return;
    final live = _live;
    if (live == null) return;
    setState(() {
      if (live.points.isNotEmpty) {
        _strokes.add(live);
        _undoIsStroke.add(true);
      }
      _live = null;
    });
  }

  void _undo() {
    if (_undoIsStroke.isEmpty) return;
    setState(() {
      final isStroke = _undoIsStroke.removeLast();
      if (isStroke) {
        if (_strokes.isNotEmpty) _strokes.removeLast();
      } else {
        if (_stickers.isNotEmpty) _stickers.removeLast();
      }
    });
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _stickers.clear();
      _undoIsStroke.clear();
      _live = null;
    });
  }

  Offset _normalized(Offset position, Size size) => Offset(
    (position.dx / size.width).clamp(0.0, 1.0),
    (position.dy / size.height).clamp(0.0, 1.0),
  );

  void _send({bool automatic = false}) {
    if (_sending || widget.state.memeSubmitted) return;
    final simplified = simplifySabotageStrokes(_visibleStrokes);
    final stickers = List<SabotageSticker>.of(_stickers);
    if (simplified.isEmpty && stickers.isEmpty) {
      if (!automatic && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.sabotageDrawFirst)));
      }
      return;
    }
    setState(() => _sending = true);
    widget.onSubmit(simplified, stickers);
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
    final state = widget.state;
    if (state.phase == RoundPhase.captionWriting &&
        state.activeMode == GameMode.photoSabotage &&
        !state.memeSubmitted &&
        !_sending &&
        state.remainingMs > 0 &&
        state.remainingMs <= 1000 &&
        (_strokes.isNotEmpty || _stickers.isNotEmpty) &&
        _autoSubmittedRound != state.currentRound) {
      _autoSubmittedRound = state.currentRound;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _send(automatic: true);
      });
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
    final promptIndex = widget.assignment.promptIndex;
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
                promptIndex != null
                    ? _sabotagePrompt(l10n, promptIndex)
                    : l10n.sabotageDrawHint(
                        owner?.name ?? widget.assignment.ownerName,
                      ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: promptIndex != null ? colors.ink : colors.ink2,
                ),
              ),
            ),
            if (state.memeSwapsLeft > 0) ...<Widget>[
              const SizedBox(width: 6),
              _SwapBadge(left: state.memeSwapsLeft),
            ],
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
                            stickers: _stickers,
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
            widthIndex: _widthIndex,
            showStickers: _showStickers,
            activeSticker: _activeSticker,
            canUndo: _undoIsStroke.isNotEmpty,
            canSwap: state.memeSwapsLeft > 0 && !_sending,
            sending: _sending,
            swapsLeft: state.memeSwapsLeft,
            onColor: (index) => setState(() {
              _colorIndex = index;
              _activeSticker = null;
            }),
            onWidth: () => setState(() {
              _widthIndex = (_widthIndex + 1) % _brushWidths.length;
              _activeSticker = null;
            }),
            onToggleStickers: () => setState(() {
              _showStickers = !_showStickers;
              if (!_showStickers) _activeSticker = null;
            }),
            onSelectSticker: (kind) => setState(() {
              _activeSticker = _activeSticker == kind ? null : kind;
            }),
            onUndo: _undo,
            onClear: _clear,
            onSwap: () {
              _clear();
              widget.onSwap();
            },
            onSend: () => _send(),
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
    required this.widthIndex,
    required this.showStickers,
    required this.activeSticker,
    required this.canUndo,
    required this.canSwap,
    required this.sending,
    required this.swapsLeft,
    required this.onColor,
    required this.onWidth,
    required this.onToggleStickers,
    required this.onSelectSticker,
    required this.onUndo,
    required this.onClear,
    required this.onSwap,
    required this.onSend,
  });

  final int colorIndex;
  final int widthIndex;
  final bool showStickers;
  final SabotageStickerKind? activeSticker;
  final bool canUndo;
  final bool canSwap;
  final bool sending;
  final int swapsLeft;
  final ValueChanged<int> onColor;
  final VoidCallback onWidth;
  final VoidCallback onToggleStickers;
  final ValueChanged<SabotageStickerKind> onSelectSticker;
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
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (var i = 0; i < sabotageColors.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: 2),
                      Semantics(
                        button: true,
                        selected: activeSticker == null && i == colorIndex,
                        label: _colorLabel(l10n, i),
                        child: Tooltip(
                          message: _colorLabel(l10n, i),
                          child: InkResponse(
                            onTap: () => onColor(i),
                            radius: 18,
                            child: SizedBox(
                              width: 34,
                              height: 36,
                              child: Center(
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 120),
                                  scale:
                                      activeSticker == null && i == colorIndex
                                      ? 1.18
                                      : 1,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: sabotageColors[i],
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            activeSticker == null &&
                                                i == colorIndex
                                            ? colors.accent
                                            : colors.ink,
                                        width:
                                            activeSticker == null &&
                                                i == colorIndex
                                            ? 3
                                            : 2,
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
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            _ToolButton(
              icon: Icons.emoji_emotions_outlined,
              label: l10n.sabotageStickers,
              highlighted: showStickers || activeSticker != null,
              onTap: onToggleStickers,
            ),
            _ToolButton(
              icon: switch (widthIndex) {
                0 => Icons.lens_outlined,
                1 => Icons.circle,
                _ => Icons.adjust,
              },
              label: l10n.sabotageBrushSize,
              onTap: onWidth,
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
        if (showStickers) ...<Widget>[
          const SizedBox(height: 4),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final kind in SabotageStickerKind.values) ...<Widget>[
                  ChoiceChip(
                    label: Text(_stickerLabel(l10n, kind)),
                    selected: activeSticker == kind,
                    onSelected: (_) => onSelectSticker(kind),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 5),
        Row(
          children: <Widget>[
            if (swapsLeft > 0) ...<Widget>[
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
            ],
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
  4 => l10n.sabotageColor5,
  5 => l10n.sabotageColor6,
  6 => l10n.sabotageColor7,
  _ => l10n.sabotageColor8,
};

String _stickerLabel(AppLocalizations l10n, SabotageStickerKind kind) =>
    switch (kind) {
      SabotageStickerKind.googlyEyes => l10n.sabotageStickerEyes,
      SabotageStickerKind.mustache => l10n.sabotageStickerMustache,
      SabotageStickerKind.crown => l10n.sabotageStickerCrown,
      SabotageStickerKind.sunglasses => l10n.sabotageStickerShades,
      SabotageStickerKind.censorBar => l10n.sabotageStickerCensor,
      SabotageStickerKind.heart => l10n.sabotageStickerHeart,
    };

String _sabotagePrompt(AppLocalizations l10n, int index) => switch (index % 8) {
  0 => l10n.sabotagePrompt1,
  1 => l10n.sabotagePrompt2,
  2 => l10n.sabotagePrompt3,
  3 => l10n.sabotagePrompt4,
  4 => l10n.sabotagePrompt5,
  5 => l10n.sabotagePrompt6,
  6 => l10n.sabotagePrompt7,
  _ => l10n.sabotagePrompt8,
};

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 20,
        color: onTap == null
            ? colors.ink3
            : highlighted
            ? colors.accent
            : colors.ink,
      ),
    );
  }
}

class _SabotageVoting extends ConsumerStatefulWidget {
  const _SabotageVoting({required this.state});

  final MatchUiState state;

  @override
  ConsumerState<_SabotageVoting> createState() => _SabotageVotingState();
}

class _SabotageVotingState extends ConsumerState<_SabotageVoting> {
  bool _comparing = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
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
    return Stack(
      children: <Widget>[
        PhotoPrecache(
          photoIds: <String>[
            for (final item in cards) item.photoId,
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.sabotageVoteTitle,
              style: gameDisplay(size: 24, height: 0.98, color: colors.ink),
            ),
            Text(
              l10n.sabotageHoldToCompare,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colors.ink2),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: GestureDetector(
                    onLongPressStart: (_) => setState(() => _comparing = true),
                    onLongPressEnd: (_) => setState(() => _comparing = false),
                    onLongPressCancel: () => setState(() => _comparing = false),
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey<String>('sabotage-replay-${card.id}'),
                      tween: Tween<double>(begin: reduce ? 1 : 0, end: 1),
                      duration: reduce
                          ? Duration.zero
                          : const Duration(milliseconds: 900),
                      builder: (context, progress, _) => SabotageArt(
                        photoId: card.photoId,
                        photoBytes: bytes,
                        strokes: _comparing
                            ? const <SabotageStroke>[]
                            : card.strokes,
                        stickers: _comparing
                            ? const <SabotageSticker>[]
                            : card.stickers,
                        progress: progress,
                        borderColor: colors.ink,
                      ),
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
            else if (card.isOwn)
              NoticeBanner(
                message: l10n.memeYourOwn,
                icon: Icons.brush_outlined,
              )
            else if (!voted)
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
        ),
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

class _SabotageReveal extends ConsumerStatefulWidget {
  const _SabotageReveal({required this.state});

  final MatchUiState state;

  @override
  ConsumerState<_SabotageReveal> createState() => _SabotageRevealState();
}

class _SabotageRevealState extends ConsumerState<_SabotageReveal> {
  bool _comparing = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
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
                child: GestureDetector(
                  onLongPressStart: (_) => setState(() => _comparing = true),
                  onLongPressEnd: (_) => setState(() => _comparing = false),
                  onLongPressCancel: () => setState(() => _comparing = false),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: reduce ? 1 : 0, end: 1),
                    duration: reduce
                        ? Duration.zero
                        : const Duration(milliseconds: 900),
                    builder: (context, progress, _) => SabotageArt(
                      photoId: winner.photoId,
                      photoBytes: PhotoMemoryCache.instance.bytesFor(
                        winner.photoId,
                      ),
                      strokes: _comparing
                          ? const <SabotageStroke>[]
                          : winner.strokes,
                      stickers: _comparing
                          ? const <SabotageSticker>[]
                          : winner.stickers,
                      progress: progress,
                      borderColor: colors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.sabotageHoldToCompare,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: colors.ink3),
              ),
              const SizedBox(height: AppSpacing.s4),
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
        if (reveal.entries.length > 1) ...<Widget>[
          const SizedBox(height: AppSpacing.s12),
          for (final entry in reveal.entries.skip(1))
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(AppRadii.rControl),
                border: Border.all(color: colors.hairline),
              ),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 48,
                    height: 60,
                    child: SabotageArt(
                      photoId: entry.photoId,
                      strokes: entry.strokes,
                      stickers: entry.stickers,
                      borderColor: colors.hairline,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entry.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.ink,
                          ),
                        ),
                        Text(
                          l10n.memeVoteTally(
                            entry.upVotes,
                            entry.mehVotes,
                            entry.downVotes,
                          ),
                          style: TextStyle(fontSize: 11, color: colors.ink2),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    l10n.points(entry.points),
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: entry.points >= 0
                          ? colors.positive
                          : colors.negative,
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.s12),
        RoundScoreboard(
          players: state.players,
          scoreDeltas: reveal.scoreDeltas,
          avatarPhotos: state.avatarPhotos,
          localPlayerId: state.localPlayerId,
          doublePoints: state.isFinalDoubleRound,
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
