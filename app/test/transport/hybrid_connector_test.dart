import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/party_pass/turn_relay_client.dart';
import 'package:whotook/core/protocol/wire_message.dart';
import 'package:whotook/core/qr/invite_codec.dart';
import 'package:whotook/transport/game_transport.dart';
import 'package:whotook/transport/hybrid_connector.dart';
import 'package:whotook/transport/webrtc_transport.dart';

/// Minimal client that records what the connector did.
class _FakeClient implements ClientTransport {
  _FakeClient({
    required this.label,
    this.failConnect = false,
    this.connectDelay = Duration.zero,
    this.notice,
  });

  final String label;
  final bool failConnect;
  final Duration connectDelay;
  final TurnLimitNotice? notice;
  final StreamController<WireMessage> _messages =
      StreamController<WireMessage>.broadcast();
  bool closed = false;
  bool connected = false;

  @override
  ConnectionMode get mode => ConnectionMode.webrtcP2p;

  @override
  bool get usesRelay => false;

  @override
  TurnLimitNotice? get turnLimitNotice => notice;

  @override
  Stream<WireMessage> get messages => _messages.stream;

  @override
  Stream<void> get disconnected => const Stream<void>.empty();

  @override
  Future<void> connect() async {
    if (connectDelay > Duration.zero) await Future<void>.delayed(connectDelay);
    if (failConnect) throw const TransportException('boom', 'unreachable');
    connected = true;
  }

  @override
  Future<void> send(WireMessage message) async {}

  @override
  Future<void> close() async {
    closed = true;
    if (!_messages.isClosed) await _messages.close();
  }
}

InvitePayload _invite({List<String> lan = const <String>[]}) => InvitePayload(
  roomId: 'room1234',
  hostId: 'host',
  secret: 'secret-AbCdEf0123456789',
  lanEndpoints: lan,
  signalingUrl: 'https://signal.example',
);

void main() {
  group('hybrid connector', () {
    test('local wins the race when the LAN socket connects in time', () async {
      final local = _FakeClient(label: 'local');
      final online = _FakeClient(label: 'online');
      final connector = HybridConnector(
        localClientFactory: (_, _) => local,
        onlineClientFactory: () => online,
      );

      final picked = await connector.connect(
        invite: _invite(lan: <String>['192.168.1.5:8765']),
        settings: const AppSettings(),
      );

      expect(identical(picked, local), isTrue);
      expect(local.connected, isTrue);
      expect(online.connected, isFalse);
    });

    test('falls back online after the 800 ms local window', () async {
      final slowLocal = _FakeClient(
        label: 'local',
        connectDelay: const Duration(milliseconds: 400),
      );
      final online = _FakeClient(label: 'online');
      final connector = HybridConnector(
        localClientFactory: (_, _) => slowLocal,
        onlineClientFactory: () => online,
        localProbeTimeout: const Duration(milliseconds: 50),
      );

      final picked = await connector.connect(
        invite: _invite(lan: <String>['10.0.0.9:8765']),
        settings: const AppSettings(),
      );

      expect(identical(picked, online), isTrue);
      expect(online.connected, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      expect(slowLocal.closed, isTrue);
    });

    test(
      'goes straight online when the invite carries no LAN endpoint',
      () async {
        final online = _FakeClient(label: 'online');
        var localCalls = 0;
        final connector = HybridConnector(
          localClientFactory: (_, _) {
            localCalls += 1;
            return _FakeClient(label: 'local');
          },
          onlineClientFactory: () => online,
        );

        final picked = await connector.connect(
          invite: _invite(),
          settings: const AppSettings(),
        );

        expect(identical(picked, online), isTrue);
        expect(localCalls, 0);
      },
    );

    test('surfaces TURN quota exhaustion instead of a generic error', () async {
      final notice = TurnLimitNotice(
        reason: 'DAILY_TURN_LIMIT_REACHED',
        dailyLimit: 5,
        usedToday: 5,
        retryAtUtc: DateTime.utc(2026, 11, 14),
      );
      final connector = HybridConnector(
        localClientFactory: (_, _) =>
            _FakeClient(label: 'local', failConnect: true),
        onlineClientFactory: () => _FailWithQuota(notice),
      );

      await expectLater(
        connector.connect(
          invite: _invite(lan: <String>['192.168.1.5:8765']),
          settings: const AppSettings(),
        ),
        throwsA(isA<TurnQuotaBlockedException>()),
      );
    });
  });

  group('signaling ice client', () {
    test('parses a granted TURN response', () async {
      final client = SignalingIceClient(
        signalingUrl: 'https://signal.example',
        acceptServerTurn: true,
        httpClient: MockClient((request) async {
          expect(request.url.toString(), 'https://signal.example/ice-config');
          return http.Response(
            '{"turnAllowed":true,"dailyLimit":5,"usedToday":1,'
            '"iceServers":[{"urls":"stun:stun.cloudflare.com:3478"},'
            '{"urls":"turn:turn.example:3478","username":"u","credential":"c"}]}',
            200,
          );
        }),
      );

      final config = await client.fetch(roomId: 'room1234', token: 'secret');

      expect(config.turnAllowed, isTrue);
      expect(config.usedToday, 1);
      expect(config.iceServers, hasLength(2));
      expect(config.iceServers.last.username, 'u');
    });

    test('official default ignores a server-issued TURN relay', () async {
      final client = SignalingIceClient(
        signalingUrl: 'https://signal.example',
        httpClient: MockClient(
          (_) async => http.Response(
            '{"turnAllowed":true,'
            '"iceServers":[{"urls":"stun:stun.cloudflare.com:3478"},'
            '{"urls":"turn:free.example:3478","username":"u","credential":"c"}]}',
            200,
          ),
        ),
      );

      final config = await client.fetch(roomId: 'room1234', token: 'secret');
      expect(config.turnAllowed, isFalse);
      expect(config.iceServers, hasLength(1));
    });

    test('a client that rejects server TURN keeps STUN only', () async {
      final client = SignalingIceClient(
        signalingUrl: 'https://signal.example',
        acceptServerTurn: false,
        httpClient: MockClient(
          (_) async => http.Response(
            '{"turnAllowed":true,'
            '"iceServers":[{"urls":"stun:stun.cloudflare.com:3478"},'
            '{"urls":"turn:free.example:3478","username":"u","credential":"c"}]}',
            200,
          ),
        ),
      );

      final config = await client.fetch(roomId: 'room1234', token: 'secret');
      expect(config.turnAllowed, isFalse);
      expect(config.iceServers, hasLength(1));
      expect(config.iceServers.single.urls.single, startsWith('stun:'));
    });

    test('parses the daily quota denial with a retry time', () async {
      final client = SignalingIceClient(
        signalingUrl: 'https://signal.example/',
        httpClient: MockClient(
          (request) async => http.Response(
            '{"turnAllowed":false,"reason":"DAILY_TURN_LIMIT_REACHED",'
            '"dailyLimit":5,"usedToday":5,'
            '"retryAtUtc":"2026-11-14T00:00:00.000Z",'
            '"iceServers":[{"urls":"stun:stun.cloudflare.com:3478"}]}',
            200,
          ),
        ),
      );

      final config = await client.fetch(roomId: 'room1234', token: 'secret');
      expect(config.turnAllowed, isFalse);
      expect(config.reason, 'DAILY_TURN_LIMIT_REACHED');
      expect(config.retryAtUtc, DateTime.utc(2026, 11, 14));
      expect(config.iceServers.single.urls.single, startsWith('stun:'));
    });

    test('rejects a room token with 401', () async {
      final client = SignalingIceClient(
        signalingUrl: 'https://signal.example',
        httpClient: MockClient((_) async => http.Response('{}', 401)),
      );

      await expectLater(
        client.fetch(roomId: 'room1234', token: 'bad'),
        throwsA(isA<TransportException>()),
      );
    });

    test('does not spend relay quota when ICE config is rejected', () async {
      var relayCalls = 0;
      final client = SignalingIceClient(
        signalingUrl: 'https://signal.example',
        httpClient: MockClient(
          (_) async => http.Response('{"error":"UNAUTHORIZED"}', 401),
        ),
        turnRelay: () async {
          relayCalls += 1;
          return const TurnRelayAttempt(passActive: true);
        },
      );

      await expectLater(
        client.fetch(roomId: 'room1234', token: 'bad'),
        throwsA(isA<TransportException>()),
      );
      expect(relayCalls, 0);
    });

    test('uses a self-hosted TURN server without /ice-config', () async {
      final client = SignalingIceClient(
        signalingUrl: 'https://signal.example',
        httpClient: MockClient(
          (_) async =>
              throw StateError('custom TURN must not call /ice-config'),
        ),
      );

      final config = await client.fetch(
        roomId: 'room1234',
        token: 'secret',
        settings: const AppSettings(
          customTurnUrl: 'turn:my-relay.example:3478',
          customTurnUsername: 'me',
          customTurnCredential: 'pw',
        ),
      );

      expect(config.turnAllowed, isTrue);
      expect(config.iceServers, hasLength(2));
      expect(config.iceServers.first.urls.single, startsWith('stun:'));
      expect(config.iceServers.last.urls.single, 'turn:my-relay.example:3478');
    });
  });
}

class _FailWithQuota extends _FakeClient {
  _FailWithQuota(TurnLimitNotice notice)
    : super(label: 'online', notice: notice);

  @override
  Future<void> connect() async => throw TurnQuotaBlockedException(notice!);
}
