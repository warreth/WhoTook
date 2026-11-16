import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whotook/core/party_pass/party_pass_repository.dart';
import 'package:whotook/core/party_pass/turn_relay_client.dart';

PartyPassCredential _credential() => PartyPassCredential(
  platform: StorePlatform.apple,
  productId: kPartyPassProductId,
  verificationToken: 'signed-transaction-jws',
  savedAtUtc: DateTime.utc(2026, 11, 16),
);

void main() {
  test('parses a granted relay response', () async {
    late Map<String, dynamic> requestBody;
    final client = TurnRelayClient(
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://signal.example/api/v1/turn-credentials',
        );
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'relayAvailable': true,
            'iceServers': <Map<String, dynamic>>[
              <String, dynamic>{'urls': 'stun:stun.cloudflare.com:3478'},
              <String, dynamic>{
                'urls': <String>[
                  'turn:turn.example:3478?transport=udp',
                  'turns:turn.example:5349?transport=tcp',
                ],
                'username': '1700000000:pp_abc',
                'credential': 'hmac',
              },
            ],
            'ttlSeconds': 2700,
            'expiresAt': '2026-11-16T13:00:00.000Z',
            'remainingMatchesToday': 14,
            'dailyLimit': 15,
          }),
          200,
        );
      }),
    );

    final grant = await client.fetchCredentials(
      baseUrl: 'https://signal.example/api/v1/',
      credential: _credential(),
    );

    expect(requestBody['platform'], 'ios');
    expect(requestBody['productId'], kPartyPassProductId);
    expect(requestBody['verificationToken'], 'signed-transaction-jws');
    expect(grant.ttlSeconds, 2700);
    expect(grant.remainingMatchesToday, 14);
    expect(grant.iceServers.last.urls, hasLength(2));
    expect(grant.iceServers.last.username, '1700000000:pp_abc');
  });

  test('maps a fair-use response and keeps the remaining count', () async {
    final client = TurnRelayClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{
            'error': 'fair_use_limit_reached',
            'remainingMatchesToday': 0,
            'dailyLimit': 15,
            'retryAtUtc': '2026-11-17T12:00:00.000Z',
          }),
          429,
        ),
      ),
    );

    await expectLater(
      client.fetchCredentials(
        baseUrl: 'https://signal.example/api/v1',
        credential: _credential(),
      ),
      throwsA(
        isA<TurnRelayException>()
            .having(
              (error) => error.code,
              'code',
              TurnRelayErrorCode.fairUseLimit,
            )
            .having((error) => error.remainingMatchesToday, 'remaining', 0),
      ),
    );
  });

  test('maps an invalid receipt to a non-retryable code', () async {
    final client = TurnRelayClient(
      httpClient: MockClient(
        (_) async => http.Response('{"error":"invalid_receipt"}', 401),
      ),
    );

    await expectLater(
      client.fetchCredentials(
        baseUrl: 'https://signal.example/api/v1',
        credential: _credential(),
      ),
      throwsA(
        isA<TurnRelayException>().having(
          (error) => error.code,
          'code',
          TurnRelayErrorCode.invalidReceipt,
        ),
      ),
    );
  });

  test('rejects a malformed success response', () async {
    final client = TurnRelayClient(
      httpClient: MockClient(
        (_) async => http.Response('{"relayAvailable":true}', 200),
      ),
    );

    await expectLater(
      client.fetchCredentials(
        baseUrl: 'https://signal.example/api/v1',
        credential: _credential(),
      ),
      throwsA(
        isA<TurnRelayException>().having(
          (error) => error.code,
          'code',
          TurnRelayErrorCode.malformed,
        ),
      ),
    );
  });

  test('verifies without spending a match', () async {
    final client = TurnRelayClient(
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://signal.example/api/v1/party-pass/verify',
        );
        return http.Response(
          '{"valid":true,"remainingMatchesToday":15,"dailyLimit":15}',
          200,
        );
      }),
    );

    final result = await client.verify(
      baseUrl: 'https://signal.example/api/v1',
      credential: _credential(),
    );
    expect(result.valid, isTrue);
    expect(result.remainingMatchesToday, 15);
  });
}
