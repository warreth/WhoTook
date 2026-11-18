import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../core/media/photo_service.dart';

/// Bundled photo source for the offline demo. No gallery permission, no
/// network, and every asset has a date so Time Traveler can run too.
class DemoPhotoLibrary implements PhotoLibraryService {
  DemoPhotoLibrary({this.playerIndex = 0, this.assetOffset = 0});

  final int playerIndex;
  final int assetOffset;
  int _call = 0;

  static const List<String> _assets = <String>[
    'assets/samples/party-dog.jpg',
    'assets/samples/party-cat.jpg',
    'assets/samples/party-hamster.jpg',
    'assets/samples/party-pizza.jpg',
    'assets/samples/party-dog2.jpg',
    'assets/samples/party-cat2.jpg',
    'assets/samples/party-dog3.jpg',
    'assets/samples/party-cat3.jpg',
    'assets/samples/party-hamster2.jpg',
    'assets/samples/party-pizza2.jpg',
    'assets/samples/party-dog4.jpg',
    'assets/samples/party-cat4.jpg',
  ];

  static final List<DateTime> _dates = <DateTime>[
    DateTime(2012, 6, 14),
    DateTime(2015, 8, 2),
    DateTime(2017, 12, 24),
    DateTime(2019, 4, 6),
    DateTime(2021, 10, 30),
    DateTime(2023, 2, 18),
    DateTime(2014, 9, 21),
    DateTime(2016, 5, 11),
    DateTime(2018, 7, 7),
    DateTime(2020, 3, 29),
    DateTime(2022, 11, 13),
    DateTime(2024, 6, 1),
  ];

  static final Map<String, Uint8List> _bytes = <String, Uint8List>{};

  static Future<Uint8List> _load(String asset) async {
    final cached = _bytes[asset];
    if (cached != null) return cached;
    final data = await rootBundle.load(asset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    _bytes[asset] = bytes;
    return bytes;
  }

  String _assetId(int index) {
    final absolute = (index + assetOffset) % _assets.length;
    return 'demo-$playerIndex-$absolute';
  }

  int _indexFor(String assetId) {
    final parts = assetId.split('-');
    if (parts.length != 3) return -1;
    return int.tryParse(parts.last) ?? -1;
  }

  Future<PickedPhoto> _photo(int index) async {
    final absolute = index % _assets.length;
    final asset = _assets[absolute];
    final bytes = await _load(asset);
    return PickedPhoto(
      assetId: _assetId(absolute),
      bytes: bytes,
      capturedAt: _dates[absolute],
    );
  }

  @override
  Future<PermissionState> requestPermission() async =>
      PermissionState.authorized;

  @override
  Future<List<AlbumSummary>> listAlbums() async => <AlbumSummary>[
    const AlbumSummary(id: 'demo-photos', name: 'Demo photos', assetCount: 6),
  ];

  @override
  Future<List<PickedPhoto>> sampleCandidates({
    required Set<String> excludedAlbumIds,
    required int count,
    Set<String> excludeAssetIds = const <String>{},
    bool requireDate = false,
  }) async {
    _call += 1;
    final start = (_call + assetOffset + playerIndex) % _assets.length;
    final order = <int>[
      for (var i = 0; i < _assets.length; i++) (start + i) % _assets.length,
    ];
    final filtered = order
        .where((index) => !excludeAssetIds.contains(_assetId(index)))
        .toList();
    // A six-photo vault cannot reroll without repeating. Keep the demo
    // rolling instead of returning an empty set.
    final chosen = (filtered.isEmpty ? order : filtered).take(count);
    return <PickedPhoto>[for (final index in chosen) await _photo(index)];
  }

  @override
  Future<PickedPhoto?> pickSinglePhoto() async {
    final photos = await sampleCandidates(
      excludedAlbumIds: const <String>{},
      count: 1,
    );
    return photos.isEmpty ? null : photos.first;
  }

  @override
  Future<List<AlbumPhotoThumb>> listAlbumPhotos(
    String albumId, {
    int page = 0,
    int size = 36,
  }) async {
    if (page > 0) return const <AlbumPhotoThumb>[];
    final photos = <AlbumPhotoThumb>[];
    for (var i = 0; i < _assets.length; i++) {
      photos.add(
        AlbumPhotoThumb(
          assetId: _assetId(i),
          thumbnailBytes: await _load(_assets[i]),
        ),
      );
    }
    return photos;
  }

  @override
  Future<PickedPhoto?> loadPhotoById(String assetId) async {
    final index = _indexFor(assetId);
    if (index < 0 || index >= _assets.length) return null;
    return _photo(index);
  }

  @override
  Future<Uint8List> compressPhoto(Uint8List raw) async => raw;
}
