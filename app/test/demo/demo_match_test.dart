import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/storage/last_room_repository.dart';
import 'package:whotook/core/storage/settings_repository.dart';
import 'package:whotook/demo/demo_match_controller.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/transport/game_transport.dart';

import '../support/test_photo_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'demo starts the real host, fills the room and readies three bots',
    () async {
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

      await controller.start();
      expect(controller.host.platformServices, isFalse);
      expect(controller.host.state.isHosting, isTrue);
      expect(controller.host.state.roomId, isNotNull);
      expect(controller.host.state.players, hasLength(4));

      await controller.host.startPrepare();
      await _waitFor(
        () =>
            controller.host.state.phase == RoundPhase.preparing &&
            controller.host.state.players
                .where((player) => !player.isHost)
                .every((player) => player.ready),
      );
      expect(controller.host.state.players, hasLength(4));

      await controller.host.markLocalReady();
      await _waitFor(
        () =>
            controller.host.state.phase == RoundPhase.guessing ||
            controller.host.state.phase == RoundPhase.countdown,
      );
      expect(controller.host.state.currentRound, 1);
      expect(controller.host.state.players, hasLength(4));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'the demo host never waits for screenshot or wake-lock services',
    () async {
      var wakeCalls = 0;
      final hub = LoopbackHub();
      final host = MatchCoordinator(
        photos: TestPhotoLibrary(seed: 4),
        settings: SettingsRepository(),
        lastRooms: LastRoomRepository.memory(),
        hostTransportFactory: (room, secret, lan) => LoopbackHostTransport(hub),
        includeOnlineTransport: false,
        platformServices: false,
        wakeLock: (awake) async {
          wakeCalls += 1;
        },
      );
      addTearDown(() async {
        await host.dispose();
        await hub.dispose();
      });

      await host.hostMatch(
        config: const MatchConfig(
          roundsK: 1,
          roundSeconds: 4,
          mode: GameMode.classic,
          pace: GamePace.fast,
        ),
      );

      expect(host.state.isHosting, isTrue);
      expect(host.state.roomId, isNotNull);
      expect(wakeCalls, 0);
    },
  );

  test(
    'demo mixed party fills the dynamic vault and starts round one',
    () async {
      final controller = DemoMatchController(
        baseSettings: const AppSettings(nickname: 'Bram'),
        config: const MatchConfig(
          roundsK: 5,
          roundSeconds: 4,
          mode: GameMode.mixedParty,
          pace: GamePace.fast,
        ),
        countdownDuration: Duration.zero,
        revealDuration: const Duration(milliseconds: 50),
        captionRevealDuration: const Duration(milliseconds: 50),
        roundDuration: const Duration(milliseconds: 400),
      );
      addTearDown(controller.dispose);

      await controller.start();
      await controller.host.startPrepare();
      expect(controller.host.state.photosNeeded, 9);
      await _waitFor(
        () =>
            controller.host.state.phase == RoundPhase.preparing &&
            controller.host.state.players
                .where((player) => !player.isHost)
                .every((player) => player.ready),
      );
      await controller.host.markLocalReady();
      await _waitFor(
        () =>
            controller.host.state.currentRound == 1 &&
            controller.host.state.phase != RoundPhase.preparing,
      );
      expect(controller.host.state.players, hasLength(4));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}
