import 'dart:convert';

import 'party_pass_storage.dart';

/// Where the pass came from. The wire value is what the private server expects.
enum StorePlatform {
  apple('ios'),
  google('android'),
  paddle('paddle');

  const StorePlatform(this.wireValue);

  final String wireValue;

  static StorePlatform? fromWire(String? value) {
    for (final platform in StorePlatform.values) {
      if (platform.wireValue == value) return platform;
    }
    return null;
  }
}

/// The cryptographic payload from the store, kept only after a successful
/// local purchase. It is a re-verifiable receipt, not a bearer token for an
/// account, and it is never written to logs.
class PartyPassCredential {
  const PartyPassCredential({
    required this.platform,
    required this.productId,
    required this.verificationToken,
    required this.savedAtUtc,
  });

  final StorePlatform platform;
  final String productId;
  final String verificationToken;
  final DateTime savedAtUtc;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'platform': platform.wireValue,
    'productId': productId,
    'verificationToken': verificationToken,
    'savedAtUtc': savedAtUtc.toUtc().toIso8601String(),
  };

  factory PartyPassCredential.fromJson(Map<String, dynamic> json) {
    final platform = StorePlatform.fromWire(json['platform'] as String?);
    final productId = json['productId'] as String?;
    final token = json['verificationToken'] as String?;
    final savedAt = DateTime.tryParse(json['savedAtUtc'] as String? ?? '');
    if (platform == null ||
        productId == null ||
        productId.isEmpty ||
        token == null ||
        token.isEmpty ||
        savedAt == null) {
      throw const FormatException('incomplete party pass credential');
    }
    return PartyPassCredential(
      platform: platform,
      productId: productId,
      verificationToken: token,
      savedAtUtc: savedAt.toUtc(),
    );
  }
}

const String kPartyPassStorageKey = 'whotook.party_pass.v1';
const String kPartyPassPendingRefKey = 'whotook.party_pass.pending.v1';
const String kPartyPassProductId = 'whotook_party_pass';

/// Local, instant unlock state. The relay still verifies the credential on
/// every credential request, so a modified local flag only changes cosmetics.
class PartyPassRepository {
  PartyPassRepository({PartyPassStorage? storage})
    : _storage = storage ?? SecurePartyPassStorage();

  final PartyPassStorage _storage;

  Future<PartyPassCredential?> load() async {
    final raw = await _storage.read(kPartyPassStorageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) return null;
      return PartyPassCredential.fromJson(parsed);
    } on Object {
      // A truncated or hand-edited preference must never crash startup.
      return null;
    }
  }

  Future<void> save(PartyPassCredential credential) =>
      _storage.write(kPartyPassStorageKey, jsonEncode(credential.toJson()));

  Future<void> clear() => _storage.delete(kPartyPassStorageKey);

  /// A random lookup secret for an in-flight Paddle checkout. It is not the
  /// license itself; the server only stores its hash.
  Future<String?> loadPendingRef() async {
    final value = await _storage.read(kPartyPassPendingRefKey);
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> savePendingRef(String ref) =>
      _storage.write(kPartyPassPendingRefKey, ref);

  Future<void> clearPendingRef() => _storage.delete(kPartyPassPendingRefKey);
}
