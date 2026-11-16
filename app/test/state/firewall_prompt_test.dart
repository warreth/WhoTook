import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/constants.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/qr/invite_codec.dart';
import 'package:whotook/core/storage/settings_repository.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/transport/game_transport.dart';
import 'package:whotook/transport/hybrid_connector.dart';
import 'package:whotook/transport/webrtc_transport.dart';

import '../support/test_photo_library.dart';

class _RelayFailingConnector extends HybridConnector {
  _RelayFailingConnector({required this.passActive});

  final bool passActive;

  @override
  Future<ClientTransport> connect({
    required InvitePayload invite,
    required AppSettings settings,
  }) async {
    throw RelayRequiredException(
      passActive: passActive,
      relayErrorCode: passActive ? 'relay_unavailable' : null,
    );
  }
}

String _invite() => encodeInviteUrl(
  const InvitePayload(
    roomId: 'room1234',
    hostId: 'host',
    secret: 'secret-AbCdEf0123456789',
    signalingUrl: 'https://signal.example',
  ),
  baseUrl: kInviteBaseUrl,
);

MatchCoordinator _coordinator({required bool passActive}) => MatchCoordinator(
  photos: TestPhotoLibrary(seed: 1),
  settings: SettingsRepository(),
  connector: _RelayFailingConnector(passActive: passActive),
  includeOnlineTransport: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('a strict firewall without a pass raises the friendly prompt', () async {
    final coordinator = _coordinator(passActive: false);
    addTearDown(coordinator.dispose);
    await coordinator.loadSettings();

    await coordinator.joinMatch(_invite());

    expect(coordinator.state.firewallPrompt, isTrue);
    expect(coordinator.state.firewallRelayAttempted, isFalse);
    expect(coordinator.state.errorMessage, isNull);
    expect(coordinator.state.loadingMessage, isNull);
  });

  test('a pass holder whose relay is down gets the retry copy', () async {
    final coordinator = _coordinator(passActive: true);
    addTearDown(coordinator.dispose);
    await coordinator.loadSettings();

    await coordinator.joinMatch(_invite());

    expect(coordinator.state.firewallPrompt, isTrue);
    expect(coordinator.state.firewallRelayAttempted, isTrue);
    expect(coordinator.state.errorMessage, isNotNull);
  });

  test('dismissing the prompt clears it', () async {
    final coordinator = _coordinator(passActive: false);
    addTearDown(coordinator.dispose);
    await coordinator.loadSettings();
    await coordinator.joinMatch(_invite());

    coordinator.dismissFirewallPrompt();
    expect(coordinator.state.firewallPrompt, isFalse);
  });
}
