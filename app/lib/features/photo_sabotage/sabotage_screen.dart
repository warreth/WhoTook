import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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
import '../../ui/widgets/photo_precache.dart';
import '../../ui/widgets/safety_controls.dart';
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

class _SabotageSnapshot {
  const _SabotageSnapshot({required this.strokes, required this.stickers});

  final List<SabotageStroke> strokes;
  final List<SabotageSticker> stickers;
}

class _SabotageEditorState extends State<_SabotageEditor> {
  static const List<double> _brushWidths = <double>[0.006, 0.012, 0.024];
  static const List<Offset> _dropOffsets = <Offset>[
    Offset(0.5, 0.44),
    Offset(0.38, 0.36),
    Offset(0.62, 0.38),
    Offset(0.42, 0.56),
    Offset(0.58, 0.54),
  ];

  final List<SabotageStroke> _strokes = <SabotageStroke>[];
  final List<SabotageSticker> _stickers = <SabotageSticker>[];
  final List<_SabotageSnapshot> _history = <_SabotageSnapshot>[];
  SabotageStroke? _live;
  int _colorIndex = 0;
  int _widthIndex = 1;
  bool _showStickers = false;
  int? _selectedStickerIndex;
  int? _draggingStickerIndex;
  Offset _dragGrabDelta = Offset.zero;
  double _scaleStartStickerScale = 1.0;
  bool _dragSnapshotSaved = false;
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

  void _pushHistory() {
    _history.add(
      _SabotageSnapshot(
        strokes: List<SabotageStroke>.of(_strokes),
        stickers: List<SabotageSticker>.of(_stickers),
      ),
    );
    if (_history.length > 40) {
      _history.removeAt(0);
    }
  }

  int? _hitTestSticker(Offset point, Size size) {
    final aspectX = size.shortestSide / size.width;
    final aspectY = size.shortestSide / size.height;
    for (var i = _stickers.length - 1; i >= 0; i--) {
      final sticker = _stickers[i];
      final dx = (point.dx - sticker.x) / aspectX;
      final dy = (point.dy - sticker.y) / aspectY;
      final hitRadius = math.max(0.095, 0.085 * sticker.scale);
      if (dx * dx + dy * dy <= hitRadius * hitRadius) {
        return i;
      }
    }
    return null;
  }

  void _addSticker(SabotageStickerKind kind) {
    if (widget.state.memeSubmitted) return;
    _pushHistory();
    final drop = _dropOffsets[_stickers.length % _dropOffsets.length];
    setState(() {
      _stickers.add(SabotageSticker(kind: kind, x: drop.dx, y: drop.dy));
      _selectedStickerIndex = _stickers.length - 1;
    });
  }

  void _resizeSelectedSticker(double delta) {
    final index = _selectedStickerIndex;
    if (index == null || index < 0 || index >= _stickers.length) return;
    _pushHistory();
    final current = _stickers[index];
    setState(() {
      _stickers[index] = current.copyWith(scale: current.scale + delta);
    });
  }

  void _deleteSelectedSticker() {
    final index = _selectedStickerIndex;
    if (index == null || index < 0 || index >= _stickers.length) return;
    _pushHistory();
    setState(() {
      _stickers.removeAt(index);
      _selectedStickerIndex = null;
      _draggingStickerIndex = null;
    });
  }

  void _onScaleStart(ScaleStartDetails details, Size size) {
    if (widget.state.memeSubmitted) return;
    final point = _normalized(details.localFocalPoint, size);
    final hit = _hitTestSticker(point, size);
    final targetIndex =
        hit ?? (details.pointerCount >= 2 ? _selectedStickerIndex : null);
    if (targetIndex != null && targetIndex < _stickers.length) {
      final target = _stickers[targetIndex];
      setState(() {
        _selectedStickerIndex = targetIndex;
        _draggingStickerIndex = targetIndex;
        _dragGrabDelta = Offset(target.x - point.dx, target.y - point.dy);
        _scaleStartStickerScale = target.scale;
        _dragSnapshotSaved = false;
        _live = null;
      });
      return;
    }
    setState(() {
      _selectedStickerIndex = null;
      _draggingStickerIndex = null;
      _live = SabotageStroke(
        colorIndex: _colorIndex,
        width: _brushWidths[_widthIndex],
        points: <Offset>[point],
      );
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size size) {
    final point = _normalized(details.localFocalPoint, size);
    final dragIndex = _draggingStickerIndex;
    if (dragIndex != null && dragIndex < _stickers.length) {
      if (!_dragSnapshotSaved) {
        _pushHistory();
        _dragSnapshotSaved = true;
      }
      final current = _stickers[dragIndex];
      final nextX = (point.dx + _dragGrabDelta.dx).clamp(0.04, 0.96);
      final nextY = (point.dy + _dragGrabDelta.dy).clamp(0.04, 0.96);
      final nextScale = details.pointerCount >= 2
          ? (_scaleStartStickerScale * details.scale).clamp(0.5, 2.2)
          : current.scale;
      setState(() {
        _stickers[dragIndex] = current.copyWith(
          x: nextX,
          y: nextY,
          scale: nextScale,
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

  void _onScaleEnd() {
    _draggingStickerIndex = null;
    _dragSnapshotSaved = false;
    final live = _live;
    if (live == null) return;
    _pushHistory();
    setState(() {
      if (live.points.isNotEmpty) {
        _strokes.add(live);
      }
      _live = null;
    });
  }

  void _undo() {
    if (_history.isEmpty) return;
    final previous = _history.removeLast();
    setState(() {
      _strokes
        ..clear()
        ..addAll(previous.strokes);
      _stickers
        ..clear()
        ..addAll(previous.stickers);
      _live = null;
      _draggingStickerIndex = null;
      if (_selectedStickerIndex != null &&
          _selectedStickerIndex! >= _stickers.length) {
        _selectedStickerIndex = null;
      }
    });
  }

  void _clear() {
    if (_strokes.isEmpty && _stickers.isEmpty) return;
    _pushHistory();
    setState(() {
      _strokes.clear();
      _stickers.clear();
      _live = null;
      _selectedStickerIndex = null;
      _draggingStickerIndex = null;
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
    setState(() {
      _selectedStickerIndex = null;
      _sending = true;
    });
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
        state.remainingMs <= 1500 &&
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
              photoBase64: state.safeAvatarPhoto(owner?.id, owner?.name),
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
                    child:
                        state.isPhotoHidden(widget.assignment.photoId) ||
                            state.isPlayerBlocked(
                              widget.assignment.ownerId,
                              widget.assignment.ownerName,
                            )
                        ? const BlockedContentPlaceholder(compact: true)
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final size = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              return GestureDetector(
                                onScaleStart: (details) =>
                                    _onScaleStart(details, size),
                                onScaleUpdate: (details) =>
                                    _onScaleUpdate(details, size),
                                onScaleEnd: (_) => _onScaleEnd(),
                                child: SabotageArt(
                                  photoId: widget.assignment.photoId,
                                  photoBytes: bytes,
                                  strokes: _visibleStrokes,
                                  stickers: _stickers,
                                  selectedStickerIndex: _selectedStickerIndex,
                                  borderColor: colors.ink,
                                ),
                              );
                            },
                          ),
                  ),
                ),
        ),
        if (!state.memeSubmitted) ...<Widget>[
          if (_selectedStickerIndex != null &&
              _selectedStickerIndex! < _stickers.length) ...<Widget>[
            const SizedBox(height: 4),
            _StickerSelectionBar(
              sticker: _stickers[_selectedStickerIndex!],
              onShrink: () => _resizeSelectedSticker(-0.2),
              onGrow: () => _resizeSelectedSticker(0.2),
              onDelete: _deleteSelectedSticker,
              onDone: () => setState(() => _selectedStickerIndex = null),
            ),
          ],
          const SizedBox(height: 5),
          _Toolbar(
            colorIndex: _colorIndex,
            widthIndex: _widthIndex,
            showStickers: _showStickers,
            stickerSelected: _selectedStickerIndex != null,
            selectedStickerKind:
                _selectedStickerIndex != null &&
                    _selectedStickerIndex! < _stickers.length
                ? _stickers[_selectedStickerIndex!].kind
                : null,
            canUndo: _history.isNotEmpty,
            canClear: _strokes.isNotEmpty || _stickers.isNotEmpty,
            canSwap: state.memeSwapsLeft > 0 && !_sending,
            sending: _sending,
            swapsLeft: state.memeSwapsLeft,
            onColor: (index) => setState(() {
              _colorIndex = index;
              _selectedStickerIndex = null;
            }),
            onWidth: () => setState(() {
              _widthIndex = (_widthIndex + 1) % _brushWidths.length;
              _selectedStickerIndex = null;
            }),
            onToggleStickers: () => setState(() {
              _showStickers = !_showStickers;
            }),
            onAddSticker: _addSticker,
            onUndo: _undo,
            onClear: _clear,
            onSwap: () {
              _clear();
              _history.clear();
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

class _StickerSelectionBar extends StatelessWidget {
  const _StickerSelectionBar({
    required this.sticker,
    required this.onShrink,
    required this.onGrow,
    required this.onDelete,
    required this.onDone,
  });

  final SabotageSticker sticker;
  final VoidCallback onShrink;
  final VoidCallback onGrow;
  final VoidCallback onDelete;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.ink, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SabotageStickerIcon(kind: sticker.kind, size: 22),
            ),
            IconButton(
              tooltip: l10n.sabotageStickerSmaller,
              onPressed: sticker.scale <= 0.55 ? null : onShrink,
              constraints: const BoxConstraints.tightFor(width: 34, height: 32),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.remove,
                size: 18,
                color: sticker.scale <= 0.55 ? colors.ink3 : colors.ink,
              ),
            ),
            IconButton(
              tooltip: l10n.sabotageStickerLarger,
              onPressed: sticker.scale >= 2.15 ? null : onGrow,
              constraints: const BoxConstraints.tightFor(width: 34, height: 32),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.add,
                size: 18,
                color: sticker.scale >= 2.15 ? colors.ink3 : colors.ink,
              ),
            ),
            IconButton(
              tooltip: l10n.sabotageStickerDelete,
              onPressed: onDelete,
              constraints: const BoxConstraints.tightFor(width: 34, height: 32),
              padding: EdgeInsets.zero,
              icon: Icon(Icons.delete_outline, size: 18, color: colors.negative),
            ),
            IconButton(
              tooltip: l10n.done,
              onPressed: onDone,
              constraints: const BoxConstraints.tightFor(width: 34, height: 32),
              padding: EdgeInsets.zero,
              icon: Icon(Icons.check, size: 18, color: colors.positive),
            ),
          ],
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
    required this.stickerSelected,
    required this.selectedStickerKind,
    required this.canUndo,
    required this.canClear,
    required this.canSwap,
    required this.sending,
    required this.swapsLeft,
    required this.onColor,
    required this.onWidth,
    required this.onToggleStickers,
    required this.onAddSticker,
    required this.onUndo,
    required this.onClear,
    required this.onSwap,
    required this.onSend,
  });

  final int colorIndex;
  final int widthIndex;
  final bool showStickers;
  final bool stickerSelected;
  final SabotageStickerKind? selectedStickerKind;
  final bool canUndo;
  final bool canClear;
  final bool canSwap;
  final bool sending;
  final int swapsLeft;
  final ValueChanged<int> onColor;
  final VoidCallback onWidth;
  final VoidCallback onToggleStickers;
  final ValueChanged<SabotageStickerKind> onAddSticker;
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
                        selected: !stickerSelected && i == colorIndex,
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
                                  scale: !stickerSelected && i == colorIndex
                                      ? 1.18
                                      : 1,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: sabotageColors[i],
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: !stickerSelected && i == colorIndex
                                            ? colors.accent
                                            : colors.ink,
                                        width: !stickerSelected && i == colorIndex
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
              highlighted: showStickers || stickerSelected,
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
              onTap: canClear ? onClear : null,
            ),
          ],
        ),
        if (showStickers) ...<Widget>[
          const SizedBox(height: 5),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final kind in SabotageStickerKind.values) ...<Widget>[
                  _StickerTrayButton(
                    kind: kind,
                    label: _stickerLabel(l10n, kind),
                    highlighted: selectedStickerKind == kind,
                    onTap: () => onAddSticker(kind),
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

class _StickerTrayButton extends StatelessWidget {
  const _StickerTrayButton({
    required this.kind,
    required this.label,
    required this.highlighted,
    required this.onTap,
  });

  final SabotageStickerKind kind;
  final String label;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: highlighted
              ? colors.accent.withValues(alpha: 0.14)
              : colors.card,
          borderRadius: BorderRadius.circular(AppRadii.rControl),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.rControl),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.rControl),
                border: Border.all(
                  color: highlighted ? colors.accent : colors.ink,
                  width: highlighted ? 2.5 : 2,
                ),
              ),
              child: SabotageStickerIcon(kind: kind, size: 30),
            ),
          ),
        ),
      ),
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
      SabotageStickerKind.clownNose => l10n.sabotageStickerClownNose,
      SabotageStickerKind.devilHorns => l10n.sabotageStickerDevilHorns,
      SabotageStickerKind.halo => l10n.sabotageStickerHalo,
      SabotageStickerKind.partyHat => l10n.sabotageStickerPartyHat,
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
      icon: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: highlighted
            ? BoxDecoration(
                color: colors.ink,
                borderRadius: BorderRadius.circular(AppRadii.rSm),
              )
            : null,
        child: Icon(
          icon,
          size: 20,
          color: onTap == null
              ? colors.ink3
              : highlighted
              ? colors.card
              : colors.ink,
        ),
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
                  child: state.isCardBlocked(card)
                      ? const BlockedContentPlaceholder(compact: true)
                      : GestureDetector(
                          onLongPressStart: (_) =>
                              setState(() => _comparing = true),
                          onLongPressEnd: (_) =>
                              setState(() => _comparing = false),
                          onLongPressCancel: () =>
                              setState(() => _comparing = false),
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
                    photoBase64: state.safeAvatarPhoto(
                      winner.authorId,
                      winner.authorName,
                    ),
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
                child:
                    state.isPhotoHidden(winner.photoId) ||
                        state.isPlayerBlocked(
                          winner.authorId,
                          winner.authorName,
                        )
                    ? const BlockedContentPlaceholder()
                    : GestureDetector(
                        onLongPressStart: (_) =>
                            setState(() => _comparing = true),
                        onLongPressEnd: (_) =>
                            setState(() => _comparing = false),
                        onLongPressCancel: () =>
                            setState(() => _comparing = false),
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
                    child:
                        state.isPhotoHidden(entry.photoId) ||
                            state.isPlayerBlocked(
                              entry.authorId,
                              entry.authorName,
                            )
                        ? Container(
                            decoration: BoxDecoration(
                              color: colors.raised,
                              borderRadius: BorderRadius.circular(
                                AppRadii.rControl,
                              ),
                              border: Border.all(color: colors.hairline),
                            ),
                            child: Icon(
                              Icons.visibility_off_outlined,
                              size: 18,
                              color: colors.ink2,
                            ),
                          )
                        : SabotageArt(
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
