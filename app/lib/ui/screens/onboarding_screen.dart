import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/media/photo_service.dart';
import '../../core/theme/whotook_theme.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

/// First run: name plus the album exclusions that keep private folders out of
/// every match. Nothing leaves the device.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final TextEditingController _name = TextEditingController();
  List<AlbumSummary> _albums = const <AlbumSummary>[];
  final Set<String> _excluded = <String>{};
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadAlbums() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final photos = ref.read(photoLibraryProvider);
    try {
      final permission = await photos.requestPermission();
      if (permission == PermissionState.denied) {
        setState(() {
          _error = 'Photo access is needed to pick match photos.';
          _loading = false;
        });
        return;
      }
      final albums = await photos.listAlbums();
      if (!mounted) return;
      setState(() => _albums = albums);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not read albums: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _finish() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Pick a name your friends will recognise.');
      return;
    }
    await ref.read(appSettingsProvider.notifier).apply(
      (current) => current.copyWith(
        nickname: name,
        excludedAlbumIds: _excluded,
        onboardingCompleted: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s24),
          children: <Widget>[
            Row(
              children: <Widget>[
                WhoTookMark(size: 32, color: colors.accent),
                const SizedBox(width: AppSpacing.s12),
                const Text(
                  'WhoTook',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s32),
            const Text(
              'Guess whose photo it is',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w500,
                height: 1.15,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Every round shows one photo from a friend. Tap the name you think it belongs to, fastest correct guess wins.',
              style: TextStyle(fontSize: 14, color: colors.ink2, height: 1.45),
            ),
            const SizedBox(height: AppSpacing.s24),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Your name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.rControl),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            SectionLabel(
              'Albums to leave out',
              trailing: Text(
                '${_excluded.length} excluded',
                style: tabularFigures(
                  TextStyle(fontSize: 12, color: colors.ink3),
                ),
              ),
            ),
            Text(
              'Screenshots, work folders and anything else private stay out of every match.',
              style: TextStyle(fontSize: 13, color: colors.ink2),
            ),
            const SizedBox(height: AppSpacing.s12),
            if (_albums.isEmpty)
              SurfaceCard(
                child: _loading
                    ? Row(
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
                      )
                    : EmptyState(
                        title: 'Album list not loaded yet',
                        body: 'Allow photo access to choose which folders can be used.',
                        actionLabel: 'Allow photo access',
                        onAction: _loadAlbums,
                      ),
              )
            else
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (final album in _albums)
                      CheckboxListTile(
                        value: _excluded.contains(album.id),
                        onChanged: (checked) {
                          setState(() {
                            if (checked ?? false) {
                              _excluded.add(album.id);
                            } else {
                              _excluded.remove(album.id);
                            }
                          });
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
            if (_error != null) ...<Widget>[
              NoticeBanner(
                message: _error!,
                tone: StatusTone.warning,
                icon: Icons.error_outline,
              ),
              const SizedBox(height: AppSpacing.s12),
            ],
            PrimaryButton(label: 'Start playing', onPressed: _finish),
            const SizedBox(height: AppSpacing.s12),
            Text(
              'Photos are compressed on this device and only shared with the players in your match.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.ink3),
            ),
          ],
        ),
      ),
    );
  }
}
