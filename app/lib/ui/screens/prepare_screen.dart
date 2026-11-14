import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/photo_service.dart';
import '../../core/models/models.dart';
import '../../core/theme/whotook_theme.dart';
import '../../state/match_coordinator.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';

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

    return Scaffold(
      body: SafeArea(
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
                    'Check your photos',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.4,
                      color: colors.ink,
                    ),
                  ),
                ),
                FrameCounter(
                  current: state.candidates.length,
                  total: state.photosNeeded,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Swap anything you would rather keep out.',
              style: TextStyle(fontSize: 13, color: colors.ink2, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.s16),
            if (state.candidates.isEmpty)
              SurfaceCard(
                child: EmptyState(
                  title: state.errorMessage == null
                      ? 'Reading your photos'
                      : 'No usable photos',
                  body: state.errorMessage ?? 'Picking frames from the albums you allowed. This stays on your device.',
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.candidates.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.s12,
                  crossAxisSpacing: AppSpacing.s12,
                  childAspectRatio: 0.84,
                ),
                itemBuilder: (context, index) {
                  final candidate = state.candidates[index];
                  return _CandidateTile(
                    candidate: candidate,
                    index: index,
                    onSwap: () => unawaited(
                      isHost
                          ? coordinator.swapCandidate(index)
                          : coordinator.clientSwapCandidate(index),
                    ),
                  );
                },
              ),
            const SizedBox(height: AppSpacing.s16),
            if (state.plantUnlocked && !state.plantUsed)
              _PlantTile(
                onTap: () =>
                    unawaited(_plant(context, coordinator, state, isHost)),
              ),
            if (state.plantUsed) ...<Widget>[
              const SizedBox(height: AppSpacing.s8),
              StatusRow(
                label: 'Secret photo planted',
                tone: StatusTone.positive,
              ),
            ],
            const SizedBox(height: AppSpacing.s16),
            Row(
              children: <Widget>[
                Expanded(
                  child: SecondaryButton(
                    label: 'Reroll all',
                    icon: Icons.refresh,
                    onPressed: () => unawaited(
                      isHost
                          ? coordinator.rerollCandidates()
                          : coordinator.clientRerollAll(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: PrimaryButton(
                    label: state.localReady
                        ? (state.isHosting ? 'Waiting for players' : 'Ready')
                        : 'Ready',
                    onPressed: state.localReady
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

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.candidate,
    required this.index,
    required this.onSwap,
  });

  final PhotoCandidate candidate;
  final int index;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadii.rCard),
        border: Border.all(color: colors.hairline),
      ),
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.rSm),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _PhotoBytes(bytes: candidate.bytes, fit: BoxFit.cover),
                  Positioned(
                    left: AppSpacing.s8,
                    top: AppSpacing.s8,
                    child: NumberTag(
                      label: (index + 1).toString().padLeft(2, '0'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onSwap,
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: const Text('Swap', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                foregroundColor: colors.ink2,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.rSm),
                ),
              ),
            ),
          ),
        ],
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Plant one secret photo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'One per match. It quietly replaces one of your approved photos.',
                      style: TextStyle(fontSize: 12),
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
  const _PhotoBytes({required this.bytes, this.fit = BoxFit.cover});

  final Uint8List? bytes;
  final BoxFit fit;

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
      fit: fit,
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
        _error = 'Could not read your albums.';
      });
    }
  }

  Future<void> _selectAlbum(AlbumSummary album) async {
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
        _error = 'Could not read this album.';
      });
    }
  }

  Future<void> _pickThumb(AlbumPhotoThumb thumb) async {
    if (_pickingId != null) return;
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
          _error = 'That photo could not be read. Try another.';
        });
        return;
      }
      await _plant(picked);
    } on Object {
      if (!mounted) return;
      setState(() {
        _pickingId = null;
        _error = 'That photo could not be read. Try another.';
      });
    }
  }

  Future<void> _pickCandidate(PhotoCandidate candidate) async {
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
        _error = 'That photo could not be shared. Try another.';
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
              const Text(
                'Pick the photo to plant',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'Any photo from your albums. One per match, and nobody learns which one it was until the podium.',
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
            const Text('Reading your albums'),
          ],
        ),
      );
    }
    final albums = _albums;
    if (albums == null) {
      return SingleChildScrollView(
        child: SurfaceCard(
          child: EmptyState(
            title: 'Albums are not available',
            body: 'Photo access may be off. Allow it and try again.',
            actionLabel: 'Retry',
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
    if (widget.candidates.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.s16),
          child: EmptyState(
            title: 'No photos to plant',
            body: 'No approved photos are available on this device yet.',
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'From your approved photos',
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
