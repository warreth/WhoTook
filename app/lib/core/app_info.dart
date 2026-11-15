import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'constants.dart';

/// The running build, read from the installed package in production and from
/// the release constants in tests.
class AppInfo {
  const AppInfo({required this.version, required this.build});

  final String version;
  final int build;
}

final appInfoProvider = Provider<AppInfo>(
  (ref) => const AppInfo(version: kAppVersion, build: kAppBuildNumber),
);
