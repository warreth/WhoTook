import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/distribution.dart';

void main() {
  test('iOS receipts keep store billing, sideloaded builds get Paddle', () {
    expect(
      resolveAppDistribution(
        ffoss: true,
        directFlag: false,
        web: false,
        platform: TargetPlatform.iOS,
        receiptEnvironment: 'app_store',
      ),
      AppDistribution.store,
    );
    expect(
      resolveAppDistribution(
        ffoss: true,
        directFlag: false,
        web: false,
        platform: TargetPlatform.iOS,
        receiptEnvironment: 'testflight',
      ),
      AppDistribution.store,
    );
    expect(
      resolveAppDistribution(
        ffoss: false,
        directFlag: false,
        web: false,
        platform: TargetPlatform.iOS,
        receiptEnvironment: 'sideloaded',
      ),
      AppDistribution.direct,
    );
    expect(
      resolveAppDistribution(
        ffoss: true,
        directFlag: false,
        web: false,
        platform: TargetPlatform.iOS,
        receiptEnvironment: 'sideloaded',
      ),
      AppDistribution.direct,
    );
  });

  test('an unreadable iOS receipt is treated as a store build', () {
    expect(
      resolveAppDistribution(
        ffoss: true,
        directFlag: false,
        web: false,
        platform: TargetPlatform.iOS,
      ),
      AppDistribution.store,
    );
  });

  test('FFOSS and legacy direct flags open Paddle on Android', () {
    for (final ffoss in <bool>[true]) {
      expect(
        resolveAppDistribution(
          ffoss: ffoss,
          directFlag: false,
          web: false,
          platform: TargetPlatform.android,
        ),
        AppDistribution.direct,
      );
    }
    expect(
      resolveAppDistribution(
        ffoss: false,
        directFlag: true,
        web: false,
        platform: TargetPlatform.android,
      ),
      AppDistribution.direct,
    );
    expect(
      resolveAppDistribution(
        ffoss: false,
        directFlag: false,
        web: false,
        platform: TargetPlatform.android,
      ),
      AppDistribution.store,
    );
  });

  test('web is always the direct Paddle surface', () {
    expect(
      resolveAppDistribution(
        ffoss: false,
        directFlag: false,
        web: true,
        platform: TargetPlatform.android,
      ),
      AppDistribution.direct,
    );
  });
}
