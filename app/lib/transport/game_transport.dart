import 'dart:async';

import '../core/models/models.dart';
import '../core/protocol/wire_message.dart';

/// One decoded message plus the transport level id of the sender.
class HostIncomingMessage {
  const HostIncomingMessage({required this.clientId, required this.message});

  final String clientId;
  final WireMessage message;
}

/// A message that arrived before the socket finished authenticating.
class TransportException implements Exception {
  const TransportException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'TransportException($code): $message';
}

/// Host side of a match. One implementation per network path; the state layer
/// composes them so a host can serve LAN and WebRTC players at the same time.
abstract class HostTransport {
  /// Fires with the peer id when a player's socket is authenticated.
  Stream<String> get clientConnected;

  Stream<String> get clientDisconnected;

  Stream<HostIncomingMessage> get messages;

  /// `host:port` on the local network, or null when this transport cannot be
  /// reached from the LAN.
  String? get localLanEndpoint;

  Future<void> start();

  Future<void> sendToClient(String clientId, WireMessage message);

  Future<void> broadcast(WireMessage message);

  Future<void> close();
}

/// Player side of a match.
abstract class ClientTransport {
  ConnectionMode get mode;

  /// Set when the signaling server refused TURN relay for this IP today.
  TurnLimitNotice? get turnLimitNotice;

  Stream<WireMessage> get messages;

  Stream<void> get disconnected;

  Future<void> connect();

  Future<void> send(WireMessage message);

  Future<void> close();
}

/// Combines transports so `broadcast` reaches every player regardless of how
/// they connected, and a disconnect on one path does not close the room.
class CompositeHostTransport implements HostTransport {
  CompositeHostTransport(this._transports);

  final List<HostTransport> _transports;
  final StreamController<String> _connected =
      StreamController<String>.broadcast();
  final StreamController<String> _disconnected =
      StreamController<String>.broadcast();
  final StreamController<HostIncomingMessage> _messages =
      StreamController<HostIncomingMessage>.broadcast();
  final Map<String, HostTransport> _owner = <String, HostTransport>{};
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  bool _closed = false;

  @override
  Stream<String> get clientConnected => _connected.stream;

  @override
  Stream<String> get clientDisconnected => _disconnected.stream;

  @override
  Stream<HostIncomingMessage> get messages => _messages.stream;

  @override
  String? get localLanEndpoint {
    for (final transport in _transports) {
      final endpoint = transport.localLanEndpoint;
      if (endpoint != null) return endpoint;
    }
    return null;
  }

  @override
  Future<void> start() async {
    for (final transport in _transports) {
      _subscriptions.add(
        transport.clientConnected.listen((id) {
          _owner[id] = transport;
          if (!_connected.isClosed) _connected.add(id);
        }),
      );
      _subscriptions.add(
        transport.clientDisconnected.listen((id) {
          _owner.remove(id);
          if (!_disconnected.isClosed) _disconnected.add(id);
        }),
      );
      _subscriptions.add(
        transport.messages.listen((incoming) {
          _owner.putIfAbsent(incoming.clientId, () => transport);
          if (!_messages.isClosed) _messages.add(incoming);
        }),
      );
      await transport.start();
    }
  }

  @override
  Future<void> sendToClient(String clientId, WireMessage message) async {
    final transport = _owner[clientId];
    if (transport == null) {
      throw TransportException('unknown_client', 'no transport for $clientId');
    }
    await transport.sendToClient(clientId, message);
  }

  @override
  Future<void> broadcast(WireMessage message) async {
    await Future.wait(_transports.map((t) => t.broadcast(message)));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await Future.wait(_transports.map((t) => t.close()));
    await _connected.close();
    await _disconnected.close();
    await _messages.close();
  }
}

/// In-memory hub used by tests and by the offline single-device mode. It keeps
/// the same envelope, ordering and chunking rules as the socket transports, so
/// an engine bug reproduces here before it reaches a phone.
class LoopbackHub {
  final List<_LoopbackPeer> _hosts = <_LoopbackPeer>[];
  final Map<String, _LoopbackPeer> _clients = <String, _LoopbackPeer>{};
  final StreamController<String> _connected =
      StreamController<String>.broadcast();
  final StreamController<String> _disconnected =
      StreamController<String>.broadcast();
  final StreamController<HostIncomingMessage> _messages =
      StreamController<HostIncomingMessage>.broadcast();
  int _nextClient = 0;

  HostTransport createHost() => LoopbackHostTransport(this);

  ClientTransport createClient() => LoopbackClientTransport(this);

  void _attachHost(_LoopbackPeer peer) => _hosts.add(peer);

  void _detachHost(_LoopbackPeer peer) => _hosts.remove(peer);

  String _attachClient(_LoopbackPeer peer) {
    final id = 'c_loop${_nextClient++}';
    _clients[id] = peer;
    if (!_connected.isClosed) _connected.add(id);
    return id;
  }

  void _detachClient(String id) {
    _clients.remove(id);
    if (!_disconnected.isClosed) _disconnected.add(id);
  }

  void _fromClient(String clientId, String raw) {
    final message = WireMessage.decode(raw);
    if (!_messages.isClosed) {
      _messages.add(HostIncomingMessage(clientId: clientId, message: message));
    }
  }

  void _toClient(String clientId, WireMessage message) {
    _clients[clientId]?._deliver(message);
  }

  void _toAllClients(WireMessage message) {
    for (final peer in _clients.values) {
      peer._deliver(message);
    }
  }

  Future<void> dispose() async {
    for (final peer in _hosts) {
      await peer._close();
    }
    for (final peer in _clients.values) {
      await peer._close();
    }
    await _connected.close();
    await _disconnected.close();
    await _messages.close();
  }
}

class _LoopbackPeer {
  _LoopbackPeer();
  final StreamController<WireMessage> _incoming =
      StreamController<WireMessage>.broadcast();
  final StreamController<void> _closed = StreamController<void>.broadcast();
  bool _isClosed = false;

  void _deliver(WireMessage message) {
    if (!_incoming.isClosed) _incoming.add(message);
  }

  Future<void> _close() async {
    if (_isClosed) return;
    _isClosed = true;
    await _incoming.close();
    await _closed.close();
  }
}

class LoopbackHostTransport implements HostTransport {
  LoopbackHostTransport(this._hub);

  final LoopbackHub _hub;
  final _LoopbackPeer _peer = _LoopbackPeer();
  final List<StreamSubscription<dynamic>> _subs =
      <StreamSubscription<dynamic>>[];
  bool _started = false;

  @override
  Stream<String> get clientConnected => _hub._connected.stream;

  @override
  Stream<String> get clientDisconnected => _hub._disconnected.stream;

  @override
  Stream<HostIncomingMessage> get messages => _hub._messages.stream;

  @override
  String? get localLanEndpoint => 'loopback';

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _hub._attachHost(_peer);
  }

  @override
  Future<void> sendToClient(String clientId, WireMessage message) async {
    _hub._toClient(clientId, message);
  }

  @override
  Future<void> broadcast(WireMessage message) async {
    _hub._toAllClients(message);
  }

  @override
  Future<void> close() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    _hub._detachHost(_peer);
    await _peer._close();
  }
}

class LoopbackClientTransport implements ClientTransport {
  LoopbackClientTransport(this._hub);

  final LoopbackHub _hub;
  final _LoopbackPeer _peer = _LoopbackPeer();
  String? _clientId;

  @override
  ConnectionMode get mode => ConnectionMode.offlineLoopback;

  @override
  TurnLimitNotice? get turnLimitNotice => null;

  @override
  Stream<WireMessage> get messages => _peer._incoming.stream;

  @override
  Stream<void> get disconnected => _peer._closed.stream;

  @override
  Future<void> connect() async {
    _clientId ??= _hub._attachClient(_peer);
    _peer._incoming.stream.listen((message) {
      // The hub expects the client to answer like a socket would; tests drive
      // this explicitly, production code never uses loopback for real players.
    });
  }

  @override
  Future<void> send(WireMessage message) async {
    final id = _clientId;
    if (id == null) {
      throw const TransportException('not_connected', 'call connect first');
    }
    _hub._fromClient(id, message.encode());
  }

  @override
  Future<void> close() async {
    final id = _clientId;
    _clientId = null;
    if (id != null) _hub._detachClient(id);
    await _peer._close();
  }
}

/// Constant time equality for room secrets. Length is compared first, then all
/// bytes, so a timing observer learns nothing about a partial match.
bool secureCompare(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
