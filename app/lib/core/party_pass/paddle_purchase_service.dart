import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../distribution.dart';
import 'party_pass_repository.dart';
import 'purchase_service.dart';
import 'turn_relay_client.dart';

/// Direct-build billing through the private Worker and Paddle Checkout.
///
/// The app never talks to Paddle directly and never sees the API key. It asks
/// the Worker for a transaction URL, opens it in the system browser, and polls
/// for the license that the signed Paddle webhook provisions.
class PaddlePartyPassPurchaseService implements PartyPassPurchaseService {
  PaddlePartyPassPurchaseService({
    http.Client? httpClient,
    PartyPassRepository? repository,
    Future<bool> Function(Uri uri)? openUrl,
    this.baseUrl = TurnRelayClient.defaultBaseUrl,
    this.requestTimeout = const Duration(seconds: 10),
    this.pollInterval = const Duration(seconds: 2),
    this.pollTimeout = const Duration(minutes: 3),
  }) : _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null,
       _repository = repository ?? PartyPassRepository(),
       _openUrl = openUrl ?? _launchExternal;

  final http.Client _http;
  final bool _ownsHttp;
  final PartyPassRepository _repository;
  final Future<bool> Function(Uri uri) _openUrl;
  final String baseUrl;
  final Duration requestTimeout;
  final Duration pollInterval;
  final Duration pollTimeout;

  final StreamController<PartyPassPurchaseEvent> _events =
      StreamController<PartyPassPurchaseEvent>.broadcast();

  bool _available = false;
  bool _initialized = false;
  bool _busy = false;

  @override
  Stream<PartyPassPurchaseEvent> get events => _events.stream;

  @override
  String? get priceLabel => kDirectPriceLabel;

  @override
  bool get available => _available;

  @override
  PartyPassBillingKind get kind => PartyPassBillingKind.paddle;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final json = await _get('/party-pass/config');
      _available = json['paddle'] == true && json['checkoutAvailable'] == true;
    } on Object {
      // The server may be offline while the app is already usable. Keep the
      // purchase button visible but let buy() report the real error.
      _available = true;
    }
  }

  @override
  Future<PartyPassPurchaseEvent> buy() async {
    if (_busy) {
      return const PartyPassPurchaseEvent(
        status: PartyPassPurchaseStatus.pending,
      );
    }
    _busy = true;
    try {
      final ref = await _repository.loadPendingRef() ?? _newPurchaseRef();
      await _repository.savePendingRef(ref);

      final checkout = await _post('/party-pass/checkout', <String, Object>{
        'productId': kPartyPassProductId,
        'purchaseRef': ref,
      });
      final checkoutStatus = checkout['status'];
      if (checkoutStatus == 'completed') {
        return _completed(checkout);
      }

      final checkoutUrl = checkout['checkoutUrl'];
      if (checkoutUrl is! String || checkoutUrl.isEmpty) {
        return const PartyPassPurchaseEvent(
          status: PartyPassPurchaseStatus.error,
          code: 'checkout_unavailable',
        );
      }
      final opened = await _openUrl(Uri.parse(checkoutUrl));
      if (!opened) {
        return const PartyPassPurchaseEvent(
          status: PartyPassPurchaseStatus.error,
          code: 'checkout_open_failed',
        );
      }

      final deadline = DateTime.now().add(pollTimeout);
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(pollInterval);
        final purchase = await _post('/party-pass/purchase', <String, Object>{
          'productId': kPartyPassProductId,
          'purchaseRef': ref,
        });
        final status = purchase['status'];
        if (status == 'completed') return _completed(purchase);
        if (status != 'pending') {
          await _repository.clearPendingRef();
          return PartyPassPurchaseEvent(
            status: PartyPassPurchaseStatus.error,
            code: status is String ? status : 'purchase_failed',
          );
        }
      }
      return const PartyPassPurchaseEvent(
        status: PartyPassPurchaseStatus.pending,
      );
    } on _PaddleHttpException catch (error) {
      if (error.code == 'purchase_expired' ||
          error.code == 'purchase_not_found') {
        await _repository.clearPendingRef();
      }
      return PartyPassPurchaseEvent(
        status: PartyPassPurchaseStatus.error,
        code: error.code,
      );
    } on Object {
      return const PartyPassPurchaseEvent(
        status: PartyPassPurchaseStatus.error,
        code: 'network_error',
      );
    } finally {
      _busy = false;
    }
  }

  @override
  Future<PartyPassPurchaseEvent> restore() async {
    final ref = await _repository.loadPendingRef();
    if (ref == null) {
      return const PartyPassPurchaseEvent(
        status: PartyPassPurchaseStatus.error,
        code: 'restore_empty',
      );
    }
    try {
      final purchase = await _post('/party-pass/purchase', <String, Object>{
        'productId': kPartyPassProductId,
        'purchaseRef': ref,
      });
      if (purchase['status'] == 'completed') return _completed(purchase);
      return const PartyPassPurchaseEvent(
        status: PartyPassPurchaseStatus.pending,
      );
    } on _PaddleHttpException catch (error) {
      if (error.code == 'purchase_expired' ||
          error.code == 'purchase_not_found') {
        await _repository.clearPendingRef();
        return const PartyPassPurchaseEvent(
          status: PartyPassPurchaseStatus.error,
          code: 'restore_empty',
        );
      }
      return PartyPassPurchaseEvent(
        status: PartyPassPurchaseStatus.error,
        code: error.code,
      );
    } on Object {
      return const PartyPassPurchaseEvent(
        status: PartyPassPurchaseStatus.error,
        code: 'network_error',
      );
    }
  }

  @override
  Future<PartyPassPurchaseEvent> redeem(String licenseKey) async {
    final canonical = _normalizeLicenseKey(licenseKey);
    if (canonical == null) {
      return const PartyPassPurchaseEvent(
        status: PartyPassPurchaseStatus.error,
        code: 'invalid_license',
      );
    }
    return PartyPassPurchaseEvent(
      status: PartyPassPurchaseStatus.purchased,
      credential: PartyPassCredential(
        platform: StorePlatform.paddle,
        productId: kPartyPassProductId,
        verificationToken: canonical,
        savedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  PartyPassPurchaseEvent _completed(Map<String, dynamic> json) {
    final key = json['licenseKey'];
    if (key is! String || _normalizeLicenseKey(key) == null) {
      return const PartyPassPurchaseEvent(
        status: PartyPassPurchaseStatus.error,
        code: 'license_missing',
      );
    }
    unawaited(_repository.clearPendingRef());
    return PartyPassPurchaseEvent(
      status: PartyPassPurchaseStatus.purchased,
      credential: PartyPassCredential(
        platform: StorePlatform.paddle,
        productId: kPartyPassProductId,
        verificationToken: _normalizeLicenseKey(key)!,
        savedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');
    final response = await _http.get(uri).timeout(requestTimeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object> body,
  ) async {
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');
    final response = await _http
        .post(
          uri,
          headers: const <String, String>{
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } on FormatException {
      json = null;
    }
    if (response.statusCode == 200 && json != null) return json;
    throw _PaddleHttpException(switch (response.statusCode) {
      400 => 'invalid_request',
      404 => 'purchase_not_found',
      409 => 'product_mismatch',
      410 => 'purchase_expired',
      429 => 'rate_limited',
      503 => 'checkout_unavailable',
      _ => 'network_error',
    });
  }

  String _newPurchaseRef() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static String? _normalizeLicenseKey(String value) {
    final compact = value.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    if (!RegExp(r'^WT[0-9A-F]{32}$').hasMatch(compact)) return null;
    final hex = compact.substring(2);
    final groups = <String>[
      for (var index = 0; index < hex.length; index += 4)
        hex.substring(index, index + 4),
    ];
    return 'WT-${groups.join('-')}';
  }

  static Future<bool> _launchExternal(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    if (_ownsHttp) _http.close();
    await _events.close();
  }
}

class _PaddleHttpException implements Exception {
  const _PaddleHttpException(this.code);

  final String code;
}
