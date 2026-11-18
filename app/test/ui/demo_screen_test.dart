import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/demo/demo_match_controller.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:whotook/state/providers.dart';
import 'package:whotook/ui/match_root.dart';
import 'package:whotook/ui/screens/demo_game_screen.dart';
import 'package:whotook/ui/screens/demo_screen.dart';
import 'package:whotook/ui/screens/lobby_screen.dart';
import 'package:whotook/ui/widgets/common.dart';

import '../support/fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await loadTestFonts();
  });

  testWidgets('demo launcher opens the real match view', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appSettingsProvider.overrideWith(_DemoSettings.new)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          theme: buildWhoTookTheme(Brightness.light),
          home: const DemoScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A real game, without the setup'), findsOneWidget);
    await expectLater(
      find.byType(DemoScreen),
      matchesGoldenFile('goldens/demo-intro.png'),
    );

    final startButton = find.widgetWithText(PrimaryButton, 'Start demo');
    expect(startButton, findsOneWidget);
    await tester.ensureVisible(startButton);
    await tester.pumpAndSettle();
    await tester.tap(startButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(DemoGameScreen, skipOffstage: false), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('demo lobby uses the real screens and hides the real invite', (
    tester,
  ) async {
    final view = tester.view;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
    final controller = DemoMatchController(
      baseSettings: const AppSettings(nickname: 'Bram'),
      config: const MatchConfig(
        roundsK: 3,
        roundSeconds: 4,
        mode: GameMode.classic,
        pace: GamePace.fast,
      ),
      countdownDuration: Duration.zero,
      revealDuration: const Duration(milliseconds: 50),
      captionRevealDuration: const Duration(milliseconds: 50),
      roundDuration: const Duration(milliseconds: 400),
    );
    addTearDown(controller.dispose);
    await tester.runAsync(controller.start);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: buildWhoTookTheme(Brightness.light),
        home: DemoMatchScope(
          controller: controller,
          child: const MatchRoot(demo: true),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Your demo table'), findsOneWidget);
    expect(find.text('Lotte'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Noor'), findsOneWidget);
    expect(find.text('Start photo check'), findsOneWidget);
    expect(find.text('Scan to join'), findsNothing);
    await expectLater(
      find.byType(LobbyScreen),
      matchesGoldenFile('goldens/demo-lobby.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _DemoSettings extends AppSettingsController {
  @override
  Future<AppSettings> build() async =>
      const AppSettings(nickname: 'Bram', onboardingCompleted: true);
}
