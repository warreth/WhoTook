import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/protocol/wire_message.dart';
import 'package:whotook/transport/game_transport.dart';
import 'package:whotook/transport/local_ws_transport.dart';

void main() {
  const roomId = 'room1234';
  const secret = 'secret-AbCdEf0123456789';

  late LocalWsHostTransport host;
  ClientTransport? clientA;
  ClientTransport? clientB;
  late List<String> joined;
  late List<HostIncomingMessage> hostInbox;

  setUp(() async {
    host = LocalWsHostTransport(
      roomId: roomId,
      secret: secret,
      advertiser: NoopMdnsAdvertiser(),
    );
    joined = <String>[];
    hostInbox = <HostIncomingMessage>[];
    host.clientConnected.listen(joined.add);
    host.messages.listen(hostInbox.add);
    await host.start();
    await host.refreshLanAddresses();
  });

  tearDown(() async {
    await clientA?.close();
    await clientB?.close();
    clientA = null;
    clientB = null;
    await host.close();
  });

  String baseUrl() => '127.0.0.1:${host.port}';

  test('binds a real TCP port and reports a LAN endpoint shape', () async {
    expect(host.port, greaterThan(0));
    final endpoint = host.localLanEndpoint;
    if (endpoint != null) {
      expect(endpoint, contains(':${host.port}'));
    }
  });

  test('rejects a wrong room secret before upgrading', () async {
    await expectLater(
      WebSocket.connect('ws://${baseUrl()}/ws?token=wrong-secret')
          .timeout(const Duration(seconds: 5)),
      throwsA(anyOf(isA<WebSocketException>(), isA<TimeoutException>())),
    );
    expect(joined, isEmpty);
  });

  test('rejects a missing secret', () async {
    await expectLater(
      WebSocket.connect('ws://${baseUrl()}/ws')
          .timeout(const Duration(seconds: 5)),
      throwsA(anyOf(isA<WebSocketException>(), isA<TimeoutException>())),
    );
  });

  test('two real clients join and receive a broadcast', () async {
    final a = LocalWsClientTransport(endpoint: baseUrl(), secret: secret);
    clientA = a;
    final aInbox = <WireMessage>[];
    a.messages.listen(aInbox.add);
    await a.connect();

    final b = LocalWsClientTransport(endpoint: baseUrl(), secret: secret);
    clientB = b;
    final bInbox = <WireMessage>[];
    b.messages.listen(bInbox.add);
    await b.connect();

    await _waitFor(() => joined.length == 2);

    await host.broadcast(
      WireMessage(type: WireType.lobbyState, seq: 1, payload: const {}),
    );
    await _waitFor(() => aInbox.isNotEmpty && bInbox.isNotEmpty);
    expect(aInbox.single.type, WireType.lobbyState);
    expect(bInbox.single.type, WireType.lobbyState);
  });

  test('targeted send reaches only the named client', () async {
    final a = LocalWsClientTransport(endpoint: baseUrl(), secret: secret);
    clientA = a;
    final aInbox = <WireMessage>[];
    a.messages.listen(aInbox.add);
    await a.connect();

    final b = LocalWsClientTransport(endpoint: baseUrl(), secret: secret);
    clientB = b;
    final bInbox = <WireMessage>[];
    b.messages.listen(bInbox.add);
    await b.connect();

    await _waitFor(() => joined.length == 2);
    final target = joined.last;

    await host.sendToClient(
      target,
      WireMessage(
        type: WireType.roundShow,
        seq: 2,
        payload: <String, dynamic>{'roundNumber': 1},
      ),
    );
    await _waitFor(() => bInbox.isNotEmpty || aInbox.isNotEmpty);
    final delivered = <WireMessage>[...aInbox, ...bInbox];
    expect(delivered.single.type, WireType.roundShow);
  });

  test('client traffic reaches the host inbox with its peer id', () async {
    final a = LocalWsClientTransport(endpoint: baseUrl(), secret: secret);
    clientA = a;
    await a.connect();
    await _waitFor(() => joined.length == 1);

    await a.send(
      WireMessage(
        type: WireType.joinReq,
        seq: 7,
        payload: <String, dynamic>{'name': 'Lotte'},
      ),
    );
    await _waitFor(() => hostInbox.isNotEmpty);
    expect(hostInbox.single.clientId, joined.single);
    expect(hostInbox.single.message.type, WireType.joinReq);
  });

  test('photo bytes survive a real 16 KB chunked transfer', () async {
    final a = LocalWsClientTransport(endpoint: baseUrl(), secret: secret);
    clientA = a;
    final chunks = <PhotoChunk>[];
    a.messages
        .where((m) => m.type == WireType.photoChunk)
        .listen((m) => chunks.add(PhotoChunk.fromJson(m.payload)));
    await a.connect();
    await _waitFor(() => joined.length == 1);

    final bytes = Uint8List.fromList(
      List<int>.generate(70 * 1024, (i) => i % 251),
    );
    final parts = PhotoChunker.split('photo-1', bytes);
    expect(parts.length, greaterThan(4));

    for (final chunk in parts) {
      await host.broadcast(
        WireMessage(type: WireType.photoChunk, seq: 2, payload: chunk.toJson()),
      );
    }
    await _waitFor(() => chunks.length == parts.length);

    final assembler = PhotoChunkAssembler();
    Uint8List? assembled;
    for (final chunk in chunks) {
      assembled ??= assembler.add(chunk);
    }
    expect(assembled, isNotNull);
    expect(assembled!.length, bytes.length);
    expect(assembled, orderedEquals(bytes));
  });

  test('prioritizeLanAddresses puts Wi-Fi and hotspot ahead of VPN/cellular tunnels', () {
    final ordered = prioritizeLanAddresses(const <({String interfaceName, String address})>[
      (interfaceName: 'pdp_ip0', address: '10.12.34.56'),
      (interfaceName: 'utun3', address: '100.64.0.1'),
      (interfaceName: 'lo0', address: '127.0.0.1'),
      (interfaceName: 'en2', address: '169.254.10.1'),
      (interfaceName: 'bridge100', address: '172.20.10.1'),
      (interfaceName: 'en0', address: '192.168.1.42'),
      (interfaceName: 'wlan0', address: '192.168.1.42'),
    ]);

    expect(ordered, <String>['192.168.1.42', '172.20.10.1']);
  });
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('condition not met within 20s');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
