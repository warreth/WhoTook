import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/party_pass/party_pass_repository.dart';
import 'package:whotook/core/party_pass/turn_relay_client.dart';
import 'package:whotook/core/qr/invite_codec.dart';
import 'package:whotook/transport/game_transport.dart';
import 'package:whotook/transport/webrtc_transport.dart';

const InvitePayload _invite = InvitePayload(
  roomId: 'room1234',
  hostId: 'host',
  secret: 'secret-AbCdEf0123456789',
  signalingUrl: 'wss://signal.whotook.party',
);

void main() {
  group('SignalingIceClient url schemes', () {
    test('posts to https when the custom url is wss', () async {
      Uri? requested;
      final client = SignalingIceClient(
        signalingUrl: 'wss://signal.whotook.party',
        httpClient: MockClient((request) async {
          requested = request.url;
          return http.Response('{"turnAllowed":false,"iceServers":[]}', 200);
        }),
      );

      await client.fetch(roomId: 'room1234', token: 'secret');

      expect(requested.toString(), 'https://signal.whotook.party/ice-config');
    });

    test('posts to http when the custom url is ws', () async {
      Uri? requested;
      final client = SignalingIceClient(
        signalingUrl: 'ws://192.168.1.5:8787',
        httpClient: MockClient((request) async {
          requested = request.url;
          return http.Response('{"turnAllowed":false,"iceServers":[]}', 200);
        }),
      );

      await client.fetch(roomId: 'room1234', token: 'secret');

      expect(requested.toString(), 'http://192.168.1.5:8787/ice-config');
    });

    test('posts the role when given', () async {
      String? body;
      final client = SignalingIceClient(
        signalingUrl: 'https://signal.whotook.party',
        httpClient: MockClient((request) async {
          body = request.body;
          return http.Response('{"turnAllowed":false,"iceServers":[]}', 200);
        }),
      );

      await client.fetch(roomId: 'room1234', token: 'secret', role: 'host');

      expect(jsonDecode(body!), containsPair('role', 'host'));
    });
  });

  group('SignalingIceClient room errors', () {
    SignalingIceClient clientReturning(int status, String body) =>
        SignalingIceClient(
          signalingUrl: 'https://signal.whotook.party',
          httpClient: MockClient(
            (request) async => http.Response(body, status),
          ),
        );

    test('maps NO_ROOM to room_not_ready', () async {
      final client = clientReturning(401, '{"error":"NO_ROOM"}');

      await expectLater(
        client.fetch(roomId: 'room1234', token: 'secret'),
        throwsA(
          isA<TransportException>().having(
            (error) => error.code,
            'code',
            'room_not_ready',
          ),
        ),
      );
    });

    test('maps a bad token to unauthorized', () async {
      final client = clientReturning(401, '{"error":"BAD_TOKEN"}');

      await expectLater(
        client.fetch(roomId: 'room1234', token: 'secret'),
        throwsA(
          isA<TransportException>().having(
            (error) => error.code,
            'code',
            'unauthorized',
          ),
        ),
      );
    });
  });

  group('Party Pass relay merge', () {
    PartyPassCredential credential() => PartyPassCredential(
      platform: StorePlatform.apple,
      productId: kPartyPassProductId,
      verificationToken: 'jws',
      savedAtUtc: DateTime.utc(2026, 11, 16),
    );

    test('adds verified coturn credentials to the ICE list', () async {
      final client = SignalingIceClient(
        signalingUrl: 'https://signal.example',
        httpClient: MockClient(
          (_) async => http.Response(
            '{"turnAllowed":false,"reason":"TURN_NOT_CONFIGURED",'
            '"iceServers":[{"urls":"stun:stun.cloudflare.com:3478"}]}',
            200,
          ),
        ),
        turnRelay: () async => TurnRelayAttempt(
          passActive: true,
          grant: TurnRelayGrant(
            iceServers: const <RelayIceServer>[
              RelayIceServer(
                urls: <String>['turn:turn.example:3478'],
                username: '1700000000:pp_abc',
                credential: 'hmac',
              ),
            ],
            ttlSeconds: 2700,
            expiresAtUtc: DateTime.utc(2026, 11, 16, 13),
            remainingMatchesToday: 14,
            dailyLimit: 15,
          ),
        ),
      );

      final config = await client.fetch(
        roomId: 'room1234',
        token: 'secret',
        settings: const AppSettings(),
      );

      expect(config.turnAllowed, isTrue);
      expect(config.remainingMatchesToday, 14);
      expect(config.iceServers, hasLength(2));
      expect(config.iceServers.last.username, '1700000000:pp_abc');
    });

    test('reports a pass holder whose relay is unavailable', () async {
      final client = SignalingIceClient(
        signalingUrl: 'https://signal.example',
        httpClient: MockClient(
          (_) async => http.Response(
            '{"turnAllowed":false,'
            '"iceServers":[{"urls":"stun:stun.cloudflare.com:3478"}]}',
            200,
          ),
        ),
        turnRelay: () async => const TurnRelayAttempt(
          passActive: true,
          errorCode: TurnRelayErrorCode.fairUseLimit,
        ),
      );

      final config = await client.fetch(roomId: 'room1234', token: 'secret');
      expect(config.turnAllowed, isFalse);
      expect(config.relayPassActive, isTrue);
      expect(config.relayErrorCode, TurnRelayErrorCode.fairUseLimit);
    });

    test('a pass holder without a token gets no relay', () async {
      final client = SignalingIceClient(
        signalingUrl: 'https://signal.example',
        httpClient: MockClient(
          (_) async => http.Response(
            '{"turnAllowed":false,'
            '"iceServers":[{"urls":"stun:stun.cloudflare.com:3478"}]}',
            200,
          ),
        ),
        turnRelay: () async => const TurnRelayAttempt(passActive: false),
      );

      final config = await client.fetch(roomId: 'room1234', token: 'secret');
      expect(config.turnAllowed, isFalse);
      expect(config.relayPassActive, isFalse);
      expect(credential().productId, kPartyPassProductId);
    });
  });

  test('client ICE timeout covers the host relay setup window', () {
    final transport = WebRtcClientTransport(
      invite: _invite,
      iceClient: SignalingIceClient(
        signalingUrl: 'https://signal.whotook.party',
      ),
    );
    expect(
      transport.iceTimeout,
      greaterThanOrEqualTo(const Duration(seconds: 20)),
    );
  });

  test('a granted relay timeout maps to the relay prompt', () {
    final transport = WebRtcClientTransport(
      invite: _invite,
      iceClient: SignalingIceClient(
        signalingUrl: 'https://signal.whotook.party',
      ),
    );
    final failure = transport.relayRequiredForTimeout(
      const IceConfig(
        turnAllowed: true,
        relayPassActive: true,
        iceServers: <IceServerConfig>[],
      ),
    );
    expect(failure, isNotNull);
    expect(failure!.passActive, isTrue);
    expect(failure.relayErrorCode, 'ice_failed');
  });

  group('WebRtcHostTransport signaling frames', () {
    late WebRtcHostTransport transport;

    setUp(() {
      transport = WebRtcHostTransport(
        invite: _invite,
        iceClient: SignalingIceClient(
          signalingUrl: 'https://signal.whotook.party',
        ),
      );
    });

    tearDown(() async {
      await transport.close();
    });

    test('ignores signaling after close', () async {
      await transport.close();
      await transport.handleSignalingFrame(<String, dynamic>{
        'type': 'peer_joined',
        'peerId': 'late-peer',
      });
    });

    test('close is idempotent', () async {
      await transport.close();
      await transport.close();
    });

    test('ignores answers and ice for a peer it does not know', () async {
      await transport.handleSignalingFrame(<String, dynamic>{
        'type': 'answer',
        'from': 'ghost',
        'payload': <String, dynamic>{'sdp': 'v=0', 'type': 'answer'},
      });
      await transport.handleSignalingFrame(<String, dynamic>{
        'type': 'ice',
        'from': 'ghost',
        'payload': <String, dynamic>{
          'candidate': 'candidate:1',
          'sdpMid': '0',
          'sdpMLineIndex': 0,
        },
      });
    });

    test('tolerates frames with missing fields', () async {
      await transport.handleSignalingFrame(<String, dynamic>{
        'type': 'peer_joined',
      });
      await transport.handleSignalingFrame(<String, dynamic>{
        'type': 'answer',
        'payload': <String, dynamic>{},
      });
      await transport.handleSignalingFrame(<String, dynamic>{
        'type': 'ice',
        'from': 'ghost',
        'payload': <String, dynamic>{},
      });
      await transport.handleSignalingFrame(<String, dynamic>{'type': 'left'});
    });

    test('peer_left reports the disconnected peer id', () async {
      final gone = <String>[];
      final subscription = transport.clientDisconnected.listen(gone.add);
      addTearDown(subscription.cancel);

      await transport.handleSignalingFrame(<String, dynamic>{
        'type': 'peer_left',
        'peerId': 'c_loop0',
      });
      await Future<void>.delayed(Duration.zero);

      expect(gone, contains('c_loop0'));
    });

    test('fetches ICE on demand and reuses it', () async {
      var fetches = 0;
      final lazy = WebRtcHostTransport(
        invite: _invite,
        iceClient: SignalingIceClient(
          signalingUrl: 'https://signal.whotook.party',
          httpClient: MockClient((request) async {
            fetches += 1;
            return http.Response(
              '{"turnAllowed":false,"iceServers":[{"urls":"stun:stun.cloudflare.com:3478"}]}',
              200,
            );
          }),
        ),
      );
      addTearDown(lazy.close);

      expect(fetches, 0);
      final first = await lazy.fetchIceForTest();
      expect(first.iceServers, isNotEmpty);
      expect(fetches, 1);

      final second = await lazy.fetchIceForTest();
      expect(identical(first, second), isTrue);
      expect(fetches, 1);
    });
  });

  group('WebRtcHostTransport signaling reconnect', () {
    test('opens a new socket after the signaling connection drops', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final sockets = <WebSocket>[];
      var connections = 0;

      server.listen((request) async {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          request.response.statusCode = 404;
          await request.response.close();
          return;
        }
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        connections += 1;
        socket.add(
          jsonEncode(<String, dynamic>{
            'type': 'welcome',
            'peerId': 'host',
            'role': 'host',
          }),
        );
        if (connections == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await socket.close();
        }
      });

      final transport = WebRtcHostTransport(
        invite: InvitePayload(
          roomId: 'room1234',
          hostId: 'host',
          secret: 'secret-AbCdEf0123456789',
          signalingUrl: 'ws://127.0.0.1:${server.port}',
        ),
        iceClient: SignalingIceClient(
          signalingUrl: 'https://signal.whotook.party',
        ),
      );
      addTearDown(() async {
        await transport.close();
        for (final socket in sockets) {
          await socket.close();
        }
      });

      await transport.start();
      await Future<void>.delayed(const Duration(milliseconds: 1800));

      expect(connections, greaterThanOrEqualTo(2));
    });
  });
}
