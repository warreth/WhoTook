import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whotook/core/party_pass/paddle_purchase_service.dart';
import 'package:whotook/core/party_pass/party_pass_repository.dart';
import 'package:whotook/core/party_pass/party_pass_storage.dart';
import 'package:whotook/core/party_pass/purchase_service.dart';

const String _ref = '0123456789abcdef0123456789abcdef';
const String _key = 'WT-1234-5678-9ABC-DEF0-1234-5678-9ABC-DEF0';

Map<String, dynamic> _json(Object value) => value as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late List<Uri> opened;
  late PartyPassRepository repository;

  setUp(() {
    requests = <http.Request>[];
    opened = <Uri>[];
    repository = PartyPassRepository(storage: InMemoryPartyPassStorage());
  });

  PaddlePartyPassPurchaseService service(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    return PaddlePartyPassPurchaseService(
      httpClient: MockClient((request) async {
        requests.add(request);
        return handler(request);
      }),
      repository: repository,
      openUrl: (uri) async {
        opened.add(uri);
        return true;
      },
      pollInterval: Duration.zero,
      pollTimeout: const Duration(seconds: 2),
    );
  }

  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: const <String, String>{'content-type': 'application/json'},
  );

  test('checkout opens Paddle and polls until the license arrives', () async {
    final subject = service((request) async {
      if (request.url.path.endsWith('/party-pass/checkout')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['productId'], kPartyPassProductId);
        expect(body['purchaseRef'], matches(RegExp(r'^[0-9a-f]{32}$')));
        return json(<String, dynamic>{
          'status': 'pending',
          'transactionId': 'txn_01m7rj9000qq72v1zy0p5waczx',
          'checkoutUrl': 'https://whotook.party/party-pass?_ptxn=txn_1',
          'expiresAt': '2030-01-01T00:00:00.000Z',
        });
      }
      if (request.url.path.endsWith('/party-pass/purchase')) {
        return json(<String, dynamic>{
          'status': 'completed',
          'productId': kPartyPassProductId,
          'licenseKey': _key.toLowerCase(),
          'expiresAt': '2030-01-01T00:00:00.000Z',
        });
      }
      return json(<String, dynamic>{'error': 'unexpected'}, 500);
    });

    await subject.initialize();
    expect(subject.available, isTrue); // offline config keeps the button usable
    final event = await subject.buy();

    expect(event.status, PartyPassPurchaseStatus.purchased);
    expect(event.credential?.platform, StorePlatform.paddle);
    expect(event.credential?.verificationToken, _key);
    expect(opened, hasLength(1));
    expect(opened.single.host, 'whotook.party');
    expect(await repository.loadPendingRef(), isNull);
    expect(
      requests.where((r) => r.url.path.endsWith('/checkout')),
      hasLength(1),
    );
    expect(requests.where((r) => r.url.path.endsWith('/purchase')), isNotEmpty);
  });

  test(
    'a repeated buy reuses the pending reference instead of charging twice',
    () async {
      await repository.savePendingRef(_ref);
      final subject = service((request) async {
        if (request.url.path.endsWith('/checkout')) {
          return json(<String, dynamic>{
            'status': 'pending',
            'transactionId': 'txn_01m7rj9000qq72v1zy0p5waczx',
            'checkoutUrl': 'https://whotook.party/party-pass?_ptxn=txn_1',
            'expiresAt': '2030-01-01T00:00:00.000Z',
          });
        }
        return json(<String, dynamic>{'error': 'purchase_not_found'}, 404);
      });

      final event = await subject.buy();
      expect(event.status, PartyPassPurchaseStatus.error);
      expect(eventsBody(requests.first)['purchaseRef'], _ref);
    },
  );

  test(
    'restore completes a purchase that finished after the app closed',
    () async {
      await repository.savePendingRef(_ref);
      final subject = service(
        (request) async => json(<String, dynamic>{
          'status': 'completed',
          'productId': kPartyPassProductId,
          'licenseKey': _key,
          'expiresAt': '2030-01-01T00:00:00.000Z',
        }),
      );

      final event = await subject.restore();
      expect(event.status, PartyPassPurchaseStatus.purchased);
      expect(event.credential?.verificationToken, _key);
      expect(await repository.loadPendingRef(), isNull);
    },
  );

  test('redeem normalises a license key and rejects garbage', () async {
    final subject = service((request) async => json(<String, dynamic>{}));

    final valid = await subject.redeem(
      ' wt 1234 5678 9abc def0 1234 5678 9abc def0 ',
    );
    expect(valid.status, PartyPassPurchaseStatus.purchased);
    expect(valid.credential?.verificationToken, _key);

    final invalid = await subject.redeem('not-a-key');
    expect(invalid.status, PartyPassPurchaseStatus.error);
    expect(invalid.code, 'invalid_license');
  });

  test('maps API failures to stable UI codes', () async {
    final subject = service((request) async {
      return json(<String, dynamic>{'error': 'checkout_unavailable'}, 503);
    });
    final event = await subject.buy();
    expect(event.status, PartyPassPurchaseStatus.error);
    expect(event.code, 'checkout_unavailable');
  });

  test('store builds never accept a web license', () async {
    final store = StorePartyPassPurchaseService();
    expect(store.kind, PartyPassBillingKind.store);
    final event = await store.redeem(_key);
    expect(event.status, PartyPassPurchaseStatus.error);
    expect(event.code, 'license_not_supported');
  });
}

Map<String, dynamic> eventsBody(http.Request request) {
  return _json(jsonDecode(request.body));
}
