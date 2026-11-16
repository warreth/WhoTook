import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/party_pass/room_theme.dart';
import 'package:whotook/core/party_pass/sound_effect.dart';
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
  late MatchCoordinator client;
  late String inviteUrl;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    hub = LoopbackHub();
    host = MatchCoordinator(
      photos: TestPhotoLibrary(seed: 1),
      settings: SettingsRepository(),
      hostTransportFactory: (roomId, secret, lan) => LoopbackHostTransport(hub),
      includeOnlineTransport: false,
      countdownDuration: Duration.zero,
    );
    await host.loadSettings();
    host.updatePartyPass(active: true);
    client = MatchCoordinator(
      photos: TestPhotoLibrary(seed: 2),
      settings: SettingsRepository(),
      lastRooms: LastRoomRepository(storageKey: 'whotook.test.party-pass'),
      playerIdOverride: 'p2',
      playerTokenOverride: 'token-p2',
      connector: HybridConnector(
        onlineClientFactory: () => LoopbackClientTransport(hub),
      ),
      countdownDuration: Duration.zero,
    );
    await client.loadSettings();
    client.updatePartyPass(active: true);

    await host.hostMatch();
    inviteUrl = host.state.inviteUrl!;
    await client.joinMatch(inviteUrl);
    await _waitFor(() => host.state.players.length == 2);
  });

  tearDown(() async {
    await client.dispose();
    await host.dispose();
    await hub.dispose();
  });

  test('a shared premium theme reaches every phone', () async {
    expect(host.state.roomThemeId, RoomThemeIds.classicParty);

    await host.setRoomTheme(RoomThemeId.cyberNeon);
    await _waitFor(() => client.state.roomThemeId == RoomThemeIds.cyberNeon);

    expect(host.state.roomThemeId, RoomThemeIds.cyberNeon);
    expect(client.state.roomThemeId, RoomThemeIds.cyberNeon);
  });

  test(
    'a Party Pass holder on the client can change the shared theme',
    () async {
      await client.setRoomTheme(RoomThemeId.pubKroeg);
      await _waitFor(() => host.state.roomThemeId == RoomThemeIds.pubKroeg);
      await _waitFor(() => client.state.roomThemeId == RoomThemeIds.pubKroeg);
    },
  );

  test('a host sound reaches the client and is rate limited', () async {
    host.playSoundEffect(PartySound.airhorn);
    await _waitFor(
      () => client.state.lastSoundEffect?.sound == PartySound.airhorn,
    );
    final firstAt = host.state.lastSoundEffect!.atMs;

    host.playSoundEffect(PartySound.crickets);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(host.state.lastSoundEffect!.atMs, firstAt);
    expect(client.state.lastSoundEffect!.sound, PartySound.airhorn);
  });

  test('a client sound reaches the host and the other clients', () async {
    client.playSoundEffect(PartySound.sadTrombone);
    await _waitFor(
      () => host.state.lastSoundEffect?.sound == PartySound.sadTrombone,
    );
    expect(host.state.lastSoundEffect!.playerId, 'p2');
    expect(client.state.lastSoundEffect!.sound, PartySound.sadTrombone);
  });

  test('a host without a pass keeps a client-selected shared theme', () async {
    host.updatePartyPass(active: false);
    await client.setRoomTheme(RoomThemeId.midnightArcade);
    await _waitFor(() => host.state.roomThemeId == RoomThemeIds.midnightArcade);

    host.updatePartyPass(active: false);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(host.state.roomThemeId, RoomThemeIds.midnightArcade);
    expect(client.state.roomThemeId, RoomThemeIds.midnightArcade);
  });

  test('a client without the pass cannot start a premium theme', () async {
    client.updatePartyPass(active: false);
    await client.setRoomTheme(RoomThemeId.retroPolaroid);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(host.state.roomThemeId, RoomThemeIds.classicParty);
    expect(client.state.roomThemeId, RoomThemeIds.classicParty);
  });
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
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
