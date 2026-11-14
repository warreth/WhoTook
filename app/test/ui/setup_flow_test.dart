import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/app.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/platform/screenshot_detector.dart';
import 'package:whotook/core/storage/settings_repository.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/state/providers.dart';
import 'package:whotook/transport/game_transport.dart';
import 'package:whotook/ui/screens/lobby_screen.dart';
import 'package:whotook/ui/screens/prepare_screen.dart';
import 'package:whotook/ui/screens/setup/host_photos_screen.dart';
import 'package:whotook/ui/widgets/common.dart';

import '../support/test_photo_library.dart';

class _NoScreenshots extends ScreenshotDetector {
  @override
  Future<void> start(void Function() onScreenshot) async {}

  @override
  Future<void> stop() async {}
}

class _MemorySettings extends SettingsRepository {
  _MemorySettings(this.initial);

  final AppSettings initial;

  @override
  Future<AppSettings> load() async => initial;

  @override
  Future<void> save(AppSettings settings) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'host flow collects rounds, pace, mode and photos before the QR',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
      view.physicalSize = const Size(390, 844);
      view.devicePixelRatio = 1;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final settings = _MemorySettings(
        const AppSettings(nickname: 'Bram', onboardingCompleted: true),
      );
      final hub = LoopbackHub();
      final coordinator = MatchCoordinator(
        photos: TestPhotoLibrary(seed: 4),
        settings: settings,
        hostTransportFactory: (roomId, secret, lan) =>
            LoopbackHostTransport(hub),
        includeOnlineTransport: false,
        screenshots: _NoScreenshots(),
        wakeLock: (_) async {},
      );
      await coordinator.loadSettings();
      addTearDown(coordinator.dispose);
      addTearDown(hub.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settings),
            photoLibraryProvider.overrideWithValue(TestPhotoLibrary(seed: 4)),
            matchCoordinatorProvider.overrideWithValue(coordinator),
          ],
          child: const WhoTookApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Host a game'));
      await tester.pumpAndSettle();
      expect(find.text('How many rounds?'), findsOneWidget);
      expect(find.text('Step 1 of 4'), findsOneWidget);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next: pick the pace'));
      await tester.pumpAndSettle();
      expect(find.text('Pick the pace'), findsOneWidget);

      await tester.tap(find.text('Fast'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next: pick a mode'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the game'), findsOneWidget);

      await tester.tap(find.text('Time Traveler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next: your photos'));
      await tester.pumpAndSettle();

      expect(find.byType(HostPhotosScreen), findsOneWidget);
      expect(find.text('15 rounds'), findsOneWidget);
      expect(find.text('Fast 6s'), findsOneWidget);
      expect(find.text('Time Traveler'), findsOneWidget);
      expect(find.byType(NumberTag), findsNWidgets(4));
      expect(find.text('Open the room'), findsOneWidget);

      final beforeShuffle = coordinator.state.candidates.first.localAssetId;
      await tester.tap(find.text('Shuffle these frames'));
      await tester.pumpAndSettle();
      expect(find.byType(NumberTag), findsNWidgets(4));
      expect(
        coordinator.state.candidates.first.localAssetId,
        isNot(beforeShuffle),
      );

      await tester.tap(find.text('Open the room'));
      await tester.pumpAndSettle();

      expect(find.byType(LobbyScreen), findsOneWidget);
      expect(find.text('Scan to join'), findsOneWidget);
      expect(coordinator.state.roomId, isNotNull);
      expect(coordinator.state.config.roundsK, 15);
      expect(coordinator.state.config.roundSeconds, 6);
      expect(coordinator.state.config.mode, GameMode.timeTraveler);
      expect(coordinator.state.candidates, hasLength(4));

      await tester.tap(find.text('Start photo check'));
      await tester.pumpAndSettle();

      expect(find.byType(PrepareScreen), findsOneWidget);
      expect(find.text('Check your photos'), findsOneWidget);
      expect(coordinator.state.candidates, hasLength(16));
      expect(find.byType(NumberTag), findsNWidgets(16));
      expect(
        find.text(
          'All 16 photos for this match are here. Reroll all for a different set.',
        ),
        findsOneWidget,
      );
    },
  );
}
