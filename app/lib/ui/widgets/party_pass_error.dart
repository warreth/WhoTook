import '../../l10n/l10n.dart';

/// Maps server and store codes to a short, human message. Unknown codes fall
/// back to the generic line so a new backend error never leaks raw text.
String partyPassErrorLabel(AppLocalizations l10n, String? code) {
  return switch (code) {
    'purchase_canceled' => l10n.partyPassErrorCanceled,
    'billing_unavailable' ||
    'billing_disabled' => l10n.partyPassErrorUnavailable,
    'product_unavailable' => l10n.partyPassErrorProduct,
    'restore_empty' => l10n.partyPassErrorRestoreEmpty,
    'pass_revoked' => l10n.partyPassErrorRevoked,
    'invalid_license' => l10n.partyPassErrorInvalidLicense,
    'license_missing' => l10n.partyPassErrorLicenseMissing,
    'purchase_expired' => l10n.partyPassErrorPurchaseExpired,
    'purchase_not_found' => l10n.partyPassErrorPurchaseNotFound,
    'checkout_unavailable' => l10n.partyPassErrorCheckoutUnavailable,
    'checkout_open_failed' => l10n.partyPassErrorCheckoutOpenFailed,
    'network_error' => l10n.partyPassErrorNetwork,
    'purchase_pending' => l10n.partyPassPurchasePending,
    'rate_limited' => l10n.partyPassErrorRateLimited,
    'invalid_receipt' ||
    'relay_unavailable' ||
    'fair_use_limit_reached' ||
    'malformed_response' => l10n.partyPassRelayError,
    _ => l10n.partyPassErrorGeneric,
  };
}
