import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/audio/game_audio_service.dart';
import '../../core/avatars.dart';
import '../../core/party_pass/party_pass_controller.dart';
import '../../core/constants.dart';
import '../../core/links.dart';
import '../../core/media/photo_service.dart';
import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../widgets/avatar_editor.dart';
import '../widgets/common.dart';
import '../widgets/game_background.dart';
import '../widgets/party_pass_sheet.dart';
import '../widgets/report_issue_button.dart';
import '../widgets/safety_controls.dart';
import 'advanced_settings_screen.dart';
import 'demo_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const Duration _nameDebounceDelay = Duration(milliseconds: 300);

  final TextEditingController _name = TextEditingController();
  late final AppSettingsController _settings;
  Timer? _nameDebounce;
  String? _pendingName;
  List<AlbumSummary>? _albums;
  bool _albumError = false;

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
    super.dispose();
  }

  void _openDemo() {
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
    final permission = await ref.read(photoLibraryProvider).requestPermission();
    if (!permission.hasAccess) {
      try {
        await PhotoManager.openSetting();
      } on Object {
        // Ignore on test hosts without photo_manager platform channels.
      }
      return;
    }
    await _loadAlbums(reset: true);
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
      body: GameBackdrop(
        mode: GameMode.classic,
        lobby: true,
        child: SafeArea(
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
              const SizedBox(height: AppSpacing.s12),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  minTileHeight: 60,
                  leading: const Icon(Icons.smart_toy_outlined, size: 20),
                  title: Text(
                    l10n.tryDemo,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    l10n.tryDemoBody,
                    style: TextStyle(fontSize: 12, color: colors.ink2),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: _openDemo,
                ),
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
                          (settings?.themePreference ??
                                      ThemePreference.system) ==
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
              SectionLabel(l10n.gameFeel),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      value: settings?.musicEnabled ?? true,
                      onChanged: (value) {
                        unawaited(
                          _settings.apply(
                            (current) => current.copyWith(musicEnabled: value),
                          ),
                        );
                        unawaited(
                          GameAudioService.instance.setMusicEnabled(value),
                        );
                      },
                      title: Text(
                        l10n.music,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        l10n.musicBody,
                        style: TextStyle(fontSize: 12, color: colors.ink2),
                      ),
                    ),
                    Divider(height: 1, color: colors.hairline),
                    SwitchListTile(
                      value: settings?.soundEnabled ?? true,
                      onChanged: (value) {
                        unawaited(
                          _settings.apply(
                            (current) => current.copyWith(soundEnabled: value),
                          ),
                        );
                        GameAudioService.instance.isSfxMuted = !value;
                        if (value) {
                          unawaited(GameAudioService.instance.tapUp());
                        }
                      },
                      title: Text(
                        l10n.soundEffects,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        l10n.soundEffectsBody,
                        style: TextStyle(fontSize: 12, color: colors.ink2),
                      ),
                    ),
                    Divider(height: 1, color: colors.hairline),
                    SwitchListTile(
                      value: settings?.hapticsEnabled ?? true,
                      onChanged: (value) {
                        unawaited(
                          _settings.apply(
                            (current) =>
                                current.copyWith(hapticsEnabled: value),
                          ),
                        );
                        if (value) unawaited(GameHaptics.instance.selection());
                      },
                      title: Text(
                        l10n.memeHaptics,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        l10n.memeHapticsBody,
                        style: TextStyle(fontSize: 12, color: colors.ink2),
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
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  minTileHeight: 64,
                  leading: const Icon(Icons.tune, size: 20),
                  title: Text(
                    l10n.advancedSettings,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    l10n.advancedSettingsBody,
                    style: TextStyle(fontSize: 12, color: colors.ink2),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => unawaited(
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AdvancedSettingsScreen(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              SectionLabel(l10n.settingsPartyPassTitle),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  minTileHeight: 64,
                  leading: Icon(
                    Icons.workspace_premium,
                    size: 20,
                    color: colors.accent,
                  ),
                  title: Text(
                    l10n.settingsPartyPassTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    ref.watch(partyPassProvider).value?.active ?? false
                        ? l10n.settingsPartyPassActive
                        : l10n.settingsPartyPassInactive,
                    style: TextStyle(fontSize: 12, color: colors.ink2),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => unawaited(showPartyPassSheet(context)),
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              SectionLabel(l10n.helpAndLegal),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    const ReportIssueButton(tile: true),
                    Divider(height: 1, color: colors.hairline),
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
                      onTap: () => unawaited(showReportBlockSheet(context)),
                    ),
                    Divider(height: 1, color: colors.hairline),
                    ListTile(
                      minTileHeight: 56,
                      leading: const Icon(Icons.block_outlined, size: 20),
                      title: Text(
                        l10n.blockedPlayersTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        l10n.blockedPlayersCount(
                          settings?.blockedPlayerNames.length ?? 0,
                        ),
                        style: TextStyle(fontSize: 12, color: colors.ink2),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => unawaited(showBlockedPlayersSheet(context)),
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
                      onTap: () =>
                          unawaited(openExternal(context, kPrivacyUrl)),
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
                style: TextStyle(
                  fontSize: 13,
                  color: colors.ink2,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                l10n.trademark,
                style: TextStyle(fontSize: 12, color: colors.ink3, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
