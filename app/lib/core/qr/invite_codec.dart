import 'dart:convert';

class InvalidInviteException implements Exception {
  const InvalidInviteException(this.reason);

  final String reason;

  @override
  String toString() => 'InvalidInviteException: $reason';
}

/// Contents of the QR invite. The whole payload lives in the URL fragment so
/// LAN IPs and the room secret never reach the web server when scanned by a
/// browser.
class InvitePayload {
  const InvitePayload({
    required this.roomId,
    required this.hostId,
    required this.secret,
    this.version = 1,
    this.lanEndpoints = const <String>[],
    this.signalingUrl,
  });

  static const int currentVersion = 1;

  final int version;
  final String roomId;
  final String hostId;
  final List<String> lanEndpoints;
  final String? signalingUrl;
  final String secret;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'v': version,
    'room': roomId,
    'hostId': hostId,
    'lan': lanEndpoints,
    'sig': signalingUrl,
    'secret': secret,
  };

  factory InvitePayload.fromJson(Map<String, dynamic> json) {
    final version = json['v'];
    if (version is! int) {
      throw const InvalidInviteException('missing version');
    }
    if (version > currentVersion || version < 1) {
      throw InvalidInviteException('unsupported version $version');
    }
    final room = json['room'];
    if (room is! String || !_roomIdPattern.hasMatch(room)) {
      throw const InvalidInviteException('invalid room id');
    }
    final host = json['hostId'];
    if (host is! String || host.isEmpty || host.length > 64) {
      throw const InvalidInviteException('invalid host id');
    }
    final secret = json['secret'];
    if (secret is! String || !_secretPattern.hasMatch(secret)) {
      throw const InvalidInviteException('invalid room secret');
    }
    final lan = json['lan'];
    if (lan != null && lan is! List) {
      throw const InvalidInviteException('lan must be a list');
    }
    final endpoints = <String>[];
    for (final entry in (lan as List<dynamic>?) ?? const <dynamic>[]) {
      if (entry is! String || entry.isEmpty) {
        throw const InvalidInviteException('invalid lan endpoint');
      }
      endpoints.add(entry);
    }
    final sig = json['sig'];
    if (sig != null && (sig is! String || sig.isEmpty)) {
      throw const InvalidInviteException('invalid signaling url');
    }
    return InvitePayload(
      version: version,
      roomId: room,
      hostId: host,
      secret: secret,
      lanEndpoints: List<String>.unmodifiable(endpoints),
      signalingUrl: sig as String?,
    );
  }

  static final RegExp _roomIdPattern = RegExp(r'^[A-Za-z0-9_-]{4,32}$');
  static final RegExp _secretPattern = RegExp(r'^[A-Za-z0-9_-]{8,128}$');
}

/// Encodes an invite as `https://whotook.party/j#<base64url(JSON)>`. Padding is
/// dropped so the fragment stays inside QR alphanumeric mode.
String encodeInviteUrl(
  InvitePayload payload, {
  String baseUrl = 'https://whotook.party/j',
}) {
  final body = base64Url
      .encode(utf8.encode(jsonEncode(payload.toJson())))
      .replaceAll('=', '');
  return '$baseUrl#$body';
}

/// Parses any accepted invite form. Throws [InvalidInviteException] for a bad
/// QR code instead of returning a half filled payload.
InvitePayload tryParseInvite(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw const InvalidInviteException('empty invite');
  }

  final fragment = _extractFragment(trimmed);
  if (fragment != null) {
    return _decodeBody(fragment);
  }
  return _decodeBody(trimmed);
}

String? _extractFragment(String raw) {
  final hashIndex = raw.indexOf('#');
  if (hashIndex >= 0) {
    final head = raw.substring(0, hashIndex);
    final body = raw.substring(hashIndex + 1).trim();
    if (body.isEmpty) {
      throw const InvalidInviteException('empty invite fragment');
    }
    final isHttp = head.startsWith('https://') || head.startsWith('http://');
    final isAppScheme = head.startsWith('whotook://');
    if (isHttp) {
      final uri = Uri.tryParse(head);
      final path = uri?.path ?? '';
      if (path != '/j' && !path.endsWith('/j')) {
        throw const InvalidInviteException('invite path must be /j');
      }
      return body;
    }
    if (isAppScheme) {
      final host = head.substring('whotook://'.length);
      if (host != 'join') {
        throw const InvalidInviteException('app link must be whotook://join');
      }
      return body;
    }
    throw const InvalidInviteException('unsupported invite scheme');
  }
  return null;
}

InvitePayload _decodeBody(String body) {
  final decoded = _tryBase64Json(body);
  if (decoded != null) {
    return decoded;
  }
  if (body.startsWith('{')) {
    final Object? parsed;
    try {
      parsed = jsonDecode(body);
    } on FormatException {
      throw const InvalidInviteException('malformed invite JSON');
    }
    if (parsed is! Map<String, dynamic>) {
      throw const InvalidInviteException('invite JSON must be an object');
    }
    return InvitePayload.fromJson(parsed);
  }
  throw const InvalidInviteException('invite is neither base64 nor JSON');
}

InvitePayload? _tryBase64Json(String body) {
  final List<int> bytes;
  try {
    bytes = base64Url.decode(base64Url.normalize(body));
  } on FormatException {
    return null;
  }
  final Object? parsed;
  try {
    parsed = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    return null;
  }
  if (parsed is! Map<String, dynamic>) {
    throw const InvalidInviteException('invite JSON must be an object');
  }
  return InvitePayload.fromJson(parsed);
}
