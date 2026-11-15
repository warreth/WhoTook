/// Small, locally stored avatar ids. Only the id travels with a player.
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
    kAvatarIds.contains(avatar) ? avatar! : kAvatarIds.first;
