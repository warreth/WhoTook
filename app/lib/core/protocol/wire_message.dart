import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Protocol event names. Kept as constants so a typo becomes a compile error.
abstract final class WireType {
  static const String joinReq = 'join_req';
  static const String joinAck = 'join_ack';
  static const String kick = 'kick';
  static const String lobbyState = 'lobby_state';
  static const String startPrepare = 'start_prepare';
  static const String submitPhotoMeta = 'submit_photos';
  static const String photoChunk = 'photo_chunk';
  static const String photoComplete = 'photo_complete';
  static const String photoRequest = 'photo_request';
  static const String playerReady = 'player_ready';
  static const String plantPhoto = 'plant_photo';
  static const String plantAssignment = 'plant_assignment';
  static const String versionWarning = 'version_warning';
  static const String roundCountdown = 'round_countdown';
  static const String roundShow = 'round_show';
  static const String submitGuess = 'submit_guess';
  static const String screenshotTaken = 'screenshot_taken';
  static const String screenshotAlert = 'screenshot_alert';
  static const String soundEffect = 'sound_effect';
  static const String roomTheme = 'room_theme';
  static const String partyPass = 'party_pass';
  static const String avatarUpdate = 'avatar_update';
  static const String roundReveal = 'round_reveal';
  static const String captionSubmit = 'caption_submit';
  static const String captionOptions = 'caption_options';
  static const String captionVote = 'caption_vote';
  static const String captionReveal = 'caption_reveal';
  static const String memeAssignment = 'meme_assignment';
  static const String memeSubmit = 'meme_submit';
  static const String memeOptions = 'meme_options';
  static const String memeFocus = 'meme_focus';
  static const String memeTally = 'meme_tally';
  static const String memeVote = 'meme_vote';
  static const String memeReveal = 'meme_reveal';
  static const String memeSwap = 'meme_swap';
  static const String timelineSubmit = 'timeline_submit';
  static const String timelineReveal = 'timeline_reveal';
  static const String extendPrepare = 'extend_prepare';
  static const String extendSubmit = 'extend_submit';
  static const String gamePodium = 'game_podium';
  static const String stateSync = 'state_sync';
  static const String roomClosed = 'room_closed';
  static const String errorNotice = 'error_notice';
  static const String ping = 'ping';
  static const String pong = 'pong';

  static const Set<String> all = <String>{
    joinReq,
    joinAck,
    kick,
    lobbyState,
    startPrepare,
    submitPhotoMeta,
    photoChunk,
    photoComplete,
    photoRequest,
    playerReady,
    plantPhoto,
    plantAssignment,
    versionWarning,
    roundCountdown,
    roundShow,
    submitGuess,
    screenshotTaken,
    screenshotAlert,
    soundEffect,
    roomTheme,
    partyPass,
    avatarUpdate,
    roundReveal,
    captionSubmit,
    captionOptions,
    captionVote,
    captionReveal,
    memeAssignment,
    memeSubmit,
    memeOptions,
    memeFocus,
    memeTally,
    memeVote,
    memeReveal,
    memeSwap,
    timelineSubmit,
    timelineReveal,
    extendPrepare,
    extendSubmit,
    gamePodium,
    stateSync,
    roomClosed,
    errorNotice,
    ping,
    pong,
  };
}

class WireFormatException implements Exception {
  const WireFormatException(this.message);

  final String message;

  @override
  String toString() => 'WireFormatException: $message';
}

/// Envelope for every message on the wire: `{ "type", "seq", "payload" }`.
class WireMessage {
  const WireMessage({
    required this.type,
    required this.seq,
    this.payload = const <String, dynamic>{},
  });

  final String type;
  final int seq;
  final Map<String, dynamic> payload;

  String encode() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'seq': seq,
    'payload': payload,
  };

  static WireMessage decode(String raw) {
    final Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } on FormatException catch (e) {
      throw WireFormatException('not JSON: ${e.message}');
    }
    if (parsed is! Map<String, dynamic>) {
      throw const WireFormatException('envelope must be a JSON object');
    }
    final type = parsed['type'];
    if (type is! String || type.isEmpty) {
      throw const WireFormatException('missing type');
    }
    final seq = parsed['seq'];
    if (seq is! int) {
      throw const WireFormatException('missing seq');
    }
    final payload = parsed['payload'];
    if (payload != null && payload is! Map<String, dynamic>) {
      throw const WireFormatException('payload must be an object');
    }
    return WireMessage(
      type: type,
      seq: seq,
      payload: (payload as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  @override
  String toString() => 'WireMessage($type, seq: $seq)';
}

/// One 16 KB slice of a photo transfer.
class PhotoChunk {
  const PhotoChunk({
    required this.photoId,
    required this.index,
    required this.total,
    required this.data,
    required this.sha256,
  });

  final String photoId;
  final int index;
  final int total;

  /// Base64 encoded slice, at most [PhotoChunker.chunkSize] raw bytes.
  final String data;

  /// SHA-256 of the whole photo, repeated on every chunk so a drop can be
  /// detected before the last chunk arrives.
  final String sha256;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'photoId': photoId,
    'index': index,
    'total': total,
    'data': data,
    'sha256': sha256,
  };

  factory PhotoChunk.fromJson(Map<String, dynamic> json) => PhotoChunk(
    photoId: json['photoId'] as String,
    index: json['index'] as int,
    total: json['total'] as int,
    data: json['data'] as String,
    sha256: json['sha256'] as String,
  );
}

/// Splits photos into fixed size base64 chunks and verifies the reassembled
/// bytes against the SHA-256 taken at split time.
abstract final class PhotoChunker {
  static const int chunkSize = 16 * 1024;
  static const int maxPhotoBytes = 2 * 1024 * 1024;

  static List<PhotoChunk> split(String photoId, Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const WireFormatException('cannot split an empty photo');
    }
    if (bytes.length > maxPhotoBytes) {
      throw WireFormatException(
        'photo is ${bytes.length} bytes, limit is $maxPhotoBytes',
      );
    }
    final digest = sha256.convert(bytes).toString();
    final total = (bytes.length + chunkSize - 1) ~/ chunkSize;
    final chunks = <PhotoChunk>[];
    for (var i = 0; i < total; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize) > bytes.length
          ? bytes.length
          : start + chunkSize;
      final slice = Uint8List.sublistView(bytes, start, end);
      chunks.add(
        PhotoChunk(
          photoId: photoId,
          index: i,
          total: total,
          data: base64Encode(slice),
          sha256: digest,
        ),
      );
    }
    return chunks;
  }
}

class PhotoAssemblyException implements Exception {
  const PhotoAssemblyException(this.message);

  final String message;

  @override
  String toString() => 'PhotoAssemblyException: $message';
}

/// Collects chunks for many photos at once and only yields bytes once every
/// chunk is present and the hash matches.
class PhotoChunkAssembler {
  final Map<String, _PendingPhoto> _pending = <String, _PendingPhoto>{};

  /// Adds one chunk. Returns the verified bytes when the photo is complete,
  /// otherwise null. Throws [PhotoAssemblyException] on corrupt input.
  Uint8List? add(PhotoChunk chunk) {
    if (chunk.total <= 0) {
      throw const PhotoAssemblyException('chunk total must be positive');
    }
    if (chunk.index < 0 || chunk.index >= chunk.total) {
      throw PhotoAssemblyException('chunk index ${chunk.index} out of range');
    }
    final pending = _pending.putIfAbsent(
      chunk.photoId,
      () => _PendingPhoto(total: chunk.total, sha256: chunk.sha256),
    );
    if (pending.total != chunk.total || pending.sha256 != chunk.sha256) {
      _pending.remove(chunk.photoId);
      throw const PhotoAssemblyException('chunk metadata mismatch');
    }
    final Uint8List slice;
    try {
      slice = base64Decode(chunk.data);
    } on FormatException {
      _pending.remove(chunk.photoId);
      throw const PhotoAssemblyException('chunk is not valid base64');
    }
    if (slice.length > PhotoChunker.chunkSize) {
      _pending.remove(chunk.photoId);
      throw const PhotoAssemblyException('chunk exceeds 16 KB');
    }
    final duplicate = pending.chunks[chunk.index];
    if (duplicate != null) {
      // Retransmits are common on a flaky link. The same bytes are already in
      // the buffer, so dropping the copy keeps the transfer alive instead of
      // discarding every chunk received so far.
      if (_sameBytes(duplicate, slice)) return null;
      _pending.remove(chunk.photoId);
      throw PhotoAssemblyException(
        'chunk ${chunk.index} changed for ${chunk.photoId}',
      );
    }
    pending.chunks[chunk.index] = slice;
    if (pending.receivedBytes > PhotoChunker.maxPhotoBytes) {
      _pending.remove(chunk.photoId);
      throw const PhotoAssemblyException('photo exceeds 2 MB');
    }
    if (pending.chunks.length != pending.total) {
      return null;
    }

    final builder = BytesBuilder(copy: false);
    for (var i = 0; i < pending.total; i++) {
      builder.add(pending.chunks[i]!);
    }
    final bytes = builder.takeBytes();
    _pending.remove(chunk.photoId);
    if (bytes.length > PhotoChunker.maxPhotoBytes) {
      throw const PhotoAssemblyException('photo exceeds 2 MB');
    }
    final digest = sha256.convert(bytes).toString();
    if (digest != pending.sha256) {
      throw const PhotoAssemblyException('SHA-256 mismatch, photo corrupted');
    }
    return bytes;
  }

  bool isPending(String photoId) => _pending.containsKey(photoId);

  void discard(String photoId) => _pending.remove(photoId);
}

class _PendingPhoto {
  _PendingPhoto({required this.total, required this.sha256});

  final int total;
  final String sha256;
  final Map<int, Uint8List> chunks = <int, Uint8List>{};

  int get receivedBytes =>
      chunks.values.fold(0, (sum, chunk) => sum + chunk.length);
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
