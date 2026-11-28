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
    this.localProbeTimeout = const Duration(milliseconds: 1500),
    this.localRetryDelay = const Duration(milliseconds: 1200),
    this.maxLocalRetries = 3,
  }) : _localFactory =
           localClientFactory ??
           ((endpoint, secret) => LocalWsClientTransport(
             endpoint: endpoint,
             secret: secret,
             connectTimeout: localProbeTimeout,
           )),
       _onlineFactory = onlineClientFactory,
       _mdnsDiscoverer = mdnsDiscoverer ?? const NoopMdnsDiscoverer();

  final LocalClientFactory _localFactory;
  final OnlineClientFactory? _onlineFactory;
  final SignalingIceClient? _iceClient;
  final Future<TurnRelayAttempt> Function()? _turnRelay;
  final MdnsDiscoverer _mdnsDiscoverer;
  final Duration localProbeTimeout;
  final Duration localRetryDelay;
  final int maxLocalRetries;

  /// Connects with the first transport that succeeds. Throws
  /// [TurnQuotaBlockedException] when online play is the only option left and
  /// the daily relay quota is gone.
  Future<ClientTransport> connect({
    required InvitePayload invite,
    required AppSettings settings,
    bool discoverLan = false,
  }) async {
    final inviteEndpoints = invite.lanEndpoints.toSet().toList();
    if (discoverLan) {
      final discovered = (await _mdnsDiscoverer.discover(
        roomId: invite.roomId,
      )).toSet().toList();
      if (discovered.isNotEmpty) {
        final localDiscovered = await _raceLocal(invite, discovered);
        if (localDiscovered != null) return localDiscovered;
      }
      final remaining = inviteEndpoints
          .where((endpoint) => !discovered.contains(endpoint))
          .toList();
      final fallbackLocal = await _raceLocal(invite, remaining);
      if (fallbackLocal != null) return fallbackLocal;
    } else {
      final local = await _raceLocal(invite, inviteEndpoints);
      if (local != null) return local;
    }

    if (inviteEndpoints.isEmpty && !discoverLan) {
      final online = _buildOnline(invite, settings);
      await online.connect();
      return online;
    }

    // On iOS, the first scan can fail immediately with EPERM/EHOSTUNREACH
    // while the Local Network permission sheet is on screen. Retry LAN in
    // parallel while negotiating online so tapping Allow still connects on
    // the first scan even in offline hotspot/airplane mode.
    final online = _buildOnline(invite, settings);
    var cancelled = false;
    var onlineSettled = false;
    var completedRetries = 0;

    Future<ClientTransport?> tryLocalRetryOnce(int attemptIndex) async {
      if (cancelled) return null;
      var endpoints = inviteEndpoints;
      if (attemptIndex == 0 && !discoverLan) {
        try {
          final discovered = await _mdnsDiscoverer.discover(
            roomId: invite.roomId,
            timeout: localProbeTimeout,
          );
          if (discovered.isNotEmpty) {
            endpoints = <String>{...discovered, ...inviteEndpoints}.toList();
          }
        } on Object {
          // Ignore mDNS errors during background LAN retry.
        }
      }
      if (cancelled || endpoints.isEmpty) return null;
      return _raceLocal(invite, endpoints);
    }

    final retryWinner = Completer<ClientTransport?>();
    unawaited(() async {
      try {
        for (var i = 0; i < maxLocalRetries; i++) {
          if (cancelled || onlineSettled) break;
          if (localRetryDelay > Duration.zero) {
            await Future<void>.delayed(localRetryDelay);
          }
          if (cancelled || onlineSettled) break;
          final won = await tryLocalRetryOnce(i);
          completedRetries++;
          if (won != null) {
            if (!cancelled && !retryWinner.isCompleted) {
              retryWinner.complete(won);
              return;
            }
            unawaited(won.close().catchError((Object _) {}));
            return;
          }
        }
      } on Object {
        // Best-effort retries must never throw unhandled errors.
      }
      if (!retryWinner.isCompleted) retryWinner.complete(null);
    }());

    final onlineFuture = online.connect().then<ClientTransport>(
      (_) => online,
    );
    unawaited(onlineFuture.catchError((Object _) => online));

    final raced = await Future.any<({bool isOnline, ClientTransport? transport, Object? error, StackTrace? stack})>(<Future<({bool isOnline, ClientTransport? transport, Object? error, StackTrace? stack})>>[
      onlineFuture.then(
        (t) {
          onlineSettled = true;
          return (isOnline: true, transport: t, error: null, stack: null);
        },
        onError: (Object err, StackTrace st) {
          onlineSettled = true;
          return (isOnline: true, transport: null, error: err, stack: st);
        },
      ),
      retryWinner.future.then(
        (t) => (isOnline: false, transport: t, error: null, stack: null),
      ),
    ]);

    if (!raced.isOnline) {
      if (raced.transport != null) {
        cancelled = true;
        unawaited(online.close().catchError((Object _) {}));
        return raced.transport!;
      }
      // Retry loop exhausted with null before online settled; wait on online.
      final onlineResult = await onlineFuture;
      cancelled = true;
      return onlineResult;
    }

    // Online settled first.
    if (raced.error == null && raced.transport != null) {
      cancelled = true;
      return raced.transport!;
    }

    cancelled = true;
    unawaited(online.close().catchError((Object _) {}));
    final err = raced.error!;
    final st = raced.stack!;
    if (err is TurnQuotaBlockedException) {
      Error.throwWithStackTrace(err, st);
    }

    // If online failed quickly (e.g., offline airplane hotspot) before a LAN
    // retry had a chance to run, give LAN one final probe after a short wait.
    if (completedRetries == 0 && maxLocalRetries > 0) {
      cancelled = false;
      if (localRetryDelay > Duration.zero) {
        await Future<void>.delayed(localRetryDelay);
      }
      final finalLocal = await tryLocalRetryOnce(0);
      cancelled = true;
      if (finalLocal != null) return finalLocal;
    }

    Error.throwWithStackTrace(err, st);
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
    var pending = lanEndpoints.length;

    void finish(ClientTransport? winner) {
      if (settled.isCompleted) return;
      settled.complete(winner);
    }

    for (final endpoint in lanEndpoints) {
      final client = _localFactory(endpoint, invite.secret);
      attempts.add(client);
      unawaited(
        client.connect().then(
          (_) {
            if (settled.isCompleted) {
              unawaited(client.close().catchError((Object _) {}));
            } else {
              finish(client);
            }
          },
          onError: (Object _) {
            unawaited(client.close().catchError((Object _) {}));
            if (--pending <= 0) finish(null);
          },
        ),
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
