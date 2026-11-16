import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import 'common.dart';

/// The self-host escape hatch for FOSS builds. It is a real form, not a link,
/// because a relay URL without credentials is rarely enough in the field.
class CustomTurnSection extends ConsumerStatefulWidget {
  const CustomTurnSection({super.key});

  @override
  ConsumerState<CustomTurnSection> createState() => _CustomTurnSectionState();
}

class _CustomTurnSectionState extends ConsumerState<CustomTurnSection> {
  final TextEditingController _url = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _credential = TextEditingController();
  late final AppSettingsController _settings;
  String? _status;
  bool _warning = false;

  @override
  void initState() {
    super.initState();
    _settings = ref.read(appSettingsProvider.notifier);
    unawaited(_load());
  }

  Future<void> _load() async {
    final settings = await ref.read(appSettingsProvider.future);
    if (!mounted) return;
    _url.text = settings.customTurnUrl ?? '';
    _username.text = settings.customTurnUsername ?? '';
    _credential.text = settings.customTurnCredential ?? '';
  }

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _credential.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final url = _url.text.trim();
    final username = url.isEmpty ? '' : _username.text.trim();
    final credential = url.isEmpty ? '' : _credential.text.trim();
    final lower = url.toLowerCase();
    if (url.isNotEmpty &&
        !lower.startsWith('turn:') &&
        !lower.startsWith('turns:')) {
      setState(() {
        _status = l10n.relayTurnSchemeError;
        _warning = true;
      });
      return;
    }
    if ((username.isEmpty) != (credential.isEmpty)) {
      setState(() {
        _status = l10n.turnCredentialPairError;
        _warning = true;
      });
      return;
    }
    await _settings.apply((current) {
      final cleared = current.copyWith(clearTurn: true);
      return cleared.copyWith(
        customTurnUrl: url.isEmpty ? null : url,
        customTurnUsername: username.isEmpty ? null : username,
        customTurnCredential: credential.isEmpty ? null : credential,
      );
    });
    if (!mounted) return;
    setState(() {
      _status = l10n.fossTurnSaved;
      _warning = false;
    });
  }

  Future<void> _reset() async {
    await _settings.apply((current) => current.copyWith(clearTurn: true));
    if (!mounted) return;
    final l10n = context.l10n;
    _url.clear();
    _username.clear();
    _credential.clear();
    setState(() {
      _status = l10n.relayDefault;
      _warning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.dns_outlined, size: 18, color: colors.accent),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  l10n.fossTurnTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            l10n.fossTurnBody,
            style: TextStyle(fontSize: 12, height: 1.4, color: colors.ink2),
          ),
          const SizedBox(height: AppSpacing.s16),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: l10n.customTurnUrl,
              helperText: l10n.customTurnHelper,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.rControl),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _username,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: l10n.turnUsername,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.rControl),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          TextField(
            controller: _credential,
            obscureText: true,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: l10n.turnCredential,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.rControl),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: <Widget>[
              Expanded(
                child: SecondaryButton(
                  label: l10n.resetToDefault,
                  onPressed: () => unawaited(_reset()),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: PrimaryButton(
                  label: l10n.saveRelay,
                  onPressed: () => unawaited(_save()),
                ),
              ),
            ],
          ),
          if (_status != null) ...<Widget>[
            const SizedBox(height: AppSpacing.s8),
            Text(
              _status!,
              style: TextStyle(
                fontSize: 12,
                color: _warning ? colors.negative : colors.positive,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
