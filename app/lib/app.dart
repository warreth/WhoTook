import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/models.dart';
import '../core/theme/whotook_theme.dart';
import '../state/match_coordinator.dart';
import '../state/providers.dart';
import 'ui/deep_link_listener.dart';
import 'ui/screens/caption_screen.dart';
import 'ui/screens/extend_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/lobby_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/podium_screen.dart';
import 'ui/screens/prepare_screen.dart';
import 'ui/screens/round_screen.dart';
import 'ui/screens/timeline_screen.dart';
import 'ui/widgets/version_warning_card.dart';

class WhoTookApp extends ConsumerWidget {
  const WhoTookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final preference =
        settings.value?.themePreference ?? ThemePreference.system;
    return MaterialApp(
      title: 'WhoTook',
      debugShowCheckedModeBanner: false,
      theme: buildWhoTookTheme(Brightness.light),
      darkTheme: buildWhoTookTheme(Brightness.dark),
      themeMode: switch (preference) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      },
      builder: (context, child) => child == null
          ? const SizedBox.shrink()
          : DeepLinkListener(child: child),
      home: settings.when(
        loading: () => const _BootScreen(),
        error: (error, stack) => const _BootScreen(),
        data: (value) => value.onboardingCompleted
            ? const _MatchRoot()
            : const OnboardingScreen(),
      ),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            WhoTookMark(size: 40, color: colors.accent),
            const SizedBox(height: AppSpacing.s16),
            Text('WhoTook', style: TextStyle(fontSize: 18, color: colors.ink2)),
          ],
        ),
      ),
    );
  }
}

/// Switches between the lobby, preparation, rounds and podium from the single
/// match state, so a reconnect lands on the right screen automatically.
class _MatchRoot extends ConsumerStatefulWidget {
  const _MatchRoot();

  @override
  ConsumerState<_MatchRoot> createState() => _MatchRootState();
}

class _MatchRootState extends ConsumerState<_MatchRoot> {
  int? _dismissedBuild;

  void _dismissWarning(VersionWarning warning) {
    setState(() => _dismissedBuild = warning.latestBuild);
    ref.read(matchCoordinatorProvider).dismissVersionWarning();
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    final settings = ref.watch(appSettingsProvider).value;
    if (settings != null) {
      coordinator.updateSettings(settings);
    }

    if (state.turnLimitNotice != null && state.connectionMode == null) {
      return HomeScreen(key: const ValueKey<String>('home'));
    }

    final atHome = state.roomId == null && state.phase == RoundPhase.lobby;
    final screen = switch (state.phase) {
      RoundPhase.lobby =>
        state.roomId == null
            ? const HomeScreen(key: ValueKey<String>('home'))
            : const LobbyScreen(key: ValueKey<String>('lobby')),
      RoundPhase.preparing => const PrepareScreen(
        key: ValueKey<String>('prepare'),
      ),
      RoundPhase.countdown ||
      RoundPhase.guessing ||
      RoundPhase.reveal => const RoundScreen(key: ValueKey<String>('round')),
      RoundPhase.captionWriting ||
      RoundPhase.captionVoting ||
      RoundPhase.captionReveal => const CaptionScreen(
        key: ValueKey<String>('caption'),
      ),
      RoundPhase.timelineGuessing || RoundPhase.timelineReveal =>
        const TimelineScreen(key: ValueKey<String>('timeline')),
      RoundPhase.extendPrompt => const ExtendScreen(
        key: ValueKey<String>('extend'),
      ),
      RoundPhase.podium => const PodiumScreen(key: ValueKey<String>('podium')),
    };
    final warning = state.versionWarning;
    return PopScope(
      canPop: atHome,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_confirmLeave(context, coordinator, state));
      },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          screen,
          if (warning != null &&
              warning.isNewer &&
              !state.versionWarningDismissed &&
              warning.latestBuild != _dismissedBuild)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      VersionWarningCard(
                        warning: warning,
                        onDismiss: () => _dismissWarning(warning),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmLeave(
    BuildContext context,
    MatchCoordinator coordinator,
    MatchUiState state,
  ) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this room?'),
        content: Text(
          state.isHosting
              ? 'The room closes for everyone.'
              : 'You leave the room and can rejoin with the QR code.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: WhoTookColors.of(context).negative,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true) {
      await coordinator.leaveMatch();
    }
  }
}
