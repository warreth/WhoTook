import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../build_flavor.dart';
import 'party_pass_repository.dart';
import 'purchase_service.dart';
import 'turn_relay_client.dart';

class PartyPassState {
  const PartyPassState({
    this.active = false,
    this.fossIncluded = false,
    this.billingAvailable = false,
    this.loading = true,
    this.purchasing = false,
    this.credential,
    this.priceLabel,
    this.errorCode,
    this.relayErrorCode,
    this.remainingMatchesToday = 15,
    this.dailyLimit = 15,
  });

  final bool active;

  /// FOSS builds include every cosmetic feature and never contact the store
  /// or the official relay.
  final bool fossIncluded;
  final bool billingAvailable;
  final bool loading;
  final bool purchasing;
  final PartyPassCredential? credential;
  final String? priceLabel;
  final String? errorCode;
  final String? relayErrorCode;
  final int remainingMatchesToday;
  final int dailyLimit;

  bool get canBuy => !fossIncluded && !active;

  String get displayPrice => priceLabel ?? '€2.99';

  PartyPassState copyWith({
    bool? active,
    bool? fossIncluded,
    bool? billingAvailable,
    bool? loading,
    bool? purchasing,
    PartyPassCredential? credential,
    String? priceLabel,
    String? errorCode,
    String? relayErrorCode,
    int? remainingMatchesToday,
    int? dailyLimit,
    bool clearError = false,
    bool clearRelayError = false,
  }) => PartyPassState(
    active: active ?? this.active,
    fossIncluded: fossIncluded ?? this.fossIncluded,
    billingAvailable: billingAvailable ?? this.billingAvailable,
    loading: loading ?? this.loading,
    purchasing: purchasing ?? this.purchasing,
    credential: credential ?? this.credential,
    priceLabel: priceLabel ?? this.priceLabel,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
    relayErrorCode: clearRelayError
        ? null
        : (relayErrorCode ?? this.relayErrorCode),
    remainingMatchesToday: remainingMatchesToday ?? this.remainingMatchesToday,
    dailyLimit: dailyLimit ?? this.dailyLimit,
  );
}

class PartyPassController extends AsyncNotifier<PartyPassState> {
  /// Override in tests to exercise the official purchase path from a FOSS
  /// test runner. Production always follows the compile-time flavor.
  bool get fossIncludedBuild => BuildFlavor.foss;

  StreamSubscription<PartyPassPurchaseEvent>? _subscription;
  TurnRelayGrant? _cachedGrant;
  String? _lastProcessedToken;
  bool _disposed = false;

  @override
  Future<PartyPassState> build() async {
    final repo = ref.watch(partyPassRepositoryProvider);
    final service = ref.watch(partyPassPurchaseServiceProvider);
    final stored = await repo.load();
    ref.onDispose(() {
      _disposed = true;
      unawaited(_subscription?.cancel());
    });

    if (fossIncludedBuild) {
      return const PartyPassState(
        active: true,
        fossIncluded: true,
        loading: false,
      );
    }

    _subscription = service.events.listen(_onPurchaseEvent);
    // Billing setup never blocks the first frame. A missing store plugin or a
    // slow network must not keep the lobby spinner alive.
    unawaited(_initializeBilling(service));
    return PartyPassState(
      active: stored != null,
      credential: stored,
      billingAvailable: service.available,
      priceLabel: service.priceLabel,
      loading: false,
    );
  }

  Future<void> _initializeBilling(PartyPassPurchaseService service) async {
    try {
      await service.initialize();
    } on Object {
      // Offline or a sideloaded store build: cosmetics stay local and the
      // relay still requires a server-verifiable receipt.
    }
    if (_disposed) return;
    final current = state.value ?? const PartyPassState();
    state = AsyncData(
      current.copyWith(
        billingAvailable: service.available,
        priceLabel: service.priceLabel,
        loading: false,
      ),
    );
  }

  Future<void> _onPurchaseEvent(PartyPassPurchaseEvent event) async {
    if (_disposed) return;
    final current = state.value ?? const PartyPassState();
    if (!event.isSuccess || event.credential == null) return;
    final credential = event.credential!;
    if (_lastProcessedToken == credential.verificationToken) return;
    _lastProcessedToken = credential.verificationToken;
    _cachedGrant = null;
    await ref.read(partyPassRepositoryProvider).save(credential);
    if (_disposed) return;
    state = AsyncData(
      current.copyWith(
        active: true,
        credential: credential,
        purchasing: false,
        billingAvailable: true,
        clearError: true,
      ),
    );
    unawaited(verify());
  }

  Future<void> unlock() async {
    final current = state.value ?? const PartyPassState();
    if (current.fossIncluded || current.purchasing) return;
    state = AsyncData(current.copyWith(purchasing: true, clearError: true));
    final event = await ref.read(partyPassPurchaseServiceProvider).buy();
    if (_disposed) return;
    await _applyPurchaseEvent(event);
  }

  Future<void> restore() async {
    final current = state.value ?? const PartyPassState();
    if (current.fossIncluded || current.purchasing) return;
    state = AsyncData(current.copyWith(purchasing: true, clearError: true));
    final event = await ref.read(partyPassPurchaseServiceProvider).restore();
    if (_disposed) return;
    await _applyPurchaseEvent(event);
  }

  Future<void> _applyPurchaseEvent(PartyPassPurchaseEvent event) async {
    final current = state.value ?? const PartyPassState();
    if (event.isSuccess && event.credential != null) {
      await _onPurchaseEvent(event);
      return;
    }
    final code = switch (event.status) {
      PartyPassPurchaseStatus.canceled => 'purchase_canceled',
      PartyPassPurchaseStatus.pending => 'purchase_pending',
      _ => event.code ?? 'purchase_failed',
    };
    state = AsyncData(current.copyWith(purchasing: false, errorCode: code));
  }

  /// Verifies the receipt without spending a relay match. Called once after a
  /// purchase or restore, and whenever the pass sheet opens.
  Future<void> verify() async {
    if (fossIncludedBuild || _disposed) return;
    final current = state.value ?? const PartyPassState();
    final credential = current.credential;
    if (credential == null) return;
    try {
      final result = await ref
          .read(turnRelayClientProvider)
          .verify(
            baseUrl: TurnRelayClient.defaultBaseUrl,
            credential: credential,
          );
      if (_disposed) return;
      if (!result.valid) {
        state = AsyncData(
          current.copyWith(
            relayErrorCode: 'invalid_receipt',
            remainingMatchesToday: 0,
          ),
        );
        return;
      }
      state = AsyncData(
        current.copyWith(
          remainingMatchesToday: result.remainingMatchesToday,
          dailyLimit: result.dailyLimit,
          clearRelayError: true,
        ),
      );
    } on TurnRelayException catch (error) {
      if (_disposed) return;
      state = AsyncData(current.copyWith(relayErrorCode: error.code));
    }
  }

  /// Called by the transport at ICE setup time. A null grant lets direct P2P
  /// get its chance; [TurnRelayAttempt.passActive] drives the failure prompt.
  Future<TurnRelayAttempt> relayAttempt() async {
    if (fossIncludedBuild || _disposed) return const TurnRelayAttempt();
    final current = state.value ?? const PartyPassState();
    final credential = current.credential;
    if (!current.active || credential == null) {
      return const TurnRelayAttempt(passActive: false);
    }
    final cached = _cachedGrant;
    if (cached != null &&
        cached.expiresAtUtc.isAfter(
          DateTime.now().toUtc().add(const Duration(minutes: 2)),
        )) {
      return TurnRelayAttempt(grant: cached, passActive: true);
    }
    try {
      final grant = await ref
          .read(turnRelayClientProvider)
          .fetchCredentials(
            baseUrl: TurnRelayClient.defaultBaseUrl,
            credential: credential,
          );
      _cachedGrant = grant;
      if (!_disposed) {
        state = AsyncData(
          current.copyWith(
            remainingMatchesToday: grant.remainingMatchesToday,
            dailyLimit: grant.dailyLimit,
            clearRelayError: true,
          ),
        );
      }
      return TurnRelayAttempt(grant: grant, passActive: true);
    } on TurnRelayException catch (error) {
      _cachedGrant = null;
      if (!_disposed) {
        state = AsyncData(
          current.copyWith(
            relayErrorCode: error.code,
            remainingMatchesToday:
                error.remainingMatchesToday ?? current.remainingMatchesToday,
          ),
        );
      }
      return TurnRelayAttempt(passActive: true, errorCode: error.code);
    }
  }

  void dismissError() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearError: true));
  }

  void dismissRelayError() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearRelayError: true));
  }
}

final partyPassRepositoryProvider = Provider<PartyPassRepository>(
  (ref) => PartyPassRepository(),
);

final partyPassPurchaseServiceProvider = Provider<PartyPassPurchaseService>((
  ref,
) {
  final service = BuildFlavor.foss
      ? DisabledPurchaseService()
      : StorePartyPassPurchaseService();
  ref.onDispose(service.dispose);
  return service;
});

final turnRelayClientProvider = Provider<TurnRelayClient>((ref) {
  final client = TurnRelayClient();
  ref.onDispose(client.close);
  return client;
});

final partyPassProvider =
    AsyncNotifierProvider<PartyPassController, PartyPassState>(
      PartyPassController.new,
    );
