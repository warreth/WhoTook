import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/build_flavor.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../screens/advanced_settings_screen.dart';
import 'game_widgets.dart';
import 'party_pass_sheet.dart';

/// Explains the strict 5G / carrier NAT case without blaming the player. The
/// free route is always first; the relay is the optional shortcut.
class FirewallPromptOverlay extends ConsumerWidget {
  const FirewallPromptOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    if (!state.firewallPrompt) return const SizedBox.shrink();
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final relayAttempted = state.firewallRelayAttempted;
    final title = relayAttempted
        ? l10n.firewallRelayDownTitle
        : l10n.firewallTitle;
    final body = relayAttempted
        ? l10n.firewallRelayDownBody
        : BuildFlavor.foss
        ? l10n.partyPassFossBody
        : l10n.firewallBody;

    void dismiss() => coordinator.dismissFirewallPrompt();

    return Positioned.fill(
      child: Stack(
        children: <Widget>[
          ModalBarrier(
            color: colors.ink.withValues(alpha: 0.55),
            dismissible: false,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.s20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.s20),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(AppRadii.rModal),
                      border: Border.all(color: colors.ink, width: 2.5),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black
                              : colors.ink,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: relayAttempted
                                    ? colors.negative
                                    : GamePalette.gold,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.rSm,
                                ),
                                border: Border.all(
                                  color: colors.ink,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                relayAttempted
                                    ? Icons.cloud_off
                                    : Icons.wifi_tethering_error,
                                size: 22,
                                color: relayAttempted
                                    ? colors.bg
                                    : GamePalette.onGold,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 20,
                                  height: 1.1,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                  color: colors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: colors.ink2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s20),
                        if (BuildFlavor.foss)
                          GameButton(
                            label: l10n.firewallFossAction,
                            icon: Icons.dns_outlined,
                            variant: GameButtonVariant.secondary,
                            fullWidth: true,
                            onPressed: () {
                              dismiss();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const AdvancedSettingsScreen(),
                                ),
                              );
                            },
                          )
                        else ...<Widget>[
                          GameButton(
                            label: l10n.firewallWifiAction,
                            icon: Icons.wifi,
                            variant: GameButtonVariant.secondary,
                            fullWidth: true,
                            onPressed: dismiss,
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          if (relayAttempted)
                            GameButton(
                              label: l10n.firewallRetryAction,
                              icon: Icons.refresh,
                              variant: GameButtonVariant.primary,
                              fullWidth: true,
                              onPressed: dismiss,
                            )
                          else
                            GameButton(
                              label: l10n.firewallUnlockAction,
                              icon: Icons.workspace_premium,
                              variant: GameButtonVariant.gold,
                              fullWidth: true,
                              onPressed: () {
                                dismiss();
                                showPartyPassSheet(context);
                              },
                            ),
                        ],
                        const SizedBox(height: AppSpacing.s8),
                        TextButton(
                          onPressed: dismiss,
                          child: Text(l10n.close),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
