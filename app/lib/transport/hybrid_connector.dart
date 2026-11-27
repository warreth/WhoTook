import 'dart:async';

import '../core/models/models.dart';
import '../core/party_pass/turn_relay_client.dart';
import '../core/qr/invite_codec.dart';
import '../core/storage/settings_repository.dart';
import 'game_transport.dart';
import 'local_ws_transport.dart';
import 'webrtc_transport.dart';

/// Builds a local socket client for one advertised endpoint. Injected so the
/// connector can be tested without real sockets.
typedef LocalClientFactory = ClientTransport Function(
  String endpoint,
  String secret,
);

/// Builds the online fallback. Injected so the 800 ms race is testable
/// without a WebRTC plugin.
typedef OnlineClientFactory = ClientTransport Function();

/// Picks the transport for a scanned QR code. Local first, because a direct
/// socket is faster, private and free; online only when the LAN probe fails.
class HybridConnector {
  HybridConnector({
    LocalClientFactory? localClientFactory,
    OnlineClientFactory? onlineClientFactory,
    this._iceClient,
    this._turnRelay,
    MdnsDiscoverer? mdnsDiscoverer,
    this.localProbeTimeout = const Duration(milliseconds: 800),
  }) : _localFactory =
           localClientFactory ??
           ((endpoint, secret) =>
               LocalWsClientTransport(endpoint: endpoint, secret: secret)),
       _onlineFactory = onlineClientFactory,
       _mdnsDiscoverer = mdnsDiscoverer ?? const NoopMdnsDiscoverer();

  final LocalClientFactory _localFactory;
  final OnlineClientFactory? _onlineFactory;
  final SignalingIceClient? _iceClient;
  final Future<TurnRelayAttempt> Function()? _turnRelay;
  final MdnsDiscoverer _mdnsDiscoverer;
  final Duration localProbeTimeout;

  /// Connects with the first transport that succeeds. Throws
  /// [TurnQuotaBlockedException] when online play is the only option left and
  /// the daily relay quota is gone.
  Future<ClientTransport> connect({
    required InvitePayload invite,
    required AppSettings settings,
    bool discoverLan = false,
  }) async {
    final endpoints = <String>[
      if (discoverLan) ...await _mdnsDiscoverer.discover(roomId: invite.roomId),
      ...invite.lanEndpoints,
    ];
    final local = await _raceLocal(invite, endpoints.toSet().toList());
    if (local != null) return local;

    final online = _buildOnline(invite, settings);
    await online.connect();
    return online;
  }

  ClientTransport _buildOnline(InvitePayload invite, AppSettings settings) {
    final injected = _onlineFactory;
    if (injected != null) return injected();
    final ice =
        _iceClient ??
        SignalingIceClient(
          signalingUrl: _signalingUrl(invite, settings),
          turnRelay: _turnRelay,
        );
    return WebRtcClientTransport(
      invite: invite,
      iceClient: ice,
      settings: settings,
    );
  }

  String _signalingUrl(InvitePayload invite, AppSettings settings) {
    final fromInvite = invite.signalingUrl?.trim();
    if (fromInvite != null && fromInvite.isNotEmpty) return fromInvite;
    final custom = settings.customSignalingUrl?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return kDefaultSignalingUrl;
  }

  Future<ClientTransport?> _raceLocal(
    InvitePayload invite,
    List<String> lanEndpoints,
  ) async {
    if (lanEndpoints.isEmpty) return null;
    final settled = Completer<ClientTransport?>();
    final attempts = <ClientTransport>[];

    void finish(ClientTransport? winner) {
      if (settled.isCompleted) return;
      settled.complete(winner);
    }

    for (final endpoint in lanEndpoints) {
      final client = _localFactory(endpoint, invite.secret);
      attempts.add(client);
      unawaited(
        client.connect().then((_) {
          if (settled.isCompleted) {
            unawaited(client.close());
          } else {
            finish(client);
          }
        }, onError: (Object _) => unawaited(client.close())),
      );
    }

    final winner = await settled.future.timeout(
      localProbeTimeout,
      onTimeout: () => null,
    );

    // Close every probe that lost the race so no half open socket lingers.
    for (final attempt in attempts) {
      if (!identical(attempt, winner)) {
        unawaited(attempt.close());
      }
    }
    return winner;
  }
}
