import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/version.dart';

void main() {
  test('build numbers are stripped before comparison', () {
    expect(normalizeAppVersion('1.9.2+15'), '1.9.2');
    expect(normalizeAppVersion(' 2.0.0+1014 '), '2.0.0');
    expect(compareAppVersions('1.9.2+15', '1.9.2+12'), 0);
    expect(compareAppVersions('1.9.2+99', '1.9.2'), 0);
    expect(isNewerAppVersion('1.9.2+99', '1.9.2+1'), isFalse);
  });

  test('major, minor and patch still decide compatibility', () {
    expect(compareAppVersions('1.9.3', '1.9.2'), greaterThan(0));
    expect(compareAppVersions('1.10.0', '1.9.9'), greaterThan(0));
    expect(compareAppVersions('2.0.0', '1.99.99'), greaterThan(0));
    expect(compareAppVersions('1.9.2', '1.9.10'), lessThan(0));
    expect(compareAppVersions('1.9', '1.9.0'), 0);
    expect(compareAppVersions('1.9.2', '1.9'), greaterThan(0));
  });

  test('the room warning ignores a newer build of the same release', () {
    const warning = VersionWarning(
      latestVersion: '1.9.2',
      latestBuild: 1014,
      ownVersion: '1.9.2+15',
      ownBuild: 15,
    );
    expect(warning.isNewer, isFalse);
    const realUpgrade = VersionWarning(
      latestVersion: '1.9.3+16',
      latestBuild: 1014,
      ownVersion: '1.9.2',
      ownBuild: 15,
    );
    expect(realUpgrade.isNewer, isTrue);
  });
}
