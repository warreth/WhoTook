import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/party_pass/party_pass_controller.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import 'game_widgets.dart';
import 'party_pass_sheet.dart';
import 'report_issue_button.dart';

/// Explains a blocked network in plain language with two clear choices:
/// join via the same Wi-Fi/hotspot for free, or optionally unlock online play.
class FirewallPromptOverlay extends ConsumerWidget {
  const FirewallPromptOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    if (!state.firewallPrompt) return const SizedBox.shrink();
    final colors = WhoTookColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final relayAttempted = state.firewallRelayAttempted;
    final pass = ref.watch(partyPassProvider).value;
    final relayCode = state.firewallRelayErrorCode ?? pass?.relayErrorCode;
    final quotaReached = relayCode == 'fair_use_limit_reached';
    final rateLimited = relayCode == 'rate_limited';
    final invalidReceipt =
        relayCode == 'invalid_receipt' || relayCode == 'product_mismatch';

    final title = !relayAttempted
        ? l10n.firewallTitle
        : quotaReached
        ? l10n.firewallQuotaTitle
        : rateLimited
        ? l10n.firewallBusyTitle
        : invalidReceipt
        ? l10n.firewallVerificationTitle
        : l10n.firewallRelayDownTitle;
    final subtitle = !relayAttempted
        ? l10n.firewallBody
        : quotaReached
        ? l10n.firewallQuotaBody
        : rateLimited
        ? l10n.firewallBusyBody
        : invalidReceipt
        ? l10n.firewallVerificationBody
        : l10n.firewallRelayDownBody;

    final retryAt = pass?.relayRetryAtUtc;
    final resetTime = (quotaReached || rateLimited) && retryAt != null
        ? MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(retryAt.toLocal()),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          )
        : null;

    void dismiss() => coordinator.dismissFirewallPrompt();

    return Positioned.fill(
      child: Stack(
        children: <Widget>[
          ModalBarrier(
            color: colors.ink.withValues(alpha: 0.58),
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
                          color: dark ? Colors.black : colors.ink,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: relayAttempted
                                    ? colors.negative
                                    : GamePalette.gold,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.rControl,
                                ),
                                border: Border.all(color: colors.ink, width: 2),
                              ),
                              child: Icon(
                                quotaReached
                                    ? Icons.timer_off_outlined
                                    : rateLimited
                                    ? Icons.hourglass_empty
                                    : invalidReceipt
                                    ? Icons.verified_user_outlined
                                    : relayAttempted
                                    ? Icons.cloud_off
                                    : Icons.wifi_off_rounded,
                                size: 22,
                                color: relayAttempted
                                    ? Colors.white
                                    : GamePalette.onGold,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontFamily: 'Fredoka',
                                      fontSize: 21,
                                      height: 1.12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                      color: colors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.4,
                                      color: colors.ink2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (!relayAttempted) ...<Widget>[
                          const SizedBox(height: AppSpacing.s16),
                          _OptionCard(
                            icon: Icons.wifi,
                            iconColor: dark
                                ? const Color(0xFF7AD7C7)
                                : GamePalette.teal,
                            iconBackground: GamePalette.teal.withValues(
                              alpha: dark ? 0.28 : 0.14,
                            ),
                            badgeLabel: l10n.firewallFreeBadge,
                            badgeBackground: GamePalette.teal,
                            badgeForeground: Colors.white,
                            title: l10n.firewallWifiCardTitle,
                            body: l10n.firewallWifiCardBody,
                            surfaceColor: colors.raised,
                            action: GameButton(
                              label: l10n.firewallWifiAction,
                              icon: Icons.refresh,
                              variant: GameButtonVariant.primary,
                              small: true,
                              fullWidth: true,
                              onPressed: () => coordinator.retryPendingJoin(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          _OptionCard(
                            icon: Icons.public,
                            iconColor: dark
                                ? GamePalette.gold
                                : GamePalette.goldInk,
                            iconBackground: GamePalette.gold.withValues(
                              alpha: dark ? 0.24 : 0.25,
                            ),
                            badgeLabel: l10n.firewallOptionalBadge,
                            badgeBackground: GamePalette.gold,
                            badgeForeground: GamePalette.onGold,
                            title: l10n.firewallPassCardTitle,
                            body: l10n.firewallPassCardBody,
                            surfaceColor: Color.alphaBlend(
                              GamePalette.gold.withValues(
                                alpha: dark ? 0.10 : 0.14,
                              ),
                              colors.raised,
                            ),
                            action: GameButton(
                              label: l10n.firewallUnlockAction,
                              icon: Icons.workspace_premium,
                              variant: GameButtonVariant.gold,
                              small: true,
                              fullWidth: true,
                              onPressed: () {
                                dismiss();
                                showPartyPassSheet(context);
                              },
                            ),
                          ),
                        ] else ...<Widget>[
                          if (resetTime != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.s12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s12,
                                vertical: AppSpacing.s8,
                              ),
                              decoration: BoxDecoration(
                                color: colors.raised,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.rControl,
                                ),
                                border: Border.all(color: colors.hairline),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.schedule,
                                    size: 16,
                                    color: colors.ink2,
                                  ),
                                  const SizedBox(width: AppSpacing.s8),
                                  Expanded(
                                    child: Text(
                                      quotaReached
                                          ? l10n.firewallQuotaReset(resetTime)
                                          : l10n.firewallBusyReset(resetTime),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: colors.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.s16),
                          GameButton(
                            label: invalidReceipt
                                ? l10n.partyPassRestore
                                : rateLimited || quotaReached
                                ? l10n.firewallRetryNow
                                : l10n.firewallRetryAction,
                            icon: invalidReceipt
                                ? Icons.restore
                                : Icons.refresh,
                            variant: GameButtonVariant.primary,
                            fullWidth: true,
                            onPressed: invalidReceipt
                                ? () {
                                    dismiss();
                                    showPartyPassSheet(context);
                                  }
                                : () => coordinator.retryPendingJoin(),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          GameButton(
                            label: l10n.firewallUseWifiAction,
                            icon: Icons.wifi,
                            variant: GameButtonVariant.secondary,
                            fullWidth: true,
                            onPressed: dismiss,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.s8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.s8,
                          children: <Widget>[
                            TextButton(
                              onPressed: dismiss,
                              child: Text(l10n.close),
                            ),
                            const ReportIssueButton(
                              screenLabel: 'Connection prompt',
                            ),
                          ],
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

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.badgeLabel,
    required this.badgeBackground,
    required this.badgeForeground,
    required this.title,
    required this.body,
    required this.surfaceColor,
    required this.action,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String badgeLabel;
  final Color badgeBackground;
  final Color badgeForeground;
  final String title;
  final String body;
  final Color surfaceColor;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.rCard),
        border: Border.all(color: colors.hairline, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(AppRadii.rSm),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: badgeForeground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              height: 1.38,
              color: colors.ink2,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          action,
        ],
      ),
    );
  }
}
