import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whotook/core/platform/screenshot_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void registerChannel(
    String name,
    Future<Object?> Function(MethodCall) handler,
  ) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(name), handler);
  }

  Future<void> pushEvent(String name, Object? payload) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const codec = StandardMethodCodec();
    unawaited(
      messenger.handlePlatformMessage(
        name,
        codec.encodeSuccessEnvelope(payload),
        (_) {},
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('uses the documented channel name', () {
    expect(ScreenshotDetector.channelName, 'app.whotook/screenshots');
  });

  test('a missing plugin is a quiet no-op', () async {
    final detector = ScreenshotDetector();
    var calls = 0;
    await detector.start(() => calls++);
    expect(detector.isListening, isFalse);
    await detector.stop();
    await detector.dispose();
    expect(calls, 0);
  });

  test('forwards native events to the callback and the stream', () async {
    const name = 'test/screenshots/events';
    final calls = <String>[];
    registerChannel(name, (call) async {
      calls.add(call.method);
      return null;
    });

    final detector = ScreenshotDetector(channel: const EventChannel(name));
    final seen = <void>[];
    final sub = detector.screenshots.listen(seen.add);
    var screenshots = 0;
    await detector.start(() => screenshots++);
    expect(detector.isListening, isTrue);

    await pushEvent(name, 'taken');
    await pushEvent(name, 'taken');

    expect(calls, contains('isSupported'));
    expect(calls, contains('listen'));
    expect(screenshots, 2);
    expect(seen.length, 2);

    await sub.cancel();
    await detector.stop();
    expect(detector.isListening, isFalse);
    await detector.dispose();
  });

  test('a platform error on the probe still allows listening', () async {
    const name = 'test/screenshots/error-probe';
    registerChannel(name, (call) async {
      if (call.method == 'isSupported') {
        throw PlatformException(code: 'unsupported');
      }
      return null;
    });
    final detector = ScreenshotDetector(channel: const EventChannel(name));
    await detector.start(() {});
    expect(detector.isListening, isTrue);
    await detector.stop();
    await detector.dispose();
  });

  test('stop is safe to call twice and before start', () async {
    final detector = ScreenshotDetector();
    await detector.stop();
    await detector.start(() {});
    await detector.stop();
    await detector.stop();
    expect(detector.isListening, isFalse);
    await detector.dispose();
  });

  test('start replaces an existing subscription', () async {
    const name = 'test/screenshots/restart';
    registerChannel(name, (call) async => null);
    final detector = ScreenshotDetector(channel: const EventChannel(name));
    var first = 0;
    var second = 0;
    await detector.start(() => first++);
    await detector.start(() => second++);
    await pushEvent(name, 'taken');
    expect(first, 0);
    expect(second, 1);
    await detector.dispose();
  });
}
