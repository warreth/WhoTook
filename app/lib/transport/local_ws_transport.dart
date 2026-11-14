import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';

import '../core/models/models.dart';
import '../core/protocol/wire_message.dart';
import 'game_transport.dart';

/// Service type advertised over mDNS so a player on the same network can find
/// the host without reading an IP out of the QR payload.
const String kWhotookMdnsType = '_whotook._tcp';

/// Advertises a room over mDNS. Kept behind an interface because multicast is
/// unavailable in unit tests and on some networks, and a failed advertisement
/// must never abort the match.
abstract class MdnsAdvertiser {
  Future<void> advertise({required String roomId, required int port});

  Future<void> stop();
}

class BonsoirMdnsAdvertiser implements MdnsAdvertiser {
  BonsoirBroadcast? _broadcast;

  @override
  Future<void> advertise({required String roomId, required int port}) async {
    await stop();
    try {
      final broadcast = BonsoirBroadcast(
        service: BonsoirService(
          name: 'WhoTook-$roomId',
          type: kWhotookMdnsType,
          port: port,
          attributes: <String, String>{'room': roomId},
        ),
      );
      await broadcast.initialize();
      await broadcast.start();
      _broadcast = broadcast;
    } on Exception {
      _broadcast = null;
    }
  }

  @override
  Future<void> stop() async {
    final broadcast = _broadcast;
    _broadcast = null;
    if (broadcast == null) return;
    try {
      await broadcast.stop();
    } on Exception {
      // Shutting down a half started broadcast is not worth surfacing.
    }
  }
}

class NoopMdnsAdvertiser implements MdnsAdvertiser {
  @override
  Future<void> advertise({required String roomId, required int port}) async {}

  @override
  Future<void> stop() async {}
}

/// Serves the match over a plain WebSocket on the local network. This is the
/// zero server path: the host phone is the server.
class LocalWsHostTransport implements HostTransport {
  LocalWsHostTransport({
    required this.roomId,
    required this.secret,
    MdnsAdvertiser? advertiser,
    int port = 0,
  }) : _advertiser = advertiser ?? NoopMdnsAdvertiser(),
       _requestedPort = port;

  static const String path = '/ws';

  final String roomId;
  final String secret;
  final MdnsAdvertiser _advertiser;
  final int _requestedPort;

  final StreamController<String> _connected =
      StreamController<String>.broadcast();
  final StreamController<String> _disconnected =
      StreamController<String>.broadcast();
  final StreamController<HostIncomingMessage> _messages =
      StreamController<HostIncomingMessage>.broadcast();
  final Map<String, WebSocket> _sockets = <String, WebSocket>{};
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  HttpServer? _server;
  List<String> _addresses = const <String>[];
  int _nextPeer = 0;
  bool _closed = false;

  int get port => _server?.port ?? 0;

  List<String> get lanAddresses => _addresses;

  @override
  Stream<String> get clientConnected => _connected.stream;

  @override
  Stream<String> get clientDisconnected => _disconnected.stream;

  @override
  Stream<HostIncomingMessage> get messages => _messages.stream;

  @override
  String? get localLanEndpoint {
    if (_server == null || _addresses.isEmpty) return null;
    return '${_addresses.first}:$port';
  }

  /// Every non loopback IPv4 address the host currently has, so a phone with
  /// both Wi-Fi and a hotspot offers both to the QR payload.
  Future<List<String>> refreshLanAddresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final addresses = <String>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.isLoopback) continue;
        if (address.address.startsWith('169.254.')) continue;
        addresses.add(address.address);
      }
    }
    _addresses = List<String>.unmodifiable(addresses);
    return _addresses;
  }

  @override
  Future<void> start() async {
    if (_server != null) return;
    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      _requestedPort,
    );
    server.autoCompress = false;
    _server = server;
    _subscriptions.add(server.listen(_handleRequest, onError: (Object _) {}));
    await refreshLanAddresses();
    await _advertiser.advertise(roomId: roomId, port: server.port);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final token = request.uri.queryParameters['token'];
    final authorized =
        request.uri.path == path &&
        token != null &&
        secureCompare(token, secret) &&
        WebSocketTransformer.isUpgradeRequest(request);

    if (!authorized) {
      request.response.statusCode = token == null ? 401 : 404;
      await request.response.close();
      return;
    }

    final socket = await WebSocketTransformer.upgrade(request);
    final peerId = 'c_lan${_nextPeer++}';
    _sockets[peerId] = socket;

    _subscriptions.add(
      socket.listen(
        (data) {
          final raw = data is String ? data : _decodeBytes(data);
          try {
            final message = WireMessage.decode(raw);
            if (!_messages.isClosed) {
              _messages.add(
                HostIncomingMessage(clientId: peerId, message: message),
              );
            }
          } on WireFormatException {
            socket.close(4400, 'bad frame');
          }
        },
        onDone: () => _dropPeer(peerId),
        onError: (Object _) => _dropPeer(peerId),
        cancelOnError: true,
      ),
    );
    if (!_connected.isClosed) _connected.add(peerId);
  }

  void _dropPeer(String peerId) {
    if (_sockets.remove(peerId) == null) return;
    if (!_disconnected.isClosed) _disconnected.add(peerId);
  }

  @override
  Future<void> sendToClient(String clientId, WireMessage message) async {
    final socket = _sockets[clientId];
    if (socket == null) {
      throw TransportException('unknown_client', 'no socket for $clientId');
    }
    socket.add(message.encode());
  }

  @override
  Future<void> broadcast(WireMessage message) async {
    final frame = message.encode();
    for (final socket in List<WebSocket>.of(_sockets.values)) {
      try {
        socket.add(frame);
      } on Object {
        // A half closed socket must not stop the frame reaching other players.
      }
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    for (final socket in _sockets.values) {
      await socket.close(1001, 'host closed');
    }
    _sockets.clear();
    await _advertiser.stop();
    await _server?.close(force: true);
    _server = null;
    await _connected.close();
    await _disconnected.close();
    await _messages.close();
  }
}

/// Dialled by a player. [endpoint] is the `host:port` pair from the QR payload.
class LocalWsClientTransport implements ClientTransport {
  LocalWsClientTransport({
    required this.endpoint,
    required this.secret,
    this.connectTimeout = const Duration(milliseconds: 800),
  });

  final String endpoint;
  final String secret;
  final Duration connectTimeout;

  final StreamController<WireMessage> _messages =
      StreamController<WireMessage>.broadcast();
  final StreamController<void> _disconnected =
      StreamController<void>.broadcast();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;

  @override
  ConnectionMode get mode => ConnectionMode.localLan;

  @override
  TurnLimitNotice? get turnLimitNotice => null;

  @override
  Stream<WireMessage> get messages => _messages.stream;

  @override
  Stream<void> get disconnected => _disconnected.stream;

  @override
  Future<void> connect() async {
    final uri = Uri.parse(
      'ws://$endpoint${LocalWsHostTransport.path}?token=$secret',
    );
    final socket = await WebSocket.connect(uri.toString()).timeout(
      connectTimeout,
      onTimeout: () => throw const TransportException(
        'connect_timeout',
        'LAN host unreachable',
      ),
    );
    _socket = socket;
    _subscription = socket.listen(
      (data) {
        final raw = data is String ? data : _decodeBytes(data);
        try {
          final message = WireMessage.decode(raw);
          if (!_messages.isClosed) _messages.add(message);
        } on WireFormatException {
          // A malformed frame ends the round, not the app.
        }
      },
      onDone: _fireDisconnected,
      onError: (Object _) => _fireDisconnected(),
      cancelOnError: true,
    );
  }

  void _fireDisconnected() {
    if (!_disconnected.isClosed) _disconnected.add(null);
  }

  @override
  Future<void> send(WireMessage message) async {
    final socket = _socket;
    if (socket == null) {
      throw const TransportException('not_connected', 'call connect first');
    }
    socket.add(message.encode());
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    await _socket?.close(1000, 'bye');
    _socket = null;
    await _messages.close();
    await _disconnected.close();
  }
}

String _decodeBytes(Object data) {
  if (data is String) return data;
  return utf8.decode(data as List<int>);
}
