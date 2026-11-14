import 'dart:async';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';
import 'package:whotook/core/media/photo_service.dart';

/// Deterministic photo source for tests. Bytes are distinct per asset so a
/// mis-routed photo is visible in an assertion instead of silently passing.
class TestPhotoLibrary implements PhotoLibraryService {
  TestPhotoLibrary({this.assetsPerAlbum = 40, this._seed = 0});

  final int assetsPerAlbum;
  final int _seed;
  int _call = 0;

  @override
  Future<PermissionState> requestPermission() async =>
      PermissionState.authorized;

  @override
  Future<List<AlbumSummary>> listAlbums() async => <AlbumSummary>[
    AlbumSummary(id: 'camera', name: 'Camera', assetCount: assetsPerAlbum),
    AlbumSummary(id: 'screenshots', name: 'Screenshots', assetCount: 4),
  ];

  @override
  Future<List<PickedPhoto>> sampleCandidates({
    required Set<String> excludedAlbumIds,
    required int count,
    Set<String> excludeAssetIds = const <String>{},
    bool requireDate = false,
  }) async {
    _call += 1;
    final result = <PickedPhoto>[];
    for (
      var i = 0;
      result.length < count && i < count + excludeAssetIds.length;
      i++
    ) {
      final id = 'a$_seed-$_call-$i';
      if (excludeAssetIds.contains(id)) continue;
      final byte = (_call * 37 + i * 11) % 251;
      result.add(
        PickedPhoto(
          assetId: id,
          bytes: Uint8List.fromList(<int>[byte, byte, byte, byte]),
          capturedAt: DateTime(2014 + ((_call + i) % 9), 1 + (i % 12), 12),
        ),
      );
    }
    return result;
  }

  @override
  Future<PickedPhoto?> pickSinglePhoto() async => (await sampleCandidates(
    excludedAlbumIds: const <String>{},
    count: 1,
  )).first;

  @override
  Future<List<AlbumPhotoThumb>> listAlbumPhotos(
    String albumId, {
    int page = 0,
    int size = 36,
  }) async {
    final total = albumId == 'screenshots' ? 4 : assetsPerAlbum;
    final start = page < 0 ? 0 : page * size;
    if (start >= total || size <= 0) return const <AlbumPhotoThumb>[];
    final end = (start + size) > total ? total : start + size;
    return <AlbumPhotoThumb>[
      for (var i = start; i < end; i++)
        AlbumPhotoThumb(
          assetId: '$albumId-$_seed-$i',
          thumbnailBytes: Uint8List.fromList(<int>[
            (i * 13) % 251,
            (i * 7) % 251,
            40,
            40,
          ]),
        ),
    ];
  }

  @override
  Future<PickedPhoto?> loadPhotoById(String assetId) async {
    final digits = RegExp(r'(\d+)$').firstMatch(assetId)?.group(1);
    final seed = digits == null ? 0 : int.parse(digits);
    final byte = (seed * 37) % 251;
    return PickedPhoto(
      assetId: assetId,
      bytes: Uint8List.fromList(<int>[byte, byte, byte, byte]),
      capturedAt: DateTime(2015 + (seed % 7), 1 + (seed % 12), 12),
    );
  }

  @override
  Future<Uint8List> compressPhoto(Uint8List raw) async => raw;
}
