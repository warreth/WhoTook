import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:photo_manager/photo_manager.dart';

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
  });

  final String assetId;
  final Uint8List bytes;

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
  static const int _pageSize = 40;
  static const int _maxPagesPerAlbum = 5;

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
    final paths = await PhotoManager.getAssetPathList(
      hasAll: false,
      type: RequestType.image,
    );
    final allowed = paths
        .where((path) => !excludedAlbumIds.contains(path.id))
        .toList();
    if (allowed.isEmpty) {
      return const <PickedPhoto>[];
    }
    allowed.shuffle(_random);

    final picked = <PickedPhoto>[];
    final seen = <String>{...excludeAssetIds};
    for (final path in allowed) {
      if (picked.length >= count) {
        break;
      }
      final assets = await _collectAssets(path, seen);
      assets.shuffle(_random);
      for (final asset in assets) {
        if (picked.length >= count) {
          break;
        }
        if (!seen.add(asset.id)) {
          continue;
        }
        final photo = await _readAsset(asset);
        if (photo == null) continue;
        if (requireDate && !_hasUsableDate(photo.capturedAt)) continue;
        picked.add(photo);
      }
    }
    return picked;
  }

  @override
  Future<PickedPhoto?> pickSinglePhoto() async {
    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
    );
    if (paths.isEmpty) {
      return null;
    }
    final assets = await _collectAssets(paths.first, const <String>{});
    if (assets.isEmpty) {
      return null;
    }
    return _readAsset(assets[_random.nextInt(assets.length)]);
  }

  @override
  Future<Uint8List> compressPhoto(Uint8List raw) {
    // keepExif false drops GPS and camera metadata before anything leaves
    // the device.
    return FlutterImageCompress.compressWithList(
      raw,
      minWidth: maxDimension,
      minHeight: maxDimension,
      quality: jpegQuality,
      keepExif: false,
      format: CompressFormat.jpeg,
    );
  }

  Future<List<AssetEntity>> _collectAssets(
    AssetPathEntity path,
    Set<String> excludeAssetIds,
  ) async {
    final assets = <AssetEntity>[];
    for (var page = 0; page < _maxPagesPerAlbum; page++) {
      final batch = await path.getAssetListPaged(
        page: page,
        size: _pageSize,
        type: RequestType.image,
      );
      if (batch.isEmpty) {
        break;
      }
      for (final asset in batch) {
        if (!excludeAssetIds.contains(asset.id)) {
          assets.add(asset);
        }
      }
      if (batch.length < _pageSize) {
        break;
      }
    }
    return assets;
  }

  Future<PickedPhoto?> _readAsset(AssetEntity asset) async {
    try {
      final raw = await asset.originBytes;
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final capturedAt = asset.createDateTime;
      return PickedPhoto(
        assetId: asset.id,
        bytes: await compressPhoto(raw),
        capturedAt: _hasUsableDate(capturedAt) ? capturedAt : null,
      );
    } on Exception {
      return null;
    }
  }

  static bool _hasUsableDate(DateTime? value) {
    if (value == null) return false;
    final year = value.year;
    if (year < 1970 || year > DateTime.now().year + 1) return false;
    return value.month >= 1 && value.month <= 12;
  }
}
