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

String normalizeAvatar(String? avatar) =>
    avatar == kPhotoAvatar || kAvatarIds.contains(avatar)
    ? avatar!
    : kAvatarIds.first;

String encodeAvatarPhoto(Uint8List bytes) => base64Encode(bytes);

Uint8List? decodeAvatarPhoto(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    final bytes = base64Decode(value);
    return bytes.isEmpty ? null : bytes;
  } on FormatException {
    return null;
  }
}
