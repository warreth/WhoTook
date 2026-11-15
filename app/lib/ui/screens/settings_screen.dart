import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/avatars.dart';
import '../../core/constants.dart';
import '../../core/links.dart';
import '../../core/media/photo_service.dart';
import '../../core/models/models.dart';
import '../../core/storage/settings_repository.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../widgets/avatar_editor.dart';
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
    final settings = ref.watch(appSettingsProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
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
                labelText: l10n.nameLabel,
                helperText: l10n.nameHelper,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.rControl),
                ),
              ),
              onChanged: _onNameChanged,
              onSubmitted: (value) => unawaited(_saveName(value)),
            ),
            const SizedBox(height: AppSpacing.s24),
            SectionLabel(l10n.avatar),
            AvatarEditor(
              avatar: normalizeAvatar(settings?.avatar),
              photoBase64: settings?.avatarPhoto,
              onChanged: (avatar, photo) => unawaited(
                _settings.apply(
                  (current) => current.copyWith(
                    avatar: avatar,
                    avatarPhoto: photo,
                    clearAvatarPhoto: photo == null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            SectionLabel(l10n.theme),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  for (final preference in ThemePreference.values)
                    ListTile(
                      minTileHeight: 56,
                      title: Text(switch (preference) {
                        ThemePreference.system => l10n.themeSystem,
                        ThemePreference.light => l10n.themeLight,
                        ThemePreference.dark => l10n.themeDark,
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
            SectionLabel(l10n.language),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  for (final language in AppLanguage.values)
                    ListTile(
                      minTileHeight: 56,
                      title: Text(switch (language) {
                        AppLanguage.system => l10n.languageSystem,
                        AppLanguage.english => l10n.languageEnglish,
                        AppLanguage.dutch => l10n.languageDutch,
                      }, style: const TextStyle(fontSize: 14)),
                      trailing: Icon(
                        (settings?.language ?? AppLanguage.system) == language
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: colors.ink2,
                      ),
                      onTap: () => unawaited(
                        _settings.apply(
                          (current) => current.copyWith(language: language),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            SectionLabel(
              l10n.privateAlbums,
              trailing: Text(
                l10n.excludedCount(settings?.excludedAlbumIds.length ?? 0),
                style: tabularFigures(
                  TextStyle(fontSize: 12, color: colors.ink3),
                ),
              ),
            ),
            Text(
              l10n.privateAlbumsBody,
              style: TextStyle(fontSize: 13, color: colors.ink2, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.s12),
            if (_albumError)
              SurfaceCard(
                child: EmptyState(
                  title: l10n.albumListUnavailable,
                  body: l10n.albumListUnavailableBody,
                  actionLabel: l10n.retry,
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
                    Text(l10n.readingAlbums),
                  ],
                ),
              )
            else if (_albums!.isEmpty)
              SurfaceCard(
                child: EmptyState(
                  title: l10n.noAlbums,
                  body: l10n.noAlbumsBody,
                  actionLabel: l10n.allowPhotoAccess,
                  onAction: () => unawaited(_retryAlbums()),
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
                          l10n.photosCount(album.assetCount),
                          style: TextStyle(fontSize: 12, color: colors.ink3),
                        ),
                        controlAffinity: ListTileControlAffinity.trailing,
                        dense: true,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.s24),
            SectionLabel(l10n.onlineRelay),
            Text(
              l10n.onlineRelayBody,
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
                title: Text(
                  l10n.selfHostedRelay,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  l10n.selfHostedRelayBody,
                  style: TextStyle(fontSize: 12, color: colors.ink3),
                ),
                children: <Widget>[
                  TextField(
                    controller: _signalingUrl,
                    keyboardType: TextInputType.url,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: l10n.signalingUrl,
                      helperText: l10n.signalingUrlHelper(kDefaultSignalingUrl),
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
                    controller: _turnUsername,
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
                    controller: _turnCredential,
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
                  const SizedBox(height: AppSpacing.s16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: SecondaryButton(
                          label: l10n.resetToDefault,
                          onPressed: () => unawaited(_resetRelay()),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: PrimaryButton(
                          label: l10n.saveRelay,
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
            SectionLabel(l10n.helpAndLegal),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  ListTile(
                    minTileHeight: 56,
                    leading: const Icon(Icons.outlined_flag, size: 20),
                    title: Text(
                      l10n.reportContent,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      l10n.reportBody(kSupportEmail),
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
                    title: Text(
                      l10n.support,
                      style: const TextStyle(
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
                    title: Text(
                      l10n.termsAndRules,
                      style: const TextStyle(
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
                    title: Text(
                      l10n.privacy,
                      style: const TextStyle(
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
            SectionLabel(l10n.about),
            Divider(color: colors.hairline, height: 1),
            const SizedBox(height: AppSpacing.s12),
            Text(
              l10n.openSource,
              style: TextStyle(fontSize: 13, color: colors.ink2, height: 1.45),
            ),
            const SizedBox(height: AppSpacing.s8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onAboutTap,
              child: Text(
                l10n.trademark,
                style: TextStyle(fontSize: 12, color: colors.ink3, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
