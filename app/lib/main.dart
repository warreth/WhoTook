import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app.dart';
import 'core/app_info.dart';
import 'core/audio/game_audio_service.dart';
import 'core/constants.dart';
import 'core/distribution.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await detectAppDistribution();
  await initializeDateFormatting('en');
  await initializeDateFormatting('nl');
  await GameAudioService.instance.initialize();
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
  runApp(
    ProviderScope(
      overrides: [appInfoProvider.overrideWithValue(info)],
      child: const WhoTookApp(),
    ),
  );
}
