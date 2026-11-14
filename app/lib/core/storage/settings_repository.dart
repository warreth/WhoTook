import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Default signaling endpoint. Self-hosters override it in Settings or by
/// passing [SettingsRepository.defaultSignalingUrl].
const String kDefaultSignalingUrl = 'https://signal.whotook.party';

const String kSettingsStorageKey = 'whotook.settings.v1';

class SettingsRepository {
  SettingsRepository({
    SharedPreferencesAsync? preferences,
    this.defaultSignalingUrl = kDefaultSignalingUrl,
  }) : _prefs = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;
  final String defaultSignalingUrl;

  Future<AppSettings> load() async {
    final raw = await _prefs.getString(kSettingsStorageKey);
    if (raw == null || raw.isEmpty) {
      return const AppSettings();
    }
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) {
        return const AppSettings();
      }
      return AppSettings.fromJson(parsed);
    } on FormatException {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) {
    return _prefs.setString(kSettingsStorageKey, jsonEncode(settings.toJson()));
  }

  Future<void> clear() => _prefs.remove(kSettingsStorageKey);

  /// Signaling URL actually used for online play: the custom one when set.
  String resolveSignalingUrl(AppSettings settings) {
    final custom = settings.customSignalingUrl?.trim();
    if (custom == null || custom.isEmpty) {
      return defaultSignalingUrl;
    }
    return custom;
  }
}
