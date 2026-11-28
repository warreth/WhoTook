import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

/// Small, locally stored avatar ids. Only the id travels with a player.
const String kPhotoAvatar = 'photo';

const List<String> kAvatarIds = <String>[
  'pets',
  'face',
  'pizza',
  'music',
  'game',
  'rocket',
  'star',
  'plant',
];

const int _kMaxAvatarCacheEntries = 48;
final LinkedHashMap<String, Uint8List> _decodedAvatarCache =
    LinkedHashMap<String, Uint8List>();

String normalizeAvatar(String? avatar) =>
    avatar == kPhotoAvatar || kAvatarIds.contains(avatar)
    ? avatar!
    : kAvatarIds.first;

String encodeAvatarPhoto(Uint8List bytes) => base64Encode(bytes);

/// Decodes and caches selfie avatar bytes so 100 ms timer rebuilds never
/// repeatedly base64-decode or allocate fresh byte buffers.
Uint8List? decodeAvatarPhoto(String? value) {
  if (value == null || value.isEmpty) return null;
  final cached = _decodedAvatarCache.remove(value);
  if (cached != null) {
    _decodedAvatarCache[value] = cached;
    return cached;
  }
  try {
    final bytes = base64Decode(value);
    if (bytes.isEmpty) return null;
    if (_decodedAvatarCache.length >= _kMaxAvatarCacheEntries) {
      _decodedAvatarCache.remove(_decodedAvatarCache.keys.first);
    }
    _decodedAvatarCache[value] = bytes;
    return bytes;
  } on FormatException {
    return null;
  }
}
