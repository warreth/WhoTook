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
                    AppSpacing.s8,
                    AppSpacing.s16,
                    AppSpacing.s8,
                  ),
                  child: Column(
                    children: <Widget>[
                      SectionLabel(
                        "Tonight's game",
                        trailing: Text(
                          isHost ? 'Locked in' : 'Chosen by host',
                          style: TextStyle(fontSize: 11, color: colors.ink3),
                        ),
                      ),
                      _SetupRow(
                        icon: Icons.casino_outlined,
                        label: 'Rounds',
                        value: '${state.config.roundsK}',
                      ),
                      Divider(height: 1, color: colors.hairline),
                      _SetupRow(
                        icon: Icons.timer_outlined,
                        label: 'Pace',
                        value:
                            '${_paceLabel(state.config.roundSeconds)} · ${state.config.roundSeconds}s',
                      ),
                      Divider(height: 1, color: colors.hairline),
                      _SetupRow(
                        icon: modeInfo(state.config.mode).icon,
                        label: 'Mode',
                        value: modeInfo(state.config.mode).label,
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

class _SetupRow extends StatelessWidget {
  const _SetupRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: colors.ink2),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: colors.ink2),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
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
          PlayerAvatar(initial: player.name, isHost: player.isHost, size: 28),
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
