import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

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
              child: PrimaryButton(
                label: 'Choose photos',
                onPressed: () => unawaited(coordinator.startPrepare()),
              ),
            )
          : null,
      appBar: AppBar(
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Lobby'),
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s20,
            AppSpacing.s8,
            AppSpacing.s20,
            112,
          ),
          children: <Widget>[
            if (isHost && state.inviteUrl != null)
              SurfaceCard(
                child: Column(
                  children: <Widget>[
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
                    Text(
                      'Scan this to join',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'Everyone points their camera at the host screen',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: colors.ink2),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    SecondaryButton(
                      label: 'Share invite link',
                      icon: Icons.ios_share,
                      onPressed: () => _shareInvite(context, state),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    StatusRow(
                      label: state.connectionMode == ConnectionMode.localLan
                          ? 'Local Wi-Fi, no server'
                          : 'Online relay',
                      tone: StatusTone.positive,
                    ),
                  ],
                ),
              ),
            if (isHost) ...<Widget>[
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SectionLabel('Rounds'),
                    Row(
                      children: <Widget>[
                        IconButton.outlined(
                          tooltip: 'Fewer rounds',
                          onPressed: state.config.roundsK > 1
                              ? () => unawaited(
                                  coordinator.setRounds(
                                    state.config.roundsK - 1,
                                  ),
                                )
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${state.config.roundsK}',
                              style: tabularFigures(
                                TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 20,
                                  color: colors.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton.outlined(
                          tooltip: 'More rounds',
                          onPressed: state.config.roundsK < 40
                              ? () => unawaited(
                                  coordinator.setRounds(
                                    state.config.roundsK + 1,
                                  ),
                                )
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
            ] else
              NoticeBanner(
                message: 'Waiting for the host to start',
                icon: Icons.hourglass_empty,
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
                    _PlayerRow(player: player),
                  if (state.players.length == 1)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      child: EmptyState(
                        title: 'Waiting for the first friend',
                        body: 'The QR code above is the only thing they need. Nothing to install on the host side.',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
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
    );
  }

  Future<void> _shareInvite(BuildContext context, MatchUiState state) async {
    final url = state.inviteUrl;
    if (url == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Invite link',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: AppSpacing.s8),
            SelectableText(
              url,
              style: const TextStyle(fontSize: 12, fontFamily: 'JetBrainsMono'),
            ),
            const SizedBox(height: AppSpacing.s16),
            SecondaryButton(
              label: 'Close',
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player});

  final Player player;

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
        ],
      ),
    );
  }
}
