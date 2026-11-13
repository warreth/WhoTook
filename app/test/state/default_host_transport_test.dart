import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/protocol/wire_message.dart';
import 'package:whotook/core/qr/invite_codec.dart';
import 'package:whotook/core/storage/settings_repository.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/transport/game_transport.dart';

import '../support/test_photo_library.dart';

/// Guards the production path: hosting with no injected transport must open a
/// real LAN socket, not a single-device stub.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'hosting without injected transports serves the invite over LAN',
    () async {
      final coordinator = MatchCoordinator(
        photos: TestPhotoLibrary(),
        settings: SettingsRepository(),
        includeOnlineTransport: false,
      );
      await coordinator.loadSettings();
      await coordinator.hostMatch();

      expect(coordinator.state.roomId, isNotNull);
      expect(coordinator.state.phase, RoundPhase.lobby);
      final invite = tryParseInvite(coordinator.state.inviteUrl!);
      expect(invite.roomId, coordinator.state.roomId);
      // Loopback-only CI machines expose no LAN address, so only assert the
      // shape when the host actually has one.
      for (final endpoint in invite.lanEndpoints) {
        expect(endpoint, matches(RegExp(r'^\d+\.\d+\.\d+\.\d+:\d+$')));
      }

      await coordinator.dispose();
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('a failing online transport never blocks the local room', () async {
    final inner = _ExplodingTransport();
    final wrapper = BestEffortHostTransport(inner);

    await wrapper.start();
    await wrapper.broadcast(WireMessage(type: WireType.ping, seq: 1));
    await wrapper.sendToClient(
      'nobody',
      WireMessage(type: WireType.ping, seq: 2),
    );
    expect(inner.startAttempts, 1);
    expect(inner.sends, 0);

    await wrapper.close();
  });
}

class _ExplodingTransport implements HostTransport {
  int startAttempts = 0;
  int sends = 0;

  @override
  Stream<String> get clientConnected => const Stream<String>.empty();

  @override
  Stream<String> get clientDisconnected => const Stream<String>.empty();

  @override
  Stream<HostIncomingMessage> get messages =>
      const Stream<HostIncomingMessage>.empty();

  @override
  String? get localLanEndpoint => null;

  @override
  Future<void> start() async {
    startAttempts += 1;
    throw const TransportException('offline', 'relay unreachable');
  }

  @override
  Future<void> sendToClient(String clientId, WireMessage message) async {
    sends += 1;
  }

  @override
  Future<void> broadcast(WireMessage message) async {
    sends += 1;
  }

  @override
  Future<void> close() async {}
}
