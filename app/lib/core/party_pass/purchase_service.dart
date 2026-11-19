import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

import 'party_pass_repository.dart';

enum PartyPassPurchaseStatus { purchased, restored, canceled, pending, error }

/// Which purchase surface a build is allowed to show.
enum PartyPassBillingKind { store, paddle }

class PartyPassPurchaseEvent {
  const PartyPassPurchaseEvent({
    required this.status,
    this.credential,
    this.code,
  });

  final PartyPassPurchaseStatus status;
  final PartyPassCredential? credential;
  final String? code;

  bool get isSuccess =>
      status == PartyPassPurchaseStatus.purchased ||
      status == PartyPassPurchaseStatus.restored;
}

/// Store billing behind one seam. Tests use a fake so no platform channel is
/// touched.
abstract class PartyPassPurchaseService {
  Stream<PartyPassPurchaseEvent> get events;

  String? get priceLabel;

  bool get available;

  PartyPassBillingKind get kind;

  Future<void> initialize();

  Future<PartyPassPurchaseEvent> buy();

  Future<PartyPassPurchaseEvent> restore();

  /// Manual redemption for a web/Paddle license key. Store builds reject this;
  /// they only accept a store receipt from the platform purchase flow.
  Future<PartyPassPurchaseEvent> redeem(String licenseKey) async {
    return const PartyPassPurchaseEvent(
      status: PartyPassPurchaseStatus.error,
      code: 'license_not_supported',
    );
  }

  Future<void> dispose();
}

/// Official App Store / Play Store billing for the non-consumable
/// `whotook_party_pass`. StoreKit 2 is the default path on iOS in
/// `in_app_purchase_storekit` 0.4.x; Google Play Billing is used on Android.
class StorePartyPassPurchaseService implements PartyPassPurchaseService {
  StorePartyPassPurchaseService({
    this.billing,
    this.buyTimeout = const Duration(minutes: 2),
    this.restoreTimeout = const Duration(seconds: 60),
  });

  final InAppPurchase? billing;
  final Duration buyTimeout;
  final Duration restoreTimeout;

  final StreamController<PartyPassPurchaseEvent> _events =
      StreamController<PartyPassPurchaseEvent>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  InAppPurchase? _resolvedBilling;
  ProductDetails? _product;
  PartyPassCredential? _lastRestored;
  Completer<PartyPassPurchaseEvent>? _pending;
  bool _initialized = false;
  bool _available = false;

  InAppPurchase get _iap =>
      _resolvedBilling ??= billing ?? InAppPurchase.instance;

  @override
  Stream<PartyPassPurchaseEvent> get events => _events.stream;

  @override
  String? get priceLabel => _product?.price;

  @override
  bool get available => _available;

  @override
  PartyPassBillingKind get kind => PartyPassBillingKind.store;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _available = await _iap.isAvailable();
      if (!_available) {
        _initialized = false;
        return;
      }
      _subscription ??= _iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object _) {},
      );
      final response = await _iap.queryProductDetails(<String>{
        kPartyPassProductId,
      });
      if (response.productDetails.isNotEmpty) {
        _product = response.productDetails.firstWhere(
          (product) => product.id == kPartyPassProductId,
          orElse: () => response.productDetails.first,
        );
      }
    } on Object {
      // A missing store (emulator, test runner, sideloaded build) must not
      // stop the app. Allow a later sheet to retry once the store is ready.
      _available = false;
      _initialized = false;
    }
    if (!_available) _initialized = false;
  }

  Future<void> _ensureProduct() async {
    if (_product != null) return;
    final response = await _iap.queryProductDetails(<String>{
      kPartyPassProductId,
    });
    for (final product in response.productDetails) {
      if (product.id == kPartyPassProductId) {
        _product = product;
        return;
      }
    }
  }

  @override
  Future<PartyPassPurchaseEvent> buy() async {
    if (!_available) {
      return const PartyPassPurchaseEvent(
        status: PartyPassPurchaseStatus.error,
        code: 'billing_unavailable',
      );
    }
    try {
      await _ensureProduct();
      final product = _product;
      if (product == null) {
        return const PartyPassPurchaseEvent(
          status: PartyPassPurchaseStatus.error,
          code: 'product_unavailable',
        );
      }
      final pending = Completer<PartyPassPurchaseEvent>();
      _pending = pending;
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _pending = null;
        return const PartyPassPurchaseEvent(
          status: PartyPassPurchaseStatus.error,
          code: 'purchase_not_started',
        );
      }
      return await pending.future.timeout(
        buyTimeout,
        onTimeout: () => const PartyPassPurchaseEvent(
          status: PartyPassPurchaseStatus.pending,
        ),
      );
    } on Object {
      _pending = null;
      return const PartyPassPurchaseEvent(
        status: PartyPassPurchaseStatus.error,
        code: 'purchase_failed',
      );
    }
  }

  @override
  Future<PartyPassPurchaseEvent> redeem(String licenseKey) async {
    return const PartyPassPurchaseEvent(
      status: PartyPassPurchaseStatus.error,
      code: 'license_not_supported',
    );
  }

  @override
  Future<PartyPassPurchaseEvent> restore() async {
    if (!_available) {
      return const PartyPassPurchaseEvent(
        status: PartyPassPurchaseStatus.error,
        code: 'billing_unavailable',
      );
    }
    final remembered = _lastRestored;
    if (remembered != null) {
      return PartyPassPurchaseEvent(
        status: PartyPassPurchaseStatus.restored,
        credential: remembered,
      );
    }
    final pending = Completer<PartyPassPurchaseEvent>();
    _pending = pending;
    PartyPassPurchaseEvent result;
    try {
      result = await _restoreFlow(pending).timeout(
        restoreTimeout,
        onTimeout: () => const PartyPassPurchaseEvent(
          status: PartyPassPurchaseStatus.error,
          code: 'restore_empty',
        ),
      );
    } on Object {
      result = const PartyPassPurchaseEvent(
        status: PartyPassPurchaseStatus.error,
        code: 'restore_failed',
      );
    }
    if (identical(_pending, pending)) _pending = null;
    return result;
  }

  Future<PartyPassPurchaseEvent> _restoreFlow(
    Completer<PartyPassPurchaseEvent> pending,
  ) async {
    await _syncStoreIfNeeded();
    if (!pending.isCompleted) {
      final restoredDuringSync = _lastRestored;
      if (restoredDuringSync != null) {
        pending.complete(
          PartyPassPurchaseEvent(
            status: PartyPassPurchaseStatus.restored,
            credential: restoredDuringSync,
          ),
        );
      }
    }
    if (!pending.isCompleted) {
      await _iap.restorePurchases();
    }
    return pending.future;
  }

  /// StoreKit 2 reads `Transaction.currentEntitlements`; a fresh device can be
  /// empty until the app explicitly syncs with the App Store. This call shows
  /// the system account prompt and is a no-op outside iOS.
  Future<void> _syncStoreIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _iap
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>()
          .sync();
    } on Object {
      // A cancelled or unavailable App Store prompt must still fall through to
      // restorePurchases(), which may already have the entitlement cached.
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != kPartyPassProductId) {
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final token = purchase.verificationData.serverVerificationData;
          final platform = _platformFor(purchase.verificationData.source);
          if (token.isEmpty || platform == null) {
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
            }
            _finish(
              const PartyPassPurchaseEvent(
                status: PartyPassPurchaseStatus.error,
                code: 'verification_payload_missing',
              ),
            );
            continue;
          }
          final credential = PartyPassCredential(
            platform: platform,
            productId: kPartyPassProductId,
            verificationToken: token,
            savedAtUtc: DateTime.now().toUtc(),
          );
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          if (purchase.status == PurchaseStatus.restored) {
            _lastRestored = credential;
          }
          _events.add(
            PartyPassPurchaseEvent(
              status: purchase.status == PurchaseStatus.restored
                  ? PartyPassPurchaseStatus.restored
                  : PartyPassPurchaseStatus.purchased,
              credential: credential,
            ),
          );
          _finish(
            PartyPassPurchaseEvent(
              status: purchase.status == PurchaseStatus.restored
                  ? PartyPassPurchaseStatus.restored
                  : PartyPassPurchaseStatus.purchased,
              credential: credential,
            ),
          );
          break;
        case PurchaseStatus.pending:
          _finish(
            const PartyPassPurchaseEvent(
              status: PartyPassPurchaseStatus.pending,
            ),
          );
          break;
        case PurchaseStatus.canceled:
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          _finish(
            const PartyPassPurchaseEvent(
              status: PartyPassPurchaseStatus.canceled,
            ),
          );
          break;
        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          _finish(
            PartyPassPurchaseEvent(
              status: PartyPassPurchaseStatus.error,
              code: purchase.error?.code,
            ),
          );
          break;
      }
    }
  }

  StorePlatform? _platformFor(String source) {
    if (source == 'app_store') return StorePlatform.apple;
    if (source == 'google_play') return StorePlatform.google;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => StorePlatform.apple,
      TargetPlatform.android => StorePlatform.google,
      _ => null,
    };
  }

  void _finish(PartyPassPurchaseEvent event) {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete(event);
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _events.close();
  }
}
