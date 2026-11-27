import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app.dart';
import 'core/app_info.dart';
import 'core/audio/game_audio_service.dart';
import 'core/constants.dart';
import 'core/diagnostics/bug_report_service.dart';
import 'core/diagnostics/device_descriptor.dart';
import 'core/distribution.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BugReportService.instance.installErrorHooks();
  try {
    await detectAppDistribution().timeout(const Duration(seconds: 2));
  } on Object {
    // Keep safe store defaults on timeout or channel failure.
  }
  await initializeDateFormatting('en');
  await initializeDateFormatting('nl');
  try {
    await GameAudioService.instance.initialize().timeout(
      const Duration(seconds: 4),
    );
  } on Object {
    // Audio setup is optional; the demo and match must still open.
  }
  var info = const AppInfo(version: kAppVersion, build: kAppBuildNumber);
  try {
    final package = await PackageInfo.fromPlatform();
    info = AppInfo(
      version: package.version,
      build: int.tryParse(package.buildNumber) ?? kAppBuildNumber,
    );
  } on Object {
    // A missing platform channel must not stop the app; the release constants
    // remain as the fallback.
  }
  DeviceDescriptor? device;
  try {
    device = await readDeviceDescriptor().timeout(const Duration(seconds: 2));
  } on Object {
    // Diagnostics fall back to the platform version string.
  }
  BugReportService.instance.configure(
    version: info.version,
    build: info.build,
    osLabel: device?.osLabel,
    deviceLabel: device?.deviceLabel,
  );
  runApp(
    ProviderScope(
      overrides: [appInfoProvider.overrideWithValue(info)],
      child: const WhoTookApp(),
    ),
  );
}
