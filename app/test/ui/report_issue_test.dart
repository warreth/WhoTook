import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:whotook/ui/widgets/idle_report_overlay.dart';
import 'package:whotook/ui/widgets/report_issue_button.dart';

Widget _app(Widget home) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildWhoTookTheme(Brightness.light),
    home: Scaffold(body: home),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('report sheet offers mail, file and clipboard', (tester) async {
    await tester.pumpWidget(
      _app(const Center(child: ReportIssueButton(tile: true))),
    );

    await tester.tap(find.text('Report this issue'));
    await tester.pumpAndSettle();

    expect(find.text('Email with diagnostics'), findsOneWidget);
    expect(find.text('Share log file'), findsOneWidget);
    expect(find.text('Copy report'), findsOneWidget);
  });

  testWidgets('a long idle screen reveals a compact report button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        IdleReportOverlay(
          resetToken: 'lobby',
          threshold: const Duration(seconds: 2),
          screenLabel: 'Lobby',
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.text('Report this issue'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Report this issue'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect(find.text('Report this issue'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('report sheet fits a small phone without overflow', (
    tester,
  ) async {
    final view = tester.view;
    view.physicalSize = const Size(320, 568);
    view.devicePixelRatio = 1;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _app(const Center(child: ReportIssueButton(tile: true))),
    );
    await tester.tap(find.text('Report this issue'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Share log file'), findsOneWidget);
  });
}
