import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../match_root.dart';
import '../../core/models/models.dart';
import '../../core/party_pass/party_pass_controller.dart';
import '../../core/theme/whotook_theme.dart';
import '../../demo/demo_match_controller.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';

/// The demo owns a real host and three real clients. Every screen below this
/// scope is the production widget, so a new game feature appears in the demo
/// without a second implementation.
class DemoGameScreen extends ConsumerStatefulWidget {
  const DemoGameScreen({
    super.key,
    required this.settings,
    required this.locale,
    this.config = const MatchConfig(
      roundsK: 5,
      roundSeconds: 8,
      mode: GameMode.mixedParty,
      pace: GamePace.fast,
    ),
  });

  final AppSettings settings;
  final Locale locale;
  final MatchConfig config;

  @override
  ConsumerState<DemoGameScreen> createState() => _DemoGameScreenState();
}

class _DemoGameScreenState extends ConsumerState<DemoGameScreen> {
  late final DemoMatchController _controller;
  late final Future<void> _starting;

  @override
  void initState() {
    super.initState();
    _controller = DemoMatchController(
      baseSettings: widget.settings,
      config: widget.config,
      locale: widget.locale,
    );
    _starting = _controller.start().timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw StateError('demo start timed out'),
    );
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return FutureBuilder<void>(
      future: _starting,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: colors.bg,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.error_outline,
                        size: 32,
                        color: colors.negative,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.demoFailed,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: colors.ink2),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: Text(l10n.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: colors.bg,
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      l10n.demoPreparing,
                      style: TextStyle(fontSize: 14, color: colors.ink2),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return DemoMatchScope(
          controller: _controller,
          child: const MatchRoot(demo: true),
        );
      },
    );
  }
}

/// Wires the production screens to one started demo controller. Keeping this
/// scope separate lets a test render the exact same demo tree.
class DemoMatchScope extends StatelessWidget {
  const DemoMatchScope({
    super.key,
    required this.controller,
    required this.child,
  });

  final DemoMatchController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      key: const ValueKey<String>('demo-match'),
      overrides: [
        appSettingsProvider.overrideWith(
          () => DemoAppSettingsController(controller.settings),
        ),
        photoLibraryProvider.overrideWithValue(controller.hostPhotos),
        matchCoordinatorProvider.overrideWithValue(controller.host),
        matchStateProvider.overrideWith((ref) => controller.host.states),
        partyPassProvider.overrideWith(DemoPartyPassController.new),
        demoModeProvider.overrideWithValue(true),
      ],
      child: child,
    );
  }
}
