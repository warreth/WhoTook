import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/game_audio_service.dart';
import '../../core/models/models.dart';
import '../../core/theme/game_skin.dart';
import '../../core/theme/responsive_game_layout.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/game_background.dart';
import '../widgets/game_widgets.dart';
import '../widgets/host_controls.dart';
import '../widgets/photo_precache.dart';

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
  int? _round;
  int _reactionTrigger = 0;
  MemeVote? _reactionKind;
  final Set<String> _requestedPhotos = <String>{};

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
    super.dispose();
  }

  void _resetForRound(int round) {
    if (_round == round) return;
    _round = round;
    _template = MemeTemplate.classic;
    _top.clear();
    _bottom.clear();
    _snapY = 48;
    _requestedPhotos.clear();
  }

  @override
  Widget build(BuildContext context) {
    final layout = ResponsiveGameLayout.of(context);
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    _resetForRound(state.currentRound);
    final photoId = state.memeAssignment?.photoId;
    if (photoId != null &&
        photoId.isNotEmpty &&
        (state.memePhotoBase64 == null || state.memePhotoBase64!.isEmpty) &&
        _requestedPhotos.add(photoId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) coordinator.requestPhoto(photoId);
      });
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          PhotoPrecache(
            photoIds: <String>[
              ?state.memeAssignment?.photoId,
              for (final card in <MemeCard>[
                ...state.memeCards,
                ...state.memeRevealCards,
                ...state.topMemes,
              ])
                card.photoId,
            ],
          ),
          GameBackdrop(
            mode: GameMode.makeItMeme,
            child: SafeArea(
              child: ScreenBody(
                maxWidth: layout.isTablet ? 560 : 720,
                child: switch (state.phase) {
                  RoundPhase.captionVoting => _MemeVoting(
                    state: state,
                    reactionKind: _reactionKind,
                    reactionTrigger: _reactionTrigger,
                    onVote: (card, vote) {
                      if (card.isOwn || state.memeVotedIds.contains(card.id)) {
                        return;
                      }
                      setState(() {
                        _reactionKind = vote;
                        _reactionTrigger++;
                      });
                      unawaited(
                        state.isHosting
                            ? coordinator.voteMeme(card.id, vote)
                            : coordinator.clientVoteMeme(card.id, vote),
                      );
                    },
                    onEndVoting: () => unawaited(coordinator.endMemeVoting()),
                    onRequestPhoto: coordinator.requestPhoto,
                  ),
                  RoundPhase.captionReveal => _MemeReveal(
                    state: state,
                    winnerKey: _winnerKey,
                    onSave: () => _saveMeme(context),
                    onNext: () => unawaited(coordinator.advanceMemeReveal()),
                  ),
                  _ => _MemeEditor(
                    state: state,
                    template: _template,
                    topController: _top,
                    bottomController: _bottom,
                    snapY: _snapY,
                    onTemplate: (template) =>
                        setState(() => _template = template),
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
          ),
        ],
      ),
    );
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
    final layout = ResponsiveGameLayout.of(context);
    if (layout.isCompactHeight || layout.isTablet) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          layout.pagePadding,
          layout.sectionGap,
          layout.pagePadding,
          layout.sectionGap,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.modeMakeItMeme,
                    style: gameDisplay(size: 21, color: colors.ink),
                  ),
                ),
                const HostControlsButton(),
                FrameCounter(
                  current: state.currentRound,
                  total: state.totalRounds,
                  label: l10n.roundBadge(state.currentRound, state.totalRounds),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ProgressSegments(
              current: state.currentRound,
              total: state.totalRounds,
            ),
            const SizedBox(height: 5),
            PanicTimerBar(
              remainingMs: state.remainingMs,
              totalMs: state.phaseDurationMs,
              label: l10n.memeWritingLabel,
            ),
            const SizedBox(height: 5),
            if (assignment == null)
              const Expanded(
                child: EmptyState(title: '…', body: ''),
              )
            else ...<Widget>[
              Row(
                children: <Widget>[
                  PlayerAvatar(
                    initial: owner?.name ?? assignment.ownerName,
                    avatar: owner?.avatar ?? '',
                    photoBase64: owner == null
                        ? null
                        : state.avatarPhotos[owner.id],
                    size: 24,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.memePhotoFrom(owner?.name ?? assignment.ownerName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colors.ink2),
                    ),
                  ),
                  _SwapBank(swaps: state.memeSwapsLeft, l10n: l10n),
                ],
              ),
              const SizedBox(height: 5),
              Expanded(
                child: MemeCanvas(
                  bytes: bytes,
                  photoId: state.memeAssignment?.photoId,
                  template: template,
                  topText: topController.text,
                  bottomText: bottomController.text,
                  snapY: snapY,
                  onSnapChanged: onSnap,
                ),
              ),
              const SizedBox(height: 5),
              MemeTemplatePicker(selected: template, onSelected: onTemplate),
              const SizedBox(height: 5),
              _MemeField(
                controller: topController,
                label: fields.$1,
                hint: l10n.memeWritePrompt,
                canvasUpdater: () {},
                enabled: !state.memeSubmitted,
              ),
              if (fields.$2 != null) ...<Widget>[
                const SizedBox(height: 4),
                _MemeField(
                  controller: bottomController,
                  label: fields.$2!,
                  canvasUpdater: () {},
                  enabled: !state.memeSubmitted,
                ),
              ],
              const SizedBox(height: 5),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: GameButton(
                        label: l10n.memeSend,
                        onPressed: onSubmit,
                        icon: Icons.arrow_upward,
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      );
    }
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
                style: gameDisplay(size: 26, color: colors.ink),
              ),
            ),
            const HostControlsButton(),
            FrameCounter(
              current: state.currentRound,
              total: state.totalRounds,
              label: l10n.roundBadge(state.currentRound, state.totalRounds),
            ),
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
            photoId: state.memeAssignment?.photoId,
            template: template,
            topText: topController.text,
            bottomText: bottomController.text,
            snapY: snapY,
            onSnapChanged: onSnap,
          ),
          const SizedBox(height: AppSpacing.s12),
          Align(
            alignment: Alignment.centerLeft,
            child: StickerBadge(
              label: l10n.memeTemplate,
              background: colors.raised,
              foreground: colors.ink,
              angle: 0.025,
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
    final colors = WhoTookColors.of(context);
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
        filled: true,
        fillColor: colors.card,
        labelStyle: gameDisplay(size: 13, color: colors.ink2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.rControl),
          borderSide: BorderSide(color: colors.ink, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.rControl),
          borderSide: BorderSide(color: colors.ink, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.rControl),
          borderSide: BorderSide(color: colors.accent, width: 3),
        ),
      ),
    );
  }
}

class _MemeVoting extends StatelessWidget {
  const _MemeVoting({
    required this.state,
    required this.reactionKind,
    required this.reactionTrigger,
    required this.onVote,
    required this.onEndVoting,
    required this.onRequestPhoto,
  });

  final MatchUiState state;
  final MemeVote? reactionKind;
  final int reactionTrigger;
  final void Function(MemeCard card, MemeVote vote) onVote;
  final VoidCallback onEndVoting;
  final ValueChanged<String> onRequestPhoto;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final cards = state.memeCards;
    if (cards.isEmpty) {
      return Center(child: PhotoShimmer(compact: false));
    }
    final focusId = state.memeFocusId;
    final card =
        cards.where((item) => item.id == focusId).firstOrNull ?? cards.first;
    final index = cards.indexOf(card);
    final voted =
        state.memeVotedIds.contains(card.id) ||
        state.memeFocusVoterIds.contains(state.localPlayerId);
    final eligible = state.memeFocusEligible > 0
        ? state.memeFocusEligible
        : cards.where((item) => !item.isOwn).length;
    final progress = state.memeFocusVotes;
    final bytesEmpty = card.photoBase64.isEmpty;
    if (bytesEmpty && card.photoId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onRequestPhoto(card.photoId);
      });
    }
    final layout = ResponsiveGameLayout.of(context);
    if (layout.isCompactHeight || layout.isTablet) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          layout.pagePadding,
          layout.sectionGap,
          layout.pagePadding,
          layout.sectionGap,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.modeMakeItMeme,
                    style: gameDisplay(size: 21, color: colors.ink),
                  ),
                ),
                const HostControlsButton(),
                FrameCounter(
                  current: state.currentRound,
                  total: state.totalRounds,
                  label: l10n.roundBadge(state.currentRound, state.totalRounds),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ProgressSegments(
              current: state.currentRound,
              total: state.totalRounds,
            ),
            if (state.isHosting && !state.memeTallying) ...<Widget>[
              const SizedBox(height: 4),
              GameButton(
                label: l10n.endVoting,
                onPressed: onEndVoting,
                variant: GameButtonVariant.secondary,
                small: true,
                fullWidth: true,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              l10n.memeVoteTitle,
              style: gameDisplay(size: 24, height: 0.98, color: colors.ink),
            ),
            Text(
              l10n.memeVoteSubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colors.ink2),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Stack(
                children: <Widget>[
                  MemeCanvas(
                    bytes: _decodeBytes(card.photoBase64),
                    photoId: card.photoId,
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
                  Positioned.fill(
                    child: _TallyBurst(active: state.memeTallying),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                StickerBadge(
                  label:
                      '${index + 1}/${state.memeFocusCount <= 0 ? cards.length : state.memeFocusCount}',
                  background: colors.raised,
                  foreground: colors.ink,
                  angle: 0.03,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.waitingForVotes(progress, eligible),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: gameDisplay(
                      size: 10,
                      color: progress >= eligible
                          ? colors.positive
                          : colors.ink2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Expanded(
                  child: _VoteButton(
                    icon: Icons.thumb_up_outlined,
                    label: l10n.memeUpvote,
                    points: '+100',
                    color: GamePalette.tealSoft,
                    enabled: !card.isOwn && !voted && !state.memeTallying,
                    compact: true,
                    onTap: () => onVote(card, MemeVote.up),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _VoteButton(
                    icon: Icons.remove_circle_outline,
                    label: l10n.memeMeh,
                    points: '0',
                    color: colors.raised,
                    enabled: !card.isOwn && !voted && !state.memeTallying,
                    compact: true,
                    onTap: () => onVote(card, MemeVote.meh),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _VoteButton(
                    icon: Icons.thumb_down_outlined,
                    label: l10n.memeDownvote,
                    points: '−50',
                    color: Color.alphaBlend(
                      colors.negative.withValues(alpha: 0.12),
                      colors.card,
                    ),
                    enabled: !card.isOwn && !voted && !state.memeTallying,
                    compact: true,
                    onTap: () => onVote(card, MemeVote.down),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.players.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final player = state.players[index];
                  final didVote = state.memeFocusVoterIds.contains(player.id);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      PlayerAvatar(
                        initial: player.name,
                        avatar: player.avatar,
                        photoBase64: state.avatarPhotos[player.id],
                        size: 28,
                      ),
                      if (didVote)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: colors.positive,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.card, width: 2),
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 2),
            Text(
              card.isOwn
                  ? l10n.memeYourMeme
                  : voted
                  ? l10n.memeVoteLocked
                  : l10n.memeTapToVote,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: voted || card.isOwn ? colors.positive : colors.ink2,
              ),
            ),
            if (state.memeTallying)
              Text(
                l10n.countingVotes,
                style: TextStyle(
                  fontSize: 10,
                  color: colors.ink2,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      );
    }
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
                style: gameDisplay(size: 26, color: colors.ink),
              ),
            ),
            const HostControlsButton(),
            FrameCounter(
              current: state.currentRound,
              total: state.totalRounds,
              label: l10n.roundBadge(state.currentRound, state.totalRounds),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        ProgressSegments(current: state.currentRound, total: state.totalRounds),
        if (state.isHosting && !state.memeTallying) ...<Widget>[
          const SizedBox(height: AppSpacing.s8),
          GameButton(
            label: l10n.endVoting,
            onPressed: onEndVoting,
            variant: GameButtonVariant.secondary,
            small: true,
            icon: Icons.timer_off_outlined,
            fullWidth: true,
          ),
        ],
        const SizedBox(height: AppSpacing.s16),
        Text(
          l10n.memeVoteTitle,
          style: gameDisplay(
            size: 32,
            height: 0.98,
            color: colors.ink,
            letterSpacing: -0.9,
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
              photoId: card.photoId,
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
            Positioned.fill(child: _TallyBurst(active: state.memeTallying)),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: <Widget>[
            StickerBadge(
              label:
                  '${index + 1}/${state.memeFocusCount <= 0 ? cards.length : state.memeFocusCount}',
              background: colors.raised,
              foreground: colors.ink,
              angle: 0.03,
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
              Flexible(
                child: Text(
                  l10n.memeAnonymous,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: colors.ink3),
                ),
              ),
            const SizedBox(width: AppSpacing.s8),
            Flexible(
              child: Text(
                l10n.waitingForVotes(progress, eligible),
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: gameDisplay(
                  size: 10,
                  color: progress >= eligible ? colors.positive : colors.ink2,
                ),
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
                enabled: !card.isOwn && !voted && !state.memeTallying,
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
                enabled: !card.isOwn && !voted && !state.memeTallying,
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
                enabled: !card.isOwn && !voted && !state.memeTallying,
                onTap: () => onVote(card, MemeVote.down),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        _VoteStatus(state: state, l10n: l10n),
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
        if (state.memeTallying) ...<Widget>[
          const SizedBox(height: AppSpacing.s12),
          NoticeBanner(message: l10n.countingVotes, icon: Icons.celebration),
        ],
      ],
    );
  }
}

class _VoteStatus extends StatelessWidget {
  const _VoteStatus({required this.state, required this.l10n});

  final MatchUiState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.how_to_vote_outlined, size: 18, color: colors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.waitingForVotes(
                    state.memeFocusVotes,
                    state.memeFocusEligible,
                  ),
                  style: gameDisplay(size: 13, color: colors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final player in state.players)
                Tooltip(
                  message: state.memeFocusVoterIds.contains(player.id)
                      ? '${player.name} · ${l10n.playerVoted}'
                      : player.name,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      PlayerAvatar(
                        initial: player.name,
                        avatar: player.avatar,
                        photoBase64: state.avatarPhotos[player.id],
                        size: 30,
                      ),
                      if (state.memeFocusVoterIds.contains(player.id))
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: colors.positive,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.card, width: 2),
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TallyBurst extends StatefulWidget {
  const _TallyBurst({required this.active});

  final bool active;

  @override
  State<_TallyBurst> createState() => _TallyBurstState();
}

class _TallyBurstState extends State<_TallyBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didUpdateWidget(covariant _TallyBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
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
    if (!widget.active) return const SizedBox.shrink();
    final l10n = context.l10n;
    final icons = <IconData>[
      Icons.thumb_up,
      Icons.remove_circle_outline,
      Icons.thumb_down,
    ];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_controller.value);
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.22 * (1 - t * 0.4)),
                ),
              ),
              Center(
                child: Transform.scale(
                  scale: 0.7 + t * 0.4,
                  child: Opacity(
                    opacity: (1 - (t - 0.7).clamp(0.0, 0.3) / 0.3).clamp(
                      0.0,
                      1.0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Text(
                        l10n.votesAreIn,
                        style: gameDisplay(
                          size: 18,
                          color: const Color(0xFF171310),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < 9; i++)
                Positioned(
                  left: 18.0 + (i * 61) % 320,
                  bottom: 24 + t * (170 + i * 7),
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: (i.isEven ? -1 : 1) * t * 0.5,
                      child: Icon(
                        icons[i % icons.length],
                        size: 26,
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

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.label,
    required this.points,
    required this.color,
    required this.enabled,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String points;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  final bool compact;

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
            constraints: BoxConstraints(minHeight: compact ? 48 : 65),
            padding: EdgeInsets.symmetric(vertical: compact ? 2 : 4),
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
                Icon(icon, size: compact ? 17 : 20, color: onColor),
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
    required this.onNext,
  });

  final MatchUiState state;
  final GlobalKey winnerKey;
  final VoidCallback onSave;
  final VoidCallback onNext;

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
    final winnerAuthor = state.players
        .where((player) => player.name == winner.authorName)
        .firstOrNull;
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
                style: gameDisplay(size: 28, color: colors.ink),
              ),
            ),
            FrameCounter(
              current: state.currentRound,
              total: state.totalRounds,
              label: l10n.roundBadge(state.currentRound, state.totalRounds),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        ProgressSegments(current: state.currentRound, total: state.totalRounds),
        const SizedBox(height: AppSpacing.s8),
        if (state.isHosting)
          GameButton(
            label: l10n.nextRound,
            onPressed: onNext,
            icon: Icons.arrow_forward_rounded,
            fullWidth: true,
          )
        else
          NoticeBanner(
            message: l10n.waitingForHostToContinue,
            icon: Icons.hourglass_empty,
          ),
        const SizedBox(height: AppSpacing.s12),
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
              Row(
                children: <Widget>[
                  if (winnerAuthor != null) ...<Widget>[
                    PlayerAvatar(
                      initial: winnerAuthor.name,
                      avatar: winnerAuthor.avatar,
                      photoBase64: state.avatarPhotos[winnerAuthor.id],
                      size: 44,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                  ],
                  Expanded(
                    child: Text(
                      winner.authorName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: gameDisplay(
                        size: 34,
                        height: 0.98,
                        color: GamePalette.onGold,
                        letterSpacing: -1.4,
                      ),
                    ),
                  ),
                ],
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
            photoId: winner.photoId,
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
