import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/party_pass/party_pass_controller.dart';
import '../../core/theme/whotook_theme.dart';
import '../../demo/demo_match_controller.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../match_root.dart';
import '../widgets/report_issue_button.dart';

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
    this.controllerBuilder,
  });

  final AppSettings settings;
  final Locale locale;
  final MatchConfig config;

  /// Test seam for a controller that never finishes starting.
  final DemoMatchController Function(
    AppSettings settings,
    Locale locale,
    MatchConfig config,
  )?
  controllerBuilder;

  @override
  ConsumerState<DemoGameScreen> createState() => _DemoGameScreenState();
}

class _DemoGameScreenState extends ConsumerState<DemoGameScreen> {
  DemoMatchController? _controller;
  late Future<void> _starting;
  Timer? _watchdog;
  bool _ready = false;
  bool _showRecovery = false;

  @override
  void initState() {
    super.initState();
    _startNewDemo();
  }

  DemoMatchController _buildController() {
    return widget.controllerBuilder?.call(
          widget.settings,
          widget.locale,
          widget.config,
        ) ??
        DemoMatchController(
          baseSettings: widget.settings,
          config: widget.config,
          locale: widget.locale,
        );
  }

  void _startNewDemo() {
    final controller = _buildController();
    _controller = controller;
    _ready = false;
    _showRecovery = false;
    final starting = controller.start();
    _starting = starting;
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 6), _showRecoveryIfWaiting);
    unawaited(
      starting
          .whenComplete(() {
            if (!identical(_starting, starting)) return;
            _watchdog?.cancel();
            if (!mounted) return;
            setState(() => _ready = true);
          })
          .catchError((Object _) {}),
    );
  }

  void _showRecoveryIfWaiting() {
    if (!mounted || _ready) return;
    setState(() => _showRecovery = true);
  }

  void _retry() {
    final old = _controller;
    _watchdog?.cancel();
    unawaited(old?.dispose());
    setState(_startNewDemo);
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    unawaited(_controller?.dispose());
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
          return _DemoSetupFailure(
            colors: colors,
            l10n: l10n,
            onRetry: _retry,
            onClose: () => Navigator.of(context).maybePop(),
          );
        }
        // `_starting` is a Future<void>, so a successful completion has
        // `data == null` and `hasData` stays false. The connection state is
        // the only reliable success signal here.
        if (snapshot.connectionState != ConnectionState.done) {
          return _DemoSetupLoading(
            colors: colors,
            l10n: l10n,
            showRecovery: _showRecovery,
            onRetry: _retry,
          );
        }
        return DemoMatchScope(
          controller: _controller!,
          child: const MatchRoot(demo: true),
        );
      },
    );
  }
}

class _DemoSetupLoading extends StatelessWidget {
  const _DemoSetupLoading({
    required this.colors,
    required this.l10n,
    required this.showRecovery,
    required this.onRetry,
  });

  final WhoTookColors colors;
  final AppLocalizations l10n;
  final bool showRecovery;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  l10n.demoPreparing,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.ink,
                  ),
                ),
                if (showRecovery) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    l10n.demoTakingLong,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: colors.ink2),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton(
                        onPressed: onRetry,
                        child: Text(l10n.demoRetry),
                      ),
                      const ReportIssueButton(screenLabel: 'Demo setup'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoSetupFailure extends StatelessWidget {
  const _DemoSetupFailure({
    required this.colors,
    required this.l10n,
    required this.onRetry,
    required this.onClose,
  });

  final WhoTookColors colors;
  final AppLocalizations l10n;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.error_outline, size: 32, color: colors.negative),
                const SizedBox(height: 12),
                Text(
                  l10n.demoFailed,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: colors.ink2),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton(
                      onPressed: onRetry,
                      child: Text(l10n.demoRetry),
                    ),
                    const ReportIssueButton(screenLabel: 'Demo setup'),
                    TextButton(onPressed: onClose, child: Text(l10n.close)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
