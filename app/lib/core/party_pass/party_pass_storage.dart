import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The small key/value seam behind [PartyPassRepository]. Store credentials go
/// to Keychain/Keystore first; preferences are only a fallback for platforms
/// or test runners where secure storage is unavailable.
abstract class PartyPassStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class SecurePartyPassStorage implements PartyPassStorage {
  SecurePartyPassStorage({
    FlutterSecureStorage? secure,
    SharedPreferencesAsync? fallback,
  }) : _secure = secure ?? const FlutterSecureStorage(),
       _fallback = fallback ?? SharedPreferencesAsync();

  final FlutterSecureStorage _secure;
  final SharedPreferencesAsync _fallback;

  @override
  Future<String?> read(String key) async {
    try {
      final value = await _secure.read(key: key);
      if (value != null && value.isNotEmpty) return value;
    } on Object {
      // Missing plugin (tests, unsupported desktop) falls through.
    }
    try {
      final value = await _fallback.getString(key);
      if (value != null && value.isNotEmpty) {
        // Migrate an older plaintext value into secure storage when possible.
        try {
          await _secure.write(key: key, value: value);
          await _fallback.remove(key);
        } on Object {
          // Keep the fallback value rather than losing the pass.
        }
        return value;
      }
    } on Object {
      // No fallback store either.
    }
    return null;
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _secure.write(key: key, value: value);
      try {
        await _fallback.remove(key);
      } on Object {
        // Ignore cleanup failure; the secure copy is authoritative.
      }
      return;
    } on Object {
      // Fall through to preferences so a device without a usable keystore can
      // still remember the pass.
    }
    await _fallback.setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _secure.delete(key: key);
    } on Object {
      // Keep going; the fallback may still hold a copy.
    }
    try {
      await _fallback.remove(key);
    } on Object {
      // Nothing else to clear.
    }
  }
}

class InMemoryPartyPassStorage implements PartyPassStorage {
  InMemoryPartyPassStorage([Map<String, String>? values])
    : _values = values ?? <String, String>{};

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
