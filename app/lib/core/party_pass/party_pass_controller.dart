import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../distribution.dart';
import 'party_pass_repository.dart';
import 'purchase_service.dart';
import 'purchase_service_factory.dart';
import 'turn_relay_client.dart';

class PartyPassState {
  const PartyPassState({
    this.active = false,
    this.billingAvailable = false,
    this.billingReady = true,
    this.billingKind = PartyPassBillingKind.store,
    this.loading = true,
    this.purchasing = false,
    this.credential,
    this.priceLabel,
    this.errorCode,
    this.relayErrorCode,
    this.relayRetryAtUtc,
    this.remainingMatchesToday = 15,
    this.dailyLimit = 15,
  });

  final bool active;

  final bool billingAvailable;

  /// Which purchase surface this build may show. Store builds never expose a
  /// direct/Paddle link; direct builds never show a store button.
  final PartyPassBillingKind billingKind;

  /// False until the billing connection has been checked at least once. Keeps
  /// the purchase sheet from claiming the store is missing during startup.
  final bool billingReady;
  final bool loading;
  final bool purchasing;
  final PartyPassCredential? credential;
  final String? priceLabel;
  final String? errorCode;
  final String? relayErrorCode;
  final DateTime? relayRetryAtUtc;
  final int remainingMatchesToday;
  final int dailyLimit;

  bool get canBuy => !active;

  String get displayPrice => priceLabel ?? '€2.99';

  PartyPassState copyWith({
    bool? active,
    bool? billingAvailable,
    bool? billingReady,
    PartyPassBillingKind? billingKind,
    bool? loading,
    bool? purchasing,
    PartyPassCredential? credential,
    String? priceLabel,
    String? errorCode,
    String? relayErrorCode,
    DateTime? relayRetryAtUtc,
    int? remainingMatchesToday,
    int? dailyLimit,
    bool clearCredential = false,
    bool clearError = false,
    bool clearRelayError = false,
    bool clearRelayRetry = false,
  }) => PartyPassState(
    active: active ?? this.active,
    billingAvailable: billingAvailable ?? this.billingAvailable,
    billingReady: billingReady ?? this.billingReady,
    billingKind: billingKind ?? this.billingKind,
    loading: loading ?? this.loading,
    purchasing: purchasing ?? this.purchasing,
    credential: clearCredential ? null : (credential ?? this.credential),
    priceLabel: priceLabel ?? this.priceLabel,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
    relayErrorCode: clearRelayError
        ? null
        : (relayErrorCode ?? this.relayErrorCode),
    relayRetryAtUtc: clearRelayError || clearRelayRetry
        ? null
        : (relayRetryAtUtc ?? this.relayRetryAtUtc),
    remainingMatchesToday: remainingMatchesToday ?? this.remainingMatchesToday,
    dailyLimit: dailyLimit ?? this.dailyLimit,
  );
}

class PartyPassController extends AsyncNotifier<PartyPassState> {
  StreamSubscription<PartyPassPurchaseEvent>? _subscription;
  TurnRelayGrant? _cachedGrant;
  String? _lastProcessedToken;
  Future<void> _credentialLock = Future<void>.value();
  int _quotaRequestId = 0;
  int _appliedQuotaRequestId = 0;
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

    _subscription = service.events.listen(_onPurchaseEvent);
    // Billing setup never blocks the first frame. A missing store plugin or a
    // slow network must not keep the lobby spinner alive.
    unawaited(_initializeBilling(service, verifyStored: stored != null));
    return PartyPassState(
      active: stored != null,
      credential: stored,
      billingAvailable: service.available,
      billingReady: false,
      billingKind: service.kind,
      priceLabel: service.priceLabel,
      loading: false,
    );
  }

  Future<void> _initializeBilling(
    PartyPassPurchaseService service, {
    required bool verifyStored,
  }) async {
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
        billingReady: true,
        billingKind: service.kind,
        priceLabel: service.priceLabel,
        loading: false,
      ),
    );
    // A stored receipt is trusted for the first frame so an offline party
    // still gets its cosmetics. This check revokes it when the store says the
    // purchase is no longer valid.
    if (verifyStored) unawaited(verify());
  }

  Future<void> _onPurchaseEvent(PartyPassPurchaseEvent event) {
    if (_disposed || !event.isSuccess || event.credential == null) {
      return Future<void>.value();
    }
    final credential = event.credential!;
    if (_lastProcessedToken == credential.verificationToken) {
      return Future<void>.value();
    }
    // The store stream and the awaited buy() result can deliver the same
    // purchase. Serialize acceptance so the second event waits for the first
    // instead of returning while the state is still locked.
    final result = _credentialLock.then((_) async {
      if (_disposed || _lastProcessedToken == credential.verificationToken) {
        return;
      }
      final current = state.value ?? const PartyPassState();
      _cachedGrant = null;
      try {
        await ref.read(partyPassRepositoryProvider).save(credential);
      } on Object {
        if (_disposed) return;
        final latest = state.value ?? current;
        state = AsyncData(
          latest.copyWith(purchasing: false, errorCode: 'storage_error'),
        );
        return;
      }
      if (_disposed) return;
      _lastProcessedToken = credential.verificationToken;
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(
          active: true,
          credential: credential,
          purchasing: false,
          billingAvailable: true,
          clearError: true,
        ),
      );
      unawaited(verify());
    });
    _credentialLock = result.catchError((Object _) {});
    return result;
  }

  Future<void> unlock() async {
    final current = state.value ?? const PartyPassState();
    if (current.purchasing) return;
    state = AsyncData(current.copyWith(purchasing: true, clearError: true));
    final event = await ref.read(partyPassPurchaseServiceProvider).buy();
    if (_disposed) return;
    await _applyPurchaseEvent(event);
  }

  Future<void> restore() async {
    final current = state.value ?? const PartyPassState();
    if (current.purchasing) return;
    state = AsyncData(current.copyWith(purchasing: true, clearError: true));
    final event = await ref.read(partyPassPurchaseServiceProvider).restore();
    if (_disposed) return;
    await _applyPurchaseEvent(event);
  }

  /// Redeems a Paddle license key typed by the user. The key is verified with
  /// the server before it is stored, so a typo never unlocks cosmetics.
  Future<void> redeem(String licenseKey) async {
    final current = state.value ?? const PartyPassState();
    if (current.purchasing) return;
    state = AsyncData(current.copyWith(purchasing: true, clearError: true));
    final event = await ref
        .read(partyPassPurchaseServiceProvider)
        .redeem(licenseKey);
    if (_disposed) return;
    if (!event.isSuccess || event.credential == null) {
      await _applyPurchaseEvent(event);
      return;
    }
    final credential = event.credential!;
    try {
      final result = await ref
          .read(turnRelayClientProvider)
          .verify(
            baseUrl: TurnRelayClient.defaultBaseUrl,
            credential: credential,
          );
      if (_disposed) return;
      if (!result.valid) {
        final latest = state.value ?? current;
        state = AsyncData(
          latest.copyWith(purchasing: false, errorCode: 'invalid_license'),
        );
        return;
      }
    } on TurnRelayException catch (error) {
      if (_disposed) return;
      final latest = state.value ?? current;
      final code = switch (error.code) {
        TurnRelayErrorCode.invalidReceipt ||
        TurnRelayErrorCode.productMismatch => 'invalid_license',
        TurnRelayErrorCode.rateLimited ||
        TurnRelayErrorCode.fairUseLimit => 'rate_limited',
        _ => 'network_error',
      };
      state = AsyncData(latest.copyWith(purchasing: false, errorCode: code));
      return;
    }
    await _onPurchaseEvent(
      PartyPassPurchaseEvent(
        status: PartyPassPurchaseStatus.purchased,
        credential: credential,
      ),
    );
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
    final latest = state.value ?? current;
    state = AsyncData(latest.copyWith(purchasing: false, errorCode: code));
  }

  /// Verifies the receipt without spending a relay match. Called once after a
  /// purchase or restore, and whenever the pass sheet opens. A definitive
  /// rejection also locks the cosmetics, not just the relay.
  Future<void> verify() async {
    if (_disposed) return;
    final current = state.value ?? const PartyPassState();
    final credential = current.credential;
    if (credential == null) return;
    final requestId = ++_quotaRequestId;
    try {
      final result = await ref
          .read(turnRelayClientProvider)
          .verify(
            baseUrl: TurnRelayClient.defaultBaseUrl,
            credential: credential,
          );
      if (_disposed) return;
      final latest = state.value ?? current;
      if (latest.credential?.verificationToken !=
              credential.verificationToken ||
          requestId < _appliedQuotaRequestId) {
        return;
      }
      _appliedQuotaRequestId = requestId;
      if (!result.valid) {
        _cachedGrant = null;
        state = AsyncData(
          latest.copyWith(
            active: false,
            clearCredential: true,
            errorCode: 'pass_revoked',
            remainingMatchesToday: 0,
            clearRelayError: true,
            clearRelayRetry: true,
          ),
        );
        await ref.read(partyPassRepositoryProvider).clear();
        return;
      }
      state = AsyncData(
        latest.copyWith(
          remainingMatchesToday: result.remainingMatchesToday,
          dailyLimit: result.dailyLimit,
          clearRelayError: true,
        ),
      );
    } on TurnRelayException catch (error) {
      if (_disposed) return;
      final latest = state.value ?? current;
      if (latest.credential?.verificationToken !=
              credential.verificationToken ||
          requestId < _appliedQuotaRequestId) {
        return;
      }
      _appliedQuotaRequestId = requestId;
      if (error.code == TurnRelayErrorCode.invalidReceipt ||
          error.code == TurnRelayErrorCode.productMismatch) {
        _cachedGrant = null;
        state = AsyncData(
          latest.copyWith(
            active: false,
            clearCredential: true,
            errorCode: 'pass_revoked',
            remainingMatchesToday: 0,
            clearRelayError: true,
            clearRelayRetry: true,
          ),
        );
        await ref.read(partyPassRepositoryProvider).clear();
        return;
      }
      state = AsyncData(
        latest.copyWith(
          relayErrorCode: error.code,
          relayRetryAtUtc: error.retryAtUtc,
          clearRelayRetry: error.retryAtUtc == null,
        ),
      );
    }
  }

  /// Called by the transport at ICE setup time. A null grant lets direct P2P
  /// get its chance; [TurnRelayAttempt.passActive] drives the failure prompt.
  Future<TurnRelayAttempt> relayAttempt() async {
    if (_disposed) return const TurnRelayAttempt();
    final current = state.value ?? const PartyPassState();
    final credential = current.credential;
    if (!current.active || credential == null) {
      return const TurnRelayAttempt(passActive: false);
    }
    final requestId = ++_quotaRequestId;
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
      if (!_disposed) {
        final latest = state.value ?? current;
        if (latest.credential?.verificationToken !=
                credential.verificationToken ||
            requestId < _appliedQuotaRequestId) {
          return TurnRelayAttempt(grant: grant, passActive: true);
        }
        _appliedQuotaRequestId = requestId;
        _cachedGrant = grant;
        state = AsyncData(
          latest.copyWith(
            remainingMatchesToday: grant.remainingMatchesToday,
            dailyLimit: grant.dailyLimit,
            clearRelayError: true,
          ),
        );
      }
      return TurnRelayAttempt(grant: grant, passActive: true);
    } on TurnRelayException catch (error) {
      if (!_disposed) {
        final latest = state.value ?? current;
        if (latest.credential?.verificationToken ==
                credential.verificationToken &&
            requestId >= _appliedQuotaRequestId) {
          _appliedQuotaRequestId = requestId;
          _cachedGrant = null;
          state = AsyncData(
            latest.copyWith(
              relayErrorCode: error.code,
              relayRetryAtUtc: error.retryAtUtc,
              clearRelayRetry: error.retryAtUtc == null,
              remainingMatchesToday:
                  error.remainingMatchesToday ?? latest.remainingMatchesToday,
            ),
          );
        }
      }
      return TurnRelayAttempt(
        passActive: true,
        errorCode: error.code,
        retryAtUtc: error.retryAtUtc,
      );
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
  final service = createPartyPassPurchaseService(
    distribution: appDistribution,
    repository: ref.watch(partyPassRepositoryProvider),
  );
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
