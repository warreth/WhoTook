import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/avatars.dart';
import '../../core/media/avatar_photo_service.dart';
import '../../core/models/models.dart';
import '../../core/theme/game_skin.dart';
import '../../core/theme/responsive_game_layout.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import '../widgets/audio_toggle_buttons.dart';
import '../widgets/avatar_editor.dart';
import '../widgets/common.dart';
import '../widgets/game_background.dart';
import '../widgets/game_widgets.dart';
import '../widgets/mode_picker.dart';
import '../widgets/online_hint.dart';
import '../widgets/party_pass_bar.dart';
import 'avatar_crop_screen.dart';

class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final isHost = state.isHosting;
    final layout = ResponsiveGameLayout.of(context);
    final l10n = context.l10n;
    final demo = ref.watch(demoModeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: isHost
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.s20,
                AppSpacing.s8,
                AppSpacing.s20,
                AppSpacing.s16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: layout.isTablet ? 560 : 720,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: GameButton(
                          label: l10n.startPhotoCheck,
                          icon: Icons.photo_camera_outlined,
                          onPressed: () =>
                              unawaited(coordinator.startPrepare()),
                          fullWidth: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
      appBar: AppBar(
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          isHost ? l10n.yourRoom : l10n.lobby,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
        ),
        actions: <Widget>[
          const AudioToggleButtons(),
          IconButton(
            tooltip: demo ? l10n.closeDemo : l10n.leaveMatch,
            onPressed: demo
                ? () => Navigator.of(context).maybePop()
                : () => unawaited(coordinator.leaveMatch()),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: GameBackdrop(
        mode: state.config.mode,
        lobby: true,
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s20,
                  AppSpacing.s8,
                  AppSpacing.s20,
                  112,
                ),
                children: <Widget>[
                  if (demo) ...<Widget>[
                    Text(
                      l10n.demoLobbyTitle,
                      style: gameDisplay(
                        size: layout.isCompactHeight ? 28 : 34,
                        height: 1.02,
                        color: colors.ink,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      l10n.demoLobbyBody,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: colors.ink2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    NoticeBanner(
                      message: l10n.demoIntroNotice,
                      icon: Icons.smart_toy_outlined,
                    ),
                  ] else if (isHost && state.inviteUrl != null) ...<Widget>[
                    Text(
                      l10n.scanToJoin,
                      style: gameDisplay(
                        size: layout.isCompactHeight ? 28 : 34,
                        height: 1.02,
                        color: colors.ink,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      l10n.scanToJoinBody,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: colors.ink2,
                      ),
                    ),
                    SizedBox(
                      height: layout.isCompactHeight ? 8 : AppSpacing.s16,
                    ),
                    SurfaceCard(
                      padding: EdgeInsets.all(
                        layout.isCompactHeight ? 10 : AppSpacing.s16,
                      ),
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.raised,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.rSm,
                                  ),
                                ),
                                child: Text(
                                  l10n.roomCode(state.roomId ?? ''),
                                  style: tabularFigures(
                                    const TextStyle(
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 10,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              StatusRow(
                                label:
                                    state.connectionMode ==
                                        ConnectionMode.localLan
                                    ? l10n.sameWifi
                                    : l10n.online,
                                tone: StatusTone.positive,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          Container(
                            padding: EdgeInsets.all(
                              layout.isCompactHeight ? 8 : AppSpacing.s12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppRadii.rSm),
                            ),
                            child: QrImageView(
                              data: state.inviteUrl!,
                              version: QrVersions.auto,
                              size: layout.qrSize,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF1F1B16),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF1F1B16),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          SecondaryButton(
                            label: l10n.shareInviteLink,
                            icon: Icons.ios_share,
                            onPressed: () => _shareInvite(context, state),
                          ),
                        ],
                      ),
                    ),
                  ] else ...<Widget>[
                    Text(
                      l10n.youreIn,
                      style: gameDisplay(
                        size: layout.isCompactHeight ? 28 : 34,
                        height: 1.02,
                        color: colors.ink,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      l10n.hostStartsPhotoCheck,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: colors.ink2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    NoticeBanner(
                      message: l10n.waitingForHostToStart,
                      icon: Icons.hourglass_empty,
                    ),
                    OnlinePlayHint(
                      key: ValueKey<String>(
                        'online-hint-${state.roomId ?? ''}',
                      ),
                      mode: state.connectionMode,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s16),
                  _ModeBanner(
                    mode: state.config.mode,
                    isHost: isHost,
                    onEdit: isHost
                        ? () => unawaited(_openSetupEditor(context))
                        : null,
                  ),
                  if (!demo) ...<Widget>[
                    const SizedBox(height: AppSpacing.s12),
                    const PartyPassLobbyBar(),
                  ],
                  SizedBox(height: layout.isCompactHeight ? 8 : AppSpacing.s12),
                  SurfaceCard(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s16,
                      AppSpacing.s12,
                      AppSpacing.s8,
                      AppSpacing.s12,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Wrap(
                            spacing: AppSpacing.s12,
                            runSpacing: AppSpacing.s8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              _SetupChip(
                                icon: Icons.casino_outlined,
                                label: l10n.roundsCount(state.config.roundsK),
                              ),
                              _SetupChip(
                                icon: Icons.timer_outlined,
                                label:
                                    '${_paceName(l10n, state.config.roundSeconds)} · ${l10n.secondsShort(state.config.roundSeconds)}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  if (!demo) ...<Widget>[
                    _LobbyAvatarCard(state: state),
                    const SizedBox(height: AppSpacing.s16),
                  ],
                  SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.s16,
                            AppSpacing.s12,
                            AppSpacing.s16,
                            AppSpacing.s12,
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  l10n.playersJoined(state.players.length),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                l10n.roomLabel(state.roomId ?? ''),
                                style: tabularFigures(
                                  TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 12,
                                    color: colors.ink3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (final player in state.players)
                          _PlayerRow(
                            player: player,
                            photoBase64: state.avatarPhotos[player.id],
                            onKick: isHost && !player.isHost
                                ? () => unawaited(
                                    _confirmKick(context, coordinator, player),
                                  )
                                : null,
                          ),
                        if (state.players.length == 1)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.s16),
                            child: EmptyState(
                              title: l10n.waitingFirstFriend,
                              body: l10n.waitingFirstFriendBody,
                            ),
                          ),
                      ],
                    ),
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSetupEditor(BuildContext context) {
    // The demo keeps its coordinator in a nested ProviderScope. A modal route
    // is mounted above that scope, so it needs the demo container explicitly.
    final container = ProviderScope.containerOf(context, listen: false);
    final demo = container.read(demoModeProvider);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => demo
          ? UncontrolledProviderScope(
              container: container,
              child: const _LobbySetupSheet(),
            )
          : const _LobbySetupSheet(),
    );
  }

  Future<void> _confirmKick(
    BuildContext context,
    MatchCoordinator coordinator,
    Player player,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removePlayerTitle(player.name)),
        content: Text(l10n.removePlayerLobbyBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: WhoTookColors.of(context).negative,
            ),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await coordinator.kickPlayer(player.id);
    }
  }

  Future<void> _shareInvite(BuildContext context, MatchUiState state) async {
    final url = state.inviteUrl;
    if (url == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _InviteSheet(url: url),
    );
  }
}

String _paceName(AppLocalizations l10n, int seconds) => switch (seconds) {
  6 => l10n.paceFast,
  12 => l10n.paceSlow,
  _ => l10n.paceNormal,
};

String _paceOptionName(AppLocalizations l10n, GamePace pace) => switch (pace) {
  GamePace.fast => l10n.paceFast,
  GamePace.normal => l10n.paceNormal,
  GamePace.slow => l10n.paceSlow,
};

class _ModeBanner extends StatelessWidget {
  const _ModeBanner({
    required this.mode,
    required this.isHost,
    required this.onEdit,
  });

  final GameMode mode;
  final bool isHost;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final gold = mode == GameMode.makeItMeme;
    final ink = gold ? GamePalette.onGold : colors.ink;
    final ink2 = gold ? GamePalette.onGoldMuted : colors.ink2;
    final info = modeInfo(mode);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: gold ? GamePalette.gold : colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rControl),
        border: Border.all(color: ink, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(color: ink, blurRadius: 0, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(AppRadii.rSm),
            ),
            child: Icon(
              info.icon,
              size: 17,
              color: gold ? GamePalette.gold : colors.bg,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  modeLabel(l10n, mode),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                Text(
                  modeBlurb(l10n, mode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: ink2),
                ),
              ],
            ),
          ),
          if (isHost)
            TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                foregroundColor: ink,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(l10n.editAction),
            ),
        ],
      ),
    );
  }
}

class _SetupChip extends StatelessWidget {
  const _SetupChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: colors.ink2),
        const SizedBox(width: AppSpacing.s4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.url});

  final String url;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s24,
        0,
        AppSpacing.s24,
        AppSpacing.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.inviteLink,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: AppSpacing.s8),
          SelectableText(
            widget.url,
            style: const TextStyle(fontSize: 12, fontFamily: 'JetBrainsMono'),
          ),
          const SizedBox(height: AppSpacing.s16),
          PrimaryButton(
            label: _copied ? l10n.copied : l10n.copyLink,
            icon: _copied ? Icons.check : Icons.copy,
            onPressed: () => unawaited(_copy()),
          ),
          const SizedBox(height: AppSpacing.s12),
          SecondaryButton(
            label: l10n.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.photoBase64,
    this.onKick,
  });

  final Player player;
  final String? photoBase64;
  final VoidCallback? onKick;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: Row(
        children: <Widget>[
          PlayerAvatar(
            initial: player.name,
            avatar: player.avatar,
            photoBase64: photoBase64,
            isHost: player.isHost,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              player.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            player.isHost
                ? l10n.hostLabel
                : (player.ready ? l10n.ready : l10n.choosing),
            style: TextStyle(
              fontSize: 12,
              color: player.ready || player.isHost ? colors.ink2 : colors.ink3,
            ),
          ),
          if (onKick != null)
            PopupMenuButton<String>(
              tooltip: l10n.playerOptions,
              icon: const Icon(Icons.more_horiz, size: 20),
              onSelected: (_) => onKick!(),
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'remove',
                  child: Text(l10n.removeFromRoom),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LobbySetupSheet extends ConsumerWidget {
  const _LobbySetupSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final config = state.config;
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s20,
            0,
            AppSpacing.s20,
            AppSpacing.s24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.tonightsGame,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.6,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                l10n.editGameBody,
                style: TextStyle(fontSize: 13, height: 1.4, color: colors.ink2),
              ),
              const SizedBox(height: AppSpacing.s16),
              SectionLabel(l10n.modeLabel),
              ModePicker(
                mode: config.mode,
                onSelect: (mode) => unawaited(coordinator.setMode(mode)),
              ),
              if (config.mode == GameMode.mixedParty) ...<Widget>[
                const SizedBox(height: AppSpacing.s12),
                Text(
                  l10n.mixedModesLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  l10n.mixedModesHint,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: colors.ink2,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                MixedModePicker(
                  selected: config.activeMixedModes,
                  onChanged: (modes) =>
                      unawaited(coordinator.setMixedModes(modes)),
                ),
              ],
              const SizedBox(height: AppSpacing.s16),
              SectionLabel(l10n.roundsLabel),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: <Widget>[
                  for (final rounds in const <int>[5, 10, 15, 20])
                    _SheetChoice(
                      label: '$rounds',
                      selected: config.roundsK == rounds,
                      onTap: () => unawaited(coordinator.setRounds(rounds)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              SectionLabel(l10n.paceLabel),
              Row(
                children: <Widget>[
                  for (final pace in GamePace.values)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: pace == GamePace.slow ? 0 : AppSpacing.s8,
                        ),
                        child: _SheetChoice(
                          label: _paceOptionName(l10n, pace),
                          detail: config.mode == GameMode.mixedParty
                              ? l10n.mixed
                              : l10n.secondsShort(
                                  pace.mainSeconds(config.mode),
                                ),
                          selected: config.pace == pace,
                          onTap: () => unawaited(coordinator.setPace(pace)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s24),
              PrimaryButton(
                label: l10n.done,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetChoice extends StatelessWidget {
  const _SheetChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.detail,
  });

  final String label;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Semantics(
      selected: selected,
      button: true,
      label: detail == null ? label : '$label, $detail',
      child: Material(
        color: selected ? colors.raised : colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rControl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.rControl),
          child: Container(
            height: detail == null ? 44 : 58,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.rControl),
              border: Border.all(
                color: selected ? colors.accent : colors.hairline,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: selected ? colors.accent : colors.ink,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    style: TextStyle(fontSize: 10, color: colors.ink3),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LobbyAvatarCard extends ConsumerStatefulWidget {
  const _LobbyAvatarCard({required this.state});

  final MatchUiState state;

  @override
  ConsumerState<_LobbyAvatarCard> createState() => _LobbyAvatarCardState();
}

class _LobbyAvatarCardState extends ConsumerState<_LobbyAvatarCard> {
  bool _picking = false;

  Player? get _local => widget.state.players
      .where((player) => player.id == widget.state.localPlayerId)
      .firstOrNull;

  Future<void> _apply(String avatar, String? photo) async {
    final coordinator = ref.read(matchCoordinatorProvider);
    await ref
        .read(appSettingsProvider.notifier)
        .apply(
          (current) => current.copyWith(
            avatar: avatar,
            avatarPhoto: photo,
            clearAvatarPhoto: photo == null,
          ),
        );
    await coordinator.setLocalAvatar(avatar, photo);
  }

  Future<void> _snapSelfie() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final bytes = await ref
          .read(avatarPhotoServiceProvider)
          .pick(camera: true);
      if (bytes == null || !mounted) return;
      final cropped = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute<Uint8List>(
          builder: (_) => AvatarCropScreen(imageBytes: bytes),
        ),
      );
      if (cropped == null || !mounted) return;
      await _apply(kPhotoAvatar, encodeAvatarPhoto(cropped));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _openStickers() async {
    final player = _local;
    if (player == null) return;
    var avatar = player.avatar;
    var photo = widget.state.avatarPhotos[player.id];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s20,
              0,
              AppSpacing.s20,
              AppSpacing.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  context.l10n.avatar,
                  style: gameDisplay(
                    size: 24,
                    color: WhoTookColors.of(context).ink,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                AvatarEditor(
                  avatar: avatar,
                  photoBase64: photo,
                  onChanged: (nextAvatar, nextPhoto) {
                    setSheetState(() {
                      avatar = nextAvatar;
                      photo = nextPhoto;
                    });
                    unawaited(_apply(nextAvatar, nextPhoto));
                  },
                ),
                const SizedBox(height: AppSpacing.s16),
                GameButton(
                  label: context.l10n.done,
                  onPressed: () => Navigator.of(context).pop(),
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final player = _local;
    if (player == null) return const SizedBox.shrink();
    final photo = widget.state.avatarPhotos[player.id];
    return SurfaceCard(
      child: Row(
        children: <Widget>[
          PlayerAvatar(
            initial: player.name,
            avatar: player.avatar,
            photoBase64: photo,
            size: 54,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.selfieStickerTitle,
                  style: gameDisplay(size: 16, color: colors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.selfieStickerBody,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: colors.ink2,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    GameButton(
                      label: l10n.takeSelfie,
                      onPressed: _picking
                          ? null
                          : () => unawaited(_snapSelfie()),
                      icon: Icons.photo_camera_front_outlined,
                      small: true,
                    ),
                    TextButton(
                      onPressed: () => unawaited(_openStickers()),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        foregroundColor: colors.ink2,
                      ),
                      child: Text(l10n.avatarChoices),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
