import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/build_flavor.dart';
import 'package:whotook/core/party_pass/party_pass_controller.dart';
import 'package:whotook/core/party_pass/party_pass_repository.dart';
import 'package:whotook/core/party_pass/purchase_service.dart';
import 'package:whotook/core/party_pass/turn_relay_client.dart';

class _OfficialPartyPassController extends PartyPassController {
  @override
  bool get fossIncludedBuild => false;
}

class _FakePurchaseService implements PartyPassPurchaseService {
  final StreamController<PartyPassPurchaseEvent> _events =
      StreamController<PartyPassPurchaseEvent>.broadcast();
  int buys = 0;
  int restores = 0;

  PartyPassCredential get _credential => PartyPassCredential(
    platform: StorePlatform.google,
    productId: kPartyPassProductId,
    verificationToken: 'google-play-purchase-token',
    savedAtUtc: DateTime.utc(2026, 11, 16),
  );

  @override
  Stream<PartyPassPurchaseEvent> get events => _events.stream;

  @override
  String? get priceLabel => '€2.99';

  @override
  bool get available => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<PartyPassPurchaseEvent> buy() async {
    buys += 1;
    final event = PartyPassPurchaseEvent(
      status: PartyPassPurchaseStatus.purchased,
      credential: _credential,
    );
    _events.add(event);
    return event;
  }

  @override
  Future<PartyPassPurchaseEvent> restore() async {
    restores += 1;
    return PartyPassPurchaseEvent(
      status: PartyPassPurchaseStatus.restored,
      credential: _credential,
    );
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
}

class _DelayedVerifyRelayClient extends _FakeRelayClient {
  final Completer<void> started = Completer<void>();
  final Completer<TurnRelayVerification> gate =
      Completer<TurnRelayVerification>();

  @override
  Future<TurnRelayVerification> verify({
    required String baseUrl,
    required PartyPassCredential credential,
  }) {
    verifies += 1;
    if (!started.isCompleted) started.complete();
    return gate.future;
  }
}

class _FakeRelayClient extends TurnRelayClient {
  int fetches = 0;
  int verifies = 0;

  @override
  Future<TurnRelayGrant> fetchCredentials({
    required String baseUrl,
    required PartyPassCredential credential,
  }) async {
    fetches += 1;
    return TurnRelayGrant(
      iceServers: const <RelayIceServer>[
        RelayIceServer(
          urls: <String>['turn:turn.example:3478'],
          username: 'expiry:pp_hash',
          credential: 'secret',
        ),
      ],
      ttlSeconds: 2700,
      expiresAtUtc: DateTime.now().toUtc().add(const Duration(minutes: 40)),
      remainingMatchesToday: 14,
      dailyLimit: 15,
    );
  }

  @override
  Future<TurnRelayVerification> verify({
    required String baseUrl,
    required PartyPassCredential credential,
  }) async {
    verifies += 1;
    return const TurnRelayVerification(
      valid: true,
      remainingMatchesToday: 15,
      dailyLimit: 15,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('a FOSS build includes cosmetics and has no official relay', () async {
    if (!BuildFlavor.foss) return;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = await container.read(partyPassProvider.future);
    expect(state.active, isTrue);
    expect(state.fossIncluded, isTrue);

    final attempt = await container
        .read(partyPassProvider.notifier)
        .relayAttempt();
    expect(attempt.grant, isNull);
    expect(attempt.passActive, isFalse);
  });

  test('an empty install starts locked and unlocks on purchase', () async {
    final purchase = _FakePurchaseService();
    final relay = _FakeRelayClient();
    final container = ProviderContainer(
      overrides: [
        partyPassProvider.overrideWith(_OfficialPartyPassController.new),
        partyPassPurchaseServiceProvider.overrideWithValue(purchase),
        turnRelayClientProvider.overrideWithValue(relay),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(purchase.dispose);

    final initial = await container.read(partyPassProvider.future);
    expect(initial.active, isFalse);
    expect(initial.canBuy, isTrue);

    await container.read(partyPassProvider.notifier).unlock();
    final unlocked = container.read(partyPassProvider).value!;
    expect(unlocked.active, isTrue);
    expect(unlocked.credential?.platform, StorePlatform.google);
    expect(purchase.buys, 1);

    final stored = await container.read(partyPassRepositoryProvider).load();
    expect(stored?.verificationToken, 'google-play-purchase-token');
  });

  test('restore recovers a purchase from another install', () async {
    final purchase = _FakePurchaseService();
    final relay = _FakeRelayClient();
    final container = ProviderContainer(
      overrides: [
        partyPassProvider.overrideWith(_OfficialPartyPassController.new),
        partyPassPurchaseServiceProvider.overrideWithValue(purchase),
        turnRelayClientProvider.overrideWithValue(relay),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(purchase.dispose);
    await container.read(partyPassProvider.future);

    await container.read(partyPassProvider.notifier).restore();
    final state = container.read(partyPassProvider).value!;
    expect(state.active, isTrue);
    expect(purchase.restores, 1);
  });

  test('a relay grant updates the allowance and is reused', () async {
    final purchase = _FakePurchaseService();
    final relay = _FakeRelayClient();
    final container = ProviderContainer(
      overrides: [
        partyPassProvider.overrideWith(_OfficialPartyPassController.new),
        partyPassPurchaseServiceProvider.overrideWithValue(purchase),
        turnRelayClientProvider.overrideWithValue(relay),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(purchase.dispose);
    await container.read(partyPassProvider.future);
    await container.read(partyPassProvider.notifier).unlock();

    final first = await container
        .read(partyPassProvider.notifier)
        .relayAttempt();
    expect(first.passActive, isTrue);
    expect(first.grant, isNotNull);
    expect(relay.fetches, 1);
    expect(container.read(partyPassProvider).value!.remainingMatchesToday, 14);

    final second = await container
        .read(partyPassProvider.notifier)
        .relayAttempt();
    expect(second.grant, isNotNull);
    expect(relay.fetches, 1, reason: 'the short-lived grant is reused');
  });

  test('a newer relay grant is not overwritten by a slow verify', () async {
    final purchase = _FakePurchaseService();
    final relay = _DelayedVerifyRelayClient();
    final container = ProviderContainer(
      overrides: [
        partyPassProvider.overrideWith(_OfficialPartyPassController.new),
        partyPassPurchaseServiceProvider.overrideWithValue(purchase),
        turnRelayClientProvider.overrideWithValue(relay),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(purchase.dispose);
    await container.read(partyPassProvider.future);
    await container.read(partyPassProvider.notifier).unlock();
    await relay.started.future;

    final attempt = await container
        .read(partyPassProvider.notifier)
        .relayAttempt();
    expect(attempt.grant, isNotNull);
    expect(container.read(partyPassProvider).value!.remainingMatchesToday, 14);

    relay.gate.complete(
      const TurnRelayVerification(
        valid: true,
        remainingMatchesToday: 15,
        dailyLimit: 15,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(partyPassProvider).value!.remainingMatchesToday, 14);
  });

  test(
    'verification reports the remaining allowance without spending it',
    () async {
      final purchase = _FakePurchaseService();
      final relay = _FakeRelayClient();
      final container = ProviderContainer(
        overrides: [
          partyPassProvider.overrideWith(_OfficialPartyPassController.new),
          partyPassPurchaseServiceProvider.overrideWithValue(purchase),
          turnRelayClientProvider.overrideWithValue(relay),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(purchase.dispose);
      await container.read(partyPassProvider.future);
      await container.read(partyPassProvider.notifier).unlock();

      final before = relay.verifies;
      await container.read(partyPassProvider.notifier).verify();
      expect(relay.verifies, before + 1);
      expect(
        container.read(partyPassProvider).value!.remainingMatchesToday,
        15,
      );
    },
  );
}
