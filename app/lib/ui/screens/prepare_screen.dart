import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/photo_service.dart';
import '../../core/models/models.dart';
import '../../core/theme/game_skin.dart';
import '../../core/theme/whotook_theme.dart';
import '../../l10n/l10n.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/game_background.dart';
import '../widgets/game_widgets.dart';
import '../widgets/host_controls.dart';
import 'settings_screen.dart';

/// Contact sheet: every player approves their own photos and can reroll as
/// often as they like before tapping Ready.
class PrepareScreen extends ConsumerWidget {
  const PrepareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = WhoTookColors.of(context);
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final isHost = state.isHosting;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.s20,
          AppSpacing.s8,
          AppSpacing.s20,
          AppSpacing.s16,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: GameButton(
                label: state.config.mode == GameMode.makeItMeme
                    ? l10n.memeVaultReroll
                    : l10n.rerollAll,
                icon: Icons.refresh,
                variant: GameButtonVariant.secondary,
                onPressed: () => unawaited(
                  isHost
                      ? coordinator.rerollCandidates()
                      : coordinator.clientRerollAll(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: GameButton(
                label: state.localReady
                    ? (state.isHosting
                          ? l10n.waitingForPlayersButton
                          : l10n.ready)
                    : state.config.mode == GameMode.makeItMeme
                    ? l10n.memeVaultReady
                    : l10n.ready,
                onPressed: state.localReady || state.candidates.isEmpty
                    ? null
                    : () => unawaited(
                        isHost
                            ? coordinator.markLocalReady()
                            : coordinator.clientMarkReady(),
                      ),
              ),
            ),
          ],
        ),
      ),
      body: GameBackdrop(
        mode: state.config.mode,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s20,
                  AppSpacing.s16,
                  AppSpacing.s20,
                  AppSpacing.s24,
                ),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          state.config.mode == GameMode.makeItMeme
                              ? l10n.memeVaultTitle
                              : l10n.checkYourPhotos,
                          style: gameDisplay(size: 28, color: colors.ink),
                        ),
                      ),
                      const HostControlsButton(),
                      FrameCounter(
                        current: state.candidates.length,
                        total: state.photosNeeded,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    state.config.mode == GameMode.makeItMeme
                        ? l10n.memeVaultBody
                        : state.photosNeeded > 0 &&
                              state.candidates.length >= state.photosNeeded
                        ? l10n.photosAllHere(state.candidates.length)
                        : state.photosNeeded > 0 && state.candidates.isNotEmpty
                        ? l10n.photosPartial(
                            state.candidates.length,
                            state.photosNeeded,
                          )
                        : l10n.photosReading,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.ink2,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  if (state.candidates.isNotEmpty &&
                      state.photosNeeded > 0 &&
                      state.candidates.length < state.photosNeeded) ...<Widget>[
                    NoticeBanner(
                      message: l10n.photosTooFew(state.candidates.length),
                      tone: StatusTone.warning,
                      icon: Icons.photo_library_outlined,
                    ),
                    const SizedBox(height: AppSpacing.s12),
                  ],
                  if (state.candidates.isEmpty)
                    SurfaceCard(
                      child: EmptyState(
                        title: state.errorMessage == null
                            ? l10n.readingAlbums
                            : l10n.noUsablePhotos,
                        body: state.errorMessage ?? l10n.noUsablePhotosBody,
                        actionLabel: l10n.photoSettings,
                        onAction: () => unawaited(
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = _photoColumns(
                          constraints.maxWidth,
                          state.candidates.length,
                        );
                        final tileWidth =
                            (constraints.maxWidth -
                                AppSpacing.s12 * (columns - 1)) /
                            columns;
                        return Wrap(
                          spacing: AppSpacing.s12,
                          runSpacing: AppSpacing.s12,
                          children: <Widget>[
                            for (
                              var index = 0;
                              index < state.candidates.length;
                              index++
                            )
                              SizedBox(
                                width: tileWidth,
                                height: tileWidth,
                                child: _PhotoTile(
                                  candidate: state.candidates[index],
                                  index: index,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: AppSpacing.s16),
                  if (state.config.mode != GameMode.makeItMeme &&
                      state.plantUnlocked &&
                      state.plantEligible &&
                      !state.plantUsed)
                    _PlantTile(
                      onTap: () => unawaited(
                        _plant(context, coordinator, state, isHost),
                      ),
                    ),
                  if (state.plantUsed) ...<Widget>[
                    const SizedBox(height: AppSpacing.s8),
                    StatusRow(
                      label: l10n.secretPhotoPlanted,
                      tone: StatusTone.positive,
                    ),
                  ],
                  if (state.config.mode == GameMode.makeItMeme) ...<Widget>[
                    const SizedBox(height: AppSpacing.s12),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colors.hairline,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.rControl),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.shield_outlined,
                            size: 16,
                            color: colors.ink3,
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              l10n.memeVaultOnly,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.ink2,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (state.errorMessage != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.s12),
                    NoticeBanner(
                      message: state.errorMessage!,
                      tone: StatusTone.warning,
                      icon: Icons.error_outline,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _plant(
    BuildContext context,
    MatchCoordinator coordinator,
    MatchUiState state,
    bool isHost,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PlantPickerSheet(
        candidates: state.candidates,
        coordinator: coordinator,
        isHost: isHost,
        localPlayerId: state.localPlayerId,
      ),
    );
  }
}

int _photoColumns(double width, int count) {
  if (count <= 4) return 2;
  if (count <= 9) return 3;
  if (width < 330) return 3;
  return 4;
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.candidate, required this.index});

  final PhotoCandidate candidate;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rCard),
        border: Border.all(color: colors.ink, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.ink,
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.rSm),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _PhotoBytes(bytes: candidate.bytes),
            Positioned(
              left: AppSpacing.s8,
              top: AppSpacing.s8,
              child: NumberTag(label: (index + 1).toString().padLeft(2, '0')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantTile extends StatelessWidget {
  const _PlantTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(AppRadii.rCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.rCard),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.rCard),
            border: Border.all(color: colors.hairline),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.raised,
                  borderRadius: BorderRadius.circular(AppRadii.rSm),
                ),
                child: Icon(
                  Icons.local_florist_outlined,
                  size: 18,
                  color: colors.ink2,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.plantSecretPhoto,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.plantSecretPhotoBody,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: colors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders compressed bytes, with a calm placeholder when a photo is still in
/// flight or the platform image decoder is unavailable.
class _PhotoBytes extends StatelessWidget {
  const _PhotoBytes({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final data = bytes;
    if (data == null || data.isEmpty) {
      return Container(
        color: colors.raised,
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined, size: 20, color: colors.ink3),
      );
    }
    return Image.memory(
      data,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) => Container(
        color: colors.raised,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 20,
          color: colors.ink3,
        ),
      ),
    );
  }
}

/// Full album browser for the planted frame, with the approved candidates as a
/// fallback when albums cannot be read. Picking a photo plants it and closes
/// the sheet in one step.
class _PlantPickerSheet extends ConsumerStatefulWidget {
  const _PlantPickerSheet({
    required this.candidates,
    required this.coordinator,
    required this.isHost,
    required this.localPlayerId,
  });

  final List<PhotoCandidate> candidates;
  final MatchCoordinator coordinator;
  final bool isHost;
  final String? localPlayerId;

  @override
  ConsumerState<_PlantPickerSheet> createState() => _PlantPickerSheetState();
}

class _PlantPickerSheetState extends ConsumerState<_PlantPickerSheet> {
  List<AlbumSummary>? _albums;
  AlbumSummary? _album;
  List<AlbumPhotoThumb>? _thumbs;
  bool _loading = true;
  bool _thumbsLoading = false;
  String? _error;
  String? _pickingId;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAlbums());
  }

  Future<void> _loadAlbums({bool reset = false}) async {
    final l10n = context.l10n;
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _albums = null;
        _album = null;
        _thumbs = null;
      });
    }
    try {
      final albums = await ref.read(photoLibraryProvider).listAlbums();
      if (!mounted) return;
      setState(() {
        _albums = albums;
        _loading = false;
      });
      if (albums.isNotEmpty) {
        await _selectAlbum(albums.first);
      }
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = l10n.couldNotReadAlbums;
      });
    }
  }

  Future<void> _selectAlbum(AlbumSummary album) async {
    final l10n = context.l10n;
    setState(() {
      _album = album;
      _thumbs = null;
      _thumbsLoading = true;
      _error = null;
    });
    try {
      final thumbs = await ref
          .read(photoLibraryProvider)
          .listAlbumPhotos(album.id);
      if (!mounted || _album?.id != album.id) return;
      setState(() {
        _thumbs = thumbs;
        _thumbsLoading = false;
      });
    } on Object {
      if (!mounted || _album?.id != album.id) return;
      setState(() {
        _thumbs = const <AlbumPhotoThumb>[];
        _thumbsLoading = false;
        _error = l10n.couldNotReadAlbum;
      });
    }
  }

  Future<void> _pickThumb(AlbumPhotoThumb thumb) async {
    if (_pickingId != null) return;
    final l10n = context.l10n;
    setState(() {
      _pickingId = thumb.assetId;
      _error = null;
    });
    try {
      final picked = await ref
          .read(photoLibraryProvider)
          .loadPhotoById(thumb.assetId);
      if (!mounted) return;
      if (picked == null) {
        setState(() {
          _pickingId = null;
          _error = l10n.couldNotReadPhoto;
        });
        return;
      }
      await _plant(picked);
    } on Object {
      if (!mounted) return;
      setState(() {
        _pickingId = null;
        _error = l10n.couldNotReadPhoto;
      });
    }
  }

  Future<void> _pickCandidate(PhotoCandidate candidate) async {
    final l10n = context.l10n;
    final bytes = candidate.bytes;
    if (bytes == null || bytes.isEmpty || _pickingId != null) return;
    setState(() {
      _pickingId = candidate.localAssetId;
      _error = null;
    });
    try {
      await _plant(
        PickedPhoto(
          assetId: candidate.localAssetId,
          bytes: bytes,
          capturedAt: candidate.hasCaptureDate
              ? DateTime(candidate.capturedYear!, candidate.capturedMonth!, 1)
              : null,
        ),
      );
    } on Object {
      if (!mounted) return;
      setState(() {
        _pickingId = null;
        _error = l10n.couldNotSharePhoto;
      });
    }
  }

  Future<void> _plant(PickedPhoto picked) async {
    if (widget.isHost) {
      await widget.coordinator.plantSecretPhoto(
        picked.assetId,
        picked.bytes,
        capturedYear: picked.capturedAt?.year,
        capturedMonth: picked.capturedAt?.month,
      );
    } else {
      await widget.coordinator.clientPlantPickedPhoto(
        PhotoCandidate(
          photoId: 'plant-${DateTime.now().microsecondsSinceEpoch}',
          localAssetId: picked.assetId,
          ownerId: widget.localPlayerId ?? 'client',
          bytes: picked.bytes,
          isPlanted: true,
          capturedYear: picked.capturedAt?.year,
          capturedMonth: picked.capturedAt?.month,
        ),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    final albums = _albums;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s20,
            0,
            AppSpacing.s20,
            AppSpacing.s20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.pickPhotoToPlant,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                l10n.pickPhotoToPlantBody,
                style: TextStyle(fontSize: 13, color: colors.ink2, height: 1.4),
              ),
              if (albums != null && albums.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.s16),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: albums.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: AppSpacing.s8),
                    itemBuilder: (context, index) {
                      final album = albums[index];
                      return _AlbumChip(
                        album: album,
                        selected: album.id == _album?.id,
                        onTap: () => unawaited(_selectAlbum(album)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
              ],
              if (_error != null) ...<Widget>[
                Text(
                  _error!,
                  style: TextStyle(fontSize: 12, color: colors.negative),
                ),
                const SizedBox(height: AppSpacing.s8),
              ],
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    if (_loading) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
      );
    }
    final albums = _albums;
    if (albums == null) {
      return SingleChildScrollView(
        child: SurfaceCard(
          child: EmptyState(
            title: l10n.albumsUnavailable,
            body: l10n.albumsUnavailableBody,
            actionLabel: l10n.retry,
            onAction: () => unawaited(_loadAlbums(reset: true)),
          ),
        ),
      );
    }
    if (albums.isEmpty) return _fallback(context);
    if (_thumbsLoading) {
      return Center(
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: colors.ink3),
        ),
      );
    }
    final thumbs = _thumbs;
    if (thumbs == null || thumbs.isEmpty) return _fallback(context);
    return GridView.builder(
      itemCount: thumbs.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.s4,
        crossAxisSpacing: AppSpacing.s4,
      ),
      itemBuilder: (context, index) {
        final thumb = thumbs[index];
        final picking = _pickingId == thumb.assetId;
        return InkWell(
          onTap: _pickingId == null ? () => unawaited(_pickThumb(thumb)) : null,
          borderRadius: BorderRadius.circular(AppRadii.rSm),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.rSm),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.memory(
                  thumb.thumbnailBytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stack) => Container(
                    color: colors.raised,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 18,
                      color: colors.ink3,
                    ),
                  ),
                ),
                if (picking)
                  Container(
                    color: colors.ink.withValues(alpha: 0.3),
                    alignment: Alignment.center,
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.bg,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _fallback(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    if (widget.candidates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: EmptyState(
            title: l10n.noPhotosToPlant,
            body: l10n.noPhotosToPlantBody,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.fromApprovedPhotos,
          style: TextStyle(fontSize: 12, color: colors.ink2),
        ),
        const SizedBox(height: AppSpacing.s8),
        Expanded(
          child: GridView.builder(
            itemCount: widget.candidates.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.s4,
              crossAxisSpacing: AppSpacing.s4,
            ),
            itemBuilder: (context, index) {
              final candidate = widget.candidates[index];
              final picking = _pickingId == candidate.localAssetId;
              return InkWell(
                onTap: _pickingId == null
                    ? () => unawaited(_pickCandidate(candidate))
                    : null,
                borderRadius: BorderRadius.circular(AppRadii.rSm),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.rSm),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _PhotoBytes(bytes: candidate.bytes),
                      Positioned(
                        left: AppSpacing.s8,
                        top: AppSpacing.s8,
                        child: NumberTag(
                          label: (index + 1).toString().padLeft(2, '0'),
                        ),
                      ),
                      if (picking)
                        Container(
                          color: colors.ink.withValues(alpha: 0.3),
                          alignment: Alignment.center,
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.bg,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AlbumChip extends StatelessWidget {
  const _AlbumChip({
    required this.album,
    required this.selected,
    required this.onTap,
  });

  final AlbumSummary album;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Material(
      color: selected ? colors.ink : colors.card,
      borderRadius: BorderRadius.circular(AppRadii.rSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.rSm),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.rSm),
            border: Border.all(color: colors.hairline),
          ),
          child: Text(
            '${album.name} ${album.assetCount}',
            style: TextStyle(
              fontSize: 12,
              color: selected ? colors.bg : colors.ink2,
            ),
          ),
        ),
      ),
    );
  }
}
