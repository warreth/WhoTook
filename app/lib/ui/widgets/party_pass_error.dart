import '../../l10n/l10n.dart';

/// Maps server and store codes to a short, human message. Unknown codes fall
/// back to the generic line so a new backend error never leaks raw text.
String partyPassErrorLabel(AppLocalizations l10n, String? code) {
  return switch (code) {
    'purchase_canceled' => l10n.partyPassErrorCanceled,
    'billing_unavailable' || 'billing_disabled' =>
      l10n.partyPassErrorUnavailable,
    'product_unavailable' => l10n.partyPassErrorProduct,
    'restore_empty' => l10n.partyPassErrorRestoreEmpty,
    'purchase_pending' => l10n.partyPassPurchasePending,
    'invalid_receipt' ||
    'relay_unavailable' ||
    'fair_use_limit_reached' ||
    'rate_limited' ||
    'network_error' ||
    'malformed_response' => l10n.partyPassRelayError,
    _ => l10n.partyPassErrorGeneric,
  };
}
