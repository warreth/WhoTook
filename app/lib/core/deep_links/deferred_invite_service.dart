import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../distribution.dart';
import '../playtest_config.dart';
import '../qr/invite_codec.dart';

/// Finds an invite that arrived before the app could open a deep link.
///
/// Android reads the Play install referrer once and keeps a local marker so the
/// same referrer cannot trigger a second join. iOS has no install referrer, so
/// the invite page copies a signed invite to the clipboard and the app reads it
/// on the next store launch. Both paths only run in store builds, never in the
/// FFOSS or web build, and never during the browser playtest.
class DeferredInviteService {
  DeferredInviteService({
    MethodChannel? channel,
    SharedPreferencesAsync? preferences,
    Future<String?> Function()? readClipboard,
  }) : _channel = channel ?? const MethodChannel(kInstallReferrerChannel),
       _prefs = preferences ?? SharedPreferencesAsync(),
       _readClipboard = readClipboard ?? _clipboardText;

  static final DeferredInviteService instance = DeferredInviteService();

  static const String kInstallReferrerChannel = 'app.whotook/install_referrer';
  static const String kStorageKey = 'whotook.deferred_invite.v1';
  static const String kIosClipboardCheckedKey =
      'whotook.ios_clipboard_checked.v1';

  final MethodChannel _channel;
  final SharedPreferencesAsync _prefs;
  final Future<String?> Function() _readClipboard;

  /// Returns a canonical invite URL at most once per stored invite.
  Future<String?> takePendingInvite() async {
    if (kIsWeb || PlaytestConfig.enabled) return null;

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (kFfossBuild || !isStoreEnvironment) return null;
      final referrer = await _installReferrer();
      final invite = parseReferrer(referrer);
      if (invite != null && await _markConsumed(invite)) return invite;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS &&
        appDistribution == AppDistribution.store &&
        !isSideloadedIos) {
      final alreadyChecked =
          await _prefs.getBool(kIosClipboardCheckedKey) ?? false;
      if (alreadyChecked) return null;
      await _prefs.setBool(kIosClipboardCheckedKey, true);
      final text = await _readClipboard();
      final invite = parseClipboard(text);
      if (invite != null && await _markConsumed(invite)) return invite;
    }
    return null;
  }

  Future<String?> _installReferrer() async {
    try {
      return await _channel.invokeMethod<String>('getInstallReferrer');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> _markConsumed(String invite) async {
    final last = await _prefs.getString(kStorageKey);
    if (last == invite) return false;
    await _prefs.setString(kStorageKey, invite);
    return true;
  }

  /// Visible so the one-shot behavior can be tested without a platform.
  @visibleForTesting
  Future<bool> markConsumed(String invite) => _markConsumed(invite);

  static Future<String?> _clipboardText() async {
    try {
      return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } on PlatformException {
      return null;
    }
  }

  /// Parses `room=<payload>` from a Play install referrer, including the
  /// URL-encoded form. A full invite URL is accepted as well.
  @visibleForTesting
  static String? parseReferrer(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;

    String? candidate;
    try {
      final params = Uri.splitQueryString(text);
      candidate = params['room'] ?? params['invite'];
    } on FormatException {
      candidate = null;
    }
    candidate ??= RegExp(r'(?:^|&)(?:room|invite)=([^&]+)')
        .firstMatch(text)
        ?.group(1);
    if (candidate != null) {
      final value = candidate;
      String decoded;
      try {
        decoded = Uri.decodeComponent(value);
      } on FormatException {
        // Keep the undecoded value; validation below will reject it if bad.
        decoded = value;
      }
      final canonical = _canonical(decoded);
      if (canonical != null) return canonical;
    }
    return _canonical(text);
  }

  /// Parses the clipboard format written by the invite page. The prefix is
  /// optional so a plain invite URL copied from a chat also works.
  @visibleForTesting
  static String? parseClipboard(String? raw) {
    var text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    const prefix = 'whotook-invite:';
    if (text.toLowerCase().startsWith(prefix)) {
      text = text.substring(prefix.length).trim();
    }
    if (text.startsWith('#')) text = text.substring(1);
    return _canonical(text);
  }

  static String? _canonical(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    try {
      return encodeInviteUrl(tryParseInvite(text));
    } on InvalidInviteException {
      return null;
    }
  }
}
