import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio/game_audio_service.dart';
import '../features/photo_sabotage/sabotage_screen.dart';
import '../features/zoom_out/zoom_out_screen.dart';
import '../core/diagnostics/bug_report_service.dart';
import '../core/audio/soundboard_service.dart';
import '../core/models/models.dart';
import '../core/party_pass/party_pass_controller.dart';
import '../core/theme/game_skin.dart';
import '../l10n/l10n.dart';
import '../core/theme/whotook_theme.dart';
import '../state/match_coordinator.dart';
import '../state/providers.dart';
import 'screens/caption_screen.dart';
import 'screens/extend_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/meme_screen.dart';
import 'screens/podium_screen.dart';
import 'screens/prepare_screen.dart';
import 'screens/round_screen.dart';
import 'screens/waiting_room_screen.dart';
import 'screens/timeline_screen.dart';
import 'widgets/firewall_prompt.dart';
import 'widgets/game_background.dart';
import 'widgets/game_widgets.dart';
import 'widgets/idle_report_overlay.dart';
import 'widgets/mode_picker.dart';
import 'widgets/screenshot_alert_toast.dart';
import 'widgets/soundboard_overlay.dart';
import 'widgets/report_issue_button.dart';
import 'widgets/version_warning_card.dart';

/// Switches between the lobby, preparation, rounds and podium from the single
/// match state, so a reconnect lands on the right screen automatically.
class MatchRoot extends ConsumerStatefulWidget {
  const MatchRoot({super.key, this.demo = false});

  /// Uses the same screens and overlays as the app. Only the room exit and the
  /// home fallback differ, because a demo has no real Home screen.
  final bool demo;

  @override
  ConsumerState<MatchRoot> createState() => _MatchRootState();
}

class _MatchRootState extends ConsumerState<MatchRoot>
    with WidgetsBindingObserver {
  int? _dismissedBuild;
  int? _splashRound;
  GameMode? _splashMode;
  Timer? _splashTimer;
  bool _showSplash = false;
  String? _audioRoomKey;
  String? _diagnosticKey;
  Size? _lastScreenSize;
  AppSettings? _lastSettings;
  bool? _lastPartyPassActive;
  Locale? _lastLocale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(matchCoordinatorProvider).onAppResumed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _splashTimer?.cancel();
    super.dispose();
  }

  void _maybeSplash({
    required RoundPhase phase,
    required bool waitingForMatch,
    required int currentRound,
    required GameMode activeMode,
  }) {
    if (phase == RoundPhase.lobby ||
        phase == RoundPhase.preparing ||
        phase == RoundPhase.podium) {
      _splashRound = null;
      _splashMode = null;
      return;
    }
    if (waitingForMatch ||
        phase != RoundPhase.countdown ||
        currentRound <= 0) {
      return;
    }
    if (_splashRound == currentRound && _splashMode == activeMode) {
      return;
    }
    _splashRound = currentRound;
    _splashMode = activeMode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _showSplash = true);
      unawaited(GameAudioService.instance.pop());
      unawaited(GameHaptics.instance.light());
      _splashTimer?.cancel();
      _splashTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _showSplash = false);
      });
    });
  }

  bool _sameAppliedSettings(AppSettings? a, AppSettings b) {
    if (a == null) return false;
    return a.nickname == b.nickname &&
        a.avatar == b.avatar &&
        a.avatarColorIndex == b.avatarColorIndex &&
        a.avatarPhoto == b.avatarPhoto &&
        a.soundEnabled == b.soundEnabled &&
        a.musicEnabled == b.musicEnabled &&
        a.hapticsEnabled == b.hapticsEnabled &&
        a.themePreference == b.themePreference &&
        a.language == b.language &&
        a.customSignalingUrl == b.customSignalingUrl &&
        a.customTurnUrl == b.customTurnUrl &&
        a.customTurnUsername == b.customTurnUsername &&
        a.customTurnCredential == b.customTurnCredential &&
        a.excludedAlbumIds.length == b.excludedAlbumIds.length &&
        a.excludedAlbumIds.containsAll(b.excludedAlbumIds) &&
        a.blockedPlayerNames.length == b.blockedPlayerNames.length &&
        a.blockedPlayerNames.containsAll(b.blockedPlayerNames);
  }

  void _dismissWarning(VersionWarning warning) {
    setState(() => _dismissedBuild = warning.latestBuild);
    ref.read(matchCoordinatorProvider).dismissVersionWarning();
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.read(matchCoordinatorProvider);
    // Watch only routing/chrome fields so 100 ms remainingMs timer ticks do
    // not rebuild the whole MatchRoot and re-fire settings/audio hooks 10x/s.
    final state = ref.watch(
      matchStateProvider.select((asyncState) {
        final s = asyncState.value ?? coordinator.state;
        return (
          roomId: s.roomId,
          phase: s.phase,
          activeMode: s.activeMode,
          configMode: s.config.mode,
          isHosting: s.isHosting,
          connectionMode: s.connectionMode,
          waitingForMatch: s.waitingForMatch,
          currentRound: s.currentRound,
          totalRounds: s.totalRounds,
          isFinalDoubleRound: s.isFinalDoubleRound,
          reconnecting: s.reconnecting,
          migratingHost: s.migratingHost,
          reconnectSecondsLeft: s.reconnectSecondsLeft,
          turnLimitNotice: s.turnLimitNotice,
          versionWarning: s.versionWarning,
          versionWarningDismissed: s.versionWarningDismissed,
        );
      }),
    );
    final screenSize = MediaQuery.sizeOf(context);
    final diagnosticKey =
        '${state.configMode.name}:${state.isHosting}:${state.phase.name}:${state.connectionMode?.name}:${widget.demo}';
    if (diagnosticKey != _diagnosticKey) {
      _diagnosticKey = diagnosticKey;
      BugReportService.instance.updateGame(
        mode: _diagnosticMode(state.configMode),
        role: state.isHosting ? 'Host' : 'Guest',
        phase: _diagnosticPhase(state.phase),
        connection: _diagnosticConnection(state.connectionMode, widget.demo),
        demo: widget.demo,
      );
    }
    if (screenSize != _lastScreenSize) {
      _lastScreenSize = screenSize;
      BugReportService.instance.updateScreen(screenSize);
    }
    _maybeSplash(
      phase: state.phase,
      waitingForMatch: state.waitingForMatch,
      currentRound: state.currentRound,
      activeMode: state.activeMode,
    );
    final settings = ref.watch(appSettingsProvider).value;
    if (settings != null && !_sameAppliedSettings(_lastSettings, settings)) {
      _lastSettings = settings;
      coordinator.updateSettings(settings);
      GameAudioService.instance.enabled = settings.soundEnabled;
      unawaited(
        GameAudioService.instance.configure(
          sfx: settings.soundEnabled,
          music: settings.musicEnabled,
        ),
      );
      SoundboardService.instance.enabled = settings.soundEnabled;
      GameHaptics.instance.enabled = settings.hapticsEnabled;
    }
    final audioRoomKey = state.roomId == null
        ? null
        : '${state.roomId}:${state.isHosting}';
    if (audioRoomKey != _audioRoomKey) {
      _audioRoomKey = audioRoomKey;
      unawaited(
        GameAudioService.instance.applyRoomRole(
          isHost: state.isHosting,
          inRoom: state.roomId != null,
        ),
      );
    }
    final partyPassActive = ref.watch(partyPassProvider).value?.active ?? false;
    if (partyPassActive != _lastPartyPassActive) {
      _lastPartyPassActive = partyPassActive;
      coordinator.updatePartyPass(active: partyPassActive);
    }
    final locale = Localizations.localeOf(context);
    if (locale != _lastLocale) {
      _lastLocale = locale;
      coordinator.updateLocale(locale);
    }

    if (state.turnLimitNotice != null && state.connectionMode == null) {
      return HomeScreen(key: const ValueKey<String>('home'));
    }
    if (widget.demo && state.roomId == null) {
      return const _DemoEndedScreen();
    }

    final atHome =
        !widget.demo && state.roomId == null && state.phase == RoundPhase.lobby;
    final screen = state.waitingForMatch
        ? const WaitingRoomScreen(key: ValueKey<String>('waiting'))
        : switch (state.phase) {
            RoundPhase.lobby =>
              state.roomId == null
                  ? const HomeScreen(key: ValueKey<String>('home'))
                  : const LobbyScreen(key: ValueKey<String>('lobby')),
            RoundPhase.preparing => const PrepareScreen(
              key: ValueKey<String>('prepare'),
            ),
            RoundPhase.countdown || RoundPhase.guessing || RoundPhase.reveal =>
              state.activeMode == GameMode.zoomOut
                  ? const ZoomOutScreen(key: ValueKey<String>('zoom-out'))
                  : const RoundScreen(key: ValueKey<String>('round')),
            RoundPhase.captionWriting ||
            RoundPhase.captionVoting ||
            RoundPhase.captionReveal =>
              state.activeMode == GameMode.photoSabotage
                  ? const SabotageScreen(key: ValueKey<String>('sabotage'))
                  : state.activeMode == GameMode.makeItMeme
                  ? const MemeScreen(key: ValueKey<String>('meme'))
                  : const CaptionScreen(key: ValueKey<String>('caption')),
            RoundPhase.timelineGuessing || RoundPhase.timelineReveal =>
              const TimelineScreen(key: ValueKey<String>('timeline')),
            RoundPhase.extendPrompt => const ExtendScreen(
              key: ValueKey<String>('extend'),
            ),
            RoundPhase.podium => const PodiumScreen(
              key: ValueKey<String>('podium'),
            ),
          };
    final warning = state.versionWarning;
    return PopScope(
      canPop: atHome,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_confirmLeave(context, coordinator, coordinator.state));
      },
      child: IdleReportOverlay(
        resetToken:
            '${state.roomId}:${state.phase.name}:${state.currentRound}:'
            '${state.activeMode.name}:${state.connectionMode?.name}',
        enabled: !atHome && !state.reconnecting,
        screenLabel: 'Match: ${_diagnosticPhase(state.phase)}',
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            screen,
            if (_showSplash && _splashRound != null && !state.waitingForMatch)
              _ArcadeSplash(
                round: _splashRound!,
                totalRounds: state.totalRounds,
                mode: _splashMode ?? state.activeMode,
                isFinalDoubleRound: state.isFinalDoubleRound,
              ),
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
                  migratingHost: state.migratingHost,
                  onLeave: () => unawaited(coordinator.leaveMatch()),
                ),
              ),
            const FirewallPromptOverlay(),
          ],
        ),
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
        title: Text(widget.demo ? l10n.endDemoTitle : l10n.leaveRoomTitle),
        content: Text(
          widget.demo
              ? l10n.endDemoBody
              : state.isHosting
              ? l10n.leaveRoomHostBody
              : l10n.leaveRoomGuestBody,
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
            child: Text(widget.demo ? l10n.endDemo : l10n.leave),
          ),
        ],
      ),
    );
    if (leave == true) {
      await coordinator.leaveMatch();
    }
  }
}

String _diagnosticMode(GameMode mode) => switch (mode) {
  GameMode.classic => 'Classic',
  GameMode.captionThis => 'Caption This',
  GameMode.zoomOut => 'Zoom-Out',
  GameMode.makeItMeme => 'Make It Meme',
  GameMode.photoSabotage => 'Foto-Sabotage',
  GameMode.timeTraveler => 'Time Traveler',
  GameMode.mixedParty => 'Mixed Party',
};

String _diagnosticPhase(RoundPhase phase) => switch (phase) {
  RoundPhase.lobby => 'Lobby',
  RoundPhase.preparing => 'Vault',
  RoundPhase.countdown => 'Countdown',
  RoundPhase.guessing => 'Round',
  RoundPhase.reveal => 'Reveal',
  RoundPhase.captionWriting => 'Caption writing',
  RoundPhase.captionVoting => 'Caption voting',
  RoundPhase.captionReveal => 'Caption reveal',
  RoundPhase.timelineGuessing => 'Time Traveler',
  RoundPhase.timelineReveal => 'Timeline reveal',
  RoundPhase.extendPrompt => 'Extra photos',
  RoundPhase.podium => 'Podium',
};

String _diagnosticConnection(ConnectionMode? mode, bool demo) {
  if (demo) return 'Demo';
  return switch (mode) {
    ConnectionMode.localLan => 'Local Wi-Fi',
    ConnectionMode.webrtcP2p => 'Direct P2P',
    ConnectionMode.webrtcTurn => 'TURN',
    ConnectionMode.offlineLoopback => 'Offline',
    null => '-',
  };
}

class _DemoEndedScreen extends StatelessWidget {
  const _DemoEndedScreen();

  @override
  Widget build(BuildContext context) {
    final colors = WhoTookColors.of(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.smart_toy_outlined, size: 40, color: colors.ink2),
                const SizedBox(height: 12),
                Text(
                  l10n.demoEndedTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.demoEndedBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: colors.ink2,
                  ),
                ),
                const SizedBox(height: 18),
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
}

class _ReconnectOverlay extends StatelessWidget {
  const _ReconnectOverlay({
    required this.secondsLeft,
    this.migratingHost = false,
    required this.onLeave,
  });

  final int secondsLeft;
  final bool migratingHost;
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
                    migratingHost
                        ? l10n.hostMigratingTitle
                        : l10n.connectionLost,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    migratingHost
                        ? l10n.hostMigratingBody(secondsLeft)
                        : l10n.reconnectingIn(secondsLeft),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: colors.ink2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.s8,
                    children: <Widget>[
                      TextButton(
                        onPressed: onLeave,
                        style: TextButton.styleFrom(
                          foregroundColor: colors.ink2,
                          minimumSize: const Size(0, 44),
                        ),
                        child: Text(l10n.leaveRoom),
                      ),
                      const ReportIssueButton(screenLabel: 'Reconnect'),
                    ],
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

class _ArcadeSplash extends StatelessWidget {
  const _ArcadeSplash({
    required this.round,
    required this.totalRounds,
    required this.mode,
    required this.isFinalDoubleRound,
  });

  final int round;
  final int totalRounds;
  final GameMode mode;
  final bool isFinalDoubleRound;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final skin = GameModeSkin.forMode(mode);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final kicker = (totalRounds > 0
            ? l10n.roundOf(round, totalRounds)
            : l10n.roundBadge(round, round))
        .toUpperCase();
    final modeTitle = modeLabel(l10n, mode);
    final blurb = switch (mode) {
      GameMode.classic => l10n.modeClassicBlurb,
      GameMode.zoomOut => l10n.modeZoomOutBlurb,
      GameMode.makeItMeme => l10n.modeMakeItMemeBlurb,
      GameMode.photoSabotage => l10n.modePhotoSabotageBlurb,
      _ => l10n.modeClassicBlurb,
    };

    return IgnorePointer(
      child: Material(
        color: skin.base,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: reduce ? 1 : 0.25, end: 1),
              duration: reduce
                  ? Duration.zero
                  : const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: Transform.rotate(angle: -0.035, child: child),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: skin.deep,
                  borderRadius: BorderRadius.circular(AppRadii.rCard),
                  border: Border.all(color: Colors.black, width: 4),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(0, 8),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      kicker,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                        color: skin.accent.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      modeTitle,
                      textAlign: TextAlign.center,
                      style: gameDisplay(
                        size: 34,
                        height: 1.0,
                        color: skin.accent,
                        letterSpacing: -0.9,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      blurb,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.86),
                      ),
                    ),
                    if (isFinalDoubleRound) ...<Widget>[
                      const SizedBox(height: 12),
                      StickerBadge(
                        label: l10n.finalRoundDoubleBadge,
                        background: GamePalette.gold,
                        foreground: GamePalette.onGold,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
