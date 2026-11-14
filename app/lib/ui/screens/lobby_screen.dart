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
                        size: 132,
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
                      'Works from any camera app',
                      style: TextStyle(fontSize: 13, color: colors.ink2),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    SecondaryButton(
                      label: 'Share invite link',
                      icon: Icons.ios_share,
                      onPressed: () => _shareInvite(context, state),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      state.connectionMode == ConnectionMode.localLan
                          ? 'Same Wi-Fi'
                          : 'Online',
                      style: TextStyle(fontSize: 13, color: colors.ink2),
                    ),
                  ],
                ),
              ),
            if (isHost) ...<Widget>[
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SectionLabel('Game mode'),
                    _ModeGrid(
                      mode: state.config.mode,
                      onSelect: (mode) => unawaited(coordinator.setMode(mode)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SectionLabel('Rounds'),
                    Row(
                      children: <Widget>[
                        IconButton.outlined(
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 44,
                          ),
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
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 48,
                          ),
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
              const SizedBox(height: AppSpacing.s12),
            ] else ...<Widget>[
              SurfaceCard(child: _ModeSummary(mode: state.config.mode)),
              const SizedBox(height: AppSpacing.s12),
              NoticeBanner(
                message: 'Waiting for the host to start',
                icon: Icons.hourglass_empty,
              ),
            ],
            const SizedBox(height: AppSpacing.s8),
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
      builder: (_) => _InviteSheet(url: url),
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

class _ModeGrid extends StatelessWidget {
  const _ModeGrid({required this.mode, required this.onSelect});

  final GameMode mode;
  final ValueChanged<GameMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.s8,
      crossAxisSpacing: AppSpacing.s8,
      childAspectRatio: 2.15,
      children: <Widget>[
        for (final value in GameMode.values)
          _ModeTile(
            mode: value,
            selected: value == mode,
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              onSelect(value);
            },
          ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final GameMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final (label, blurb, icon) = _modeInfo(mode);
    return Semantics(
      selected: selected,
      button: true,
      label: '$label. $blurb',
      child: Material(
        color: selected ? colors.raised : colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rControl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.rControl),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.rControl),
              border: Border.all(
                color: selected ? colors.accent : colors.hairline,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: selected ? colors.accent : colors.ink2,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        blurb,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.2,
                          color: colors.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check, size: 15, color: colors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeSummary extends StatelessWidget {
  const _ModeSummary({required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final (label, blurb, icon) = _modeInfo(mode);
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: colors.accent),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(blurb, style: TextStyle(fontSize: 12, color: colors.ink2)),
            ],
          ),
        ),
        Text('Host picks', style: TextStyle(fontSize: 11, color: colors.ink3)),
      ],
    );
  }
}

(String, String, IconData) _modeInfo(GameMode mode) => switch (mode) {
  GameMode.classic => (
    'Classic',
    'Guess who took it.',
    Icons.photo_camera_outlined,
  ),
  GameMode.captionThis => (
    'Caption This',
    'Write the funniest caption.',
    Icons.chat_bubble_outline,
  ),
  GameMode.timeTraveler => (
    'Time Traveler',
    'Guess the year and month.',
    Icons.history,
  ),
  GameMode.mixedParty => ('Mixed Party', 'All three, shuffled.', Icons.shuffle),
};
