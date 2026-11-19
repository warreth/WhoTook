import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String kLastRoomStorageKey = 'whotook.last_room.v1';

/// The last room this phone joined, kept across restarts so the player can
/// step back in without scanning the same QR again.
class LastRoom {
  const LastRoom({
    required this.inviteUrl,
    required this.roomId,
    required this.playerId,
    required this.playerToken,
    required this.joinedAtUtc,
  });

  final String inviteUrl;
  final String roomId;
  final String playerId;
  final String playerToken;
  final DateTime joinedAtUtc;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'inviteUrl': inviteUrl,
    'roomId': roomId,
    'playerId': playerId,
    'playerToken': playerToken,
    'joinedAtUtc': joinedAtUtc.toIso8601String(),
  };

  factory LastRoom.fromJson(Map<String, dynamic> json) => LastRoom(
    inviteUrl: json['inviteUrl'] as String,
    roomId: json['roomId'] as String,
    playerId: (json['playerId'] as String?) ?? '',
    playerToken: (json['playerToken'] as String?) ?? '',
    joinedAtUtc:
        DateTime.tryParse(json['joinedAtUtc'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
  );
}

class LastRoomRepository {
  LastRoomRepository({
    SharedPreferencesAsync? preferences,
    this.storageKey = kLastRoomStorageKey,
  }) : _prefs = preferences ?? SharedPreferencesAsync();

  /// The offline demo keeps its rooms in memory and never touches the
  /// platform preferences channel.
  LastRoomRepository.memory({this.storageKey = kLastRoomStorageKey})
    : _prefs = null;

  final SharedPreferencesAsync? _prefs;
  final String storageKey;
  LastRoom? _memory;

  Future<LastRoom?> load() async {
    final prefs = _prefs;
    if (prefs == null) return _memory;
    final raw = await prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) return null;
      final room = LastRoom.fromJson(parsed);
      if (room.inviteUrl.isEmpty || room.roomId.isEmpty) return null;
      return room;
    } on Object {
      return null;
    }
  }

  Future<void> remember(LastRoom room) async {
    _memory = room;
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setString(storageKey, jsonEncode(room.toJson()));
    }
  }

  Future<void> forget() async {
    _memory = null;
    final prefs = _prefs;
    if (prefs != null) await prefs.remove(storageKey);
  }
}
