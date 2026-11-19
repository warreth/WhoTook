import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/party_pass/party_pass_repository.dart';
import 'package:whotook/core/party_pass/party_pass_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saves, loads and clears a verified credential', () async {
    final repo = PartyPassRepository(storage: InMemoryPartyPassStorage());
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

  test('keeps Paddle pending references out of the credential slot', () async {
    final storage = InMemoryPartyPassStorage();
    final repo = PartyPassRepository(storage: storage);
    await repo.savePendingRef('ref-0123456789abcdef0123456789abcdef');

    expect(await repo.loadPendingRef(), 'ref-0123456789abcdef0123456789abcdef');
    expect(await repo.load(), isNull);

    await repo.clearPendingRef();
    expect(await repo.loadPendingRef(), isNull);
  });

  test('ignores a corrupt stored payload', () async {
    final storage = InMemoryPartyPassStorage(<String, String>{
      kPartyPassStorageKey: '{"platform":"ios"}',
    });
    expect(await PartyPassRepository(storage: storage).load(), isNull);

    await storage.write(kPartyPassStorageKey, 'not json');
    expect(await PartyPassRepository(storage: storage).load(), isNull);
  });
}
