import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/links.dart';
import '../../core/media/photo_service.dart';
import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import 'demo_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const Duration _nameDebounceDelay = Duration(milliseconds: 300);

  final TextEditingController _name = TextEditingController();
  final TextEditingController _signalingUrl = TextEditingController();
  final TextEditingController _turnUrl = TextEditingController();
  final TextEditingController _turnUsername = TextEditingController();
  final TextEditingController _turnCredential = TextEditingController();
  late final AppSettingsController _settings;
  Timer? _nameDebounce;
  String? _pendingName;
  String? _relayStatus;
  bool _relayStatusWarning = false;
  List<AlbumSummary>? _albums;
  bool _albumError = false;
  int _demoTaps = 0;

  @override
  void initState() {
    super.initState();
    _settings = ref.read(appSettingsProvider.notifier);
    unawaited(_loadSettings());
    unawaited(_loadAlbums());
  }

  /// The provider is still loading on the first frame, so the fields are filled
  /// once the stored values arrive instead of showing an empty box.
  Future<void> _loadSettings() async {
    final settings = await ref.read(appSettingsProvider.future);
    if (!mounted) return;
    _name.text = settings.nickname;
    _signalingUrl.text = settings.customSignalingUrl ?? '';
    _turnUrl.text = settings.customTurnUrl ?? '';
    _turnUsername.text = settings.customTurnUsername ?? '';
    _turnCredential.text = settings.customTurnCredential ?? '';
  }

  Future<void> _saveName(String value) async {
    _nameDebounce?.cancel();
    _nameDebounce = null;
    _pendingName = null;
    final name = value.trim();
    if (name.isEmpty) return;
    await _settings.apply((current) => current.copyWith(nickname: name));
  }

  /// Typing saves on its own; the field never depends on the keyboard submit.
  void _onNameChanged(String value) {
    _pendingName = value;
    _nameDebounce?.cancel();
    _nameDebounce = Timer(
      _nameDebounceDelay,
      () => unawaited(_saveName(value)),
    );
  }

  @override
  void dispose() {
    _nameDebounce?.cancel();
    final pending = _pendingName;
    if (pending != null) {
      final name = pending.trim();
      if (name.isNotEmpty) {
        unawaited(
          _settings.apply((current) => current.copyWith(nickname: name)),
        );
      }
    }
    _name.dispose();
    _signalingUrl.dispose();
    _turnUrl.dispose();
    _turnUsername.dispose();
    _turnCredential.dispose();
    super.dispose();
  }

  void _onAboutTap() {
    _demoTaps += 1;
    if (_demoTaps < 7) return;
    _demoTaps = 0;
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const DemoScreen()));
  }

  Future<void> _loadAlbums({bool reset = false}) async {
    if (reset) {
      setState(() {
        _albumError = false;
        _albums = null;
      });
    }
    try {
      final albums = await ref.read(photoLibraryProvider).listAlbums();
      if (!mounted) return;
      setState(() => _albums = albums);
    } on Object {
      if (!mounted) return;
      setState(() => _albumError = true);
    }
  }

  /// Asks for photo access again before reloading, which is the only way a
  /// limited selection can be widened after onboarding.
  Future<void> _retryAlbums() async {
    await ref.read(photoLibraryProvider).requestPermission();
    await _loadAlbums(reset: true);
  }

  Future<void> _saveRelay() async {
    final signaling = _signalingUrl.text.trim();
    final turn = _turnUrl.text.trim();
    final hasSignalingScheme =
        signaling.startsWith('https://') ||
        signaling.startsWith('http://') ||
        signaling.startsWith('wss://') ||
        signaling.startsWith('ws://');
    if (!hasSignalingScheme) {
      setState(() {
        _relayStatus =
            'Signaling URL must start with https://, http://, wss:// or ws://';
        _relayStatusWarning = true;
      });
      return;
    }
    final lowerTurn = turn.toLowerCase();
    if (turn.isNotEmpty &&
        !lowerTurn.startsWith('turn:') &&
        !lowerTurn.startsWith('turns:')) {
      setState(() {
        _relayStatus = 'TURN URL must start with turn: or turns:';
        _relayStatusWarning = true;
      });
      return;
    }
    final username = _turnUsername.text.trim();
    final credential = _turnCredential.text.trim();
    await _settings.apply((current) {
      // Clearing first lets empty fields really mean "not set" instead of
      // keeping the previous value.
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
      _relayStatus = 'Relay saved';
      _relayStatusWarning = false;
    });
  }

  Future<void> _resetRelay() async {
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
      _relayStatus = 'Back to the default relay';
      _relayStatusWarning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final settings = ref.watch(appSettingsProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: colors.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s20),
          children: <Widget>[
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                helperText: 'Shown to other players',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.rControl),
                ),
              ),
              onChanged: _onNameChanged,
              onSubmitted: (value) => unawaited(_saveName(value)),
            ),
            const SizedBox(height: AppSpacing.s24),
            SectionLabel('Theme'),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  for (final preference in ThemePreference.values)
                    ListTile(
                      minTileHeight: 56,
                      title: Text(switch (preference) {
                        ThemePreference.system => 'Follow the device',
                        ThemePreference.light => 'Light',
                        ThemePreference.dark => 'Dark',
                      }, style: const TextStyle(fontSize: 14)),
                      trailing: Icon(
                        (settings?.themePreference ?? ThemePreference.system) ==
                                preference
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: colors.ink2,
                      ),
                      onTap: () => unawaited(
                        _settings.apply(
                          (current) =>
                              current.copyWith(themePreference: preference),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            SectionLabel(
              'Albums left out',
              trailing: Text(
                '${settings?.excludedAlbumIds.length ?? 0} excluded',
                style: tabularFigures(
                  TextStyle(fontSize: 12, color: colors.ink3),
                ),
              ),
            ),
            if (_albumError)
              SurfaceCard(
                child: EmptyState(
                  title: 'Album list unavailable',
                  body: 'Photo access was not granted. Allow it and try again.',
                  actionLabel: 'Retry',
                  onAction: () => unawaited(_retryAlbums()),
                ),
              )
            else if (_albums == null)
              SurfaceCard(
                child: Row(
                  children: <Widget>[
                    SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.ink3,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    const Text('Reading your albums'),
                  ],
                ),
              )
            else
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (final album in _albums!)
                      CheckboxListTile(
                        value:
                            settings?.excludedAlbumIds.contains(album.id) ??
                            false,
                        onChanged: (checked) {
                          unawaited(
                            _settings.apply((current) {
                              final excluded = Set<String>.of(
                                current.excludedAlbumIds,
                              );
                              if (checked ?? false) {
                                excluded.add(album.id);
                              } else {
                                excluded.remove(album.id);
                              }
                              return current.copyWith(
                                excludedAlbumIds: excluded,
                              );
                            }),
                          );
                        },
                        title: Text(
                          album.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${album.assetCount} photos',
                          style: TextStyle(fontSize: 12, color: colors.ink3),
                        ),
                        controlAffinity: ListTileControlAffinity.trailing,
                        dense: true,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.s24),
            const SectionLabel('Online relay'),
            Text(
              'Local play never uses a server. Online play uses a small relay for friends elsewhere.',
              style: TextStyle(fontSize: 13, color: colors.ink2, height: 1.45),
            ),
            const SizedBox(height: AppSpacing.s12),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  0,
                  AppSpacing.s16,
                  AppSpacing.s16,
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                title: const Text(
                  'Self-hosted relay',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Point the app at your own signaling and TURN server',
                  style: TextStyle(fontSize: 12, color: colors.ink3),
                ),
                children: <Widget>[
                  TextField(
                    controller: _signalingUrl,
                    keyboardType: TextInputType.url,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Signaling URL',
                      helperText: 'Default: https://signal.whotook.party',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.rControl),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  TextField(
                    controller: _turnUrl,
                    keyboardType: TextInputType.url,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Custom TURN URL',
                      helperText: 'Optional, e.g. turn:turn.example.org:3478',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.rControl),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  TextField(
                    controller: _turnUsername,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'TURN username',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.rControl),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  TextField(
                    controller: _turnCredential,
                    obscureText: true,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'TURN credential',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.rControl),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: SecondaryButton(
                          label: 'Reset to default',
                          onPressed: () => unawaited(_resetRelay()),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Save relay',
                          onPressed: () => unawaited(_saveRelay()),
                        ),
                      ),
                    ],
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
            const SizedBox(height: AppSpacing.s24),
            const SectionLabel('Help and legal'),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  ListTile(
                    minTileHeight: 56,
                    leading: const Icon(Icons.outlined_flag, size: 20),
                    title: const Text(
                      'Report content or a player',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Send the room code and what happened to $kSupportEmail',
                      style: TextStyle(fontSize: 12, color: colors.ink2),
                    ),
                    onTap: () => unawaited(
                      openExternal(
                        context,
                        'mailto:$kSupportEmail?subject=WhoTook%20report',
                      ),
                    ),
                  ),
                  Divider(height: 1, color: colors.hairline),
                  ListTile(
                    minTileHeight: 56,
                    leading: const Icon(Icons.mail_outline, size: 20),
                    title: const Text(
                      'Support',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      kSupportEmail,
                      style: TextStyle(fontSize: 12, color: colors.ink2),
                    ),
                    onTap: () => unawaited(openSupport(context)),
                  ),
                  Divider(height: 1, color: colors.hairline),
                  ListTile(
                    minTileHeight: 56,
                    leading: const Icon(Icons.gavel_outlined, size: 20),
                    title: const Text(
                      'Terms and community rules',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => unawaited(openExternal(context, kTermsUrl)),
                  ),
                  Divider(height: 1, color: colors.hairline),
                  ListTile(
                    minTileHeight: 56,
                    leading: const Icon(Icons.privacy_tip_outlined, size: 20),
                    title: const Text(
                      'Privacy',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => unawaited(openExternal(context, kPrivacyUrl)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            const SectionLabel('About'),
            Divider(color: colors.hairline, height: 1),
            const SizedBox(height: AppSpacing.s12),
            Text(
              'Open source under the AGPLv3. Photos stay on your phone.',
              style: TextStyle(fontSize: 13, color: colors.ink2, height: 1.45),
            ),
            const SizedBox(height: AppSpacing.s8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onAboutTap,
              child: Text(
                'WhoTook™ is a trademark of the project owner.',
                style: TextStyle(fontSize: 12, color: colors.ink3, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
