import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/models.dart';
import '../core/navigation.dart';
import '../core/party_pass/party_pass_controller.dart';
import '../core/party_pass/room_theme.dart';
import '../core/audio/game_audio_service.dart';
import '../l10n/l10n.dart';
import '../core/theme/whotook_theme.dart';
import '../state/match_coordinator.dart';
import '../state/providers.dart';
import 'ui/deep_link_listener.dart';
import 'ui/screens/caption_screen.dart';
import 'ui/screens/extend_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/lobby_screen.dart';
import 'ui/screens/meme_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/podium_screen.dart';
import 'ui/screens/prepare_screen.dart';
import 'ui/screens/round_screen.dart';
import 'ui/screens/timeline_screen.dart';
import 'ui/widgets/firewall_prompt.dart';
import 'ui/widgets/screenshot_alert_toast.dart';
import 'ui/widgets/soundboard_overlay.dart';
import 'ui/widgets/version_warning_card.dart';

class WhoTookApp extends ConsumerWidget {
  const WhoTookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final preference =
        settings.value?.themePreference ?? ThemePreference.system;
    final roomThemeId =
        ref.watch(
          matchStateProvider.select(
            (value) => value.value?.roomThemeId,
          ),
        ) ??
        kDefaultRoomThemeId;
    final roomTheme = RoomThemeId.fromWire(roomThemeId);
    final hasSharedTheme = !roomTheme.isClassic;
    final language = settings.value?.language ?? AppLanguage.system;
    final locale = switch (language) {
      AppLanguage.system => null,
      AppLanguage.english => const Locale('en'),
      AppLanguage.dutch => const Locale('nl'),
    };
    return MaterialApp(
      title: 'WhoTook',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildWhoTookTheme(
        Brightness.light,
        palette: hasSharedTheme ? roomTheme.palette(Brightness.light) : null,
      ),
      darkTheme: buildWhoTookTheme(
        Brightness.dark,
        palette: hasSharedTheme ? roomTheme.palette(Brightness.dark) : null,
      ),
      themeMode: switch (roomTheme.forcedBrightness) {
        Brightness.dark => ThemeMode.dark,
        Brightness.light => ThemeMode.light,
        null => switch (preference) {
          ThemePreference.system => ThemeMode.system,
          ThemePreference.light => ThemeMode.light,
          ThemePreference.dark => ThemeMode.dark,
        },
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
      GameAudioService.instance.enabled = settings.soundEnabled;
      GameHaptics.instance.enabled = settings.hapticsEnabled;
    }
    final partyPass = ref.watch(partyPassProvider).value;
    coordinator.updatePartyPass(active: partyPass?.active ?? false);
    coordinator.updateLocale(Localizations.localeOf(context));

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
      RoundPhase.captionReveal =>
        state.activeMode == GameMode.makeItMeme
            ? const MemeScreen(key: ValueKey<String>('meme'))
            : const CaptionScreen(key: ValueKey<String>('caption')),
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
              !state.reconnecting &&
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
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ScreenshotAlertToast(),
          ),
          const SoundboardToast(),
          const SoundboardPill(),
          if (state.reconnecting)
            Positioned.fill(
              child: _ReconnectOverlay(
                secondsLeft: state.reconnectSecondsLeft,
                onLeave: () => unawaited(coordinator.leaveMatch()),
              ),
            ),
          const FirewallPromptOverlay(),
        ],
      ),
    );
  }

  Future<void> _confirmLeave(
    BuildContext context,
    MatchCoordinator coordinator,
    MatchUiState state,
  ) async {
    final l10n = context.l10n;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.leaveRoomTitle),
        content: Text(
          state.isHosting ? l10n.leaveRoomHostBody : l10n.leaveRoomGuestBody,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.stay),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: WhoTookColors.of(context).negative,
            ),
            child: Text(l10n.leave),
          ),
        ],
      ),
    );
    if (leave == true) {
      await coordinator.leaveMatch();
    }
  }
}

class _ReconnectOverlay extends StatelessWidget {
  const _ReconnectOverlay({required this.secondsLeft, required this.onLeave});

  final int secondsLeft;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return ColoredBox(
      color: colors.bg.withValues(alpha: 0.94),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s20),
                  Text(
                    l10n.connectionLost,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    l10n.reconnectingIn(secondsLeft),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: colors.ink2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s20),
                  TextButton(
                    onPressed: onLeave,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.ink2,
                      minimumSize: const Size(0, 44),
                    ),
                    child: Text(l10n.leaveRoom),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
