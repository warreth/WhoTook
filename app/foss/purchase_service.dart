import 'dart:async';

import 'party_pass_repository.dart';

// This file replaces purchase_service.dart in a FOSS build. It deliberately
// has no in_app_purchase import so the native StoreKit/Play Billing plugins
// are not in the dependency graph.
enum PartyPassPurchaseStatus { purchased, restored, canceled, pending, error }

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

abstract class PartyPassPurchaseService {
  Stream<PartyPassPurchaseEvent> get events;

  String? get priceLabel;

  bool get available;

  Future<void> initialize();

  Future<PartyPassPurchaseEvent> buy();

  Future<PartyPassPurchaseEvent> restore();

  Future<void> dispose();
}

class DisabledPurchaseService implements PartyPassPurchaseService {
  @override
  Stream<PartyPassPurchaseEvent> get events => const Stream.empty();

  @override
  String? get priceLabel => null;

  @override
  bool get available => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<PartyPassPurchaseEvent> buy() async => const PartyPassPurchaseEvent(
    status: PartyPassPurchaseStatus.error,
    code: 'billing_disabled',
  );

  @override
  Future<PartyPassPurchaseEvent> restore() async =>
      const PartyPassPurchaseEvent(
        status: PartyPassPurchaseStatus.error,
        code: 'billing_disabled',
      );

  @override
  Future<void> dispose() async {}
}

/// The controller still references the official class name. In a FOSS build it
/// is always unavailable and never initialized by the provider.
class StorePartyPassPurchaseService extends DisabledPurchaseService {}
