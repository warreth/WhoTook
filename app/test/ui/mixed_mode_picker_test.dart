import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:whotook/ui/widgets/mode_picker.dart';

import '../support/fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestFonts);

  testWidgets('mixed modes start on all three and refuse a one-mode mix', (
    tester,
  ) async {
    final view = tester.view;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    Set<GameMode> selected = <GameMode>{
      GameMode.classic,
      GameMode.makeItMeme,
      GameMode.zoomOut,
    };
    late Set<GameMode> lastChanged;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildWhoTookTheme(Brightness.light),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setState) => MixedModePicker(
                selected: selected,
                onChanged: (modes) {
                  lastChanged = modes;
                  setState(() => selected = modes);
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('Make It Meme'), findsOneWidget);
    expect(find.text('Zoom-Out'), findsOneWidget);

    await tester.tap(find.text('Make It Meme'));
    await tester.pump();
    expect(lastChanged, <GameMode>{GameMode.classic, GameMode.zoomOut});
    expect(selected, hasLength(2));

    await tester.tap(find.text('Classic'));
    await tester.pump();
    expect(selected, hasLength(2));
    expect(
      find.text('Keep at least two modes in Mixed Party.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Make It Meme'));
    await tester.pump();
    expect(selected, hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mixed mode selector golden', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildWhoTookTheme(Brightness.light),
        home: Scaffold(
          backgroundColor: const Color(0xFFF7F4EE),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: MixedModePicker(
              selected: MatchConfig.coreMixedModes,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(MixedModePicker),
      matchesGoldenFile('goldens/mixed-modes.png'),
    );
  });

  testWidgets('mixed mode selector golden at 320', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(320, 568);
    view.devicePixelRatio = 1;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('nl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildWhoTookTheme(Brightness.dark),
        home: Scaffold(
          backgroundColor: const Color(0xFF161513),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: MixedModePicker(
              selected: MatchConfig.coreMixedModes,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(MixedModePicker),
      matchesGoldenFile('goldens/mixed-modes-320.png'),
    );
  });

  testWidgets('mixed mode chips fit a small phone', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(320, 568);
    view.devicePixelRatio = 1;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('nl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildWhoTookTheme(Brightness.dark),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: MixedModePicker(
              selected: MatchConfig.coreMixedModes,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Klassiek'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
