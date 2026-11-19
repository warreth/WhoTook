import 'dart:async';

import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import 'photo_service.dart';

/// Deterministic gallery for the headless web playtest. It reads the bundled
/// party samples and gives every photo a real capture date, so Classic, Make
/// It Meme and Time Traveler can all run without a device gallery.
class PlaytestPhotoLibrary implements PhotoLibraryService {
  static const List<String> _assets = <String>[
    'party-cat.jpg',
    'party-dog.jpg',
    'party-hamster.jpg',
    'party-pizza.jpg',
    'party-cat2.jpg',
    'party-dog2.jpg',
    'party-cat3.jpg',
    'party-dog3.jpg',
    'party-hamster2.jpg',
    'party-pizza2.jpg',
    'party-cat4.jpg',
    'party-dog4.jpg',
  ];

  static final List<DateTime> _dates = <DateTime>[
    DateTime(1998, 4, 12),
    DateTime(2001, 8, 3),
    DateTime(2004, 11, 21),
    DateTime(2007, 2, 9),
    DateTime(2009, 7, 18),
    DateTime(2012, 5, 30),
    DateTime(2014, 9, 14),
    DateTime(2016, 12, 2),
    DateTime(2018, 6, 23),
    DateTime(2020, 3, 7),
    DateTime(2022, 10, 16),
    DateTime(2023, 1, 28),
  ];

  final Map<String, Uint8List> _bytes = <String, Uint8List>{};
  final Map<String, PickedPhoto> _byAsset = <String, PickedPhoto>{};
  int _serial = 0;

  @override
  Future<PermissionState> requestPermission() async =>
      PermissionState.authorized;

  @override
  Future<List<AlbumSummary>> listAlbums() async => <AlbumSummary>[
    const AlbumSummary(id: 'playtest', name: 'Playtest', assetCount: 12),
  ];

  Future<Uint8List> _load(String asset) async {
    final cached = _bytes[asset];
    if (cached != null) return cached;
    final data = await rootBundle.load('assets/samples/$asset');
    final bytes = data.buffer.asUint8List();
    _bytes[asset] = bytes;
    return bytes;
  }

  @override
  Future<List<PickedPhoto>> sampleCandidates({
    required Set<String> excludedAlbumIds,
    required int count,
    Set<String> excludeAssetIds = const <String>{},
    bool requireDate = false,
  }) async {
    final result = <PickedPhoto>[];
    for (var attempt = 0; result.length < count && attempt < 64; attempt++) {
      final index = (_serial + attempt) % _assets.length;
      final asset = _assets[index];
      final unique = '${asset.replaceAll('.', '-')}-${_serial++}';
      final localAssetId = 'playtest-$unique';
      if (excludeAssetIds.contains(localAssetId)) continue;
      final photo = PickedPhoto(
        assetId: localAssetId,
        bytes: await _load(asset),
        capturedAt: _dates[index],
      );
      _byAsset[localAssetId] = photo;
      result.add(photo);
    }
    return result;
  }

  @override
  Future<PickedPhoto?> pickSinglePhoto() async {
    final photos = await sampleCandidates(
      excludedAlbumIds: const <String>{},
      count: 1,
    );
    return photos.firstOrNull;
  }

  @override
  Future<List<AlbumPhotoThumb>> listAlbumPhotos(
    String albumId, {
    int page = 0,
    int size = 36,
  }) async => const <AlbumPhotoThumb>[];

  @override
  Future<PickedPhoto?> loadPhotoById(String assetId) async => _byAsset[assetId];

  @override
  Future<Uint8List> compressPhoto(Uint8List raw) async => raw;
}
