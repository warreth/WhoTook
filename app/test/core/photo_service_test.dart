import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:whotook/core/media/photo_service.dart';

/// Test double for [PhotoLibraryService]: keeps the seam exercised without a
/// device, and stays out of production code.
class FakePhotoLibraryService implements PhotoLibraryService {
  FakePhotoLibraryService({
    this.permission = PermissionState.authorized,
    this.albums = const <AlbumSummary>[],
    this.assets = const <String, String>{},
    int seed = 1,
  }) : _random = Random(seed);

  final PermissionState permission;
  final List<AlbumSummary> albums;

  /// asset id -> album id.
  final Map<String, String> assets;
  final Random _random;
  final Set<String> requestedPermissions = <String>{};
  final List<Set<String>> sampledExclusions = <Set<String>>[];

  @override
  Future<PermissionState> requestPermission() async {
    requestedPermissions.add('request');
    return permission;
  }

  @override
  Future<List<AlbumSummary>> listAlbums() async => albums;

  @override
  Future<List<PickedPhoto>> sampleCandidates({
    required Set<String> excludedAlbumIds,
    required int count,
    Set<String> excludeAssetIds = const <String>{},
  }) async {
    sampledExclusions.add(excludedAlbumIds);
    final pool =
        assets.entries
            .where((e) => !excludedAlbumIds.contains(e.value))
            .where((e) => !excludeAssetIds.contains(e.key))
            .map((e) => e.key)
            .toList()
          ..shuffle(_random);
    return pool
        .take(count)
        .map(
          (id) => PickedPhoto(assetId: id, bytes: Uint8List.fromList(<int>[1])),
        )
        .toList();
  }

  @override
  Future<PickedPhoto?> pickSinglePhoto() async {
    if (assets.isEmpty) {
      return null;
    }
    final id = assets.keys.elementAt(_random.nextInt(assets.length));
    return PickedPhoto(assetId: id, bytes: Uint8List.fromList(<int>[2]));
  }

  @override
  Future<List<AlbumPhotoThumb>> listAlbumPhotos(
    String albumId, {
    int page = 0,
    int size = 36,
  }) async {
    final ids = assets.entries
        .where((e) => e.value == albumId)
        .map((e) => e.key)
        .toList();
    final start = page * size;
    if (start >= ids.length || size <= 0) return const <AlbumPhotoThumb>[];
    final end = (start + size) > ids.length ? ids.length : start + size;
    return <AlbumPhotoThumb>[
      for (final id in ids.sublist(start, end))
        AlbumPhotoThumb(
          assetId: id,
          thumbnailBytes: Uint8List.fromList(<int>[3]),
        ),
    ];
  }

  @override
  Future<PickedPhoto?> loadPhotoById(String assetId) async {
    if (!assets.containsKey(assetId)) return null;
    return PickedPhoto(assetId: assetId, bytes: Uint8List.fromList(<int>[4]));
  }

  @override
  Future<Uint8List> compressPhoto(Uint8List raw) async =>
      Uint8List.fromList(<int>[raw.length & 0xFF]);
}

void main() {
  test('the fake honours album exclusions and already used assets', () async {
    final service = FakePhotoLibraryService(
      albums: const <AlbumSummary>[
        AlbumSummary(id: 'cam', name: 'Camera', assetCount: 3),
        AlbumSummary(id: 'shots', name: 'Screenshots', assetCount: 2),
      ],
      assets: const <String, String>{
        'a1': 'cam',
        'a2': 'cam',
        'a3': 'cam',
        's1': 'shots',
        's2': 'shots',
      },
    );
    final picked = await service.sampleCandidates(
      excludedAlbumIds: <String>{'shots'},
      count: 10,
    );
    expect(picked.length, 3);
    expect(picked.every((p) => p.assetId.startsWith('a')), isTrue);
    expect(service.sampledExclusions.single, <String>{'shots'});

    final reroll = await service.sampleCandidates(
      excludedAlbumIds: const <String>{},
      count: 10,
      excludeAssetIds: <String>{'a1', 'a2'},
    );
    expect(reroll.map((p) => p.assetId), isNot(contains('a1')));
    expect(reroll.map((p) => p.assetId), isNot(contains('a2')));
  });

  test('the fake reports permission state and compresses', () async {
    final service = FakePhotoLibraryService(
      permission: PermissionState.limited,
    );
    expect(await service.requestPermission(), PermissionState.limited);
    expect(service.requestedPermissions, contains('request'));
    final compressed = await service.compressPhoto(Uint8List(300));
    expect(compressed.single, 300 & 0xFF);
  });

  test('the fake returns null when there is nothing to pick', () async {
    final service = FakePhotoLibraryService();
    expect(await service.pickSinglePhoto(), isNull);
    expect(
      await service.sampleCandidates(
        excludedAlbumIds: const <String>{},
        count: 3,
      ),
      isEmpty,
    );
  });

  test('the device service exposes the documented compression settings', () {
    expect(DevicePhotoLibraryService.maxDimension, 1080);
    expect(DevicePhotoLibraryService.jpegQuality, 75);
  });
}
