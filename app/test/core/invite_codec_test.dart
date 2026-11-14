import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/qr/invite_codec.dart';

const InvitePayload sample = InvitePayload(
  roomId: 'k8m2p9x4',
  hostId: 'h_9a1f',
  secret: '0123456789abcdef0123456789abcdef',
  lanEndpoints: <String>['192.168.1.42:8765'],
  signalingUrl: 'wss://signal.whotook.party',
);

Matcher throwsInvalidInvite([String? reasonPart]) => throwsA(
  isA<InvalidInviteException>().having(
    (e) => e.reason,
    'reason',
    reasonPart == null ? anything : contains(reasonPart),
  ),
);

void main() {
  group('encodeInviteUrl', () {
    test('puts the payload in the URL fragment', () {
      final url = encodeInviteUrl(sample);
      expect(url.startsWith('https://whotook.party/j#'), isTrue);
      final fragment = url.split('#').last;
      expect(fragment, isNotEmpty);
      // base64url only, so the QR stays inside the alphanumeric mode.
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(fragment), isTrue);
    });

    test('honours a custom base url', () {
      final url = encodeInviteUrl(
        sample,
        baseUrl: 'https://party.example.org/j',
      );
      expect(url.startsWith('https://party.example.org/j#'), isTrue);
    });

    test('keeps the documented JSON field names', () {
      final url = encodeInviteUrl(sample);
      final json = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(url.split('#').last))),
      ) as Map<String, dynamic>;
      expect(json['v'], 1);
      expect(json['room'], 'k8m2p9x4');
      expect(json['hostId'], 'h_9a1f');
      expect(json['lan'], <String>['192.168.1.42:8765']);
      expect(json['sig'], 'wss://signal.whotook.party');
      expect(json['secret'], sample.secret);
    });
  });

  group('tryParseInvite', () {
    test('roundtrips the canonical invite URL', () {
      final parsed = tryParseInvite(encodeInviteUrl(sample));
      expect(parsed.roomId, 'k8m2p9x4');
      expect(parsed.hostId, 'h_9a1f');
      expect(parsed.secret, sample.secret);
      expect(parsed.lanEndpoints, <String>['192.168.1.42:8765']);
      expect(parsed.signalingUrl, 'wss://signal.whotook.party');
      expect(parsed.version, 1);
    });

    test('accepts a custom domain with /j#', () {
      final url = encodeInviteUrl(sample, baseUrl: 'https://my.server/j');
      expect(tryParseInvite(url).roomId, 'k8m2p9x4');
    });

    test('accepts the whotook://join app link', () {
      final fragment = encodeInviteUrl(sample).split('#').last;
      final parsed = tryParseInvite('whotook://join#$fragment');
      expect(parsed.roomId, 'k8m2p9x4');
    });

    test('accepts a raw base64 body and raw JSON', () {
      final body = encodeInviteUrl(sample).split('#').last;
      expect(tryParseInvite(body).roomId, 'k8m2p9x4');

      final json = jsonEncode(sample.toJson());
      final fromJson = tryParseInvite(json);
      expect(fromJson.roomId, 'k8m2p9x4');
      expect(fromJson.secret, sample.secret);

      final fromB64Json = tryParseInvite(base64Url.encode(utf8.encode(json)));
      expect(fromB64Json.hostId, 'h_9a1f');
    });

    test('tolerates surrounding whitespace and missing padding', () {
      final body = encodeInviteUrl(sample).split('#').last;
      expect(body.contains('='), isFalse);
      expect(tryParseInvite('  $body\n').roomId, 'k8m2p9x4');
      expect(tryParseInvite('$body==').roomId, 'k8m2p9x4');
    });

    test('accepts an invite without optional fields', () {
      final minimal = InvitePayload(
        roomId: 'abcd',
        hostId: 'h1',
        secret: 'abcdefgh',
      );
      final parsed = tryParseInvite(encodeInviteUrl(minimal));
      expect(parsed.lanEndpoints, isEmpty);
      expect(parsed.signalingUrl, isNull);
    });
  });

  group('invalid invites', () {
    test('rejects an empty string', () {
      expect(() => tryParseInvite(''), throwsInvalidInvite('empty'));
    });

    test('rejects garbage', () {
      expect(
        () => tryParseInvite('not an invite at all'),
        throwsInvalidInvite(),
      );
    });

    test('rejects a URL with an empty fragment', () {
      expect(
        () => tryParseInvite('https://whotook.party/j#'),
        throwsInvalidInvite('empty'),
      );
    });

    test('rejects the wrong path', () {
      final body = encodeInviteUrl(sample).split('#').last;
      expect(
        () => tryParseInvite('https://whotook.party/other#$body'),
        throwsInvalidInvite('/j'),
      );
    });

    test('rejects an unsupported scheme', () {
      final body = encodeInviteUrl(sample).split('#').last;
      expect(
        () => tryParseInvite('ftp://whotook.party/j#$body'),
        throwsInvalidInvite('scheme'),
      );
    });

    test('rejects a missing room id', () {
      final bad = base64Url.encode(
        utf8.encode(
          jsonEncode(<String, dynamic>{
            'v': 1,
            'hostId': 'h',
            'secret': 'abcdefgh',
          }),
        ),
      );
      expect(() => tryParseInvite(bad), throwsInvalidInvite('room'));
    });

    test('rejects a room id with illegal characters', () {
      final bad = base64Url.encode(
        utf8.encode(
          jsonEncode(<String, dynamic>{
            'v': 1,
            'room': 'bad room!',
            'hostId': 'h',
            'secret': 'abcdefgh',
          }),
        ),
      );
      expect(() => tryParseInvite(bad), throwsInvalidInvite('room'));
    });

    test('rejects a missing or short secret', () {
      final missing = base64Url.encode(
        utf8.encode(
          jsonEncode(<String, dynamic>{'v': 1, 'room': 'abcd', 'hostId': 'h'}),
        ),
      );
      expect(() => tryParseInvite(missing), throwsInvalidInvite('secret'));

      final short = base64Url.encode(
        utf8.encode(
          jsonEncode(<String, dynamic>{
            'v': 1,
            'room': 'abcd',
            'hostId': 'h',
            'secret': 'abc',
          }),
        ),
      );
      expect(() => tryParseInvite(short), throwsInvalidInvite('secret'));
    });

    test('rejects an unknown version', () {
      final future = base64Url.encode(
        utf8.encode(
          jsonEncode(<String, dynamic>{
            'v': 99,
            'room': 'abcd',
            'hostId': 'h',
            'secret': 'abcdefgh',
          }),
        ),
      );
      expect(() => tryParseInvite(future), throwsInvalidInvite('version'));
    });

    test('rejects a missing host id', () {
      final bad = base64Url.encode(
        utf8.encode(
          jsonEncode(<String, dynamic>{
            'v': 1,
            'room': 'abcd',
            'secret': 'abcdefgh',
          }),
        ),
      );
      expect(() => tryParseInvite(bad), throwsInvalidInvite('host'));
    });

    test('rejects malformed JSON behind a valid base64 body', () {
      final bad = base64Url.encode(utf8.encode('{"v":1,'));
      expect(() => tryParseInvite(bad), throwsInvalidInvite());
    });

    test('rejects a JSON array instead of an object', () {
      final bad = base64Url.encode(utf8.encode('[1,2,3]'));
      expect(() => tryParseInvite(bad), throwsInvalidInvite());
    });
  });
}
