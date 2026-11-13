import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/storage/settings_repository.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('the default signaling url is the documented one', () {
    expect(kDefaultSignalingUrl, 'https://whotook-signaling.whotook.app');
  });

  test('loads defaults when nothing was stored', () async {
    final repo = SettingsRepository();
    final settings = await repo.load();
    expect(settings.nickname, isEmpty);
    expect(settings.excludedAlbumIds, isEmpty);
    expect(settings.themePreference, ThemePreference.system);
    expect(settings.onboardingCompleted, isFalse);
    expect(settings.customSignalingUrl, isNull);
  });

  test('saves and reloads every field', () async {
    final repo = SettingsRepository();
    const settings = AppSettings(
      nickname: 'Sam',
      avatarColorIndex: 3,
      excludedAlbumIds: <String>{'Screenshots', 'WhatsApp Images'},
      themePreference: ThemePreference.dark,
      onboardingCompleted: true,
      customSignalingUrl: 'wss://signal.example.org',
      customTurnUrl: 'turn:turn.example.org:3478',
      customTurnUsername: 'user',
      customTurnCredential: 'pass',
    );
    await repo.save(settings);

    final loaded = await SettingsRepository().load();
    expect(loaded.nickname, 'Sam');
    expect(loaded.avatarColorIndex, 3);
    expect(loaded.excludedAlbumIds, <String>{'Screenshots', 'WhatsApp Images'});
    expect(loaded.themePreference, ThemePreference.dark);
    expect(loaded.onboardingCompleted, isTrue);
    expect(loaded.customSignalingUrl, 'wss://signal.example.org');
    expect(loaded.customTurnUrl, 'turn:turn.example.org:3478');
    expect(loaded.customTurnUsername, 'user');
    expect(loaded.customTurnCredential, 'pass');
  });

  test('survives a corrupted store by falling back to defaults', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(kSettingsStorageKey, '{not json');
    final settings = await SettingsRepository(preferences: prefs).load();
    expect(settings.nickname, isEmpty);
    expect(settings.themePreference, ThemePreference.system);
  });

  test('ignores an unknown theme preference', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(
      kSettingsStorageKey,
      '{"nickname":"A","themePreference":"neon"}',
    );
    final settings = await SettingsRepository(preferences: prefs).load();
    expect(settings.themePreference, ThemePreference.system);
  });

  test('resolveSignalingUrl prefers the custom url', () {
    final repo = SettingsRepository();
    expect(repo.resolveSignalingUrl(const AppSettings()), kDefaultSignalingUrl);
    expect(
      repo.resolveSignalingUrl(
        const AppSettings(customSignalingUrl: '  wss://mine.example  '),
      ),
      'wss://mine.example',
    );
    expect(
      repo.resolveSignalingUrl(const AppSettings(customSignalingUrl: '   ')),
      kDefaultSignalingUrl,
    );
    expect(
      SettingsRepository(defaultSignalingUrl: 'wss://self.host')
          .resolveSignalingUrl(const AppSettings()),
      'wss://self.host',
    );
  });

  test('clear removes the stored settings', () async {
    final repo = SettingsRepository();
    await repo.save(const AppSettings(nickname: 'Gone'));
    await repo.clear();
    expect((await repo.load()).nickname, isEmpty);
  });

  test('copyWith can clear the custom endpoints', () {
    const settings = AppSettings(
      customSignalingUrl: 'wss://a',
      customTurnUrl: 'turn:b',
      customTurnUsername: 'u',
      customTurnCredential: 'c',
    );
    final cleared = settings.copyWith(
      clearCustomSignalingUrl: true,
      clearTurn: true,
    );
    expect(cleared.customSignalingUrl, isNull);
    expect(cleared.customTurnUrl, isNull);
    expect(cleared.customTurnUsername, isNull);
    expect(cleared.customTurnCredential, isNull);
  });
}
