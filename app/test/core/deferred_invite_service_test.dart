import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:whotook/core/deep_links/deferred_invite_service.dart';
import 'package:whotook/core/qr/invite_codec.dart';

const InvitePayload _invite = InvitePayload(
  roomId: 'K7M2P9',
  hostId: 'host-lotte',
  secret: 'demoSecret12345',
  hostName: 'Lotte',
);

void main() {
  final canonical = encodeInviteUrl(_invite);
  final fragment = canonical.split('#').last;

  group('install referrer', () {
    test('reads room from a plain referrer', () {
      expect(DeferredInviteService.parseReferrer('room=$fragment'), canonical);
    });

    test('reads an encoded referrer next to tracking fields', () {
      final encoded = Uri.encodeComponent(canonical);
      expect(
        DeferredInviteService.parseReferrer(
          'utm_source=test&room=$encoded&utm_medium=invite',
        ),
        canonical,
      );
    });

    test('accepts a full invite URL as the referrer', () {
      expect(DeferredInviteService.parseReferrer(canonical), canonical);
    });

    test('rejects junk and a bare room code', () {
      expect(DeferredInviteService.parseReferrer(null), isNull);
      expect(DeferredInviteService.parseReferrer(''), isNull);
      expect(DeferredInviteService.parseReferrer('room=K7M2P9'), isNull);
      expect(DeferredInviteService.parseReferrer('not an invite'), isNull);
    });
  });

  group('clipboard invite', () {
    test('strips the whotook-invite prefix', () {
      expect(
        DeferredInviteService.parseClipboard('whotook-invite:$canonical'),
        canonical,
      );
      expect(
        DeferredInviteService.parseClipboard('  whotook-invite:$fragment  '),
        canonical,
      );
    });

    test('accepts a plain invite URL and the app link', () {
      expect(DeferredInviteService.parseClipboard(canonical), canonical);
      expect(
        DeferredInviteService.parseClipboard('whotook://join#$fragment'),
        canonical,
      );
    });

    test('ignores other clipboard text', () {
      expect(DeferredInviteService.parseClipboard('hello world'), isNull);
      expect(DeferredInviteService.parseClipboard(''), isNull);
      expect(
        DeferredInviteService.parseClipboard('whotook-invite:K7M2P9'),
        isNull,
      );
    });
  });

  test('the same invite only triggers once', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final service = DeferredInviteService();
    expect(await service.markConsumed(canonical), isTrue);
    expect(await service.markConsumed(canonical), isFalse);
    final second = encodeInviteUrl(
      const InvitePayload(
        roomId: 'ABCD',
        hostId: 'host-two',
        secret: 'anotherSecret123',
      ),
    );
    expect(await service.markConsumed(second), isTrue);
  });

  test('the host name survives the invite roundtrip', () {
    expect(tryParseInvite(canonical).hostName, 'Lotte');
  });
}
