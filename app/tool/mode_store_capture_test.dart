// Regenerates the mode-setup screenshots in store/assets/screenshots.
// Run from app/: flutter test tool/mode_store_capture_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/state/providers.dart';
import 'package:whotook/ui/screens/setup/mode_setup_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  for (final target in _targets) {
    testWidgets('mode ${target.folder}', (tester) async {
      tester.view.physicalSize = Size(
        target.width * target.scale,
        target.height * target.scale,
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: target.width,
            height: target.height,
            child: ProviderScope(
              overrides: [
                appSettingsProvider.overrideWith(() => _FixedSettings()),
                matchStateProvider.overrideWith(
                  (ref) => Stream<MatchUiState>.value(
                    const MatchUiState(
                      config: MatchConfig(
                        roundsK: 10,
                        roundSeconds: 8,
                        mode: GameMode.captionThis,
                      ),
                    ),
                  ),
                ),
              ],
              child: MaterialApp(
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                debugShowCheckedModeBanner: false,
                theme: buildWhoTookTheme(Brightness.light),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: Size(target.width, target.height),
                    devicePixelRatio: 1,
                  ),
                  child: child!,
                ),
                home: const ModeSetupScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(
        find.byType(FittedBox),
        matchesGoldenFile(
          '../../store/assets/screenshots/${target.folder}/02-mode-setup.png',
        ),
      );
    });
  }
}

class _Target {
  const _Target(this.folder, this.width, this.height, this.scale);
  final String folder;
  final double width;
  final double height;
  final int scale;
}

const List<_Target> _targets = <_Target>[
  _Target('iphone69', 440, 956, 3),
  _Target('ipad13', 1032, 1376, 2),
  _Target('play', 390, 780, 3),
];

class _FixedSettings extends AppSettingsController {
  @override
  Future<AppSettings> build() async =>
      const AppSettings(nickname: 'Bram', onboardingCompleted: true);
}

Future<void> _loadFonts() async {
  final dmSans = FontLoader('DMSans')
    ..addFont(rootBundle.load('assets/fonts/DMSans.ttf'));
  final mono = FontLoader('JetBrainsMono')
    ..addFont(rootBundle.load('assets/fonts/JetBrainsMono.ttf'));
  await Future.wait(<Future<void>>[dmSans.load(), mono.load()]);
  final iconFont = File(
    '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}'
    '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (iconFont.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(
        Future<ByteData>.value(
          ByteData.sublistView(iconFont.readAsBytesSync()),
        ),
      );
    await loader.load();
  }
}
