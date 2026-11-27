import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/party_pass/party_pass_controller.dart';
import '../../core/party_pass/room_theme.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import 'game_widgets.dart';
import 'party_pass_sheet.dart';
import 'room_theme_picker.dart';

/// Compact lobby identity for the paid layer: what theme is shared, whether
/// the soundboard is ready, how players are connected, and the one pass action.
class PartyPassLobbyBar extends ConsumerWidget {
  const PartyPassLobbyBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final state = ref.watch(matchStateProvider).value ?? const MatchUiState();
    final pass = ref.watch(partyPassProvider).value ?? const PartyPassState();
    final theme = RoomThemeId.fromWire(state.roomThemeId);
    final customTurn = ref.watch(appSettingsProvider).value?.customTurnUrl;
    final shadow = Theme.of(context).brightness == Brightness.dark
        ? Colors.black
        : colors.ink;
    final relayLabel = _relayLabel(
      l10n,
      state.connectionMode,
      hasCustomTurn: customTurn != null && customTurn.trim().isNotEmpty,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rCard),
        border: Border.all(color: colors.ink, width: 2.5),
        boxShadow: <BoxShadow>[
          BoxShadow(color: shadow, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: <Widget>[
              _StatusChip(
                icon: Icons.palette_outlined,
                label: l10n.lobbyThemeLabel,
                value: roomThemeLabel(l10n, theme),
                onTap: () => showRoomThemePicker(context),
              ),
              _StatusChip(
                icon: Icons.graphic_eq,
                label: l10n.lobbySoundboardLabel,
                value: pass.active
                    ? l10n.lobbySoundboardOn
                    : l10n.lobbySoundboardOff,
              ),
              _StatusChip(
                icon: Icons.public,
                label: l10n.lobbyRelayLabel,
                value: relayLabel,
                onTap: () => showPartyPassSheet(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          if (pass.loading)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s8),
              child: Text(
                l10n.partyPassLoading,
                style: TextStyle(fontSize: 12, color: colors.ink3),
              ),
            )
          else if (pass.active)
            InkWell(
              onTap: () => showPartyPassSheet(context),
              borderRadius: BorderRadius.circular(AppRadii.rControl),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s8,
                ),
                decoration: BoxDecoration(
                  color: GamePalette.gold,
                  borderRadius: BorderRadius.circular(AppRadii.rControl),
                  border: Border.all(color: GamePalette.onGold, width: 2.5),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.workspace_premium,
                      size: 18,
                      color: GamePalette.onGold,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        l10n.partyPassLobbyActive,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: GamePalette.onGold,
                        ),
                      ),
                    ),
                    if (pass.remainingMatchesToday > 0)
                      Text(
                        '${pass.remainingMatchesToday}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: GamePalette.onGold,
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            GameButton(
              label: pass.displayPrice.isEmpty
                  ? l10n.partyPassUnlockNoPrice
                  : l10n.partyPassLobbyButton(pass.displayPrice),
              icon: Icons.auto_awesome,
              variant: GameButtonVariant.gold,
              small: true,
              fullWidth: true,
              onPressed: () => showPartyPassSheet(context),
            ),
        ],
      ),
    );
  }

  String _relayLabel(
    AppLocalizations l10n,
    ConnectionMode? mode, {
    required bool hasCustomTurn,
  }) {
    if (hasCustomTurn) return l10n.relayStatusCustom;
    return switch (mode) {
      ConnectionMode.localLan => l10n.relayStatusLocal,
      ConnectionMode.webrtcP2p => l10n.relayStatusDirect,
      ConnectionMode.webrtcTurn => l10n.relayStatusRelay,
      ConnectionMode.offlineLoopback => l10n.relayStatusOffline,
      null => l10n.relayStatusOffline,
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(AppRadii.rSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: colors.ink2),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: colors.ink3)),
          Text(':', style: TextStyle(fontSize: 11, color: colors.ink3)),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.ink,
              ),
            ),
          ),
          if (onTap != null) ...<Widget>[
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 13, color: colors.ink3),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: '$label: $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.rSm),
        child: content,
      ),
    );
  }
}
