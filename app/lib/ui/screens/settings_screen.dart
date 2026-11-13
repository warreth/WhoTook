import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/photo_service.dart';
import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _name = TextEditingController();
  List<AlbumSummary>? _albums;
  bool _albumError = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider).value;
    _name.text = settings?.nickname ?? '';
    unawaited(_loadAlbums());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadAlbums() async {
    try {
      final albums = await ref.read(photoLibraryProvider).listAlbums();
      if (!mounted) return;
      setState(() => _albums = albums);
    } on Object {
      if (!mounted) return;
      setState(() => _albumError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final settings = ref.watch(appSettingsProvider).value;
    final controller = ref.read(appSettingsProvider.notifier);

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
            SectionLabel('Name'),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Shown to other players',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.rControl),
                ),
              ),
              onSubmitted: (value) => unawaited(
                controller.apply(
                  (current) => current.copyWith(nickname: value.trim()),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            SectionLabel('Theme'),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  for (final preference in ThemePreference.values)
                    ListTile(
                      dense: true,
                      title: Text(
                        switch (preference) {
                          ThemePreference.system => 'Follow the device',
                          ThemePreference.light => 'Light',
                          ThemePreference.dark => 'Dark',
                        },
                        style: const TextStyle(fontSize: 14),
                      ),
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
                        controller.apply(
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
                  onAction: _loadAlbums,
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
                            controller.apply((current) {
                              final excluded =
                                  Set<String>.of(current.excludedAlbumIds);
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
              'Local Wi-Fi and hotspots never touch a server. Online play uses a small relay, limited per network each day so it stays free.',
              style: TextStyle(fontSize: 13, color: colors.ink2, height: 1.45),
            ),
            const SizedBox(height: AppSpacing.s24),
            Text(
              'WhoTook is open source under the AGPLv3. Photos are processed on device and never stored on a server.',
              style: TextStyle(fontSize: 12, color: colors.ink3, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
