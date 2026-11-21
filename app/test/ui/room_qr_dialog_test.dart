import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:whotook/ui/widgets/room_qr_dialog.dart';

import '../support/fonts.dart';

Widget _app({required void Function(BuildContext) onOpen}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildWhoTookTheme(Brightness.light),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => onOpen(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestFonts);

  for (final size in const <Size>[Size(320, 568), Size(390, 844)]) {
    testWidgets(
      'room QR dialog fits ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        final view = tester.view;
        view.physicalSize = size;
        view.devicePixelRatio = 1;
        addTearDown(() {
          view.resetPhysicalSize();
          view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _app(
            onOpen: (context) => showRoomQrDialog(
              context,
              roomId: 'abc12345',
              inviteUrl: 'https://whotook.party/j/invite-token',
            ),
          ),
        );
        await _open(tester);

        expect(find.text('Scan to join'), findsOneWidget);
        expect(find.text('ROOM abc12345'), findsOneWidget);
        expect(find.text('Share invite link'), findsOneWidget);
        expect(find.byType(QrImageView), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(RoomQrDialog),
          matchesGoldenFile(
            size.width == 390
                ? 'goldens/room-qr-dialog.png'
                : 'goldens/room-qr-dialog-320.png',
          ),
        );

        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(QrImageView), findsNothing);
      },
    );
  }
}
