import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/party_pass/party_pass_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('saves, loads and clears a verified credential', () async {
    final repo = PartyPassRepository();
    expect(await repo.load(), isNull);

    final credential = PartyPassCredential(
      platform: StorePlatform.apple,
      productId: kPartyPassProductId,
      verificationToken: 'signed.jws.token',
      savedAtUtc: DateTime.utc(2026, 11, 16, 12),
    );
    await repo.save(credential);

    final loaded = await repo.load();
    expect(loaded, isNotNull);
    expect(loaded!.platform, StorePlatform.apple);
    expect(loaded.productId, kPartyPassProductId);
    expect(loaded.verificationToken, 'signed.jws.token');
    expect(loaded.savedAtUtc, DateTime.utc(2026, 11, 16, 12));

    await repo.clear();
    expect(await repo.load(), isNull);
  });

  test('ignores a corrupt stored payload', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(kPartyPassStorageKey, '{"platform":"ios"}');
    expect(await PartyPassRepository(preferences: prefs).load(), isNull);

    await prefs.setString(kPartyPassStorageKey, 'not json');
    expect(await PartyPassRepository(preferences: prefs).load(), isNull);
  });
}
