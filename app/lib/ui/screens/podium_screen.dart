import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/game_audio_service.dart';
import '../../core/models/models.dart';
import '../../core/theme/game_skin.dart';
import '../../core/theme/responsive_game_layout.dart';
import '../../core/theme/whotook_theme.dart';
import '../../core/media/photo_memory_cache.dart';
import '../../features/photo_sabotage/sabotage_art.dart';
import '../../l10n/l10n.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/game_background.dart';
import '../widgets/game_widgets.dart';
import '../widgets/host_controls.dart';
import '../widgets/safety_controls.dart';

/// The finish line: a champion frame, centered steps, a burst of paper and the
/// Top 3 memes from a Make It Meme match.
class PodiumScreen extends ConsumerWidget {
  const PodiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final layout = ResponsiveGameLayout.of(context);
    final l10n = context.l10n;
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final board = state.leaderboard;
    final top = board.take(3).toList();
    final rest = board.skip(3).toList();
    final champion = top.isEmpty ? null : top.first;
    final runners = top.skip(1).toList();
    final displayAwards = state.awards
        .where((award) => award.kind != MatchAwardKind.champion)
        .toList();
    final skin = state.topMemes.isNotEmpty
        ? GameModeSkin.meme
        : GameModeSkin.forMode(state.config.mode);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameBackdrop(
        mode: state.topMemes.isNotEmpty
            ? GameMode.makeItMeme
            : state.config.mode,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: layout.isTablet ? 560 : 720,
                    ),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        layout.pagePadding,
                        layout.isCompactHeight ? 10 : 16,
                        layout.pagePadding,
                        layout.isCompactHeight ? 10 : 16,
                      ),
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                l10n.podium,
                                style: gameDisplay(
                                  size: layout.isCompactHeight ? 26 : 32,
                                  color: colors.ink,
                                  letterSpacing: -0.9,
                                ),
                              ),
                            ),
                            const HostControlsButton(),
                            const SizedBox(width: AppSpacing.s4),
                            StickerBadge(
                              label: l10n.roundsCount(state.totalRounds),
                              background: skin.accent,
                              foreground: skin.onAccent,
                              angle: 0.04,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        _PodiumFanfare(
                          child: _PodiumStage(
                            champion: champion,
                            runners: runners,
                            state: state,
                            l10n: l10n,
                            colors: colors,
                          ),
                        ),
                        if (rest.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.s12),
                          SurfaceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                SectionLabel(l10n.standingsLabel),
                                for (var i = 0; i < rest.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        SizedBox(
                                          width: 28,
                                          child: Text(
                                            '#${i + 4}',
                                            style: tabularFigures(
                                              TextStyle(
                                                fontFamily: 'JetBrainsMono',
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: colors.ink2,
                                              ),
                                            ),
                                          ),
                                        ),
                                        PlayerAvatar(
                                          initial: rest[i].name,
                                          avatar: rest[i].avatar,
                                          photoBase64: state.safeAvatarPhoto(
                                            rest[i].id,
                                            rest[i].name,
                                          ),
                                          isHost: rest[i].isHost,
                                          size: 26,
                                        ),
                                        const SizedBox(width: AppSpacing.s8),
                                        Expanded(
                                          child: Text(
                                            rest[i].id == state.localPlayerId
                                                ? '${rest[i].name} (${l10n.you})'
                                                : rest[i].name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                                  rest[i].id ==
                                                      state.localPlayerId
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: colors.ink,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          l10n.points(rest[i].score),
                                          style: tabularFigures(
                                            TextStyle(
                                              fontFamily: 'JetBrainsMono',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: colors.ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (state.waitingPlayersCount > 0) ...<Widget>[
                          const SizedBox(height: AppSpacing.s12),
                          NoticeBanner(
                            message: l10n.waitingPlayersNextGame(
                              state.waitingPlayersCount,
                            ),
                            icon: Icons.person_add_outlined,
                          ),
                        ],
                        if (state.topMemes.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.s16),
                          _TopMemesSection(state: state),
                        ],
                        if (displayAwards.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.s12),
                          SurfaceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                SectionLabel(l10n.matchAwards),
                                for (final award in displayAwards)
                                  _AwardRow(award: award),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              _PodiumActions(state: state, coordinator: coordinator),
            ],
          ),
        ),
      ),
    );
  }
}

class _PodiumFanfare extends StatefulWidget {
  const _PodiumFanfare({required this.child});

  final Widget child;

  @override
  State<_PodiumFanfare> createState() => _PodiumFanfareState();
}

class _PodiumFanfareState extends State<_PodiumFanfare> {
  @override
  void initState() {
    super.initState();
    unawaited(GameAudioService.instance.fanfare());
    unawaited(GameHaptics.instance.heavy());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PodiumStage extends StatelessWidget {
  const _PodiumStage({
    required this.champion,
    required this.runners,
    required this.state,
    required this.l10n,
    required this.colors,
  });

  final Player? champion;
  final List<Player> runners;
  final MatchUiState state;
  final AppLocalizations l10n;
  final WhoTookColors colors;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.rModal),
        border: Border.all(color: colors.ink, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: dark ? Colors.black : colors.ink,
            offset: const Offset(0, 7),
            blurRadius: 0,
          ),
        ],
        gradient: RadialGradient(
          center: const Alignment(0, -0.9),
          radius: 1.2,
          colors: <Color>[
            Color.alphaBlend(
              GamePalette.gold.withValues(alpha: dark ? 0.12 : 0.2),
              colors.card,
            ),
            colors.card,
          ],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: _ConfettiBurst()),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s16,
              AppSpacing.s16,
              AppSpacing.s16,
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      l10n.finalTable.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 9,
                        letterSpacing: 1.1,
                        color: colors.ink2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      l10n.roundsCount(state.totalRounds),
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 9,
                        color: colors.ink3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                if (champion != null)
                  _Champion(player: champion!, state: state),
                const SizedBox(height: AppSpacing.s12),
                if (runners.isNotEmpty)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Row(
                        children: <Widget>[
                          for (var i = 0; i < runners.length; i++) ...<Widget>[
                            if (i > 0) const SizedBox(width: AppSpacing.s8),
                            Expanded(
                              child: _PodiumStep(
                                player: runners[i],
                                place: i + 2,
                                photoBase64: state.safeAvatarPhoto(
                                  runners[i].id,
                                  runners[i].name,
                                ),
                                colors: colors,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumActions extends StatelessWidget {
  const _PodiumActions({required this.state, required this.coordinator});

  final MatchUiState state;
  final MatchCoordinator coordinator;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s8,
        AppSpacing.s20,
        AppSpacing.s8,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: state.isHosting
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    GameButton(
                      label: l10n.oneMoreRound,
                      onPressed: () => unawaited(coordinator.extendMatch()),
                      icon: Icons.replay,
                      fullWidth: true,
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    GameButton(
                      label: l10n.backToLobby,
                      onPressed: () => unawaited(coordinator.playAgain()),
                      variant: GameButtonVariant.secondary,
                      icon: Icons.meeting_room_outlined,
                      fullWidth: true,
                    ),
                    TextButton(
                      onPressed: () => unawaited(coordinator.leaveMatch()),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        foregroundColor: WhoTookColors.of(context).ink2,
                      ),
                      child: Text(l10n.leaveMatch),
                    ),
                  ],
                )
              : NoticeBanner(
                  message: l10n.waitingForHost,
                  icon: Icons.hourglass_empty,
                ),
        ),
      ),
    );
  }
}

class _TopMemesSection extends StatelessWidget {
  const _TopMemesSection({required this.state});

  final MatchUiState state;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.emoji_events, color: GamePalette.goldDeep),
            const SizedBox(width: AppSpacing.s8),
            Text(
              l10n.topCreations,
              style: gameDisplay(size: 20, color: colors.ink),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        for (var i = 0; i < state.topMemes.length; i++) ...<Widget>[
          _TopMemeCard(
            meme: state.topMemes[i],
            rank: i + 1,
            player: state.players
                .where((p) => p.id == state.topMemes[i].authorId)
                .firstOrNull,
            avatarPhoto: state.safeAvatarPhoto(
              state.topMemes[i].authorId,
              state.topMemes[i].authorName,
            ),
            hidden: state.isCardBlocked(state.topMemes[i]),
          ),
          if (i != state.topMemes.length - 1)
            const SizedBox(height: AppSpacing.s12),
        ],
      ],
    );
  }
}

class _TopMemeCard extends StatefulWidget {
  const _TopMemeCard({
    required this.meme,
    required this.rank,
    required this.player,
    required this.avatarPhoto,
    this.hidden = false,
  });

  final MemeCard meme;
  final int rank;
  final Player? player;
  final String? avatarPhoto;
  final bool hidden;

  @override
  State<_TopMemeCard> createState() => _TopMemeCardState();
}

class _TopMemeCardState extends State<_TopMemeCard> {
  final GlobalKey _key = GlobalKey();
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await MemeExporter.save(_key, album: 'WhoTook');
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? context.l10n.memeSaved : context.l10n.memeSaveFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final meme = widget.meme;
    final name = meme.authorName ?? widget.player?.name ?? l10n.player;
    return Container(
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
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.rank == 1 ? GamePalette.gold : colors.raised,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.ink, width: 2),
                ),
                child: Text(
                  '#${widget.rank}',
                  style: gameDisplay(
                    size: 13,
                    color: widget.rank == 1 ? GamePalette.onGold : colors.ink,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              PlayerAvatar(
                initial: name,
                avatar: widget.player?.avatar ?? '',
                photoBase64: widget.avatarPhoto,
                isHost: widget.player?.isHost ?? false,
                size: 36,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (widget.rank == 1)
                      Text(
                        (meme.isSabotage
                                ? l10n.winningSabotage
                                : l10n.winningMemeTitle)
                            .toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 7,
                          letterSpacing: 0.6,
                          color: GamePalette.goldDeep,
                        ),
                      ),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colors.ink,
                      ),
                    ),
                    Text(
                      l10n.memeVoteTally(
                        meme.upVotes,
                        meme.mehVotes,
                        meme.downVotes,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: colors.ink2),
                    ),
                  ],
                ),
              ),
              StickerBadge(
                label: l10n.memePoints(meme.points),
                background: GamePalette.gold,
                foreground: GamePalette.onGold,
                angle: 0.04,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          RepaintBoundary(
            key: _key,
            child: widget.hidden
                ? const AspectRatio(
                    aspectRatio: 4 / 5,
                    child: BlockedContentPlaceholder(),
                  )
                : (meme.isSabotage
                      ? AspectRatio(
                          aspectRatio: 4 / 5,
                          child: SabotageArt(
                            photoId: meme.photoId,
                            photoBytes: PhotoMemoryCache.instance.bytesFor(
                              meme.photoId,
                            ),
                            strokes: meme.strokes,
                            stickers: meme.stickers,
                            showWatermark: true,
                          ),
                        )
                      : MemeCanvas(
                          bytes: _decodeMeme(meme.photoBase64),
                          photoId: meme.photoId,
                          template: meme.template,
                          topText: meme.topText,
                          bottomText: meme.bottomText,
                          snapY: meme.snapY,
                          showWatermark: true,
                        )),
          ),
          const SizedBox(height: AppSpacing.s8),
          GameButton(
            label: meme.isSabotage ? l10n.sabotageSave : l10n.memeDownload,
            onPressed: _saving || widget.hidden ? null : _save,
            variant: GameButtonVariant.gold,
            icon: Icons.download_outlined,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

Uint8List? _decodeMeme(String value) {
  if (value.isEmpty) return null;
  try {
    return base64Decode(value);
  } on FormatException {
    return null;
  }
}

class _Champion extends StatelessWidget {
  const _Champion({required this.player, required this.state});

  final Player player;
  final MatchUiState state;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final layout = ResponsiveGameLayout.of(context);
    final l10n = context.l10n;
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GamePalette.gold, width: 3),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: GamePalette.gold.withValues(alpha: 0.22),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              PlayerAvatar(
                initial: player.name,
                avatar: player.avatar,
                photoBase64: state.safeAvatarPhoto(player.id, player.name),
                isHost: player.isHost,
                size: layout.isCompactHeight ? 92 : 116,
                crown: true,
              ),
              Positioned(
                right: -4,
                bottom: 2,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: GamePalette.gold,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.card, width: 3),
                  ),
                  child: const Icon(
                    Icons.emoji_events_outlined,
                    size: 17,
                    color: Color(0xFF2A1B06),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.placeFirst.toUpperCase(),
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 9,
                letterSpacing: 1,
                color: colors.ink2,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.card,
                border: Border.all(color: GamePalette.goldDeep),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l10n.champion.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 8,
                  letterSpacing: 0.8,
                  color: colors.ink,
                ),
              ),
            ),
          ],
        ),
        Text(
          player.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: layout.isCompactHeight
              ? gameDisplay(size: 28, color: colors.ink, letterSpacing: -1.4)
              : TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.4,
                  height: 0.98,
                  color: colors.ink,
                ),
        ),
        const SizedBox(height: 3),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: player.score.toDouble()),
          duration: const Duration(milliseconds: 850),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Text(
            l10n.points(value.round()),
            style: tabularFigures(
              TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 15,
                color: Theme.of(context).brightness == Brightness.dark
                    ? GamePalette.gold
                    : GamePalette.goldInk,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PodiumStep extends StatelessWidget {
  const _PodiumStep({
    required this.player,
    required this.place,
    required this.photoBase64,
    required this.colors,
  });

  final Player player;
  final int place;
  final String? photoBase64;
  final WhoTookColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (place) {
      2 => l10n.placeSecond,
      3 => l10n.placeThird,
      _ => l10n.placeNth(place),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 9, 7, 9),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(9),
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
        children: <Widget>[
          PlayerAvatar(
            initial: player.name,
            avatar: player.avatar,
            photoBase64: photoBase64,
            isHost: player.isHost,
            size: 38,
          ),
          const SizedBox(height: 5),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 8,
              color: colors.ink3,
            ),
          ),
          Text(
            player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          Text(
            l10n.points(player.score),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 10,
              color: colors.ink2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AwardRow extends StatelessWidget {
  const _AwardRow({required this.award});

  final MatchAward award;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final (label, icon) = switch (award.kind) {
      MatchAwardKind.champion => (l10n.champion, Icons.emoji_events_outlined),
      MatchAwardKind.quickestDraw => (l10n.quickestDraw, Icons.bolt_outlined),
      MatchAwardKind.unstoppable => (l10n.longestStreak, Icons.trending_up),
      MatchAwardKind.masterOfMystery => (
        l10n.masterOfMystery,
        Icons.visibility_off_outlined,
      ),
      MatchAwardKind.paparazzi => (l10n.paparazzi, Icons.camera_alt_outlined),
      MatchAwardKind.smoothPlanter => (
        l10n.smoothPlanter,
        Icons.local_florist_outlined,
      ),
      MatchAwardKind.crowdFavorite => (
        l10n.crowdFavorite,
        Icons.thumb_up_alt_outlined,
      ),
    };
    final suffix = switch (award.kind) {
      MatchAwardKind.quickestDraw =>
        ' ${l10n.awardSeconds(((award.value ?? 0) / 1000).toStringAsFixed(1))}',
      MatchAwardKind.unstoppable => ' ${l10n.awardStreak(award.value ?? 0)}',
      MatchAwardKind.masterOfMystery =>
        ' ${l10n.awardWrongGuesses(award.value ?? 0)}',
      MatchAwardKind.paparazzi => ' ${l10n.awardFrames(award.value ?? 0)}',
      MatchAwardKind.smoothPlanter => ' ${l10n.awardFooled(award.value ?? 0)}',
      MatchAwardKind.crowdFavorite => ' ${l10n.awardUpvotes(award.value ?? 0)}',
      MatchAwardKind.champion => ' ${l10n.awardPoints(award.value ?? 0)}',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 16, color: colors.ink3),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            flex: 5,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: colors.ink2),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            flex: 6,
            child: Text(
              '${award.playerName}$suffix',
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiBurst extends StatefulWidget {
  const _ConfettiBurst();

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward();
    _pieces = _buildPieces();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(
          progress: _controller,
          pieces: _pieces,
          colors: <Color>[
            colors.accent,
            GamePalette.gold,
            GamePalette.teal,
            GamePalette.blue,
            colors.ink3,
          ],
        ),
      ),
    );
  }

  List<_ConfettiPiece> _buildPieces() {
    final random = math.Random(14);
    return List<_ConfettiPiece>.generate(54, (index) {
      return _ConfettiPiece(
        x: random.nextDouble(),
        delay: random.nextDouble() * 0.32,
        speed: 0.3 + random.nextDouble() * 0.5,
        drift: (random.nextDouble() - 0.5) * 0.24,
        rotation: random.nextDouble() * math.pi * 2,
        spin: (random.nextDouble() - 0.5) * 8,
        size: 4 + random.nextDouble() * 5,
        round: index % 5 == 0,
      );
    });
  }
}

class _ConfettiPiece {
  const _ConfettiPiece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.rotation,
    required this.spin,
    required this.size,
    required this.round,
  });

  final double x;
  final double delay;
  final double speed;
  final double drift;
  final double rotation;
  final double spin;
  final double size;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.progress,
    required this.pieces,
    required this.colors,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final List<_ConfettiPiece> pieces;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < pieces.length; i++) {
      final piece = pieces[i];
      final raw = ((progress.value - piece.delay) / (1 - piece.delay)).clamp(
        0.0,
        1.0,
      );
      if (raw <= 0) continue;
      final t = Curves.easeIn.transform(raw);
      final x = (piece.x + piece.drift * t) * size.width;
      final y = t * (size.height + 80) - 20;
      final paint = Paint()..color = colors[i % colors.length];
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.rotation + piece.spin * t);
      if (piece.round) {
        canvas.drawCircle(Offset.zero, piece.size * 0.55, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.size,
            height: piece.size * 1.7,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.pieces != pieces ||
      oldDelegate.colors != colors;
}
