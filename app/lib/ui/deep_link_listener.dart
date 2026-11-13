import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Routes an invite opened from a chat app into the join flow. The link is
/// handled once per URI so a rebuild never joins twice.
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  final AppLinks _links = AppLinks();
  StreamSubscription<Uri>? _subscription;
  String? _handled;

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
    if (raw == _handled) return;
    _handled = raw;
    final coordinator = ref.read(matchCoordinatorProvider);
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
