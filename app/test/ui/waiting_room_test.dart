import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/storage/settings_repository.dart';
import 'package:whotook/core/theme/whotook_theme.dart';
import 'package:whotook/l10n/l10n.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/state/providers.dart';
import 'package:whotook/ui/screens/waiting_room_screen.dart';

import '../support/fonts.dart';
import '../support/test_photo_library.dart';

Uint8List _photo() => File('test/ui/fixtures/party-dog.jpg').readAsBytesSync();

Future<void> _settleImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  });
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await loadTestFonts();
  });

  testWidgets('a waiting player spectates the running round', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    final photo = _photo();
    await tester.runAsync(() async {
      final stream = MemoryImage(photo).resolve(ImageConfiguration.empty);
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

    final coordinator = MatchCoordinator(
      photos: TestPhotoLibrary(),
      settings: SettingsRepository(),
    );
    addTearDown(coordinator.dispose);
    const state = MatchUiState(
      waitingForMatch: true,
      roomId: 'abc12345',
      currentRound: 2,
      totalRounds: 10,
      phase: RoundPhase.guessing,
      activeMode: GameMode.classic,
      activePhotoId: 'photo-1',
      phaseDurationMs: 8000,
      remainingMs: 5000,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchCoordinatorProvider.overrideWithValue(coordinator),
          matchStateProvider.overrideWith(
            (ref) => Stream<MatchUiState>.value(
              state.copyWith(activePhotoBytes: photo),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildWhoTookTheme(Brightness.light),
          home: const WaitingRoomScreen(),
        ),
      ),
    );
    await tester.pump();
    await _settleImages(tester);

    expect(find.text('Match in progress'), findsOneWidget);
    expect(find.text('Watching round 2 of 10'), findsOneWidget);
    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('ROOM abc12345'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(WaitingRoomScreen),
      matchesGoldenFile('goldens/waiting-room.png'),
    );
  });
}
