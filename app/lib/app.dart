import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/models.dart';
import '../core/theme/whotook_theme.dart';
import '../state/providers.dart';
import 'ui/deep_link_listener.dart';
import 'ui/screens/extend_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/lobby_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/podium_screen.dart';
import 'ui/screens/prepare_screen.dart';
import 'ui/screens/round_screen.dart';

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
class _MatchRoot extends ConsumerWidget {
  const _MatchRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;

    if (state.turnLimitNotice != null && state.connectionMode == null) {
      return HomeScreen(key: const ValueKey<String>('home'));
    }

    return switch (state.phase) {
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
      RoundPhase.extendPrompt => const ExtendScreen(
        key: ValueKey<String>('extend'),
      ),
      RoundPhase.podium => const PodiumScreen(key: ValueKey<String>('podium')),
    };
  }
}
