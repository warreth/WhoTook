// Regenerates the home screenshots in store/assets/screenshots.
// Run from app/: flutter test tool/home_store_capture_test.dart --update-goldens
import 'dart:async';
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
import 'package:whotook/ui/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  for (final target in _targets) {
    testWidgets('home ${target.folder}', (tester) async {
      await _precacheAssets(tester);
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
                appSettingsProvider.overrideWith(
                  () => _FixedSettings(
                    const AppSettings(
                      nickname: 'Bram',
                      onboardingCompleted: true,
                    ),
                  ),
                ),
                matchStateProvider.overrideWith(
                  (ref) => Stream<MatchUiState>.value(const MatchUiState()),
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
                home: const HomeScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await expectLater(
        find.byType(FittedBox),
        matchesGoldenFile(
          '../../store/assets/screenshots/${target.folder}/01-home.png',
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
  _FixedSettings(this._value);
  final AppSettings _value;
  @override
  Future<AppSettings> build() async => _value;
}

Future<void> _precacheAssets(WidgetTester tester) async {
  for (final name in <String>[
    'party-dog',
    'party-cat',
    'party-hamster',
    'party-pizza',
  ]) {
    final provider = AssetImage('assets/samples/$name.jpg');
    await tester.runAsync(() async {
      final stream = provider.resolve(ImageConfiguration.empty);
      final done = Completer<void>();
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (_, _) {
          if (!done.isCompleted) done.complete();
          stream.removeListener(listener);
        },
        onError: (_, _) {
          if (!done.isCompleted) done.complete();
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      await done.future;
    });
  }
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
