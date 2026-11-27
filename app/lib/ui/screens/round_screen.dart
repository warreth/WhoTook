import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/game_audio_service.dart';
import '../../core/models/models.dart';
import '../../core/theme/game_skin.dart';
import '../../core/theme/responsive_game_layout.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/game_background.dart';
import '../widgets/game_widgets.dart';
import '../widgets/host_controls.dart';
import '../widgets/mode_picker.dart';
import '../widgets/round_scoreboard.dart';

/// One photo, one timer, and every player in the room as a button, including
/// yourself, so a glance at a screen never gives the owner away.
class RoundScreen extends ConsumerWidget {
  const RoundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final layout = ResponsiveGameLayout.of(context);
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
                          showingReveal || showingCountdown
                              ? l10n.roundOf(roundNumber, state.totalRounds)
                              : l10n.whoTookThis,
                          style: gameDisplay(
                            size: layout.titleSize,
                            color: colors.ink,
                          ),
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
                        activeMode: state.activeMode,
                        isFinalDoubleRound: state.isFinalDoubleRound,
                        syncReceived: state.vaultSyncReceived,
                        syncTotal: state.vaultSyncTotal,
                      ),
                    )
                  else if (showingReveal)
                    Expanded(
                      child: _RevealBlock(
                        reveal: reveal,
                        players: state.players,
                        avatarPhotos: state.avatarPhotos,
                        localPlayerId: state.localPlayerId,
                        photoBytes: state.activePhotoBytes,
                        photoId: reveal.photoId,
                        isHosting: state.isHosting,
                        isFinalDoubleRound: state.isFinalDoubleRound,
                        onNext: () => unawaited(coordinator.skipRound()),
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
                          photoId: state.activePhotoId,
                          isPanorama: state.activePhotoIsPanorama,
                        ),
                      ),
                    ),
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
                    const SizedBox(height: AppSpacing.s8),
                    if (state.lockedGuessOwnerId != null)
                      Text(
                        l10n.lockedInWaiting,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: colors.ink2),
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

/// The gap between "photos are ready" and the first frame. A calm numeral, no
/// empty photo box and no ticking timer that is not running yet.
class _CountdownView extends StatelessWidget {
  const _CountdownView({
    required this.seconds,
    required this.activeMode,
    this.isFinalDoubleRound = false,
    this.syncReceived = 0,
    this.syncTotal = 0,
  });

  final int seconds;
  final GameMode activeMode;
  final bool isFinalDoubleRound;
  final int syncReceived;
  final int syncTotal;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final syncing = syncTotal > 0;
    return Center(
      child: Semantics(
        liveRegion: true,
        label: syncing ? l10n.syncingVaults : l10n.countdown,
        value: syncing
            ? l10n.syncingVaultsProgress(syncReceived, syncTotal)
            : l10n.countdownSeconds(seconds),
        child: SurfaceCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s24,
            vertical: AppSpacing.s32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s4,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  StickerBadge(
                    label: modeLabel(l10n, activeMode).toUpperCase(),
                    background: colors.raised,
                    foreground: colors.ink,
                  ),
                  if (isFinalDoubleRound)
                    StickerBadge(
                      label: l10n.finalRoundDoubleBadge,
                      background: GamePalette.gold,
                      foreground: GamePalette.onGold,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                syncing ? l10n.syncingVaults : l10n.getReady,
                style: TextStyle(fontSize: 15, color: colors.ink2),
              ),
              const SizedBox(height: AppSpacing.s8),
              if (syncing) ...<Widget>[
                SizedBox(
                  width: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: syncTotal == 0 ? null : syncReceived / syncTotal,
                      minHeight: 10,
                      backgroundColor: colors.raised,
                      color: colors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                Text(
                  l10n.syncingVaultsProgress(syncReceived, syncTotal),
                  textAlign: TextAlign.center,
                  style: tabularFigures(
                    TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.ink,
                    ),
                  ),
                ),
              ] else
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
  const _PhotoFrame({
    super.key,
    required this.bytes,
    this.photoId,
    this.isPanorama = false,
  });

  final Uint8List? bytes;
  final String? photoId;
  final bool isPanorama;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return Semantics(
      container: true,
      image: true,
      label: l10n.gamePhoto,
      child: GestureDetector(
        onTap: bytes == null || bytes!.isEmpty
            ? null
            : () => showPhotoLightbox(
                context,
                bytes: bytes,
                photoId: photoId,
                caption: l10n.tapToZoomBody,
              ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Container(
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
                    child: _Photo(
                      bytes: bytes,
                      photoId: photoId,
                      isPanorama: isPanorama,
                    ),
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
            Positioned(right: 14, bottom: 14, child: TapToZoomBadge()),
          ],
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.bytes, this.photoId, this.isPanorama = false});

  final Uint8List? bytes;
  final String? photoId;
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
        photoId: photoId,
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
    required this.photoBytes,
    required this.photoId,
    required this.isHosting,
    required this.onNext,
    this.isFinalDoubleRound = false,
  });

  final RoundReveal reveal;
  final List<Player> players;
  final Map<String, String> avatarPhotos;
  final String? localPlayerId;
  final Uint8List? photoBytes;
  final String photoId;
  final bool isHosting;
  final VoidCallback onNext;
  final bool isFinalDoubleRound;

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
    _timer = Timer(const Duration(milliseconds: 500), () {
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

  Player? _player(String id) =>
      widget.players.where((player) => player.id == id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final reveal = widget.reveal;
    final owner = _player(reveal.ownerId);
    final fastest = reveal.microAward?.kind == MicroAwardKind.fastestGuess
        ? reveal.microAward
        : null;
    final fooled = reveal.guesses
        .where(
          (g) => !g.isOwnPhoto && !g.isCorrect && g.guessedOwnerId.isNotEmpty,
        )
        .length;
    final missed = reveal.guesses
        .where((g) => !g.isOwnPhoto && g.guessedOwnerId.isEmpty)
        .length;
    final localId = widget.localPlayerId;
    final localGuess = localId == null
        ? null
        : reveal.guesses.where((g) => g.playerId == localId).firstOrNull;
    final localOwnPhoto = localId != null && reveal.ownerId == localId;
    final (localResult, localTone, localIcon) = switch (localGuess) {
      _ when localId == null => (null, colors.ink2, Icons.remove),
      null => (l10n.noAnswer, colors.negative, Icons.timer_off_outlined),
      _ when localGuess.guessedOwnerId.isEmpty => (
        l10n.noAnswer,
        colors.negative,
        Icons.timer_off_outlined,
      ),
      _ when localGuess.isCorrect => (
        localOwnPhoto
            ? l10n.yourPhotoYouGotIt(localGuess.pointsAwarded)
            : l10n.youGotIt(localGuess.pointsAwarded),
        colors.positive,
        Icons.check_circle_outline,
      ),
      _ => (
        localOwnPhoto ? l10n.yourPhotoWrongGuess : l10n.wrongGuess,
        colors.negative,
        Icons.cancel_outlined,
      ),
    };
    final ownerDelta = owner == null ? 0 : (reveal.scoreDeltas[owner.id] ?? 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              _RevealHero(
                shown: _shown,
                owner: owner,
                ownerAvatar: owner == null
                    ? null
                    : widget.avatarPhotos[owner.id],
                photoBytes: widget.photoBytes,
                photoId: widget.photoId,
                fastest: fastest,
                fooled: fooled,
                missed: missed,
                nobodyGuessed: reveal.nobodyGuessed,
                everyoneGuessed: reveal.everyoneGuessed,
              ),
              if (localResult != null && _shown) ...<Widget>[
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Icon(localIcon, size: 14, color: localTone),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        localResult,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: localTone,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (_shown && owner != null && fooled > 0 && ownerDelta > 0) ...<Widget>[
                const SizedBox(height: 6),
                NoticeBanner(
                  message:
                      '${owner.name}: ${l10n.playersFooled(fooled)} (${l10n.points(ownerDelta)})',
                  icon: Icons.visibility_off_outlined,
                ),
              ],
              if (_shown) ...<Widget>[
                const SizedBox(height: AppSpacing.s12),
                RoundScoreboard(
                  players: widget.players,
                  scoreDeltas: reveal.scoreDeltas,
                  streaks: reveal.streaks,
                  avatarPhotos: widget.avatarPhotos,
                  localPlayerId: widget.localPlayerId,
                  doublePoints: widget.isFinalDoubleRound,
                ),
              ],
              const SizedBox(height: AppSpacing.s12),
              for (var i = 0; i < reveal.guesses.length; i++) ...<Widget>[
                Builder(
                  builder: (context) {
                    final guess = reveal.guesses[i];
                    final player = _player(guess.playerId);
                    final guessed = guess.guessedOwnerId.isEmpty
                        ? null
                        : _player(guess.guessedOwnerId);
                    return _RevealGuessCard(
                      shown: _shown,
                      guess: guess,
                      player: player,
                      guessedName: guessed?.name,
                      avatarPhoto: player == null
                          ? null
                          : widget.avatarPhotos[player.id],
                      isLocal: player?.id == widget.localPlayerId,
                      isOwner: guess.isOwnPhoto,
                    );
                  },
                ),
                if (i != reveal.guesses.length - 1) const SizedBox(height: 7),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        if (widget.isHosting)
          GameButton(
            label: l10n.nextRound,
            onPressed: widget.onNext,
            icon: Icons.arrow_forward_rounded,
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

class _RevealHero extends StatelessWidget {
  const _RevealHero({
    required this.shown,
    required this.owner,
    required this.ownerAvatar,
    required this.photoBytes,
    required this.photoId,
    required this.fastest,
    required this.fooled,
    required this.missed,
    required this.nobodyGuessed,
    required this.everyoneGuessed,
  });

  final bool shown;
  final Player? owner;
  final String? ownerAvatar;
  final Uint8List? photoBytes;
  final String photoId;
  final MicroAward? fastest;
  final int fooled;
  final int missed;
  final bool nobodyGuessed;
  final bool everyoneGuessed;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final ownerName = owner?.name ?? l10n.player;
    final summary = <String>[
      if (fooled > 0) l10n.playersFooled(fooled),
      if (missed > 0) l10n.playersDidNotAnswer(missed),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rCard),
        border: Border.all(color: colors.ink, width: 2.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.ink,
            offset: const Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 108,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                PolaroidPhotoCard(
                  bytes: photoBytes,
                  caption: shown ? l10n.shotBy(ownerName) : '...',
                  tilt: -0.045,
                  aspectRatio: 1.02,
                  onTap: photoBytes == null || photoBytes!.isEmpty
                      ? null
                      : () => showPhotoLightbox(
                          context,
                          bytes: photoBytes,
                          photoId: photoId,
                          caption: ownerName,
                        ),
                ),
                if (shown && owner != null)
                  Positioned(
                    right: -8,
                    bottom: 6,
                    child: Transform.rotate(
                      angle: 0.08,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: colors.card,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.ink, width: 2.5),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: colors.ink,
                              offset: const Offset(0, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: PlayerAvatar(
                          initial: ownerName,
                          avatar: owner!.avatar,
                          photoBase64: ownerAvatar,
                          isHost: owner!.isHost,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 260),
                  opacity: shown ? 1 : 0,
                  child: Text(
                    shown ? l10n.itWasPhotoOf(ownerName) : l10n.whoTookIt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: gameDisplay(size: 19, color: colors.ink),
                  ),
                ),
                const SizedBox(height: 6),
                if (fastest != null)
                  _RevealBadge(
                    icon: Icons.bolt,
                    background: GamePalette.gold,
                    foreground: GamePalette.onGold,
                    label: l10n.fastestAward(
                      fastest!.playerName ?? '',
                      ((fastest!.elapsedMs ?? 0) / 1000).toStringAsFixed(1),
                    ),
                  )
                else if (shown)
                  _RevealBadge(
                    icon: Icons.visibility_off_outlined,
                    background: colors.raised,
                    foreground: colors.ink2,
                    label: nobodyGuessed
                        ? l10n.nobodyGuessed
                        : everyoneGuessed
                        ? l10n.everyoneNailedIt
                        : fooled > 0
                        ? l10n.playersFooled(fooled)
                        : l10n.everyoneGotItRight,
                  ),
                if (owner != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.photo_camera_outlined,
                        size: 13,
                        color: colors.ink3,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          summary.isEmpty ? l10n.everyoneGotItRight : summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            color: colors.ink2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevealBadge extends StatelessWidget {
  const _RevealBadge({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.label,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: GamePalette.onGold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevealGuessCard extends StatelessWidget {
  const _RevealGuessCard({
    required this.shown,
    required this.guess,
    required this.player,
    required this.guessedName,
    required this.avatarPhoto,
    required this.isLocal,
    required this.isOwner,
  });

  final bool shown;
  final GuessRecord guess;
  final Player? player;
  final String? guessedName;
  final String? avatarPhoto;
  final bool isLocal;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final name = player?.name ?? l10n.player;
    final (detail, detailTone) = switch (guess) {
      _ when !shown => (l10n.revealing, colors.ink2),
      _ when guess.guessedOwnerId.isEmpty => (
        l10n.noGuessMade,
        colors.negative,
      ),
      _ when guess.isOwnPhoto => (l10n.ownerLabel, colors.ink2),
      _ when guess.isCorrect => (l10n.guessedCorrectly, colors.positive),
      _ => (l10n.guessedWrong(guessedName ?? l10n.player), colors.negative),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      decoration: BoxDecoration(
        color: isOwner ? colors.raised : colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rControl),
        border: Border.all(
          color: isLocal ? colors.accent : colors.ink,
          width: isLocal ? 2.5 : 2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.ink,
            offset: const Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          PlayerAvatar(
            initial: name,
            avatar: player?.avatar ?? '',
            photoBase64: avatarPhoto,
            isHost: player?.isHost ?? false,
            size: 34,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colors.ink,
                        ),
                      ),
                    ),
                    if (isOwner) ...<Widget>[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.photo_camera,
                        size: 12,
                        color: GamePalette.goldDeep,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: detailTone,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end: shown ? guess.pointsAwarded.toDouble() : 0,
                ),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: guess.pointsAwarded > 0
                        ? colors.positive
                        : colors.raised,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colors.ink, width: 1.5),
                  ),
                  child: Text(
                    guess.pointsAwarded > 0
                        ? '+${l10n.points(value.round())}'
                        : '+0',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: guess.pointsAwarded > 0
                          ? Colors.white
                          : colors.ink3,
                    ),
                  ),
                ),
              ),
              if (player != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  '${player!.score}',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 9,
                    color: colors.ink3,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
