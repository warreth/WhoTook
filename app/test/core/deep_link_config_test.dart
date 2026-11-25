import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS entitlements claim the invite domain', () {
    final entitlements = File('ios/Runner/Runner.entitlements')
        .readAsStringSync();
    expect(entitlements, contains('applinks:whotook.party'));
  });

  test('Android manifest claims the invite path and package', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:autoVerify="true"'));
    expect(manifest, contains('android:scheme="https"'));
    expect(manifest, contains('android:host="whotook.party"'));
    expect(manifest, contains('android:pathPrefix="/j"'));
    expect(manifest, contains('android:scheme="whotook"'));
  });

  test('the install referrer channel is wired on Android', () {
    final main = File(
      'android/app/src/main/kotlin/party/whotook/app/MainActivity.kt',
    ).readAsStringSync();
    expect(main, contains('app.whotook/install_referrer'));
    expect(main, contains('InstallReferrerClient'));
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('com.android.installreferrer'));
  });
}
