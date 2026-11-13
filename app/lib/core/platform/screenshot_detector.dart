import 'dart:async';

import 'package:flutter/services.dart';

/// Bridges the native screenshot channel. The channel is missing in unit tests
/// and on platforms without the bridge, so every failure turns into a quiet
/// no-op instead of an uncaught platform exception.
class ScreenshotDetector {
  ScreenshotDetector({EventChannel? channel})
    : _channel = channel ?? const EventChannel(channelName);

  static const String channelName = 'app.whotook/screenshots';

  final EventChannel _channel;
  StreamSubscription<dynamic>? _subscription;
  final StreamController<void> _events = StreamController<void>.broadcast();

  /// Emits once per detected screenshot. Never throws.
  Stream<void> get screenshots => _events.stream;

  bool get isListening => _subscription != null;

  /// Subscribes and forwards every native event to [onScreenshot].
  Future<void> start(void Function() onScreenshot) async {
    await stop();
    if (!await _channelAvailable()) {
      return;
    }
    _subscription = _channel.receiveBroadcastStream().listen(
      (_) {
        onScreenshot();
        if (!_events.isClosed) {
          _events.add(null);
        }
      },
      onError: (Object _) {},
      onDone: () {
        _subscription = null;
      },
    );
  }

  Future<void> stop() async {
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
  }

  /// `receiveBroadcastStream` reports a missing plugin through
  /// `FlutterError.reportError` and leaves the stream open, so the channel is
  /// probed with a plain method call first.
  Future<bool> _channelAvailable() async {
    final probe = MethodChannel(
      _channel.name,
      _channel.codec,
      _channel.binaryMessenger,
    );
    try {
      await probe.invokeMethod<void>('isSupported');
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      // The native side answered, even if it rejected the method.
      return true;
    }
  }
}
