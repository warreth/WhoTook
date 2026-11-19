import 'dart:async';
import 'dart:math';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/diagnostics/bug_report_service.dart';
import '../core/models/models.dart';
import '../core/party_pass/party_pass_controller.dart';
import '../core/storage/last_room_repository.dart';
import '../core/storage/settings_repository.dart';
import '../state/match_coordinator.dart';
import '../state/providers.dart';
import '../transport/game_transport.dart';
import '../transport/hybrid_connector.dart';
import 'demo_photo_library.dart';

/// Runs the real host and three real clients over the in-process loopback
/// transport. The UI is the production match UI, so a demo can never drift
/// away from the game's screens or rules.
class DemoMatchController {
  DemoMatchController({
    required this.baseSettings,
    this.config = const MatchConfig(
      roundsK: 5,
      roundSeconds: 8,
      mode: GameMode.mixedParty,
      pace: GamePace.fast,
    ),
    this.locale = const Locale('en'),
    this.countdownDuration = const Duration(milliseconds: 800),
    this.revealDuration = const Duration(seconds: 2),
    this.captionRevealDuration = const Duration(seconds: 4),
    this.roundDuration,
  });

  final AppSettings baseSettings;
  final MatchConfig config;
  final Locale locale;
  final Duration countdownDuration;
  final Duration revealDuration;
  final Duration captionRevealDuration;
  final Duration? roundDuration;

  late final LoopbackHub _hub;
  late final DemoPhotoLibrary hostPhotos;
  late final MatchCoordinator host;
  late final AppSettings settings;
  final List<_DemoBot> _bots = <_DemoBot>[];
  final List<LastRoomRepository> _rooms = <LastRoomRepository>[];
  Timer? _driver;
  DateTime _phaseStarted = DateTime.now();
  String _phaseKey = '';
  final Map<String, DateTime> _fired = <String, DateTime>{};
  bool _disposed = false;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    BugReportService.instance.record('DEMO', 'Starting demo setup');
    try {
      _hub = LoopbackHub();
      hostPhotos = DemoPhotoLibrary();
      settings = baseSettings.copyWith(
        nickname: baseSettings.nickname.trim().isEmpty
            ? 'Jij'
            : baseSettings.nickname.trim(),
        avatar: 'rocket',
        clearAvatarPhoto: true,
        onboardingCompleted: true,
      );
      host = MatchCoordinator(
        photos: hostPhotos,
        settings: SettingsRepository(),
        lastRooms: _roomsFor('host'),
        hostTransportFactory: (room, secret, lan) => LoopbackHostTransport(_hub),
        includeOnlineTransport: false,
        platformServices: false,
        random: Random(7),
        appVersion: kAppVersion,
        appBuild: kAppBuildNumber,
        countdownDuration: countdownDuration,
        revealDuration: revealDuration,
        captionRevealDuration: captionRevealDuration,
        timelineRevealDuration: revealDuration,
        roundDuration: roundDuration,
      );
      host.updateSettings(settings);
      host.updateLocale(locale);
      await _guard('STEP_1 host', () => host.hostMatch(config: config));
      if (_disposed) return;
      if (host.state.roomId == null || host.state.inviteUrl == null) {
        throw StateError('demo room did not open');
      }

      const names = <String>['Lotte', 'Sam', 'Noor'];
      const avatars = <String>['star', 'music', 'plant'];
      for (var i = 0; i < names.length; i++) {
        final bot = _DemoBot(
          index: i + 1,
          name: names[i],
          avatar: avatars[i],
          hub: _hub,
          rooms: _roomsFor('bot-$i'),
          locale: locale,
          countdownDuration: countdownDuration,
        );
        _bots.add(bot);
        await _guard('STEP_2 bot ${i + 1} start', bot.start);
        if (_disposed) return;
        await _guard('STEP_3 bot ${i + 1} join', () => bot.join(host.state.inviteUrl!));
        if (_disposed) return;
      }
      await _guard(
        'STEP_4 ready',
        () => _waitFor(() => _disposed || host.state.players.length >= 4),
      );
      if (_disposed) return;
      _driver = Timer.periodic(
        const Duration(milliseconds: 300),
        (_) => _driveBots(),
      );
      BugReportService.instance.record('DEMO', 'Demo setup ready');
    } catch (error, stack) {
      _started = false;
      BugReportService.instance.recordError('DEMO', error, stack);
      rethrow;
    }
  }

  Future<T> _guard<T>(String step, Future<T> Function() action) async {
    final watch = Stopwatch()..start();
    final parts = step.split(' ');
    final tag = 'DEMO_${parts.first}';
    final label = parts.skip(1).join(' ');
    BugReportService.instance.record(tag, '$label start');
    try {
      final result = await action().timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw TimeoutException('$step timed out'),
      );
      BugReportService.instance.record(
        tag,
        '$label ok ${watch.elapsedMilliseconds}ms',
      );
      return result;
    } catch (error, stack) {
      BugReportService.instance.recordError(tag, error, stack);
      rethrow;
    }
  }

  LastRoomRepository _roomsFor(String id) {
    final repo = LastRoomRepository.memory(storageKey: 'whotook.demo.$id');
    _rooms.add(repo);
    return repo;
  }

  Future<void> _waitFor(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('demo did not become ready');
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  void _driveBots() {
    if (_disposed || !host.state.isHosting) return;
    final hostState = host.state;
    final phaseKey =
        '${hostState.phase.name}:${hostState.currentRound}:'
        '${hostState.activeMode.name}';
    if (phaseKey != _phaseKey) {
      _phaseKey = phaseKey;
      _phaseStarted = DateTime.now();
    }
    for (final bot in _bots) {
      _driveBot(bot, hostState);
    }
  }

  void _driveBot(_DemoBot bot, MatchUiState hostState) {
    final client = bot.coordinator;
    final state = client.state;
    switch (hostState.phase) {
      case RoundPhase.preparing:
        if (state.candidates.isNotEmpty && !state.localReady) {
          if (_once(
            'ready:${bot.index}:${_phaseStarted.millisecondsSinceEpoch}',
          )) {
            unawaited(client.clientMarkReady());
          }
        }
      case RoundPhase.guessing:
        if (state.lockedGuessOwnerId != null) return;
        final showTime =
            hostState.lockedGuessOwnerId != null ||
            hostState.remainingMs <= 3500;
        if (!showTime) return;
        final options = state.activeRoundOptions
            .where((player) => player.id != state.localPlayerId)
            .toList();
        if (options.isEmpty) return;
        final target = options[bot.random.nextInt(options.length)];
        if (_once('guess:${bot.index}:${hostState.currentRound}')) {
          unawaited(client.clientSubmitGuess(target.id));
        }
      case RoundPhase.captionWriting:
        if (hostState.activeMode == GameMode.makeItMeme) {
          if (state.memeAssignment == null || state.memeSubmitted) return;
          if (DateTime.now().difference(_phaseStarted) <
              const Duration(seconds: 3)) {
            return;
          }
          if (_once('meme:${bot.index}:${hostState.currentRound}')) {
            final meme = bot.meme(hostState.currentRound);
            unawaited(
              client.clientSubmitMeme(
                template: meme.$1,
                topText: meme.$2,
                bottomText: meme.$3,
                snapY: 48,
              ),
            );
          }
        } else if (hostState.activeMode == GameMode.captionThis) {
          if (state.captionSubmitted) return;
          if (DateTime.now().difference(_phaseStarted) <
              const Duration(seconds: 3)) {
            return;
          }
          if (_once('caption:${bot.index}:${hostState.currentRound}')) {
            unawaited(
              client.clientSubmitCaption(bot.caption(hostState.currentRound)),
            );
          }
        }
      case RoundPhase.captionVoting:
        if (hostState.memeCards.isNotEmpty) {
          final ready =
              hostState.memeVotedIds.isNotEmpty ||
              DateTime.now().difference(_phaseStarted) >
                  const Duration(seconds: 12);
          if (!ready) return;
          for (final card in state.memeCards) {
            if (card.isOwn || state.memeVotedIds.contains(card.id)) continue;
            final key =
                'memevote:${bot.index}:${hostState.currentRound}:${card.id}';
            if (!_once(key)) continue;
            final vote = switch ((hostState.currentRound + bot.index) % 3) {
              0 => MemeVote.up,
              1 => MemeVote.meh,
              _ => MemeVote.down,
            };
            unawaited(client.clientVoteMeme(card.id, vote));
          }
        } else if (state.captionOptions.isNotEmpty) {
          final ready =
              hostState.votedCaptionId != null ||
              DateTime.now().difference(_phaseStarted) >
                  const Duration(seconds: 12);
          if (!ready) return;
          final options = state.captionOptions
              .where((option) => option.id != state.ownCaptionId)
              .toList();
          if (options.isEmpty) return;
          final option = options[bot.random.nextInt(options.length)];
          if (_once('captionvote:${bot.index}:${hostState.currentRound}')) {
            unawaited(client.clientVoteCaption(option.id));
          }
        }
      case RoundPhase.timelineGuessing:
        if (state.timelineSubmitted) return;
        if (DateTime.now().difference(_phaseStarted) <
            const Duration(seconds: 3)) {
          return;
        }
        if (_once('timeline:${bot.index}:${hostState.currentRound}')) {
          final year =
              1994 + ((hostState.currentRound * 7 + bot.index * 5) % 30);
          final month = 1 + ((hostState.currentRound * 3 + bot.index * 4) % 12);
          unawaited(client.clientSubmitTimeline(year, month));
        }
      case RoundPhase.lobby ||
          RoundPhase.countdown ||
          RoundPhase.reveal ||
          RoundPhase.captionReveal ||
          RoundPhase.timelineReveal ||
          RoundPhase.extendPrompt ||
          RoundPhase.podium:
        return;
    }
  }

  bool _once(String key) {
    final now = DateTime.now();
    final last = _fired[key];
    if (last != null && now.difference(last) < const Duration(seconds: 3)) {
      return false;
    }
    _fired[key] = now;
    return true;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _driver?.cancel();
    // The demo only owns memory and loopback objects. Tear them down without
    // awaiting native channels: a user can leave while a bot is still joining.
    for (final bot in _bots) {
      unawaited(bot.dispose().catchError((Object _) {}));
    }
    _bots.clear();
    unawaited(host.dispose().catchError((Object _) {}));
    unawaited(_hub.dispose().catchError((Object _) {}));
    for (final room in _rooms) {
      unawaited(room.forget().catchError((Object _) {}));
    }
    _rooms.clear();
  }

  @visibleForTesting
  List<MatchCoordinator> get botsForTesting =>
      List<MatchCoordinator>.unmodifiable(_bots.map((bot) => bot.coordinator));
}

class _DemoBot {
  _DemoBot({
    required this.index,
    required this.name,
    required this.avatar,
    required this.hub,
    required this.rooms,
    required this.locale,
    required this.countdownDuration,
  });

  final int index;
  final String name;
  final String avatar;
  final LoopbackHub hub;
  final LastRoomRepository rooms;
  final Locale locale;
  final Duration countdownDuration;
  final Random random = Random(20);
  late final MatchCoordinator coordinator;

  Future<void> start() async {
    coordinator = MatchCoordinator(
      photos: DemoPhotoLibrary(playerIndex: index, assetOffset: index),
      settings: SettingsRepository(),
      lastRooms: rooms,
      connector: HybridConnector(
        localClientFactory: (endpoint, secret) => LoopbackClientTransport(hub),
        onlineClientFactory: () => LoopbackClientTransport(hub),
      ),
      appVersion: kAppVersion,
      appBuild: kAppBuildNumber,
      countdownDuration: countdownDuration,
      platformServices: false,
    );
    coordinator.updateSettings(
      AppSettings(nickname: name, avatar: avatar, onboardingCompleted: true),
    );
    coordinator.updateLocale(locale);
  }

  Future<void> join(String invite) => coordinator.joinMatch(invite);

  Future<void> dispose() => coordinator.dispose();

  (MemeTemplate, String, String) meme(int round) {
    const templates = <MemeTemplate>[
      MemeTemplate.classic,
      MemeTemplate.pov,
      MemeTemplate.breaking,
      MemeTemplate.live,
      MemeTemplate.poster,
      MemeTemplate.snap,
      MemeTemplate.split,
    ];
    const tops = <String>[
      'When the cake hits the floor',
      'POV: someone says one more round',
      'BREAKING: the group chat is awake',
      'LIVE from the kitchen',
      'Nobody:',
      'Me arriving with six photos',
      'The photo they did not expect',
    ];
    const bottoms = <String>[
      'and the room heard you',
      'we are still here',
      'nobody is going home',
      'it is 2am',
      'this is the whole story',
      'same room, same Wi-Fi',
      'and somehow it won',
    ];
    final pick = (round + index) % templates.length;
    return (templates[pick], tops[pick], bottoms[pick]);
  }

  String caption(int round) {
    const lines = <String>[
      'This is going to be a long night.',
      'I can explain. Probably.',
      'The cake did not survive.',
      'Nobody move, I am thinking.',
      'This is why we cannot have nice things.',
      'Same room, same Wi-Fi, same chaos.',
    ];
    return lines[(round + index) % lines.length];
  }
}

/// Demo settings stay in memory, so opening the demo never changes the real
/// player name or avatar.
class DemoAppSettingsController extends AppSettingsController {
  DemoAppSettingsController(this.initial);

  final AppSettings initial;

  @override
  Future<AppSettings> build() async => initial;

  @override
  Future<void> apply(AppSettings Function(AppSettings current) change) async {
    state = AsyncData(change(state.value ?? initial));
  }
}

/// The demo does not touch billing or the relay.
class DemoPartyPassController extends PartyPassController {
  @override
  Future<PartyPassState> build() async => const PartyPassState(loading: false);
}
