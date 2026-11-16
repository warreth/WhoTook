import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/game_audio_service.dart';
import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/game_widgets.dart';
import '../widgets/host_controls.dart';

/// Make It Meme: one photo from another player, seven templates, five
/// match-wide swaps, anonymous votes, and a downloadable round winner.
class MemeScreen extends ConsumerStatefulWidget {
  const MemeScreen({super.key});

  @override
  ConsumerState<MemeScreen> createState() => _MemeScreenState();
}

class _MemeScreenState extends ConsumerState<MemeScreen> {
  final TextEditingController _top = TextEditingController();
  final TextEditingController _bottom = TextEditingController();
  final GlobalKey _winnerKey = GlobalKey();
  MemeTemplate _template = MemeTemplate.classic;
  double _snapY = 48;
  int _voteIndex = 0;
  int? _round;
  int _reactionTrigger = 0;
  MemeVote? _reactionKind;
  Timer? _autoAdvance;

  @override
  void initState() {
    super.initState();
    _top.addListener(_onTextChanged);
    _bottom.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _top.removeListener(_onTextChanged);
    _bottom.removeListener(_onTextChanged);
    _top.dispose();
    _bottom.dispose();
    _autoAdvance?.cancel();
    super.dispose();
  }

  void _resetForRound(int round) {
    if (_round == round) return;
    _round = round;
    _template = MemeTemplate.classic;
    _top.clear();
    _bottom.clear();
    _snapY = 48;
    _voteIndex = 0;
    _autoAdvance?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    _resetForRound(state.currentRound);
    return Scaffold(
      body: SafeArea(
        child: ScreenBody(
          child: switch (state.phase) {
            RoundPhase.captionVoting => _MemeVoting(
              state: state,
              index: _voteIndex,
              reactionKind: _reactionKind,
              reactionTrigger: _reactionTrigger,
              onSelectIndex: (index) => setState(() => _voteIndex = index),
              onVote: (card, vote) {
                if (card.isOwn || state.memeVotedIds.contains(card.id)) return;
                setState(() {
                  _reactionKind = vote;
                  _reactionTrigger++;
                });
                unawaited(
                  state.isHosting
                      ? coordinator.voteMeme(card.id, vote)
                      : coordinator.clientVoteMeme(card.id, vote),
                );
                _autoAdvance?.cancel();
                _autoAdvance = Timer(const Duration(milliseconds: 700), () {
                  if (mounted) _advanceVote(state);
                });
              },
              onNext: () => _advanceVote(state),
            ),
            RoundPhase.captionReveal => _MemeReveal(
              state: state,
              winnerKey: _winnerKey,
              onSave: () => _saveMeme(context),
            ),
            _ => _MemeEditor(
              state: state,
              template: _template,
              topController: _top,
              bottomController: _bottom,
              snapY: _snapY,
              onTemplate: (template) => setState(() => _template = template),
              onSnap: (value) => setState(() => _snapY = value),
              onSwap: () => unawaited(
                state.isHosting
                    ? coordinator.swapMemePhoto()
                    : coordinator.clientSwapMemePhoto(),
              ),
              onSubmit: () => unawaited(_submit(coordinator, state)),
            ),
          },
        ),
      ),
    );
  }

  void _advanceVote(MatchUiState state) {
    if (state.memeCards.isEmpty) return;
    var next = (_voteIndex + 1) % state.memeCards.length;
    for (var i = 0; i < state.memeCards.length; i++) {
      final candidate = (_voteIndex + 1 + i) % state.memeCards.length;
      final card = state.memeCards[candidate];
      if (!state.memeVotedIds.contains(card.id)) {
        next = candidate;
        break;
      }
    }
    if (next != _voteIndex) setState(() => _voteIndex = next);
  }

  Future<void> _submit(MatchCoordinator coordinator, MatchUiState state) async {
    final top = _top.text.trim();
    final bottom = _bottom.text.trim();
    if (top.isEmpty && bottom.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.memeWriteSomething)));
      return;
    }
    await (state.isHosting
        ? coordinator.submitMeme(
            template: _template,
            topText: top,
            bottomText: bottom,
            snapY: _snapY,
          )
        : coordinator.clientSubmitMeme(
            template: _template,
            topText: top,
            bottomText: bottom,
            snapY: _snapY,
          ));
  }

  Future<void> _saveMeme(BuildContext context) async {
    final ok = await MemeExporter.save(_winnerKey, album: 'WhoTook');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? context.l10n.memeSaved : context.l10n.memeSaveFailed,
        ),
      ),
    );
  }
}

class _MemeEditor extends StatelessWidget {
  const _MemeEditor({
    required this.state,
    required this.template,
    required this.topController,
    required this.bottomController,
    required this.snapY,
    required this.onTemplate,
    required this.onSnap,
    required this.onSwap,
    required this.onSubmit,
  });

  final MatchUiState state;
  final MemeTemplate template;
  final TextEditingController topController;
  final TextEditingController bottomController;
  final double snapY;
  final ValueChanged<MemeTemplate> onTemplate;
  final ValueChanged<double> onSnap;
  final VoidCallback onSwap;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final bytes = _decodeBytes(state.memePhotoBase64);
    final assignment = state.memeAssignment;
    final owner = assignment == null
        ? null
        : state.players
              .where((player) => player.id == assignment.ownerId)
              .firstOrNull;
    final fields = memeFieldLabels(l10n, template);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s12,
        AppSpacing.s20,
        AppSpacing.s24,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.modeMakeItMeme,
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
        const SizedBox(height: AppSpacing.s12),
        PanicTimerBar(
          remainingMs: state.remainingMs,
          totalMs: state.phaseDurationMs,
          label: l10n.memeWritingLabel,
        ),
        const SizedBox(height: AppSpacing.s12),
        if (assignment == null)
          const EmptyState(title: '…', body: '')
        else ...<Widget>[
          Row(
            children: <Widget>[
              PlayerAvatar(
                initial: owner?.name ?? assignment.ownerName,
                avatar: owner?.avatar ?? '',
                photoBase64: owner == null
                    ? null
                    : state.avatarPhotos[owner.id],
                size: 28,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  l10n.memePhotoFrom(owner?.name ?? assignment.ownerName),
                  style: TextStyle(fontSize: 13, color: colors.ink2),
                ),
              ),
              _SwapBank(swaps: state.memeSwapsLeft, l10n: l10n),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          MemeCanvas(
            bytes: bytes,
            template: template,
            topText: topController.text,
            bottomText: bottomController.text,
            snapY: snapY,
            onSnapChanged: onSnap,
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            l10n.memeTemplate.toUpperCase(),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 9,
              letterSpacing: 0.8,
              color: colors.ink3,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          MemeTemplatePicker(selected: template, onSelected: onTemplate),
          const SizedBox(height: AppSpacing.s12),
          _MemeField(
            controller: topController,
            label: fields.$1,
            hint: l10n.memeWritePrompt,
            canvasUpdater: () {},
            enabled: !state.memeSubmitted,
          ),
          if (fields.$2 != null) ...<Widget>[
            const SizedBox(height: AppSpacing.s8),
            _MemeField(
              controller: bottomController,
              label: fields.$2!,
              canvasUpdater: () {},
              enabled: !state.memeSubmitted,
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          if (state.memeSubmitted)
            NoticeBanner(
              message: l10n.memeSentWaiting,
              icon: Icons.hourglass_empty,
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: GameButton(
                    label: l10n.memeSwapPhoto,
                    onPressed: state.memeSwapsLeft > 0 ? onSwap : null,
                    variant: GameButtonVariant.secondary,
                    small: true,
                    icon: Icons.swap_horiz,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: GameButton(
                    label: l10n.memeSend,
                    onPressed: onSubmit,
                    icon: Icons.arrow_upward,
                  ),
                ),
              ],
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
      ],
    );
  }
}

class _SwapBank extends StatelessWidget {
  const _SwapBank({required this.swaps, required this.l10n});

  final int swaps;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Tooltip(
      message: '${l10n.memeSwapsLeft(swaps)}. ${l10n.memeSwapsMatchWide}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: colors.hairline, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${l10n.memeMatchSwaps.toUpperCase()} $swaps/5',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: swaps > 0 ? colors.accent : colors.ink3,
          ),
        ),
      ),
    );
  }
}

class _MemeField extends StatelessWidget {
  const _MemeField({
    required this.controller,
    required this.label,
    required this.canvasUpdater,
    required this.enabled,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final VoidCallback canvasUpdater;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLength: 70,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (_) => canvasUpdater(),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.rControl),
        ),
      ),
    );
  }
}

class _MemeVoting extends StatelessWidget {
  const _MemeVoting({
    required this.state,
    required this.index,
    required this.reactionKind,
    required this.reactionTrigger,
    required this.onSelectIndex,
    required this.onVote,
    required this.onNext,
  });

  final MatchUiState state;
  final int index;
  final MemeVote? reactionKind;
  final int reactionTrigger;
  final ValueChanged<int> onSelectIndex;
  final void Function(MemeCard card, MemeVote vote) onVote;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final cards = state.memeCards;
    if (cards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final safeIndex = index.clamp(0, cards.length - 1);
    final card = cards[safeIndex];
    final voted = state.memeVotedIds.contains(card.id);
    final progress = state.memeVotedIds.length;
    final eligible = cards.where((item) => !item.isOwn).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s12,
        AppSpacing.s20,
        AppSpacing.s24,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.modeMakeItMeme,
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
        const SizedBox(height: AppSpacing.s16),
        Text(
          l10n.memeVoteTitle,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: -1,
            height: 1,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          l10n.memeVoteSubtitle,
          style: TextStyle(fontSize: 13, height: 1.4, color: colors.ink2),
        ),
        const SizedBox(height: AppSpacing.s12),
        Stack(
          children: <Widget>[
            MemeCanvas(
              bytes: _decodeBytes(card.photoBase64),
              template: card.template,
              topText: card.topText,
              bottomText: card.bottomText,
              snapY: card.snapY,
              showWatermark: true,
            ),
            Positioned.fill(
              child: _ReactionBurst(
                kind: reactionKind,
                trigger: reactionTrigger,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: <Widget>[
            Text(
              '${safeIndex + 1} / ${cards.length}',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                color: colors.ink3,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            if (card.isOwn)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.raised,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.memeYourMeme,
                  style: TextStyle(fontSize: 9, color: colors.ink2),
                ),
              )
            else
              Text(
                l10n.memeAnonymous,
                style: TextStyle(fontSize: 10, color: colors.ink3),
              ),
            const Spacer(),
            Text(
              '$progress/$eligible',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10,
                color: colors.ink3,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: <Widget>[
            Expanded(
              child: _VoteButton(
                icon: Icons.thumb_up_outlined,
                label: l10n.memeUpvote,
                points: '+100',
                color: GamePalette.tealSoft,
                enabled: !card.isOwn && !voted,
                onTap: () => onVote(card, MemeVote.up),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _VoteButton(
                icon: Icons.remove_circle_outline,
                label: l10n.memeMeh,
                points: '0',
                color: colors.raised,
                enabled: !card.isOwn && !voted,
                onTap: () => onVote(card, MemeVote.meh),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _VoteButton(
                icon: Icons.thumb_down_outlined,
                label: l10n.memeDownvote,
                points: '−50',
                color: Color.alphaBlend(
                  colors.negative.withValues(alpha: 0.12),
                  colors.card,
                ),
                enabled: !card.isOwn && !voted,
                onTap: () => onVote(card, MemeVote.down),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          card.isOwn
              ? l10n.memeYourMeme
              : voted
              ? l10n.memeVoteLocked
              : l10n.memeTapToVote,
          style: TextStyle(
            fontSize: 12,
            color: voted || card.isOwn ? colors.positive : colors.ink2,
          ),
        ),
        if (progress >= eligible) ...<Widget>[
          const SizedBox(height: AppSpacing.s8),
          NoticeBanner(
            message: l10n.memeWaitingVotes,
            icon: Icons.hourglass_empty,
          ),
        ],
        const SizedBox(height: AppSpacing.s12),
        GameButton(
          label: safeIndex == cards.length - 1
              ? l10n.memeSeeResult
              : l10n.memeNextMeme,
          onPressed: progress >= eligible
              ? null
              : (card.isOwn || voted ? onNext : null),
          fullWidth: true,
          variant: GameButtonVariant.secondary,
          icon: Icons.arrow_forward,
        ),
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.label,
    required this.points,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String points;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shadow = dark ? Colors.black : colors.ink;
    // The upvote tile keeps its pale teal in both themes. A light ink on that
    // tile disappears in dark mode, so pick the foreground from the tile.
    final onColor = color.computeLuminance() > 0.45
        ? const Color(0xFF1F1B16)
        : colors.ink;
    final onColorMuted = onColor.withValues(alpha: 0.62);
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label $points',
      child: GestureDetector(
        onTap: enabled
            ? () {
                unawaited(GameHaptics.instance.selection());
                onTap();
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            height: 65,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: colors.ink, width: 2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: shadow,
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 20, color: onColor),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: onColor,
                  ),
                ),
                Text(
                  points,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 9,
                    color: onColorMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactionBurst extends StatefulWidget {
  const _ReactionBurst({required this.kind, required this.trigger});

  final MemeVote? kind;
  final int trigger;

  @override
  State<_ReactionBurst> createState() => _ReactionBurstState();
}

class _ReactionBurstState extends State<_ReactionBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didUpdateWidget(covariant _ReactionBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != _seen && widget.kind != null) {
      _seen = widget.trigger;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.kind == null) return const SizedBox.shrink();
    final icon = switch (widget.kind!) {
      MemeVote.up => Icons.thumb_up,
      MemeVote.meh => Icons.remove_circle_outline,
      MemeVote.down => Icons.thumb_down,
    };
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = Curves.easeOut.transform(_controller.value);
          return Stack(
            children: <Widget>[
              for (var i = 0; i < 5; i++)
                Positioned(
                  left: 24.0 + (i * 53) % 300,
                  bottom: 30 + progress * (160 + i * 8),
                  child: Opacity(
                    opacity: (1 - progress).clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: (i.isEven ? -1 : 1) * progress * 0.4,
                      child: Icon(
                        icon,
                        size: 25,
                        color: Colors.white,
                        shadows: const <Shadow>[
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MemeReveal extends StatelessWidget {
  const _MemeReveal({
    required this.state,
    required this.winnerKey,
    required this.onSave,
  });

  final MatchUiState state;
  final GlobalKey winnerKey;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final reveal = state.lastMemeReveal;
    final cards = state.memeRevealCards;
    if (reveal == null || cards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s20),
          child: EmptyState(
            title: l10n.memeNoMemes,
            body: l10n.nextRoundInMoment,
          ),
        ),
      );
    }
    final winner =
        cards.where((card) => card.isWinner).firstOrNull ?? cards.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s12,
        AppSpacing.s20,
        AppSpacing.s24,
      ),
      children: <Widget>[
        Text(
          l10n.modeMakeItMeme,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.4,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        ProgressSegments(current: state.currentRound, total: state.totalRounds),
        const SizedBox(height: AppSpacing.s16),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: GamePalette.gold,
            borderRadius: BorderRadius.circular(AppRadii.rCard),
            border: Border.all(color: GamePalette.onGold, width: 2),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: GamePalette.onGold,
                offset: Offset(0, 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.memeRoundWinner.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 9,
                  letterSpacing: 1.1,
                  color: GamePalette.onGoldMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                winner.authorName ?? '',
                style: const TextStyle(
                  fontSize: 34,
                  height: 0.98,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.4,
                  color: GamePalette.onGold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${l10n.memeCreatorPoints.toUpperCase()} · ${l10n.memePoints(winner.points)}',
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  color: GamePalette.onGoldMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        RepaintBoundary(
          key: winnerKey,
          child: MemeCanvas(
            bytes: _decodeBytes(winner.photoBase64),
            template: winner.template,
            topText: winner.topText,
            bottomText: winner.bottomText,
            snapY: winner.snapY,
            showWatermark: true,
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: <Widget>[
            Expanded(
              child: _VoteStat(label: l10n.memeVotesUp, value: winner.upVotes),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _VoteStat(
                label: l10n.memeVotesMeh,
                value: winner.mehVotes,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _VoteStat(
                label: l10n.memeVotesDown,
                value: winner.downVotes,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: colors.raised,
            borderRadius: BorderRadius.circular(AppRadii.rControl),
            border: Border.all(color: colors.hairline),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.star_outline,
                size: 20,
                color: GamePalette.goldDeep,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.memeModelRoyalty.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 8,
                        letterSpacing: 0.7,
                        color: colors.ink3,
                      ),
                    ),
                    Text(
                      l10n.memeRoyaltyBody(winner.photoOwnerName ?? ''),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: colors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        GameButton(
          label: l10n.memeDownload,
          onPressed: onSave,
          variant: GameButtonVariant.gold,
          icon: Icons.download_outlined,
          fullWidth: true,
        ),
        const SizedBox(height: AppSpacing.s16),
        Text(
          l10n.memeTopMemes,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        for (final card in reveal.entries.take(3))
          _MemeResultRow(
            card: cards.where((c) => c.id == card.id).firstOrNull,
            entry: card,
          ),
        const SizedBox(height: AppSpacing.s12),
        Text(
          l10n.memeFinalRound,
          style: TextStyle(fontSize: 11, height: 1.4, color: colors.ink3),
        ),
      ],
    );
  }
}

class _VoteStat extends StatelessWidget {
  const _VoteStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 7,
              color: colors.ink3,
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemeResultRow extends StatelessWidget {
  const _MemeResultRow({required this.card, required this.entry});

  final MemeCard? card;
  final MemeEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final bytes = card == null ? null : _decodeBytes(card!.photoBase64);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.hairline),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              width: 54,
              height: 54,
              child: bytes == null
                  ? ColoredBox(color: colors.raised)
                  : Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.authorName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${entry.upVotes} up · ${entry.mehVotes} meh · ${entry.downVotes} down',
                  style: TextStyle(fontSize: 10, color: colors.ink2),
                ),
              ],
            ),
          ),
          Text(
            l10nPoints(context, entry.points),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              color: entry.points >= 0 ? colors.positive : colors.negative,
            ),
          ),
        ],
      ),
    );
  }

  String l10nPoints(BuildContext context, int points) =>
      '${points >= 0 ? '+' : ''}$points';
}

(String, String?) memeFieldLabels(
  AppLocalizations l10n,
  MemeTemplate template,
) => switch (template) {
  MemeTemplate.classic => (l10n.memeTopLine, l10n.memeBottomLine),
  MemeTemplate.pov => (l10n.memeHeader, l10n.memeBottomLine),
  MemeTemplate.breaking => (l10n.memeHeadline, null),
  MemeTemplate.live => (l10n.memeReaction, null),
  MemeTemplate.poster => (l10n.memeTitle, l10n.memeSubtitle),
  MemeTemplate.snap => (l10n.memeBarText, null),
  MemeTemplate.split => (l10n.memeTopPanel, l10n.memeBottomPanel),
};

Uint8List? _decodeBytes(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return base64Decode(value);
  } on FormatException {
    return null;
  }
}
