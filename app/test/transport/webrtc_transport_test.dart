import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
