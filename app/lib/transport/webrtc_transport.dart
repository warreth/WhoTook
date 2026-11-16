import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/build_flavor.dart';
import '../core/models/models.dart';
import '../core/party_pass/turn_relay_client.dart';
import '../core/protocol/wire_message.dart';
import '../core/qr/invite_codec.dart';
import 'game_transport.dart';

/// Raised when the signaling server refused TURN for this IP and direct P2P
/// also failed, so the player has to move to the same Wi-Fi or a hotspot.
class TurnQuotaBlockedException implements Exception {
  const TurnQuotaBlockedException(this.notice);

  final TurnLimitNotice notice;

  @override
  String toString() => 'TurnQuotaBlockedException(${notice.reason})';
}

/// Direct P2P failed and no relay credentials were available. This is the
/// strict 5G / carrier-NAT case the lobby explains to the player.
class RelayRequiredException implements Exception {
  const RelayRequiredException({this.passActive = false, this.relayErrorCode});

  final bool passActive;
  final String? relayErrorCode;

  @override
  String toString() =>
      'RelayRequiredException(passActive: $passActive, $relayErrorCode)';
}

class IceServerConfig {
  const IceServerConfig({required this.urls, this.username, this.credential});

  final List<String> urls;
  final String? username;
  final String? credential;

  Map<String, dynamic> toWebRtc() => <String, dynamic>{
    'urls': urls,
    if (username != null) 'username': username,
    if (credential != null) 'credential': credential,
  };

  static IceServerConfig fromJson(Map<String, dynamic> json) {
    final raw = json['urls'];
    final urls = raw is List
        ? raw.map((e) => e.toString()).toList()
        : <String>[raw.toString()];
    return IceServerConfig(
      urls: urls,
      username: json['username'] as String?,
      credential: json['credential'] as String?,
    );
  }
}

class IceConfig {
  const IceConfig({
    required this.turnAllowed,
    required this.iceServers,
    this.reason,
    this.dailyLimit = 5,
    this.usedToday = 0,
    this.retryAtUtc,
    this.remainingMatchesToday = 0,
    this.relayPassActive = false,
    this.relayErrorCode,
  });

  final bool turnAllowed;
  final List<IceServerConfig> iceServers;
  final String? reason;
  final int dailyLimit;
  final int usedToday;
  final DateTime? retryAtUtc;
  final int remainingMatchesToday;
  final bool relayPassActive;
  final String? relayErrorCode;

  Map<String, dynamic> toRtcConfiguration() => <String, dynamic>{
    'iceServers': iceServers.map((s) => s.toWebRtc()).toList(),
    'sdpSemantics': 'unified-plan',
  };

  factory IceConfig.fromJson(Map<String, dynamic> json) {
    final servers = <IceServerConfig>[];
    for (final entry in (json['iceServers'] as List<dynamic>? ?? const [])) {
      if (entry is Map<String, dynamic>) {
        servers.add(IceServerConfig.fromJson(entry));
      }
    }
    final retry = json['retryAtUtc'];
    return IceConfig(
      turnAllowed: json['turnAllowed'] as bool? ?? false,
      iceServers: servers,
      reason: json['reason'] as String?,
      dailyLimit: json['dailyLimit'] as int? ?? 5,
      usedToday: json['usedToday'] as int? ?? 0,
      retryAtUtc: retry is String ? DateTime.tryParse(retry) : null,
      remainingMatchesToday: json['remainingMatchesToday'] as int? ?? 0,
    );
  }
}

/// Asks the signaling Worker for ICE servers and applies the per IP TURN
/// quota. A custom TURN server from Settings always wins, because a
/// self-hosted match must not depend on the shared free pool.
class SignalingIceClient {
  SignalingIceClient({
    required this.signalingUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 6),
    this.turnRelay,
    this.acceptServerTurn = !BuildFlavor.official,
    this.noRoomRetryDelay = const Duration(milliseconds: 250),
    this.noRoomRetryAttempts = 20,
  }) : _http = httpClient ?? http.Client();

  final String signalingUrl;
  final Duration timeout;
  final http.Client _http;

  /// Official builds obtain relay credentials only from a verified Party Pass.
  /// Legacy self-hosted signaling servers may still return TURN to FOSS builds.
  final Future<TurnRelayAttempt> Function()? turnRelay;
  final bool acceptServerTurn;
  final Duration noRoomRetryDelay;
  final int noRoomRetryAttempts;

  Future<IceConfig> fetch({
    required String roomId,
    required String token,
    AppSettings settings = const AppSettings(),
  }) async {
    final custom = _customTurn(settings);
    if (custom != null) {
      // A self-hosted relay does not need our `/ice-config` contract, and a
      // signaling-only server may not implement it. Use public STUN plus the
      // operator's TURN entry directly.
      return IceConfig(
        turnAllowed: true,
        iceServers: <IceServerConfig>[
          const IceServerConfig(
            urls: <String>['stun:stun.cloudflare.com:3478'],
          ),
          custom,
        ],
      );
    }
    // A `wss://` custom URL is common, but ICE config is a plain HTTPS call.
    final origin = signalingUrl
        .replaceFirst(RegExp(r'^ws://'), 'http://')
        .replaceFirst(RegExp(r'^wss://'), 'https://');
    final base = Uri.parse(origin);
    final endpoint = base.replace(
      path: '${base.path.replaceAll(RegExp(r'/+$'), '')}/ice-config',
      query: null,
      fragment: null,
    );
    late http.Response response;
    for (var attempt = 0; ; attempt += 1) {
      response = await _http
          .post(
            endpoint,
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, String>{
              'roomId': roomId,
              'token': token,
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 401) break;
      if (!_isNoRoom(response.body) || attempt >= noRoomRetryAttempts) {
        throw const TransportException('unauthorized', 'room token rejected');
      }
      // The host may still be opening its signaling room. Wait briefly for it
      // instead of failing the whole join.
      await Future<void>.delayed(noRoomRetryDelay);
    }

    if (response.statusCode != 200) {
      throw TransportException(
        'ice_config_failed',
        'status ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final parsed = IceConfig.fromJson(decoded);
    final config = acceptServerTurn
        ? parsed
        : IceConfig(
            turnAllowed: false,
            iceServers: parsed.iceServers
                .where(
                  (server) => server.urls.every(
                    (url) =>
                        url.startsWith('stun:') || url.startsWith('stuns:'),
                  ),
                )
                .toList(growable: false),
            reason: parsed.reason,
            dailyLimit: parsed.dailyLimit,
            usedToday: parsed.usedToday,
            retryAtUtc: parsed.retryAtUtc,
          );
    final relay = turnRelay;
    if (relay == null) return config;
    final attempt = await relay();
    final grant = attempt.grant;
    if (grant == null) {
      return IceConfig(
        turnAllowed: false,
        iceServers: config.iceServers,
        reason: attempt.errorCode ?? config.reason,
        dailyLimit: config.dailyLimit,
        usedToday: config.usedToday,
        retryAtUtc: config.retryAtUtc,
        relayPassActive: attempt.passActive,
        relayErrorCode: attempt.errorCode,
      );
    }
    final relayServers = <IceServerConfig>[
      for (final server in grant.iceServers)
        IceServerConfig(
          urls: server.urls,
          username: server.username,
          credential: server.credential,
        ),
    ];
    return IceConfig(
      turnAllowed: true,
      iceServers: <IceServerConfig>[...config.iceServers, ...relayServers],
      reason: config.reason,
      dailyLimit: grant.dailyLimit,
      usedToday: grant.dailyLimit - grant.remainingMatchesToday,
      retryAtUtc: config.retryAtUtc,
      remainingMatchesToday: grant.remainingMatchesToday,
      relayPassActive: true,
    );
  }

  bool _isNoRoom(String body) {
    try {
      final parsed = jsonDecode(body);
      return parsed is Map<String, dynamic> && parsed['error'] == 'NO_ROOM';
    } on FormatException {
      return false;
    }
  }

  IceServerConfig? _customTurn(AppSettings settings) {
    final url = settings.customTurnUrl?.trim();
    if (url == null || url.isEmpty) return null;
    final username = settings.customTurnUsername?.trim();
    final credential = settings.customTurnCredential?.trim();
    return IceServerConfig(
      urls: <String>[url],
      username: (username == null || username.isEmpty) ? null : username,
      credential: (credential == null || credential.isEmpty)
          ? null
          : credential,
    );
  }
}

/// Shared WebSocket signaling + DataChannel plumbing for both roles.
abstract class _WebRtcTransportBase {
  _WebRtcTransportBase({required this.invite, required this.role});

  final InvitePayload invite;
  final String role;

  final StreamController<WireMessage> _messages =
      StreamController<WireMessage>.broadcast();
  final StreamController<void> _disconnected =
      StreamController<void>.broadcast();

  WebSocketChannel? _signaling;
  RTCPeerConnection? _peer;
  RTCDataChannel? _channel;
  StreamSubscription<dynamic>? _signalingSub;
  TurnLimitNotice? _turnNotice;

  Stream<WireMessage> get messages => _messages.stream;

  Stream<void> get disconnected => _disconnected.stream;

  TurnLimitNotice? get turnLimitNotice => _turnNotice;

  Uri get signalingUri {
    final base = invite.signalingUrl;
    if (base == null || base.isEmpty) {
      throw const TransportException(
        'no_signaling',
        'invite has no signaling url',
      );
    }
    final origin = base.replaceFirst(RegExp(r'^http'), 'ws');
    return Uri.parse(
      '${origin.replaceAll(RegExp(r'/+$'), '')}/room/${invite.roomId}'
      '?role=$role&token=${invite.secret}',
    );
  }

  Future<void> openSignaling() async {
    final channel = WebSocketChannel.connect(signalingUri);
    await channel.ready.timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw const TransportException(
        'signaling_timeout',
        'server unreachable',
      ),
    );
    _signaling = channel;
    _signalingSub = channel.stream.listen(
      _onSignalingFrame,
      onDone: _fireDisconnected,
      onError: (Object _) => _fireDisconnected(),
      cancelOnError: true,
    );
  }

  void _onSignalingFrame(dynamic data) {
    final raw = data is String ? data : utf8.decode(data as List<int>);
    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return;
    }
    switch (parsed['type']) {
      case 'welcome':
        onWelcome(parsed);
      case 'peer_joined':
        onPeerJoined(parsed);
      case 'offer':
        onOffer(parsed);
      case 'answer':
        onAnswer(parsed);
      case 'ice':
        onRemoteIce(parsed);
      case 'peer_left':
      case 'room_closed':
        _fireDisconnected();
    }
  }

  void onWelcome(Map<String, dynamic> frame);

  void onPeerJoined(Map<String, dynamic> frame) {}

  Future<void> onOffer(Map<String, dynamic> frame);

  Future<void> onAnswer(Map<String, dynamic> frame);

  Future<void> onRemoteIce(Map<String, dynamic> frame);

  void sendSignal(String type, {String? to, Map<String, dynamic>? payload}) {
    final signaling = _signaling;
    if (signaling == null) return;
    signaling.sink.add(
      jsonEncode(<String, dynamic>{
        'type': type,
        'to': ?to,
        'payload': payload ?? const <String, dynamic>{},
      }),
    );
  }

  void attachChannel(RTCDataChannel channel) {
    _channel = channel;
    channel.onMessage = (message) {
      try {
        final decoded = WireMessage.decode(message.text);
        if (!_messages.isClosed) _messages.add(decoded);
      } on WireFormatException {
        // A malformed application frame never closes the peer connection.
      }
    };
    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _fireDisconnected();
      }
    };
  }

  Future<void> sendOverChannel(WireMessage message) async {
    final channel = _channel;
    if (channel == null ||
        channel.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw const TransportException(
        'not_connected',
        'data channel is not open',
      );
    }
    channel.send(RTCDataChannelMessage(message.encode()));
  }

  void _fireDisconnected() {
    if (!_disconnected.isClosed) _disconnected.add(null);
  }

  Future<void> closeAll() async {
    await _signalingSub?.cancel();
    _signalingSub = null;
    await _signaling?.sink.close();
    _signaling = null;
    await _channel?.close();
    _channel = null;
    await _peer?.close();
    _peer = null;
    await _messages.close();
    await _disconnected.close();
  }
}

/// Converts an HTTP(S) signaling origin to the matching WebSocket scheme.
String _toWebSocketOrigin(String url) {
  if (url.startsWith('https://')) return 'wss://${url.substring(8)}';
  if (url.startsWith('http://')) return 'ws://${url.substring(7)}';
  return url;
}

/// Host side of the online path. One peer connection per remote player is
/// created by the host when the signaling server reports a joiner.
class WebRtcHostTransport implements HostTransport {
  WebRtcHostTransport({
    required this.invite,
    required this.iceClient,
    this.settings = const AppSettings(),
  });

  final InvitePayload invite;
  final SignalingIceClient iceClient;
  final AppSettings settings;

  final StreamController<String> _connected =
      StreamController<String>.broadcast();
  final StreamController<String> _disconnected =
      StreamController<String>.broadcast();
  final StreamController<HostIncomingMessage> _messages =
      StreamController<HostIncomingMessage>.broadcast();
  final Map<String, WebRtcHostPeer> _peers = <String, WebRtcHostPeer>{};
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  WebSocketChannel? _signaling;
  IceConfig? _iceConfig;
  bool _configReady = false;
  bool _closed = false;
  final List<Map<String, dynamic>> _pendingSignaling = <Map<String, dynamic>>[];

  @override
  Stream<String> get clientConnected => _connected.stream;

  @override
  Stream<String> get clientDisconnected => _disconnected.stream;

  @override
  Stream<HostIncomingMessage> get messages => _messages.stream;

  @override
  String? get localLanEndpoint => null;

  @override
  Future<void> start() async {
    if (_closed) return;
    final origin = _toWebSocketOrigin(invite.signalingUrl ?? '');
    final uri = Uri.parse(
      '${origin.replaceAll(RegExp(r'/+$'), '')}'
      '/room/${invite.roomId}?role=host&token=${invite.secret}',
    );
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    if (_closed) {
      await channel.sink.close();
      return;
    }
    _signaling = channel;
    _subscriptions.add(
      channel.stream.listen(
        _onFrame,
        onError: (Object _) {},
        cancelOnError: true,
      ),
    );
    try {
      final config = await iceClient.fetch(
        roomId: invite.roomId,
        token: invite.secret,
        settings: settings,
      );
      if (_closed) {
        _pendingSignaling.clear();
        await channel.sink.close();
        _signaling = null;
        return;
      }
      _iceConfig = config;
      _configReady = true;
      final pending = List<Map<String, dynamic>>.of(_pendingSignaling);
      _pendingSignaling.clear();
      for (final frame in pending) {
        if (_closed) break;
        await handleSignalingFrame(frame);
      }
      if (_closed) {
        _pendingSignaling.clear();
        await channel.sink.close();
        _signaling = null;
      }
    } on Object {
      await channel.sink.close();
      _signaling = null;
      rethrow;
    }
  }

  Future<void> _onFrame(dynamic data) async {
    if (_closed) return;
    final raw = data is String ? data : utf8.decode(data as List<int>);
    final Map<String, dynamic> frame;
    try {
      frame = jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return;
    }
    if (!_configReady) {
      if (_pendingSignaling.length < 64) _pendingSignaling.add(frame);
      return;
    }
    await handleSignalingFrame(frame);
  }

  /// Routes one signaling frame. Public so frame parsing can be unit tested
  /// without a live WebSocket or a native peer connection.
  Future<void> handleSignalingFrame(Map<String, dynamic> frame) async {
    if (_closed) return;
    switch (frame['type']) {
      case 'peer_joined':
        final peerId = frame['peerId'] as String?;
        if (peerId == null) return;
        final existing = _peers.remove(peerId);
        if (existing != null) await existing.close();
        final peer = _createPeer(peerId);
        _peers[peerId] = peer;
        await peer.createOffer();
        if (_closed) {
          _peers.remove(peerId);
          await peer.close();
        }
      case 'answer':
        final from = frame['from'] as String?;
        final payload = frame['payload'] as Map<String, dynamic>?;
        if (from == null || payload == null) return;
        await _peers[from]?.onAnswer(
          RTCSessionDescription(
            payload['sdp'] as String?,
            payload['type'] as String?,
          ),
        );
      case 'ice':
        final from = frame['from'] as String?;
        final payload = frame['payload'] as Map<String, dynamic>?;
        final candidate = payload?['candidate'] as String?;
        if (from == null || candidate == null) return;
        await _peers[from]?.onRemoteIce(
          RTCIceCandidate(
            candidate,
            payload!['sdpMid'] as String?,
            payload['sdpMLineIndex'] as int?,
          ),
        );
      case 'peer_left':
        final peerId = frame['peerId'] as String?;
        if (peerId == null) return;
        final peer = _peers.remove(peerId);
        await peer?.close();
        if (!_disconnected.isClosed) _disconnected.add(peerId);
    }
  }

  WebRtcHostPeer _createPeer(String peerId) => WebRtcHostPeer(
    peerId: peerId,
    configuration:
        (_iceConfig ??
                const IceConfig(
                  turnAllowed: false,
                  iceServers: <IceServerConfig>[],
                ))
            .toRtcConfiguration(),
    sendSignal: (type, payload) => _sendSignal(type, peerId, payload),
    onMessage: (message) {
      if (!_messages.isClosed) {
        _messages.add(HostIncomingMessage(clientId: peerId, message: message));
      }
    },
    onOpen: () {
      if (!_connected.isClosed) _connected.add(peerId);
    },
    onClosed: () {
      _peers.remove(peerId);
      if (!_disconnected.isClosed) _disconnected.add(peerId);
    },
  );

  void _sendSignal(String type, String to, Map<String, dynamic> payload) {
    _signaling?.sink.add(
      jsonEncode(<String, dynamic>{'type': type, 'to': to, 'payload': payload}),
    );
  }

  @override
  Future<void> sendToClient(String clientId, WireMessage message) async {
    final peer = _peers[clientId];
    if (peer == null) {
      throw TransportException('unknown_client', 'no peer for $clientId');
    }
    await peer.send(message);
  }

  @override
  Future<void> broadcast(WireMessage message) async {
    for (final peer in List<WebRtcHostPeer>.of(_peers.values)) {
      if (!peer.isOpen) continue;
      try {
        await peer.send(message);
      } on TransportException {
        // A peer that is closing must not abort delivery to healthy peers.
      }
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _pendingSignaling.clear();
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    for (final peer in _peers.values) {
      await peer.close();
    }
    _peers.clear();
    await _signaling?.sink.close();
    _signaling = null;
    await _connected.close();
    await _disconnected.close();
    await _messages.close();
  }
}

/// Host end of one remote player.
class WebRtcHostPeer {
  WebRtcHostPeer({
    required this.peerId,
    required this.configuration,
    required this.sendSignal,
    required this.onMessage,
    required this.onOpen,
    required this.onClosed,
  });

  final String peerId;
  final Map<String, dynamic> configuration;
  final void Function(String type, Map<String, dynamic> payload) sendSignal;
  final void Function(WireMessage message) onMessage;
  final void Function() onOpen;
  final void Function() onClosed;

  RTCPeerConnection? _peer;
  RTCDataChannel? _channel;

  bool get isOpen => _channel?.state == RTCDataChannelState.RTCDataChannelOpen;

  Future<void> createOffer() async {
    final peer = await createPeerConnection(configuration);
    _peer = peer;
    final channel = await peer.createDataChannel(
      'game',
      RTCDataChannelInit()..ordered = true,
    );
    _channel = channel;
    _bindChannel(channel);

    peer.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      sendSignal('ice', <String, dynamic>{
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    final offer = await peer.createOffer();
    await peer.setLocalDescription(offer);
    sendSignal('offer', <String, dynamic>{
      'sdp': offer.sdp,
      'type': offer.type,
    });
  }

  Future<void> onAnswer(RTCSessionDescription answer) async {
    await _peer?.setRemoteDescription(answer);
  }

  Future<void> onRemoteIce(RTCIceCandidate candidate) async {
    await _peer?.addCandidate(candidate);
  }

  void _bindChannel(RTCDataChannel channel) {
    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) onOpen();
      if (state == RTCDataChannelState.RTCDataChannelClosed) onClosed();
    };
    channel.onMessage = (message) {
      try {
        onMessage(WireMessage.decode(message.text));
      } on WireFormatException {
        // Ignore malformed frames rather than tearing down a healthy peer.
      }
    };
  }

  Future<void> send(WireMessage message) async {
    final channel = _channel;
    if (channel == null ||
        channel.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw const TransportException('not_connected', 'data channel closed');
    }
    channel.send(RTCDataChannelMessage(message.encode()));
  }

  Future<void> close() async {
    await _channel?.close();
    _channel = null;
    await _peer?.close();
    _peer = null;
  }
}

/// Player side of the online path.
class WebRtcClientTransport extends _WebRtcTransportBase
    implements ClientTransport {
  WebRtcClientTransport({
    required super.invite,
    required this.iceClient,
    this.settings = const AppSettings(),
    this.iceTimeout = const Duration(seconds: 20),
  }) : super(role: 'client');

  final SignalingIceClient iceClient;
  final AppSettings settings;

  /// Covers the host's /ice-config plus relay issuance before its offer. A
  /// failed free P2P attempt waits this long before the firewall prompt.
  final Duration iceTimeout;

  IceConfig? _config;
  Completer<void>? _channelOpen;

  @override
  ConnectionMode get mode {
    if (_config?.turnAllowed == true) return ConnectionMode.webrtcTurn;
    return ConnectionMode.webrtcP2p;
  }

  @override
  Future<void> connect() async {
    _channelOpen = Completer<void>();
    _config = await iceClient.fetch(
      roomId: invite.roomId,
      token: invite.secret,
      settings: settings,
    );
    if (!_config!.turnAllowed && _config!.reason != null) {
      _turnNotice = TurnLimitNotice(
        reason: _config!.reason!,
        dailyLimit: _config!.dailyLimit,
        usedToday: _config!.usedToday,
        retryAtUtc: _config!.retryAtUtc ?? DateTime.now().toUtc(),
      );
    }
    await openSignaling();
    await _channelOpen!.future.timeout(
      iceTimeout,
      onTimeout: () {
        final relayFailure = relayRequiredForTimeout(_config);
        if (relayFailure != null) throw relayFailure;
        final notice = _turnNotice;
        if (notice != null) throw TurnQuotaBlockedException(notice);
        throw const TransportException('ice_failed', 'peer connection failed');
      },
    );
  }

  /// A pass holder whose granted relay still timed out gets the relay prompt,
  /// not the generic "cannot reach host" error.
  RelayRequiredException? relayRequiredForTimeout(IceConfig? config) {
    if (config == null) return null;
    if (config.relayPassActive || !config.turnAllowed) {
      return RelayRequiredException(
        passActive: config.relayPassActive,
        relayErrorCode:
            config.relayErrorCode ?? (config.turnAllowed ? 'ice_failed' : null),
      );
    }
    return null;
  }

  @override
  void onWelcome(Map<String, dynamic> frame) {}

  @override
  Future<void> onOffer(Map<String, dynamic> frame) async {
    final payload = frame['payload'] as Map<String, dynamic>? ?? const {};
    final peer = await createPeerConnection(
      (_config ??
              const IceConfig(
                turnAllowed: false,
                iceServers: <IceServerConfig>[],
              ))
          .toRtcConfiguration(),
    );
    _peer = peer;

    peer.onDataChannel = (channel) {
      attachChannel(channel);
      if (!(_channelOpen?.isCompleted ?? true)) _channelOpen!.complete();
    };
    peer.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      sendSignal(
        'ice',
        payload: <String, dynamic>{
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };

    await peer.setRemoteDescription(
      RTCSessionDescription(
        payload['sdp'] as String?,
        payload['type'] as String?,
      ),
    );
    final answer = await peer.createAnswer();
    await peer.setLocalDescription(answer);
    sendSignal(
      'answer',
      payload: <String, dynamic>{'sdp': answer.sdp, 'type': answer.type},
    );
  }

  @override
  Future<void> onAnswer(Map<String, dynamic> frame) async {
    final payload = frame['payload'] as Map<String, dynamic>? ?? const {};
    await _peer?.setRemoteDescription(
      RTCSessionDescription(
        payload['sdp'] as String?,
        payload['type'] as String?,
      ),
    );
  }

  @override
  Future<void> onRemoteIce(Map<String, dynamic> frame) async {
    final payload = frame['payload'] as Map<String, dynamic>? ?? const {};
    final candidate = payload['candidate'] as String?;
    if (candidate == null) return;
    await _peer?.addCandidate(
      RTCIceCandidate(
        candidate,
        payload['sdpMid'] as String?,
        payload['sdpMLineIndex'] as int?,
      ),
    );
  }

  @override
  void onPeerJoined(Map<String, dynamic> frame) {}

  @override
  Future<void> send(WireMessage message) => sendOverChannel(message);

  @override
  Future<void> close() => closeAll();
}
