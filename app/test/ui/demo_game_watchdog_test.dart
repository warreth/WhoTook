import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/demo/demo_match_controller.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:whotook/ui/screens/demo_game_screen.dart';

class _HangingDemoController extends DemoMatchController {
  _HangingDemoController(AppSettings settings)
    : super(baseSettings: settings);

  final Completer<void> never = Completer<void>();

  @override
  Future<void> start() => never.future;

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo setup reveals retry and report after six seconds', (
    tester,
  ) async {
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildWhoTookTheme(Brightness.light),
        locale: const Locale('nl'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: DemoGameScreen(
          settings: const AppSettings(nickname: 'Bram'),
          locale: const Locale('nl'),
          controllerBuilder: (settings, locale, config) {
            builds += 1;
            return _HangingDemoController(settings);
          },
        ),
      ),
    );

    expect(find.text('Demotafel klaarzetten'), findsOneWidget);
    expect(find.text('Opnieuw proberen'), findsNothing);

    await tester.pump(const Duration(seconds: 7));
    expect(find.text('Dit duurt langer dan verwacht.'), findsOneWidget);
    expect(find.text('Opnieuw proberen'), findsOneWidget);
    expect(find.text('Meld dit probleem'), findsOneWidget);

    await tester.tap(find.text('Opnieuw proberen'));
    await tester.pump();
    expect(builds, 2);
    expect(find.text('Demotafel klaarzetten'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
