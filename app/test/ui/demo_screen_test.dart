import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/ui/screens/demo_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo runs a complete sample round', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildWhoTookTheme(Brightness.light),
        home: const DemoScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Check your photos'), findsOneWidget);
    expect(find.text('Start demo round'), findsOneWidget);

    await tester.tap(find.text('Start demo round'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Who took this?'), findsOneWidget);

    await tester.tap(find.text('Lotte'));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Shot by Lotte'), findsOneWidget);
    expect(find.text('You got it. +820'), findsOneWidget);

    await tester.tap(find.text('See the podium'));
    await tester.pumpAndSettle();
    expect(find.text('CHAMPION'), findsOneWidget);
    expect(find.text('3410 pts'), findsOneWidget);
  });
}
