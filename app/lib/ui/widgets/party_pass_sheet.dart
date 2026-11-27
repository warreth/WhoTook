import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/links.dart';
import '../../core/party_pass/party_pass_controller.dart';
import '../../core/party_pass/purchase_service.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../screens/advanced_settings_screen.dart';
import 'common.dart';
import 'game_widgets.dart';
import 'party_pass_error.dart';

Future<void> showPartyPassSheet(
  BuildContext context, {
  bool verifyOnOpen = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PartyPassBottomSheet(verifyOnOpen: verifyOnOpen),
  );
}

/// The one purchase surface. It is deliberately readable without a store:
/// every perk, the price, restore, and the self-host escape hatch.
class PartyPassBottomSheet extends ConsumerStatefulWidget {
  const PartyPassBottomSheet({super.key, this.verifyOnOpen = true});

  final bool verifyOnOpen;

  @override
  ConsumerState<PartyPassBottomSheet> createState() =>
      _PartyPassBottomSheetState();
}

class _PartyPassBottomSheetState extends ConsumerState<PartyPassBottomSheet> {
  @override
  void initState() {
    super.initState();
    if (widget.verifyOnOpen) {
      final pass = ref.read(partyPassProvider).value;
      if (pass != null && pass.active) {
        unawaited(ref.read(partyPassProvider.notifier).verify());
      }
    }
  }

  Future<void> _unlock() async {
    await ref.read(partyPassProvider.notifier).unlock();
  }

  Future<void> _restore() async {
    await ref.read(partyPassProvider.notifier).restore();
  }

  Future<void> _enterLicense() async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final key = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.partyPassLicenseTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: l10n.partyPassLicenseHint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.partyPassLicenseApply),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || key == null || key.trim().isEmpty) return;
    await ref.read(partyPassProvider.notifier).redeem(key);
  }

  void _openCustomTurn() {
    Navigator.of(context).pop();
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AdvancedSettingsScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final pass = ref.watch(partyPassProvider).value ?? const PartyPassState();
    final busy = pass.purchasing;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.s12,
            0,
            AppSpacing.s12,
            AppSpacing.s12,
          ),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s20,
              AppSpacing.s20,
              AppSpacing.s20,
              AppSpacing.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: GamePalette.gold,
                        borderRadius: BorderRadius.circular(AppRadii.rControl),
                        border: Border.all(color: GamePalette.onGold, width: 2),
                      ),
                      child: const Icon(
                        Icons.workspace_premium,
                        color: GamePalette.onGold,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.partyPassTitle,
                            style: TextStyle(
                              fontSize: 24,
                              height: 1.05,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                              color: colors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pass.active
                                ? l10n.partyPassActiveBody
                                : l10n.partyPassSubtitle,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: colors.ink2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                if (pass.loading || !pass.billingReady)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                    child: Text(
                      l10n.partyPassLoading,
                      style: TextStyle(fontSize: 12, color: colors.ink3),
                    ),
                  ),
                if (pass.active)
                  _ActiveBadge(
                    l10n: l10n,
                    remaining: pass.remainingMatchesToday,
                    limit: pass.dailyLimit,
                    relayError: pass.relayErrorCode,
                  )
                else
                  Text(
                    pass.billingKind == PartyPassBillingKind.paddle
                        ? l10n.partyPassRestoreHintPaddle
                        : l10n.partyPassRestoreHint,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: colors.ink2,
                    ),
                  ),
                const SizedBox(height: AppSpacing.s16),
                _Perk(
                  icon: Icons.public,
                  title: l10n.partyPassPerkRelayTitle,
                  body: l10n.partyPassPerkRelayBody,
                ),
                const SizedBox(height: AppSpacing.s8),
                _Perk(
                  icon: Icons.graphic_eq,
                  title: l10n.partyPassPerkSoundboardTitle,
                  body: l10n.partyPassPerkSoundboardBody,
                ),
                const SizedBox(height: AppSpacing.s8),
                _Perk(
                  icon: Icons.palette_outlined,
                  title: l10n.partyPassPerkThemesTitle,
                  body: l10n.partyPassPerkThemesBody,
                ),
                if (!pass.active) ...<Widget>[
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    l10n.soundboardLocked,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: colors.ink3,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.s20),
                if (pass.errorCode != null) ...<Widget>[
                  NoticeBanner(
                    message: partyPassErrorLabel(l10n, pass.errorCode),
                    tone: StatusTone.warning,
                    icon: Icons.error_outline,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                ],
                if (pass.relayErrorCode != null && pass.active) ...<Widget>[
                  NoticeBanner(
                    message: partyPassErrorLabel(l10n, pass.relayErrorCode),
                    tone: StatusTone.warning,
                    icon: Icons.cloud_off,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                ],
                if (pass.active) ...<Widget>[
                  TextButton(
                    onPressed: busy ? null : () => unawaited(_restore()),
                    child: Text(l10n.partyPassRestore),
                  ),
                ] else if (pass.billingKind ==
                    PartyPassBillingKind.paddle) ...<Widget>[
                  if (pass.billingReady && pass.billingAvailable) ...<Widget>[
                    GameButton(
                      label: pass.displayPrice.isEmpty
                          ? l10n.partyPassUnlockNoPrice
                          : l10n.partyPassUnlockButton(pass.displayPrice),
                      icon: Icons.lock_open,
                      variant: GameButtonVariant.gold,
                      onPressed: busy ? null : () => unawaited(_unlock()),
                      fullWidth: true,
                    ),
                  ] else if (pass.billingReady) ...<Widget>[
                    Text(
                      l10n.partyPassPaddleUnavailable,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: colors.ink3,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s8),
                  TextButton(
                    onPressed: busy ? null : () => unawaited(_restore()),
                    child: Text(l10n.partyPassRestore),
                  ),
                  TextButton(
                    onPressed: busy ? null : () => unawaited(_enterLicense()),
                    child: Text(l10n.partyPassLicenseButton),
                  ),
                ] else if (pass.billingReady &&
                    pass.billingAvailable) ...<Widget>[
                  GameButton(
                    label: pass.displayPrice.isEmpty
                        ? l10n.partyPassUnlockNoPrice
                        : l10n.partyPassUnlockButton(pass.displayPrice),
                    icon: Icons.lock_open,
                    variant: GameButtonVariant.gold,
                    onPressed: busy ? null : () => unawaited(_unlock()),
                    fullWidth: true,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  TextButton(
                    onPressed: busy ? null : () => unawaited(_restore()),
                    child: Text(l10n.partyPassRestore),
                  ),
                ] else if (pass.billingReady) ...<Widget>[
                  Text(
                    l10n.partyPassStoreUnavailable,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: colors.ink3,
                    ),
                  ),
                  // Never send an iOS build to the website from the Party Pass
                  // sheet: that page sells the pass outside Apple. Apple and
                  // TestFlight builds must have no external purchase path.
                  if (kIsWeb ||
                      defaultTargetPlatform != TargetPlatform.iOS) ...[
                    const SizedBox(height: AppSpacing.s12),
                    GameButton(
                      label: l10n.partyPassStoreButton,
                      icon: Icons.open_in_new,
                      variant: GameButtonVariant.secondary,
                      onPressed: () =>
                          unawaited(openExternal(context, appStoreUrl())),
                      fullWidth: true,
                    ),
                  ],
                ],
                if (busy)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.ink3,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Flexible(
                          child: Text(
                            l10n.partyPassPurchasePending,
                            style: TextStyle(fontSize: 12, color: colors.ink3),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.s16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.s16,
                  children: <Widget>[
                    TextButton(
                      onPressed: () =>
                          unawaited(openExternal(context, kTermsUrl)),
                      child: Text(l10n.partyPassTerms),
                    ),
                    TextButton(
                      onPressed: () =>
                          unawaited(openExternal(context, kPrivacyUrl)),
                      child: Text(l10n.partyPassPrivacy),
                    ),
                    TextButton(
                      onPressed: _openCustomTurn,
                      child: Text(l10n.partyPassCustomTurn),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(AppRadii.rControl),
        border: Border.all(color: colors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(AppRadii.rSm),
              border: Border.all(color: colors.ink, width: 2),
            ),
            child: Icon(icon, size: 18, color: colors.accent),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: colors.ink2,
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

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({
    required this.l10n,
    required this.remaining,
    required this.limit,
    required this.relayError,
  });

  final AppLocalizations l10n;
  final int remaining;
  final int limit;
  final String? relayError;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final ratio = limit <= 0 ? 0.0 : (remaining / limit).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(AppRadii.rControl),
        border: Border.all(color: GamePalette.goldDeep, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.workspace_premium,
                size: 18,
                color: GamePalette.goldDeep,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  l10n.partyPassActiveBadge,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: GamePalette.goldDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: colors.card,
              valueColor: const AlwaysStoppedAnimation<Color>(
                GamePalette.goldDeep,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            relayError == null
                ? l10n.partyPassFairUse(remaining, limit)
                : l10n.partyPassRelayError,
            style: TextStyle(fontSize: 12, color: colors.ink2),
          ),
        ],
      ),
    );
  }
}
