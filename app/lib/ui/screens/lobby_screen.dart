import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/mode_picker.dart';

class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final isHost = state.isHosting;

    return Scaffold(
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
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: 'Start photo check',
                          icon: Icons.photo_camera_outlined,
                          onPressed: () =>
                              unawaited(coordinator.startPrepare()),
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
          isHost ? 'Your room' : 'Lobby',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Leave match',
            onPressed: () => unawaited(coordinator.leaveMatch()),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
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
                if (isHost && state.inviteUrl != null) ...<Widget>[
                  Text(
                    'Scan to join',
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.9,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'Point any camera at the code. No app download needed to join.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: colors.ink2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  SurfaceCard(
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
                                'ROOM ${state.roomId ?? ''}',
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
                                  ? 'Same Wi-Fi'
                                  : 'Online',
                              tone: StatusTone.positive,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.s12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadii.rSm),
                          ),
                          child: QrImageView(
                            data: state.inviteUrl!,
                            version: QrVersions.auto,
                            size: 160,
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
                          label: 'Share invite link',
                          icon: Icons.ios_share,
                          onPressed: () => _shareInvite(context, state),
                        ),
                      ],
                    ),
                  ),
                ] else ...<Widget>[
                  Text(
                    "You're in",
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.9,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'The host starts the photo check when everyone is here.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: colors.ink2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  const NoticeBanner(
                    message: 'Waiting for the host to start',
                    icon: Icons.hourglass_empty,
                  ),
                ],
                const SizedBox(height: AppSpacing.s16),
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
                              label: '${state.config.roundsK} rounds',
                            ),
                            _SetupChip(
                              icon: Icons.timer_outlined,
                              label:
                                  '${_paceLabel(state.config.roundSeconds)} · ${state.config.roundSeconds}s',
                            ),
                            _SetupChip(
                              icon: modeInfo(state.config.mode).icon,
                              label: modeInfo(state.config.mode).label,
                            ),
                          ],
                        ),
                      ),
                      if (isHost)
                        TextButton(
                          onPressed: () => unawaited(_openSetupEditor(context)),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s8,
                            ),
                            foregroundColor: colors.accent,
                          ),
                          child: const Text('Edit'),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.s8),
                          child: Text(
                            'Chosen by host',
                            style: TextStyle(fontSize: 11, color: colors.ink3),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
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
                                state.players.length == 1
                                    ? '1 player joined'
                                    : '${state.players.length} players joined',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              'Room ${state.roomId ?? ''}',
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
                            title: 'Waiting for the first friend',
                            body: 'The QR code above is the only thing they need.',
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
    );
  }

  Future<void> _openSetupEditor(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _LobbySetupSheet(),
    );
  }

  Future<void> _confirmKick(
    BuildContext context,
    MatchCoordinator coordinator,
    Player player,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${player.name}?'),
        content: const Text(
          'They leave this room. They can join again with the QR code.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: WhoTookColors.of(context).negative,
            ),
            child: const Text('Remove'),
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

String _paceLabel(int seconds) => switch (seconds) {
  6 => 'Fast',
  12 => 'Slow',
  _ => 'Normal',
};

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
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
          const Text(
            'Invite link',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: AppSpacing.s8),
          SelectableText(
            widget.url,
            style: const TextStyle(fontSize: 12, fontFamily: 'JetBrainsMono'),
          ),
          const SizedBox(height: AppSpacing.s16),
          PrimaryButton(
            label: _copied ? 'Copied' : 'Copy link',
            icon: _copied ? Icons.check : Icons.copy,
            onPressed: () => unawaited(_copy()),
          ),
          const SizedBox(height: AppSpacing.s12),
          SecondaryButton(
            label: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player, this.onKick});

  final Player player;
  final VoidCallback? onKick;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
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
            player.isHost ? 'Host' : (player.ready ? 'Ready' : 'Choosing'),
            style: TextStyle(
              fontSize: 12,
              color: player.ready || player.isHost ? colors.ink2 : colors.ink3,
            ),
          ),
          if (onKick != null)
            PopupMenuButton<String>(
              tooltip: 'Player options',
              icon: const Icon(Icons.more_horiz, size: 20),
              onSelected: (_) => onKick!(),
              itemBuilder: (context) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'remove',
                  child: Text('Remove from room'),
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
                "Tonight's game",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.6,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'Changes reach everyone in the room. You can edit again until the photo check starts.',
                style: TextStyle(fontSize: 13, height: 1.4, color: colors.ink2),
              ),
              const SizedBox(height: AppSpacing.s16),
              const SectionLabel('Mode'),
              ModePicker(
                mode: config.mode,
                onSelect: (mode) => unawaited(coordinator.setMode(mode)),
              ),
              const SizedBox(height: AppSpacing.s16),
              const SectionLabel('Rounds'),
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
              const SectionLabel('Pace'),
              Row(
                children: <Widget>[
                  for (final pace in GamePace.values)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: pace == GamePace.slow ? 0 : AppSpacing.s8,
                        ),
                        child: _SheetChoice(
                          label: pace.label,
                          detail: config.mode == GameMode.mixedParty
                              ? 'Mixed'
                              : '${pace.mainSeconds(config.mode)}s',
                          selected: config.pace == pace,
                          onTap: () => unawaited(coordinator.setPace(pace)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s24),
              PrimaryButton(
                label: 'Done',
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
