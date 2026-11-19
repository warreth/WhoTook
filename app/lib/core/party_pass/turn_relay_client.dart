import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'party_pass_repository.dart';

/// One ICE server returned by the private Party Pass relay.
class RelayIceServer {
  const RelayIceServer({required this.urls, this.username, this.credential});

  final List<String> urls;
  final String? username;
  final String? credential;

  factory RelayIceServer.fromJson(Map<String, dynamic> json) {
    final raw = json['urls'];
    final urls = raw is List
        ? raw.map((value) => value.toString()).toList()
        : <String>[if (raw != null) raw.toString()];
    return RelayIceServer(
      urls: urls.where((url) => url.isNotEmpty).toList(growable: false),
      username: json['username'] as String?,
      credential: json['credential'] as String?,
    );
  }
}

class TurnRelayGrant {
  const TurnRelayGrant({
    required this.iceServers,
    required this.ttlSeconds,
    required this.expiresAtUtc,
    required this.remainingMatchesToday,
    required this.dailyLimit,
  });

  final List<RelayIceServer> iceServers;
  final int ttlSeconds;
  final DateTime expiresAtUtc;
  final int remainingMatchesToday;
  final int dailyLimit;
}

/// One relay attempt. [passActive] lets the connection failure UI distinguish
/// "buy the pass" from "the relay is temporarily unavailable".
class TurnRelayAttempt {
  const TurnRelayAttempt({
    this.grant,
    this.passActive = false,
    this.errorCode,
    this.retryAtUtc,
  });

  final TurnRelayGrant? grant;
  final bool passActive;
  final String? errorCode;
  final DateTime? retryAtUtc;
}

class TurnRelayVerification {
  const TurnRelayVerification({
    required this.valid,
    required this.remainingMatchesToday,
    required this.dailyLimit,
  });

  final bool valid;
  final int remainingMatchesToday;
  final int dailyLimit;
}

/// Failure codes shared by the app and the private server. Codes, never the
/// receipt, are safe to show in the UI or write to a log.
abstract final class TurnRelayErrorCode {
  static const String invalidRequest = 'invalid_request';
  static const String invalidReceipt = 'invalid_receipt';
  static const String productMismatch = 'product_mismatch';
  static const String fairUseLimit = 'fair_use_limit_reached';
  static const String rateLimited = 'rate_limited';
  static const String relayUnavailable = 'relay_unavailable';
  static const String network = 'network_error';
  static const String malformed = 'malformed_response';
}

class TurnRelayException implements Exception {
  const TurnRelayException(
    this.code, {
    this.remainingMatchesToday,
    this.retryAtUtc,
  });

  final String code;
  final int? remainingMatchesToday;
  final DateTime? retryAtUtc;

  @override
  String toString() => 'TurnRelayException($code)';
}

/// Fetches short-lived coturn credentials for a verified store purchase.
class TurnRelayClient {
  TurnRelayClient({
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final Duration timeout;

  static const String defaultBaseUrl = 'https://signal.whotook.party/api/v1';

  Future<TurnRelayGrant> fetchCredentials({
    required String baseUrl,
    required PartyPassCredential credential,
  }) async {
    final json = await _post(
      baseUrl: baseUrl,
      path: '/turn-credentials',
      credential: credential,
    );
    final servers = <RelayIceServer>[];
    final rawServers = json['iceServers'];
    if (rawServers is List) {
      for (final entry in rawServers) {
        if (entry is Map<String, dynamic>) {
          final server = RelayIceServer.fromJson(entry);
          if (server.urls.isNotEmpty) servers.add(server);
        }
      }
    }
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
    final ttl = json['ttlSeconds'];
    if (servers.isEmpty || expiresAt == null || ttl is! int || ttl <= 0) {
      throw const TurnRelayException(TurnRelayErrorCode.malformed);
    }
    return TurnRelayGrant(
      iceServers: servers,
      ttlSeconds: ttl,
      expiresAtUtc: expiresAt.toUtc(),
      remainingMatchesToday: (json['remainingMatchesToday'] as int?) ?? 0,
      dailyLimit: (json['dailyLimit'] as int?) ?? 0,
    );
  }

  Future<TurnRelayVerification> verify({
    required String baseUrl,
    required PartyPassCredential credential,
  }) async {
    final json = await _post(
      baseUrl: baseUrl,
      path: '/party-pass/verify',
      credential: credential,
    );
    return TurnRelayVerification(
      valid: json['valid'] as bool? ?? false,
      remainingMatchesToday: (json['remainingMatchesToday'] as int?) ?? 0,
      dailyLimit: (json['dailyLimit'] as int?) ?? 0,
    );
  }

  Future<Map<String, dynamic>> _post({
    required String baseUrl,
    required String path,
    required PartyPassCredential credential,
  }) async {
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');
    final http.Response response;
    try {
      response = await _http
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, String>{
              'platform': credential.platform.wireValue,
              'productId': credential.productId,
              'verificationToken': credential.verificationToken,
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const TurnRelayException(TurnRelayErrorCode.network);
    } on Object {
      throw const TurnRelayException(TurnRelayErrorCode.network);
    }

    Map<String, dynamic>? decoded;
    try {
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) decoded = value;
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode == 200 && decoded != null) return decoded;

    final code = _codeForStatus(
      response.statusCode,
      decoded?['error'] as String?,
    );
    throw TurnRelayException(
      code,
      remainingMatchesToday: decoded?['remainingMatchesToday'] as int?,
      retryAtUtc: DateTime.tryParse(decoded?['retryAtUtc'] as String? ?? '')
          ?.toUtc(),
    );
  }

  String _codeForStatus(int status, String? serverCode) {
    return switch (status) {
      400 => TurnRelayErrorCode.invalidRequest,
      401 || 403 => TurnRelayErrorCode.invalidReceipt,
      409 => TurnRelayErrorCode.productMismatch,
      429 =>
        serverCode == TurnRelayErrorCode.fairUseLimit
            ? TurnRelayErrorCode.fairUseLimit
            : TurnRelayErrorCode.rateLimited,
      503 => TurnRelayErrorCode.relayUnavailable,
      _ => TurnRelayErrorCode.network,
    };
  }

  void close() => _http.close();
}
