import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/constants.dart';
import 'package:whotook/core/media/photo_memory_cache.dart';
import 'package:whotook/core/media/photo_service.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/storage/last_room_repository.dart';
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
      planterOverride: 'host',
      roundDuration: const Duration(milliseconds: 900),
      countdownDuration: Duration.zero,
      vaultFallbackDelay: const Duration(milliseconds: 250),
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

  test('host can remove a player from the lobby', () async {
    final targetId = clientOne.state.localPlayerId;
    expect(targetId, isNotNull);
    expect(host.state.players.any((p) => p.id == targetId), isTrue);

    await host.kickPlayer(targetId!);
    await _waitFor(() => host.state.players.length == 2);
    await _waitFor(() => clientOne.state.roomId == null);

    expect(host.state.players.any((p) => p.id == targetId), isFalse);
    expect(clientOne.state.errorMessage, contains('removed'));
  });

  test('client timers follow the host clock', () async {
    await prepareAndStart(rounds: 2);
    final before = clientOne.state.remainingMs;
    expect(before, greaterThan(0));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(clientOne.state.remainingMs, lessThan(before));
  });

  test('client scoreboard matches the host after a reveal', () async {
    await prepareAndStart(rounds: 2);
    await guessEverywhere();
    await _waitFor(() => clientOne.state.lastReveal != null);
    await _waitFor(() => host.state.lastReveal != null);

    for (final hostPlayer in host.state.players) {
      final mirror = clientOne.state.players.firstWhere(
        (player) => player.id == hostPlayer.id,
      );
      expect(mirror.score, hostPlayer.score, reason: hostPlayer.id);
    }
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('a screenshot alert reaches every phone', () async {
    await prepareAndStart(rounds: 2);

    await clientOne.notifyScreenshot();
    await _waitFor(() => host.state.screenshotAlerts.isNotEmpty);
    expect(host.state.screenshotAlerts.last.playerName, isNotEmpty);

    await _waitFor(() => clientTwo.state.screenshotAlerts.isNotEmpty);
    expect(
      clientTwo.state.screenshotAlerts.last.playerId,
      clientOne.state.localPlayerId,
    );
  }, timeout: const Timeout(Duration(seconds: 45)));

  test(
    'plant a photo is offered only while others are still choosing',
    () async {
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
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );

  test('own photo guess scores like a normal correct guess', () async {
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
    expect(own.isCorrect, isTrue);
    expect(own.pointsAwarded, greaterThanOrEqualTo(500));
    expect(
      host.state.players.firstWhere((p) => p.id == 'host').streak,
      greaterThan(0),
    );
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('home preset rounds and timer update before hosting', () async {
    final draft = MatchCoordinator(
      photos: TestPhotoLibrary(seed: 9),
      settings: SettingsRepository(),
      includeOnlineTransport: false,
      countdownDuration: Duration.zero,
    );
    await draft.loadSettings();

    await draft.setRounds(6);
    await draft.setRoundSeconds(4);

    expect(draft.state.config.roundsK, 6);
    expect(draft.state.config.roundSeconds, 4);
    await draft.dispose();
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('client plant unlocks while another player is still choosing', () async {
    await host.setRounds(2);
    await host.startPrepare();
    await _waitFor(() => host.state.candidates.isNotEmpty);
    await _waitFor(() => clientOne.state.candidates.isNotEmpty);

    expect(clientOne.state.plantUnlocked, isFalse);
    await clientOne.clientMarkReady();
    await _waitFor(() => clientOne.state.localReady);
    await _waitFor(() => clientOne.state.plantUnlocked);

    expect(clientOne.state.plantUnlocked, isTrue);
    expect(host.state.players.any((p) => !p.ready), isTrue);
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('client extension photos reach the host deck with bytes', () async {
    await prepareAndStart(rounds: 2);
    await playUntilPodium();
    expect(host.state.phase, RoundPhase.podium);
    final roundsBefore = host.state.totalRounds;
    final clientId = clientOne.state.localPlayerId!;

    await host.extendMatch(extraRounds: 3, extraPhotos: 2);
    await _waitFor(() => clientOne.state.extensionCandidates.isNotEmpty);
    await _waitFor(() => clientTwo.state.extensionCandidates.isNotEmpty);

    await clientOne.clientApproveExtension();
    await clientTwo.clientApproveExtension();
    await host.approveExtension();
    await _waitFor(() => host.state.totalRounds > roundsBefore);

    final extensionEntries = host.engine!.deck
        .where((entry) => entry.roundNumber > roundsBefore)
        .where((entry) => entry.ownerId == clientId)
        .toList();
    expect(extensionEntries, hasLength(1));
    expect(extensionEntries.single.photo.bytes, isNotNull);
    expect(extensionEntries.single.photo.bytes, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('client planted photo reaches the host deck with bytes', () async {
    final plantHub = LoopbackHub();
    final plantHost = MatchCoordinator(
      photos: _TwoPhotoLibrary(),
      settings: SettingsRepository(),
      hostTransportFactory: (roomId, secret, lan) =>
          LoopbackHostTransport(plantHub),
      planterOverride: 'c_loop0',
      roundDuration: const Duration(milliseconds: 900),
      countdownDuration: Duration.zero,
      revealDuration: const Duration(milliseconds: 40),
      extendWindow: const Duration(milliseconds: 300),
    );
    final plantClient = MatchCoordinator(
      photos: _TwoPhotoLibrary(),
      settings: SettingsRepository(),
      playerIdOverride: 'c_loop0',
      playerTokenOverride: 'plant-token',
      connector: HybridConnector(
        onlineClientFactory: () => LoopbackClientTransport(plantHub),
      ),
      roundDuration: const Duration(milliseconds: 900),
      countdownDuration: Duration.zero,
      revealDuration: const Duration(milliseconds: 40),
      extendWindow: const Duration(milliseconds: 300),
    );
    await plantHost.loadSettings();
    await plantClient.loadSettings();

    await plantHost.hostMatch();
    await plantClient.joinMatch(plantHost.state.inviteUrl!);
    await _waitFor(() => plantHost.state.players.length == 2);

    await plantHost.setRounds(4);
    await plantHost.startPrepare();
    await _waitFor(() => plantHost.state.candidates.isNotEmpty);
    await _waitFor(() => plantClient.state.candidates.isNotEmpty);
    expect(plantHost.state.candidates, hasLength(2));
    expect(plantClient.state.candidates, hasLength(2));

    await plantClient.clientMarkReady();
    await _waitFor(() => plantClient.state.plantUnlocked);
    await _waitFor(
      () => plantHost.state.players
          .where((player) => player.id == plantClient.state.localPlayerId)
          .every((player) => player.ready),
    );
    await plantClient.clientPlantPickedPhoto(
      plantClient.state.candidates.first,
    );
    await _waitFor(() => plantClient.state.plantUsed);
    await _waitFor(
      () =>
          plantHost.engine!
              .player(plantClient.state.localPlayerId!)
              ?.plantUsed ==
          true,
    );

    await plantHost.markLocalReady();
    await _waitFor(() => plantHost.state.phase == RoundPhase.guessing);

    final planted = plantHost.engine!.deck
        .where(
          (entry) =>
              entry.ownerId == plantClient.state.localPlayerId &&
              entry.photo.isPlanted,
        )
        .toList();
    expect(planted, hasLength(1));
    expect(planted.single.photo.bytes, isNotNull);
    expect(planted.single.photo.bytes, isNotEmpty);

    await plantClient.dispose();
    await plantHost.dispose();
    await plantHub.dispose();
  }, timeout: const Timeout(Duration(seconds: 45)));

  test(
    'Caption This runs from writing to anonymous voting to reveal',
    () async {
      await host.setMode(GameMode.captionThis);
      await _waitFor(() => clientOne.state.config.mode == GameMode.captionThis);
      await host.startPrepare();
      await _waitFor(() => host.state.candidates.isNotEmpty);
      await _waitFor(() => clientOne.state.candidates.isNotEmpty);
      await _waitFor(() => clientTwo.state.candidates.isNotEmpty);
      await host.markLocalReady();
      await clientOne.clientMarkReady();
      await clientTwo.clientMarkReady();
      await _waitFor(() => host.state.phase == RoundPhase.captionWriting);

      await host.submitCaption('host caption');
      await clientOne.clientSubmitCaption('one caption');
      await clientTwo.clientSubmitCaption('two caption');
      await _waitFor(() => host.state.phase == RoundPhase.captionVoting);
      await _waitFor(() => clientOne.state.captionOptions.isNotEmpty);
      await _waitFor(() => clientTwo.state.captionOptions.isNotEmpty);

      expect(host.state.captionOptions, hasLength(3));
      expect(clientOne.state.captionOptions, hasLength(3));
      expect(clientOne.state.ownCaptionId, isNotNull);
      final hostVote = host.state.captionOptions.firstWhere(
        (option) => option.id != host.state.ownCaptionId,
      );
      final clientVote = clientOne.state.captionOptions.firstWhere(
        (option) => option.id != clientOne.state.ownCaptionId,
      );
      final clientTwoVote = clientTwo.state.captionOptions.first;
      await host.voteCaption(hostVote.id);
      await clientOne.clientVoteCaption(clientVote.id);
      await clientTwo.clientVoteCaption(clientTwoVote.id);

      await _waitFor(() => host.state.phase == RoundPhase.captionReveal);
      await _waitFor(() => clientOne.state.phase == RoundPhase.captionReveal);
      final reveal = host.state.lastCaptionReveal;
      expect(reveal, isNotNull);
      expect(reveal!.entries, hasLength(3));
      expect(
        reveal.entries.map((entry) => entry.authorName),
        contains('Player'),
      );
      expect(reveal.scoreDeltas.values.any((value) => value > 0), isTrue);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test('legacy Time Traveler config safely falls back to Classic', () async {
    final fallback = MatchConfig.fromJson(const <String, dynamic>{
      'roundsK': 6,
      'roundSeconds': 8,
      'mode': 'timeTraveler',
      'pace': 'normal',
    });
    expect(fallback.mode, GameMode.classic);
    expect(fallback.needsPhotoDates, isFalse);

    await host.setMode(fallback.mode);
    await _waitFor(() => clientOne.state.config.mode == GameMode.classic);
    await host.startPrepare();
    await _waitFor(() => host.state.candidates.isNotEmpty);
    await _waitFor(() => clientOne.state.candidates.isNotEmpty);
    await _waitFor(() => clientTwo.state.candidates.isNotEmpty);
    await host.markLocalReady();
    await clientOne.clientMarkReady();
    await clientTwo.clientMarkReady();
    await _waitFor(() => host.state.phase == RoundPhase.guessing);

    final guessTarget = host.state.players.first.id;
    await host.submitGuess(guessTarget);
    await clientOne.clientSubmitGuess(guessTarget);
    await clientTwo.clientSubmitGuess(guessTarget);
    await _waitFor(() => host.state.phase == RoundPhase.reveal);
    expect(host.state.lastReveal, isNotNull);
    expect(clientOne.state.lastReveal, isNotNull);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the host can skip a stuck round', () async {
    await prepareAndStart(rounds: 2);
    await _waitFor(() => host.state.phase == RoundPhase.guessing);
    await host.skipRound();
    await _waitFor(
      () =>
          host.state.phase == RoundPhase.reveal ||
          host.state.phase == RoundPhase.countdown ||
          host.state.phase == RoundPhase.podium,
    );
    expect(host.state.phase, isNot(RoundPhase.guessing));
  });

  test('the host can reveal captions before every vote', () async {
    await host.setMode(GameMode.captionThis);
    await _waitFor(() => clientOne.state.config.mode == GameMode.captionThis);
    await host.startPrepare();
    await _waitFor(() => host.state.candidates.isNotEmpty);
    await _waitFor(() => clientOne.state.candidates.isNotEmpty);
    await _waitFor(() => clientTwo.state.candidates.isNotEmpty);
    await host.markLocalReady();
    await clientOne.clientMarkReady();
    await clientTwo.clientMarkReady();
    await _waitFor(() => host.state.phase == RoundPhase.captionWriting);
    await host.submitCaption('host');
    await clientOne.clientSubmitCaption('one');
    await clientTwo.clientSubmitCaption('two');
    await _waitFor(() => host.state.phase == RoundPhase.captionVoting);
    await host.revealCaptionNow();
    await _waitFor(() => host.state.phase == RoundPhase.captionReveal);
    expect(host.state.lastCaptionReveal, isNotNull);
  });

  test('the host can remove a player during a round', () async {
    await prepareAndStart(rounds: 2);
    await _waitFor(() => host.state.phase == RoundPhase.guessing);
    await host.kickPlayer('p2');
    await _waitFor(
      () =>
          clientOne.state.roomId == null &&
          clientOne.state.errorMessage != null,
    );
    expect(
      host.state.players.firstWhere((player) => player.id == 'p2').connected,
      isFalse,
    );
    expect(clientOne.state.errorMessage, contains('removed'));
  });

  test('the last joined room survives a restart', () async {
    final store = LastRoomRepository(storageKey: 'whotook.test.room.2');
    LastRoom? room;
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (room == null && DateTime.now().isBefore(deadline)) {
      room = await store.load();
      if (room == null) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
    expect(room, isNotNull);
    expect(room!.roomId, clientOne.state.roomId);
    expect(room.inviteUrl, isNotEmpty);

    await clientOne.leaveMatch();
    expect(await store.load(), isNull);
  });

  test('a photo avatar travels with the player into the room', () async {
    final repo = SettingsRepository();
    await repo.save(
      const AppSettings(
        nickname: 'PhotoSam',
        avatar: 'photo',
        avatarPhoto: 'abc',
        onboardingCompleted: true,
      ),
    );
    final avatarClient = MatchCoordinator(
      photos: TestPhotoLibrary(seed: 31),
      settings: repo,
      lastRooms: LastRoomRepository(storageKey: 'whotook.test.avatar'),
      playerIdOverride: 'p-photo',
      playerTokenOverride: 'avatar-token',
      connector: HybridConnector(
        onlineClientFactory: () => LoopbackClientTransport(hub),
      ),
      roundDuration: const Duration(milliseconds: 900),
      countdownDuration: Duration.zero,
      revealDuration: const Duration(milliseconds: 40),
      extendWindow: const Duration(milliseconds: 300),
    );
    addTearDown(avatarClient.dispose);
    await avatarClient.loadSettings();
    await avatarClient.joinMatch(inviteUrl);
    await _waitFor(() => host.state.players.length == 4);
    await _waitFor(() => host.state.avatarPhotos['p-photo'] == 'abc');
    expect(host.state.avatarPhotos['p-photo'], 'abc');
  });

  test(
    'a newer semantic version warns the host and the older clients',
    () async {
      final newer = MatchCoordinator(
        photos: TestPhotoLibrary(seed: 22),
        settings: SettingsRepository(),
        connector: HybridConnector(
          onlineClientFactory: () => LoopbackClientTransport(hub),
        ),
        appVersion: '99.0.0',
        appBuild: 999,
        roundDuration: const Duration(milliseconds: 900),
        countdownDuration: Duration.zero,
        revealDuration: const Duration(milliseconds: 40),
        extendWindow: const Duration(milliseconds: 300),
      );
      addTearDown(newer.dispose);
      await newer.loadSettings();
      await newer.joinMatch(inviteUrl);
      await _waitFor(() => host.state.players.length == 4);
      await _waitFor(() => host.state.versionWarning != null);
      await _waitFor(() => clientOne.state.versionWarning != null);

      expect(host.state.versionWarning!.latestVersion, '99.0.0');
      expect(host.state.versionWarning!.ownVersion, kAppVersion);
      expect(clientOne.state.versionWarning!.latestVersion, '99.0.0');
      expect(
        clientOne.state.versionWarning!.latestVersion.split('+').first,
        '99.0.0',
      );
      expect(newer.state.versionWarning, isNull);

      host.dismissVersionWarning();
      expect(host.state.versionWarningDismissed, isTrue);
    },
  );

  test('joining after the lobby started waits for the next match', () async {
    await prepareAndStart(rounds: 2);
    final late = _client(hub, seed: 9);
    addTearDown(late.dispose);
    await late.loadSettings();
    await late.joinMatch(inviteUrl);
    await _waitFor(
      () =>
          late.state.waitingForMatch &&
          late.state.localPlayerId != null &&
          late.state.roomId != null,
    );
    expect(late.state.waitingForMatch, isTrue);
    expect(late.state.roomId, host.state.roomId);
    expect(host.state.players.length, 3);
    await _waitFor(() => late.state.currentRound > 0);
    expect(late.state.activeMode, host.state.activeMode);
    await _waitFor(() => late.state.activePhotoBytes != null);

    await host.playAgain();
    await _waitFor(
      () => !late.state.waitingForMatch && host.state.players.length == 4,
    );
    expect(late.state.phase, RoundPhase.lobby);
    expect(late.state.players.length, 4);

    await host.startPrepare();
    await _waitFor(() => late.state.candidates.isNotEmpty);
    expect(late.state.photosNeeded, greaterThan(0));
    await late.clientMarkReady();
    await _waitFor(
      () => host.state.players
          .firstWhere((player) => player.id == late.state.localPlayerId)
          .ready,
    );
  }, timeout: const Timeout(Duration(seconds: 45)));

  test(
    'late joiner exits waiting room at podium and joins extendMatch',
    () async {
      await prepareAndStart(rounds: 2);
      final late = _client(hub, seed: 10);
      addTearDown(late.dispose);
      await late.loadSettings();
      await late.joinMatch(inviteUrl);
      await _waitFor(() => late.state.waitingForMatch);
      expect(host.state.waitingPlayersCount, 1);

      await playUntilPodium();
      await _waitFor(
        () => late.state.phase == RoundPhase.podium && !late.state.waitingForMatch,
      );
      expect(late.state.waitingForMatch, isFalse);

      await host.extendMatch(extraRounds: 2, extraPhotos: 2);
      await _waitFor(() => late.state.phase == RoundPhase.extendPrompt);
      await _waitFor(() => late.state.extensionCandidates.isNotEmpty);
      expect(
        host.state.players.any((p) => p.id == late.state.localPlayerId),
        isTrue,
      );
      await clientOne.clientApproveExtension();
      await clientTwo.clientApproveExtension();
      await late.clientApproveExtension();
      await host.approveExtension();
      await _waitFor(() => late.state.phase == RoundPhase.guessing);
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );

  test('a client can rejoin the current round after a restart', () async {
    await prepareAndStart(rounds: 3);
    await _waitFor(() => host.state.phase == RoundPhase.guessing);
    final scoreBefore = host.state.players
        .firstWhere((player) => player.id == 'p2')
        .score;
    await clientOne.dispose();
    await _waitFor(
      () =>
          host.state.players
              .firstWhere((player) => player.id == 'p2')
              .connected ==
          false,
    );

    final restarted = _client(hub, seed: 2);
    addTearDown(restarted.dispose);
    await restarted.loadSettings();
    await restarted.joinMatch(inviteUrl);
    await _waitFor(
      () =>
          restarted.state.phase == RoundPhase.guessing &&
          restarted.state.activePhotoBytes != null,
    );
    expect(restarted.state.localPlayerId, 'p2');
    expect(restarted.state.players.length, 3);
    expect(
      restarted.state.players.firstWhere((player) => player.id == 'p2').score,
      scoreBefore,
    );
    expect(restarted.state.remainingMs, greaterThan(0));
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('a client reconnect restores the photo check set', () async {
    await host.setRounds(3);
    await host.startPrepare();
    await _waitFor(() => clientOne.state.candidates.isNotEmpty);
    await clientOne.clientMarkReady();
    await _waitFor(
      () => host.state.players.firstWhere((p) => p.id == 'p2').ready,
    );
    await clientOne.debugDropClientConnection();
    await _waitFor(() => clientOne.state.reconnecting);
    await _waitFor(
      () =>
          !clientOne.state.reconnecting &&
          clientOne.state.phase == RoundPhase.preparing &&
          clientOne.state.localReady,
    );
    expect(clientOne.state.candidates, isNotEmpty);
    expect(clientOne.state.localPlayerId, 'p2');
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('a client reconnect restores the caption vote screen', () async {
    await host.setMode(GameMode.captionThis);
    await _waitFor(() => clientOne.state.config.mode == GameMode.captionThis);
    await host.startPrepare();
    await _waitFor(() => host.state.candidates.isNotEmpty);
    await _waitFor(() => clientOne.state.candidates.isNotEmpty);
    await _waitFor(() => clientTwo.state.candidates.isNotEmpty);
    await host.markLocalReady();
    await clientOne.clientMarkReady();
    await clientTwo.clientMarkReady();
    await _waitFor(() => host.state.phase == RoundPhase.captionWriting);
    await host.submitCaption('Host caption');
    await clientOne.clientSubmitCaption('One caption');
    await clientTwo.clientSubmitCaption('Two caption');
    await _waitFor(() => host.state.phase == RoundPhase.captionVoting);
    await clientOne.debugDropClientConnection();
    await _waitFor(() => clientOne.state.reconnecting);
    await _waitFor(
      () =>
          !clientOne.state.reconnecting &&
          clientOne.state.phase == RoundPhase.captionVoting,
    );
    expect(clientOne.state.captionOptions, isNotEmpty);
    expect(clientOne.state.ownCaptionId, isNotNull);
    expect(clientOne.state.votedCaptionId, isNull);
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('three players build and vote on anonymous memes', () async {
    await host.setMode(GameMode.makeItMeme);
    await _waitFor(() => host.state.config.mode == GameMode.makeItMeme);
    await host.startPrepare();
    await _waitFor(() => host.state.candidates.isNotEmpty);
    await _waitFor(() => clientOne.state.candidates.isNotEmpty);
    await _waitFor(() => clientTwo.state.candidates.isNotEmpty);
    await host.markLocalReady();
    await clientOne.clientMarkReady();
    await clientTwo.clientMarkReady();
    await _waitFor(() => host.state.phase == RoundPhase.captionWriting);
    for (final photo in host.state.candidates) {
      expect(
        PhotoMemoryCache.instance.hasPhoto(photo.photoId),
        isTrue,
        reason: 'host photo ${photo.photoId} was not preloaded',
      );
      expect(
        PhotoMemoryCache.instance.hasPhoto(photo.photoId) ||
            clientOne.state.candidates.any(
              (candidate) => candidate.photoId == photo.photoId,
            ),
        isTrue,
      );
    }
    await _waitFor(() => host.state.memeAssignment != null);
    await _waitFor(() => clientOne.state.memeAssignment != null);
    await _waitFor(() => clientTwo.state.memeAssignment != null);
    expect(
      PhotoMemoryCache.instance.hasPhoto(host.state.memeAssignment!.photoId),
      isTrue,
    );
    expect(
      PhotoMemoryCache.instance.hasPhoto(
        clientOne.state.memeAssignment!.photoId,
      ),
      isTrue,
    );
    expect(host.state.memeSwapsLeft, 5);

    await clientOne.clientSwapMemePhoto();
    await _waitFor(() => clientOne.state.memeSwapsLeft == 4);
    expect(clientOne.state.memeAssignment?.photoId, isNotEmpty);
    expect(
      PhotoMemoryCache.instance.hasPhoto(
        clientOne.state.memeAssignment!.photoId,
      ),
      isTrue,
    );

    await host.submitMeme(
      template: MemeTemplate.classic,
      topText: 'Host top',
      bottomText: 'Host bottom',
      snapY: 48,
    );
    await clientOne.clientSubmitMeme(
      template: MemeTemplate.pov,
      topText: 'One top',
      bottomText: 'One bottom',
      snapY: 48,
    );
    await clientTwo.clientSubmitMeme(
      template: MemeTemplate.breaking,
      topText: 'Two top',
      bottomText: '',
      snapY: 48,
    );
    await _waitFor(() => host.state.phase == RoundPhase.captionVoting);
    await _waitFor(() => clientOne.state.memeCards.isNotEmpty);
    await _waitFor(() => clientTwo.state.memeCards.isNotEmpty);
    expect(
      host.state.memeCards.every((card) => card.photoBase64.isEmpty),
      isTrue,
    );
    expect(
      clientOne.state.memeCards.every((card) => card.photoBase64.isEmpty),
      isTrue,
    );
    expect(host.state.memeFocusId, isNotNull);
    expect(clientOne.state.memeFocusId, host.state.memeFocusId);
    expect(clientTwo.state.memeFocusId, host.state.memeFocusId);
    expect(clientOne.state.memeFocusEligible, greaterThanOrEqualTo(2));
    expect(host.state.memeCards, hasLength(3));
    expect(clientOne.state.memeCards.where((card) => card.isOwn), hasLength(1));
    expect(
      clientOne.state.memeCards.any((card) => card.authorName != null),
      isFalse,
    );

    void voteAll(MatchCoordinator coordinator) {
      for (final card in coordinator.state.memeCards) {
        if (card.isOwn) continue;
        final vote = coordinator == host
            ? coordinator.voteMeme(card.id, MemeVote.up)
            : coordinator.clientVoteMeme(card.id, MemeVote.up);
        unawaited(vote);
      }
    }

    voteAll(host);
    voteAll(clientOne);
    voteAll(clientTwo);
    await _waitFor(
      () => host.state.phase == RoundPhase.captionReveal,
      timeout: const Duration(seconds: 20),
    );
    await _waitFor(() => clientOne.state.phase == RoundPhase.captionReveal);
    expect(host.state.lastMemeReveal, isNotNull);
    expect(host.state.memeRevealCards, hasLength(3));
    expect(host.state.memeRevealCards.first.authorName, isNotNull);
    expect(host.state.topMemes, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('host fallback unlocks a vault missing one ready', () async {
    await host.startPrepare();
    await _waitFor(() => host.state.candidates.isNotEmpty);
    await _waitFor(() => clientOne.state.candidates.isNotEmpty);
    await _waitFor(() => clientTwo.state.candidates.isNotEmpty);
    await host.markLocalReady();
    await clientOne.clientMarkReady();
    await _waitFor(() => host.state.forceStartAvailable);
    expect(host.state.phase, RoundPhase.preparing);
    expect(clientTwo.state.localReady, isFalse);

    await host.forceStartMatch();
    await _waitFor(() => host.state.phase != RoundPhase.preparing);
    expect(host.state.currentRound, 1);
    expect(host.state.phase, anyOf(RoundPhase.countdown, RoundPhase.guessing));
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('host leaving ends the client room', () async {
    await host.leaveMatch();
    await _waitFor(
      () =>
          clientOne.state.roomId == null &&
          clientOne.state.errorMessage != null,
    );
    expect(clientOne.state.errorMessage, contains('host ended'));
  });

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
      lastRooms: LastRoomRepository(storageKey: 'whotook.test.room.$seed'),
      playerIdOverride: 'p$seed',
      playerTokenOverride: 'token-$seed',
      reconnectAttemptDelay: const Duration(milliseconds: 400),
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

/// Produces a short candidate list so a small deck deals every photo,
/// including whichever one the engine randomly planted.
class _TwoPhotoLibrary extends TestPhotoLibrary {
  _TwoPhotoLibrary() : super(seed: 11);

  @override
  Future<List<PickedPhoto>> sampleCandidates({
    required Set<String> excludedAlbumIds,
    required int count,
    Set<String> excludeAssetIds = const <String>{},
    bool requireDate = false,
  }) async {
    final all = await super.sampleCandidates(
      excludedAlbumIds: excludedAlbumIds,
      count: count,
      excludeAssetIds: excludeAssetIds,
      requireDate: requireDate,
    );
    return all.take(2).toList();
  }
}
