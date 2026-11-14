import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Routes an invite opened from a chat app into the join flow. Duplicate
/// initial and stream events are ignored, but a deliberate re-tap works once
/// the previous attempt has failed and left the room unset.
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  static const Duration _duplicateWindow = Duration(seconds: 2);

  final AppLinks _links = AppLinks();
  StreamSubscription<Uri>? _subscription;
  String? _handled;
  DateTime? _handledAt;

  @override
  void initState() {
    super.initState();
    unawaited(_readInitial());
    _subscription = _links.uriLinkStream.listen(
      _handle,
      onError: (Object _) {},
    );
  }

  Future<void> _readInitial() async {
    try {
      final uri = await _links.getInitialLink();
      if (uri != null) _handle(uri);
    } on Object {
      // No deep link support on this platform or build.
    }
  }

  void _handle(Uri uri) {
    final raw = uri.toString();
    final coordinator = ref.read(matchCoordinatorProvider);
    final now = DateTime.now();
    final handledAt = _handledAt;
    final insideWindow =
        handledAt != null && now.difference(handledAt) < _duplicateWindow;
    // The initial link and the stream often deliver the same URI. Ignore the
    // repeat while a join is in flight, but allow a deliberate re-tap once the
    // previous attempt failed and left the room unset.
    if (raw == _handled && (coordinator.state.roomId != null || insideWindow)) {
      return;
    }
    _handled = raw;
    _handledAt = now;
    if (coordinator.state.roomId != null) return;
    unawaited(coordinator.joinMatch(raw));
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
