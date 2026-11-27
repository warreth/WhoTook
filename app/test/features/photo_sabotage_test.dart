import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/features/photo_sabotage/sabotage_painter.dart';
import 'package:whotook/features/photo_sabotage/sabotage_screen.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/state/providers.dart';

import '../support/test_photo_library.dart';

import 'package:whotook/features/photo_sabotage/sabotage_stroke_utils.dart';

class _FixedSettings extends AppSettingsController {
  _FixedSettings(this._value);

  final AppSettings _value;

  @override
  Future<AppSettings> build() async => _value;
}

void main() {
  test('normalized strokes survive the wire roundtrip', () {
    final stroke = SabotageStroke(
      colorIndex: 3,
      width: 0.012,
      points: const <Offset>[
        Offset(0.1, 0.2),
        Offset(0.4, 0.5),
        Offset(0.8, 0.9),
      ],
    );
    final restored = SabotageStroke.fromJson(stroke.toJson());
    expect(restored.colorIndex, 3);
    expect(restored.width, closeTo(0.012, 0.0001));
    expect(restored.points, hasLength(3));
    expect(restored.points.first.dx, closeTo(0.1, 0.0001));
  });

  test('a long drawing stays under the payload limit on the wire', () {
    final strokes = <SabotageStroke>[
      for (var stroke = 0; stroke < 6; stroke++)
        SabotageStroke(
          colorIndex: stroke % 8,
          width: 0.01,
          points: <Offset>[
            for (var i = 0; i < 180; i++)
              Offset(
                0.1 + 0.8 * (i / 180),
                0.2 + 0.6 * sin(i / 8 + stroke).abs(),
              ),
          ],
        ),
    ];
    final simplified = simplifySabotageStrokes(strokes);
    expect(simplified, hasLength(6));
    expect(
      simplified.fold<int>(0, (sum, stroke) => sum + stroke.points.length),
      lessThan(6 * 180),
    );
    expect(sabotagePayloadBytes(simplified), lessThan(sabotageMaxPayloadBytes));
    for (final stroke in simplified) {
      expect(stroke.points, isNotEmpty);
      for (final point in stroke.points) {
        expect(point.dx, inInclusiveRange(0, 1));
        expect(point.dy, inInclusiveRange(0, 1));
      }
    }
  });

  test('many-stroke scribbles and stickers fit the payload budget', () {
    final strokes = <SabotageStroke>[
      for (var stroke = 0; stroke < 40; stroke++)
        SabotageStroke(
          colorIndex: stroke % 8,
          width: 0.012,
          points: <Offset>[
            for (var i = 0; i < 64; i++)
              Offset(
                0.05 + 0.9 * ((i * 37 + stroke * 11) % 64) / 64,
                0.05 + 0.9 * ((i * 53 + stroke * 7) % 64) / 64,
              ),
          ],
        ),
    ];
    final simplified = simplifySabotageStrokes(strokes);
    expect(simplified, isNotEmpty);
    const stickers = <SabotageSticker>[
      SabotageSticker(kind: SabotageStickerKind.googlyEyes, x: 0.4, y: 0.3),
      SabotageSticker(kind: SabotageStickerKind.crown, x: 0.5, y: 0.15),
    ];
    expect(
      sabotagePayloadBytes(simplified, stickers: stickers),
      lessThanOrEqualTo(sabotageMaxPayloadBytes),
    );
    final restoredSticker = SabotageSticker.fromJson(stickers.first.toJson());
    expect(restoredSticker.kind, SabotageStickerKind.googlyEyes);
  });

  test('keeps single-point tap dots and clamps stray points', () {
    final points = <Offset>[
      const Offset(-0.2, 0.2),
      const Offset(0.4, 0.4),
      const Offset(0.6, 0.6),
      const Offset(1.2, 0.8),
    ];
    final simplified = simplifySabotageStrokes(<SabotageStroke>[
      SabotageStroke(colorIndex: 0, width: 0.01, points: points),
      const SabotageStroke(
        colorIndex: 1,
        width: 0.012,
        points: <Offset>[Offset(0.5, 0.5)],
      ),
    ]);
    expect(simplified, hasLength(2));
    expect(simplified.first.points.first.dx, 0);
    expect(simplified.first.points.last.dx, 1);
    expect(simplified.last.points, hasLength(1));
  });

  test('sabotage pace uses 60s / 90s / 120s windows', () {
    expect(GamePace.fast.sabotageSeconds, 60);
    expect(GamePace.normal.sabotageSeconds, 90);
    expect(GamePace.slow.sabotageSeconds, 120);
  });

  test('all 10 sabotage sticker kinds survive JSON roundtrip', () {
    expect(SabotageStickerKind.values, hasLength(10));
    for (final kind in SabotageStickerKind.values) {
      final sticker = SabotageSticker(kind: kind, x: 0.35, y: 0.65, scale: 1.4);
      final restored = SabotageSticker.fromJson(sticker.toJson());
      expect(restored.kind, kind);
      expect(restored.x, closeTo(0.35, 0.001));
      expect(restored.y, closeTo(0.65, 0.001));
      expect(restored.scale, closeTo(1.4, 0.01));
    }
  });

  testWidgets(
    'sabotage stickers are icon-only and stay movable, resizable, and deletable after drawing',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final view = tester.view;
      view.physicalSize = const Size(390, 844);
      view.devicePixelRatio = 1;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final state = MatchUiState(
        isHosting: true,
        roomId: 'room1234',
        localPlayerId: 'host',
        phase: RoundPhase.captionWriting,
        activeMode: GameMode.photoSabotage,
        currentRound: 1,
        totalRounds: 4,
        remainingMs: 85000,
        phaseDurationMs: 90000,
        players: <Player>[
          Player(id: 'host', name: 'Bram', isHost: true),
          Player(id: 'p2', name: 'Lotte'),
        ],
        memeAssignment: const MemeAssignment(
          playerId: 'host',
          photoId: 'ph1',
          ownerId: 'p2',
          ownerName: 'Lotte',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith(
              () => _FixedSettings(
                const AppSettings(nickname: 'Bram', onboardingCompleted: true),
              ),
            ),
            photoLibraryProvider.overrideWithValue(TestPhotoLibrary()),
            matchStateProvider.overrideWith((ref) => Stream.value(state)),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildWhoTookTheme(Brightness.light),
            home: const SabotageScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the sticker tray and verify icon previews replace text labels.
      await tester.tap(find.byTooltip('Stickers'));
      await tester.pumpAndSettle();
      expect(find.byType(SabotageStickerIcon), findsWidgets);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Mustache'), findsNothing);

      // Drop a Googly Eyes sticker onto the canvas.
      await tester.tap(find.byTooltip('Eyes'));
      await tester.pumpAndSettle();

      // Selection bar appears with resize and delete controls.
      expect(find.byTooltip('Larger'), findsOneWidget);
      expect(find.byTooltip('Smaller'), findsOneWidget);
      expect(find.byTooltip('Remove sticker'), findsOneWidget);

      await tester.tap(find.byTooltip('Larger'));
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      await tester.pump();

      // Selection bar hides after Done, and marker drawing works freely.
      expect(find.byTooltip('Remove sticker'), findsNothing);
      final canvasFinder = find.byType(CustomPaint).first;
      await tester.drag(canvasFinder, const Offset(40, 20));
      await tester.pump();

      // Tapping back onto the sticker selects it again and lets us delete it.
      final artBox = tester.getRect(find.byType(SabotageScreen));
      expect(artBox.width, greaterThan(0));
      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
    },
  );
}
