import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/storage/settings_repository.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/transport/game_transport.dart';
import 'package:whotook/transport/hybrid_connector.dart';

import '../support/test_photo_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LoopbackHub hub;
  late MatchCoordinator host;
  late MatchCoordinator clientOne;
  late MatchCoordinator clientTwo;
  late String inviteUrl;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    hub = LoopbackHub();
    host = MatchCoordinator(
      photos: TestPhotoLibrary(seed: 1),
      settings: SettingsRepository(),
      hostTransportFactory: (roomId, secret, lan) => LoopbackHostTransport(hub),
      roundDuration: const Duration(milliseconds: 900),
      countdownDuration: Duration.zero,
      revealDuration: const Duration(milliseconds: 40),
      extendWindow: const Duration(milliseconds: 300),
    );
    await host.loadSettings();

    clientOne = _client(hub, seed: 2);
    clientTwo = _client(hub, seed: 3);
    await clientOne.loadSettings();
    await clientTwo.loadSettings();

    await host.hostMatch();
    inviteUrl = host.state.inviteUrl!;
    await clientOne.joinMatch(inviteUrl);
    await clientTwo.joinMatch(inviteUrl);
    await _waitFor(() => host.state.players.length == 3);
  });

  tearDown(() async {
    await clientOne.dispose();
    await clientTwo.dispose();
    await host.dispose();
    await hub.dispose();
  });

  /// Brings every phone to the guessing screen for the current round.
  Future<void> prepareAndStart({int rounds = 3}) async {
    await host.setRounds(rounds);
    await host.startPrepare();
    await _waitFor(() => host.state.candidates.isNotEmpty);
    await _waitFor(() => clientOne.state.candidates.isNotEmpty);
    await _waitFor(() => clientTwo.state.candidates.isNotEmpty);

    await host.markLocalReady();
    await clientOne.clientMarkReady();
    await clientTwo.clientMarkReady();
    await _waitFor(() => host.state.phase == RoundPhase.guessing);
  }

  Future<void> guessEverywhere() async {
    final ids = host.state.activeRoundOptions.map((p) => p.id).toList();
    for (final id in ids) {
      if (id == 'host') continue;
      // The owner still taps a name so a glance at the screen reveals nothing.
    }
    await host.submitGuess(ids.first);
    await clientOne.clientSubmitGuess(ids.first);
    await clientTwo.clientSubmitGuess(ids.first);
    await _waitFor(
      () =>
          host.state.phase == RoundPhase.reveal ||
          host.state.phase == RoundPhase.countdown ||
          host.state.phase == RoundPhase.podium,
    );
  }

  Future<void> playUntilPodium({int maxRounds = 12}) async {
    var guard = 0;
    while (host.state.phase != RoundPhase.podium && guard < maxRounds) {
      guard += 1;
      await _waitFor(
        () =>
            host.state.phase == RoundPhase.guessing ||
            host.state.phase == RoundPhase.podium,
      );
      if (host.state.phase == RoundPhase.podium) break;
      await guessEverywhere();
      if (host.state.phase == RoundPhase.reveal) {
        await _waitFor(() => host.state.phase != RoundPhase.reveal);
      }
    }
  }

  test('three players play a full match and land on the podium', () async {
    expect(host.state.players, hasLength(3));
    expect(clientOne.state.players, hasLength(3));

    await prepareAndStart(rounds: 3);

    expect(host.state.photosNeeded, greaterThanOrEqualTo(3));
    expect(host.state.localReady, isTrue);
    expect(clientOne.state.localReady, isTrue);

    await playUntilPodium();

    expect(host.state.phase, RoundPhase.podium);
    expect(host.state.awards, isNotEmpty);
    expect(
      host.state.awards.map((a) => a.kind),
      contains(MatchAwardKind.champion),
    );
    expect(clientOne.state.phase, RoundPhase.podium);
    expect(clientOne.state.awards, isNotEmpty);
    expect(
      clientOne.state.awards.map((a) => a.kind),
      contains(MatchAwardKind.champion),
    );
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('host can extend the match and the extra rounds are played', () async {
    await prepareAndStart(rounds: 2);
    await playUntilPodium();
    expect(host.state.phase, RoundPhase.podium);
    final roundsBefore = host.state.totalRounds;

    await host.extendMatch(extraRounds: 2, extraPhotos: 2);
    await _waitFor(() => clientOne.state.phase == RoundPhase.extendPrompt);
    expect(clientOne.state.extensionSecondsLeft, greaterThan(0));

    await _waitFor(() => clientOne.state.extensionCandidates.isNotEmpty);
    await _waitFor(() => clientTwo.state.extensionCandidates.isNotEmpty);
    await clientOne.clientApproveExtension();
    await clientTwo.clientApproveExtension();
    await host.approveExtension();

    await _waitFor(() => host.state.totalRounds > roundsBefore);
    await playUntilPodium();

    expect(host.state.phase, RoundPhase.podium);
    expect(host.state.totalRounds, greaterThan(roundsBefore));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a screenshot alert reaches every phone', () async {
    await prepareAndStart(rounds: 2);

    await clientOne.notifyScreenshot();
    await _waitFor(() => host.state.screenshotAlerts.isNotEmpty);
    expect(host.state.screenshotAlerts.last.playerName, isNotEmpty);

    await _waitFor(() => clientTwo.state.screenshotAlerts.isNotEmpty);
    expect(clientTwo.state.screenshotAlerts.last.playerId, 'c_loop0');
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('plant a photo is offered only while others are still choosing', () async {
    await host.setRounds(2);
    await host.startPrepare();
    await _waitFor(() => host.state.candidates.isNotEmpty);

    // Nobody ready yet: the plant window is closed.
    expect(host.state.plantUnlocked, isFalse);

    await host.markLocalReady();
    await _waitFor(() => host.state.plantUnlocked);
    expect(host.state.plantUnlocked, isTrue);

    await host.plantSecretPhoto(
      host.state.candidates.first.localAssetId,
      host.state.candidates.first.bytes!,
    );
    expect(host.state.plantUsed, isTrue);

    // Using it twice must be refused by the engine.
    await expectLater(
      host.plantSecretPhoto(
        host.state.candidates.first.localAssetId,
        host.state.candidates.first.bytes!,
      ),
      completes,
    );
    expect(host.state.errorMessage, contains('once per game'));
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('own photo guess pays the fixed bonus and keeps the streak', () async {
    await prepareAndStart(rounds: 3);

    RoundReveal? hostOwned;
    for (var round = 0; round < 6; round++) {
      await _waitFor(
        () =>
            host.state.phase == RoundPhase.guessing ||
            host.state.phase == RoundPhase.podium,
      );
      if (host.state.phase == RoundPhase.podium) break;

      final other = host.state.activeRoundOptions
          .firstWhere((p) => p.id != 'host')
          .id;
      await host.submitGuess('host');
      await clientOne.clientSubmitGuess(other);
      await clientTwo.clientSubmitGuess(other);

      await _waitFor(
        () =>
            host.state.phase == RoundPhase.reveal ||
            host.state.phase == RoundPhase.podium,
      );
      final reveal = host.state.lastReveal;
      if (reveal != null && reveal.ownerId == 'host') {
        hostOwned = reveal;
        break;
      }
      await _waitFor(() => host.state.phase != RoundPhase.reveal);
    }

    expect(hostOwned, isNotNull, reason: 'the host photo should come up');
    final own = hostOwned!.guesses.firstWhere((g) => g.playerId == 'host');
    expect(own.isOwnPhoto, isTrue);
    expect(own.pointsAwarded, 300);
    expect(host.state.players.firstWhere((p) => p.id == 'host').streak,
        greaterThan(0));
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('play again returns everyone to a clean lobby', () async {
    await prepareAndStart(rounds: 1);
    await playUntilPodium();
    expect(host.state.phase, RoundPhase.podium);

    await host.playAgain();
    await _waitFor(() => host.state.phase == RoundPhase.lobby);
    expect(host.state.players, hasLength(3));
    expect(host.state.awards, isEmpty);
    expect(host.state.currentRound, 0);
  }, timeout: const Timeout(Duration(seconds: 60)));
}

MatchCoordinator _client(LoopbackHub hub, {required int seed}) =>
    MatchCoordinator(
      photos: TestPhotoLibrary(seed: seed),
      settings: SettingsRepository(),
      connector: HybridConnector(
        onlineClientFactory: () => LoopbackClientTransport(hub),
      ),
      roundDuration: const Duration(milliseconds: 900),
      countdownDuration: Duration.zero,
      revealDuration: const Duration(milliseconds: 40),
      extendWindow: const Duration(milliseconds: 300),
    );

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
