import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whotook/core/models/models.dart';
import 'package:whotook/core/party_pass/party_pass_repository.dart';
import 'package:whotook/core/party_pass/turn_relay_client.dart';
import 'package:whotook/core/qr/invite_codec.dart';
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
  });
}
