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
  Future<Uint8List> compressPhoto(Uint8List raw) async => raw;
}
