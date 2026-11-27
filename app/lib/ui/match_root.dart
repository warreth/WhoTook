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
import 'widgets/idle_report_overlay.dart';
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

class _MatchRootState extends ConsumerState<MatchRoot> {
  int? _dismissedBuild;
  String? _audioRoomKey;

  void _dismissWarning(VersionWarning warning) {
    setState(() => _dismissedBuild = warning.latestBuild);
    ref.read(matchCoordinatorProvider).dismissVersionWarning();
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    BugReportService.instance
      ..updateGame(
        mode: _diagnosticMode(state.config.mode),
        role: state.isHosting ? 'Host' : 'Guest',
        phase: _diagnosticPhase(state.phase),
        connection: _diagnosticConnection(state.connectionMode, widget.demo),
        demo: widget.demo,
      )
      ..updateScreen(MediaQuery.sizeOf(context));
    if (state.waitingForMatch) {
      return const WaitingRoomScreen();
    }
    final settings = ref.watch(appSettingsProvider).value;
    if (settings != null) {
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
    final partyPass = ref.watch(partyPassProvider).value;
    coordinator.updatePartyPass(active: partyPass?.active ?? false);
    coordinator.updateLocale(Localizations.localeOf(context));

    if (state.turnLimitNotice != null && state.connectionMode == null) {
      return HomeScreen(key: const ValueKey<String>('home'));
    }
    if (widget.demo && state.roomId == null) {
      return const _DemoEndedScreen();
    }

    final atHome =
        !widget.demo && state.roomId == null && state.phase == RoundPhase.lobby;
    final screen = switch (state.phase) {
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
      RoundPhase.podium => const PodiumScreen(key: ValueKey<String>('podium')),
    };
    final warning = state.versionWarning;
    return PopScope(
      canPop: atHome,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_confirmLeave(context, coordinator, state));
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
