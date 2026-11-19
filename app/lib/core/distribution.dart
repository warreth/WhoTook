import 'package:flutter/foundation.dart';

/// How this binary was distributed. Store builds may only use Apple/Google
/// billing; direct builds (GitHub APK, SideStore IPA, web) use Paddle.
enum AppDistribution { store, direct }

const String _configuredDistribution = String.fromEnvironment(
  'WHOTOOK_DISTRIBUTION',
  defaultValue: 'store',
);

AppDistribution get appDistribution =>
    _configuredDistribution == 'direct' || kIsWeb
    ? AppDistribution.direct
    : AppDistribution.store;

bool get isDirectBuild => appDistribution == AppDistribution.direct;

const String kDirectPriceLabel = String.fromEnvironment(
  'WHOTOOK_PRICE_LABEL',
  defaultValue: '€2.99',
);
