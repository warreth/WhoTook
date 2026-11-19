import '../distribution.dart';
import 'paddle_purchase_service.dart';
import 'party_pass_repository.dart';
import 'purchase_service.dart';

/// The single place where a build chooses its allowed purchase surface.
///
/// Store builds can only use Apple/Google billing. Direct builds can only use
/// Paddle and the license-key path. Keeping this in one function makes the
/// store-policy decision testable without a platform channel.
PartyPassPurchaseService createPartyPassPurchaseService({
  required AppDistribution distribution,
  required PartyPassRepository repository,
}) {
  if (distribution == AppDistribution.direct) {
    return PaddlePartyPassPurchaseService(repository: repository);
  }
  return StorePartyPassPurchaseService();
}
