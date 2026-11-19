import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Store builds must never contain an external payment link or a checkout
/// URL. Direct builds fetch the checkout location from the private Worker at
/// runtime, so no payment host may be compiled into the app at all.
const _blockedHosts = [
  'paddle.com',
  'buy.paddle',
  'checkout.paddle',
  'stripe.com',
  'paypal.com',
  'gumroad',
  'lemonsqueezy',
  'ko-fi.com',
  'buymeacoffee',
];

void main() {
  test('the app source contains no external payment links', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'run the test from app/');

    final offenders = <String>[];
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync().toLowerCase();
      for (final host in _blockedHosts) {
        if (source.contains(host)) offenders.add('${entity.path}: $host');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Store builds may only use Apple/Google billing. Keep payment '
          'links in the private Worker, not in the app.',
    );
  });
}
