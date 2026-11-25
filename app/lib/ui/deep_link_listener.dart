import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/deep_links/deferred_invite_service.dart';
import '../core/models/models.dart';
import '../core/navigation.dart';
import '../state/providers.dart';
import 'screens/join_confirm_screen.dart';

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
  bool _deferredStarted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_readInitial());
    // Wait for the first route before offering a deferred invite. A post-frame
    // callback keeps this out of the test timer invariants and gives the
    // confirm screen a real navigator.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_readDeferredInvite());
    });
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

  void _handle(Uri uri) => _handleString(uri.toString());

  Future<void> _readDeferredInvite() async {
    if (_deferredStarted) return;
    _deferredStarted = true;
    final AppSettings settings;
    try {
      settings = await ref.read(appSettingsProvider.future);
    } on Object {
      _deferredStarted = false;
      return;
    }
    if (!settings.onboardingCompleted) {
      // A first-run player gets the clipboard/referrer offer after onboarding.
      _deferredStarted = false;
      return;
    }
    // A missing native install referrer simply returns null.
    if (!mounted) return;
    final String? invite;
    try {
      invite = await DeferredInviteService.instance.takePendingInvite();
    } on Object {
      _deferredStarted = false;
      return;
    }
    if (invite == null || !mounted) return;
    _handleString(invite);
  }

  void _handleString(String raw) {
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
    if (ref.read(appSettingsProvider).value?.onboardingCompleted != true) {
      return;
    }
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      unawaited(coordinator.joinMatch(raw));
      return;
    }
    unawaited(
      navigator.push<bool>(
        MaterialPageRoute<bool>(builder: (_) => JoinConfirmScreen(invite: raw)),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appSettingsProvider, (previous, next) {
      if (_deferredStarted) return;
      if (next.value?.onboardingCompleted == true) {
        unawaited(_readDeferredInvite());
      }
    });
    return widget.child;
  }
}
