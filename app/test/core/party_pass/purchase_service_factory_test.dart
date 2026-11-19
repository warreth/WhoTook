import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/distribution.dart';
import 'package:whotook/core/party_pass/party_pass_repository.dart';
import 'package:whotook/core/party_pass/party_pass_storage.dart';
import 'package:whotook/core/party_pass/purchase_service.dart';
import 'package:whotook/core/party_pass/purchase_service_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repository = PartyPassRepository(storage: InMemoryPartyPassStorage());

  test('store builds select store billing, never Paddle', () {
    final service = createPartyPassPurchaseService(
      distribution: AppDistribution.store,
      repository: repository,
    );
    addTearDown(service.dispose);
    expect(service.kind, PartyPassBillingKind.store);
    expect(service, isA<StorePartyPassPurchaseService>());
  });

  test('direct builds select Paddle billing, never the store', () {
    final service = createPartyPassPurchaseService(
      distribution: AppDistribution.direct,
      repository: repository,
    );
    addTearDown(service.dispose);
    expect(service.kind, PartyPassBillingKind.paddle);
    expect(service, isNot(isA<StorePartyPassPurchaseService>()));
  });
}
