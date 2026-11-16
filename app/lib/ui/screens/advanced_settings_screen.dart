import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/settings_repository.dart';
import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/game_background.dart';

/// Relay and self-hosting controls live here so the everyday settings screen
/// stays about the player, not the network.
class AdvancedSettingsScreen extends ConsumerStatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  ConsumerState<AdvancedSettingsScreen> createState() =>
      _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState
    extends ConsumerState<AdvancedSettingsScreen> {
  final TextEditingController _signalingUrl = TextEditingController();
  final TextEditingController _turnUrl = TextEditingController();
  final TextEditingController _turnUsername = TextEditingController();
  final TextEditingController _turnCredential = TextEditingController();
  late final AppSettingsController _settings;
  String? _relayStatus;
  bool _relayStatusWarning = false;

  @override
  void initState() {
    super.initState();
    _settings = ref.read(appSettingsProvider.notifier);
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final settings = await ref.read(appSettingsProvider.future);
    if (!mounted) return;
    _signalingUrl.text = settings.customSignalingUrl ?? '';
    _turnUrl.text = settings.customTurnUrl ?? '';
    _turnUsername.text = settings.customTurnUsername ?? '';
    _turnCredential.text = settings.customTurnCredential ?? '';
  }

  @override
  void dispose() {
    _signalingUrl.dispose();
    _turnUrl.dispose();
    _turnUsername.dispose();
    _turnCredential.dispose();
    super.dispose();
  }

  Future<void> _saveRelay() async {
    final l10n = context.l10n;
    final signaling = _signalingUrl.text.trim();
    final turn = _turnUrl.text.trim();
    final hasSignalingScheme =
        signaling.startsWith('https://') ||
        signaling.startsWith('http://') ||
        signaling.startsWith('wss://') ||
        signaling.startsWith('ws://');
    if (!hasSignalingScheme) {
      setState(() {
        _relayStatus = l10n.relaySignalingSchemeError;
        _relayStatusWarning = true;
      });
      return;
    }
    final lowerTurn = turn.toLowerCase();
    if (turn.isNotEmpty &&
        !lowerTurn.startsWith('turn:') &&
        !lowerTurn.startsWith('turns:')) {
      setState(() {
        _relayStatus = l10n.relayTurnSchemeError;
        _relayStatusWarning = true;
      });
      return;
    }
    final username = _turnUsername.text.trim();
    final credential = _turnCredential.text.trim();
    await _settings.apply((current) {
      final cleared = current.copyWith(
        clearCustomSignalingUrl: true,
        clearTurn: true,
      );
      return cleared.copyWith(
        customSignalingUrl: signaling,
        customTurnUrl: turn.isEmpty ? null : turn,
        customTurnUsername: username.isEmpty ? null : username,
        customTurnCredential: credential.isEmpty ? null : credential,
      );
    });
    if (!mounted) return;
    setState(() {
      _relayStatus = l10n.relaySaved;
      _relayStatusWarning = false;
    });
  }

  Future<void> _resetRelay() async {
    final l10n = context.l10n;
    await _settings.apply(
      (current) =>
          current.copyWith(clearCustomSignalingUrl: true, clearTurn: true),
    );
    if (!mounted) return;
    setState(() {
      _signalingUrl.clear();
      _turnUrl.clear();
      _turnUsername.clear();
      _turnCredential.clear();
      _relayStatus = l10n.relayDefault;
      _relayStatusWarning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.advancedSettings),
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: GameBackdrop(
        mode: GameMode.classic,
        lobby: true,
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.s20),
                children: <Widget>[
                  SectionLabel(l10n.onlineRelay),
                  Text(
                    l10n.onlineRelayBody,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: colors.ink2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.selfHostedRelay,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.selfHostedRelayBody,
                          style: TextStyle(fontSize: 12, color: colors.ink3),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        TextField(
                          controller: _signalingUrl,
                          keyboardType: TextInputType.url,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: l10n.signalingUrl,
                            helperText: l10n.signalingUrlHelper(
                              kDefaultSignalingUrl,
                            ),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.rControl,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        TextField(
                          controller: _turnUrl,
                          keyboardType: TextInputType.url,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: l10n.customTurnUrl,
                            helperText: l10n.customTurnHelper,
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.rControl,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        TextField(
                          controller: _turnUsername,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: l10n.turnUsername,
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.rControl,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        TextField(
                          controller: _turnCredential,
                          obscureText: true,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: l10n.turnCredential,
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.rControl,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        SizedBox(
                          width: double.infinity,
                          child: SecondaryButton(
                            label: l10n.resetToDefault,
                            onPressed: () => unawaited(_resetRelay()),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(
                            label: l10n.saveRelay,
                            onPressed: () => unawaited(_saveRelay()),
                          ),
                        ),
                        if (_relayStatus != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            _relayStatus!,
                            style: TextStyle(
                              fontSize: 12,
                              color: _relayStatusWarning
                                  ? colors.negative
                                  : colors.positive,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
