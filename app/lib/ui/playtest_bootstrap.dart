import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/models.dart';
import '../core/playtest_bridge.dart';
import '../core/playtest_config.dart';
import '../state/match_coordinator.dart';
import '../state/providers.dart';
import 'match_root.dart';
import 'widgets/game_widgets.dart';

/// Test-only shell for the headless web playtest. It turns URL parameters into
/// a host room or a client join, publishes a readable state snapshot for
/// Playwright, and executes small commands through the real coordinator. It is
/// compiled only when `--dart-define=PLAYTEST_MODE=true` is set.
class PlaytestBootstrap extends ConsumerStatefulWidget {
  const PlaytestBootstrap({super.key});

  @override
  ConsumerState<PlaytestBootstrap> createState() => _PlaytestBootstrapState();
}

class _PlaytestBootstrapState extends ConsumerState<PlaytestBootstrap> {
  Timer? _commandTimer;
  bool _booted = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (!PlaytestConfig.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
    _commandTimer = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => unawaited(_runNextCommand()),
    );
  }

  @override
  void dispose() {
    _commandTimer?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    if (_booted || !PlaytestConfig.enabled) return;
    _booted = true;
    final coordinator = ref.read(matchCoordinatorProvider);
    await coordinator.loadSettings();
    final params = Uri.base.queryParameters;
    final role = params['role'];
    if (role == 'host' && coordinator.state.roomId == null) {
      final mode = _modeFrom(params['mode']);
      final rounds = int.tryParse(params['rounds'] ?? '') ?? 3;
      final seconds = int.tryParse(params['roundSeconds'] ?? '') ?? 20;
      await coordinator.hostMatch(
        config: MatchConfig(mode: mode, roundsK: rounds, roundSeconds: seconds),
      );
    } else if (role == 'client') {
      final invite = params['invite'];
      if (invite != null && invite.isNotEmpty) {
        await coordinator.joinMatch(invite);
      }
    }
  }

  GameMode _modeFrom(String? value) => switch (value) {
    'classic' => GameMode.classic,
    'meme' || 'makeItMeme' => GameMode.makeItMeme,
    'sabotage' || 'photoSabotage' => GameMode.photoSabotage,
    'time' || 'timeTraveler' => GameMode.timeTraveler,
    'zoom' || 'zoomOut' => GameMode.zoomOut,
    _ => GameMode.mixedParty,
  };

  Future<void> _runNextCommand() async {
    if (_busy || !_booted) return;
    final raw = takePlaytestCommand();
    if (raw == null) return;
    _busy = true;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        await _execute(decoded);
      }
    } on Object {
      // A bad command must not take the playtest app down.
    } finally {
      _busy = false;
    }
  }

  Future<void> _execute(Map<String, dynamic> command) async {
    final coordinator = ref.read(matchCoordinatorProvider);
    final action = command['action'] as String?;
    final value = command['value'];
    switch (action) {
      case 'startPrepare':
        await coordinator.startPrepare();
      case 'ready':
        if (coordinator.state.isHosting) {
          await coordinator.markLocalReady();
        } else {
          await coordinator.clientMarkReady();
        }
      case 'skipRound':
        await coordinator.skipRound();
      case 'endMemeVoting':
        await coordinator.endMemeVoting();
      case 'advanceMemeReveal':
        await coordinator.advanceMemeReveal();
      case 'classicGuess':
        final ownerId = value as String?;
        if (ownerId == null || ownerId.isEmpty) return;
        if (coordinator.state.isHosting) {
          await coordinator.submitGuess(ownerId);
        } else {
          await coordinator.clientSubmitGuess(ownerId);
        }
      case 'memeSubmit':
        final map = value is Map<String, dynamic>
            ? value
            : const <String, dynamic>{};
        final template = MemeTemplate.values.firstWhere(
          (candidate) => candidate.name == map['template'],
          orElse: () => MemeTemplate.classic,
        );
        if (coordinator.state.isHosting) {
          await coordinator.submitMeme(
            template: template,
            topText: map['topText'] as String? ?? '',
            bottomText: map['bottomText'] as String? ?? '',
            snapY: 48,
          );
        } else {
          await coordinator.clientSubmitMeme(
            template: template,
            topText: map['topText'] as String? ?? '',
            bottomText: map['bottomText'] as String? ?? '',
            snapY: 48,
          );
        }
      case 'sabotageSubmit':
        final strokes = <SabotageStroke>[
          SabotageStroke(
            colorIndex: 2,
            width: 0.012,
            points: const <Offset>[
              Offset(0.24, 0.3),
              Offset(0.52, 0.42),
              Offset(0.7, 0.68),
            ],
          ),
          SabotageStroke(
            colorIndex: 4,
            width: 0.02,
            points: const <Offset>[Offset(0.35, 0.7), Offset(0.6, 0.55)],
          ),
        ];
        if (coordinator.state.isHosting) {
          await coordinator.submitSabotage(strokes);
        } else {
          await coordinator.clientSubmitSabotage(strokes);
        }
      case 'memeVote':
        final focus = coordinator.state.memeFocusId;
        if (focus == null || focus.isEmpty) return;
        final ownId = coordinator.state.memeCards
            .where((card) => card.isOwn)
            .firstOrNull
            ?.id;
        if (ownId == focus) return;
        final vote = MemeVote.values.firstWhere(
          (candidate) => candidate.name == (value ?? 'up'),
          orElse: () => MemeVote.up,
        );
        if (coordinator.state.isHosting) {
          await coordinator.voteMeme(focus, vote);
        } else {
          await coordinator.clientVoteMeme(focus, vote);
        }
      case 'timelineSubmit':
        final map = value is Map<String, dynamic>
            ? value
            : const <String, dynamic>{};
        final year = map['year'] as int? ?? 2015;
        final month = map['month'] as int? ?? 6;
        if (coordinator.state.isHosting) {
          await coordinator.submitTimeline(year, month);
        } else {
          await coordinator.clientSubmitTimeline(year, month);
        }
      case 'openPhotoZoom':
        final state = coordinator.state;
        final bytes = state.activePhotoBytes;
        if (bytes == null || bytes.isEmpty) return;
        unawaited(
          showPhotoLightbox(
            context,
            bytes: bytes,
            photoId: state.activePhotoId,
            caption: state.isHosting ? 'Host' : 'Guest',
          ),
        );
      case 'closePhotoZoom':
        if (mounted) Navigator.of(context).maybePop();
    }
  }

  void _publish(MatchUiState state) {
    final snapshot = <String, dynamic>{
      'phase': state.phase.name,
      'activeMode': state.activeMode.name,
      'currentRound': state.currentRound,
      'totalRounds': state.totalRounds,
      'roomId': state.roomId,
      'inviteUrl': state.inviteUrl,
      'localPlayerId': state.localPlayerId,
      'isHosting': state.isHosting,
      'isConnected': state.connectionMode != null,
      'players': <Map<String, dynamic>>[
        for (final player in state.players)
          <String, dynamic>{
            'id': player.id,
            'name': player.name,
            'score': player.score,
            'isHost': player.isHost,
            'connected': player.connected,
          },
      ],
      'activePhotoId': state.activePhotoId,
      'activePhotoBytesLength': state.activePhotoBytes?.length ?? 0,
      'activePhotoIsPanorama': state.activePhotoIsPanorama,
      'activeRoundOptions': <Map<String, dynamic>>[
        for (final player in state.activeRoundOptions)
          <String, dynamic>{'id': player.id, 'name': player.name},
      ],
      'candidates': state.candidates.length,
      'localReady': state.localReady,
      'remainingMs': state.remainingMs,
      'memeAssignment': state.memeAssignment?.photoId,
      'memePhotoBytesLength': state.memePhotoBase64?.length ?? 0,
      'memeSubmitted': state.memeSubmitted,
      'memeSubmissions': state.memeSubmissions,
      'memeVotesSubmitted': state.memeVotesSubmitted,
      'memeFocusId': state.memeFocusId,
      'memeFocusIndex': state.memeFocusIndex,
      'memeFocusCount': state.memeFocusCount,
      'memeCards': state.memeCards.length,
      'ownMemeId': state.memeCards.where((card) => card.isOwn).firstOrNull?.id,
      'memeRevealCards': state.memeRevealCards.length,
      'timelineSubmitted': state.timelineSubmitted,
      'timelineGuesses': state.timelineGuesses,
      'topMemes': <Map<String, dynamic>>[
        for (final meme in state.topMemes)
          <String, dynamic>{
            'id': meme.id,
            'authorId': meme.authorId,
            'authorName': meme.authorName,
            'photoId': meme.photoId,
            'points': meme.points,
            'upVotes': meme.upVotes,
          },
      ],
      'awards': <Map<String, dynamic>>[
        for (final award in state.awards)
          <String, dynamic>{
            'kind': award.kind.name,
            'playerName': award.playerName,
            'value': award.value,
          },
      ],
      'lastRevealOwnerId': state.lastReveal?.ownerId,
      'lastRevealWrong': state.lastReveal == null
          ? 0
          : state.lastReveal!.guesses
                .where(
                  (guess) =>
                      !guess.isOwnPhoto &&
                      !guess.isCorrect &&
                      guess.guessedOwnerId.isNotEmpty,
                )
                .length,
      'errorMessage': state.errorMessage,
      'versionWarning': state.versionWarning?.latestVersion,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    publishPlaytestState(jsonEncode(snapshot));
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = ref.read(matchCoordinatorProvider);
    final state = ref.watch(matchStateProvider).value ?? coordinator.state;
    ref.listen<AsyncValue<MatchUiState>>(matchStateProvider, (_, next) {
      final value = next.value;
      if (value != null) _publish(value);
    });
    if (!PlaytestConfig.enabled) return const MatchRoot();
    _publish(state);
    return const MatchRoot();
  }
}
