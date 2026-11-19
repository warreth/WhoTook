import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How this binary was distributed. Store builds may only use Apple/Google
/// billing; FFOSS and sideloaded builds use Paddle or a license key.
enum AppDistribution { store, direct }

/// The public FFOSS build flag. Kept as an explicit switch so the release
/// workflow can build a tracker-free binary without store billing.
const bool kFfossBuild = bool.fromEnvironment(
  'FFOSS_BUILD',
  defaultValue: false,
);

/// Older release scripts used this name. It stays as an alias so existing
/// local builds keep working.
const bool _directDistributionFlag =
    String.fromEnvironment('WHOTOOK_DISTRIBUTION', defaultValue: 'store') ==
    'direct';

AppDistribution _appDistribution = AppDistribution.store;
bool _sideloadedIos = false;

/// Resolved after the native receipt probe in `main`.
AppDistribution get appDistribution => _appDistribution;

bool get isDirectBuild => appDistribution == AppDistribution.direct;

bool get isStoreEnvironment => appDistribution == AppDistribution.store;

bool get isFfossBuild => kFfossBuild && isDirectBuild;

bool get isSideloadedIos => _sideloadedIos;

/// Pure resolution seam, also used by tests.
@visibleForTesting
AppDistribution resolveAppDistribution({
  required bool ffoss,
  required bool directFlag,
  required bool web,
  required TargetPlatform platform,
  String? receiptEnvironment,
}) {
  if (web) return AppDistribution.direct;
  if (platform == TargetPlatform.iOS) {
    // A store receipt always wins. This is what makes one iOS binary safe:
    // TestFlight and App Store installs keep IAP even though the FFOSS flag is
    // compiled in, while the same binary sideloaded through AltStore/SideStore
    // has no receipt and gets the direct Paddle surface.
    if (receiptEnvironment == 'app_store' ||
        receiptEnvironment == 'testflight') {
      return AppDistribution.store;
    }
    if (receiptEnvironment == 'sideloaded') return AppDistribution.direct;
    return AppDistribution.store;
  }
  if (ffoss || directFlag) return AppDistribution.direct;
  return AppDistribution.store;
}

/// Ask the native side whether this iOS install came from Apple. Android and
/// web are decided by the build flag. Never throws: an unknown platform is a
/// store build, which is the safe default for external-payment gating.
Future<void> detectAppDistribution() async {
  String? receiptEnvironment;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      receiptEnvironment = await const MethodChannel('app.whotook/distribution')
          .invokeMethod<String>('receiptEnvironment');
    } on Object {
      // An old binary without the channel must keep store behavior.
    }
  }
  _appDistribution = resolveAppDistribution(
    ffoss: kFfossBuild,
    directFlag: _directDistributionFlag,
    web: kIsWeb,
    platform: defaultTargetPlatform,
    receiptEnvironment: receiptEnvironment,
  );
  _sideloadedIos =
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      receiptEnvironment == 'sideloaded';
}

const String kDirectPriceLabel = String.fromEnvironment(
  'WHOTOOK_PRICE_LABEL',
  defaultValue: '€2.99',
);
