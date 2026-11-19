import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/party_pass/party_pass_controller.dart';
import 'package:whotook/core/party_pass/party_pass_repository.dart';
import 'package:whotook/core/party_pass/party_pass_storage.dart';
import 'package:whotook/core/party_pass/purchase_service.dart';
import 'package:whotook/core/party_pass/turn_relay_client.dart';

class _PaddleFake implements PartyPassPurchaseService {
  _PaddleFake();

  final String validKey = 'WT-0000-0000-0000-0000-0000-0000-0000-0001';
  final StreamController<PartyPassPurchaseEvent> _events =
      StreamController<PartyPassPurchaseEvent>.broadcast();

  @override
  Stream<PartyPassPurchaseEvent> get events => _events.stream;

  @override
  String? get priceLabel => '€2.99';

  @override
  bool get available => true;

  @override
  PartyPassBillingKind get kind => PartyPassBillingKind.paddle;

  @override
  Future<void> initialize() async {}

  @override
  Future<PartyPassPurchaseEvent> buy() async {
    return PartyPassPurchaseEvent(
      status: PartyPassPurchaseStatus.purchased,
      credential: PartyPassCredential(
        platform: StorePlatform.paddle,
        productId: kPartyPassProductId,
        verificationToken: validKey,
        savedAtUtc: DateTime.utc(2026, 11, 19),
      ),
    );
  }

  @override
  Future<PartyPassPurchaseEvent> restore() async {
    return const PartyPassPurchaseEvent(
      status: PartyPassPurchaseStatus.error,
      code: 'restore_empty',
    );
  }

  @override
  Future<PartyPassPurchaseEvent> redeem(String licenseKey) async {
    return PartyPassPurchaseEvent(
      status: PartyPassPurchaseStatus.purchased,
      credential: PartyPassCredential(
        platform: StorePlatform.paddle,
        productId: kPartyPassProductId,
        verificationToken: licenseKey,
        savedAtUtc: DateTime.utc(2026, 11, 19),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
}

class _Relay extends TurnRelayClient {
  _Relay({this.valid = true, this.error});

  bool valid;
  TurnRelayException? error;
  int verifies = 0;

  @override
  Future<TurnRelayVerification> verify({
    required String baseUrl,
    required PartyPassCredential credential,
  }) async {
    verifies += 1;
    if (error != null) throw error!;
    return TurnRelayVerification(
      valid: valid,
      remainingMatchesToday: valid ? 15 : 0,
      dailyLimit: valid ? 15 : 0,
    );
  }

  @override
  Future<TurnRelayGrant> fetchCredentials({
    required String baseUrl,
    required PartyPassCredential credential,
  }) async {
    throw const TurnRelayException(TurnRelayErrorCode.network);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a valid Paddle license unlocks only after the server verifies it',
    () async {
      final purchase = _PaddleFake();
      final relay = _Relay();
      final repo = PartyPassRepository(storage: InMemoryPartyPassStorage());
      final container = ProviderContainer(
        overrides: [
          partyPassProvider.overrideWith(PartyPassController.new),
          partyPassPurchaseServiceProvider.overrideWithValue(purchase),
          turnRelayClientProvider.overrideWithValue(relay),
          partyPassRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(purchase.dispose);
      final initial = await container.read(partyPassProvider.future);
      expect(initial.billingKind, PartyPassBillingKind.paddle);

      await container
          .read(partyPassProvider.notifier)
          .redeem('WT-0000-0000-0000-0000-0000-0000-0000-0001');

      final state = container.read(partyPassProvider).value!;
      expect(state.active, isTrue);
      expect(state.credential?.platform, StorePlatform.paddle);
      expect(relay.verifies, greaterThanOrEqualTo(1));
      expect(await repo.load(), isNotNull);
    },
  );

  test('an invalid Paddle license does not unlock or persist', () async {
    final purchase = _PaddleFake();
    final relay = _Relay(valid: false);
    final repo = PartyPassRepository(storage: InMemoryPartyPassStorage());
    final container = ProviderContainer(
      overrides: [
        partyPassProvider.overrideWith(PartyPassController.new),
        partyPassPurchaseServiceProvider.overrideWithValue(purchase),
        turnRelayClientProvider.overrideWithValue(relay),
        partyPassRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(purchase.dispose);
    await container.read(partyPassProvider.future);

    await container.read(partyPassProvider.notifier).redeem('WT-BAD');

    final state = container.read(partyPassProvider).value!;
    expect(state.active, isFalse);
    expect(state.errorCode, 'invalid_license');
    expect(await repo.load(), isNull);
  });

  test('a definitive receipt rejection clears a stored pass', () async {
    final purchase = _PaddleFake();
    final relay = _Relay(
      error: const TurnRelayException(TurnRelayErrorCode.invalidReceipt),
    );
    final repo = PartyPassRepository(storage: InMemoryPartyPassStorage());
    await repo.save(
      PartyPassCredential(
        platform: StorePlatform.paddle,
        productId: kPartyPassProductId,
        verificationToken: 'WT-0000-0000-0000-0000-0000-0000-0000-0001',
        savedAtUtc: DateTime.utc(2026, 11, 19),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        partyPassProvider.overrideWith(PartyPassController.new),
        partyPassPurchaseServiceProvider.overrideWithValue(purchase),
        turnRelayClientProvider.overrideWithValue(relay),
        partyPassRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(purchase.dispose);

    final initial = await container.read(partyPassProvider.future);
    expect(initial.active, isTrue);

    await container.read(partyPassProvider.notifier).verify();

    final state = container.read(partyPassProvider).value!;
    expect(state.active, isFalse);
    expect(state.credential, isNull);
    expect(state.errorCode, 'pass_revoked');
    expect(await repo.load(), isNull);
  });

  test('a network failure keeps the stored pass for offline play', () async {
    final purchase = _PaddleFake();
    final relay = _Relay(
      error: const TurnRelayException(TurnRelayErrorCode.network),
    );
    final repo = PartyPassRepository(storage: InMemoryPartyPassStorage());
    final credential = PartyPassCredential(
      platform: StorePlatform.paddle,
      productId: kPartyPassProductId,
      verificationToken: 'WT-0000-0000-0000-0000-0000-0000-0000-0001',
      savedAtUtc: DateTime.utc(2026, 11, 19),
    );
    await repo.save(credential);
    final container = ProviderContainer(
      overrides: [
        partyPassProvider.overrideWith(PartyPassController.new),
        partyPassPurchaseServiceProvider.overrideWithValue(purchase),
        turnRelayClientProvider.overrideWithValue(relay),
        partyPassRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(purchase.dispose);

    await container.read(partyPassProvider.future);
    await container.read(partyPassProvider.notifier).verify();

    final state = container.read(partyPassProvider).value!;
    expect(state.active, isTrue);
    expect(state.credential?.verificationToken, credential.verificationToken);
    expect(state.relayErrorCode, TurnRelayErrorCode.network);
  });
}
