import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:photo_manager/photo_manager.dart';

/// Smaller JPEGs for peers whose data path relays through TURN. The upload
/// profile is milder because the host may re-encode it once more for relayed
/// receivers.
const int kRelayPhotoDimension = 720;
const int kRelayPhotoQuality = 60;
const int kRelayUploadDimension = 900;
const int kRelayUploadQuality = 68;

/// One random index from each equal slice of the full library range. The result
/// covers the oldest and newest photos instead of only the recent camera roll.
@visibleForTesting
List<int> stratifiedSampleIndices(int total, int count, Random random) {
  if (total <= 0 || count <= 0) return const <int>[];
  final take = min(total, count);
  final seen = <int>{};
  final indices = <int>[];
  for (var i = 0; i < take; i++) {
    final start = (total * i) ~/ take;
    final end = (total * (i + 1)) ~/ take;
    final span = max(1, end - start);
    var index = start + random.nextInt(span);
    if (index >= total) index = total - 1;
    // Slices are disjoint when total >= count; scanning forward keeps the
    // smaller-than-count case unique too.
    while (!seen.add(index) && seen.length < total) {
      index = (index + 1) % total;
    }
    indices.add(index);
  }
  return indices;
}

/// Injectable seam so tests can watch the relay path without the native codec.
typedef PhotoCompressor = Future<Uint8List> Function(
  Uint8List raw, {
  int? maxDimension,
  int? quality,
});

Future<Uint8List> compressPhotoBytes(
  Uint8List raw, {
  int maxDimension = 1080,
  int quality = 75,
}) async {
  try {
    final compressed = await FlutterImageCompress.compressWithList(
      raw,
      minWidth: maxDimension,
      minHeight: maxDimension,
      quality: quality,
      keepExif: false,
      format: CompressFormat.jpeg,
    );
    return compressed.isEmpty ? raw : compressed;
  } on Object {
    return raw;
  }
}

class PhotoPermissionDeniedException implements Exception {
  const PhotoPermissionDeniedException(this.state);

  final PermissionState state;

  @override
  String toString() => 'PhotoPermissionDeniedException: ${state.name}';
}

class AlbumSummary {
  const AlbumSummary({
    required this.id,
    required this.name,
    required this.assetCount,
  });

  final String id;
  final String name;
  final int assetCount;
}

class PickedPhoto {
  const PickedPhoto({
    required this.assetId,
    required this.bytes,
    this.capturedAt,
    this.isPanorama = false,
  });

  final String assetId;
  final Uint8List bytes;
  final bool isPanorama;

  /// Gallery capture time. Time Traveler refuses photos without a usable date.
  final DateTime? capturedAt;
}

/// One tile in the album browser: a small decoded thumbnail plus its asset id.
class AlbumPhotoThumb {
  const AlbumPhotoThumb({required this.assetId, required this.thumbnailBytes});

  final String assetId;
  final Uint8List thumbnailBytes;
}

/// Photo access behind one seam so the prepare screen can be driven by a fake
/// in tests. Every byte returned here is already compressed and EXIF-free.
abstract class PhotoLibraryService {
  Future<PermissionState> requestPermission();

  Future<List<AlbumSummary>> listAlbums();

  /// Picks [count] random photos from albums not in [excludedAlbumIds],
  /// skipping [excludeAssetIds] (already approved or rerolled away).
  Future<List<PickedPhoto>> sampleCandidates({
    required Set<String> excludedAlbumIds,
    required int count,
    Set<String> excludeAssetIds = const <String>{},
    bool requireDate = false,
  });

  Future<PickedPhoto?> pickSinglePhoto();

  /// One page of album tiles, using small thumbnails so browsing a huge
  /// album never decodes full resolution images into memory.
  Future<List<AlbumPhotoThumb>> listAlbumPhotos(
    String albumId, {
    int page = 0,
    int size = 36,
  });

  /// Reads and compresses one specific asset, e.g. a photo picked from the
  /// album browser.
  Future<PickedPhoto?> loadPhotoById(String assetId);

  Future<Uint8List> compressPhoto(Uint8List raw);
}

class DevicePhotoLibraryService implements PhotoLibraryService {
  DevicePhotoLibraryService({Random? random}) : _random = random ?? Random();

  static const int maxDimension = 1080;
  static const int jpegQuality = 75;

  static const PermissionRequestOption _requestOption = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.image,
      mediaLocation: false,
    ),
  );

  final Random _random;

  @override
  Future<PermissionState> requestPermission() async {
    var state = await PhotoManager.requestPermissionExtend(
      requestOption: _requestOption,
    );
    // Android 14+ and iOS can grant a partial selection. Re-prompting opens
    // the system picker so the player can widen it without leaving the app.
    if (state == PermissionState.limited) {
      await PhotoManager.presentLimited(type: RequestType.image);
      state = await PhotoManager.getPermissionState(
        requestOption: _requestOption,
      );
    }
    return state;
  }

  @override
  Future<List<AlbumSummary>> listAlbums() async {
    final paths = await PhotoManager.getAssetPathList(
      hasAll: false,
      type: RequestType.image,
    );
    final albums = <AlbumSummary>[];
    for (final path in paths) {
      albums.add(
        AlbumSummary(
          id: path.id,
          name: path.name,
          assetCount: await path.assetCountAsync,
        ),
      );
    }
    return albums;
  }

  @override
  Future<List<AlbumPhotoThumb>> listAlbumPhotos(
    String albumId, {
    int page = 0,
    int size = 36,
  }) async {
    final paths = await PhotoManager.getAssetPathList(
      hasAll: true,
      type: RequestType.image,
    );
    AssetPathEntity? album;
    for (final path in paths) {
      if (path.id == albumId) {
        album = path;
        break;
      }
    }
    if (album == null) {
      return const <AlbumPhotoThumb>[];
    }
    final assets = await album.getAssetListPaged(
      page: page,
      size: size,
      type: RequestType.image,
    );
    final thumbs = <AlbumPhotoThumb>[];
    for (final asset in assets) {
      // Square 240 px thumbs keep a long album scroller light on memory.
      final thumb = await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(240),
        quality: 75,
      );
      if (thumb == null || thumb.isEmpty) continue;
      thumbs.add(AlbumPhotoThumb(assetId: asset.id, thumbnailBytes: thumb));
    }
    return thumbs;
  }

  @override
  Future<PickedPhoto?> loadPhotoById(String assetId) async {
    final asset = await AssetEntity.fromId(assetId);
    if (asset == null) return null;
    return _readAsset(asset);
  }

  @override
  Future<List<PickedPhoto>> sampleCandidates({
    required Set<String> excludedAlbumIds,
    required int count,
    Set<String> excludeAssetIds = const <String>{},
    bool requireDate = false,
  }) async {
    if (count <= 0) {
      return const <PickedPhoto>[];
    }
    final ranges = await _sampleRanges(excludedAlbumIds);
    final total = ranges.fold<int>(0, (sum, range) => sum + range.count);
    if (total <= 0) {
      return const <PickedPhoto>[];
    }

    // One random index from every full-history slice. This is the difference
    // between "recent camera roll page" and an actually random sample.
    final indices = stratifiedSampleIndices(total, count, _random);
    final attempted = <int>{};
    final picked = <PickedPhoto>[];
    for (final index in indices) {
      final photo = await _photoAt(
        ranges: ranges,
        index: index,
        excludeAssetIds: excludeAssetIds,
        requireDate: requireDate,
        attempted: attempted,
      );
      if (photo != null) picked.add(photo);
    }

    // A slot can fail because the asset is corrupt, a video, already excluded
    // or missing a date. Retry across the whole range, never the recent page.
    var guard = 0;
    final maxAttempts = max(count * 8, 24);
    while (picked.length < count &&
        guard++ < maxAttempts &&
        attempted.length < total) {
      final photo = await _photoAt(
        ranges: ranges,
        index: _random.nextInt(total),
        excludeAssetIds: excludeAssetIds,
        requireDate: requireDate,
        attempted: attempted,
      );
      if (photo != null) picked.add(photo);
    }
    picked.shuffle(_random);
    return picked;
  }

  @override
  Future<PickedPhoto?> pickSinglePhoto() async {
    final ranges = await _sampleRanges(const <String>{});
    final total = ranges.fold<int>(0, (sum, range) => sum + range.count);
    if (total <= 0) return null;
    final attempted = <int>{};
    final maxAttempts = min(total, 16);
    for (var i = 0; i < maxAttempts; i++) {
      final photo = await _photoAt(
        ranges: ranges,
        index: _random.nextInt(total),
        excludeAssetIds: const <String>{},
        requireDate: false,
        attempted: attempted,
      );
      if (photo != null) return photo;
    }
    return null;
  }

  @override
  Future<Uint8List> compressPhoto(Uint8List raw) {
    // keepExif false drops GPS and camera metadata before anything leaves
    // the device.
    return compressPhotoBytes(
      raw,
      maxDimension: maxDimension,
      quality: jpegQuality,
    );
  }

  /// The all-photos path gives a chronological full timeline. When the host
  /// excludes albums we cannot filter that path, so allowed albums become
  /// adjacent ranges instead and each range is sampled across its whole count.
  Future<List<_PhotoRange>> _sampleRanges(Set<String> excludedAlbumIds) async {
    final paths = excludedAlbumIds.isEmpty
        ? await PhotoManager.getAssetPathList(
            onlyAll: true,
            type: RequestType.image,
          )
        : await PhotoManager.getAssetPathList(
            hasAll: false,
            type: RequestType.image,
          );
    final ranges = <_PhotoRange>[];
    var offset = 0;
    for (final path in paths) {
      if (excludedAlbumIds.contains(path.id)) continue;
      final total = await path.assetCountAsync;
      if (total <= 0) continue;
      ranges.add(_PhotoRange(path: path, start: offset, count: total));
      offset += total;
    }
    return ranges;
  }

  Future<PickedPhoto?> _photoAt({
    required List<_PhotoRange> ranges,
    required int index,
    required Set<String> excludeAssetIds,
    required bool requireDate,
    required Set<int> attempted,
  }) async {
    if (!attempted.add(index)) return null;
    final range = _rangeFor(ranges, index);
    if (range == null) return null;
    final local = index - range.start;
    try {
      final assets = await range.path.getAssetListRange(
        start: local,
        end: local + 1,
        type: RequestType.image,
      );
      if (assets.isEmpty) return null;
      final asset = assets.first;
      if (excludeAssetIds.contains(asset.id)) return null;
      final photo = await _readAsset(asset);
      if (photo == null) return null;
      if (requireDate && !isUsableCaptureDate(photo.capturedAt)) return null;
      return photo;
    } on Object {
      return null;
    }
  }

  static _PhotoRange? _rangeFor(List<_PhotoRange> ranges, int index) {
    for (final range in ranges) {
      if (index >= range.start && index < range.start + range.count) {
        return range;
      }
    }
    return null;
  }

  Future<PickedPhoto?> _readAsset(AssetEntity asset) async {
    try {
      final capturedAt = asset.createDateTime;
      // Ask the photo manager for a compressed frame first. Origin bytes plus
      // flutter_image_compress make the gallery feel slow on large libraries.
      final thumb = await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(maxDimension),
        quality: jpegQuality,
      );
      if (thumb != null && thumb.isNotEmpty) {
        return PickedPhoto(
          assetId: asset.id,
          bytes: thumb,
          capturedAt: isUsableCaptureDate(capturedAt) ? capturedAt : null,
          isPanorama: _isPanorama(asset),
        );
      }
      final raw = await asset.originBytes;
      if (raw == null || raw.isEmpty) {
        return null;
      }
      return PickedPhoto(
        assetId: asset.id,
        bytes: await compressPhoto(raw),
        capturedAt: isUsableCaptureDate(capturedAt) ? capturedAt : null,
        isPanorama: _isPanorama(asset),
      );
    } on Object {
      return null;
    }
  }

  static bool _isPanorama(AssetEntity asset) {
    final width = asset.width;
    final height = asset.height;
    if (width <= 0 || height <= 0) return false;
    return width / height > 2.2 || height / width > 2.2;
  }

  static bool isUsableCaptureDate(DateTime? value) {
    if (value == null) return false;
    final year = value.year;
    if (year < 1970 || year > DateTime.now().year + 1) return false;
    if (value.month < 1 || value.month > 12) return false;
    // Photo managers return the Unix epoch for photos without a capture date.
    return !(year == 1970 && value.month == 1 && value.day == 1);
  }
}

class _PhotoRange {
  const _PhotoRange({
    required this.path,
    required this.start,
    required this.count,
  });

  final AssetPathEntity path;
  final int start;
  final int count;
}
