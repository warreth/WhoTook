import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/protocol/wire_message.dart';
import 'package:whotook/state/match_coordinator.dart';
import 'package:whotook/transport/game_transport.dart';

class _FakeHostTransport implements HostTransport {
  _FakeHostTransport({required this.failures});

  final int failures;
  int starts = 0;
  final StreamController<String> _connected =
      StreamController<String>.broadcast();
  final StreamController<String> _disconnected =
      StreamController<String>.broadcast();
  final StreamController<HostIncomingMessage> _messages =
      StreamController<HostIncomingMessage>.broadcast();

  @override
  Stream<String> get clientConnected => _connected.stream;

  @override
  Stream<String> get clientDisconnected => _disconnected.stream;

  @override
  Stream<HostIncomingMessage> get messages => _messages.stream;

  @override
  String? get localLanEndpoint => null;

  @override
  Set<String> get clientIds => const <String>{};

  @override
  bool isRelayed(String clientId) => false;

  @override
  Future<void> start() async {
    starts += 1;
    if (starts <= failures) throw Exception('offline');
  }

  @override
  Future<void> sendToClient(String clientId, WireMessage message) async {}

  @override
  Future<void> broadcast(WireMessage message) async {}

  @override
  Future<void> close() async {
    await _connected.close();
    await _disconnected.close();
    await _messages.close();
  }
}

void main() {
  test('starts the online half in the background and retries', () async {
    final inner = _FakeHostTransport(failures: 1);
    final transport = BestEffortHostTransport(
      inner,
      retryDelays: const <Duration>[Duration.zero, Duration.zero],
    );

    await transport.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(inner.starts, 2);
    await transport.close();
  });

  test('stops retrying once closed', () async {
    final inner = _FakeHostTransport(failures: 5);
    final transport = BestEffortHostTransport(
      inner,
      retryDelays: const <Duration>[Duration.zero, Duration(milliseconds: 50)],
    );

    await transport.start();
    await Future<void>.delayed(Duration.zero);
    expect(inner.starts, 1);

    await transport.close();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(inner.starts, 1);
  });
}
