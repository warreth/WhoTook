import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:whotook/core/audio/game_audio_service.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:whotook/ui/screens/demo_game_screen.dart';
import 'package:whotook/ui/screens/lobby_screen.dart';

/// Runs on a real Android device or emulator and on the iOS simulator:
///
///   flutter test integration_test/demo_mode_test.dart -d `<device>`
///
/// This is the platform gate the unit tests cannot be: it boots the real
/// host, three loopback clients, the bundled photos and the real plugin
/// channels, then demands the lobby instead of the loading screen.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('nl');
    try {
      await GameAudioService.instance.initialize();
    } on Object {
      // Audio is optional; the demo must still open without it.
    }
  });

  testWidgets('Demo Mode opens the lobby on this device', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          theme: buildWhoTookTheme(Brightness.light),
          home: const DemoGameScreen(
            settings: AppSettings(
              nickname: 'Tester',
              onboardingCompleted: true,
            ),
            locale: Locale('en'),
          ),
        ),
      ),
    );

    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(LobbyScreen, skipOffstage: false).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Setting up the demo table'), findsNothing);
    expect(find.byType(LobbyScreen, skipOffstage: false), findsOneWidget);
    expect(find.text('Tester'), findsWidgets);
    expect(find.text('Lotte'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Noor'), findsOneWidget);
    expect(find.text('Start photo check'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
