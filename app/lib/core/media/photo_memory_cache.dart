import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// One decoded [MemoryImage] per photo id for the whole app. The photo bytes
/// arriving over P2P are immutable once their chunk hash verifies, so the
/// provider can be reused across timer ticks, text rebuilds and phases.
class PhotoMemoryCache {
  PhotoMemoryCache._();

  static final PhotoMemoryCache instance = PhotoMemoryCache._();

  final Map<String, Uint8List> _bytes = <String, Uint8List>{};
  final Map<String, MemoryImage> _providers = <String, MemoryImage>{};

  bool hasPhoto(String photoId) =>
      photoId.isNotEmpty && (_bytes[photoId]?.isNotEmpty ?? false);

  Uint8List? bytesFor(String photoId) => _bytes[photoId];

  ImageProvider? providerFor(String photoId) {
    final bytes = _bytes[photoId];
    if (bytes == null || bytes.isEmpty) return null;
    return _providers.putIfAbsent(photoId, () => MemoryImage(bytes));
  }

  /// Lock a verified photo in the cache. A later identical transfer is a
  /// no-op; a different payload for the same id is ignored, which prevents an
  /// in-flight duplicate chunk from blanking or corrupting a finished photo.
  bool put(String photoId, Uint8List bytes) {
    if (photoId.isEmpty || bytes.isEmpty) return false;
    final existing = _bytes[photoId];
    if (existing != null && existing.isNotEmpty) {
      if (listEquals(existing, bytes)) return false;
      return false;
    }
    _bytes[photoId] = bytes;
    _providers[photoId] = MemoryImage(bytes);
    return true;
  }

  bool putBase64(String photoId, String encoded) {
    if (photoId.isEmpty || encoded.isEmpty) return false;
    if (hasPhoto(photoId)) return false;
    try {
      return put(photoId, base64Decode(encoded));
    } on FormatException {
      return false;
    }
  }

  Iterable<String> get photoIds => _providers.keys;

  /// Warms Flutter's decoded-image cache while the vault is still on screen.
  /// The same providers are reused by every later round and reveal.
  Future<void> precacheAll(BuildContext context) async {
    for (final provider in List<MemoryImage>.of(_providers.values)) {
      try {
        await precacheImage(provider, context);
      } on Object {
        // One bad photo must not stop the rest of the vault.
      }
    }
  }

  void clear() {
    _bytes.clear();
    _providers.clear();
  }
}
